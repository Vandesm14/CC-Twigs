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

function tbl.merge(tbl1, tbl2)
  local tbl = {}
  for key, val in pairs(tbl1) do
    tbl[key] = val
  end
  for key, val in pairs(tbl2) do
    tbl[key] = val
  end

  return tbl
end

return tbl
