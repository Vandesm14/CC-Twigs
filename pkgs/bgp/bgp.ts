import { pretty_print } from 'cc.pretty';
import { getModems } from '../lib/lib';

const BGP_PORT = 179;

// Get the computer's ID
const computerID = os.getComputerID();

// Use the computer ID as the BGP router ID
print('BGP Router ID: ' + computerID);

function getLocalNeighbors() {
  const modemSides = getModems();
  const modems = modemSides
    // Get all of the modems
    .map((modem) => peripheral.wrap(modem) as ModemPeripheral);
  // Get all computers on the network (of the modem)
  const computerIDs: Map<string, number[]> = new Map(
    modems.map((modem, i) => [
      modemSides[i],
      modem.getNamesRemote
        ? modem
            .getNamesRemote()
            .filter((name) => name.startsWith('computer_'))
            .map((name) => modem.callRemote(name, 'getID') as number)
        : [],
    ])
  );

  return {
    ids: Array.from(computerIDs.values()).reduce((a, b) => a.concat(b), []),
    mapOfSides: computerIDs,
  };
}

interface BGPMessage {
  // The type of message
  type: 'seek';

  // The historical path of the message
  trace: Record<number, number>;

  // The ID of the computer that sent the message
  from: number;

  // The ID of the computer that originally sent the message (the first computer)
  origin: number;
}

function tryParseNumber(value: string) {
  const num = Number(value);
  if (isNaN(num)) return value;
  return num;
}

function sendBGPMessage(message: BGPMessage, modemSide: string) {
  const modem = peripheral.wrap(modemSide) as ModemPeripheral;
  modem.transmit(BGP_PORT, BGP_PORT, message);
}

const neighbors = getLocalNeighbors();

print(`Found ${neighbors.ids.length} nodes on local network.`);

const modemSides = getModems();
const modems = modemSides.map(
  (modem) => peripheral.wrap(modem) as ModemPeripheral
);

function openPorts() {
  modems.forEach((modem) => modem.open(BGP_PORT));
}

function closePorts() {
  modems.forEach((modem) => modem.close(BGP_PORT));
}

function broadcastBGP(previous?: BGPMessage) {
  modemSides.forEach((modemSide) => {
    // Send a BGP message
    const message: BGPMessage = {
      type: 'seek',
      trace: previous?.trace
        ? [...Object.values(previous.trace), computerID]
        : [computerID],
      from: computerID,
      origin: previous?.origin ?? computerID,
    };

    sendBGPMessage(message, modemSide);
  });
}

function waitForMessage(this: void) {
  const [event, side, channel, replyChannel, rawMessage] =
    os.pullEvent('modem_message');

  const message = rawMessage as BGPMessage;

  pretty_print(message);

  if (message.type === 'seek') {
    // If the message has already been seen, ignore it
    if (Object.values(message.trace).includes(computerID)) {
      print('Message already seen, ignoring...');
      return;
    }

    print(`Received BGP message from ${message.from}, forwarding...`);

    // Else, broadcast it to all of the neighbors
    broadcastBGP(message);
  }
}

function main() {
  // open the ports
  openPorts();
  print('Ports open');

  // broadcast the BGP message
  broadcastBGP();
  print('BGP message broadcasted');

  while (true) {
    waitForMessage();
  }
}

main();
