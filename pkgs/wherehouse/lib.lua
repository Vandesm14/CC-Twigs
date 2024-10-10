local pretty = require "cc.pretty"

local lib = {}

--- @param chest Inventory
--- @return string|nil
local function getName(chest)
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

--- @class Chest
--- @field name string
--- @field items itemList
Chest = {}

function lib.scanItems()
  --- @type table<number, Chest>
  local chests = {}

  -- Scan each chest for items, until we hit the end-stop
  --- @diagnostic disable-next-line: param-type-mismatch
  for i, chest in ipairs({ peripheral.find("minecraft:chest") }) do
    --- @cast chest Inventory

    if chest ~= nil then
      local name = getName(chest)
      if name ~= nil then
        table.insert(chests, {
          name = name,
          items = chest.list()
        })
      end
    end
  end

  pretty.pretty_print(chests)
end

return lib
