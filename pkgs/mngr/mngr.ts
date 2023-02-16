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

const args = [...$vararg];
const command = args[0];
const arg1 = args[1];
const arg2 = args[2];

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

if (command === 'copy-bin') {
  copyAllBinFiles();
  print('Copied all bin files to .mngr/bin/*');
}

if (command === 'update') {
  // If no argument, update all packages
  const links = getLinkedBins();
  const pkgs = arg1
    ? [arg1]
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
    updateAndRunPackage(arg1, {
      ...(arg2 ? { bin: arg2 } : {}),
      args: args.slice(!!arg2 ? 3 : 2),
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
    // This is an "alias" for install just so we don't print anything
    installPackage(arg1, { quiet: true });
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
    doInstallPackage(arg1);
  } else if (command === 'remove') {
    removePackage(arg1);
    print(`Removed ${arg1}.`);
  } else if (command === 'list') {
    const pkgs = listInstalledPackages();
    print(`Installed packages: ${pkgs.join(', ')}`);
  } else if (command === 'info') {
    const { deps, files } = fetchPackage(arg1);

    const obj = {
      Package: arg1,
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
