import { getModems, pluralize } from '../lib/lib';

// Get the computer's ID
const computerID = os.getComputerID();

// Use the computer ID as the BGP router ID
print('BGP Router ID: ' + computerID);

function getAllNeighbors() {
  const modemSides = getModems();
  const modems = modemSides
    // Get all of the modems
    .map((modem) => peripheral.wrap(modem) as ModemPeripheral);
  // Get all computers on the network (of the modem)
  const computerIDs: Map<string, number[]> = new Map(
    modems.map((modem, i) => [
      modemSides[i],
      modem
        .getNamesRemote()
        .filter((name) => name.startsWith('computer_'))
        .map((name) => modem.callRemote(name, 'getID') as number),
    ])
  );

  return {
    ids: Array.from(computerIDs.values()).reduce((a, b) => a.concat(b), []),
    mapOfSides: computerIDs,
  };
}

const neighbors = getAllNeighbors();

print(`Found ${neighbors.ids.length} computers on the network.`);
print(neighbors.ids.join(', '));
