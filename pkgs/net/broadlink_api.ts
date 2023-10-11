/** The unique broadlink protocol ID. */
export const pid = 1036;

/** Sends a broadlink frame. */
export function send<T>(this: void, data: T): void {
  os.queueEvent('modem_message', undefined, pid, pid, [
    pid,
    os.getComputerID(),
    data,
  ]);
}

export default { pid, send };
