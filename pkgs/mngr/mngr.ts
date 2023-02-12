// @ts-expect-error: FIXME: We're in module scope, args isn't redeclared
const args = [...$vararg];
const cmd = args[0];
const scope = args[1];

function getServerList() {
  // read from ".mngr/serverlist.txt", a list of servers separated by newline
  const [file] = fs.open('.mngr/serverlist.txt', 'r');
  if (!file) {
    print('Failed to open serverlist.txt');
    shell.exit();
  }

  const servers = file.readAll().split('\n');
  file.close();

  return servers;
}

function ensureMngrDir() {
  if (fs.exists('.mngr')) return true;

  fs.makeDir('.mngr');
}

function ensureServerList() {
  if (fs.exists('.mngr/serverlist.txt')) return true;

  const [file] = fs.open('.mngr/serverlist.txt', 'w');
  if (!file) {
    print('Failed to create serverlist.txt');
    shell.exit();
  }

  file.write('http://mr.thedevbird.com:3000/pkgs');
  file.close();

  print('Added default server to serverlist.txt');
}

function ensureAutorun() {
  if (fs.exists('startup.lua')) return true;

  const [file] = fs.open('startup.lua', 'w');
  if (!file) {
    print('Failed to create startup.lua');
    shell.exit();
  }

  file.write(`shell.setPath(shell.path() .. ":/pkgs/")`);
  file.close();

  if (!shell.path().includes(':/pkgs/'))
    shell.setPath(shell.path() + ':/pkgs/');
}

function ensurePkgsDir() {
  if (fs.exists('pkgs')) return true;

  fs.makeDir('pkgs');
}

function ensureMngrInPkgs() {
  if (fs.exists('pkgs/mngr/mngr.lua') && fs.exists('pkgs/mngr.lua'))
    return true;

  installPackage('mngr');
  fs.delete('mngr.lua');
}

function ensureMngrSetup() {
  const success = [];

  // Ensure that the .mngr directory exists (for storing serverlist.txt and other stuff)
  success.push(ensureMngrDir());

  // Ensure that the serverlist.txt exists (for storing servers/mirrors)
  success.push(ensureServerList());

  // Ensure that the pkgs directory exists (for storing packages)
  success.push(ensurePkgsDir());

  // Ensure that the autorun.lua exists (for setting shell path to pkgs)
  success.push(ensureAutorun());

  // Ensure that mngr is in pkgs/mngr (for updating mngr; bootstrapping ftw!)
  success.push(ensureMngrInPkgs());

  if (success.includes(false)) print('Mngr setup complete!');
}

ensureMngrSetup();

function getDepsForPackage(pkg: string) {
  // TODO: Implement scanning from multiple servers ("mirrors")
  const server = getServerList()[0];

  const url = `${server}/${pkg}/needs.txt`;
  const [res] = http.get(url);
  if (typeof res === 'boolean' || !res) {
    return [];
  }

  const text = res.readAll();
  res.close();

  return text.split('\n');
}

function getLibsForPackage(pkg: string) {
  // TODO: Implement scanning from multiple servers ("mirrors")
  const server = getServerList()[0];

  const url = `${server}/${pkg}/has.txt`;
  const [res] = http.get(url);
  if (typeof res === 'boolean' || !res) {
    return [];
  }

  const text = res.readAll();
  res.close();

  return text.split('\n');
}

function downloadPackage(pkg: string, lib?: string) {
  const server = getServerList()[0];
  lib = lib ?? pkg;

  const url = `${server}/${pkg}/${lib}.lua`;
  const [res] = http.get(url);
  if (typeof res === 'boolean') {
    print(`Failed to download ${pkg}/${lib} from ${server}`);
    return;
  }

  // check if the folder pkgs/<pkg> exists
  const dirExists = fs.exists(`pkgs/${pkg}`);
  if (!dirExists) {
    fs.makeDir(`pkgs/${pkg}`);
  }

  const [file] = fs.open(`pkgs/${pkg}/${lib}.lua`, 'w');
  if (!file) {
    print(`Failed to create file for ${pkg}/${lib}`);
    return;
  }

  if (!res) {
    print(`Failed to download ${pkg}/${lib} from ${server}`);
    print(`URL: ${url}`);
    return;
  }

  file.write(res.readAll());
  file.close();
  res.close();
}

function installPackage(pkg: string) {
  const deps = getDepsForPackage(pkg);
  const libs = getLibsForPackage(pkg);

  const totals = {
    deps: deps.length,
    files: 0,
  };

  for (const dep of deps) {
    const total = installPackage(dep);
    totals.files += total.files;
    totals.deps += total.deps;
  }

  for (const lib of libs) {
    downloadPackage(pkg, lib);
    totals.files++;
  }

  downloadPackage(pkg);
  totals.files++;

  // Copy a top-level package file to the root of `pkgs/` so that it can be run
  if (fs.exists(`pkgs/${pkg}.lua`)) fs.delete(`pkgs/${pkg}.lua`);
  fs.copy(`pkgs/${pkg}/${pkg}.lua`, `pkgs/${pkg}.lua`);

  return totals;
}

function removePackage(pkg: string) {
  fs.delete(`pkgs/${pkg}`);
  fs.delete(`pkgs/${pkg}.lua`);
}

function doInstallPackage(pkg: string) {
  const total = installPackage(pkg);
  print(
    `Installed ${pkg} along with ${total.deps} deps (${total.files} total files)`
  );
}

function updateAndRunPackage(scope: string) {
  const parts = scope.split('/');

  const pkg = parts[0];
  const lib = parts.length > 1 ? parts[1] : pkg;

  doInstallPackage(pkg);

  // Runs the main package file
  shell.run(`pkgs/${pkg}/${lib}.lua`);
}

function printUsage() {
  print('Usage: mngr <install|update|remove|run> <package>');
  print('Example: mngr install bgp');
  print('Example: mngr run bgp');
  print('Example: mngr run bgp/start');
  print('Example: mngr remove bgp');
}

if (cmd === 'run') {
  if (!scope) {
    printUsage();
    shell.exit();
  }

  updateAndRunPackage(scope);
}

if (cmd === 'install') {
  if (!scope) {
    printUsage();
    shell.exit();
  }

  doInstallPackage(scope);
}

if (cmd === 'update') {
  const pkgs = scope
    ? [scope]
    : fs.list('pkgs').filter((pkg) => !pkg.endsWith('.lua'));

  print(`Updating ${pkgs.length} packages...`);
  pkgs.forEach(doInstallPackage);
}

if (cmd === 'remove') {
  if (!scope) {
    printUsage();
    shell.exit();
  }

  removePackage(scope);
  print(`Removed ${scope}.`);
}

if (cmd === 'list') {
  const pkgs = fs.list('pkgs').filter((pkg) => !pkg.endsWith('.lua'));
  print(`Installed packages: ${pkgs.join(', ')}`);
}

if (cmd === 'help' || !cmd) {
  printUsage();
  shell.exit();
}
