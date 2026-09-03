//! Rust-side "packages": named programs that drive a connected computer
//! via `Computer::call`, mirroring `pkgs/` on the Lua side except these
//! run here instead of being uploaded. Add a program by dropping a module
//! in this dir and registering it in `find`/`NAMES` below -- no plugin
//! loading or dynamic dispatch magic, just a match statement.

pub mod chest_scan;

use futures_util::future::BoxFuture;

use crate::registry::{CallError, Computer};

/// A program: takes the connected computer, does its thing (typically a
/// few `call`s plus a final `print`), and returns a short summary.
pub type Program = fn(&Computer) -> BoxFuture<'_, Result<String, CallError>>;

pub const NAMES: &[&str] = &["chest-scan"];

pub fn find(name: &str) -> Option<Program> {
  match name {
    "chest-scan" => Some(|computer| Box::pin(chest_scan::run(computer))),
    _ => None,
  }
}
