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
        print(name .. ": " .. count)
      end
    elseif type_ == "order" then
      print("Found:")
      for name, count in pairs(data) do
        print(name .. ": " .. count)
      end
    end
  end
end
