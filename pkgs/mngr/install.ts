export const address =
  settings.get('mngr.address') ?? 'http://mr.thedevbird.com:3000/pkgs';

function downloadFile(file: string) {
  shell.run('wget', `${address}/mngr/${file}.lua`, `pkgs/mngr/${file}.lua`);
}

downloadFile('mngr');
downloadFile('api');

shell.run('pkgs/mngr/mngr.lua');
