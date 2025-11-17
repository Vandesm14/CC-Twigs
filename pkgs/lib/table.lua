local tbl = {}

function tbl.contains(tbl, item)
  for _, el in pairs(tbl) do
    if el == item then
      return true
    end
  end

  return false
end

function tbl.keys(tbl)
  local keys = {}
  for key in pairs(tbl) do
    table.insert(keys, key)
  end
  return keys
end

function tbl.values(tbl)
  local values = {}
  for _, value in pairs(tbl) do
    table.insert(values, value)
  end
  return values
end

function tbl.len(tbl)
  local len = 0
  for _, _ in pairs(tbl) do
    len = len + 1
  end
  return len
end

--- Mutably merges two tables, updating values on the left table from the right.
--- If there is a shared key between both, the value from the right table will
--- be used.
--- @param left table
--- @param right table
function tbl.merge(left, right)
  for key, val in pairs(right) do
    left[key] = val
  end
end

--- Recursively compares two values for deep equality.
--- Handles tables, primitives, and nil values.
--- @param a any
--- @param b any
--- @return boolean
function tbl.deepEqual(a, b)
  -- Track visited table pairs to prevent infinite recursion on circular references
  local visited = {}

  local function compare(a, b)
    -- If they're the same reference, they're equal
    if a == b then
      return true
    end

    -- If either is nil, they're only equal if both are nil
    if a == nil or b == nil then
      return false
    end

    -- Check if types match
    local typeA = type(a)
    local typeB = type(b)
    if typeA ~= typeB then
      return false
    end

    -- For non-table types, use direct comparison
    if typeA ~= "table" then
      return a == b
    end

    -- For tables, check if we've already compared this pair
    -- Use a simple key based on table identity
    local aKey = tostring(a):match("table: (%w+)")
    local bKey = tostring(b):match("table: (%w+)")
    local pairKey = (aKey or "a") .. ":" .. (bKey or "b")

    -- If we've seen this pair before, assume equal to break cycles
    if visited[pairKey] then
      return true
    end
    visited[pairKey] = true

    -- Collect all keys from both tables
    local keys = {}
    for k in pairs(a) do
      keys[k] = true
    end
    for k in pairs(b) do
      keys[k] = true
    end

    -- Compare each key
    for k in pairs(keys) do
      local v1 = a[k]
      local v2 = b[k]

      -- Recursively compare values
      if not compare(v1, v2) then
        return false
      end
    end

    return true
  end

  return compare(a, b)
end

return tbl
