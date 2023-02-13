import { getModems } from 'lib/lib';
import { getDBEntry } from './db';
import { generateRandomHash } from './lib';
import { BGPCarrierMessage, BGPMessageType } from './types';

const BGP_PORT = 179;
const computerID = os.getComputerID();

/** Gets a list of the local neighbors for a wired LAN */
export function getLocalNeighbors() {
  const modemSides = getModems();
  const modems = modemSides
    // Get all of the modems
    .map((modem) => peripheral.wrap(modem) as ModemPeripheral);

  const sidesToIds: Record<string, number[]> = {};
  modems.forEach((modem, i) => {
    if (modem.getNamesRemote) {
      sidesToIds[modemSides[i]] = modem
        .getNamesRemote()
        .filter((name) => name.startsWith('computer_'))
        .map((name) => modem.callRemote(name, 'getID') as number);
    } else {
      sidesToIds[modemSides[i]] = [];
    }
  });

  const idsToSides: Record<number, string[]> = {};
  Object.entries(sidesToIds).forEach(([side, ids]) => {
    ids.forEach((id) => {
      if (!idsToSides[id]) idsToSides[id] = [];
      idsToSides[id].push(side);
    });
  });

  return {
    ids: Object.values(sidesToIds).reduce((a, b) => a.concat(b), []),
    sidesToIds,
    idsToSides,
  };
}

/** Sends a carrier message to the destination accordingly */
export function sendBGPCarrierMessage(payload: BGPCarrierMessage['payload']) {
  const { to } = payload;
  const entry = getDBEntry(to);
  const neighbors = getLocalNeighbors();

  if (!entry || Object.values(entry).length === 0) {
    throw new Error(`Could not find a route to: ${to}`);
  }

  const via = Object.values(entry)[0];
  const side = neighbors.idsToSides[via]?.[0];

  const message: BGPCarrierMessage = {
    id: generateRandomHash(),
    type: BGPMessageType.CARRIER,
    payload,
    from: computerID,
    origin: computerID,
    trace: [computerID],
  };

  if (to === computerID) {
    // TODO: Support sending messages to localhost
    // Can't use handleBGPMessage because it's tied to the main file
    // handleBGPMessage(message);
    print('Cannot send messages to localhost');
    return;
  }

  if (!side) {
    throw new Error(`Could not find a modem that sends to: ${to} via ${entry}`);
  }

  const modem = peripheral.wrap(side) as ModemPeripheral;
  modem.transmit(BGP_PORT, BGP_PORT, message);

  print(`Sent message to ${to} via ${via}`);
}
