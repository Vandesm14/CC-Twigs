local pretty = require "cc.pretty"
local Order = require "wh.order"
local lib = require "wh.lib"
local Queue = require "wh.queue"
local tbl = require "lib.table"
local str = require "lib.str"
local Branches = require "wh.branches"

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

local usage = "Usage: " .. arg[0] .. " <order|ls|capacity|scan|defrag>\n" ..
    "  ls [search]           - List items, optionally filter by substring\n" ..
    "  order <item> <amt> [<item> <amt> ...] - Order items (use short name like 'cobblestone' or full like 'minecraft:cobblestone'). Amount is required.\n" ..
    "  scan                  - Scan and update cache (slots.json) for input, storage, and output slots\n" ..
    "  defrag                - Find items with 2+ partial stacks that can be consolidated"
local command = arg[1]

rednet.open("back")

-- Initialize cache if it doesn't exist
if not fs.exists("slots.json") then
  print("Cache not found. Running initial scan...")
  print("Scanning inputs...")
  local input_slots, input_maxCounts = lib.scanItemsLive({}, tbl.keys(Branches.input), true)

  print("Scanning storage...")
  local storage_slots, storage_maxCounts = lib.scanItemsLive({}, tbl.keys(Branches.storage), true)

  print("Scanning outputs...")
  local output_slots, output_maxCounts = lib.scanItemsLive({}, tbl.keys(Branches.output), true)

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

-- Load cache globally
local cache = lib.loadCache()

--- @return Order[]
local function pull()
  local storage_slots = cache.storage
  local maxCounts = cache.maxCounts

  print("Scanning inputs...")
  local input_slots, _ = lib.scanItemsLive(maxCounts, tbl.keys(Branches.input))
  cache.input = input_slots

  --- @type Order[]
  local orders = {}

  print("Calculating orders...")
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
            actions = Branches.input[item.chest_id] .. Branches.storage[result.slot.chest_id] .. Branches.output["_"],
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
            actions = Branches.input[item.chest_id] .. Branches.storage[result.chest_id] .. Branches.output["_"],
            type = "input"
          }
        end
      end

      if order ~= nil then
        table.insert(orders, order)
        lib.applyOrder(cache, order)
        item.count = item.count - order.count
      end
    end
  end

  return orders
end

--- @param query string
--- @param amount number
--- @return Order[]
local function order(query, amount)
  local storage_slots = cache.storage
  local maxCounts = cache.maxCounts

  print("Scanning outputs...")
  local output_slots, _ = lib.scanItemsLive(maxCounts, tbl.keys(Branches.output), true)
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

  --- @type Order[]
  local orders = {}

  print("Calculating orders...")
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
          actions = Branches.input["_"] .. Branches.storage[result.slot.chest_id] .. Branches.output[output.chest_id],
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
          actions = Branches.input["_"] .. Branches.storage[result.chest_id] .. Branches.output[output.chest_id],
          type = "output"
        }
      end
    end

    if order ~= nil then
      table.insert(orders, order)
      lib.applyOrder(cache, order)
      amountLeft = amountLeft - order.count
    else
      break
    end
  end

  -- if amountLeft > 0 then
  --   error("found only: " .. (amount - amountLeft) .. " " .. name .. " (requested: " .. amount .. ")")
  -- end

  return orders
end

if command == nil then
  printError(usage)
  printError()
  printError("Command must be provided.")
  return
elseif command == "ls" then
  local query = arg[2]

  local file = fs.open("list.txt", "w")
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

  if file ~= nil then
    for _, line in pairs(lines) do
      file.writeLine(line)
      print(line)
    end

    file.close()
  end

  print("")
  print("Open list.txt to view full list.")
elseif command == "pull" then
  local orders = pull()

  -- Save updated cache
  lib.saveCache(cache)
  print("Done.")
elseif command == "order" then
  if arg[2] == nil then
    printError("Usage: " .. arg[0] .. " order <item> <amt> [<item> <amt> ...]")
    printError()
    printError("At least one item and amount must be provided")
    return
  end

  --- @type Order[]
  local allOrders = {}
  local i = 2
  while i <= #arg do
    local query = arg[i]
    local amount = tonumber(arg[i + 1])

    if query == nil or type(query) ~= "string" then
      printError("Usage: " .. arg[0] .. " order <item> <amt> [<item> <amt> ...]")
      printError()
      printError("Item name expected at position " .. (i - 1))
      return
    end

    if amount == nil then
      printError("Usage: " .. arg[0] .. " order <item> <amt> [<item> <amt> ...]")
      printError()
      printError("Amount expected after item '" .. query .. "'")
      return
    end

    local orders = order(query, amount)
    for _, ord in pairs(orders) do
      table.insert(allOrders, ord)
    end

    i = i + 2
  end

  -- Save updated cache
  lib.saveCache(cache)
  print("Done.")
elseif command == "capacity" then
  local capacity = 0
  local used = 0

  --- @diagnostic disable-next-line: param-type-mismatch
  for _, slot in pairs(cache.storage) do
    capacity = capacity + 1
    if slot.count > 0 then
      used = used + 1
    end
  end

  local available = capacity - used

  print("Capacity: " .. used .. " / " .. capacity .. " slots used (" .. available .. " available)")
elseif command == "scan" then
  print("Scanning inputs...")
  local input_slots, input_maxCounts = lib.scanItemsLive({}, tbl.keys(Branches.input), true)

  print("Scanning storage...")
  local storage_slots, storage_maxCounts = lib.scanItemsLive({}, tbl.keys(Branches.storage), true)

  print("Scanning outputs...")
  local output_slots, output_maxCounts = lib.scanItemsLive({}, tbl.keys(Branches.output), true)

  local maxCounts = tbl.merge(input_maxCounts, tbl.merge(storage_maxCounts, output_maxCounts))

  cache.input = input_slots
  cache.storage = storage_slots
  cache.output = output_slots
  cache.maxCounts = maxCounts

  lib.saveCache(cache)
  print("Cache updated successfully (slots.json)")
elseif command == "check" then
  local storage_slots = cache.storage
  local maxCounts = cache.maxCounts

  local file = fs.open("check.txt", "w")
  local lines = {}

  -- Group partial slots by item name
  --- @type table<string, Record[]>
  local partialByItem = {}

  for _, slot in pairs(storage_slots) do
    local maxCount = maxCounts[slot.name]
    if maxCount ~= nil and slot.count > 0 and slot.count < maxCount then
      local key = slot.name
      if slot.nbt ~= nil then
        key = key .. " " .. slot.nbt
      end
      if partialByItem[key] == nil then
        partialByItem[key] = {}
      end
      table.insert(partialByItem[key], slot)
    end
  end

  -- Filter to only items with 2+ partial slots
  local foundAny = false
  for itemName, partialSlots in pairs(partialByItem) do
    if #partialSlots >= 2 then
      local name = str.split(itemName, " ")[1]
      if name ~= nil then
        local maxCount = maxCounts[name]
        foundAny = true
        table.insert(lines, "")
        table.insert(lines, name .. " (" .. #partialSlots .. " partial stacks):")
        for _, slot in pairs(partialSlots) do
          table.insert(lines, "  Chest ID: " ..
            slot.chest_id .. ", Slot ID: " .. slot.slot_id .. ", Count: " .. slot.count .. "/" .. maxCount)
        end
      end
    end
  end

  if not foundAny then
    table.insert(lines, "No items found with 2+ partial stacks.")
  end

  if file ~= nil then
    for _, line in pairs(lines) do
      file.writeLine(line)
      print(line)
    end

    file.close()
  end

  print("")
  print("Open check.txt to view full list.")
end
