import { assert } from 'https://deno.land/std@0.177.0/testing/asserts.ts';

const existsSync = (path: string) => {
  try {
    Deno.statSync(path);
    return true;
  } catch {
    return false;
  }
};

const computers: Record<number, Deno.Process> = {};

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

export async function craftosRun(id: number, cmd: string, timeoutMs = 500) {
  console.log(`${id}> ${cmd}`);
  Deno.writeTextFileSync(`.craftos/computer/${id}/startup.lua`, cmd);
  const p = exec(`craftos -d .craftos -i ${id} --headless`);
  await sleep(timeoutMs);
  p.close();
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

  0: [4],
  1: [1],
  2: [1, 2],
  3: [2, 3],
  4: [3, 4],
  5: [4, 5],
  6: [5],
  7: [5],
};

const ids: number[] = Object.keys(networkedComputers).map((id) => parseInt(id));

export async function setupNetworks(network = networkedComputers) {
  const SIDES = ['top', 'bottom', 'left', 'right', 'front', 'back'];
  const commands: Record<number, string[]> = {};

  Object.entries(network).forEach(([id, networks]) => {
    const idNum = parseInt(id);
    if (!commands[idNum])
      commands[idNum] = networks.map(
        (network, i) => `shell.run("attach ${SIDES[i]} modem ${network}")`
      );
  });

  await Promise.all(
    Object.entries(commands).map(([id, cmds]) =>
      Promise.all(cmds.map((cmd) => craftosRun(parseInt(id), cmd, 1000)))
    )
  );
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
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
        'shell.run("wget run http://mr.thedevbird.com:3000/pkgs/mngr/install.lua")',
        1000
      )
    )
  );
}

export async function runBGP() {
  await Promise.all(
    ids.map((id) =>
      craftosRun(id, 'shell.run(".mngr/bin/mngr run net/bgp")', 10_000)
    )
  );
}

export async function setupAll() {
  await setupCraftos();
  await setupNetworks();
  await setupMngr();
}
