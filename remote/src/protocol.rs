//! Wire format shared with `pkgs/rpc/lib.lua`: JSON over a text WebSocket
//! frame in each direction.
//!
//! Server -> computer: `{"id": <number>, "method": "<dotted.path>", "args": [...]}`
//! Computer -> server: `{"id": <same id>, "result": <value>}` or
//! `{"id": <same id>, "error": "<message>"}`.

use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Debug, Serialize)]
pub struct Request<'a> {
  pub id: u64,
  pub method: &'a str,
  pub args: Value,
}

#[derive(Debug, Deserialize)]
pub struct Response {
  pub id: u64,
  #[serde(default)]
  pub result: Option<Value>,
  #[serde(default)]
  pub error: Option<String>,
}
