import { pretty_print } from 'cc.pretty';
import { getModems } from '../lib/lib';

const BGP_PORT = 179;

// Get the computer's ID
const computerID = os.getComputerID();

// Use the computer ID as the BGP router ID
print('BGP Router ID: ' + computerID);

/** Gets a list of the local neighbors for a wired LAN */
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

const neighbors = getLocalNeighbors();

print(`Found ${neighbors.ids.length} nodes on local network.`);

const modemSides = getModems();
const modems = modemSides.map(
  (modem) => peripheral.wrap(modem) as ModemPeripheral
);

const history: string[] = [];

/** Generates a random SHA hash: "8a19e136" */
function generateRandomHash() {
  return Math.random().toString(16).substring(2, 10);
}

type LuaArray<T> = {
  [key: number]: T;
  [Symbol.iterator](): IterableIterator<T>;
};

enum BGPMessageType {
  UPDATE_LISTING = 'update_listing',
  CARRIER = 'carrier',
}
interface BGPMessage {
  // A random SHA hash of the message
  id: string;

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

interface BGPCarrierMessage extends BGPMessage {
  type: BGPMessageType.CARRIER;

  payload: {
    // The ID of the computer that the message is destined for
    to: number;

    // The ID of the computer that the message is originating from
    from: number;

    // The data of the message
    data: any;
  };
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

function updateDBEntry(destination: number, from: number) {
  const [fileRead] = fs.open('bgp.db', 'r');
  let db = textutils.unserialize(fileRead.readAll()) as Record<
    string,
    LuaArray<number>
  >;
  fileRead.close();
  db = db ?? {};

  if (Object.keys(db).length === 0) print(`DB is empty!`);

  const destinationKey = `c_${destination}`;
  if (db[destinationKey]) {
    db[destinationKey] = Array.from(new Set([...db[destinationKey], from]));
  } else {
    db[destinationKey] = [from];
  }

  const [fileWrite] = fs.open('bgp.db', 'w');
  fileWrite.write(textutils.serialize(db));
  fileWrite.close();
  print(
    `Updated DB for ${destination} with ${
      Object.values(db[destinationKey]).length
    } routes.`
  );
}

function getDB(originId: number) {
  const [fileRead] = fs.open('bgp.db', 'r');
  const db = textutils.unserialize(fileRead.readAll()) as Record<
    number,
    LuaArray<number>
  >;
  fileRead.close();

  return db;
}

function broadcastBGPUpdateListing(previous?: BGPUpdateListingMessage) {
  const message: BGPUpdateListingMessage = {
    id: previous?.id ?? generateRandomHash(),
    type: BGPMessageType.UPDATE_LISTING,
    trace: previous?.trace
      ? [...Object.values(previous.trace), computerID]
      : [computerID],
    from: computerID,
    origin: previous?.origin ?? computerID,
    neighbors: previous?.neighbors
      ? Array.from(
          new Set([...previous.neighbors, ...neighbors.ids, computerID])
        )
      : Array.from(new Set([...neighbors.ids, computerID])),
  };

  // Add the message to the history
  history.push(message.id);

  modemSides.forEach((modemSide) => {
    // Send a BGP message
    sendBGPMessage(message, modemSide, false);
  });

  // If this is our message, update the DB for ourselves
  // if (!previous)
  //   Object.values(message.neighbors).forEach((neighbor) =>
  //     updateDBEntry(neighbor, neighbor)
  //   );

  print(
    `${previous ? 'Propagating' : 'Broadcasting'} BGP message ${message.id}...`
  );
}

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
    if (history.includes(updateListingMessage.id)) {
      print('Message already seen, ignoring...');
      return;
    }
    history.push(updateListingMessage.id);

    // updateDBEntry(updateListingMessage.from, updateListingMessage.neighbors);
    Object.values(updateListingMessage.neighbors).forEach((neighbor) => {
      // Only update the DB if the neighbor is not us
      if (neighbor !== computerID)
        updateDBEntry(neighbor, updateListingMessage.from);
    });

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

createDBIfNotExists();
createDBIfNotExists();
main();
