import { TTL } from './constants';
import { chunkArray } from './lib';
import { BGPDatabase, BGPDatabaseRecord } from './types';

/** The ID of the computer */
const computerID = os.getComputerID();
const DB_PATH = 'pkgs/bgp/bgp.db';

let localDB: BGPDatabase = [];

export function createDBIfNotExists() {
  const exists = fs.exists(DB_PATH);
  if (!exists) clearDB();
}

export function clearDB() {
  const [fileWrite] = fs.open(DB_PATH, 'w');
  // TODO: Find a better way to initialize with self
  // Currently, we need a side and a TTL, which we don't have
  const initWith = [];
  fileWrite.write(
    // Initialize with self
    textutils.serializeJSON(initWith)
  );
  fileWrite.close();

  localDB = initWith;
}

export function saveDB(db: BGPDatabase) {
  const [fileWrite] = fs.open(DB_PATH, 'w');
  fileWrite.write(textutils.serializeJSON(db));
  fileWrite.close();

  localDB = db;
}

/** Updates the DB for which node to go via to reach a destination  */
export function updateRoute(record: Omit<BGPDatabaseRecord, 'ttl'>) {
  const { side, hops, destination, via } = record;

  let db = getDB();

  const existing = db.find(
    (record) => record.destination === destination && record.via === via
  );

  if (existing) {
    existing.ttl = os.epoch('utc') + TTL;
    existing.hops = hops;
    existing.side = side;
  } else {
    db.push({
      destination,
      via,
      side,
      ttl: os.epoch('utc') + TTL,
      hops,
    });
  }

  saveDB(db);
}

/** Finds a route to a destination with the shortest hops */
export function findShortestRoute(
  destination: number
): BGPDatabaseRecord | null {
  const records = getRoutesForDest(destination);

  const smallest = records.reduce<BGPDatabaseRecord>((acc, value) => {
    if (!acc) return value;
    if (value.hops < acc.hops) return value;
    return acc;
  }, null);

  return smallest;
}

export function getDB() {
  if (localDB.length > 0) return localDB;
  const [fileRead] = fs.open(DB_PATH, 'r');
  const text = fileRead.readAll();
  const db = textutils.unserializeJSON(text) as BGPDatabase;
  fileRead.close();

  return db;
}

let lastPrint = '';
export function printDB() {
  const db = getDB();
  if (db.length === 0) {
    print(`DB: empty`);
    return;
  }
  const destinations = Array.from(
    new Set(db.map((record) => record.destination))
  );
  const pairs: [number, BGPDatabaseRecord | null][] = destinations.map(
    (dest) => [dest, findShortestRoute(dest)]
  );

  let toPrint = `DB:\n${chunkArray(
    pairs
      .sort(([a], [b]) => a - b)
      .map(([dest, record]) => {
        if (!record) return `${dest}: null`;
        if (computerID === record.destination)
          return `${dest}: self (${record.hops})`;
        return `${dest}: ${record.via} (${record.hops})`;
      }),
    2
  )
    .map((chunk) => chunk.join(', '))
    .join('\n')}`;
  if (toPrint === lastPrint) return;

  lastPrint = toPrint;
  print(toPrint);
}

export function getRoutesForDest(
  destination: number
): BGPDatabaseRecord[] | null {
  const db = getDB();

  const records = db.filter((entry) => entry.destination === destination);
  if (records.length === 0) return null;

  return records;
}

export function pruneTTLs() {
  const db = getDB();
  const now = os.epoch('utc');

  const pruned = db.filter((entry) => entry.ttl > now);

  saveDB(pruned);
}
