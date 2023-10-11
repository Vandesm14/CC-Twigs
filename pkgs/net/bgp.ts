import broadlink from './broadlink_api';

/** The heartbeat interval in milliseconds.  */
const HEARTBEAT_INTERVAL = 5000;
/** The time-to-live interval in milliseconds.  */
const TIME_TO_LIVE_INTERVAL = HEARTBEAT_INTERVAL + 2000;
/** The BGP routes table file path. */
const BGP_ROUTES_TABLE_PATH = '.mngr/data/bgp/route_table.json';
const COMPUTER_ID = os.getComputerID();

let pingTimerId: number | undefined;
let heartbeatTimerId: number | undefined;

let seenSources: number[] = [];
let routes: BGPRoute[] = [];

let logs: string[] = [];

export const pid = 7312;

export const enum Locale {
    /** Relative to in-game time. */
    InGame = 'ingame',
    /** Relative to UTC. */
    Utc = 'utc',
    /** Relative to the user's local time. */
    Local = 'local',
}

/**
 * Returns the duration in milliseconds since the epoch for `locale`.
 *
 * This converts in-game milliseconds into real-world milliseconds.
 *
 * @param locale The locale to get the epoch for.
 */
export function epoch(this: void): number {
    return os.epoch() / 72;
}

export function daemon(this: void): void {
    displayRoutes();

    function handleSendPing() {
        if (pingTimerId === undefined) {
            pingTimerId = os.startTimer(HEARTBEAT_INTERVAL / 1000);
            logs.push("Adding ping timer for " + tostring(HEARTBEAT_INTERVAL / 1000) + " seconds");
        }
        if (heartbeatTimerId === undefined) {
            heartbeatTimerId = os.startTimer(TIME_TO_LIVE_INTERVAL / 1000);
            logs.push("Adding heartbeat timer for " + tostring(TIME_TO_LIVE_INTERVAL / 1000) + " seconds");
        }

        let timerId: number;
        do {
            timerId = os.pullEvent('timer')[1];

            logs.push(`Pulled timer: ${timerId} (ping ${pingTimerId}, heart ${heartbeatTimerId})`);
        } while (timerId !== pingTimerId && timerId !== heartbeatTimerId);

        switch (timerId) {
            case (pingTimerId):
                logs.push("Sending ping...");
                pingTimerId = undefined;
                broadlink.send([pid, [os.getComputerID()]]);
                break;
            case (heartbeatTimerId):
                logs.push("Pruning routes...");
                heartbeatTimerId = undefined;
                seenSources = [];
                routes = routes.filter((route) => route.ttl > epoch());
                break;
        }
    }

    function handleReceivePing() {
        const [_event, _side, _channel, _replyChannel, payload] =
            os.pullEvent('modem_message');

        if (
            !(
                type(payload) === 'table' &&
                payload[1] === pid &&
                type(payload[2]) === "table"
            )
        ) {
            return;
        }

        for (const x of payload[2]) {
            if (type(x) !== 'number') {
                return;
            }
        }

        const [_pid, trace]: [number, number[]] = payload as [number, number[]];

        if (trace.length === 0 || trace.some((id) => id === os.getComputerID())) {
            return;
        }

        for (const destination of trace) {
            const via = trace[trace.length - 1];
            const hops = routeDistance(trace, destination);

            if (destination !== COMPUTER_ID && via !== undefined) {
                updateRoute({ destination, via, hops });
            }
        }

        broadlink.send([pid, [...trace, os.getComputerID()]]);
    }

    parallel.waitForAny(handleSendPing, handleReceivePing);
}

export default { pid };

function routeDistance(this: void, trace: number[], id: number): number {
    if (id === COMPUTER_ID) return 0;
    const previous = trace[trace.length - 1];

    const inclusion = previous === COMPUTER_ID ? 2 : 1;
    return trace.length - trace.indexOf(id) - inclusion;
}

