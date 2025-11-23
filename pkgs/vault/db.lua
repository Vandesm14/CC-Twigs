local tbl = require "/pkgs.lib.table"

local db = {}

--- @alias Slot { name: string, nbt: string, count: number }
--- @alias Inventories table<string, Slot[]>
--- @alias Transfer { item: string, count: number, from_chest: string, from_slot: number, to_chest: string, to_slot: number }
--- @alias Database { inventories: Inventories, maxCounts: table<string, number>, counts: table<string, number> }

--- Create a new Database instance.
--- @return Database
function db.new()
  return {
    inventories = {},
    empty = {},
    maxCounts = {},
    counts = {},
  }
end

--- Scan current slot data into Database.
--- @param database Database
--- @param filter string[]|nil Filter chest IDs.
function db.scanInventories(database, filter)
  --- @type Inventories
  local inventories = {}

  local names = peripheral.getNames()
  for _, name in pairs(names) do
    local chest = peripheral.wrap(name)
    -- If not nil and is an inventory (has `.list`).
    if chest ~= nil and chest.list ~= nil then
      local slots = {}

      -- If no filter or is within our filter.
      if filter == nil or (filter ~= nil and tbl.contains(filter, name)) then
        local list = chest.list()
        for slot_id = 1, chest.size(), 1 do
          local item = list[slot_id]
          if item ~= nil then
            table.insert(slots, {
              name = item.name,
              nbt = item.nbt,
              count = item.count,
            })

            if database.maxCounts[item.name] == nil then
              local detail = chest.getItemDetail(slot_id)
              if detail ~= nil then
                database.maxCounts[item.name] = detail.maxCount
              end
            end
          else
            table.insert(slots, {
              name = "",
              nbt = "",
              count = 0,
            })
          end
        end
      end

      inventories[name] = slots
    end
  end

  tbl.merge(database.inventories, inventories)
end

---comment
---@param database Database
---@param chest_id string
---@param slot_id number
---@return Slot|nil
function db.querySlot(database, chest_id, slot_id)
  local slot = database.inventories[chest_id][slot_id]
  if slot and slot.count == 0 then
    return nil
  end

  return slot
end

--- Transfer count from an inventory into another inventory.
--- @param count number count of items to transfer
--- @param from_chest string the name of the inventory to transfer from
--- @param from_slot number the slot of the inventory to transfer from
--- @param to_chest string the name of the inventory to transfer to
--- @param to_slot number the slot of the inventory to transfer to
--- @return boolean success
function db.transfer(count, from_chest, from_slot, to_chest, to_slot)
  local destination = peripheral.wrap(to_chest)
  if destination ~= nil then
    local success, _ = pcall(
      destination.pullItems,
      from_chest,
      from_slot,
      count,
      to_slot
    )

    return success
  end

  return false
end

return db
