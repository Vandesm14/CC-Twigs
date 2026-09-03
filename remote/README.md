# remote

RPC over CC:Tweaked's native `http.websocket` API: call any dotted-path CC
API/peripheral method on a connected computer from Rust and await the
result. No CC mods, no external Lua libs — just `http`/`textutils`.

## Run

```
cargo run --release
```

Listens on `0.0.0.0:8080`.

## Point a computer at it

On the computer:

```
set rpc.url ws://<server-ip>:8080/ws
```

Then run `pkgs/rpc/rpc.bin.lua` (or `mngr enable rpc` to run it on every
boot, once it's on the computer via `mngr` — see the root README). Its
label (or its id if unlabelled) becomes its name on the server.

Don't use `localhost`/`hostname` for `rpc.url` — CraftOS-PC's websocket
client tries the IPv6 resolution first with no fallback and fails with a
misleading "Not Found" error. Use a literal IP.

## Wire format

Text WebSocket frames, JSON both ways, matching `pkgs/rpc/lib.lua`:

- server -> computer: `{"id": <number>, "method": "<dotted.path>", "args": [...]}`
- computer -> server: `{"id": <same id>, "result": <value>}` or
  `{"id": <same id>, "error": "<message>"}`

`method` is resolved by walking the dotted path through `_G`
(`"turtle.forward"` -> `turtle.forward`, `"redstone.setOutput"` ->
`redstone.setOutput`, ...), so any CC API or peripheral call works without
a hardcoded method list. Only the method's *first* return value comes back
— JSON has no room for Lua's multi-return.

## Rust API

```rust
let computer = registry.read().await.get("turtle-1").cloned().unwrap();
let ok: Value = computer.call("turtle.forward", json!([])).await?;
```

`Computer::call` correlates request/response by id via a oneshot channel,
so concurrent in-flight calls on the same connection don't cross wires. On
disconnect every pending call resolves to `CallError::Disconnected` instead
of hanging.

There's also an HTTP-facing example of the same thing, for a quick `curl`
round trip without writing Rust:

```
curl -X POST http://localhost:8080/call/turtle-1 \
  -H 'content-type: application/json' \
  -d '{"method": "turtle.forward", "args": []}'
```

`GET /computers` lists currently-connected computer names.

## Adding a typed wrapper later

The transport stays generic (`call(method, args)`); a typed convenience
layer is just a struct wrapping a `Arc<Computer>`, e.g.:

```rust
struct Turtle(Arc<Computer>);

impl Turtle {
  async fn forward(&self) -> Result<bool, CallError> {
    Ok(self.0.call("turtle.forward", json!([])).await?.as_bool().unwrap_or(false))
  }
}
```

## src/pkgs/ — Rust-side programs

Mirrors `pkgs/` on the Lua side, but these run here and drive a computer
via `Computer::call` instead of being uploaded to it. Each program is a
module under `src/pkgs/`, registered by name in `src/pkgs/mod.rs`'s
`find`/`NAMES`. Run one over HTTP:

```
curl -X POST http://localhost:8080/run/<computer>/<program>
```

`GET /programs` lists available program names.

Demo program: `chest-scan` — walks every connected inventory peripheral
(`peripheral.getNames` + `peripheral.hasType(name, "inventory")`), tallies
item counts across all of them via `peripheral.call(name, "list")`, and
`print`s the top 5 items and the scanned chest names back on the computer.
See `src/pkgs/chest_scan.rs`.

## Why no bootstrap HTTP endpoint here

The repo already has a package server (`deno task serve`, see root
README) that serves every file under `pkgs/`, `pkgs/rpc/rpc.bin.lua`
included — `wget run http://<pkg-server>/rpc/rpc.bin.lua` already works
via that, or install it normally through `mngr`. Duplicating static file
serving here would just be a second, out-of-sync copy of the same thing.
