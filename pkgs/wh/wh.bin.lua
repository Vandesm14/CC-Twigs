local pretty = require "cc.pretty"
local lib = require "wh.lib"
local tbl = require "lib.table"
local branches = require "wh.branches"
local str = require "lib.str"

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

-- Load cache globally
local cache = lib.loadCache()

if command == "help" then
  print(usage)
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
  lib.pull(cache)
  lib.saveCache(cache)
  print("Done.")
elseif command == "order" then
  if arg[2] == nil then
    printError("Usage: " .. arg[0] .. " order <item> <amt> [<item> <amt> ...]")
    printError()
    printError("At least one item and amount must be provided")
    return
  end

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

    lib.order(cache, query, amount)

    i = i + 2
  end
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
elseif command == "scan" or command == nil then
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
