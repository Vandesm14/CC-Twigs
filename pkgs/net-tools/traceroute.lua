local searchnet = require("net.searchnet")

local usage = "Usage: " .. arg[0] .. " <destination>"
local destination = arg[1]

if destination == nil then
  printError(usage)
  printError()
  printError("Destination must be provided.")
  return
end

--- @diagnostic disable-next-line: redefined-local
local destination = tonumber(destination)

if destination == nil then
  printError(usage)
  printError()
  printError("Desination must be a number.")
  return
end

--- @type integer[] | nil
local route = searchnet.search(destination)

if route ~= nil then
  print("Route to " .. tostring(destination) .. ":")
  -- Add ourselves to the path for user friendliness
  table.insert(route, 1, os.getComputerID())
  print(table.concat(route, " -> "))
else
  printError("No route to " .. tostring(destination) .. ".")
end
