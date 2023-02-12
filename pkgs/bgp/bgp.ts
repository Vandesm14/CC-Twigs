import { pretty_print } from 'cc.pretty';
import { getModems } from '../lib/lib';

const BGP_PORT = 179;

// Get the computer's ID
const computerID = os.getComputerID();

// Use the computer ID as the BGP router ID
print('BGP Router ID: ' + computerID);

function getLocalNeighbors() {
  const modemSides = getModems();
  const modems = modemSides
    // Get all of the modems
    .map((modem) => peripheral.wrap(modem) as ModemPeripheral);
  // Get all computers on the network (of the modem)
  const computerIDs: Map<string, number[]> = new Map(
    modems.map((modem, i) => [
      modemSides[i],
      modem.getNamesRemote
        ? modem
            .getNamesRemote()
            .filter((name) => name.startsWith('computer_'))
            .map((name) => modem.callRemote(name, 'getID') as number)
        : [],
    ])
  );

  return {
    ids: Array.from(computerIDs.values()).reduce((a, b) => a.concat(b), []),
    mapOfSides: computerIDs,
  };
}

type LuaArray<T> = Record<number, T>;

enum BGPMessageType {
  UPDATE_LISTING = 'update_listing',
}
interface BGPMessage {
  // The type of message
  type: BGPMessageType;

  // The historical path of the message
  trace: LuaArray<number>;

  // The ID of the computer that sent the message
  from: number;

  // The ID of the computer that originally sent the message (the first computer)
  origin: number;
}

interface BGPUpdateListingMessage extends BGPMessage {
  type: BGPMessageType.UPDATE_LISTING;

  // The computers in the origin's LAN
  neighbors: LuaArray<number>;
}

function sendBGPMessage(
  message: BGPMessage,
  modemSide: string,
  printMsg = true
) {
  const modem = peripheral.wrap(modemSide) as ModemPeripheral;

  if (printMsg) {
    print('out:');
    pretty_print(message);
  }

  modem.transmit(BGP_PORT, BGP_PORT, message);
}

const neighbors = getLocalNeighbors();

print(`Found ${neighbors.ids.length} nodes on local network.`);

const modemSides = getModems();
const modems = modemSides.map(
  (modem) => peripheral.wrap(modem) as ModemPeripheral
);

function openPorts() {
  modems.forEach((modem) => modem.open(BGP_PORT));
}

function createDBIfNotExists() {
  const exists = fs.exists('bgp.db');
  if (!exists) {
    const [file] = fs.open('bgp.db', 'w');
    file.writeLine('{}');
    file.close();
  }
}

function updateDBEntry(originId: number, neighbors: LuaArray<number>) {
  createDBIfNotExists();

  const [fileRead] = fs.open('bgp.db', 'r');
  let db = textutils.unserialize(fileRead.readAll()) as Record<
    number,
    LuaArray<number>
  >;
  fileRead.close();
  db = db ?? {};

  db[`c_${originId}`] = neighbors;

  const [fileWrite] = fs.open('bgp.db', 'w');
  fileWrite.write(textutils.serialize(db));
  fileWrite.close();

  print(
    `Updated DB for ${originId} with ${
      Object.values(neighbors).length
    } neighbors.`
  );
}

function getDBEntry(originId: number) {
  createDBIfNotExists();

  const [fileRead] = fs.open('bgp.db', 'r');
  const db = textutils.unserialize(fileRead.readLine()) as Record<
    number,
    LuaArray<number>
  >;
  fileRead.close();

  return db[originId];
}

function broadcastBGPUpdateListing(previous?: BGPUpdateListingMessage) {
  const message: BGPUpdateListingMessage = {
    type: BGPMessageType.UPDATE_LISTING,
    trace: previous?.trace
      ? [...Object.values(previous.trace), computerID]
      : [computerID],
    from: computerID,
    origin: previous?.origin ?? computerID,
    neighbors: previous?.neighbors ?? neighbors.ids,
  };

  modemSides.forEach((modemSide) => {
    // Send a BGP message
    sendBGPMessage(message, modemSide, false);
  });

  // If this is our message, update the DB for ourselves
  if (!previous) updateDBEntry(message.origin, message.neighbors);

  print('out:');
  pretty_print(message);
}

let lastMessage: BGPUpdateListingMessage = null;

/** Waits for a `modem_message` OS event, then prints the message and relays the BGP message */
function waitForMessage(this: void) {
  const [event, side, channel, replyChannel, rawMessage] =
    os.pullEvent('modem_message');

  const message = rawMessage as BGPMessage;

  // print('in:');
  // pretty_print(message);

  if (message.type === BGPMessageType.UPDATE_LISTING) {
    const updateListingMessage = message as BGPUpdateListingMessage;

    // If the message has already been seen, ignore it
    if (Object.values(updateListingMessage.trace).includes(computerID)) {
      print('Message already seen, ignoring...');
      return;
    }

    updateDBEntry(updateListingMessage.origin, updateListingMessage.neighbors);

    lastMessage = updateListingMessage;
    print(
      `Received BGP message from ${updateListingMessage.from}, forwarding...`
    );

    // Else, broadcast it to all of the neighbors
    broadcastBGPUpdateListing(updateListingMessage);
  }
}

function main() {
  // open the ports
  openPorts();
  print('Ports open');

  while (true) {
    let didReceiveMessage = false;

    // Wait for a message, or timeout after `TIMEOUT` seconds
    const TIMEOUT = 5;
    parallel.waitForAny(
      () => sleep(TIMEOUT),
      () => {
        waitForMessage();
        didReceiveMessage = true;
      }
    );

    if (!didReceiveMessage) {
      // If we haven't received a message, broadcast our own
      broadcastBGPUpdateListing();
      print('BGP message broadcasted');
    }
  }
}

main();
