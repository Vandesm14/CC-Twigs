import type { Peripheral, ModemPeripheral } from './peripheral';

/**
 * Puts the current thread to sleep for the specifier amount of time.
 *
 * The thread may sleep for shorter or longer than specified in real-time due to
 * scheduling.
 *
 * This calls {@linkcode coroutine.yield} internally.
 *
 * @param millis The number of milliseconds to sleep.
 */
export function sleep(this: void, millis: number) {
  os.sleep(millis / 1000);
}

/**
 * Puts the current thread to sleep until an epoch is reached.
 *
 * The thread may sleep for shorter or longer than specified in real-time due to
 * scheduling.
 *
 * This calls {@linkcode sleep} internally.
 *
 * @param until The epoch in milliseconds to sleep until.
 * @param locale The locale whoes epoch to compare against.
 */
export function sleepUntil(this: void, until: number, locale = Locale.InGame) {
  const diff = until - epoch(locale);
  if (diff > 0) sleep(diff);
}

/**
 * Returns the duration in milliseconds since the epoch for `locale`.
 *
 * This converts in-game milliseconds into real-world milliseconds.
 *
 * @param locale The locale to get the epoch for.
 */
export function epoch(this: void, locale = Locale.InGame): number {
  return locale === Locale.InGame ? os.epoch() / 72 : os.epoch(locale);
}

/** Returns the duration in milliseconds since this computer was started. */
export function uptime(this: void): number {
  return os.clock() * 1000;
}

/** Shutdown this computer immediately. */
export function shutdown(this: void): never {
  os.shutdown();
}

/** Reboot this computer immediately. */
export function reboot(this: void): never {
  os.reboot();
}

/** Returns this computer's ID. */
export function id(this: void): number {
  return os.getComputerID();
}

/** Returns this computer's label. */
export function label(this: void): string | undefined {
  return os.getComputerLabel();
}

/**
 * Sets this computer's label, or unsets it if `undefined` is supplied.
 *
 * @param label The new label or `undefined` to unset the label.
 */
export function setLabel(this: void, label?: string): void {
  os.setComputerLabel(label);
}

/**
 * Waits for an {@linkcode Event}.
 *
 * This calls {@linkcode coroutine.yield} internally.
 *
 * @param filter The {@linkcode EventKind} to wait for.
 * @param raw Whether to also wait for {@linkcode TerminateEvent}s.
 */
export function event<E extends EventKind>(
  this: void,
  filter?: E,
  raw = false
): Event<E> {
  const event = raw ? os.pullEventRaw(filter) : os.pullEvent(filter);
  return createEvent(event);
}

/**
 * Queues an {@linkcode Event}.
 *
 * @param event The {@linkcode Event} to queue.
 */
export function queueEvent<T extends Event<EventKind>>(
  this: void,
  event: T
): void {
  switch (event.event) {
    case EventKind.ModemMessage:
      os.queueEvent(
        event.event,
        event.side,
        event.channel,
        event.replyChannel,
        event.message,
        event.distance
      );
      break;
    case EventKind.PeripheralAttach:
    case EventKind.PeripheralDetach:
      os.queueEvent(event.event, event.side);
      break;
    case EventKind.Terminate:
      os.queueEvent(event.event);
      break;
  }
}

/**
 * Waits for a {@linkcode CustomEvent}.
 *
 * This calls {@linkcode coroutine.yield} internally.
 *
 * @param filter The {@linkcode EventKind} to wait for.
 */
export function customEvent<E extends string, T extends Record<PropertyKey, unknown>>(filter: E): CustomEvent<E, T> {
  return os.pullEvent(filter) as unknown as CustomEvent<E, T>;
}

/**
 * Queues a {@linkcode CustomEvent}.
 *
 * @param event The {@linkcode CustomEvent} to queue.
 */
export function queueCustomEvent<T extends CustomEvent<string, Record<PropertyKey, unknown>>>(
  this: void,
  event: T
): void {
  os.queueEvent(event[0], event[1]);
}

export default {
  sleep,
  sleepUntil,
  epoch,
  uptime,
  shutdown,
  reboot,
  id,
  label,
  setLabel,
  event,
  queueEvent,
  customEvent,
  queueCustomEvent,
};

/** Represents a locale. */
export const enum Locale {
  /** Relative to in-game time. */
  InGame = 'ingame',
  /** Relative to UTC. */
  Utc = 'utc',
  /** Relative to the user's local time. */
  Local = 'local',
}

/** Represents an event. */
export type Event<E extends EventKind> = E extends EventKind.ModemMessage
  ? ModemMessageEvent
  : E extends EventKind.PeripheralAttach
  ? PeripheralAttachEvent
  : E extends EventKind.PeripheralDetach
  ? PeripheralDetachEvent
  : E extends EventKind.Terminate
  ? TerminateEvent
  : AnyEvent;
/** Represents any event. */
export type AnyEvent =
  | PeripheralAttachEvent
  | PeripheralDetachEvent
  | TerminateEvent;

/** Represents a custom event. */
export type CustomEvent<E extends string, T extends Record<PropertyKey, unknown>> = [E, T];

/**
 * Represents an event fired when a {@linkcode ModemPeripheral} receives a
 * message.
 */
export type ModemMessageEvent<T = unknown> = {
  /** The {@linkcode EventKind} repeated. */
  event: EventKind.ModemMessage;
  /** The {@linkcode Side} the message was received from. */
  side: Side;
  /** The channel the message was received via. */
  channel: number;
  /** The channel to reply via. */
  replyChannel: number;
  /** The message data. */
  message: T;
  /** The distance in metres between the sender and receiver. */
  distance: number;
};

/** Represents an event fired when a {@linkcode Peripheral} is attached. */
export type PeripheralAttachEvent = {
  /** The {@linkcode EventKind} repeated. */
  event: EventKind.PeripheralAttach;
  /** The {@linkcode Side} the peripheral was attached to. */
  side: Side;
};

/** Represents an event fired when a {@linkcode Peripheral} is detached. */
export type PeripheralDetachEvent = {
  /** The {@linkcode EventKind} repeated. */
  event: EventKind.PeripheralDetach;
  /** The {@linkcode Side} the peripheral was detached from. */
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
  ModemMessage = 'modem_message',
  /** A peripheral attach event. */
  PeripheralAttach = 'peripheral',
  /** A peripheral detach event. */
  PeripheralDetach = 'peripheral_detach',
  /** A terminate event. */
  Terminate = 'terminate',
}

/** Represents a block side relative to its direction. */
export const enum Side {
  /** The top side. */
  Top = 'top',
  /** The bottom side. */
  Bottom = 'bottom',
  /** The left side. */
  Left = 'left',
  /** The right side. */
  Right = 'right',
  /** The front side. */
  Front = 'front',
  /** The back side. */
  Back = 'back',
}

function createEvent<E extends EventKind>(
  event: [string, ...unknown[]]
): Event<E> {
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
    case EventKind.PeripheralDetach:
      return {
        event: event[0],
        side: event[1],
      } as Event<E>;
    case EventKind.Terminate:
      return { event: EventKind.Terminate } as Event<E>;
    default:
      throw `unsupported event: ${event[0]}`;
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

  function pullEvent(
    this: void,
    filter?: string
  ): LuaMultiReturn<[string, ...unknown[]]>;
  function pullEventRaw(
    this: void,
    filter?: string
  ): LuaMultiReturn<[string, ...unknown[]]>;

  function queueEvent(this: void, event: string, ...args: unknown[]): void;
}
