export type LuaArray<T> = {
  [key: number]: T;
  [Symbol.iterator](): IterableIterator<T>;
};

export type BGPDatabase = Record<string, LuaArray<number>>;

export enum BGPMessageType {
  PROPAGATE = 'propagate',
  CARRIER = 'carrier',
}
export interface BGPMessage {
  /** A random SHA hash of the message */
  id: string;

  type: BGPMessageType;

  /** The historical path of the message */
  trace: LuaArray<number>;

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

export interface BGPCarrierMessage extends BGPMessage {
  type: BGPMessageType.CARRIER;

  /** The underlying payload (to, from, data) */
  payload: {
    /** The ID of the computer that the message is destined for */
    to: number;

    /** The ID of the computer that the message is originating from */
    from: number;

    /** The data of the message */
    data: any;
  };
}
