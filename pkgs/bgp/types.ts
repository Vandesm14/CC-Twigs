export type LuaArray<T> = {
  [key: number]: T;
  [Symbol.iterator](): IterableIterator<T>;
};

export interface BGPDatabase {
  // key: the destination computer ID
  [key: string]: BGPDestinationEntry;
}

export interface BGPDestinationEntry {
  // key: the ID of the node that can reach the destination
  [key: string]: {
    /** The side of the node */
    side: string;

    /** The TTL of the entry (as expiry time in epoch) */
    ttl: number;
  };
}

export interface BGPDestinationEntryInt {
  // key: the ID of the node that can reach the destination
  [key: number]: {
    /** The side of the node */
    side: string;

    /** The TTL of the entry (as expiry time in epoch) */
    ttl: number;
  };
}

export interface ModemMessage {
  event: string;
  side: string;
  channel: number;
  replyChannel: number;
  message: any;
}

export enum BGPMessageType {
  PROPAGATE = 'propagate',
  CARRIER = 'carrier',
}
export interface BGPMessage {
  /** A random string to differentiate messages */
  id: string;

  type: BGPMessageType;

  /** The ID of the computer that sent the message */
  from: number;

  /** The ID of the computer that originally sent the message (the first computer) */
  origin: number;
}

export interface BGPPropagateMessage extends BGPMessage {
  type: BGPMessageType.PROPAGATE;

  /** The computers in the origin's LAN */
  neighbors: LuaArray<number>;
}

export interface IPMessage {
  /** A random string to differentiate messages */
  id: string;

  /** The ID of the computer that the message is destined for */
  to: number;

  /** The ID of the computer that the message is originating from */
  from: number;

  /** The data that is being sent */
  data: any;
}
