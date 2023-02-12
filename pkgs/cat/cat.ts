// @ts-expect-error: FIXME: We're in modle scope, args isn't redeclared
const args = [...$vararg];
const file = args[0];

const exists = fs.exists(file);
if (!exists) {
  print(`File ${file} does not exist.`);

  // @ts-expect-error: Lua allows this
  return;
}

const [f, err] = fs.open(file, 'r');

if (err) {
  print(`Failed to open file ${file}: ${err}`);

  // @ts-expect-error: Lua allows this
  return;
}

const text = f.readAll();
f.close();

const lines = text.split('\n');
lines.forEach((str) => print(str));
