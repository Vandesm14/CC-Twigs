import {
  address,
  doInstallPackage,
  getDepsForPackage,
  getLibsForPackage,
  installPackage,
  removePackage,
  updateAndRunPackage,
} from './api';

const args = [...$vararg];
const cmd = args[0];
const scope = args[1];

function ensureMngrDir() {
  if (fs.exists('.mngr')) return true;

  fs.makeDir('.mngr');
}

function ensureServerList() {
  if (fs.exists('pkgs/mngr/serverlist.txt')) return true;

  const [file] = fs.open('pkgs/mngr/serverlist.txt', 'w');
  if (!file) {
    print('Failed to create serverlist.txt');
    shell.exit();
    return;
  }

  file.write(address);
  file.close();

  print('Added default server to serverlist.txt');
}

function ensureAutorun() {
  if (fs.exists('startup.lua')) return true;

  const [file] = fs.open('startup.lua', 'w');
  if (!file) {
    print('Failed to create startup.lua');
    shell.exit();
    return;
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

function printUsage() {
  print('Usage: mngr <install|update|remove|run> <package>');
  print('Example: mngr install bgp');
  print('Example: mngr run bgp');
  print('Example: mngr run bgp/start');
  print('Example: mngr remove bgp');
}

if (cmd === 'run') {
  if (!scope) printUsage();

  updateAndRunPackage(scope);
}

if (cmd === 'install') {
  if (!scope) printUsage();

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
  if (!scope) printUsage();

  removePackage(scope);
  print(`Removed ${scope}.`);
}

if (cmd === 'list') {
  const pkgs = fs.list('pkgs').filter((pkg) => !pkg.endsWith('.lua'));
  print(`Installed packages: ${pkgs.join(', ')}`);
}

if (cmd === 'info') {
  if (!scope) printUsage();

  const obj = {
    Package: scope,
    Depends: getDepsForPackage(scope).join(',') ?? 'N/A',
    Includes: getLibsForPackage(scope).join(','),
  };

  print(
    Object.entries(obj)
      .map(([k, v]) => `${k}: ${v}`)
      .join('\n')
  );
}

if (cmd === 'check') {
  // TODO: Implement checking for updates
  print('NOPE, not yet implemented');
}

if (cmd === 'help' || !cmd) printUsage();

export {};
