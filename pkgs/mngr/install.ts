export const address =
  settings.get('mngr.address') ?? 'http://mr.thedevbird.com:3000/pkgs';

function downloadFile(file: string) {
  shell.run('wget', `${address}/mngr/${file}`, `.mngr/lib/mngr/${file}`);
}

downloadFile('mngr.lua');
downloadFile('api.lua');
downloadFile('file.lua');
downloadFile('usage.txt');
downloadFile('README.md');
downloadFile('pkg.json');

shell.run('.mngr/lib/mngr/mngr.lua install mngr');
