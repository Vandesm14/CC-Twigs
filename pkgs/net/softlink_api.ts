/** Sends a frame with the softlink protocol. */
export function send<T>(
    this: void,
    side: Side,
    destinations: number[],
    data: T,
): void {
    os.queueEvent("softlink_send", side, destinations, data);
}

/**
    Receives a frame with the softlink protocol.

    This pauses execution on the current thread and waits for a softlink receive
    event.
*/
export function receive(this: void): FrameEvent<unknown> {
    const event = os.pullEvent("softlink_receive");
    return $multi(event[1], event[2], event[3]);
}

export default { send, receive };

export type FrameEvent<T> = LuaMultiReturn<[Side, number, T]>;

type Side = "top" | "bottom" | "left" | "right" | "front" | "back";