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

export function printDB(short = false) {
  const db = getDB();

  if (Object.keys(db).length === 0) print(`DB is empty!`);

  if (!short) {
    print(`DB has ${Object.keys(db).length} entries.`);
    Object.entries(db).forEach(([key, value]) => {
      print(`${key}: ${Object.values(value).join(', ')}`);
    });
  } else {
    print(
      `${Object.entries(db)
        .map(([key, values]) => {
          const ids = Object.keys(values);
          const keyAsNum = parseInt(key);
          const value = parseInt(ids[0]);
          const isSame = value === keyAsNum;
          return isSame ? `${value}` : `${keyAsNum}->${value}`;
        })
        .join(', ')}`
    );
  }
}

export function getDBEntry(destination: number): BGPDestinationEntry | null {
  const db = getDB();

  if (!db) return null;

  const entry = db[destination.toString()];
  return entry;
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
