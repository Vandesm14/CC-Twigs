local tbl = {}

function tbl.contains(tbl, item)
  for _, el in ipairs(tbl) do
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

return tbl
