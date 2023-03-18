import { readOrCreate } from './file';
import { Package } from './types';

export const address =
  settings.get('mngr.address') ?? 'http://mr.thedevbird.com:3000/pkgs';

export function getServerList() {
  return readOrCreate('.mngr/serverlist.txt', [address].join('\n')).split('\n');
}

export function fetchPackage(pkg: string): Package {
  const servers = getServerList();
  if (!servers) throw new Error('No servers found');
  const server = servers[0];

  const url = `${server}/${pkg}/pkg.json`;
  const [res] = http.get(url);

  if (typeof res === 'boolean' || !res) {
    throw new Error(`Failed to fetch ${pkg} from ${server}`);
  }

  const text = res.readAll();
  res.close();
  if (!text) throw new Error(`Failed to fetch ${pkg} from ${server}`);

  return textutils.unserializeJSON(text);
}

export function downloadPackage(
  pkg: string,
  opts?: { file?: string; quiet?: boolean }
) {
  const file = opts?.file ?? pkg;
  const quiet = opts?.quiet ?? false;

  const servers = getServerList();
  if (!servers) throw new Error('No servers found');
  const server = servers[0];

  const url = `${server}/${pkg}/${file}`;
  const [res] = http.get(url);
  if (typeof res === 'boolean') {
    print(`Failed to download ${pkg}/${file} from ${server}`);
    return;
  }

  // check if the folder .mngr/lib/<pkg> exists
  const dirExists = isPkgInstalled(pkg);
  if (!dirExists) {
    fs.makeDir(`.mngr/lib/${pkg}`);
  }

  const [fileWrite] = fs.open(`.mngr/lib/${pkg}/${file}`, 'w');
  if (!fileWrite) {
    print(`Failed to create file for ${pkg}/${file}`);
    return;
  }

  if (!res) {
    print(`Failed to download ${pkg}/${file} from ${server}`);
    print(`URL: ${url}`);
    return;
  }

  fileWrite.write(res.readAll());
  fileWrite.close();
  res.close();

  if (!quiet) print(`Downloaded ${pkg}/${file}`);
}

export function installPackage(
  pkg: string,
  opts?: { dry?: boolean; quiet?: boolean }
) {
  const dry = opts?.dry ?? false;
  const quiet = opts?.quiet ?? false;

  const { deps, files } = fetchPackage(pkg);

  const totals = {
    deps: deps.length,
    files: files.length,
  };

  let filesToUpdate = getFilesToUpdate(pkg);
  filesToUpdate = filesToUpdate ? filesToUpdate : files;

  for (const dep of deps) {
    const total = installPackage(dep, { dry, quiet });
    totals.files += total.files;
    totals.deps += total.deps;
  }

  if (dry) return totals;

  for (const file of files) {
    const shouldDownload = filesToUpdate.includes(file) ?? true;
    if (shouldDownload) downloadPackage(pkg, { file, quiet });
  }

  // Copys the files specified as binaries in the pkg.json file
  // to the .mngr/bin folder so they can be run from the command line
  copyBinFiles(pkg);

  return totals;
}

export function removePackage(pkg: string) {
  fs.delete(`.mngr/lib/${pkg}`);
  fs.delete(`.mngr/bin/${pkg}.lua`);
}

export function isPkgInstalled(pkg: string) {
  return fs.exists(`.mngr/lib/${pkg}`);
}

export function doInstallPackage(pkg: string, doPrint = true) {
  const total = installPackage(pkg);
  if (doPrint)
    print(
      `Installed ${pkg} along with ${total.deps} deps (${total.files} total files)`
    );
}

export function doUpdatePackage(pkg: string, doPrint = true) {
  if (!isPkgInstalled(pkg)) throw new Error(`Package ${pkg} is not installed`);

  const total = installPackage(pkg);
  if (doPrint)
    print(
      `Updated ${pkg} along with ${total.deps} deps (${total.files} total files)`
    );
}

export function updateAndRunPackage(
  pkg: string,
  opts?: { args?: string[]; bin?: string }
): void {
  doInstallPackage(pkg);

  const fileToRun = opts?.bin ?? pkg;

  if (!fs.exists(`.mngr/bin/${fileToRun}.lua`)) {
    print(`Failed to find .mngr/bin/${fileToRun}.lua`);
    return;
  }

  // Runs the main package file
  shell.run(`.mngr/bin/${fileToRun}.lua ${opts?.args?.join(' ') ?? ''}`);
}

