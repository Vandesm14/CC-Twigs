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
  const pkgJSON: Package = JSON.parse(existingJSON);
  pkgJSON.name ??= name;
  pkgJSON.main ??= `${name}.lua`;
  pkgJSON.deps = needs.sort();
  pkgJSON.files = files
    .filter((file) => !file.endsWith('.ts'))
    .map((file) => file.replace(`pkgs/${name}/`, ''))
    .sort();

  pkgJSON.checksums = {};
  pkgJSON.files.forEach((file) => {
    // Don't include the pkg.json file in the checksums
    if (file === 'pkg.json') return;

    const content = Deno.readFileSync(`./pkgs/${name}/${file}`);
    const hash = new Hash('md5');
    pkgJSON.checksums[file] = hash.digest(content).hex();
  });

  Deno.writeTextFileSync(
    `./pkgs/${name}/pkg.json`,
    JSON.stringify(pkgJSON, null, 2)
  );
});
