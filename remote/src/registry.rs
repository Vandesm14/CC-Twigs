//! Per-computer connection state: a `Computer` handle exposes an async
//! `call()` that correlates a request to its response via an id + oneshot
//! channel, so multiple in-flight calls on the same connection don't get
//! mixed up. The `Registry` maps computer name -> live `Computer`.

use std::collections::HashMap;
use std::fmt;
use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};

use serde_json::Value;
use tokio::sync::{RwLock, mpsc, oneshot};

use crate::protocol::{Request, Response};

type PendingCalls =
  RwLock<HashMap<u64, oneshot::Sender<Result<Value, String>>>>;

#[derive(Debug)]
pub enum CallError {
  /// The computer disconnected before (or while) the call was in flight.
  Disconnected,
  /// The computer's `pcall` around the method failed; carries its message.
  Remote(String),
}

impl fmt::Display for CallError {
  fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
    match self {
      CallError::Disconnected => write!(f, "computer disconnected"),
      CallError::Remote(message) => write!(f, "{message}"),
    }
  }
}

impl std::error::Error for CallError {}

/// A live connection to one CC computer.
pub struct Computer {
  outgoing: mpsc::UnboundedSender<String>,
  pending: PendingCalls,
  next_id: AtomicU64,
}

impl Computer {
  pub fn new(outgoing: mpsc::UnboundedSender<String>) -> Self {
    Self {
      outgoing,
      pending: RwLock::new(HashMap::new()),
      next_id: AtomicU64::new(1),
    }
  }

  /// Calls a dotted-path method on the computer, e.g. `"turtle.forward"`,
  /// and awaits its result.
  pub async fn call(
    &self,
    method: &str,
    args: Value,
  ) -> Result<Value, CallError> {
    let id = self.next_id.fetch_add(1, Ordering::Relaxed);
    let (tx, rx) = oneshot::channel();
    self.pending.write().await.insert(id, tx);

    let text = serde_json::to_string(&Request { id, method, args })
      .expect("request serializes to JSON");

    if self.outgoing.send(text).is_err() {
      self.pending.write().await.remove(&id);
      return Err(CallError::Disconnected);
    }

    match rx.await {
      Ok(Ok(value)) => Ok(value),
      Ok(Err(message)) => Err(CallError::Remote(message)),
      Err(_) => Err(CallError::Disconnected),
    }
  }

  /// Resolves the pending call matching `response.id`, if it's still
  /// waiting (it may have already timed out and been dropped elsewhere).
  pub async fn resolve(&self, response: Response) {
    if let Some(tx) = self.pending.write().await.remove(&response.id) {
      let result = match response.error {
        Some(message) => Err(message),
        None => Ok(response.result.unwrap_or(Value::Null)),
      };
      let _ = tx.send(result);
    }
  }

  /// Fails every still-pending call. Call this once the connection dies so
  /// no `call()` future hangs forever.
  pub async fn fail_all(&self) {
    for (_, tx) in self.pending.write().await.drain() {
      let _ = tx.send(Err(CallError::Disconnected.to_string()));
    }
  }
}

pub type Registry = Arc<RwLock<HashMap<String, Arc<Computer>>>>;
