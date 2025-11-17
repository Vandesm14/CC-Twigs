local tbl = require "/pkgs.lib.table"

local db = {}

--- @alias Slot { name: string, nbt: string, count: number }
--- @alias Slots table<string, Slot[]>
--- @alias Database { slots: Slots, maxCounts: table<string, number>, counts: table<string, number> }

--- Create a new Database instance.
--- @return Database
function db.new()
  return {
    slots = {},
    empty = {},
    maxCounts = {},
    counts = {},
  }
end

--- Scan current slot data into Database.
--- @param database Database
--- @param filter number[]|nil Filter chest IDs.
function db.scanSlots(database, filter)
  --- @type Slots
  local slots = {}

  local names = peripheral.getNames()
  for _, name in pairs(names) do
    local chest = peripheral.wrap(name)
    -- If not nil and is an inventory (has `.list`).
    if chest ~= nil and chest.list ~= nil then
      local coll = {}

      -- If no filter or is within our filter.
      if filter == nil or (filter ~= nil and tbl.contains(filter, name)) then
        local list = chest.list()
        for slot_id = 1, chest.size(), 1 do
          local item = list[slot_id]
          if item ~= nil then
            table.insert(coll, {
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
            table.insert(coll, {
              name = "",
              nbt = "",
              count = 0,
            })
          end
        end
      end

      slots[name] = coll
    end
  end

  tbl.merge(database.slots, slots)
end

---comment
---@param database Database
---@param chest_id string
---@param slot_id number
---@return Slot|nil
function db.querySlot(database, chest_id, slot_id)
  local slot = database.slots[chest_id][slot_id]
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
