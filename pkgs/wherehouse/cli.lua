local pretty = require "cc.pretty"
local lib = require "wherehouse.lib"
local Order = require "turt.order"

local usage = "Usage: " .. arg[0] .. " <order|ls|capacity>"
local command = arg[1]

if command == nil then
  printError(usage)
  printError()
  printError("Command must be provided.")
  return
elseif command == "ls" then
  local query = arg[2]

  local chests = lib.scanItems()
  
  for _, chest in pairs(chests) do
    print("")
    print("Chest " .. chest.name .. ":")
    for _, item in pairs(chest.items) do
      if query ~= nil and type(query) == "string" then
        if string.find(item.name, query) ~= nil then
          print(item.name .. ": " .. item.count)
        end
      else
        print(item.name .. ": " .. item.count)
      end
    end
  end
elseif command == "pull" then
  local inputChest = nil

  print("Finding available space...")
  local list = lib.scanItems()
  local position = nil
  local mostSpace = nil
  local acc = 0
  for _, chest in pairs(list) do
    print("Scanning chest '" .. chest.name .. "'...")
    local name = lib.getName(chest.inventory)
    if name == "input_chest" then
      inputChest = chest
    end

    local space = chest.inventory.size() - #chest.inventory.list()
    if space > acc then
      local newPosition = lib.getChestPosition(chest.inventory)
      if newPosition ~= nil then
        acc = space
        mostSpace = chest
        position = newPosition
      end
    end
  end

  if mostSpace == nil or inputChest == nil then
    printError("No space in network.")
    return
  end

  if position == nil then
    printError("No position of largest chest")
    return
  end

  print("Queueing orders to '" .. mostSpace.name .. "'...")
  for _, item in pairs(inputChest.items) do
    if item.name ~= "computercraft:disk" then
      if acc > 0 then
        if position ~= nil then
          local chunk = Order:new(item.name, item.count, position, "input")
          print("Sent order for '" .. item.name .. "'")
          rednet.broadcast(chunk, "wherehouse")
          error("stop")
        end
  
        acc = acc -1
      end
    end
  end

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

  rednet.open("top")

  local order = {
    [item] = amount
  }

  --- @type table<string, integer>
  local myItems = {}

  -- Add 0's for all the order items
  for name, _ in pairs(order) do
    myItems[name] = 0
  end

  -- Scan each chest for items, until we hit the end-stop
  --- @diagnostic disable-next-line: param-type-mismatch
  for _, chest in ipairs({ peripheral.find("minecraft:chest", function(_, chest) return chest.size() == 54 end) }) do
    --- @cast chest Inventory
    local chestName = peripheral.getName(chest)
    print("Checking chest '" .. chestName .. "'...")

    -- Check for items. Run through each item
    for _, item in pairs(chest.list()) do
      -- If we have all we need, skip
      if order[item.name] ~= nil and myItems[item.name] == order[item.name] then
        break
      end

      if item ~= nil then
        -- If the order wants this item...
        if order[item.name] ~= nil then
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

            local position = lib.getChestPosition(chest)
            if position ~= nil then
              local chunk = Order:new(item.name, need, position, "output")
              rednet.broadcast(chunk, "wherehouse")
            end
          end
        end
      end
    end
  end

  print("Found:")
  for name, count in pairs(myItems) do
    print(name .. ": " .. count)
  end
elseif command == "capacity" then
  local capacity = 0

  --- @diagnostic disable-next-line: param-type-mismatch
  for _, chest in ipairs({ peripheral.find("minecraft:chest") }) do
    --- @cast chest Inventory
    capacity = capacity + chest.size()
  end

  print("The capacity is:", capacity)
end