function updateRoute(route: Omit<BGPRoute, 'ttl'>) {
    const previous = routes.find(
        (r) => r.destination === route.destination && r.via === route.via
    );

    if (previous !== undefined) {
        previous.ttl = epoch() + TIME_TO_LIVE_INTERVAL;
        previous.hops = route.hops;
    } else {
        routes.push({ ...route, ttl: epoch() + TIME_TO_LIVE_INTERVAL });
    }

    saveRoutes();
}

function saveRoutes() {
    const [file] = fs.open(BGP_ROUTES_TABLE_PATH, 'w');
    file!.write(textutils.serializeJSON(routes));
    file!.close();
}

function displayRoutes() {
    const [width, height] = term.getSize();

    const uniqueDests = routes.reduce(
        (acc, val) =>
            acc.includes(val.destination) ? acc : [...acc, val.destination],
        [] as number[]
    );

    const destAndRoutes = uniqueDests
        .map((dest) => [dest, shortestRoute(dest)] as [number, BGPRoute])
        // NOTE: route can be undefined; typescript is not smart enough to type it
        .filter(([dest, route]) => route !== undefined || dest === COMPUTER_ID);

    const prettyDestAndRoutes = destAndRoutes
        .sort(([dest1, _route1], [dest2, _route2]) => dest1 - dest2)
        .map(([dest, route]) => `${dest}: ${route.via} (${route.hops})`)
        .reduce((acc, val) => {
            if (
                acc.length === 0 ||
                acc[acc.length - 1]!.length + val.length + 5 > width
            )
                acc.push('');
            acc[acc.length - 1]! += `${acc[acc.length - 1]!.length > 0 ? ', ' : ''
                }${val}`;
            return acc;
        }, [] as string[])
        .join('\n');

    term.clear();
    term.setCursorPos(1, 1);

    print(`Route Table: ${destAndRoutes.length} dest(s)`);
    print('\ndest: via (hops)');

    print(prettyDestAndRoutes);

    print('\nLogs:');
    const [_x, y] = term.getCursorPos();
    while (logs.length > height - y) logs.shift();
    for (const log of logs) {
        print(log);
    }
}

function shortestRoute(destination: number): BGPRoute | undefined {
    const destinationRoutes = routes.filter(
        ({ destination: d }) => d === destination
    );
    if (destinationRoutes.length <= 0) return undefined;

    const shortest = destinationRoutes.reduce(
        (acc, val) => (acc === undefined || val.hops < acc.hops ? val : acc),
        destinationRoutes.shift()
    );
    return shortest;
}

/** A known BGP route. */
type BGPRoute = {
    /** The destination computer. */
    destination: number;
    /** The computer that can get to the destination. */
    via: number;
    // /** The side of the peripheral that connects to the via computer. */
    // side: PeripheralName;
    /** The time-to-live for this route. */
    ttl: number;
    /**
     * The number of hops it takes to get to the destination.
     *
     * This excludes the source and destination computers from the count.
     */
    hops: number;
};

/*
Pinging:
1. Send a ping message every 15s via all modems
2. The `.trace` prop of the message includes the current computer ID (`[<sender ID>]`) initially

Receiving BGP Ping:
1. Receive a BGP ping
2. Add your own ID to the end of the trace
3. Drop pings based on:
  - If the trace includes the current computer ID
  - If the source (`trace[0]`) is undefined
4. Relay the ping via all modems if:
  - The trace does not include the current computer ID
5. Run through each ID in the trace and update the route only if:
  - The destination is not us
  - The via (`trace[-1]`) is not undefined

Receiving an IP message:
1. Drop the message based on:
  - If the trace contains our ID
  - If the trace is less than 2 (`[origin, via]`)
  - If the trace does not end with our ID
2. If the destination is our ID, "take" the message (relay to other programs or something)
3. Else, find a route to the destination
4. Find the shortest route using the routing table
5. If no route can be found, drop the message
6. Else, find the via (next hop) and the modem side to send message
7. Push the via to the trace
8. Find the modem
9. If no modem can be found, drop the message
10. Else, transmit the message

Updating a BGP route:
1. Find the previous route in the table for the destination
2. If there is a previous message, update the route
3. If not, insert one

Pruning Old Routes:
1. Filter routes that exceed the heartbeat interval
*/
