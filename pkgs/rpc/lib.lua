local lib = {}

--- Resolves a dotted path like "turtle.forward" or "redstone.setOutput"
--- against `root` (default `_G`), walking one table field per segment.
--- Works for any global/API/peripheral table, not just a fixed list.
--- @param path string
--- @param root table|nil
--- @return any
function lib.resolve(path, root)
  local value = root or _G
  for segment in path:gmatch("[^.]+") do
    if type(value) ~= "table" then return nil end
    value = value[segment]
  end
  return value
end

--- @param id number
--- @param result any
--- @return string
function lib.encodeResult(id, result)
  return textutils.serialiseJSON({ id = id, result = result })
end

--- @param id number
--- @param message string
--- @return string
function lib.encodeError(id, message)
  return textutils.serialiseJSON({ id = id, error = message })
end

--- Decodes an incoming `{"id": ..., "method": ..., "args": [...]}` message.
--- Returns nil if `json` isn't valid JSON or is missing `id`/`method`.
--- @param json string
--- @return table|nil
function lib.decodeRequest(json)
  local ok, decoded = pcall(textutils.unserialiseJSON, json)
  if not ok or type(decoded) ~= "table" then return nil end
  if type(decoded.id) ~= "number" or type(decoded.method) ~= "string" then
    return nil
  end
  return decoded
end

--- Resolves `method` and calls it with `args` via pcall.
--- Only the function's first return value is kept (JSON has no room for
--- Lua's multi-return) -- layer a typed wrapper on top if a call needs more.
--- @param method string
--- @param args table
--- @return boolean ok
--- @return any resultOrErrorMessage
function lib.dispatch(method, args)
  local fn = lib.resolve(method)
  if type(fn) ~= "function" then
    return false, "no such method: " .. method
  end
  return pcall(fn, table.unpack(args))
end

return lib
