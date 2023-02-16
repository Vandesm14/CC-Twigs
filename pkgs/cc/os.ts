import { Peripheral } from "./peripheral";

/**
 * Synchronously waits for {@linkcode millis} to elapse on the current thread
 * before continuing execution.
 *
 * This calls {@linkcode coroutine.yield} internally.
 *
 * @param millis The number of milliseconds.
 */
export function sleep(this: void, millis: number): void {
  os.sleep(millis / 1000);
}

/**
 * Synchronously waits for the {@linkcode until} epoch on the current thread
 * before continuing execution.
 *
 * This calls {@linkcode sleep} internally.
 *
 * @param until The epoch to wait until in milliseconds.
 * @param locale The {@linkcode Locale} to be relative to.
 */
export function sleepUntil(this: void, until: number, locale = Locale.InGame) {
  const diff = until - epoch(locale);
  if (diff > 0) sleep(diff);
}

/**
 * Returns the epoch since the beginning of a {@linkcode Locale}.
 *
 * This converts `ingame` milliseconds into real-world milliseconds.
 *
 * @param locale The {@linkcode Locale} to be relative to.
 */
export function epoch(this: void, locale = Locale.InGame): number {
  return locale === Locale.InGame ? os.epoch() / 72 : os.epoch(locale);
}

/** Returns the number of milliseconds the computer has been up. */
export function clock(this: void): number {
  return os.clock() * 1000;
}

/** Shutdown the computer immediately. */
export function shutdown(this: void): never {
  os.shutdown();
}

/** Reboot the computer immediately. */
export function reboot(this: void): never {
  os.reboot();
}

/** Returns the computer ID. */
export function id(this: void): ComputerId {
  return os.getComputerID();
}

/** Returns the computer label. */
export function label(this: void): ComputerLabel {
  return os.getComputerLabel();
}

/** Sets the computer label, or unsets it if `undefined`. */
export function setLabel(this: void, label?: ComputerLabel): void {
  os.setComputerLabel(label);
}

/**
 * Synchronously waits for an {@linkcode Event} on the current thread before
 * continuing execution.
 *
 * This calls {@linkcode coroutine.yield} internally.
 *
 * @param filter The {@linkcode EventKind} to filter by.
 * @param raw Whether to also check for {@linkcode EventKind.Terminate}.
 */
export function event<E extends EventKind>(this: void, filter: E, raw = false): Event<E> {
  const event = raw ? os.pullEventRaw(filter) : os.pullEvent(filter);
  return createEvent(event);
}

/**
 * Queues an {@linkcode Event}.
 *
 * @param event The {@linkcode Event} to queue.
 */
export function queueEvent<T extends Event<EventKind>>(this: void, event: T): void {
  switch (event.event) {
    case (EventKind.ModemMessage):
      os.queueEvent(
        event.event,
        event.side,
        event.channel,
        event.replyChannel,
        event.message,
        event.distance,
      );
      break;
    case (EventKind.PeripheralAttach):
    case (EventKind.PeripheralDetach):
      os.queueEvent(event.event, event.side);
      break;
    case (EventKind.Terminate):
      os.queueEvent(event.event);
      break;
  }
}

/** Represents a locale. */
export const enum Locale {
  /** Relative to ingame. */
  InGame = "ingame",
  /** Relative to UTC. */
  Utc = "utc",
  /** Relative to user local. */
  Local = "local",
}

/** Represents a computer ID. */
export type ComputerId = number;
/** Represents a computer label. */
export type ComputerLabel = string | undefined;

/** Represents an event. */
export type Event<E extends EventKind> = E extends EventKind.ModemMessage
  ? ModemMessageEvent
  : E extends EventKind.PeripheralAttach ? PeripheralAttachEvent
  : E extends EventKind.PeripheralDetach ? PeripheralDetachEvent
  : E extends EventKind.Terminate ? TerminateEvent
  : AnyEvent;
/** Represents any event. */
export type AnyEvent =
  | PeripheralAttachEvent
  | PeripheralDetachEvent
  | TerminateEvent;

/**
 * Represents an event fired when a {@linkcode ModemPeripheral} receives a
 * message.
 */
export type ModemMessageEvent = {
  /** The {@linkcode EventKind} repeated. */
  event: EventKind.ModemMessage;
  /** The {@linkcode Side} the message was received from. */
  side: Side;
  /** The channel the message was received via. */
  channel: number;
  /** The channel to reply via. */
  replyChannel: number;
  /** The message data. */
  message: unknown;
  /** The distance in metres between the sender and receiver. */
  distance: number;
};

/** Represents an event fired when a {@linkcode Peripheral} is attached. */
export type PeripheralAttachEvent = {
  /** The {@linkcode EventKind} repeated. */
  event: EventKind.PeripheralAttach;
  /** The {@linkcode Side} the {@linkcode Peripheral} was attached to. */
  side: Side;
};

/** Represents an event fired when a {@linkcode Peripheral} is attached. */
export type PeripheralDetachEvent = {
  /** The {@linkcode EventKind} repeated. */
  event: EventKind.PeripheralDetach;
  /** The {@linkcode Side} the {@linkcode Peripheral} was detached to. */
  side: Side;
};

/** Represents an event fired when `ctrl+t` is held. */
export type TerminateEvent = {
  /** The {@linkcode EventKind} repeated. */
  event: EventKind.Terminate;
};

/** Represents an event kind. */
export const enum EventKind {
  /** A modem message event. */
  ModemMessage = "modem_message",
  /** A peripheral attach event. */
  PeripheralAttach = "peripheral",
  /** A peripheral detach event. */
  PeripheralDetach = "peripheral_detach",
  /** A terminate event. */
  Terminate = "terminate",
}

/** Represents a block side relative to its direction. */
export const enum Side {
  /** The top side. */
  Top = "top",
  /** The bottom side. */
  Bottom = "bottom",
  /** The left side. */
  Left = "left",
  /** The right side. */
  Right = "right",
  /** The front side. */
  Front = "front",
  /** The back side. */
  Back = "back",
}

function createEvent<E extends EventKind>(event: [string, ...unknown[]]) {
  switch (event[0]) {
    case EventKind.ModemMessage:
      return {
        event: EventKind.ModemMessage,
        side: event[1],
        channel: event[2],
        replyChannel: event[3],
        message: event[4],
        distance: event[5],
      } as Event<E>;
    case EventKind.PeripheralAttach:
      return {
        event: EventKind.PeripheralAttach,
        side: event[1],
      } as Event<E>;
    case EventKind.PeripheralDetach:
      return {
        event: EventKind.PeripheralDetach,
        side: event[1],
      } as Event<E>;
    case EventKind.Terminate:
      return { event: EventKind.Terminate } as Event<E>;
    default:
      throw `unknown event: ${event[0]}`;
  }
}

declare module os {
  function sleep(this: void, secs: number): void;

  function epoch(this: void, locale?: Locale): number;
  function clock(this: void): number;

  function shutdown(this: void): never;
  function reboot(this: void): never;

  function getComputerID(this: void): number;
  function getComputerLabel(this: void): string | undefined;
  function setComputerLabel(this: void, label?: string): void;

  function pullEvent(this: void, filter?: string): LuaMultiReturn<[string, ...unknown[]]>;
  function pullEventRaw(
    this: void,
    filter?: string,
  ): LuaMultiReturn<[string, ...unknown[]]>;

  function queueEvent(this: void, event: string, ...args: unknown[]): void;
}
