import { Package } from './types';

export const address =
  settings.get('mngr.address') ?? 'http://mr.thedevbird.com:3000/pkgs';

export function getServerList() {
  const [file] = fs.open('.mngr/serverlist.txt', 'r');
  if (!file) {
    print('Failed to open serverlist.txt');
    shell.exit();
    return;
  }

  const servers = file.readAll().split('\n');
  file.close();

  return servers;
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

export function downloadPackage(pkg: string, file?: string) {
  const servers = getServerList();
  if (!servers) throw new Error('No servers found');
  const server = servers[0];
  file = file ?? pkg;

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
}

export function installPackage(pkg: string, dry = false) {
  const { deps, files } = fetchPackage(pkg);

  const totals = {
    deps: deps.length,
    files: files.length,
  };

  for (const dep of deps) {
    const total = installPackage(dep, dry);
    totals.files += total.files;
    totals.deps += total.deps;
  }

  if (dry) return totals;

  for (const file of files) {
    downloadPackage(pkg, file);
  }

  // Copy a top-level package file to the root of `pkgs/` so that it can be run
  if (fs.exists(`.mngr/bin/${pkg}.lua`)) fs.delete(`.mngr/bin/${pkg}.lua`);
  if (fs.exists(`.mngr/lib/${pkg}/${pkg}.lua`))
    fs.copy(`.mngr/lib/${pkg}/${pkg}.lua`, `.mngr/bin/${pkg}.lua`);

  return totals;
}

export function removePackage(pkg: string) {
  fs.delete(`.mngr/lib/${pkg}`);
  fs.delete(`.mngr/bin/${pkg}.lua`);
}

export function isPkgInstalled(pkg: string) {
  return fs.exists(`.mngr/lib/${pkg}`);
}

export function doInstallPackage(pkg: string) {
  const total = installPackage(pkg);
  print(
    `Installed ${pkg} along with ${total.deps} deps (${total.files} total files)`
  );
}

export function updateAndRunPackage(pkg: string, bin?: string) {
  bin = bin ?? pkg;
  doInstallPackage(pkg);

  // Runs the main package file
  shell.run(`.mngr/bin/${bin}.lua`);
}

export function listInstalledPackages() {
  const pkgs = fs.list('.mngr/lib');
  const installed = pkgs.filter((pkg) => !pkg.endsWith('.lua'));
  return installed;
}

export function fetchLocalPackage(pkg: string): Package {
  const [file] = fs.open(`.mngr/lib/${pkg}/pkg.json`, 'r');
  if (!file) {
    throw new Error(`Failed to open .mngr/lib/${pkg}/pkg.json`);
  }

  const text = file.readAll();
  file.close();

  return textutils.unserializeJSON(text);
}

/** Copies bin files from .mngr/lib/<pkg> to .mngr/bin/<bin>.lua */
// export function copyBinFiles() {
//   const pkgs = listInstalledPackages();
//   for (const pkg of pkgs) {
//     const { bin } = fetchLocalPackage(pkg);
//     const binFiles =
//     for (const bin of binFiles) {
//       fs.copy(`.mngr/lib/${pkg}/bin/${bin}`, `.mngr/bin/${bin}`);
//     }
//   }
// }
