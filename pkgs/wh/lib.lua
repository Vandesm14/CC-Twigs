local tbl = require "lib.table"
local pretty = require "cc.pretty"
local branches = require "wh.branches"
local str = require "lib.str"

local lib = {}

--- @alias Record { name: string, nbt: string, count: number, chest_id: number, slot_id: number }
--- @alias Cache { input: Record[], storage: Record[], output: Record[], maxCounts: table<string, number> }

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
--- @param maxCounts table<string, number>
--- @param filter number[]|nil Filter chest IDs.
--- @param empty boolean|nil Whether to include empty slots
--- @return table<number, Record>, table<string, number>
function lib.scanItems(maxCounts, filter, empty)
  --- @type table<number, Record>
  local records = {}

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
                maxCounts[item.name] = chest.getItemLimit(slot_id)
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
                  maxCounts[item.name] = chest.getItemLimit(slot_id)
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

    -- Log transaction to CSV (only for transactions involving storage)
    if order.type == "input" or order.type == "output" then
      lib.logTransaction(order, cache)
    end
  else
    error("transaction failed: " .. pretty.render(pretty.pretty(order)))
  end
end

--- @param cache Cache
function lib.pull(cache)
  local storage_slots = cache.storage
  local maxCounts = cache.maxCounts

  print("Scanning inputs...")
  local input_slots, _ = lib.scanItems(maxCounts, branches.input)
  cache.input = input_slots

  print("Applying actions...")
  for _, item in pairs(input_slots) do
    local maxCount = maxCounts[item.name]
    while item.count > 0 do
      --- @type Order|nil
      local order = nil
      if maxCount ~= nil and item.count < maxCount then
        local result = lib.findInputPartialSlot(maxCount, storage_slots, item)

        if result ~= nil then
          local count = item.count
          if (result.count + item.count) > maxCount then
            count = maxCount - result.count
          end

          order = {
            item = item.name,
            count = count,
            from = { chest_id = item.chest_id, slot_id = item.slot_id },
            to = { chest_id = result.slot.chest_id, slot_id = result.slot.slot_id },
            type = "input"
          }
        end
      end

      if order == nil then
        local result = lib.findEmptySlot(storage_slots)
        if result ~= nil then
          order = {
            item = item.name,
            count = item.count,
            from = { chest_id = item.chest_id, slot_id = item.slot_id },
            to = { chest_id = result.chest_id, slot_id = result.slot_id },
            type = "input"
          }
        end
      end

      if order ~= nil then
        lib.applyOrder(cache, order)
        item.count = item.count - order.count
      end
    end
  end
end

--- @param cache Cache
--- @param query string
--- @param amount number
function lib.order(cache, query, amount)
  local storage_slots = cache.storage
  local maxCounts = cache.maxCounts

  print("Scanning outputs...")
  local output_slots, _ = lib.scanItems(maxCounts, branches.output, true)
  cache.output = output_slots

  -- Determine if we're doing exact full name match or post-colon match
  local isFullNameQuery = str.contains(query, ":")

  local name = nil
  for _, key in pairs(tbl.keys(maxCounts)) do
    if name ~= nil then
      break
    end

    if isFullNameQuery then
      -- Match the full name exactly (e.g., "minecraft:cobblestone")
      if str.equals(key, query) then
        name = key
      end
    else
      -- Match the post-colon part exactly (e.g., "cobblestone" matches "minecraft:cobblestone")
      if str.endsWith(key, ":" .. query) then
        name = key
      end
    end
  end

  if name == nil then
    error("No matches for \"" .. query .. "\"")
  end

  local maxCount = maxCounts[name]
  local amountLeft = amount

  print("Applying actions...")
  while amountLeft > 0 do
    local output = lib.findEmptySlot(output_slots)
    if output == nil then
      print("no more space in output")
      break
    end

    --- @type Order|nil
    local order = nil

    -- If amountLeft is a multiple of maxCount, skip partial stacks and grab full stacks directly
    if amountLeft % maxCount ~= 0 then
      local result = lib.findOutputPartialSlot(maxCount, storage_slots, name)
      if result ~= nil then
        local count = amountLeft
        if result.count < amountLeft then
          count = result.count
        end

        order = {
          item = name,
          count = count,
          from = { chest_id = result.slot.chest_id, slot_id = result.slot.slot_id },
          to = { chest_id = output.chest_id, slot_id = output.slot_id },
          type = "output"
        }
      end
    end

    if order == nil then
      local result = lib.findFullSlot(maxCount, storage_slots, name)
      if result ~= nil then
        local count = amountLeft
        if maxCount < amountLeft then
          count = maxCount
        end

        order = {
          item = name,
          count = count,
          from = { chest_id = result.chest_id, slot_id = result.slot_id },
          to = { chest_id = output.chest_id, slot_id = output.slot_id },
          type = "output"
        }
      end
    end

    if order ~= nil then
      lib.applyOrder(cache, order)
      amountLeft = amountLeft - order.count
    else
      break
    end
  end
