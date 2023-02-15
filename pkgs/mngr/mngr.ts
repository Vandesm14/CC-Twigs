import {
  address,
  copyBinFiles,
  doInstallPackage,
  fetchPackage,
  listInstalledPackages,
  removePackage,
  updateAndRunPackage,
} from './api';

const args = [...$vararg];
const cmd = args[0];
const scope = args[1];

function ensureServerList() {
  if (fs.exists('.mngr/serverlist.txt')) return true;

  const [file] = fs.open('.mngr/serverlist.txt', 'w');
  if (!file) {
    print('Failed to create serverlist.txt');
    shell.exit();
    return;
  }

  file.write(address);
  file.close();

  print('Added default server to serverlist.txt');
}

function ensurePathOnStartup() {
  if (fs.exists('startup.lua')) return true;

  const [file] = fs.open('startup.lua', 'w');
  if (!file) {
    print('Failed to create startup.lua');
    shell.exit();
    return;
  }

  file.write(`shell.setPath(shell.path() .. ":/.mngr/bin/")`);
  file.close();

  if (!shell.path().includes(':/.mngr/bin/'))
    shell.setPath(shell.path() + ':/.mngr/bin/');
}

function ensureMngrSetup() {
  const success = [];

  // Ensure that the serverlist.txt exists (for storing servers/mirrors)
  success.push(ensureServerList());

  // Ensure that the autorun.lua exists (for setting shell path to mngr bin)
  success.push(ensurePathOnStartup());

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
  // If no argument, update all packages
  const pkgs = scope ? [scope] : listInstalledPackages();

  print(`Updating ${pkgs.length} packages...`);
  pkgs.forEach(doInstallPackage);
}

if (cmd === 'remove') {
  if (!scope) printUsage();

  removePackage(scope);
  print(`Removed ${scope}.`);
}

if (cmd === 'list') {
  const pkgs = listInstalledPackages();
  print(`Installed packages: ${pkgs.join(', ')}`);
}

if (cmd === 'info') {
  if (!scope) printUsage();
  const { deps, files } = fetchPackage(scope);

  const obj = {
    Package: scope,
    Depends: deps.join(', '),
    Includes: files.join(', '),
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

if (cmd === 'copy-bin') {
  copyBinFiles();
  print('Copied all bin files to .mngr/bin/*');
}

if (cmd === 'help' || !cmd) printUsage();

export {};
