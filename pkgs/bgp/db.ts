import { BGPDatabase, LuaArray } from './types';

const computerID = os.getComputerID();

let localDB: BGPDatabase = {};

export function createDBIfNotExists() {
  const exists = fs.exists('bgp.db');
  if (!exists) clearDB();
}

export function clearDB() {
  const [fileWrite] = fs.open('bgp.db', 'w');
  const initWith = {
    [`c_${computerID}`]: [computerID],
  };
  fileWrite.write(
    // Initialize with self
    textutils.serializeJSON(initWith)
  );
  fileWrite.close();

  localDB = initWith;
}

/** Updates the DB for which node to go via to reach a destination  */
export function updateDBEntry(destination: number, via: number) {
  let db = getDB();
  db = db ?? {};

  const destinationKey = `c_${destination}`;
  if (db[destinationKey]) {
    db[destinationKey] = Array.from(new Set([...db[destinationKey], via]));
  } else {
    db[destinationKey] = [via];
  }

  const [fileWrite] = fs.open('bgp.db', 'w');
  fileWrite.write(textutils.serializeJSON(db));
  fileWrite.close();
}

export function getDB() {
  if (Object.keys(localDB).length > 0) return localDB;
  const [fileRead] = fs.open('bgp.db', 'r');
  const text = fileRead.readAll();
  const db = textutils.unserializeJSON(text) as BGPDatabase;
  fileRead.close();

  return db;
}

export function printDB(short = false) {
  const db = getDB();

  if (Object.keys(db).length === 0) print(`DB is empty!`);

  print('BGP Router ID: ' + computerID);

  if (!short) {
    print(`DB has ${Object.keys(db).length} entries.`);
    Object.entries(db).forEach(([key, value]) => {
      print(`${key}: ${Object.values(value).join(', ')}`);
    });
  } else {
    print(`${Object.keys(db).join()}`);
  }
}

export function getDBEntry(destination: number): LuaArray<number> | null {
  const db = getDB();

  if (!db) return null;

  const entry = db[`c_${destination}`];
  return entry;
}
