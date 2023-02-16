import os, { EventKind, ModemMessageEvent } from 'cc/os';
import parallel from 'cc/parallel';
import {
  formatIPMessage,
  getPeripheralState,
  openPorts,
  sendRawBGP,
  sendRawIP,
  State,
  trace,
} from './api';
import { TIMEOUT } from './constants';
import {
  clearDB,
  createDBIfNotExists,
  findShortestRoute,
  printDB,
  pruneTTLs,
  updateRoute,
} from './db';
import { BGPMessage, IPMessage } from './types';

const BGP_PORT = 179;
const COMPUTER_ID = os.id();

let textBelow = '';
let originHistory: number[] = [];

/** Broadcasts or forwards a BGP propagation message */
function broadcastBGPPropagate(
  {
    modemNames,
    wirelessModemNames,
  }: Pick<State, 'modemNames' | 'wirelessModemNames'>,
  previous?: BGPMessage,
  side?: string
) {
  const message: BGPMessage = {
    trace: trace(previous?.trace).addSelf(),
    hardwired: modemNames.length > wirelessModemNames.length,
  };

  // Filter out the sides that we've already sent the message to or seen the message from
  const namesToSendTo = Array.from(
    new Set([
      ...modemNames.filter((modemName) => modemName !== side),

      // We are using a trick to get neighbors for LAN modems,
      // we can't use that trick for wireless modems, so we
      // always have to relay to wireless modems
      ...wirelessModemNames,
    ])
  );

  namesToSendTo.forEach((modemName) => {
    // Send a BGP message
    sendRawBGP(message, modemName);
  });
}

/** Waits for a `modem_message` OS event, then returns the message */
function waitForMessage(this: void): ModemMessageEvent {
  return os.event(EventKind.ModemMessage);
}

function waitForPeripheralAdd(this: void) {
  os.event(EventKind.PeripheralAttach);
}

function waitForPeripheralRemove(this: void) {
  os.event(EventKind.PeripheralDetach);
}

function handleBGPMessage(
  state: Pick<State, 'modemNames' | 'wirelessModemNames'>,
  event: ModemMessageEvent
) {
  const { side } = event;
  const message = event.message as BGPMessage;
  const messageTrace = trace(message.trace);

  const propagateMessage = message as BGPMessage;
  const hasSeen = messageTrace.hasSeen();
  const from = messageTrace.from();

  const origin = messageTrace.origin();
  if (origin === undefined || originHistory.includes(origin)) {
    return;
  }

  originHistory.push(origin);

  if (!hasSeen) {
    // If we haven't seen this message before,
    // broadcast it to all of the neighbors
    broadcastBGPPropagate(state, propagateMessage, side);
  }

  // Run through each of the ids in the trace
  // stop at the last one, because that is the one that sent us the message.
  // We can use trace().distance(destination) to get the number of hops to the destination
  message.trace.forEach((id, index) => {
    const destination = id;
    const via = from;

    const hops = messageTrace.distance(destination);

    // Only update the DB if the neighbor is not us
    if (destination !== COMPUTER_ID && via) {
      updateRoute({
        destination,
        via,
        side,
        hops,
      });
    }
  });
}

function handleIPMessage(
  state: Pick<State, 'modemNames' | 'wirelessModemNames'>,
  event: ModemMessageEvent
) {
  const { channel } = event;
  const message = event.message as IPMessage;
  const ipMessage = message as IPMessage;
  const messageTrace = trace(ipMessage.trace);

  // When an IP message is sent, it will usually have the immediate
  // destination as the last entry in the trace.
  // If the destination is us, then we will handle it.
  // If the IP message was broadcasted, that is,
  // without an immediate destination, then we will handle it.
  const notForUs =
    messageTrace.size() > 1 ? messageTrace.from() !== COMPUTER_ID : false;

  const hasSeen = messageTrace.hasSeen();

  if (hasSeen || messageTrace.isEmpty() || notForUs) {
    // If we've seen this message before, ignore it
    return;
  }

  const route = findShortestRoute(message.to);
  const via = route?.via;
  const side = route?.side;

  if (ipMessage.to === COMPUTER_ID) {
    // TODO: when we have custom events, we should emit an event here
    textBelow = formatIPMessage(ipMessage);
    printDB({
      below: textBelow,
    });
  } else if (via && side) {
    textBelow = `Received IP Message from ${message.from} -> ${message.to} via ${via}`;
    printDB({
      below: textBelow,
    });

    let newMessage = {
      ...ipMessage,
      trace: trace(ipMessage.trace).add([via]),
    };

    const sides = Array.from(
      new Set([
        ...state.modemNames.filter((side) => side !== event.side),
        ...state.wirelessModemNames,
      ])
    );

    sides.forEach((modemSide) => {
      sendRawIP(newMessage, channel, modemSide);
    });
  } else {
    // TODO: Back to sender
    textBelow = `Received IP Message from ${message.from} -> ${message.to} (no route)`;
    printDB({
      below: textBelow,
    });
  }
}

/** Handles a BGP message depending on the type */
function handleMessageEvent(
  state: Pick<State, 'modemNames' | 'wirelessModemNames'>,
  event: ModemMessageEvent
) {
  if (event.channel === BGP_PORT) {
    handleBGPMessage(state, event);
  } else {
    handleIPMessage(state, event);
  }
}

function main() {
  createDBIfNotExists();
  clearDB();

  // Timeout to wait for a message (real-world BGP uses 30 seconds)
  let state: State = getPeripheralState();

  // Initialize the timeout to now so we trigger immediately
  let epochTimeout = os.epoch();

  const handlePeripheralChange = () => {
    print('Peripherals changed, refreshing...');
    state = getPeripheralState();
    openPorts(state);

    // If a modem is removed, we need to clear the DB
    // because the data is no longer valid
    clearDB();
  };

  print('Starting BGP loop...');
  broadcastBGPPropagate(state);

  while (true) {
    let event: ModemMessageEvent | null = null;

    // Ensure that all of the ports are open
    openPorts(state);

    // If either of the functions return, the other one will be cancelled
    parallel.waitForAny(
      () => {
        // Wait for a modem message
        event = waitForMessage();
      },
      () => {
        // Wait for `TIMEOUT` seconds
        os.sleepUntil(epochTimeout);
        epochTimeout = os.epoch() + TIMEOUT;
      },
      () => {
        // Wait for a peripheral to be added
        waitForPeripheralAdd();
        handlePeripheralChange();
      },
      () => {
        // Wait for a peripheral to be removed
        waitForPeripheralRemove();
        handlePeripheralChange();
      }
    );

    // If we got a message, handle it
    if (event) {
      // Handle the message
      handleMessageEvent(state, event);
      event = null;
    } else {
      pruneTTLs();
      originHistory = [];

      // If we didn't get a message, then we timed out
      // broadcast our own BGP message
      broadcastBGPPropagate(state);
    }

    printDB({
      below: textBelow,
    });
  }
}

main();
