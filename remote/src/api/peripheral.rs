use serde_json::json;

use crate::{api::APIError, registry::Computer};

pub async fn get_names(computer: &Computer) -> Result<Vec<String>, APIError> {
  Ok(serde_json::from_value(
    computer.call("peripheral.getNames", json!([])).await?,
  )?)
}
