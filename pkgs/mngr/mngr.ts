// @ts-expect-error: FIXME: We're in modle scope, args isn't redeclared
const args = [...$vararg];
const cmd = args[0];
const scope = args[1];

function getServerList() {
  // read from ".mngr/serverlist.txt", a list of servers separated by newline
  const dirExists = fs.exists('.mngr/serverlist.txt');
  if (!dirExists) {
    const [file] = fs.open('.mngr/serverlist.txt', 'w');
    if (!file) {
      print('Failed to create serverlist.txt');
      shell.exit();
    }

    file.write('http://mr.thedevbird.com:3000/pkgs');
    file.close();

    print('Added default server to serverlist.txt');
  }

  const [file] = fs.open('.mngr/serverlist.txt', 'r');
  if (!file) {
    print('Failed to open serverlist.txt');
    shell.exit();
  }

  const servers = file.readAll().split('\n');
  file.close();

  return servers;
}

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

  return totals;
}

function removePackage(pkg: string) {
  fs.delete(`pkgs/${pkg}`);
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

if (cmd === 'install' || cmd === 'update') {
  doInstallPackage(scope);

  // @ts-expect-error: Lua allows this
  return;
}

if (cmd === 'remove') {
  removePackage(scope);
  print(`Removed ${scope}.`);

  // @ts-expect-error: Lua allows this
  return;
}

if (cmd === 'run') {
  updateAndRunPackage(scope);

  // @ts-expect-error: Lua allows this
  return;
}

print('Usage: mngr <install|update|remove|run> <package>');
print('Example: mngr install bgp');
print('Example: mngr run bgp');
print('Example: mngr run bgp/start');
print('Example: mngr remove bgp');
