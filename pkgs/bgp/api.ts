import { pretty_print } from 'cc.pretty';
import { getModems } from 'lib/lib';
import { BGP_PORT } from './constants';
import { getDBEntry } from './db';
import { generateRandomHash } from './lib';
import { BGPCarrierMessage, BGPMessageType } from './types';

/** The ID of the computer */
const computerID = os.getComputerID();

export interface State {
  /** List of modem sides */
  modemSides: string[];

  /** Map of modem sides to modem peripherals */
  sidesToModems: Map<string, ModemPeripheral>;

  /** List of modem sides that are wireless */
  wirelessModemSides: string[];
}

/** Creates useful compositions around modems such as getting all sides occupied by modems */
export function getPeripheralState(): State {
  const modemSides = getModems();
  const sidesToModems = new Map<string, ModemPeripheral>(
    modemSides.map((side) => [side, peripheral.wrap(side) as ModemPeripheral])
  );
  const wirelessModemSides = modemSides.filter((side) =>
    sidesToModems.get(side).isWireless()
  );

  return {
    modemSides,
    sidesToModems,
    wirelessModemSides,
  };
}

/** Opens the BGP port on all modems */
export function openPorts({ sidesToModems }: Pick<State, 'sidesToModems'>) {
  sidesToModems.forEach((modem) => modem.open(BGP_PORT));
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

  if (!entry || Object.keys(entry).length === 0) {
    throw new Error(`Could not find a route to: ${to}`);
  }

  const via = Object.keys(entry)[0];
  const side = entry[via].side;

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
