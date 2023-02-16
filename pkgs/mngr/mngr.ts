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

function ensureServerList(): boolean {
  if (fs.exists('.mngr/serverlist.txt')) return true;

  const [file] = fs.open('.mngr/serverlist.txt', 'w');
  if (!file) {
    print('Failed to create serverlist.txt');
    shell.exit();
    return false;
  }

  file.write(address);
  file.close();

  print('Added default server to serverlist.txt');
  return true;
}

function ensurePathOnStartup(): boolean {
  if (fs.exists('startup.lua')) return true;

  const [file] = fs.open('startup.lua', 'w');
  if (!file) {
    print('Failed to create startup.lua');
    shell.exit();
    return false;
  }

  file.write(`shell.setPath(shell.path() .. ":/.mngr/bin/")`);
  file.close();

  if (!shell.path().includes(':/.mngr/bin/'))
    shell.setPath(shell.path() + ':/.mngr/bin/');
  return true;
}

function ensureMngrSetup() {
  // Ensure that the serverlist.txt exists (for storing servers/mirrors)
  // Ensure that the startup.lua exists (for setting shell path to mngr bin)
  if (!ensureServerList() || !ensurePathOnStartup())
    print('Mngr setup failure.');
}

ensureMngrSetup();

function printUsage() {
  print('Usage: mngr <install|update|remove|run> <package>');
  print('Example: mngr install bgp');
  print('Example: mngr run bgp');
  print('Example: mngr run bgp/start');
  print('Example: mngr remove bgp');
}

if (cmd === 'copy-bin') {
  copyBinFiles();
  print('Copied all bin files to .mngr/bin/*');
}

if (cmd === 'update') {
  // If no argument, update all packages
  const pkgs = scope ? [scope] : listInstalledPackages();

  print(`Updating ${pkgs.length} packages...`);
  pkgs.forEach((pkg) => doInstallPackage(pkg));
} else if (cmd === 'help' || !cmd) printUsage();

if (scope) {
  if (cmd === 'run') updateAndRunPackage(scope, args.slice(2));
  else if (cmd === 'install') doInstallPackage(scope);
  else if (cmd === 'remove') {
    removePackage(scope);
    print(`Removed ${scope}.`);
  } else if (cmd === 'list') {
    const pkgs = listInstalledPackages();
    print(`Installed packages: ${pkgs.join(', ')}`);
  } else if (cmd === 'info') {
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
}
