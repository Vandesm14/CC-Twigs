local lib = require "wh.lib"
local str = require "lib.str"

local cli = {}

--- Opens all available modems for rednet communication
local function openAllModems()
  local names = peripheral.getNames()
  for _, name in pairs(names) do
    local pType = peripheral.getType(name)
    if pType == "modem" then
      local success, err = pcall(rednet.open, name)
      if not success then
        printError("Failed to open modem " .. name .. ": " .. tostring(err))
      end
    end
  end
end

--- Helper to add a message to the adapter table
--- @param adapter [boolean, string][] Adapter table of [success, message] tuples
--- @param success boolean Whether this is a success message (true) or error (false)
--- @param ... any Message parts to concatenate
local function addMessage(adapter, success, ...)
  local args = { ... }
  local message = table.concat(args, " ")
  table.insert(adapter, { success, message })
end

--- Temporarily override print functions to capture lib output
--- @param adapter [boolean, string][] Adapter table
--- @return function Original print function
--- @return function Original printError function
local function captureLibPrints(adapter)
  local originalPrint = print
  local originalPrintError = printError

  print = function(...)
    addMessage(adapter, true, ...)
    originalPrint(...)
  end

  printError = function(...)
    addMessage(adapter, false, ...)
    originalPrintError(...)
  end

  return originalPrint, originalPrintError
end

--- Restore original print functions
--- @param originalPrint function Original print function
--- @param originalPrintError function Original printError function
local function restoreLibPrints(originalPrint, originalPrintError)
  print = originalPrint
  printError = originalPrintError
end

