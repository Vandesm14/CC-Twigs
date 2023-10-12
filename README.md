# CC-Twigs

This contains both a package manager and packages for ComputerCraft.

## What is a Package?

Each package is a directory, where the name of the directory is the package
name. Package directories contain files which are associated with that package.
All package directories are located within the `pkgs` directory at the root of
this repository.

Using the below tree as an example:

```
pkgs
└─net
  ├─protocol.lua
  └─server.lua
```

There is a package named `net` that contains a `protocol.lua` and `server.lua`
file. These can later be referred to when making HTTP requests or using the
`mngr` tool.

## The Package Server

This provides a simple way for external applications to query about packages and
download their files. To run the server, use the command `deno task serve`,
which requires [Deno] to be installed and available. It will then begin
listening for HTTP requests at `http://localhost:3000/`.

You can request data from the server using the folloing HTTP requests:

- `GET /` — Responds with newline-separated package names.
- `GET /package` — Responds with newline-separated package files.
- `GET /package/file` — Responds with the content of the package file.

These may respond with a `404` if the package or file does not exist.

## Mngr

Mngr is a tool for ComputerCraft computers to manage packages from the package
server. To install mngr, follow the steps below on a ComputerCraft computer:

1. Set the `mngr.url` setting to the package server URL —
   `set mngr.url http://localhost:3000`.
2. Download the mngr file via HTTP — `wget http://localhost:3000/mngr/mngr.lua`.
3. Run the `mngr.lua` file and input `y` when asked to install — `mngr`.
4. Remove the install `mngr.lua` file — `rm mngr.lua`.
5. Run mngr to see the available commands — `mngr`.

[Deno]: https://deno.land
