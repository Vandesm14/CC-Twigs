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
import { sleepUntil } from './lib';
import { BGPMessage, IPMessage, ModemMessage } from './types';

const BGP_PORT = 179;
const computerID = os.getComputerID();

let textBelow = '';

/** Broadcasts or forwards a BGP propagation message */
function broadcastBGPPropagate(
  {
    modemSides,
    wirelessModemSides,
  }: Pick<State, 'modemSides' | 'wirelessModemSides'>,
  previous?: BGPMessage,
  side?: string
) {
  const message: BGPMessage = {
    trace: trace(previous?.trace).addSelf(),
    hardwired: modemSides.length > wirelessModemSides.length,
  };

  // Filter out the sides that we've already sent the message to or seen the message from
  const sidesToSendTo = Array.from(
    new Set([
      ...modemSides.filter((modemSide) => modemSide !== side),

      // We are using a trick to get neighbors for LAN modems,
      // we can't use that trick for wireless modems, so we
      // always have to relay to wireless modems
      ...wirelessModemSides,
    ])
  );

  sidesToSendTo.forEach((modemSide) => {
    // Send a BGP message
    sendRawBGP(message, modemSide);
  });
}

/** Waits for a `modem_message` OS event, then returns the message */
function waitForMessage(this: void): ModemMessage {
  const [event, side, channel, replyChannel, rawMessage] =
    os.pullEvent('modem_message');

  const message = rawMessage;
  return {
    event,
    side,
    channel,
    replyChannel,
    message,
  };
}

function waitForPeripheralAdd(this: void) {
  os.pullEvent('peripheral');
}

function waitForPeripheralRemove(this: void) {
  os.pullEvent('peripheral_detach');
}

function handleBGPMessage(
  state: Pick<State, 'modemSides' | 'wirelessModemSides'>,
  event: ModemMessage
) {
  const { side } = event;
  const message = event.message as BGPMessage;
  const messageTrace = trace(message.trace);

  const propagateMessage = message as BGPMessage;
  const hasSeen = messageTrace.hasSeen();
  const from = messageTrace.from();

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
    if (destination !== computerID && via) {
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
  state: Pick<State, 'modemSides' | 'wirelessModemSides'>,
  event: ModemMessage
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
    messageTrace.size() > 1 ? messageTrace.from() !== computerID : false;

  const hasSeen = messageTrace.hasSeen();

  if (hasSeen || messageTrace.isEmpty() || notForUs) {
    // If we've seen this message before, ignore it
    return;
  }

  const route = findShortestRoute(message.to);
  const via = route?.via;
  const side = route?.side;

  if (ipMessage.to === computerID) {
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
        ...state.modemSides.filter((side) => side !== event.side),
        ...state.wirelessModemSides,
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
  state: Pick<State, 'modemSides' | 'wirelessModemSides'>,
  event: ModemMessage
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
  let epochTimeout = os.epoch() + TIMEOUT;

  const handlePeripheralChange = () => {
    print('Peripherals changed, refreshing...');
    state = getPeripheralState();
    openPorts(state);

    // If a port is removed, we need to clear the DB
    // because the data is no longer valid
    clearDB();
  };

  print('Starting BGP loop...');
  broadcastBGPPropagate(state);

  while (true) {
    let event: ModemMessage | null = null;

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
        sleepUntil(epochTimeout);
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
