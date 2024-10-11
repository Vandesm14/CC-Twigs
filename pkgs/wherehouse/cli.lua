local pretty = require "cc.pretty"
local lib = require "wherehouse.lib"
local Order = require "turt.order"

--- @param items itemList
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
  local query = arg[2]

  --- The distribution chest MUST be a single chest
  --- and the storage chests MUST be double chests
  --- @diagnostic disable-next-line: param-type-mismatch
  local distributionChest = peripheral.find("minecraft:barrel")
  --- @cast distributionChest Inventory

  if distributionChest == nil then
    printError("No distribution chest found.")
    return true
  end

  local items = {}
  countItems(distributionChest.list(), items)
  local myItems = {}
  for key, val in pairs(items) do
    myItems[key] = val
  end

  local distributionChestName = peripheral.getName(distributionChest)

  -- Run through each stack and try to place it in a chest
  for slot, item in pairs(distributionChest.list()) do
    --- @diagnostic disable-next-line: param-type-mismatch
    for _, chest in ipairs({ peripheral.find("minecraft:chest") }) do
      --- @cast chest Inventory
      local chestName = lib.getName(chest)

      -- Move the stack into the chest
      local success, got = pcall(
        chest.pullItems,
        distributionChestName,
        slot
      )

      -- If we succeed, then decrement how many items we have left
      if success then
        print("sent", got, "of", item.name, "to", chestName)
        myItems[item.name] = myItems[item.name] - got

        -- If we clear out all of our items, skip to the next item
        if got == myItems[item.name] then
          break
        end
      end
    end
  end

  print("Pulled:")
  for name, count in pairs(items) do
    if query ~= nil and type(query) == "string" then
      if string.find(name, query) ~= nil then
        print(name .. ": " .. count)
      end
    else
      print(name .. ": " .. count)
    end
  end
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
    for slot, item in pairs(chest.list()) do
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
