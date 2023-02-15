import { epoch } from 'time/time';
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
  if (!fileWrite) throw new Error('DB file not found');
  // TODO: Find a better way to initialize with self
  // Currently, we need a side and a TTL, which we don't have
  const initWith: BGPDatabase = [];
  fileWrite.write(
    // Initialize with self
    textutils.serializeJSON(initWith)
  );
  fileWrite.close();

  localDB = initWith;
}

export function saveDB(db: BGPDatabase) {
  const [fileWrite] = fs.open(DB_PATH, 'w');
  if (!fileWrite) throw new Error('DB file not found');
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
    existing.ttl = epoch() + TTL;
    existing.hops = hops;
    existing.side = side;
  } else {
    db.push({
      destination,
      via,
      side,
      ttl: epoch() + TTL,
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
  if (!records || records.length === 0) return null;

  const smallest = records.reduce<BGPDatabaseRecord | null>((acc, value) => {
    if (!acc) return value;
    if (value.hops < acc.hops) return value;
    return acc;
  }, null);

  return smallest;
}

export function getDB() {
  if (localDB.length > 0) return localDB;
  const [fileRead] = fs.open(DB_PATH, 'r');
  if (!fileRead) throw new Error('DB file not found');

  const text = fileRead.readAll();
  const db = textutils.unserializeJSON(text) as BGPDatabase;
  fileRead.close();

  return db;
}

let lastPrint = '';
export function printDB(text?: { above?: string; below?: string }) {
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

  let toPrint = `${text?.above ? text.above + '\n' : ''}DB: ${
    pairs.length
  } dests\ndest: via (hops)\n${chunkArray(
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
    .join('\n')}${text?.below ? '\n' + text.below : ''}`;
  if (toPrint === lastPrint) return;

  term.clear();
  term.setCursorPos(1, 1);

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
  const now = epoch();

  const pruned = db.filter((entry) => entry.ttl > now);

  saveDB(pruned);
}
