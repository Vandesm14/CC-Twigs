local pretty = require "cc.pretty"
local lib = require "wh.lib"
local str = require "lib.str"

rednet.open("back")

local cache = lib.loadOrInitCache()

local command = arg[1]
if command == "ls" then
  local query = arg[2]

  local file = fs.open("list.txt", "w")
  local lines = lib.ls(cache, query)

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

  --- @type [string, number][]
  local orders = {}

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

    local name = lib.matchQuery(cache, query)
    if name ~= nil then
      local count = lib.countItem(cache, name)
      if amount > count then
        printError("Not enough " .. name .. ", found " .. count)
      else
        table.insert({ name, amount })
      end
    else
      printError("No " .. query .. " found")
    end

    i = i + 2
  end

  for _, order in pairs(orders) do
    if not lib.order(cache, order[1], order[2]) then
      break
    end
  end

  lib.saveCache(cache)
  print("Done.")
elseif command == "capacity" then
  local capacity, used = lib.capacity(cache)
  local available = capacity - used
  print("Capacity: " .. used .. " / " .. capacity .. " slots used (" .. available .. " available)")
elseif command == "scan" or command == nil then
  local unaccounted = lib.scanAll(cache)
  lib.saveCache(cache)

  print("Found " .. #unaccounted .. " unaccounted changes since last scan")
  for _, trx in pairs(unaccounted) do
    print(trx)
  end
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
elseif command == "head" then
  local head = 8
  if arg[2] ~= nil then
    local n = tonumber(arg[2])
    if n ~= nil then
      head = n
    end
  end

  local csvFile = "transactions.csv"

  if not fs.exists(csvFile) then
    printError("transactions.csv not found. No transactions recorded yet.")
    return
  end

  local file = fs.open(csvFile, "r")
  if file == nil then
    printError("Unable to read transactions.csv file.")
    return
  end

  -- Read all lines
  --- @type string[]
  local lines = {}
  local line = file.readLine()
  while line ~= nil do
    table.insert(lines, line)
    line = file.readLine()
  end
  file.close()

  -- Skip header if present
  local startIndex = 1
  if #lines > 0 and lines[1] == "time,label,item,amount,balance" then
    startIndex = 2
  end

  -- Get the last transactions
  local numTransactions = #lines - startIndex + 1
  local displayCount = math.min(head, numTransactions)

  if displayCount == 0 then
    print("No transactions found.")
    return
  end

  -- Print header
  print("time,label,item,amount,balance")

  -- Print the last transactions
  local startLine = #lines - displayCount + 1
  for i = startLine, #lines do
    print(lines[i])
  end
else
  error("unknown command: " .. command)
end
