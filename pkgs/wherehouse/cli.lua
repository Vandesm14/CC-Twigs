local pretty = require("cc.pretty")
local follownet = require("net.follownet")
local server = require("wherehouse.server")

local usage = "Usage: " .. arg[0] .. " <order|ls>"
local command = arg[1]

if command == nil then
  printError(usage)
  printError()
  printError("Command must be provided.")
  return
elseif command == "ls" then
  local query = arg[2]

  follownet.transmit({ 3, 4 }, { 3524, { 3, os.getComputerID() }, "list" })

  local _, _, packet = follownet.receive()
  local pid, path, type_, data = table.unpack(packet)

  if
      pid == server.pid
      and type(path) == "table"
      and type(type_) == "string"
      and type(data) == "table"
  then
    if type_ == "list" then
      print("Items:")
      for name, count in pairs(data) do
        if query ~= nil and type(query) == "string" then
          if string.find(name, query) ~= nil then
            print(name .. ": " .. count)
          end
        else
          print(name .. ": " .. count)
        end
      end
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

  local order = {
    [item] = amount
  }

  print("Order:")
  pretty.pretty_print(order)

  follownet.transmit({ 3, 4 }, { 3524, { 3, os.getComputerID() }, "order", order })

  local _, _, packet = follownet.receive()
  local pid, path, type_, data = table.unpack(packet)

  if
      pid == server.pid
      and type(path) == "table"
      and type(type_) == "string"
      and type(data) == "table" then
    print("Found:")
    for name, count in pairs(data) do
      print(name .. ": " .. count)
    end
  end
end
