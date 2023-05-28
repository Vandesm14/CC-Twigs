import { walkSync } from 'https://deno.land/std@0.175.0/fs/walk.ts';
import { Hash, encode } from 'https://deno.land/x/checksum@1.2.0/mod.ts';
import { Package } from '../pkgs/mngr/types.ts';

const packages = Deno.readDirSync('./pkgs');
const names = [...packages].map((pkg) => pkg.name);

console.log(`${names.length} Packages:`, names.join(', '));

const existsSync = (path: string) => {
  try {
    Deno.statSync(path);
    return true;
  } catch {
    return false;
  }
};

function getFileChecksum(pkg: string, file: string) {
  const content = Deno.readTextFileSync(`./pkgs/${pkg}/${file}`);
  return checksum(content);
}

function checksum(text: string) {
  const hash = new Hash('md5');
  return hash.digest(encode(text)).hex();
}

names.forEach((name) => {
  // Get all the .lua files in the package
  const lua = walkSync(`./pkgs/${name}`, {
    includeDirs: false,
  });
  const files = [...lua].map((file) => file.path);
  const luaNames = files.filter((path) => path.endsWith('.lua'));
  const needs: string[] = [];

  console.log(`${luaNames.length} Lua files:`, luaNames.join(', '));

  luaNames.forEach((luaName) => {
    const luaFile = Deno.readTextFileSync(luaName);

    // Match: `require("pkgs.<package>")` and add the package to the needs array
    const matches = luaFile.match(/(?<=require\("pkgs\.).+"/g);
    if (matches) {
      matches.forEach((match) => {
        const parts = match.split('.');
        const pkg = parts[0];
        if (pkg !== name && !needs.includes(pkg)) needs.push(pkg);
      });
    }

    // Match: `require("pkgs.")` and remove the `pkgs.`
    let newLuaFile = luaFile.replace(/(?<=require\(")pkgs\./g, '');

    // Change package path to include the .mngr/lib/ folder
    newLuaFile = `package.path = "/.mngr/lib/?.lua;" .. package.path\n${newLuaFile}`;

    Deno.writeTextFileSync(luaName, newLuaFile);
  });

  if (!existsSync(`./pkgs/${name}/pkg.json`)) {
    Deno.writeTextFileSync(`./pkgs/${name}/pkg.json`, '{}');
  }

  const existingJSON = Deno.readTextFileSync(`./pkgs/${name}/pkg.json`);
  let pkgJSON: Package = JSON.parse(existingJSON);
  pkgJSON.name ??= name;
  pkgJSON.deps = needs.sort();
  pkgJSON.files = files
    .map((file) => file.replace(`pkgs/${name}/`, ''))
    .sort();

  pkgJSON.checksums = {};

  // We set the checksum for the pkg.json first, to prevent it from changing each build
  // (self referental checksums aren't fun)
  pkgJSON.checksums['pkg.json'] = checksum(JSON.stringify(pkgJSON, null, 2));

  pkgJSON.files.forEach((file) => {
    // Don't include the pkg.json file in the checksums
    if (file === 'pkg.json') return;

    pkgJSON.checksums[file] = getFileChecksum(name, file);
  });

  // Sort the pkg.json keys alphabetically
  pkgJSON = Object.fromEntries(Object.entries(pkgJSON).sort((a, b) => {
    if (a[0] < b[0]) return -1;
    if (a[0] > b[0]) return 1;

    return 0;
  })) as Package;

  Deno.writeTextFileSync(
    `./pkgs/${name}/pkg.json`,
    JSON.stringify(pkgJSON, null, 2)
  );
});
