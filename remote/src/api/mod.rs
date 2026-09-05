pub mod peripheral;

#[derive(thiserror::Error, Debug)]
pub enum APIError {
  #[error("json error: {0}")]
  Serde(#[from] serde_json::Error),
  #[error("call error: {0}")]
  Call(#[from] crate::registry::CallError),
}
