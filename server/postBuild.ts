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

function dedupe<T>(array: T[]) {
  return Array.from(new Set(array));
}

const packagePathString = `package.path = "/.mngr/lib/?.lua;" .. package.path`;
const packagePathRegex = /(package\.path)(.+)(\n*)/;

names.forEach((name) => {
  // Get all the .lua files in the package
  const lua = walkSync(`./pkgs/${name}`, {
    includeDirs: false,
  });
  const files = dedupe(
    [...lua, { path: `pkgs/${name}/pkg.json` }].map((file) => file.path)
  );
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

    // Remove all instances of an existing package.path
    newLuaFile = newLuaFile.replace(packagePathRegex, '');

    // Change package path to include the .mngr/lib/ folder
    newLuaFile = `${packagePathString}\n${newLuaFile}`;

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

  pkgJSON.checksums['pkg.json'] = (() => {
    const content = JSON.stringify(pkgJSON, null, 2);
    return checksum(content);
  })();

  pkgJSON.files.forEach((file) => {
    // Don't include the pkg.json file in the checksums
    if (file === 'pkg.json') return;

    pkgJSON.checksums[file] = getFileChecksum(name, file);
  });

  Deno.writeTextFileSync(
    `./pkgs/${name}/pkg.json`,
    JSON.stringify(pkgJSON, null, 2)
  );
});
