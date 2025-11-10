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

  -- Load cached maxCounts from file if it exists
  if fs.exists("maxcount.lua") then
    local file = fs.open("maxcount.lua", "r")
    if file ~= nil then
      local content = file.readAll()
      file.close()
      local loaded = textutils.unserialize(content)
      if loaded ~= nil and type(loaded) == "table" then
        maxCounts = loaded
      end
    end
  end

  local names = peripheral.getNames()
  for _, name in pairs(names) do
    local chest = peripheral.wrap(name)
    if chest ~= nil then
      local chest_id = lib.chestID(name)
      if filter == nil or (filter ~= nil and tbl.contains(filter, chest_id)) then
        if chest_id ~= nil then
          local list = chest.list()
          if not empty then
            for slot_id, item in pairs(list) do
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
            end
          else
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

  -- Save maxCounts to file
  local file = fs.open("maxcount.lua", "w")
  if file ~= nil then
    file.write(textutils.serialize(maxCounts))
    file.close()
  end

  return records, maxCounts
end

--- @param maxCount number
--- @param slots Record[]
--- @param item Record
--- @return { slot: ChestSlot, count: number }|nil
function lib.findInputPartialSlot(maxCount, slots, item)
  for _, record in pairs(slots) do
    if maxCount ~= nil and record.name == item.name and record.nbt == item.nbt and record.count < maxCount then
      return {
        slot = {
          slot_id = record.slot_id,
          chest_id = record.chest_id,
        },
        count = record.count
      }
    end
  end

  return nil
end

--- @param maxCount number
--- @param slots Record[]
--- @param item string
--- @return { slot: ChestSlot, count: number }|nil
function lib.findOutputPartialSlot(maxCount, slots, item)
  for _, record in pairs(slots) do
    if maxCount ~= nil and record.name == item and record.count < maxCount and record.count > 0 then
      return {
        slot = {
          slot_id = record.slot_id,
          chest_id = record.chest_id,
        },
        count = record.count
      }
    end
  end

  return nil
end

--- @param slots Record[]
--- @return ChestSlot|nil
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

--- @param maxCount number
--- @param slots Record[]
--- @param item string
--- @return ChestSlot|nil
function lib.findFullSlot(maxCount, slots, item)
  for _, record in pairs(slots) do
    if maxCount ~= nil and record.name == item and record.count == maxCount then
      return {
        slot_id = record.slot_id,
        chest_id = record.chest_id,
      }
    end
  end

  return nil
end

--- @param slots Record[]
--- @param order Order
function lib.applyOrder(slots, order)
  if order.type == "input" then
    for i, record in pairs(slots) do
      if record.chest_id == order.to.chest_id and record.slot_id == order.to.slot_id then
        local record = slots[i]
        if record ~= nil then
          record.count = record.count + order.count
        end
        return
      end
    end
  elseif order.type == "output" then
    for i, record in pairs(slots) do
      if record.chest_id == order.from.chest_id and record.slot_id == order.from.slot_id then
        local record = slots[i]
        if record ~= nil then
          record.count = record.count - order.count
        end
        return
      end
    end
  end
end

return lib