end

--- @param items Record[]
--- @param table table
local function countItems(items, table)
  -- Run through each item in the chest
  for _, item in pairs(items) do
    local name, count = item.name, item.count

    -- Update or set the entry
    if table[name] ~= nil then
      table[name] = table[name] + count
    else
      table[name] = count
    end
  end
end

--- @param cache Cache
--- @param query string|nil
--- @return string[]
function lib.ls(cache, query)
  local lines = {}
  local items = {}

  -- Load storage from cache
  --- @diagnostic disable-next-line: param-type-mismatch
  countItems(cache.storage, items)

  if query ~= nil and type(query) == "string" then
    table.insert(lines, "Items (filtered by '" .. query .. "'):")
  else
    table.insert(lines, "Items:")
  end
  for name, count in pairs(items) do
    if query ~= nil and type(query) == "string" then
      if string.find(name, query) ~= nil then
        table.insert(lines, name .. ": " .. count)
      end
    else
      table.insert(lines, name .. ": " .. count)
    end
  end

  return lines
end

--- Returns the total and used capacity (total, used).
--- @return number
--- @return number
function lib.capacity(cache)
  local total = 0
  local used = 0

  --- @diagnostic disable-next-line: param-type-mismatch
  for _, slot in pairs(cache.storage) do
    total = total + 1
    if slot.count > 0 then
      used = used + 1
    end
  end

  return total, used
end

--- @param cache Cache
function lib.scanAll(cache)
  print("Scanning inputs...")
  local input_slots, input_maxCounts = lib.scanItems({}, branches.input, true)

  print("Scanning storage...")
  local storage_slots, storage_maxCounts = lib.scanItems({}, branches.storage, true)

  print("Scanning outputs...")
  local output_slots, output_maxCounts = lib.scanItems({}, branches.output, true)

  local maxCounts = tbl.merge(input_maxCounts, tbl.merge(storage_maxCounts, output_maxCounts))

  cache.input = input_slots
  cache.storage = storage_slots
  cache.output = output_slots
  cache.maxCounts = maxCounts
end

--- @return Cache
function lib.loadOrInitCache()
  -- Initialize cache if it doesn't exist
  if not fs.exists("slots.json") then
    print("Cache not found. Running initial scan...")
    print("Scanning inputs...")
    local input_slots, input_maxCounts = lib.scanItems({}, branches.input, true)

    print("Scanning storage...")
    local storage_slots, storage_maxCounts = lib.scanItems({}, branches.storage, true)

    print("Scanning outputs...")
    local output_slots, output_maxCounts = lib.scanItems({}, branches.output, true)

    local maxCounts = tbl.merge(input_maxCounts, tbl.merge(storage_maxCounts, output_maxCounts))

    local cache = {
      input = input_slots,
      storage = storage_slots,
      output = output_slots,
      maxCounts = maxCounts
    }
    lib.saveCache(cache)
    print("Initial cache created successfully (slots.json)")
    print("")
  end

  return lib.loadCache()
end

--- @param cache Cache
--- @param item string
--- @return number
function lib.countItem(cache, item)
  local count = 0
  for _, record in pairs(cache) do
    if record.name == item then
      count = count + record.count
    end
  end

  return count
end

--- Logs a transaction to transactions.csv
--- @param order Order
--- @param cache Cache
function lib.logTransaction(order, cache)
  local csvFile = "transactions.csv"
  local fileExists = fs.exists(csvFile)

  local file = fs.open(csvFile, "a")
  if file == nil then
    error("Unable to open transactions.csv for writing.")
  end

  -- Initialize CSV with headers if file doesn't exist
  if not fileExists then
    file.writeLine("time,label,item,amount,balance")
  end

  -- Get current time (Unix timestamp)
  local time = os.time("ingame")

  -- Get computer label (or ID if no label)
  local label = os.getComputerLabel()
  if label == nil or label == "" then
    label = "computer_" .. tostring(os.getComputerID())
  end

  -- Determine amount: positive for input (items added to storage), negative for output (items removed from storage)
  local amount = order.count
  if order.type == "output" then
    amount = -amount
  end

  -- Get balance using lib.countItem
  local balance = lib.countItem(cache.storage, order.item)

  -- Write transaction line
  file.writeLine(time .. "," .. label .. "," .. order.item .. "," .. amount .. "," .. balance)

  file.close()
end

return lib
