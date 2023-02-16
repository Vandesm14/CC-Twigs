import { Side } from './os';

/**
 * Returns the attached {@linkcode PeripheralName}s and their
 * {@linkcode PeripheralKind}.
 */
export function names(this: void): PeripheralNameKind[] {
  const res = [];

  const names = peripheral.getNames();
  for (let i = 0; i < names.length; i++) {
    const name = names[i]!;
    const kind = peripheral.getType(name)!;
    res.push({ name, kind });
  }

  return res;
}

/**
 * Returns all {@linkcode Peripheral}s that match the {@linkcode filter}.
 *
 * @param fitler The {@linkcode PeripheralKind} to filter by.
 */
export function find<P extends PeripheralKind>(
  this: void,
  fitler: P
): Peripheral<P>[] {
  return peripheral.find(fitler) as Peripheral<P>[];
}

/**
 * Returns a {@linkcode Peripheral} from its {@linkcode PeripheralName}.
 *
 * @param name The {@linkcode PeripheralName} to wrap.
 *
 * @throws If the {@linkcode PeripheralName} is invalid.
 */
export function wrap(this: void, name: PeripheralName): AnyPeripheral {
  const wrapped = peripheral.wrap(name);
  if (wrapped !== undefined) return wrapped;
  throw `cannot wrap "${name}" as it does not exist`;
}

/**
 * Returns the {@linkcode PeripheralKind} of a {@linkcode Peripheral}.
 *
 * @param wrapped The {@linkcode Peripheral} to get the {@linkcode PeripheralKind} of.
 *
 * @throws If the {@linkcode Peripheral} is invalid.
 */
export function type(
  this: void,
  wrapped: Peripheral<PeripheralKind>
): PeripheralKind {
  const type = peripheral.getType(wrapped);
  if (type !== undefined) return type;
  throw 'cannot get type as peripheral does not exist';
}

export default { names, find, wrap, type };

/** Represents a peripheral. */
export type Peripheral<P extends PeripheralKind> =
  P extends PeripheralKind.Command
    ? CommandBlockPeripheral
    : P extends PeripheralKind.Computer
    ? ComputerPeripheral
    : P extends PeripheralKind.Modem
    ? ModemPeripheral
    : AnyPeripheral;
/** Represents any peripheral. */
export type AnyPeripheral =
  | CommandBlockPeripheral
  | ComputerPeripheral
  | ModemPeripheral;

/** Represents a peripheral kind. */
export const enum PeripheralKind {
  /** A command block. */
  Command = 'command',
  /** A computer. */
  Computer = 'computer',
  /** A disk drive. */
  Drive = 'drive',
  /** A modem. */
  Modem = 'modem',
  /** A monitor. */
  Monitor = 'monitor',
  /** A printer. */
  Printer = 'printer',
  /** A speaker. */
  Speaker = 'speaker',
}

/** Represents a command block. */
export declare class CommandBlockPeripheral {
  /** Returns the command that will be executed. */
  getCommand(this: void): string;

  /**
   * Sets the {@linkcode command} that will be executed.
   *
   * @param command The new command.
   */
  setCommand(this: void, command: string): void;

  /** Executes the command. */
  runCommand(this: void): void;
}

/** Represents a computer. */
export declare class ComputerPeripheral {
  /** Turns on the computer immediately. */
  turnOn(this: void): void;

  /** Shuts down the computer immediately. */
  shutdown(this: void): void;

  /** Reboots the computer immediately. */
  reboot(this: void): void;

  /** Returns whether the computer is up. */
  isOn(this: void): boolean;

  /** Returns the computer ID. */
  getID(this: void): number;

  /** Returns the computer label. */
  getLabel(this: void): string | undefined;
}

/** Represents a wireless or wired modem. */
export declare class ModemPeripheral {
  /**
   * Opens a channel so that it can receive
   * {@linkcode EventKind.ModemMessage}.
   *
   * @param channel The channel to open.
   *
   * @throws If the channel is not between 0-65635.
   * @throws If there are already 128 channels open.
   */
  open(this: void, channel: number): void;

  /**
   * Closes a channel so that it can not receive
   * {@linkcode EventKind.ModemMessage}.
   *
   * @param channel The channel to close.
   *
   * @throws If the channel is not between 0-65635.
   */
  close(this: void, channel: number): void;

  /** Closes all open channels. */
  closeAll(this: void, channel: number): void;

  /**
   * Sends a {@linkcode EventKind.ModemMessage} to all attached modems with
   * {@linkcode channel} open.
   *
   * This does not require {@linkcode channel} to be open on this modem.
   *
   * @param channel The channel to send via.
   * @param replyChannel The channel to reply via.
   * @param message The message to send.
   *
   * @throws If the channel is not between 0-65635.
   */
  transmit<T>(
    this: void,
    channel: number,
    replyChannel: number,
    message: T
  ): void;

  /** Returns whether the modem is wireless. */
  isWireless(this: void): boolean;
}

/** Represents the name of a peripheral. */
export type PeripheralName = Side | `${PeripheralKind}_${number}`;

type PeripheralNameKind = { name: PeripheralName; kind: PeripheralKind };

declare module peripheral {
  function getNames(this: void): PeripheralName[];
  function getType(
    this: void,
    name: PeripheralName | Peripheral<PeripheralKind>
  ): PeripheralKind | undefined;
  function find(this: void, kind: string): LuaMultiReturn<unknown[]>;
  function wrap(
    this: void,
    name: string
  ): Peripheral<PeripheralKind> | undefined;
}
