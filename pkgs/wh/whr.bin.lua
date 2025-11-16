local cli = require "/pkgs.wh.cli"

-- Open all available modems for receiving responses
local function openAllModems()
  local names = peripheral.getNames()
  local openedCount = 0
  for _, name in pairs(names) do
    local pType = peripheral.getType(name)
    if pType == "modem" then
      local success, err = pcall(rednet.open, name)
      if success then
        openedCount = openedCount + 1
      else
        printError("Failed to open modem " .. name .. ": " .. tostring(err))
      end
    end
  end

  return openedCount > 0
end

-- Convert arg table to array format
--- @type string[]
local args = {}
for i = 1, #arg do
  args[i] = arg[i]
end

if #args == 0 then
  printError("Usage: wh-net <command> [arguments...]")
  return
end

-- Open modems for receiving responses
if not openAllModems() then
  printError("No modems found. Cannot send/receive network commands.")
  return
end

-- Broadcast the command via cli.parse with remote mode
cli.parse(args, "remote")

-- Listen for response messages
--- @type [boolean, string][]|nil
local receivedAdapter = nil
local receivedDone = false
local timeout = 10 -- seconds

print("Waiting for response...")

local startTime = os.clock()
while (os.clock() - startTime) < timeout and not receivedDone do
  local senderId, message, protocol = rednet.receive("wh-response", 0.5)

  if senderId ~= nil and message ~= nil and type(message) == "table" then
    if message.type == "adapter" then
      receivedAdapter = message.adapter
    elseif message.type == "done" then
      receivedDone = true
    end
  end
end

-- Display all received adapter messages
if receivedAdapter ~= nil then
  for _, entry in ipairs(receivedAdapter) do
    local success_flag, msg = entry[1], entry[2]
    if success_flag then
      print(msg)
    else
      printError(msg)
    end
  end
elseif not receivedDone then
  printError("Timeout waiting for response")
end
