local follownet = require("net.follownet")
local server = require("wherehouse.server")

local usage = "Usage: " .. arg[0] .. " <order|ls>"
local command = arg[1]
local query = arg[2]

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
end
