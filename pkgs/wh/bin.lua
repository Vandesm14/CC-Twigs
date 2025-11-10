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

local usage = "Usage: " .. arg[0] .. " <order|ls|capacity>\n" ..
    "  ls [search]           - List items, optionally filter by substring\n" ..
    "  order <item> [<amt>] - Order items (use short name like 'cobblestone' or full like 'minecraft:cobblestone'). Defaults to 64 if not specified."
local command = arg[1]

rednet.open("back")

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
        local result = lib.findExistingSlot(maxCount, storage_slots, item)
        if result ~= nil then
          order = {
            item = result.name,
            count = result.count,
            from = { chest_id = item.chest_id, slot_id = item.slot_id },
            to = { chest_id = result.chest_id, slot_id = result.slot_id },
            actions = Branches.input[item.chest_id] .. Branches.storage[result.chest_id] .. Branches.output["_"],
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

  print("Queueing orders...")
  local queue = Queue:new(orders)
  queue:run()

  print("Done.")
elseif command == "order" then
  -- local item = arg[2]
  -- local amount = tonumber(arg[3])

  -- if item == nil or type(item) ~= "string" then
  --   printError("Usage: " .. arg[0] .. " order <item> [<amt>]")
  --   printError()
  --   printError("Item must be provided")
  --   return
  -- end

  -- -- Default to a stack (64) if no amount is provided
  -- if amount == nil then
  --   amount = 64
  -- elseif type(amount) ~= "number" then
  --   printError("Usage: " .. arg[0] .. " order <item> [<amt>]")
  --   printError()
  --   printError("Amount must be a number")
  --   return
  -- end

  -- -- Determine if we're doing exact full name match or post-colon match
  -- local isFullNameQuery = str.contains(item, ":")

  -- --- @type table<string, integer>
  -- local myItems = {}
  -- local amountNeeded = amount

  -- --- @type table<number, Order>
  -- local orders = {}

  -- print("Calculating orders...")

  -- local chests = lib.scanItems(tbl.keys(Branches.storage))

  -- -- Scan each chest for items, until we hit the end-stop
  -- --- @diagnostic disable-next-line: param-type-mismatch
  -- for _, chest in pairs(chests) do
  --   -- print("Checking chest '" .. chest.id .. "'...")

  --   -- Check for items. Run through each item
  --   for _, chestItem in pairs(chest.items) do
  --     -- If we have all we need, skip
  --     if amountNeeded <= 0 then
  --       break
  --     end

  --     -- Check if the item matches exactly
  --     local matches = false
  --     if isFullNameQuery then
  --       -- Match the full name exactly (e.g., "minecraft:cobblestone")
  --       matches = str.equals(chestItem.name, item)
  --     else
  --       -- Match the post-colon part exactly (e.g., "cobblestone" matches "minecraft:cobblestone")
  --       matches = str.endsWith(chestItem.name, ":" .. item)
  --     end

  --     if matches and chestItem ~= nil then
  --       -- Initialize tracking for this item if needed
  --       if myItems[chestItem.name] == nil then
  --         myItems[chestItem.name] = 0
  --       end

  --       local got = math.min(chestItem.count, amountNeeded)
  --       myItems[chestItem.name] = myItems[chestItem.name] + got
  --       amountNeeded = amountNeeded - got
  --       print(
  --         "  Got",
  --         tostring(got),
  --         chestItem.name .. ", need",
  --         tostring(amountNeeded),
  --         "more."
  --       )

  --       local chunk = Order:new(chestItem.name, got,
  --         Branches.input["_"] .. Branches.storage[chest.id] .. Branches.output[tbl.keys(Branches.output)[1]], "output")
  --       table.insert(orders, chunk)
  --     end
  --   end
  -- end

  -- print("Found:")
  -- for name, count in pairs(myItems) do
  --   print(name .. ": " .. count)
  -- end

  -- print("Queueing orders...")
  -- local queue = Queue:new(orders)
  -- queue:run()
  -- print("Done.")
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
end
