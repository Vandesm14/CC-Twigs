import {
  clearScreenDown,
  cursorTo,
} from 'https://deno.land/std@0.177.0/node/readline.ts';
import { readline } from 'https://deno.land/x/readline@v1.1.0/mod.ts';

const existsSync = (path: string) => {
  try {
    Deno.statSync(path);
    return true;
  } catch {
    return false;
  }
};

// Define the path to the JSON file
const jsonPath = './logs.json';

// Check if the JSON file exists
if (!existsSync(jsonPath)) {
  console.log(`JSON file not found at ${jsonPath}`);
  Deno.exit();
}

// Read the JSON file and convert it into a table with all possible keys
const jsonData = JSON.parse(Deno.readTextFileSync(jsonPath));
const allKeys = new Set();
for (const obj of jsonData) {
  const keys = Object.keys(obj);
  for (const key of keys) {
    allKeys.add(key);
    if (typeof obj[key] === 'object' && obj[key] !== null) {
      const nestedKeys = Object.keys(obj[key]).map(
        (nestedKey) => `${key}.${nestedKey}`
      );
      nestedKeys.forEach((nestedKey) => allKeys.add(nestedKey));
    }
  }
}
const table = Array.from(allKeys).map((key) => ({ key }));

// Define a helper function to filter the data based on user input
function filterData(data: typeof table, input?: string) {
  // This function will be implemented later when a query language is defined
  return data;
}

// Start the interactive editor
let filteredData = jsonData;

// @ts-expect-error
clearScreenDown(Deno.stdout);

while (true) {
  // @ts-expect-error
  cursorTo(Deno.stdout, 0, 0);
  console.log(`Table: allKeys\n\n${JSON.stringify(table, null, 2)}`);
  console.log('\nEnter a filter below:');
  const iterator = readline(Deno.stdin);
  const result = await iterator.next();
  const text: string = result.value;
  if (text === null) break;
  if (text.trim().toLowerCase() === 'exit') break;
  filteredData = filterData(jsonData, text.trim());
}
