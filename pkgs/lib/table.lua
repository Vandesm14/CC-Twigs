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

return tbl
