local tbl = require "/pkgs.lib.table"

local db = {}

--- @alias Slot { name: string, nbt: string, count: number, chest_id: string, slot_id: number }
--- @alias EmptySlot { chest_id: string, slot_id: number }
--- @alias Database { slots: Slot[], empty: EmptySlot[], maxCounts: table<string, number>, counts: table<string, number> }

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
  --- @type Slot[]
  local slots = {}
  --- @type EmptySlot[]
  local empty_slots = {}

  local names = peripheral.getNames()
  for _, name in pairs(names) do
    local chest = peripheral.wrap(name)
    if chest ~= nil and chest.list ~= nil then
      if filter == nil or (filter ~= nil and tbl.contains(filter, name)) then
        if name ~= nil then
          local list = chest.list()
          for slot_id = 1, chest.size(), 1 do
            local item = list[slot_id]
            if item ~= nil then
              table.insert(slots, {
                name = item.name,
                nbt = item.nbt,
                count = item.count,
                slot_id = slot_id,
                chest_id = name,
              })

              if database.maxCounts[item.name] == nil then
                local detail = chest.getItemDetail(slot_id)
                if detail ~= nil then
                  database.maxCounts[item.name] = detail.maxCount
                end
              end
            else
              table.insert(empty_slots, {
                slot_id = slot_id,
                chest_id = name,
              })
            end
          end
        end
      end
    end
  end

  tbl.merge(database.slots, slots)
  tbl.merge(database.empty, empty_slots)
end

return db
