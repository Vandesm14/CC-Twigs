import { pretty_print } from 'cc.pretty';
import { getModems } from 'lib/lib';
import { BGP_PORT, IP_PORT } from './constants';
import { getDBEntry } from './db';
import { BGPMessage, IPMessage } from './types';

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
  sidesToModems.forEach((modem) => {
    modem.open(BGP_PORT);
    modem.open(IP_PORT);
  });
}

/** Displays a BGP message */
export function displayIPMessage(message: IPMessage) {
  print(`Received IP message:`);
  pretty_print(message);
}

/** A small wrapper to ensure type-safety of sending a BGP message */
export function sendRawBGP(message: BGPMessage, modemSide: string) {
  const modem = peripheral.wrap(modemSide) as ModemPeripheral;

  modem.transmit(BGP_PORT, BGP_PORT, message);
}

/** A small wrapper to ensure type-safety of sending an IP message */
export function sendRawIP(
  message: IPMessage,
  channel: number,
  modemSide: string
) {
  const modem = peripheral.wrap(modemSide) as ModemPeripheral;

  modem.transmit(channel, channel, message);
}

export interface sendIPProps {
  /** If `true`, ignores BGP logic and broacasts message via all modems */
  broadcast?: boolean;

  /**
   * The channel to send the message on
   * @default IP_PORT
   */
  channel?: number;
}

/** Sends a carrier message to the destination accordingly */
export function sendIP(
  message: Omit<IPMessage, 'id' | 'trace'>,
  opts?: { broadcast?: boolean; channel?: number }
) {
  const { to } = message;
  const entry = opts?.broadcast ? 'any' : getDBEntry(to);

  if (!opts?.broadcast && (!entry || Object.keys(entry).length === 0)) {
    throw new Error(`Could not find a route to: ${to}`);
  }

  const via = opts?.broadcast ? 'any' : Object.keys(entry)[0];
  const sides = opts?.broadcast ? getModems() : [entry[via].side];

  let ipMessage: IPMessage = {
    ...message,

    // We add the ID of the destination so that they know
    // that they are the next hop in our journey (but not the destination)
    // Only do this if we are not broadcasting
    trace: opts?.broadcast ? [computerID] : [computerID, parseInt(via)],
  };

  if (to === computerID) {
    // TODO: actually handle sending to "localhost"
    displayIPMessage(ipMessage);
    return;
  }

  if (sides.length === 0) {
    throw new Error(`Could not find a modem that sends to: ${to} via ${entry}`);
  }

  sides.forEach((side) => {
    sendRawIP(ipMessage, opts?.channel ?? IP_PORT, side);
  });

  print(`Sent message to ${to} via ${via}`);
}

export function trace(trace?: number[]) {
  trace = [...trace] ?? [];

  const obj = {
    /** Gets the last item */
    from() {
      return trace.slice(-1)[0];
    },

    /** Gets the first item */
    origin() {
      return trace[0];
    },

    /** Checks if the last item is the computerID */
    // shouldDrop() {
    //   return obj.from() === computerID;
    // },

    /** Checks if the node has seen the message (only if the id is within the array) */
    hasSeen(id = computerID) {
      return trace.indexOf(id) !== -1 && trace.indexOf(id) !== obj.size() - 1;
    },

    /** Checks if the trace is not empty */
    isEmpty() {
      return !(trace.length > 0);
    },

    /** Adds the computerID to the end of the trace */
    addSelf(ids?: number[]) {
      return [...trace, computerID, ...(ids ?? [])];
    },

    /** Adds an array of computerIDs to the end of the trace */
    add(ids: number[]) {
      return [...trace, ...ids];
    },

    /** Gets the size of the trace */
    size() {
      return trace.length;
    },

    /** Creates a Set from the trace */
    toSet() {
      return new Set(trace);
    },
  };

  return obj;
}
