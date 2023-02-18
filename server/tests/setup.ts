import * as io from 'https://deno.land/std@0.177.0/io/mod.ts';
import { assert } from 'https://deno.land/std@0.177.0/testing/asserts.ts';

const existsSync = (path: string) => {
  try {
    Deno.statSync(path);
    return true;
  } catch {
    return false;
  }
};

const stripAnsi = (str: string) =>
  str.replace(/\x1b\[[0-9;]*m/g, '').replace(/\x1b\[[0-9;]*K/g, '');

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

const computers: Record<
  number,
  Deno.Process<{
    cmd: string[];
    stdout: 'piped';
    stdin: 'piped';
  }>
> = {};

export function startComputer(id: number) {
  const p = Deno.run({
    cmd: ['craftos', '-d', '.craftos', '-i', id.toString(), '--cli'],
    stdout: 'piped',
    stdin: 'piped',
  });

  computers[id] = p;
}

export function exec(cmd: string): Deno.Process {
  console.log(`$ ${cmd}`);

  const p = Deno.run({
    cmd: cmd.split(' '),
    stdout: 'piped',
    stdin: 'piped',
  });

  return p;
}

export async function assertExec(cmd: string) {
  const p = exec(cmd);

  const { code, success } = await p.status();

  assert(success === true);
  assert(code === 0);
}

export async function craftosRun(id: number, cmd: string) {
  if (!computers[id]) {
    startComputer(id);
  }

  console.log(`${id}: ${cmd}`);

  const p = computers[id];
  p.stdin.write(new TextEncoder().encode(`${cmd}\n`));

  const r = io.readLines(p.stdout);
  const lines: string[] = [];

  await Promise.race([
    (async () => {
      for await (const line of r) {
        lines.push(stripAnsi(line));
        console.log(`${id}: ${stripAnsi(line)}`);
      }
    })(),
    new Promise((resolve) => {
      setTimeout(() => {
        console.log('Timeout');
        resolve(true);
      }, 1000);
    }),
  ]);

  Deno.writeTextFileSync(`${id}.log`, lines.join('\n'));
}

/** [key: ComputerID]: NetworkID[] */
const networkedComputers: Record<number, number[]> = {
  /*
    // System A
    Network 1: 1, 2
    Network 2: 2, 3
    Network 3: 3, 4

    // Wireless
    Network 4: 0, 4, 5

    // System B
    Network 5: 5, 6, 7
  */

  // 0: [4],
  // 1: [1],
  // 2: [1, 2],
  // 3: [2, 3],
  // 4: [3, 4],
  // 5: [4, 5],
  // 6: [5],
  // 7: [5],
  1: [1],
  2: [1],
};

const ids: number[] = Object.keys(networkedComputers).map((id) => parseInt(id));

export async function setupNetworks(network = networkedComputers) {
  const SIDES = ['top', 'bottom', 'left', 'right', 'front', 'back'];
  const commands: Record<number, string[]> = {};

  Object.entries(network).forEach(([id, networks]) => {
    const idNum = parseInt(id);
    if (!commands[idNum])
      commands[idNum] = networks.map(
        (network, i) => `attach ${SIDES[i]} modem ${network}`
      );
  });

  await Promise.all(
    Object.entries(commands).map(([id, cmds]) =>
      Promise.all(cmds.map((cmd) => craftosRun(parseInt(id), cmd)))
    )
  );
}

export async function setupCraftos() {
  // Remove the .craftos folder if it exists
  // and create a new one for each computer
  if (existsSync('.craftos')) {
    await Deno.remove('.craftos', { recursive: true });
  }
  await Promise.all(
    ids.map((id) => Deno.mkdir(`.craftos/computer/${id}`, { recursive: true }))
  );
}

export async function setupMngr() {
  await Promise.all(
    ids.map((id) =>
      craftosRun(
        id,
        'wget run http://mr.thedevbird.com:3000/pkgs/mngr/install.lua'
      )
    )
  );
}

export async function runBGP() {
  await Promise.all(
    ids.map((id) => craftosRun(id, '.mngr/bin/mngr run net/bgp'))
  );
}

export async function setupAll() {
  await setupCraftos();
  await setupNetworks();
  await setupMngr();
}
