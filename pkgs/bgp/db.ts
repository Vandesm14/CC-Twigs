import { TTL } from './constants';
import { BGPDatabase, BGPDestinationEntry } from './types';

let localDB: BGPDatabase = {};

const DB_PATH = 'pkgs/bgp/bgp.db';

export function createDBIfNotExists() {
  const exists = fs.exists(DB_PATH);
  if (!exists) clearDB();
}

export function clearDB() {
  const [fileWrite] = fs.open(DB_PATH, 'w');
  // TODO: Find a better way to initialize with self
  // Currently, we need a side and a TTL, which we don't have
  const initWith = {};
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
export function updateDBEntry({
  destination,
  via,
  side,
}: {
  destination: number;
  via: number;
  side: string;
}) {
  let db = getDB();
  db = db ?? {};

  const destinationKey = destination.toString();
  const viaKey = via.toString();
  db[destinationKey] = {
    ...(db[destinationKey] ?? {}),
    [viaKey]: {
      side,
      ttl: os.epoch('utc') + TTL,
    },
  };

  saveDB(db);
}

export function getDB() {
  if (Object.keys(localDB).length > 0) return localDB;
  const [fileRead] = fs.open(DB_PATH, 'r');
  const text = fileRead.readAll();
  const db = textutils.unserializeJSON(text) as BGPDatabase;
  fileRead.close();

  return db;
}

let lastPrint = '';
export function printDB(short = false) {
  const db = getDB();

  if (Object.keys(db).length === 0) print(`DB is empty!`);

  if (!short) {
    print(`DB has ${Object.keys(db).length} entries.`);
    let toPrint = Object.entries(db)
      .sort(([a], [b]) => (a < b ? -1 : 1))
      .map(([key, values]) => `${key}: ${Object.values(values).join(', ')}`)
      .join('\n');

    if (toPrint === lastPrint) return;
    lastPrint = toPrint;

    print(toPrint);
  } else {
    let toPrint = `${Object.entries(db)
      .sort(([a], [b]) => (a < b ? -1 : 1))
      .map(([key, values]) => {
        const ids = Object.keys(values);
        const keyAsNum = parseInt(key);
        const value = ids
          .map((id) => parseInt(id))
          .sort()
          .join(' or ');
        const isSame = ids.length > 1 ? false : parseInt(ids[0]) === keyAsNum;

        return isSame ? `${value}` : `${keyAsNum} via ${value}`;
      })
      .join(', ')}`;

    if (toPrint === lastPrint) return;
    lastPrint = toPrint;

    print(toPrint);
  }
}

export function getDBEntry(destination: number): BGPDestinationEntry | null {
  const db = getDB();

  if (!db) return null;

  const entry = db[destination.toString()];
  return entry;
}

export function getDBEntrySide(destination: number): string | null {
  const entry = getDBEntry(destination);
  if (!entry) return null;

  const via = Object.values(entry)[0];
  return via.side;
}

export function pruneTTLs() {
  const db = getDB();
  const now = os.epoch('utc');

  const pruned = Object.entries(db).reduce((acc, [key, value]) => {
    const prunedValues = Object.entries(value).reduce((acc, [key, value]) => {
      if (value.ttl > now) {
        acc[key] = value;
      }
      return acc;
    }, {} as BGPDestinationEntry);

    if (Object.keys(prunedValues).length > 0) {
      acc[key] = prunedValues;
    }

    return acc;
  }, {} as BGPDatabase);

  saveDB(pruned);
}
