local pretty = require "cc.pretty"
local Order = require "turt.order"
local lib = require "wh.lib"
local Queue = require "wh.queue"
local tbl = require "lib.table"
local Branches = require "wh.branches"

--- @param chest ccTweaked.peripherals.Inventory
--- @param table table
local function countItems(chest, table)
  -- Run through each item in the chest
  for _, item in pairs(chest.list()) do
    local name, count = item.name, item.count

    -- Update or set the entry
    if table[name] ~= nil then
      table[name] = table[name] + count
    else
      table[name] = count
    end
  end
end

local usage = "Usage: " .. arg[0] .. " <order|ls|capacity>"
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
  for _, chest in pairs(lib.scanItems(tbl.keys(Branches.storage))) do
    if chest ~= nil then
      countItems(chest.inventory, items)
    end
  end

  table.insert(lines, "Items:")
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
  local inputChest = nil
  --- @cast inputChest Chest|nil

  local list = lib.scanItems(tbl.keys(Branches.input))
  for _, chest in pairs(list) do
    if tbl.len(chest.inventory.list()) > 0 then
      inputChest = chest
      break
    end
  end

  print("Finding available space...")
  local list = lib.scanItems(tbl.keys(Branches.storage))
  local acc = 0
  local mostSpace = nil
  for _, chest in pairs(list) do
    local space = chest.inventory.size() - #chest.inventory.list()
    if space > acc then
      acc = space
      mostSpace = chest
    end
  end

  if mostSpace == nil then
    printError("No space in network.")
    return
  end

  if inputChest == nil then
    printError("No items to input.")
    return
  end

  print("Calculating orders to '" .. mostSpace.id .. "'...")
  local orders = {}
  for _, item in pairs(inputChest.items) do
    if acc > 0 then
      local chunk = Order:new(item.name, item.count,
        Branches.input[inputChest.id] .. Branches.storage[mostSpace.id] .. Branches.output["_"],
        "input")
      table.insert(orders, chunk)

      acc = acc - 1
    end
  end

  print("Queueing orders...")
  local queue = Queue:new(orders)
  queue:run()

  print("Done.")
elseif command == "order" then
  local item = arg[2]
  local amount = tonumber(arg[3])

  if item == nil or type(item) ~= "string" then
    printError("Usage: " .. arg[0] .. " order <item> <amount>")
    printError()
    printError("Item must be provided")
    return
  end

  if amount == nil or type(amount) ~= "number" then
    printError("Usage: " .. arg[0] .. " order <item> <amount>")
    printError()
    printError("Amount must be provided")
    return
  end

  local order = {
    [item] = amount
  }

  --- @type table<string, integer>
  local myItems = {}

  -- Add 0's for all the order items
  for name, _ in pairs(order) do
    myItems[name] = 0
  end

  --- @type table<number, Order>
  local orders = {}

  print("Calculating orders...")

  local chests = lib.scanItems(tbl.keys(Branches.storage))

  -- Scan each chest for items, until we hit the end-stop
  --- @diagnostic disable-next-line: param-type-mismatch
  for _, chest in pairs(chests) do
    -- print("Checking chest '" .. chest.id .. "'...")

    -- Check for items. Run through each item
    for _, item in pairs(chest.items) do
      -- If we have all we need, skip
      if order[item.name] ~= nil and myItems[item.name] == order[item.name] then
        break
      end

      -- If the order wants this item...
      if order[item.name] ~= nil and item ~= nil then
        local need = order[item.name] - myItems[item.name]

        -- ...and we don't have enough
        if need > 0 then
          local got = math.min(item.count, need)
          myItems[item.name] = myItems[item.name] + got
          print(
            "  Got",
            tostring(got),
            item.name .. ", need",
            tostring(need - got),
            "more."
          )

          local chunk = Order:new(item.name, got,
            Branches.input["_"] .. Branches.storage[chest.id] .. Branches.output[tbl.keys(Branches.output)[1]], "output")
          table.insert(orders, chunk)
        end
      end
    end
  end

  print("Found:")
  for name, count in pairs(myItems) do
    print(name .. ": " .. count)
  end

  print("Queueing orders...")
  local queue = Queue:new(orders)
  queue:run()
  print("Done.")
elseif command == "capacity" then
  local capacity = 0
  local used = 0

  --- @diagnostic disable-next-line: param-type-mismatch
  for _, chest in pairs(lib.scanItems(tbl.keys(Branches.storage))) do
    capacity = capacity + chest.inventory.size()
    used = used + tbl.len(chest.inventory.list())
  end

  local available = capacity - used

  print("Capacity: " .. used .. " / " .. capacity .. " slots used (" .. available .. " available)")
end