--- Parses and executes warehouse commands
--- @param args string[] Array of command arguments (e.g., {"ls", "cobblestone"})
--- @param mode "local"|"remote" Execution mode: "local" executes directly, "remote" broadcasts via rednet
--- @return boolean success Whether the command executed successfully
--- @return [boolean, string][] adapter Table of [success, message] tuples
function cli.parse(args, mode)
  if mode == "remote" then
    -- Open all modems and broadcast the command
    openAllModems()

    -- Join arguments into a space-separated string
    local message = table.concat(args, " ")

    -- Broadcast the message with "wh" protocol
    rednet.broadcast(message, "wh")
    return true, {}
  elseif mode == "local" then
    -- Create adapter table to collect output
    --- @type [boolean, string][]
    local adapter = {}

    -- Capture lib prints temporarily for loadOrInitCache and saveCache
    local originalPrint, originalPrintError = captureLibPrints(adapter)
    local cache = lib.loadOrInitCache()
    restoreLibPrints(originalPrint, originalPrintError)

    local success = false
    local command = args[1]

    if command == "ls" then
      local query = args[2]

      local file = fs.open("list.txt", "w")
      local lines = lib.ls(cache, query)

      if file ~= nil then
        for _, line in pairs(lines) do
          file.writeLine(line)
          addMessage(adapter, true, line)
        end

        file.close()
      end

      addMessage(adapter, true, "")
      addMessage(adapter, true, "Open list.txt to view full list.")

      -- Print adapter messages if local mode
      for _, entry in ipairs(adapter) do
        local success_flag, msg = entry[1], entry[2]
        if success_flag then
          print(msg)
        else
          printError(msg)
        end
      end

      return true, adapter
    elseif command == "pull" then
      lib.pull(cache)

      -- Capture saveCache print
      originalPrint, originalPrintError = captureLibPrints(adapter)
      lib.saveCache(cache)
      restoreLibPrints(originalPrint, originalPrintError)

      addMessage(adapter, true, "Done.")

      -- Print adapter messages if local mode
      for _, entry in ipairs(adapter) do
        local success_flag, msg = entry[1], entry[2]
        if success_flag then
          print(msg)
        else
          printError(msg)
        end
      end

      return true, adapter
    elseif command == "order" then
      if args[2] == nil then
        addMessage(adapter, false, "Usage: wh order <item> <amt> [<item> <amt> ...]")
        addMessage(adapter, false, "")
        addMessage(adapter, false, "At least one item and amount must be provided")

        -- Print adapter messages
        for _, entry in ipairs(adapter) do
          local success_flag, msg = entry[1], entry[2]
          if success_flag then
            print(msg)
          else
            printError(msg)
          end
        end

        return false, adapter
      end

      --- @type [string, number][]
      local orders = {}

      local i = 2
      while i <= #args do
        local amount = tonumber(args[i])
        local query = args[i + 1]

        if query == nil or type(query) ~= "string" then
          addMessage(adapter, false, "Usage: wh order <item> <amt> [<item> <amt> ...]")
          addMessage(adapter, false, "")
          addMessage(adapter, false, "Item name expected at position " .. (i - 1))

          -- Print adapter messages
          for _, entry in ipairs(adapter) do
            local success_flag, msg = entry[1], entry[2]
            if success_flag then
              print(msg)
            else
              printError(msg)
            end
          end

          return false, adapter
        end

        if amount == nil then
          addMessage(adapter, false, "Usage: wh order <item> <amt> [<item> <amt> ...]")
          addMessage(adapter, false, "")
          addMessage(adapter, false, "Amount expected after item '" .. query .. "'")

          -- Print adapter messages
          for _, entry in ipairs(adapter) do
            local success_flag, msg = entry[1], entry[2]
            if success_flag then
              print(msg)
            else
              printError(msg)
            end
          end

          return false, adapter
        end

        local name = lib.matchQuery(cache, query)
        if name ~= nil then
          local count = lib.countItem(cache, name)
          if amount > count then
            addMessage(adapter, false, "Not enough " .. name .. ", found " .. count)
          else
            table.insert(orders, { name, amount })
          end
        else
          addMessage(adapter, false, "No " .. query .. " found")
        end

        i = i + 2
      end

      for _, order in pairs(orders) do
        if not lib.order(cache, order[1], order[2]) then
          break
        end
      end

      -- Capture saveCache print
      originalPrint, originalPrintError = captureLibPrints(adapter)
      lib.saveCache(cache)
      restoreLibPrints(originalPrint, originalPrintError)

      addMessage(adapter, true, "Done.")

      -- Print adapter messages if local mode
      for _, entry in ipairs(adapter) do
        local success_flag, msg = entry[1], entry[2]
        if success_flag then
          print(msg)
        else
          printError(msg)
        end
      end

      return true, adapter
    elseif command == "capacity" then
      local capacity, used = lib.capacity(cache)
      local available = capacity - used
      addMessage(adapter, true,
        "Capacity: " .. used .. " / " .. capacity .. " slots used (" .. available .. " available)")

      -- Print adapter messages if local mode
      for _, entry in ipairs(adapter) do
        local success_flag, msg = entry[1], entry[2]
        if success_flag then
          print(msg)
        else
          printError(msg)
        end
      end

      return true, adapter
    elseif command == "scan" or command == nil then
      local unaccounted = lib.scanAll(cache)

      -- Capture saveCache print
      originalPrint, originalPrintError = captureLibPrints(adapter)
      lib.saveCache(cache)
      restoreLibPrints(originalPrint, originalPrintError)

      addMessage(adapter, true, "Found " .. #unaccounted .. " unaccounted changes since last scan")
      for _, trx in pairs(unaccounted) do
        addMessage(adapter, true, trx)
      end

      -- Print adapter messages if local mode
      for _, entry in ipairs(adapter) do
        local success_flag, msg = entry[1], entry[2]
        if success_flag then
          print(msg)
        else
          printError(msg)
        end
      end

      return true, adapter
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
          addMessage(adapter, true, line)
        end

        file.close()
      end

      addMessage(adapter, true, "")
      addMessage(adapter, true, "Open check.txt to view full list.")

      -- Print adapter messages if local mode
      for _, entry in ipairs(adapter) do
        local success_flag, msg = entry[1], entry[2]
        if success_flag then
          print(msg)
        else
          printError(msg)
        end
      end

      return true, adapter
    elseif command == "head" then
      local head = 8
      if args[2] ~= nil then
        local n = tonumber(args[2])
        if n ~= nil then
          head = n
        end
      end

      local csvFile = "transactions.csv"

      if not fs.exists(csvFile) then
        addMessage(adapter, false, "transactions.csv not found. No transactions recorded yet.")

        -- Print adapter messages
        for _, entry in ipairs(adapter) do
          local success_flag, msg = entry[1], entry[2]
          if success_flag then
            print(msg)
          else
            printError(msg)
          end
        end

        return false, adapter
      end

      local file = fs.open(csvFile, "r")
      if file == nil then
        addMessage(adapter, false, "Unable to read transactions.csv file.")

        -- Print adapter messages
        for _, entry in ipairs(adapter) do
          local success_flag, msg = entry[1], entry[2]
          if success_flag then
            print(msg)
          else
            printError(msg)
          end
        end

        return false, adapter
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
        addMessage(adapter, true, "No transactions found.")

        -- Print adapter messages if local mode
        for _, entry in ipairs(adapter) do
          local success_flag, msg = entry[1], entry[2]
          if success_flag then
            print(msg)
          else
            printError(msg)
          end
        end

        return true, adapter
      end

      -- Add header
      addMessage(adapter, true, "time,label,item,amount,balance")

      -- Add the last transactions
      local startLine = #lines - displayCount + 1
      for i = startLine, #lines do
        addMessage(adapter, true, lines[i])
      end

      -- Print adapter messages if local mode
      for _, entry in ipairs(adapter) do
        local success_flag, msg = entry[1], entry[2]
        if success_flag then
          print(msg)
        else
          printError(msg)
        end
      end

      return true, adapter
    else
      addMessage(adapter, false, "unknown command: " .. tostring(command))

      -- Print adapter messages
      for _, entry in ipairs(adapter) do
        local success_flag, msg = entry[1], entry[2]
        if success_flag then
          print(msg)
        else
          printError(msg)
        end
      end

      return false, adapter
    end
  else
    printError("Invalid mode: " .. tostring(mode) .. ". Must be 'local' or 'remote'")
    return false, {}
  end
end

return cli
