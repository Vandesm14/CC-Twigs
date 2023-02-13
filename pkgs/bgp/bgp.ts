import { displayBGPMessage, getPeripheralState, openPorts, State } from './api';
import { TIMEOUT } from './constants';
import {
  clearDB,
  createDBIfNotExists,
  getDBEntry,
  printDB,
  updateDBEntry,
} from './db';
import { generateRandomHash, sleepUntil } from './lib';
import {
  BGPCarrierMessage,
  BGPMessage,
  BGPMessageType,
  BGPPropagateMessage,
} from './types';

const BGP_PORT = 179;
const computerID = os.getComputerID();

const history: string[] = [];

/** A small wrapper to ensure type-safety of sending a BGP message */
function sendBGPMessage(message: BGPMessage, modemSide: string) {
  const modem = peripheral.wrap(modemSide) as ModemPeripheral;

  modem.transmit(BGP_PORT, BGP_PORT, message);
}

/** Broadcasts or forwards a BGP propagation message */
function broadcastBGPPropagate(
  {
    neighbors,
    wirelessModemSides,
  }: Pick<State, 'neighbors' | 'wirelessModemSides'>,
  previous?: BGPPropagateMessage,
  side?: string
) {
  const message: BGPPropagateMessage = {
    // Generate a new ID if this is a new message
    id: previous?.id ?? generateRandomHash(),
    type: BGPMessageType.PROPAGATE,
    trace: previous?.trace
      ? [...Object.values(previous.trace), computerID]
      : [computerID],
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
  const idsToSides = Object.entries(neighbors.idsToSides);
  const sidesToSendTo = [
    ...idsToSides
      // parsingInt bc TS thinks it's a string
      .filter(([id]) => !Object.values(message.trace).includes(parseInt(id)))
      .flatMap(([_, sides]) => sides),

    // We are using a trick to get neighbors for LAN modems,
    // we can't use that trick for wireless modems, so we
    // always have to relay to wireless modems
    ...wirelessModemSides,
  ];

  if (!previous) print(`Broadcasting BGP message: ${message.id}`);

  sidesToSendTo.forEach((modemSide) => {
    // Send a BGP message
    sendBGPMessage(message, modemSide);
  });

  if (previous) {
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
function waitForMessage(this: void) {
  const [event, side, channel, replyChannel, rawMessage] =
    os.pullEvent('modem_message');

  const message = rawMessage as BGPMessage;
  return { message, side };
}

function waitForPeripheralAdd(this: void) {
  os.pullEvent('peripheral');
}

function waitForPeripheralRemove(this: void) {
  os.pullEvent('peripheral_detach');
}

/** Handles a BGP message depending on the type */
function handleBGPMessage(
  state: Pick<State, 'neighbors' | 'wirelessModemSides'>,
  message: BGPMessage,
  side: string
) {
  const { neighbors } = state;

  if (message.type === BGPMessageType.PROPAGATE) {
    const propagateMessage = message as BGPPropagateMessage;
    const isInHistory = history.includes(propagateMessage.id);

    history.push(propagateMessage.id);

    if (!isInHistory) {
      print(`Received BGP message: ${message.id}`);

      // If we haven't seen this message before,
      // broadcast it to all of the neighbors
      broadcastBGPPropagate(state, propagateMessage, side);
    } else print(`Received BGP message: ${message.id} (already seen)`);
  } else if (message.type === BGPMessageType.CARRIER) {
    const carrierMessage = message as BGPCarrierMessage;
    const entry = getDBEntry(carrierMessage.payload.to);

    const goto =
      entry && Object.keys(entry).length > 0 ? Object.keys(entry)[0] : null;

    let newMessage: BGPCarrierMessage = {
      ...carrierMessage,
      from: computerID,
      trace: [...Object.values(carrierMessage.trace), computerID],
      payload: {
        ...carrierMessage.payload,
      },
    };
    const sides = neighbors.idsToSides[goto];
    let side: string;

    if (carrierMessage.payload.to === computerID) {
      displayBGPMessage(carrierMessage);
      return;
    } else if (goto && sides && sides.length > 0) {
      print(`Received BGP carrier message: ${message.id} (sending to ${goto})`);
      side = neighbors.idsToSides[goto][0];
    } else {
      // TODO: Back to sender
      print(`Received BGP carrier message: ${message.id} (no route)`);
      const sides = neighbors.idsToSides[carrierMessage.from];

      if (!sides || sides.length === 0) {
        print('No route back to sender');
        return;
      }

      side = sides[0];
      newMessage.payload = {
        ...carrierMessage.payload,
        to: carrierMessage.payload.from,
      };
    }

    sendBGPMessage(newMessage, side);
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

  while (true) {
    let message: { message: BGPMessage; side: string } | null;

    // Ensure that all of the ports are open
    openPorts(state);

    // If either of the functions return, the other one will be cancelled
    parallel.waitForAny(
      () => {
        // Wait for a BPG message
        message = waitForMessage();
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
    if (message) {
      // Handle the message
      handleBGPMessage(state, message.message, message.side);
      message = null;
    } else {
      // If we didn't get a message, then we timed out
      // broadcast our own BGP message
      broadcastBGPPropagate(state);
    }

    printDB(true);
  }
}

main();
