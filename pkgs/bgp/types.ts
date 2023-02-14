export type LuaArray<T> = {
  [key: number]: T;
  [Symbol.iterator](): IterableIterator<T>;
};

export type BGPDatabase = Array<BGPDatabaseRecord>;

export interface BGPDatabaseRecord {
  /** The ID of the destination computer */
  destination: number;

  /** The ID of the computer that can reach the destination */
  via: number;

  /** The side of the modem that connects to `via` */
  side: string;

  /** The TTL of the entry (as expiry time in epoch) */
  ttl: number;

  /**
   * How many hops it will take to get to the destination
   *
   * For example: if `A -> B -> C`
   *
   * then `A` will take `1` hop to get to `C`
   *
   * then `B` will take `0` hops to get to `C` (direct connection)
   */
  hops: number;
}

export interface ModemMessage {
  event: string;
  side: string;
  channel: number;
  replyChannel: number;
  message: any;
}

export interface BGPMessage {
  /** The trace of nodes that handled the message (origin, ...first -> last) */
  trace: LuaArray<number>;

  /** The computers in the origin's LAN */
  neighbors: LuaArray<number>;

  /** If the last node was hardwired. If we get a message from a hardwired node, we drop latter wireless entries (no need for extra hops) */
  hardwired: boolean;
}

export interface IPMessage {
  /** The ID of the computer that the message is destined for */
  to: number;

  /** The ID of the computer that the message is originating from */
  from: number;

  /** The trace of nodes that handled the message (origin, ...first -> last) */
  trace: LuaArray<number>;

  /** The data that is being sent */
  data: any;
}
