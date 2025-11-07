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
- `GET /package/file/deps` — Responds with newline-separated package file
  dependency package names.

These may respond with a `404` if the package or file does not exist.

## Mngr

Mngr is a tool for ComputerCraft computers to manage packages from the package
server. To install mngr, follow the steps below on a ComputerCraft computer:

1. Set the `mngr.url` setting to the package server URL —
   `set mngr.url http://localhost:3000`.
2. Download and run the mngr install file via HTTP —
   `wget run http://localhost:3000/mngr/bin.lua`.
3. Run `mngr` to refetch packages from the server.

## Turt

Turt is a turtle automation program that navigates paths using colored blocks
and waypoints. Turtles follow tracks and respond to colored blocks and barrel
identifiers to execute navigation logic and warehouse operations.

### Colors

Turtles detect colored blocks (dyed blocks) underneath them as they move. These
colors control navigation behavior:

- **white** — Turn right. If yield counter is active, skip the turn if blocked.
- **black** — Turn left. If yield counter is active, skip the turn if blocked.
- **yellow** — Increment the ignore counter. The next colored block will be
  ignored.
- **lime** — Increment the yield counter. The next turn will be skipped if
  blocked.
- **green** — Wait (pause movement). Turtle resumes when it moves off a green
  block or encounters a non-green colored block.
- **purple** — End operation and return to idle state. Also used as a
  home/status reporting location.

### Waypoint Identifiers

Turtles detect barrels underneath them with specific item names (disk labels) to
trigger waypoint actions. These identifiers are stored in the first slot of the
barrel:

- **wp-storage-right** — Storage waypoint. Turn right, move up to target Y
  position, and either pull items from chest (output orders) or drop all items
  (input orders). Then return down and turn left.
- **wp-storage-left** — Storage waypoint. Turn left, move up to target Y
  position, and either pull items from chest (output orders) or drop items
  (input orders). Then return down and turn right.
- **wp-input-right** — Input waypoint. For input orders, turn right, pull items
  from chest, and turn left.
- **wp-input-left** — Input waypoint. For input orders, turn left, pull items
  from chest, and turn right.
- **wp-output-right** — Output waypoint. For output orders, turn right, drop
  items into chest, and turn left.
- **wp-output-left** — Output waypoint. For output orders, turn left, drop items
  into chest, and turn right.

### Storage Chest Identifiers

The wherehouse system uses coordinate-based naming for storage chests. Each
chest must have a disk in its first slot with a label following this pattern:

- **c{x}\_{y}\_{z}** — Coordinate identifier (e.g., `c10_5_20`). The wherehouse
  manager uses these coordinates to direct turtles to specific storage
  locations. The `x`, `y`, and `z` values correspond to GPS coordinates in the
  world.
- **input_chest** — Special identifier for the main input chest where items are
  deposited for distribution to storage.

[Deno]: https://deno.land
