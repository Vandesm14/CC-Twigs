import * as pretty from 'cc.pretty';
import os, { EventKind, ModemMessageEvent, Side } from 'cc/os';
import parallel from 'cc/parallel';
import peripheral, {
  ModemPeripheral,
  PeripheralKind,
  PeripheralName,
} from 'cc/peripheral';
import {
  BASE,
  BaseMessage,
  BGP,
  BGPMessage,
  BGP_CHANNEL,
  BGP_CHANNEL_RANGE,
  BGP_ROUTES_TABLE_PATH,
  HEARTBEAT_INTERVAL,
  TIME_TO_LIVE_INTERVAL,
} from './api';

const COMPUTER_ID = os.id();

let shouldExit = false;
let heartbeatTimeout = os.epoch() + HEARTBEAT_INTERVAL;
let routes: BGPRoute[] = [];

let logs: string[] = [];

while (!shouldExit) {
  displayRoutes();

  modems().forEach(([_name, modem]) => {
    for (let i = BGP_CHANNEL_RANGE[0]; i < BGP_CHANNEL_RANGE[1]; i++) {
      modem.open(i);
    }
  });

  parallel.waitForAny(
    // process should terminate and cleanup
    () => {
      os.event(EventKind.Terminate, true);

      modems().forEach(([_name, modem]) => {
        for (let i = BGP_CHANNEL_RANGE[0]; i < BGP_CHANNEL_RANGE[1]; i++) {
          modem.close(i);
        }
      });

      shouldExit = true;
      print('Aborting...');
    },

    // continue the loop to update modems
    () => os.event(EventKind.PeripheralAttach),
    // continue the loop to update modems
    () => os.event(EventKind.PeripheralDetach),

    // send a BGP message after the heartbeat interval elapses
    () => {
      os.sleepUntil(heartbeatTimeout);
      heartbeatTimeout = os.epoch() + HEARTBEAT_INTERVAL;

      routes = routes.filter((route) => route.ttl > os.epoch());

      broadcastBGP(modems());
    },

    // handle a modem message
    () => {
      const event = os.event(EventKind.ModemMessage);
      const { message } = event;

      if (event.channel === BGP_CHANNEL && BGP.isBGPMessage(message)) {
        // NOTE: this is to ensure type safety as typescript is not smart enough otherwise
        handleBGPMessage({ ...event, message });
      } else if (BASE.isBaseMessage(message)) {
        // NOTE: this is to ensure type safety as typescript is not smart enough otherwise
        handleBaseMessage({ ...event, message });
      }
    }
  );
}

function handleBGPMessage(event: ModemMessageEvent<BGPMessage>) {
  const source = BGP.source(event.message);

  if (source === undefined) return;

  if (!BGP.seen(event.message)) {
    broadcastBGP(modems(), event.message, event.side);
  }

  event.message.trace.forEach((destination) => {
    const via = BGP.previous(event.message);
    const hops = BGP.distance(event.message, destination);

    if (destination !== COMPUTER_ID && via !== undefined) {
      updateRoute({ destination, via, side: event.side, hops });
    }
  });
}

function handleBaseMessage(event: ModemMessageEvent<BaseMessage>) {
  if (
    BASE.seen(event.message) ||
    event.message.trace.length < 2 ||
    event.message.trace.slice(-1)[0] !== COMPUTER_ID
  ) {
    logs.push(`dropped ${pretty.render(pretty.pretty(event.message))}`);
    return;
  }

  // the base message is for us
  if (event.message.destination === COMPUTER_ID) {
    // TODO: accept the message event
    logs.push(`took ${pretty.render(pretty.pretty(event.message))}`);
    return;
  }

  // the base message is for another computer
  const route = shortestRoute(event.message.destination);
  if (route === undefined) {
    logs.push(`no route ${pretty.render(pretty.pretty(event.message))}`);
    return;
  }

  const via = route.via;
  const side = route.side;
  event.message.trace.push(via);

  const modem = modems().find(([name, _modem]) => name === side)?.[1];
  if (modem === undefined) {
    logs.push(`no modem ${pretty.render(pretty.pretty(event.message))}`);
    return;
  }

  logs.push(
    `passed ${BASE.source(event.message)} to ${BASE.destination(
      event.message
    )} via ${via}`
  );
  modem.transmit(event.channel, event.replyChannel, event.message);
}

function broadcastBGP(
  modems: [PeripheralName, ModemPeripheral][],
  previous?: BGPMessage,
  side?: Side
) {
  const message: BGPMessage = {
    trace: [...(previous?.trace ?? []), COMPUTER_ID],
  };

  // filter out the wired modem that we received the message through
  const filteredModems = modems.filter(
    ([name, modem]) => modem.isWireless() || name !== side
  );
  filteredModems.forEach(([_name, modem]) => sendRawBGP(modem, message));
}

function sendRawBGP(modem: ModemPeripheral, message: BGPMessage) {
  modem.transmit(BGP_CHANNEL, BGP_CHANNEL, message);
}

function updateRoute(route: Omit<BGPRoute, 'ttl'>) {
  const previous = routes.find(
    (r) => r.destination === route.destination && r.via === route.via
  );

  if (previous !== undefined) {
    previous.ttl = os.epoch() + TIME_TO_LIVE_INTERVAL;
    previous.hops = route.hops;
    previous.side = route.side;
  } else {
    routes.push({ ...route, ttl: os.epoch() + TIME_TO_LIVE_INTERVAL });
  }

  saveRoutes();
}

function saveRoutes() {
  const [file] = fs.open(BGP_ROUTES_TABLE_PATH, 'w');
  file!.write(textutils.serializeJSON(routes));
  file!.close();
}

function modems(): [PeripheralName, ModemPeripheral][] {
  return peripheral
    .attached()
    .filter(({ kind }) => kind === PeripheralKind.Modem)
    .map(({ name }) => [name, peripheral.wrap(name) as ModemPeripheral]);
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
      acc[acc.length - 1]! += `${
        acc[acc.length - 1]!.length > 0 ? ', ' : ''
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
  /** The side of the peripheral that connects to the via computer. */
  side: PeripheralName;
  /** The time-to-live for this route. */
  ttl: number;
  /**
   * The number of hops it takes to get to the destination.
   *
   * This excludes the source and destination computers from the count.
   */
  hops: number;
};
