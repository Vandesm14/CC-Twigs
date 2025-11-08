local tbl = require "lib.table"

local lib = {}

--- @class Chest
--- @field id number
--- @field items ccTweaked.peripherals.inventory.itemList
--- @field inventory ccTweaked.peripherals.Inventory
Chest = {}

--- @class StatusMessage
--- @field type "status"
--- @field value { name: string, fuel: number }
StatusMessage = {}

--- @class AvailMessage
--- @field type "avail"
--- @field value nil
StatusMessage = {}

--- @class OrderMessage
--- @field type "order"
--- @field value Order
OrderMessage = {}

--- @alias Message StatusMessage|OrderMessage|AvailMessage

--- Chest ID = `minecraft:barrel_{id}`
--- comment
--- @param name string
--- @return number|nil
function lib.chestID(name)
  if name ~= nil then
    local id = name:match("minecraft:barrel_(%d+)")
    if id ~= nil then
      return tonumber(id)
    end
  end

  return nil
end

--- @param filter number[]|nil Filter chest IDs.
function lib.scanItems(filter)
  --- @type table<number, Chest>
  local chests = {}

  -- Scan each chest for items, until we hit the end-stop
  --- @diagnostic disable-next-line: param-type-mismatch
  peripheral.find("minecraft:barrel", function(name, chest)
    --- @cast chest ccTweaked.peripherals.Inventory

    if chest ~= nil then
      local id = lib.chestID(name)
      if filter == nil or (filter ~= nil and tbl.contains(filter, id)) then
        print("Scanned chest '" .. name .. "'...")

        if id ~= nil then
          table.insert(chests, {
            id = id,
            items = chest.list(),
            inventory = chest
          })
        end
      end
    end

    return true
  end)

  return chests
end

return lib
