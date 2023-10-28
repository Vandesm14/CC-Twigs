local searchnet = require("net.searchnet")

local usage = "Usage: " .. arg[0] .. " <destination>"
local destinationId = arg[1]

if destinationId == nil then
  printError(usage)
  printError()
  printError("Expected a destinationId ID.")
  return
end

--- @diagnostic disable-next-line: redefined-local
local destinationId = tonumber(destinationId)

if destinationId == nil then
  printError(usage)
  printError()
  printError("Expected the destinationId ID to be a number.")
  return
end

--- @type integer[] | nil
local route = searchnet.find(destinationId)

if route ~= nil then
  print("Route to " .. tostring(destinationId) .. ":")

	for i = 1, #route / 2 do
		local source = table.remove(route, 1)
		local destination = table.remove(route, 1)
		print(
			source.id,
			"(" .. source.name .. ")",
			"->",
			destination.id,
			"(" .. destination.name .. ")"
		)
	end
else
  printError("No route to " .. tostring(destinationId) .. ".")
end
