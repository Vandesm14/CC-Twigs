// @ts-expect-error: FIXME: We're in module scope, args isn't redeclared
const args = [...$vararg];

const from = args[0];
const to = args[1];

const fromDir = fs.isDir(from);
const toDir = fs.isDir(to);

if (!fromDir) {
  print(`dd: cannot stat '${from}': No such file or directory`);
  shell.exit();
} else if (!toDir) {
  print(`dd: cannot stat '${to}': No such file or directory`);
  shell.exit();
}

const removeResult = shell.run(`rm ${to}`);
if (!removeResult) {
  print(`dd: failed to remove '${to}'`);
  shell.exit();
}

const copyResult = shell.run(`cp ${from} ${to}`);
if (!copyResult) {
  print(`dd: failed to copy '${from}' to '${to}'`);
  shell.exit();
}

print(`dd: copied '${from}' to '${to}'`);
