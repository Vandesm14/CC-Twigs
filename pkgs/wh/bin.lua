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

local usage = "Usage: " .. arg[0] .. " <order|ls|capacity|export|check>\n" ..
    "  ls [search]           - List items, optionally filter by substring\n" ..
    "  order <item> [<amt>]  - Order items (use short name like 'cobblestone' or full like 'minecraft:cobblestone'). Defaults to 64 if not specified.\n" ..
    "  export                - Export input, storage, and output slot lists to slots.json\n" ..
    "  check                 - Find items with 2+ partial stacks that can be consolidated"
local command = arg[1]

rednet.open("back")

--- @return Order[]
local function pull()
  print("Scanning storage...")
  local storage_slots, storage_maxCounts = lib.scanItems(tbl.keys(Branches.storage), true)

  print("Scanning inputs...")
  local input_slots, input_maxCounts = lib.scanItems(tbl.keys(Branches.input))
  local maxCounts = tbl.merge(storage_maxCounts, input_maxCounts)

  --- @type Order[]
  local orders = {}

  print("Planning movements...")
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
        lib.applyOrder(storage_slots, order)
        item.count = item.count - order.count
      end
    end
  end

  print("Done.")

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

  -- Scan each chest for items, until we hit the end-stop
  --- @diagnostic disable-next-line: param-type-mismatch
  countItems(lib.scanItems(tbl.keys(Branches.storage)), items)

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

  print("Queueing orders...")
  local queue = Queue:new(orders)
  queue:run()

  print("Done.")
elseif command == "order" then
  local query = arg[2]
  local amount = tonumber(arg[3])

  if query == nil or type(query) ~= "string" then
    printError("Usage: " .. arg[0] .. " order <item> [<amt>]")
    printError()
    printError("Item must be provided")
    return
  end

  -- Determine if we're doing exact full name match or post-colon match
  local isFullNameQuery = str.contains(query, ":")

  print("Scanning storage...")
  local slots, maxCounts = lib.scanItems(tbl.keys(Branches.storage))
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

  -- Default to a stack (64) if no amount is provided
  if amount == nil then
    amount = maxCount
  elseif type(amount) ~= "number" then
    printError("Usage: " .. arg[0] .. " order <item> [<amt>]")
    printError()
    printError("Amount must be a number")
    return
  end

  --- @type Order[]
  local orders = {}
  local amountLeft = amount

  local output_chest_id = tbl.keys(Branches.output)[1]
  local output_slot_id = 1

  print("Calculating orders...")
  while amountLeft > 0 do
    --- @type Order|nil
    local order = nil

    -- If amountLeft is a multiple of 64, skip partial stacks and grab full stacks directly
    if amountLeft % maxCount ~= 0 then
      local result = lib.findOutputPartialSlot(maxCount, slots, name)
      if result ~= nil then
        local count = amountLeft
        if result.count < amountLeft then
          count = result.count
        end

        order = {
          item = name,
          count = count,
          from = { chest_id = result.slot.chest_id, slot_id = result.slot.slot_id },
          to = { chest_id = output_slot_id, slot_id = output_slot_id },
          actions = Branches.input["_"] .. Branches.storage[result.slot.chest_id] .. Branches.output[output_chest_id],
          type = "output"
        }
      end
    end

    if order == nil then
      local result = lib.findFullSlot(maxCount, slots, name)
      if result ~= nil then
        local count = amountLeft
        if maxCount < amountLeft then
          count = maxCount
        end

        order = {
          item = name,
          count = count,
          from = { chest_id = result.chest_id, slot_id = result.slot_id },
          to = { chest_id = output_slot_id, slot_id = output_slot_id },
          actions = Branches.input["_"] .. Branches.storage[result.chest_id] .. Branches.output[output_chest_id],
          type = "output"
        }
      end
    end

    if order ~= nil then
      table.insert(orders, order)
      lib.applyOrder(slots, order)
      amountLeft = amountLeft - order.count
    else
      break
    end
  end

  if amountLeft > 0 then
    error("found only: " .. (amount - amountLeft) .. " " .. name)
  end

  print("Queueing orders...")
  local queue = Queue:new(orders)
  queue:run()
  print("Done.")
elseif command == "capacity" then
  local capacity = 0
  local used = 0

  --- @diagnostic disable-next-line: param-type-mismatch
  for _, slot in pairs(lib.scanItems(tbl.keys(Branches.storage), true)) do
    capacity = capacity + 1
    if slot.count > 0 then
      used = used + 1
    end
  end

  local available = capacity - used

  print("Capacity: " .. used .. " / " .. capacity .. " slots used (" .. available .. " available)")
elseif command == "export" then
  print("Scanning input slots...")
  local input_slots, input_maxCounts = lib.scanItems(tbl.keys(Branches.input))

  print("Scanning storage slots...")
  local storage_slots, storage_maxCounts = lib.scanItems(tbl.keys(Branches.storage))

  print("Scanning output slots...")
  local output_slots, output_maxCounts = lib.scanItems(tbl.keys(Branches.output))

  local maxCounts = tbl.merge(input_maxCounts, tbl.merge(storage_maxCounts, output_maxCounts))

  local slots = {
    input = input_slots,
    storage = storage_slots,
    output = output_slots,
    maxCounts = maxCounts
  }

  local json = textutils.serializeJSON(slots, false)
  local file = fs.open("slots.json", "w")
  if file ~= nil then
    file.write(json)
    file.close()
    print("Exported slots to slots.json")
  else
    printError("Unable to create slots.json file.")
  end
elseif command == "check" then
  print("Scanning storage slots...")
  local storage_slots, maxCounts = lib.scanItems(tbl.keys(Branches.storage))

  -- Group partial slots by item name
  --- @type table<string, Record[]>
  local partialByItem = {}

  for _, slot in pairs(storage_slots) do
    local maxCount = maxCounts[slot.name]
    if maxCount ~= nil and slot.count > 0 and slot.count < maxCount then
      if partialByItem[slot.name] == nil then
        partialByItem[slot.name] = {}
      end
      table.insert(partialByItem[slot.name], slot)
    end
  end

  -- Filter to only items with 2+ partial slots
  local foundAny = false
  for itemName, partialSlots in pairs(partialByItem) do
    if #partialSlots >= 2 then
      foundAny = true
      print("")
      print(itemName .. " (" .. #partialSlots .. " partial stacks):")
      for _, slot in pairs(partialSlots) do
        print("  Chest ID: " ..
          slot.chest_id .. ", Slot ID: " .. slot.slot_id .. ", Count: " .. slot.count .. "/" .. maxCounts[itemName])
      end
    end
  end

  if not foundAny then
    print("No items found with 2+ partial stacks.")
  end
end
