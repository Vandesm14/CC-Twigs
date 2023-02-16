import type { Side, ModemMessageEvent } from './os';

/** Returns all attached {@linkcode Peripheral} names and kinds. */
export function attached(
  this: void
): { name: PeripheralName; kind: PeripheralKind }[] {
  const res = [];

  const names = peripheral.getNames();
  for (let i = 0; i < names.length; i++) {
    const name = names[i]!;
    const kind = type(name)!;
    res.push({ name, kind });
  }

  return res;
}

/**
 * Returns all {@linkcode Peripheral}s that match a specified kind.
 *
 * @param fitler The {@linkcode PeripheralKind} to filter for.
 */
export function find<P extends PeripheralKind>(
  this: void,
  fitler: P
): Peripheral<P>[] {
  return peripheral.find(fitler) as Peripheral<P>[];
}

/**
 * Returns wrapped {@linkcode Peripheral} by its name.
 *
 * @param name The {@linkcode PeripheralName} to wrap.
 */
export function wrap<P extends PeripheralName>(
  this: void,
  name: P
): PeripheralByName<P> | undefined {
  return peripheral.wrap(name) as PeripheralByName<P> | undefined;
}

/**
 * Returns the kind of a {@linkcode Peripheral} or by its name.
 *
 * @param per The {@linkcode Peripheral} or {@linkcode PeripheralName} to query.
 */
// TODO: make this return the PeripheralKind if known
export function type(
  this: void,
  per: Peripheral<PeripheralKind> | PeripheralName
): PeripheralKind | undefined {
  return peripheral.getType(per);
}

export default { attached, find, wrap, type };

/** Represents a peripheral. */
export type Peripheral<P extends PeripheralKind> =
  P extends PeripheralKind.Command
    ? CommandPeripheral
    : P extends PeripheralKind.Computer
    ? ComputerPeripheral
    : P extends PeripheralKind.Modem
    ? ModemPeripheral
    : AnyPeripheral;
/** Represents any peripheral. */
export type AnyPeripheral =
  | CommandPeripheral
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

/** Represents a peripheral by name. */
export type PeripheralByName<P extends PeripheralName> =
  P extends `${PeripheralKind.Command}_${number}`
    ? CommandPeripheral
    : P extends `${PeripheralKind.Computer}_${number}`
    ? ComputerPeripheral
    : P extends `${PeripheralKind.Drive}_${number}`
    ? DrivePeripheral
    : P extends `${PeripheralKind.Modem}_${number}`
    ? ModemPeripheral
    : P extends `${PeripheralKind.Monitor}_${number}`
    ? MonitorPeripheral
    : P extends `${PeripheralKind.Printer}_${number}`
    ? PrinterPeripheral
    : P extends `${PeripheralKind.Speaker}_${number}`
    ? SpeakerPeripheral
    : AnyPeripheral;

/** Represents a peripheral kind by name. */
export type PeripheralKindByName<P extends PeripheralName> =
  P extends `${PeripheralKind.Command}_${number}`
    ? PeripheralKind.Command
    : P extends `${PeripheralKind.Computer}_${number}`
    ? PeripheralKind.Computer
    : P extends `${PeripheralKind.Drive}_${number}`
    ? PeripheralKind.Drive
    : P extends `${PeripheralKind.Modem}_${number}`
    ? PeripheralKind.Modem
    : P extends `${PeripheralKind.Monitor}_${number}`
    ? PeripheralKind.Monitor
    : P extends `${PeripheralKind.Printer}_${number}`
    ? PeripheralKind.Printer
    : P extends `${PeripheralKind.Speaker}_${number}`
    ? PeripheralKind.Speaker
    : PeripheralKind;

/** Represents the name of a peripheral. */
export type PeripheralName = Side | `${PeripheralKind}_${number}`;

/** Represents a command block. */
export declare class CommandPeripheral {
  /** Returns the command that will be executed. */
  getCommand(this: void): string;

  /**
   * Sets the command to be executed.
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
   * Opens a channel so that it can receive {@linkcode ModemMessageEvent}.
   *
   * @param channel The channel to open.
   *
   * @throws If the channel is not between 0-65635.
   * @throws If there are already 128 channels open.
   */
  open(this: void, channel: number): void;

  /**
   * Closes a channel so that it cannot receive {@linkcode ModemMessageEvent}.
   *
   * @param channel The channel to close.
   *
   * @throws If the channel is not between 0-65635.
   */
  close(this: void, channel: number): void;

  /** Closes all open channels. */
  closeAll(this: void, channel: number): void;

  /**
   * Sends a {@linkcode ModemMessageEvent} to all attached modems with the
   * specified channel open.
   *
   * This does not require the channel to be open on this modem.
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

// type PeripheralNameKind = { name: PeripheralName; kind: PeripheralKind };

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
