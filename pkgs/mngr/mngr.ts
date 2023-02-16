import {
  address,
  copyAllBinFiles,
  doInstallPackage,
  fetchPackage,
  getBinRelations,
  getLinkedBins,
  installPackage,
  listInstalledPackages,
  removePackage,
  updateAndRunPackage,
} from './api';
import { createFileIfNotExist } from './file';

const args = [...$vararg];
const command = args[0];
const arg1 = args[1];

function ensureServerList() {
  if (fs.exists('.mngr/serverlist.txt')) return;

  const [file] = fs.open('.mngr/serverlist.txt', 'w');
  if (!file) {
    throw new Error('Could not create serverlist.txt');
  }

  file.write(address);
  file.close();

  print('Added default server to serverlist.txt');
}

function ensurePathOnStartup() {
  if (!shell.path().includes(':/.mngr/bin/'))
    shell.setPath(shell.path() + ':/.mngr/bin/');

  createFileIfNotExist(
    'startup/mngr.lua',
    `shell.setPath(shell.path() .. ":/.mngr/bin/")`
  );
}

function ensureMngrSetup() {
  // Ensure that the serverlist.txt exists (for storing servers/mirrors)
  ensureServerList();

  // Ensure that the startup/mngr.lua exists (for setting shell path to mngr bin)
  ensurePathOnStartup();
}

ensureMngrSetup();

function printUsage() {
  print('Usage: mngr <install|update|remove|run> <package>');
  print('Example: mngr install bgp');
  print('Example: mngr run bgp');
  print('Example: mngr remove bgp');
}

if (command === 'copy-bin') {
  copyAllBinFiles();
  print('Copied all bin files to .mngr/bin/*');
}

if (command === 'update') {
  const pkg = arg1;

  // If no argument, update all packages
  const links = getLinkedBins();
  const pkgs = pkg
    ? [pkg]
    : listInstalledPackages().filter(
        (pkg) => !links.some((link) => link.pkg === pkg)
      );

  print(`Updating ${pkgs.length} packages...`);
  pkgs.forEach((pkg) => doInstallPackage(pkg, false));
  print(
    `Updated ${pkgs.length} package${pkgs.length ? 's' : ''}: ${pkgs.join(
      ', '
    )}`
  );

  // @ts-expect-error
  return;
} else if (command === 'links') {
  const links = getLinkedBins().map((link) => `${link.pkg}/${link.bin}`);
  print(links.length > 0 ? links.join('\n') : 'No links found.');

  // @ts-expect-error
  return;
} else if (command === 'help' || !command) {
  printUsage();

  // @ts-expect-error
  return;
}

if (arg1) {
  if (command === 'run') {
    const pathSpec = arg1.split('/');
    const pkg = pathSpec[0];
    const bin = pathSpec.length > 1 ? pathSpec[1] : undefined;

    if (!pkg) throw new Error('Invalid pathspec');

    updateAndRunPackage(pkg, {
      ...(bin ? { bin } : {}),
      args: args.slice(2),
    });
  } else if (command === 'link') {
    const binRelations = getBinRelations();
    const binary = arg1;

    if (binary === 'mngr') {
      print('Linking mngr is not allowed');

      // @ts-expect-error
      return;
    }

    const pkg = binRelations[binary];
    if (!pkg) {
      print(`No package found for ${binary}`);

      // @ts-expect-error
      return;
    }

    // Installs the package, and aliases the binaries to run `mngr run <pkg> <bin>`
    doInstallPackage(pkg);

    const luaAliasCode = (pkg: string, file?: string) =>
      `
      local args = {...}
      shell.run("mngr", "use-link", "${pkg}", "${file}", unpack(args))
      shell.run(".mngr/links/${file}", unpack(args))`
        .split('\n')
        .map((line) => line.trim())
        .join('\n')
        .trim();

    const binPath = `.mngr/bin/${binary}.lua`;
    const linkPath = `.mngr/links/${binary}.lua`;

    if (fs.exists(linkPath)) {
      fs.delete(linkPath);
    }
    // Move the actual binary to the links folder
    fs.move(binPath, linkPath);

    // Create a new binary that aliases the actual binary
    const [fileWrite] = fs.open(binPath, 'w');
    if (!fileWrite) {
      print(`Failed to create ${binPath}`);
    } else {
      fileWrite.write(luaAliasCode(pkg, binary));
      fileWrite.close();
      print(`Linked ${binary}`);
    }
  } else if (command === 'use-link') {
    const pkg = arg1;

    // This is an "alias" for install just so we don't print anything
    installPackage(pkg, { quiet: true });
  } else if (command === 'unlink') {
    const binary = arg1;

    const binRelations = getBinRelations();
    const pkg = binRelations[binary];
    if (!pkg) {
      print(`No package found for ${binary}`);

      // @ts-expect-error
      return;
    }

    installPackage(pkg);

    const path = `.mngr/links/${binary}.lua`;
    if (fs.exists(path)) {
      fs.delete(path);
      print(`Unlinked ${binary}`);
    } else {
      print(`No link found for ${binary}`);
    }
  } else if (command === 'install') {
    const pkg = arg1;
    doInstallPackage(pkg);
  } else if (command === 'remove') {
    const pkg = arg1;
    removePackage(pkg);
    print(`Removed ${pkg}.`);
  } else if (command === 'list') {
    const pkgs = listInstalledPackages();
    print(`Installed packages: ${pkgs.join(', ')}`);
  } else if (command === 'info') {
    const pkg = arg1;

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
} else {
  printUsage();
}
