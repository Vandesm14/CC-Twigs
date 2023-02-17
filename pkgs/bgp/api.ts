import os from 'cc/os';

/** The reserved channel for BGP communication. */
export const BGP_CHANNEL = 0;
/** The heartbeat interval in milliseconds.  */
export const HEARTBEAT_INTERVAL = 5000;
/** The time-to-live interval in milliseconds.  */
export const TIME_TO_LIVE_INTERVAL = HEARTBEAT_INTERVAL + 2000;
/** The BGP channel routing range. */
export const BGP_CHANNEL_RANGE: [number, number] = [0, 127];
/** The BGP routes table file path. */
export const BGP_ROUTES_TABLE_PATH = '.mngr/data/bgp/route_table.json';

const COMPUTER_ID = os.id();

/** Contains functionality for {@linkcode BGPMessage}s. */
export const BGP = {
  /** Returns whether an unknown message is a {@linkcode BGPMessage}. */
  isBGPMessage(this: void, message: unknown): message is BGPMessage {
    return (
      typeof message === 'object' &&
      message !== null &&
      'trace' in message &&
      Array.isArray(message.trace)
    );
  },

  /** Returns the source computer. */
  source(this: void, message: BGPMessage): number | undefined {
    return message.trace[0];
  },

  /** Returns the previously visited computer. */
  previous(this: void, message: BGPMessage): number | undefined {
    return message.trace[message.trace.length - 1];
  },

  /** Returns whether this computer has already seen the message. */
  seen(this: void, message: BGPMessage, id = COMPUTER_ID): boolean {
    return (
      message.trace.indexOf(id) !== -1 &&
      message.trace.indexOf(id) !== message.trace.length
    );
  },

  /**
   * Returns the distance of an computer from itself.
   *
   * This will compensate for whether the computer is at the end of the trace.
   */
  distance(this: void, message: BGPMessage, id: number): number {
    if (id === COMPUTER_ID) return 0;

    const inclusion = BGP.previous(message) === COMPUTER_ID ? 2 : 1;
    return message.trace.length - message.trace.indexOf(id) - inclusion;
  },
};

/** Contains functionality for {@linkcode BaseMessage}s. */
export const BASE = {
  /** Returns whether an unknown message is a {@linkcode BaseMessage}. */
  isBaseMessage(this: void, message: unknown): message is BaseMessage {
    return (
      typeof message === 'object' &&
      message !== null &&
      'destination' in message &&
      typeof message.destination === 'number' &&
      'trace' in message &&
      Array.isArray(message.trace)
    );
  },

  /** Returns the source computer. */
  source(this: void, message: BaseMessage): number | undefined {
    return message.trace[0];
  },

  /** Returns the destination computer. */
  destination(this: void, message: BaseMessage): number | undefined {
    return message.destination;
  },
};

/** A BGP propagation message. */
export type BGPMessage = {
  /** The trace of computers visited so far. */
  trace: number[];
};

/** A base message routable by BGP. */
export type BaseMessage = {
  /** The destination of the packet. */
  destination: number;
  /** The trace of computers visited so far. */
  trace: number[];
};
