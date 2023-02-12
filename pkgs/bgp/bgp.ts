// import { pretty_print } from 'cc.pretty';
import { getModems } from '../lib/lib';
import { generateRandomHash } from './lib';
import {
  BGPMessage,
  BGPMessageType,
  BGPUpdateListingMessage,
  LuaArray,
} from './types';
import * as log from 'debug/log';

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

function sendBGPMessage(
  message: BGPMessage,
  modemSide: string,
  printMsg = true
) {
  const modem = peripheral.wrap(modemSide) as ModemPeripheral;

  modem.transmit(BGP_PORT, BGP_PORT, message);
}

function openPorts() {
  modems.forEach((modem) => modem.open(BGP_PORT));
}

function createDBIfNotExists() {
  const exists = fs.exists('bgp.db');
  if (!exists) clearDB();
}

function clearDB() {
  const [fileWrite] = fs.open('bgp.db', 'w');
  fileWrite.write('{}');
  fileWrite.close();
}

function updateDBEntry(destination: number, from: number) {
  const [fileRead] = fs.open('bgp.db', 'r');
  let db = textutils.unserialize(fileRead.readAll()) as Record<
    string,
    LuaArray<number>
  >;
  fileRead.close();
  db = db ?? {};

  const destinationKey = `c_${destination}`;
  if (db[destinationKey]) {
    db[destinationKey] = Array.from(new Set([...db[destinationKey], from]));
  } else {
    db[destinationKey] = [from];
  }

  const [fileWrite] = fs.open('bgp.db', 'w');
  fileWrite.write(textutils.serialize(db));
  fileWrite.close();

  term.clear();
  term.setCursorPos(1, 1);

  if (Object.keys(db).length === 0) print(`DB was empty!`);

  print(`DB has ${Object.keys(db).length} entries.`);
  Object.entries(db).forEach(([key, value]) => {
    print(`${key}: ${Object.values(value).join(', ')}`);
  });
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
          new Set([
            // Add the previous neighbors to the list
            ...previous.neighbors,
            // Add our neighbors to the list
            ...neighbors.ids,
            // Add the previous computer ID to the list
            previous.from,
            // Add our computer ID to the list
            computerID,
          ])
        )
      : Array.from(new Set([...neighbors.ids, computerID])),
  };

  print(`${previous ? 'Relaying' : 'Broadcasting'} BGP message: ${message.id}`);

  log.viaHTTP({
    comment: 'Sending BGP message',
    id: computerID,
    ts: os.epoch('utc'),
    type: previous ? 'Relaying' : 'Broadcasting',
    message,
  });

  // Add the message to the history
  history.push(message.id);

  modemSides.forEach((modemSide) => {
    // Send a BGP message
    sendBGPMessage(message, modemSide, false);
  });
}

/** Waits for a `modem_message` OS event, then prints the message and relays the BGP message */
function waitForMessage(this: void) {
  const [event, side, channel, replyChannel, rawMessage] =
    os.pullEvent('modem_message');

  const message = rawMessage as BGPMessage;

  print(`Received BGP message: ${message.id}`);

  log.viaHTTP({
    comment: 'Received BGP message',
    ts: os.epoch('utc'),
    id: computerID,
    message,
  });

  if (message.type === BGPMessageType.UPDATE_LISTING) {
    const updateListingMessage = message as BGPUpdateListingMessage;

    // updateDBEntry(updateListingMessage.from, updateListingMessage.neighbors);
    Object.values(updateListingMessage.neighbors).forEach((neighbor) => {
      // Only update the DB if the neighbor is not us
      if (neighbor !== computerID)
        updateDBEntry(neighbor, updateListingMessage.from);
    });

    if (!history.includes(updateListingMessage.id)) {
      // If we haven't seen this message before,
      // broadcast it to all of the neighbors
      broadcastBGPUpdateListing(updateListingMessage);
    }

    history.push(updateListingMessage.id);
  }
}

function main() {
  // open the ports
  openPorts();
  print('Ports open');

  while (true) {
    // Timeout to wait for a message (real-world BGP uses 30 seconds)
    const TIMEOUT = 5;

    // If either of the functions return, the other one will be cancelled
    parallel.waitForAny(
      () => {
        // Wait for a BPG message
        waitForMessage();
      },
      () => {
        // Wait for `TIMEOUT` seconds
        sleep(TIMEOUT);

        // If we haven't received a message in `TIMEOUT` seconds,
        // clear the DB and broadcast a new BGP message
        clearDB();
        broadcastBGPUpdateListing();
      }
    );
  }
}

createDBIfNotExists();
main();
