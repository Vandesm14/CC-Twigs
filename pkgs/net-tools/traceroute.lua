local mngr = require("mngr.mngr")
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

-- Run the daemons for Searchnet
local foundNet = false

for _, package in ipairs(mngr.getInstalledPackages()) do
  if package == "net" then
    foundNet = true
    break
  end
end

if not foundNet then
  printError("Be sure to install the 'net' package.")
  return
end

multishell.launch(_ENV, "/.mngr/net/daemons.lua")

--- @type integer[] | nil
local route = searchnet.search(destination)

if route ~= nil then
  print("Route to " .. tostring(destination) .. ":")
  print(table.concat(route, " -> "))
else
  printError("No route to " .. tostring(destination) .. ".")
end
