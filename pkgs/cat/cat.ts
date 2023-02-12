// @ts-expect-error: FIXME: We're in modle scope, args isn't redeclared
const args = [...$vararg];
const file = args[0];

const exists = fs.exists(file);
if (!exists) {
  print(`File ${file} does not exist.`);

  // @ts-expect-error: Lua allows this
  return;
}

const [f] = fs.open(file, 'r');
const text = f.readAll();
f.close();

const lines = text.split('\n');
lines.forEach(print);
