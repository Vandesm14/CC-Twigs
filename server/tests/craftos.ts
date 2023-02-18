import * as io from 'https://deno.land/std@0.177.0/io/mod.ts';

const TIMEOUT_MS = 2_000;

const stripAnsi = (str: string) =>
  str.replace(/\x1b\[[0-9;]*m/g, '').replace(/\x1b\[[0-9;]*K/g, '');

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

export async function craftosRun(id: number, cmd: string) {
  console.log(`${id}: ${cmd}`);

  // Start the CraftOS process for the specified ID
  const p = Deno.run({
    cmd: [
      'craftos',
      '-d',
      `.craftos/computer/${id}`,
      '-i',
      id.toString(),
      '--cli',
    ],
    stdout: 'piped',
    stdin: 'piped',
  });

  try {
    // Write the command to the process's stdin
    await p.stdin.write(new TextEncoder().encode(`${cmd}\n`));

    // Read the output from the process's stdout
    const reader = io.readLines(p.stdout);
    const lines: string[] = [];

    while (true) {
      const line = await Promise.race([
        reader.next(),
        sleep(TIMEOUT_MS).then(() => null),
      ]);

      if (!line) {
        console.log(`Timeout: ${cmd}`);
        break;
      }

      const value = line.value;

      lines.push(stripAnsi(value));
      console.log(`${id}: ${stripAnsi(value)}`);
    }

    // Write the output to a file
    Deno.writeTextFileSync(`${id}.log`, lines.join('\n'));
  } catch (err) {
    console.error(err);
  } finally {
    // Clean up the process
    p.stdout.close();
    p.stdin.close();
    p.close();
  }
}

craftosRun(0, 'ls');
