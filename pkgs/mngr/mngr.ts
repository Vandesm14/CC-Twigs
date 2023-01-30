const args = [...$vararg];

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

print('Mngr - Package Manager');
print(getServerList().join());
