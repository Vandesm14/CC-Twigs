import { walkSync } from 'https://deno.land/std@0.175.0/fs/walk.ts';

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
    exts: ['.lua'],
  });
  const luaNames = [...lua].map((file) => file.path);
  const needs: Array<string> = [];

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

    // Change package path to include the pkgs folder
    newLuaFile = `package.path = "/pkgs/?.lua;" .. package.path\n${newLuaFile}`;

    Deno.writeTextFileSync(luaName, newLuaFile);
  });

  // If the package has other lua files besindes the <pkg>.lua file, create a has.txt file
  if (
    luaNames
      .map((n) => n.replace('.lua', '').split('/').slice(-1)[0])
      .some((n) => n !== name)
  ) {
    // Create a has.txt file with all the lua files for the package
    Deno.writeTextFileSync(
      `./pkgs/${name}/has.txt`,
      luaNames
        .map((name) => name.split('/').slice(-1)[0].replace('.lua', ''))
        .join('\n')
    );
  } else if (existsSync(`./pkgs/${name}/has.txt`)) {
    Deno.removeSync(`./pkgs/${name}/has.txt`);
  }

  if (needs.length > 0) {
    // Create a needs.txt file with all the packages the package needs
    Deno.writeTextFileSync(`./pkgs/${name}/needs.txt`, needs.join('\n'));
  } else if (existsSync(`./pkgs/${name}/needs.txt`)) {
    // If there are no packages the package needs, remove the needs.txt file
    Deno.removeSync(`./pkgs/${name}/needs.txt`);
  }
});
