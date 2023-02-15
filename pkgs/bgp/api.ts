import { pretty_print } from 'cc.pretty';
import { getModems } from 'lib/lib';
import { BGP_PORT, IP_PORT } from './constants';
import { findShortestRoute } from './db';
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
    // We know that the modem exists because we just wrapped it
    sidesToModems.get(side)!.isWireless()
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
  if (!modem) return;

  modem.transmit(BGP_PORT, BGP_PORT, message);
}

/** A small wrapper to ensure type-safety of sending an IP message */
export function sendRawIP(
  message: IPMessage,
  channel: number,
  modemSide: string
) {
  const modem = peripheral.wrap(modemSide) as ModemPeripheral;
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
    trace: [computerID],
  };

  let sides = getModems();

  if (to === computerID) {
    // TODO: actually handle sending to "localhost"
    displayIPMessage(ipMessage);
    return;
  } else if (opts?.broadcast) {
    print(`Sent message to ${to} via *`);
  } else {
    if (sides.length === 0) throw new Error(`No modems found`);

    const route = findShortestRoute(to);
    if (!route) throw new Error(`Could not find a route to: ${to}`);

    sides = [route.side];
    ipMessage.trace = [computerID, route.via];

    print(`Sent message to ${to} via ${route.via}`);
  }

  sides.forEach((side) => {
    sendRawIP(ipMessage, opts?.channel ?? IP_PORT, side);
  });

  // const { to } = message;
  // const route = findShortestRoute(to);

  // if (!opts?.broadcast && !route) {
  //   throw new Error(`Could not find a route to: ${to}`);
  // }

  // let sides = opts?.broadcast ? getModems() : [route.side];

  // let ipMessage: IPMessage = {
  //   ...message,

  //   // We add the ID of the destination so that they know
  //   // that they are the next hop in our journey (but not the destination)
  //   // Only do this if we are not broadcasting
  //   trace: opts?.broadcast ? [computerID] : [computerID, route.via],
  // };

  // if (to === computerID) {
  //   // TODO: actually handle sending to "localhost"
  //   displayIPMessage(ipMessage);
  //   return;
  // }

  // if (sides.length === 0) {
  //   throw new Error(
  //     `Could not find a modem that sends to: ${to} via ${
  //       opts?.broadcast ? 'any' : route
  //     }`
  //   );
  // }

  // sides.forEach((side) => {
  //   sendRawIP(ipMessage, opts?.channel ?? IP_PORT, side);
  // });

  // print(`Sent message to ${to} via ${opts?.broadcast ? 'any' : route.via}`);
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
      if (id === computerID) return 0;
      const selfIsAtEnd = obj.from() === computerID;

      if (selfIsAtEnd) {
        return storedTrace.length - storedTrace.indexOf(id) - 2;
      } else {
        return storedTrace.length - storedTrace.indexOf(id) - 1;
      }
    },

    /** Checks if the node has seen the message (only if the id is within the array) */
    hasSeen(id = computerID) {
      return (
        storedTrace.indexOf(id) !== -1 &&
        storedTrace.indexOf(id) !== obj.size() - 1
      );
    },

    /** Checks if the trace is not empty */
    isEmpty() {
      return !(storedTrace.length > 0);
    },

    /** Adds the computerID to the end of the trace */
    addSelf(ids?: number[]) {
      return [...storedTrace, computerID, ...(ids ?? [])];
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
