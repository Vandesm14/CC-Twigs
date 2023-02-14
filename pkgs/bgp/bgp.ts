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
import { luaArray, sleepUntil } from './lib';
import { BGPMessage, IPMessage, ModemMessage } from './types';

const BGP_PORT = 179;
const computerID = os.getComputerID();

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
    trace: previous?.trace
      ? [...luaArray(previous.trace), computerID]
      : [computerID],
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

  const propagateMessage = message as BGPMessage;
  const hasSeen = luaArray(propagateMessage.trace)?.includes(computerID);

  if (!hasSeen) {
    // If we haven't seen this message before,
    // broadcast it to all of the neighbors
    broadcastBGPPropagate(state, propagateMessage, side);
  }

  if (propagateMessage?.neighbors) {
    luaArray(propagateMessage.neighbors).forEach((neighbor) => {
      // Only update the DB if the neighbor is not us
      if (
        neighbor !== computerID &&
        luaArray(propagateMessage?.trace).length > 0
      ) {
        updateDBEntry({
          destination: neighbor,
          via: luaArray(propagateMessage.trace).slice(-1)[0],
          side,
        });
      }
    });
  }
}

function handleIPMessage(
  state: Pick<State, 'modemSides' | 'wirelessModemSides'>,
  event: ModemMessage
) {
  const { message, channel } = event;
  const ipMessage = message as IPMessage;

  const hasSeen = luaArray(ipMessage.trace)?.includes(computerID);
  if (hasSeen) {
    // If we've seen this message before, ignore it
    return;
  }

  const entry = getDBEntry(message.to);
  const via =
    entry && Object.keys(entry).length > 0 ? Object.keys(entry)[0] : null;
  let side = getDBEntrySide(message.to);

  if (ipMessage.to === computerID) {
    // TODO: when we have custom events, we should emit an event here
    // this is when we receive a message for us
    displayIPMessage(ipMessage);
    return;
  } else if (via && side) {
    print(
      `Received IP Message from ${message.from} -> ${message.to} via ${via}`
    );

    let newMessage = {
      ...ipMessage,
      trace: [...luaArray(message.trace), computerID],
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
    print(
      `Received IP Message from ${message.from} -> ${message.to} (no route)`
    );
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
  broadcastBGPPropagate(state);

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
