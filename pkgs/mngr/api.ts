export const address =
  settings.get('mngr.address') ?? 'http://mr.thedevbird.com:3000/pkgs';

export function getServerList() {
  const [file] = fs.open('pkgs/mngr/serverlist.txt', 'r');
  if (!file) {
    print('Failed to open serverlist.txt');
    shell.exit();
    return;
  }

  const servers = file.readAll().split('\n');
  file.close();

  return servers;
}

export function getDepsForPackage(pkg: string) {
  // TODO: Implement scanning from multiple servers ("mirrors")
  const servers = getServerList();
  if (!servers) throw new Error('No servers found');
  const server = servers[0];

  const url = `${server}/${pkg}/needs.txt`;
  const [res] = http.get(url);
  if (typeof res === 'boolean' || !res) {
    return [];
  }

  const text = res.readAll();
  res.close();
  if (!text) return [];

  return text.split('\n');
}

export function getLibsForPackage(pkg: string) {
  // TODO: Implement scanning from multiple servers ("mirrors")
  const servers = getServerList();
  if (!servers) throw new Error('No servers found');
  const server = servers[0];

  const url = `${server}/${pkg}/has.txt`;
  const [res] = http.get(url);
  if (typeof res === 'boolean' || !res) {
    return [pkg];
  }

  const text = res.readAll();
  res.close();
  if (!text) return [pkg];

  return text.split('\n');
}

export function downloadPackage(pkg: string, lib?: string) {
  const servers = getServerList();
  if (!servers) throw new Error('No servers found');
  const server = servers[0];
  lib = lib ?? pkg;

  const url = `${server}/${pkg}/${lib}.lua`;
  const [res] = http.get(url);
  if (typeof res === 'boolean') {
    print(`Failed to download ${pkg}/${lib} from ${server}`);
    return;
  }

  // check if the folder pkgs/<pkg> exists
  const dirExists = isPkgInstalled(pkg);
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

export function installPackage(pkg: string, dry = false) {
  const deps = getDepsForPackage(pkg);
  const libs = getLibsForPackage(pkg);

  const totals = {
    deps: deps.length,
    files: libs.length,
  };

  for (const dep of deps) {
    const total = installPackage(dep, dry);
    totals.files += total.files;
    totals.deps += total.deps;
  }

  if (dry) return totals;

  for (const lib of libs) {
    downloadPackage(pkg, lib);
  }

  // Copy a top-level package file to the root of `pkgs/` so that it can be run
  if (fs.exists(`pkgs/${pkg}.lua`)) fs.delete(`pkgs/${pkg}.lua`);
  if (fs.exists(`pkgs/${pkg}/${pkg}.lua`))
    fs.copy(`pkgs/${pkg}/${pkg}.lua`, `pkgs/${pkg}.lua`);

  return totals;
}

export function removePackage(pkg: string) {
  fs.delete(`pkgs/${pkg}`);
  fs.delete(`pkgs/${pkg}.lua`);
}

export function isPkgInstalled(pkg: string) {
  return fs.exists(`pkgs/${pkg}`);
}

export function doInstallPackage(pkg: string) {
  const total = installPackage(pkg);
  print(
    `Installed ${pkg} along with ${total.deps} deps (${total.files} total files)`
  );
}

export function updateAndRunPackage(scope: string) {
  const parts = scope.split('/');

  const pkg = parts[0];
  const lib = parts.length > 1 ? parts[1] : pkg;

  doInstallPackage(pkg);

  // Runs the main package file
  shell.run(`pkgs/${pkg}/${lib}.lua`);
}
