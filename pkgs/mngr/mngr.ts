const args = [...$vararg];
const cmd = args[0];
const pkg = args[1];

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

function downloadPackage(pkg: string) {
  const server = getServerList()[0];

  const url = `${server}/${pkg}/${pkg}.lua`;
  const [res] = http.get(url);
  if (typeof res === 'boolean') {
    print(`Failed to download ${pkg} from ${server}`);
    return;
  }

  const [file] = fs.open(`pkgs/${pkg}.lua`, 'w');
  if (!file) {
    print(`Failed to create file for ${pkg}`);
    return;
  }

  file.write(res.readAll());
  file.close();
  res.close();
}

function installPackage(pkg: string) {
  const deps = getDepsForPackage(pkg);

  for (const dep of deps) {
    downloadPackage(dep);
  }

  downloadPackage(pkg);

  return deps.length;
}

function removePackage(pkg: string) {
  fs.delete(`pkgs/${pkg}.lua`);
}

if (cmd === 'install' || cmd === 'update') {
  const total = installPackage(pkg);
  print(`Installed ${pkg} and ${total} deps.`);

  // @ts-expect-error: Lua allows this
  return;
}

if (cmd === 'remove') {
  removePackage(pkg);
  print(`Removed ${pkg}.`);

  // @ts-expect-error: Lua allows this
  return;
}

print('Usage: mngr <install|update|remove> <package>');
