import * as fs from 'https://deno.land/std@0.175.0/fs/walk.ts';
import { Server } from 'https://deno.land/std@0.175.0/http/server.ts';

const PATH = Deno.args[0] || '.';

async function debounce(fn: () => any, time: number) {
  let timeout: number;
  return function () {
    clearTimeout(timeout);
    timeout = setTimeout(fn, time);
  };
}

async function getEntries() {
  const entries = [];
  for await (const entry of fs.walk(PATH, {
    exts: ['.lua', '.txt'],
    maxDepth: 2,
  })) {
    entries.push(entry.path);
  }
  return entries;
}

let entries: string[] = await getEntries();

const port = 3000;
const handler = (req: Request) => {
  const url = new URL(req.url);
  const path = url.pathname.slice(1);
  if (path === '') return new Response(entries.join('\n'), { status: 200 });
  if (!path || entries.every((entry) => !entry.startsWith(path)))
    return new Response('Not found', { status: 404 });

  const isDir = Deno.statSync(path).isDirectory;
  if (isDir)
    return new Response(
      entries
        .filter((entry) => entry.startsWith(path))
        .map((entry) => entry.replace(`${path}/`, ''))
        .join('\n'),
      { status: 200 }
    );

  const file = Deno.readFileSync(path);

  console.log(`Serving ${path}`);

  return new Response(file, {
    status: 200,
    headers: {
      'content-type': 'text/plain',
    },
  });
};

const server = new Server({ port, handler });

const watcher = Deno.watchFs(PATH);
const debouncer = await debounce(async () => {
  console.log('Change detected, updating entries...');
  entries = await getEntries();
}, 1000);

// Async IIFE so we can do other stuff outside of the loop
(async () => {
  for await (const event of watcher) {
    debouncer();
  }
})();

console.log(`Server running on port: ${port} (serving ${PATH})`);
server.listenAndServe();
