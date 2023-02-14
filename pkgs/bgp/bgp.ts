import {
  displayIPMessage,
  getPeripheralState,
  openPorts,
  sendRawBGP,
  sendRawIP,
  State,
} from './api';
import { TIMEOUT } from './constants';
import {
  clearDB,
  createDBIfNotExists,
  getDBEntry,
  getDBEntrySide,
  printDB,
  pruneTTLs,
  updateDBEntry,
} from './db';
import { generateRandomHash, sleepUntil } from './lib';
import { BGPMessageType, BGPPropagateMessage, ModemMessage } from './types';

const BGP_PORT = 179;
const computerID = os.getComputerID();

const history: string[] = [];

/** Broadcasts or forwards a BGP propagation message */
function broadcastBGPPropagate(
  {
    modemSides,
    wirelessModemSides,
  }: Pick<State, 'modemSides' | 'wirelessModemSides'>,
  previous?: BGPPropagateMessage,
  side?: string
) {
  const message: BGPPropagateMessage = {
    // Generate a new ID if this is a new message
    id: previous?.id ?? generateRandomHash(),
    type: BGPMessageType.PROPAGATE,
    from: computerID,
    origin: previous?.origin ?? computerID,
    neighbors: previous?.neighbors
      ? Array.from(
          new Set([
            // Add the previous neighbors to the list
            ...previous.neighbors,
            // Add our computer ID to the list
            computerID,
          ])
        )
      : [computerID],
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

  if (previous?.neighbors) {
    // Run through each neighbor and update the destination to the previous.from (where the message came from)
    // so we know where to send the message to for each destination
    Object.values(previous.neighbors).forEach((neighbor) => {
      // Only update the DB if the neighbor is not us
      // if (neighbor !== computerID) updateDBEntry(neighbor, previous.from);
      if (neighbor !== computerID)
        updateDBEntry({
          destination: neighbor,
          via: previous.from,
          side,
        });
    });
  }

  // Add the message to the history
  history.push(message.id);
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
  const { message, side } = event;

  const propagateMessage = message as BGPPropagateMessage;
  const isInHistory = history.includes(propagateMessage.id);

  history.push(propagateMessage.id);

  if (!isInHistory) {
    // If we haven't seen this message before,
    // broadcast it to all of the neighbors
    broadcastBGPPropagate(state, propagateMessage, side);
  }
}

function handleIPMessage(
  state: Pick<State, 'modemSides' | 'wirelessModemSides'>,
  event: ModemMessage
) {
  const { message, channel } = event;

  const entry = getDBEntry(message.to);
  const via =
    entry && Object.keys(entry).length > 0 ? Object.keys(entry)[0] : null;
  let side = getDBEntrySide(message.to);

  if (message.to === computerID) {
    // TODO: when we have custom events, we should emit an event here
    // this is when we receive a message for us
    displayIPMessage(message);
    return;
  } else if (via && side) {
    print(`Received IP Message: ${message.id} (sending to ${via})`);

    const sides = Array.from(
      new Set([
        ...state.modemSides.filter((side) => side !== event.side),
        ...state.wirelessModemSides,
      ])
    );

    sides.forEach((modemSide) => {
      sendRawIP(message, channel, modemSide);
    });
  } else {
    // TODO: Back to sender
    print(`Received IP Message: ${message.id} (no route)`);
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
  let epochTimeout = os.epoch('utc') + TIMEOUT;

  const handlePeripheralChange = () => {
    print('Peripherals changed, refreshing...');
    state = getPeripheralState();
    openPorts(state);

    // If a port is removed, we need to clear the DB
    // because the data is no longer valid
    clearDB();
  };

  print('Starting BGP loop...');

  while (true) {
    let event: ModemMessage | null;

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
        epochTimeout = os.epoch('utc') + TIMEOUT;
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

    printDB(true);
  }
}

main();
