/** The unique unilink protocol ID. */
export const pid = 1035;

/** Sends a unicast frame. */
export function send<T>(this: void, destination: number, data: T): void {
  os.queueEvent('modem_message', undefined, pid, pid, [
    pid,
    os.getComputerID(),
    destination,
    data,
  ]);
}

export default { pid, send };
