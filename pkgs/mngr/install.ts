export const address =
  settings.get('mngr.address') ?? 'http://mr.thedevbird.com:3000/pkgs';

function downloadFile(file: string) {
  shell.run(
    'wget',
    `${address}/mngr/${file}.lua`,
    `.mngr/lib/mngr/${file}.lua`
  );
}

downloadFile('mngr');
downloadFile('api');

shell.run('.mngr/lib/mngr/mngr.lua install mngr');
