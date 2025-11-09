local tbl = require "lib.table"

local lib = {}

--- @alias Record { name: string, nbt: string, count: number, chest_id: number, slot_id: number }

--- @alias StatusMessage { type: `status`, value: { name: string, fuel: number } }
--- @alias AvailMessage { type: `avail`, value: nil }
--- @alias OrderMessage { type: `order`, value: Order }
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
--- @param empty boolean|nil Whether to include empty slots
--- @return table<number, Record>, table<string, number>
function lib.scanItems(filter, empty)
  --- @type table<number, Record>
  local records = {}
  --- @type table<string, number>
  local maxCounts = {}

  local names = peripheral.getNames()
  for _, name in pairs(names) do
    local chest = peripheral.wrap(name)
    if chest ~= nil then
      local chest_id = lib.chestID(name)
      if filter == nil or (filter ~= nil and tbl.contains(filter, chest_id)) then
        if chest_id ~= nil then
          local list = chest.list()
          for slot_id = 1, chest.size(), 1 do
            local item = list[slot_id]
            if item ~= nil then
              table.insert(records, {
                name = item.name,
                nbt = item.nbt,
                count = item.count,
                slot_id = slot_id,
                chest_id = chest_id,
              })

              if maxCounts[item.name] == nil then
                local detail = chest.getItemDetail(slot_id)
                if detail ~= nil then
                  maxCounts[item.name] = detail.maxCount
                end
              end
            else
              if empty then
                table.insert(records, {
                  name = "",
                  nbt = "",
                  count = 0,
                  slot_id = slot_id,
                  chest_id = chest_id,
                })
              end
            end
          end
        end
      end
    end
  end

  return records, maxCounts
end

--- @param maxCounts table<string, number>
--- @param slots Record[]
--- @param item Record
--- @return Record|nil
function lib.findExistingSlot(maxCounts, slots, item)
  for _, record in pairs(slots) do
    local maxCount = maxCounts[item.name]
    if maxCount ~= nil and record.name == item.name and record.nbt == item.nbt and record.count < maxCount then
      -- print("can use slot " .. record.slot_id .. " of " .. record.chest_id)
      local count = item.count
      if (record.count + item.count) > maxCount then
        count = maxCount - record.count
      end
      return {
        name = item.name,
        nbt = item.nbt,
        count = count,
        slot_id = record.slot_id,
        chest_id = record.chest_id,
      }
    end
  end

  return nil
end

--- @param slots Record[]
--- @return { slot_id: number, chest_id: number }|nil
function lib.findEmptySlot(slots)
  for _, record in pairs(slots) do
    if record.count == 0 then
      return {
        slot_id = record.slot_id,
        chest_id = record.chest_id,
      }
    end
  end

  return nil
end

return lib
