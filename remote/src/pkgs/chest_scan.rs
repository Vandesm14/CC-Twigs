//! Demo program: scans every connected inventory peripheral (chest,
//! barrel, ...), tallies item counts across all of them, and prints the
//! top 5 items plus the scanned peripheral names back on the computer.

use std::collections::HashMap;

use serde_json::{Value, json};

use crate::{
  api::peripheral,
  registry::{CallError, Computer},
};

pub async fn run(computer: &Computer) -> Result<String, CallError> {
  let names = peripheral::get_names(computer).await.unwrap_or_default();

  let mut chest_names = Vec::new();
  let mut totals: HashMap<String, i64> = HashMap::new();

  for name in &names {
    let is_inventory = computer
      .call("peripheral.hasType", json!([name, "inventory"]))
      .await?;
    if is_inventory != Value::Bool(true) {
      continue;
    }

    chest_names.push(name.clone());

    let list = computer
      .call("peripheral.call", json!([name, "list"]))
      .await?;
    for (item_name, count) in extract_items(&list) {
      *totals.entry(item_name).or_insert(0) += count;
    }
  }

  let mut top: Vec<(String, i64)> = totals.into_iter().collect();
  top.sort_by_key(|(_, count)| std::cmp::Reverse(*count));
  top.truncate(5);

  computer
    .call(
      "print",
      json!([format!(
        "Connected chests ({}): {}",
        chest_names.len(),
        if chest_names.is_empty() {
          "none".to_string()
        } else {
          chest_names.join(", ")
        }
      )]),
    )
    .await?;

  computer.call("print", json!(["Top 5 items:"])).await?;
  if top.is_empty() {
    computer.call("print", json!(["  (none found)"])).await?;
  }
  for (item_name, count) in &top {
    computer
      .call("print", json!([format!("  {count} x {item_name}")]))
      .await?;
  }

  Ok(format!(
    "scanned {} chest(s), {} unique item(s)",
    chest_names.len(),
    top.len()
  ))
}

/// `peripheral.call(name, "list")` returns a Lua table keyed by slot
/// number. `textutils.serialiseJSON` encodes that as a JSON object when
/// slots are sparse (the common case -- empty slots are omitted), but as
/// an array when every slot happens to be full and contiguous from 1 --
/// so accept either.
fn extract_items(list: &Value) -> Vec<(String, i64)> {
  match list {
    Value::Object(map) => map.values().filter_map(item_from_value).collect(),
    Value::Array(items) => items.iter().filter_map(item_from_value).collect(),
    _ => Vec::new(),
  }
}

fn item_from_value(value: &Value) -> Option<(String, i64)> {
  let name = value.get("name")?.as_str()?.to_string();
  let count = value.get("count").and_then(Value::as_i64).unwrap_or(0);
  Some((name, count))
}
