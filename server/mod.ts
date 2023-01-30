import * as fs from 'https://deno.land/std@0.175.0/fs/walk.ts';
import { Server } from 'https://deno.land/std@0.175.0/http/server.ts';

const PATH = Deno.args[0] || '.';
const entries: string[] = [];

for await (const entry of fs.walk(PATH, {
  exts: ['.lua', '.txt'],
  maxDepth: 2,
})) {
  entries.push(entry.path);
}

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

  return new Response(file, {
    status: 200,
    headers: {
      'content-type': 'text/plain',
    },
  });
};

const server = new Server({ port, handler });

console.log(`Server running on port: ${port}`);
await server.listenAndServe();
