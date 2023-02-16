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
const pkg = args[1];
const file = args[2];

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
  print('Example: mngr remove bgp');
}

if (cmd === 'copy-bin') {
  copyBinFiles();
  print('Copied all bin files to .mngr/bin/*');
}

if (cmd === 'update') {
  // If no argument, update all packages
  const pkgs = pkg ? [pkg] : listInstalledPackages();

  print(`Updating ${pkgs.length} packages...`);
  pkgs.forEach((pkg) => doInstallPackage(pkg, false));
  print(
    `Updated ${pkgs.length} package${pkgs.length ? 's' : ''} (${pkgs.join(
      ', '
    )})`
  );
} else if (cmd === 'help' || !cmd) printUsage();

if (pkg) {
  if (cmd === 'run')
    updateAndRunPackage(pkg, {
      ...(file ? { bin: file } : {}),
      args: args.slice(!!file ? 3 : 2),
    });
  else if (cmd === 'dev') {
    // Installs the package, and aliases the binaries to run `mngr run <pkg> <bin>`
    doInstallPackage(pkg);
  } else if (cmd === 'install') doInstallPackage(pkg);
  else if (cmd === 'remove') {
    removePackage(pkg);
    print(`Removed ${pkg}.`);
  } else if (cmd === 'list') {
    const pkgs = listInstalledPackages();
    print(`Installed packages: ${pkgs.join(', ')}`);
  } else if (cmd === 'info') {
    const { deps, files } = fetchPackage(pkg);

    const obj = {
      Package: pkg,
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
