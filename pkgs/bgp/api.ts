import { pretty_print } from 'cc.pretty';
import { getModems } from 'lib/lib';
import { getDBEntry } from './db';
import { generateRandomHash } from './lib';
import { BGPCarrierMessage, BGPMessageType } from './types';

const BGP_PORT = 179;
const computerID = os.getComputerID();

export interface State {
  /** Composition around computers connected to the LAN and their relation with modem sides */
  neighbors: ReturnType<typeof getLocalNeighbors>;

  /** List of modem sides */
  modemSides: string[];

  /** Map of modem sides to modem peripherals */
  sidesToModems: Map<string, ModemPeripheral>;

  /** List of modem sides that are wireless */
  wirelessModemSides: string[];
}

/** Creates useful compositions around modems such as getting all sides occupied by modems */
export function getPeripheralState(): State {
  const neighbors = getLocalNeighbors();

  const modemSides = getModems();
  const sidesToModems = new Map<string, ModemPeripheral>(
    modemSides.map((side) => [side, peripheral.wrap(side) as ModemPeripheral])
  );
  const wirelessModemSides = modemSides.filter((side) =>
    sidesToModems.get(side).isWireless()
  );

  return {
    neighbors,
    modemSides,
    sidesToModems,
    wirelessModemSides,
  };
}

/** Opens the BGP port on all modems */
export function openPorts({ sidesToModems }: Pick<State, 'sidesToModems'>) {
  sidesToModems.forEach((modem) => modem.open(BGP_PORT));
}

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

/** Displays a BGP message */
export function displayBGPMessage(message: BGPCarrierMessage) {
  print(`Received BGP carrier message:`);
  pretty_print(message.payload);
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
    displayBGPMessage(message);
    return;
  }

  if (!side) {
    throw new Error(`Could not find a modem that sends to: ${to} via ${entry}`);
  }

  const modem = peripheral.wrap(side) as ModemPeripheral;
  modem.transmit(BGP_PORT, BGP_PORT, message);

  print(`Sent message to ${to} via ${via}`);
}
