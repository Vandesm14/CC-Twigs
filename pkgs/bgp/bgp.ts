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
  const sidesToIds: Map<string, number[]> = new Map(
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

  const idsToSides = new Map<number, string[]>([]);
  sidesToIds.forEach((ids, side) => {
    ids.forEach((id) => {
      if (!idsToSides.has(id)) idsToSides.set(id, []);
      idsToSides.get(id).push(side);
    });
  });

  return {
    ids: Array.from(sidesToIds.values()).reduce((a, b) => a.concat(b), []),
    sidesToIds,
    idsToSides,
  };
}

const neighbors = getLocalNeighbors();

print(`Found ${neighbors.ids.length} nodes on local network.`);

const modemSides = getModems();
const modems = modemSides.map(
  (modem) => peripheral.wrap(modem) as ModemPeripheral
);
const sidesToModems = new Map<string, ModemPeripheral>(
  modemSides.map((side, i) => [side, modems[i]])
);
const wirelessModemSides = modemSides.filter((side) =>
  sidesToModems.get(side).isWireless()
);

const history: string[] = [];

function sendBGPMessage(message: BGPMessage, modemSide: string) {
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
    // Generate a new ID if this is a new message
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

  // Filter out the sides that we've already sent the message to or seen the message from
  const idsToSides = Array.from(neighbors.idsToSides);
  const sidesToSendTo = [
    ...idsToSides
      .filter(([id]) => !Object.values(message.trace).includes(id))
      .flatMap(([_, sides]) => sides),

    // We are using a trick to get neighbors for LAN modems,
    // we can't use that trick for wireless modems, so we
    // always have to relay to wireless modems
    ...wirelessModemSides,
  ];

  print(`${previous ? 'Relaying' : 'Broadcasting'} BGP message: ${message.id}`);

  sidesToSendTo.forEach((modemSide) => {
    // Send a BGP message
    sendBGPMessage(message, modemSide);
  });

  if (previous) {
    // Run through each neighbor and update the destination to the previous.from (where the message came from)
    // so we know where to send the message to for each destination
    Object.values(previous.neighbors).forEach((neighbor) => {
      // Only update the DB if the neighbor is not us
      if (neighbor !== computerID) updateDBEntry(neighbor, previous.from);
    });
  }

  // Run through our own neighbors and update the destination to the message.from
  // so we know where to send the message to for each destination
  neighbors.ids.forEach((neighbor) => {
    // Only update the DB if the neighbor is not us
    if (neighbor !== computerID) updateDBEntry(neighbor, neighbor);
  });

  // Add the message to the history
  history.push(message.id);
}

/** Waits for a `modem_message` OS event, then prints the message and relays the BGP message */
function waitForMessage(this: void) {
  const [event, side, channel, replyChannel, rawMessage] =
    os.pullEvent('modem_message');

  const message = rawMessage as BGPMessage;

  print(`Received BGP message: ${message.id}`);

  if (message.type === BGPMessageType.UPDATE_LISTING) {
    const updateListingMessage = message as BGPUpdateListingMessage;
    const isInHistory = history.includes(updateListingMessage.id);

    history.push(updateListingMessage.id);

    if (!isInHistory) {
      // If we haven't seen this message before,
      // broadcast it to all of the neighbors
      broadcastBGPUpdateListing(updateListingMessage);
    }
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
        broadcastBGPUpdateListing();
      }
    );
  }
}

createDBIfNotExists();
clearDB();
main();
