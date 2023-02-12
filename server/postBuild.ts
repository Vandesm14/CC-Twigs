import * as fs from 'https://deno.land/std@0.175.0/fs/walk.ts';

const packages = Deno.readDirSync('./pkgs');
const names = [...packages].map((pkg) => pkg.name);

console.log(`${names.length} Packages:`, names.join(', '));

names.forEach((name) => {
  // Get all the .lua files in the package
  const lua = fs.walkSync(`./pkgs/${name}`, {
    includeDirs: false,
    exts: ['.lua'],
  });
  const luaNames = [...lua].map((file) => file.path);

  console.log(`${luaNames.length} Lua files:`, luaNames.join(', '));

  luaNames.forEach((luaName) => {
    const luaFile = Deno.readTextFileSync(luaName);
    // Match: `require("pkgs.")` and remove the `pkgs.`
    let newLuaFile = luaFile.replace(/(?<=require\(")pkgs\./g, '');

    // Change package path to include the pkgs folder
    newLuaFile = `package.path = "/pkgs/?.lua;" .. package.path\n${newLuaFile}`;

    Deno.writeTextFileSync(luaName, newLuaFile);
  });
});
