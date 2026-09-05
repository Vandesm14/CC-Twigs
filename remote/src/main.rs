//! RPC server for ComputerCraft computers: accepts a WebSocket connection
//! per computer at `/ws/<name>`, then lets other code call dotted-path
//! CC API methods on a connected computer and await the result.
//!
//! See `pkgs/rpc/rpc.bin.lua` for the matching client, and the README for
//! the wire format and how to point a computer at this server.

pub mod api;
mod pkgs;
mod protocol;
mod registry;

use std::collections::HashMap;
use std::sync::Arc;

use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::routing::{get, post};
use axum::{Json, Router};
use futures_util::{SinkExt, StreamExt};
use serde::Deserialize;
use serde_json::Value;
use tokio::sync::{RwLock, mpsc};

use protocol::Response;
use registry::{Computer, Registry};

#[derive(Clone)]
struct AppState {
  registry: Registry,
}

#[tokio::main]
async fn main() {
  let state = AppState {
    registry: Arc::new(RwLock::new(HashMap::new())),
  };

  let app = Router::new()
    .route("/ws/{name}", get(ws_handler))
    .route("/computers", get(list_computers))
    .route("/call/{name}", post(call_computer))
    .route("/programs", get(list_programs))
    .route("/run/{computer}/{program}", post(run_program))
    .with_state(state);

  let addr = "0.0.0.0:8080";
  let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
  println!("rpc server listening on {addr}");
  axum::serve(listener, app).await.unwrap();
}

async fn ws_handler(
  ws: WebSocketUpgrade,
  Path(name): Path<String>,
  State(state): State<AppState>,
) -> impl IntoResponse {
  ws.on_upgrade(move |socket| handle_socket(socket, name, state))
}

/// Owns one computer's connection for its lifetime: forwards outgoing calls
/// to the socket, routes incoming responses back to their `call()`, and on
/// disconnect fails any calls still waiting so they don't hang forever.
async fn handle_socket(socket: WebSocket, name: String, state: AppState) {
  let (mut sink, mut stream) = socket.split();
  let (tx, mut rx) = mpsc::unbounded_channel::<String>();
  let computer = Arc::new(Computer::new(tx));

  state
    .registry
    .write()
    .await
    .insert(name.clone(), computer.clone());
  println!("computer '{name}' connected");

  let writer = tokio::spawn(async move {
    while let Some(text) = rx.recv().await {
      if sink.send(Message::Text(text.into())).await.is_err() {
        break;
      }
    }
  });

  while let Some(Ok(message)) = stream.next().await {
    if let Message::Text(text) = message
      && let Ok(response) = serde_json::from_str::<Response>(&text)
    {
      computer.resolve(response).await;
    }
  }

  writer.abort();
  computer.fail_all().await;
  state.registry.write().await.remove(&name);
  println!("computer '{name}' disconnected");
}

async fn list_computers(State(state): State<AppState>) -> impl IntoResponse {
  let names: Vec<String> =
    state.registry.read().await.keys().cloned().collect();
  Json(names)
}

#[derive(Deserialize)]
struct CallBody {
  method: String,
  #[serde(default)]
  args: Value,
}

/// `POST /call/<name>` with `{"method": "turtle.forward", "args": []}` —
/// an HTTP-facing example of the same `Computer::call` other Rust code
/// would use directly. Useful for a quick `curl` round-trip test.
async fn call_computer(
  Path(name): Path<String>,
  State(state): State<AppState>,
  Json(body): Json<CallBody>,
) -> impl IntoResponse {
  let computer = state.registry.read().await.get(&name).cloned();

  let Some(computer) = computer else {
    return (
      StatusCode::NOT_FOUND,
      format!("no computer named '{name}' connected"),
    )
      .into_response();
  };

  let args = if body.args.is_null() {
    Value::Array(vec![])
  } else {
    body.args
  };

  match computer.call(&body.method, args).await {
    Ok(value) => Json(serde_json::json!({ "result": value })).into_response(),
    Err(err) => (StatusCode::BAD_GATEWAY, err.to_string()).into_response(),
  }
}

async fn list_programs() -> impl IntoResponse {
  Json(pkgs::NAMES)
}

/// `POST /run/<computer>/<program>` runs one of the programs in `src/pkgs`
/// against a connected computer, e.g. `/run/turtle-1/chest-scan`.
async fn run_program(
  Path((computer_name, program_name)): Path<(String, String)>,
  State(state): State<AppState>,
) -> impl IntoResponse {
  let computer = state.registry.read().await.get(&computer_name).cloned();

  let Some(computer) = computer else {
    return (
      StatusCode::NOT_FOUND,
      format!("no computer named '{computer_name}' connected"),
    )
      .into_response();
  };

  let Some(program) = pkgs::find(&program_name) else {
    return (
      StatusCode::NOT_FOUND,
      format!("no program named '{program_name}'"),
    )
      .into_response();
  };

  match program(&computer).await {
    Ok(summary) => {
      Json(serde_json::json!({ "summary": summary })).into_response()
    }
    Err(err) => (StatusCode::BAD_GATEWAY, err.to_string()).into_response(),
  }
}
