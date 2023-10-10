import { pretty_print } from "cc.pretty";

export const channel = 2782;

/** Sends a softlink {@linkcode SendFrame} via a {@linkcode ModemPeripheral}. */
export function send<T>(
    this: void,
    modem: ModemPeripheral,
    frame: SendFrame<T>,
): void {
    modem.transmit(channel, channel, {
        // 1. The source is the current computer ID.
        source: os.getComputerID(),
        // 2. The destinations are either:
        //     a. A table with zero computer IDs - broadcast.
        //     b. A table with one computer ID - unicast.
        //     c. A table with many computer IDs - multicast.
        destinations: frame.destinations,
        // 3. The data may or may not exist and can be of any type.
        data: frame.data,
    });
}

/** Receives a softlink {@linkcode RecvFrame} via the OS event queue. */
export function recv(this: void): RecvFrame<unknown> {
    let unused = [];
    let event;

    do {
        if (typeof (event) !== "undefined") {
            unused.push(event);
        }

        event = os.pullEvent("modem_message");
    } while (!isFrameForUs(event[4]));

    for (const event of unused) {
        // @ts-ignore
        os.queueEvent(...event);
    }

    // 1. The destinations must be removed for privacy.
    return { source: event[4].source, data: event[4].data };
}

/** Opens the softlink channel on a modem. */
export function open(this: void, modem: ModemPeripheral): void {
    modem.open(channel);
}

/** Closes the softlink channel on a modem. */
export function close(this: void, modem: ModemPeripheral): void {
    modem.close(channel);
}

export default { send, recv, open, close };

export type SendFrame<T> = {
    destinations: number[];
    data?: T;
};

export type RecvFrame<T> = {
    source: number;
    data?: T;
};

function isFrameForUs(this: void, frame: unknown): frame is RecvFrame<unknown> {
    if (!(
        typeof (frame) === "object"
        && frame !== null
        && "source" in frame
        // @ts-ignore-error
        && typeof (frame.source) === "number"
        && "destinations" in frame
        // @ts-ignore-error
        && typeof (frame.destinations) === "object"
    )) {
        return false;
    }

    const frame_ = frame as SendFrame<unknown> & RecvFrame<unknown>;

    if (frame_.destinations.length === 0) {
        return true;
    }

    for (const destination of frame_.destinations) {
        if (destination === os.getComputerID()) {
            return true;
        }
    }

    return false;
}
