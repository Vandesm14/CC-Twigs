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

/** Contains functionality for {@linkcode IPMessage}s. */
export const IP = {
  /** Creates a {@linkcode IPMessage}. */
  create(
    this: void,
    destination: number,
    via: number,
    source = COMPUTER_ID
  ): IPMessage {
    return { destination, trace: [source, via] };
  },

  /** Returns whether an unknown message is a {@linkcode IPMessage}. */
  isIPMessage(this: void, message: unknown): message is IPMessage {
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
  source(this: void, message: IPMessage): number | undefined {
    return message.trace[0];
  },

  /** Returns the destination computer. */
  destination(this: void, message: IPMessage): number | undefined {
    return message.destination;
  },

  /** Returns whether this computer has already seen the message. */
  seen(this: void, message: IPMessage, id = COMPUTER_ID): boolean {
    return (
      message.trace.indexOf(id) !== -1 &&
      message.trace.indexOf(id) !== message.trace.length - 1
    );
  },
};

/** Contains functionality for {@linkcode UDPMessage}s. */
export const UDP = {
  /** Creates a {@linkcode UDPMessage}. */
  create<T>(this: void, ipMessage: IPMessage, data: T): UDPMessage<T> {
    return { ...ipMessage, data };
  },

  /** Returns whether an unknown message is a {@linkcode UDPMessage}. */
  isUDPMessage(this: void, message: unknown): message is UDPMessage {
    return IP.isIPMessage(message) && 'data' in message;
  },
};

/** A BGP propagation message. */
export type BGPMessage = {
  /** The trace of computers visited so far. */
  trace: number[];
};

/** An IP message routable by BGP. */
export type IPMessage = {
  /** The destination of the message. */
  destination: number;
  /** The trace of computers visited so far. */
  trace: number[];
};

/** A UDP message routable by IP. */
export type UDPMessage<T = unknown> = IPMessage & {
  /** The data of the message. */
  data: T;
};

/** Represents a network event. */
export type NetEvent<E extends NetEventKind> = E extends NetEventKind.IP
  ? never
  : E extends NetEventKind.UDP
  ? never
  : AnyNetEvent;
/** Represents any network event. */
export type AnyNetEvent = never;

/** Represents a network event kind. */
export const enum NetEventKind {
  /** An IP message event. */
  IP = 'ip_message',
  /** A UDP message event. */
  UDP = 'udp_message',
}

/** Represents an IP network event. */
export type IPMessageEvent = IPMessage & {
  /** The channel the message was received on. */
  channel: number;
  /** The channel to send reply messages via. */
  replyChannel: number;
};
