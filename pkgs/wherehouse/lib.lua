local lib = {}

--- @param chest Inventory
--- @return string|nil
function lib.getName(chest)
  -- Run through each item in the chest
  for slot, item in pairs(chest.list()) do
    local name, count = item.name, item.count
    local nbt = chest.getItemDetail(slot)

    if nbt ~= nil then
      if nbt.name == "computercraft:disk" then
        return nbt.displayName
      end
    end
  end

  return nil
end

--- @class Position
--- @field x number
--- @field y number
--- @field z number
Position = {}

--- @class Chest
--- @field name string
--- @field items itemList
--- @field position Position
Chest = {}

-- Chest ID = `c{x}_{y}_{z}`
local function parseCoordinates(str)
  local x, y, z = str:match("c(%d+)_(%d+)_(%d+)")
  return { x = tonumber(x), y = tonumber(y), z = tonumber(z) }
end

function lib.scanItems()
  --- @type table<number, Chest>
  local chests = {}

  -- Scan each chest for items, until we hit the end-stop
  --- @diagnostic disable-next-line: param-type-mismatch
  for _, chest in ipairs({ peripheral.find("minecraft:chest") }) do
    --- @cast chest Inventory

    if chest ~= nil then
      local name = lib.getName(chest)
      if name ~= nil then
        table.insert(chests, {
          name = name,
          items = chest.list(),
          position = parseCoordinates(name)
        })
      end
    end
  end

  return chests
end

return lib
