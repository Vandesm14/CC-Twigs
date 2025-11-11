local tbl = require "lib.table"
local pretty = require "cc.pretty"

local lib = {}

--- @alias Record { name: string, nbt: string, count: number, chest_id: number, slot_id: number }
--- @alias Cache { input: Record[], storage: Record[], output: Record[], maxCounts: table<string, number> }

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

--- Chest ID = `minecraft:barrel_{id}`
--- comment
--- @param id number
--- @return string
function lib.expandChestID(id)
  return "minecraft:barrel_" .. id
end

--- Performs live scanning of peripherals
--- @param filter number[]|nil Filter chest IDs.
--- @param empty boolean|nil Whether to include empty slots
--- @return table<number, Record>, table<string, number>
function lib.scanItemsLive(filter, empty)
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

--- Saves cache data to slots.json
--- @param cache Cache
function lib.saveCache(cache)
  local json = textutils.serializeJSON(cache, false)
  local file = fs.open("slots.json", "w")
  if file ~= nil then
    file.write(json)
    file.close()
  else
    error("Unable to create slots.json file.")
  end

  print("cache saved.")
end

--- Loads entire cache data from slots.json
--- @return Cache
function lib.loadCache()
  if not fs.exists("slots.json") then
    error("Cache file slots.json not found. Please run 'wh scan' first.")
  end

  local file = fs.open("slots.json", "r")
  if file == nil then
    error("Unable to read slots.json file.")
  end

  local content = file.readAll()
  file.close()

  local cache = textutils.unserializeJSON(content)
  if cache == nil then
    error("Invalid slots.json format.")
  end

  print("cache loaded.")

  return cache
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

--- @param cache Cache
--- @param order Order
function lib.applyOrder(cache, order)
  local chest = peripheral.wrap(lib.expandChestID(order.to.chest_id))
  if chest ~= nil then
    local success, _ = pcall(
      chest.pullItems,
      lib.expandChestID(order.from.chest_id),
      order.from.slot_id,
      order.count,
      order.to.slot_id
    )
    if not success then
      error("transfer failed: " .. pretty.render(pretty.pretty(order)))
    end
  else
    error("failed to find chest: " .. lib.expandChestID(order.to.chest_id))
  end

  --- @type Record[]|nil
  local from_slots = nil
  --- @type Record[]|nil
  local to_slots = nil
  if order.type == "input" then
    from_slots = cache.input
    to_slots = cache.storage
  elseif order.type == "output" then
    from_slots = cache.storage
    to_slots = cache.output
  end

  --- @type Record|nil
  local from = nil
  --- @type Record|nil
  local to = nil
  if from_slots ~= nil and to_slots ~= nil then
    for _, record in pairs(from_slots) do
      if record.chest_id == order.from.chest_id and record.slot_id == order.from.slot_id then
        from = record
        break
      end
    end

    for _, record in pairs(to_slots) do
      if record.chest_id == order.to.chest_id and record.slot_id == order.to.slot_id then
        to = record
        break
      end
    end
  else
    error("unreachable")
  end

  if from ~= nil and to ~= nil then
    -- print("from: " .. order.from.chest_id .. " " .. order.from.slot_id .. " (" .. -order.count .. ")")
    -- print("to: " .. order.to.chest_id .. " " .. order.to.slot_id .. " (" .. order.count .. ")")
    from.count = from.count - order.count
    to.count = to.count + order.count
    to.name = order.item
  else
    error("transaction failed: " .. pretty.render(pretty.pretty(order)))
  end
end

return lib