export function listInstalledPackages() {
  const pkgs = fs.list('.mngr/lib');
  const installed = pkgs.filter((pkg) => !pkg.endsWith('.lua'));
  return installed;
}

export function fetchLocalPackage(pkg: string): Package | undefined {
  const [file] = fs.open(`.mngr/lib/${pkg}/pkg.json`, 'r');
  if (!file) {
    throw new Error(`Failed to open .mngr/lib/${pkg}/pkg.json`);
  }

  const text = file.readAll();
  file.close();

  return textutils.unserializeJSON(text);
}

export function copyAllBinFiles() {
  const pkgs = listInstalledPackages();
  for (const pkg of pkgs) {
    copyBinFiles(pkg);
  }
}

/** Copies bin files from .mngr/lib/<pkg> to .mngr/bin/<bin>.lua */
export function copyBinFiles(pkg: string) {
  const localPkg = fetchLocalPackage(pkg);
  const linkedBins = getLinkedBins()
    .filter((link) => link.pkg === pkg)
    .map((link) => link.bin);
  if (localPkg?.bin !== undefined) {
    for (const [bin] of Object.entries(localPkg.bin)) {
      // If the binary isn't linked, we can copy it
      // if it is linked, copyBinFile will copy it
      // to the linked folder instead of the bin folder
      copyBinFile(pkg, bin, linkedBins.includes(bin));
    }
  }
}

/** Copies a bin file from .mngr/lib/<pkg> to .mngr/bin/<bin>.lua */
export function copyBinFile(pkg: string, bin: string, useLinked = false) {
  const binFolder = useLinked ? '.mngr/links' : '.mngr/bin';

  const localPkg = fetchLocalPackage(pkg);
  if (localPkg?.bin !== undefined) {
    const file = localPkg.bin[bin];
    if (file) {
      if (fs.exists(`${binFolder}/${bin}.lua`)) {
        fs.delete(`${binFolder}/${bin}.lua`);
      }

      fs.copy(`.mngr/lib/${pkg}/${file}`, `${binFolder}/${bin}.lua`);
    }
  }
}

/** Gets a list of all linked binaries */
export function getLinkedBins(): { pkg: string; bin: string }[] {
  if (!fs.exists('.mngr/links')) return [];
  const bins = fs.list('.mngr/links').map((bin) => bin.replace('.lua', ''));
  const linkedBins: { pkg: string; bin: string }[] = [];
  const binRelations = getBinRelations();
  for (const bin of bins) {
    const pkg = binRelations[bin];
    if (pkg) {
      linkedBins.push({ pkg, bin });
    }
  }

  return linkedBins;
}

/** Gets the relations between binary names and packages */
export function getBinRelations(): Record<string, string> {
  const pkgs = listInstalledPackages();
  const relations: Record<string, string> = {};
  for (const pkg of pkgs) {
    const localPkg = fetchLocalPackage(pkg);
    if (localPkg?.bin !== undefined) {
      for (const [cmd, file] of Object.entries(localPkg.bin)) {
        relations[cmd] = pkg;
      }
    }
  }

  return relations;
}

export function fetchAllLocalPackages(remote = false): Package[] {
  const pkgs = listInstalledPackages();
  const packages: Package[] = [];
  for (const pkg of pkgs) {
    const localPkg = remote ? fetchPackage(pkg) : fetchLocalPackage(pkg);
    if (localPkg) {
      packages.push(localPkg);
    }
  }

  return packages;
}

export function getFilesToUpdate(pkg: string): string[] | undefined {
  if (!isPkgInstalled(pkg)) return undefined;

  const local = fetchLocalPackage(pkg);
  const remote = fetchPackage(pkg);

  const files: string[] = [];

  if (!local || !remote) {
    return undefined;
  }

  const checksums = local.checksums;
  const remoteChecksums = remote.checksums;

  for (const [file, checksum] of Object.entries(checksums)) {
    if (remoteChecksums[file] !== checksum) {
      files.push(file);
    }
  }

  // if the remote package has more files than the local package, we need to update
  if (Object.keys(remoteChecksums).length > Object.keys(checksums).length) {
    for (const file of Object.keys(remoteChecksums)) {
      if (!checksums[file]) {
        files.push(file);
      }
    }
  }

  // If we have files to update, update the pkg.json file
  // i.e. If we have a change, we need to update the checksums
  if (files.length > 0) files.push('pkg.json');

  return files;
}
