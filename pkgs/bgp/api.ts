import { pretty, render } from 'cc.pretty';
import { default as os } from 'cc/os';
import {
  ModemPeripheral,
  default as peripheral,
  PeripheralKind,
  PeripheralName,
} from 'cc/peripheral';
import { BGP_CHANNEL, IP_PORT } from './constants';
import { findShortestRoute } from './db';
import { BGPMessage, IPMessage } from './types';

/** The ID of the computer */
const COMPUTER_ID = os.id();

export interface State {
  /** List of modem names */
  modemNames: PeripheralName[];

  /** Modem peripherals */
  modems: ModemPeripheral[];

  /** List of modem names that are wireless */
  wirelessModemNames: PeripheralName[];
}

/** Creates useful compositions around modems such as getting all sides occupied by modems */
export function getPeripheralState(): State {
  const modems = peripheral.find(PeripheralKind.Modem);
  const modemNames = peripheral
    .attached()
    .filter(({ kind }) => kind === PeripheralKind.Modem)
    .map(({ name }) => name);
  const wirelessModemNames = modemNames.filter((name) =>
    (peripheral.wrap(name) as ModemPeripheral).isWireless()
  );

  return { modemNames, modems, wirelessModemNames };
}

/** Opens the BGP port on all modems */
export function openPorts({ modems }: Pick<State, 'modems'>) {
  modems.forEach((modem) => {
    modem.open(BGP_CHANNEL);
    modem.open(IP_PORT);
  });
}

/** Displays a BGP message */
export function formatIPMessage(message: IPMessage) {
  return `Receeived IP Message:\n${render(pretty(message))}`;
}

/** A small wrapper to ensure type-safety of sending a BGP message */
export function sendRawBGP(message: BGPMessage, modemSide: PeripheralName) {
  const modem = peripheral.wrap(modemSide) as ModemPeripheral;
  if (!modem) return;

  modem.transmit(BGP_CHANNEL, BGP_CHANNEL, message);
}

/** A small wrapper to ensure type-safety of sending an IP message */
export function sendRawIP(
  message: IPMessage,
  channel: number,
  modemName: PeripheralName
) {
  const modem = peripheral.wrap(modemName) as ModemPeripheral;
  if (!modem) return;

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
  const ipMessage: IPMessage = {
    ...message,
    trace: [COMPUTER_ID],
  };

  let sides = peripheral
    .attached()
    .filter(({ kind }) => kind === PeripheralKind.Modem)
    .map(({ name }) => name);

  if (to === COMPUTER_ID) {
    // TODO: actually handle sending to "localhost"
    throw new Error(`Cannot send message to self`);
  } else if (opts?.broadcast) {
    print(`Sent message to ${to} via *`);
  } else {
    if (sides.length === 0) throw new Error(`No modems found`);

    const route = findShortestRoute(to);
    if (!route) throw new Error(`Could not find a route to: ${to}`);

    sides = [route.side];
    ipMessage.trace = [COMPUTER_ID, route.via];

    print(`Sent message to ${to} via ${route.via}`);
  }

  sides.forEach((side) => {
    sendRawIP(ipMessage, opts?.channel ?? IP_PORT, side);
  });
}

export function trace(trace?: number[]) {
  const storedTrace = trace ? [...trace] : [];

  const obj = {
    /** Gets the last item */
    from() {
      return storedTrace.slice(-1)[0];
    },

    /** Gets the first item */
    origin() {
      return storedTrace[0];
    },

    /**
     * Gets the distance of a node from self
     * [a, b, c, d, self]
     * distacne(self) = 0 (self)
     * distance(d)    = 1
     * distance(a)    = 4
     *
     * If self isn't in the trace, it will compensate (BGP logic)
     * [a, b, c, d]
     * distacne(self) = 0 (self)
     * distance(d)    = 1
     * distance(a)    = 4
     */
    distance(id: number) {
      if (id === COMPUTER_ID) return 0;
      const selfIsAtEnd = obj.from() === COMPUTER_ID;

      if (selfIsAtEnd) {
        return storedTrace.length - storedTrace.indexOf(id) - 2;
      } else {
        return storedTrace.length - storedTrace.indexOf(id) - 1;
      }
    },

    /** Checks if the node has seen the message (only if the id is within the array) */
    hasSeen(id = COMPUTER_ID) {
      return (
        storedTrace.indexOf(id) !== -1 &&
        storedTrace.indexOf(id) !== obj.size() - 1
      );
    },

    /** Checks if the trace is empty */
    isEmpty() {
      return !(storedTrace.length > 0);
    },

    /** Adds the computerID to the end of the trace */
    addSelf(ids?: number[]) {
      return [...storedTrace, COMPUTER_ID, ...(ids ?? [])];
    },

    /** Adds an array of computerIDs to the end of the trace */
    add(ids: number[]) {
      return [...storedTrace, ...ids];
    },

    /** Gets the size of the trace */
    size() {
      return storedTrace.length;
    },

    /** Creates a Set from the trace */
    toSet() {
      return new Set(trace);
    },
  };

  return obj;
}
