local cli = require "wh.cli"
local str = require "lib.str"

-- Open all available modems
local function openAllModems()
  local names = peripheral.getNames()
  local openedCount = 0
  for _, name in pairs(names) do
    local pType = peripheral.getType(name)
    if pType == "modem" then
      local success, err = pcall(rednet.open, name)
      if success then
        openedCount = openedCount + 1
        print("Opened modem: " .. name)
      else
        printError("Failed to open modem " .. name .. ": " .. tostring(err))
      end
    end
  end

  if openedCount == 0 then
    printError("No modems found. Cannot listen for network commands.")
    return false
  end

  print("Listening for 'wh' protocol packets on " .. openedCount .. " modem(s)...")
  return true
end

-- Main server loop
if not openAllModems() then
  return
end

while true do
  local senderId, message, protocol = rednet.receive("wh", 1)

  if senderId ~= nil and message ~= nil then
    print("Received command from computer " .. senderId .. ": " .. tostring(message))

    -- Split message by spaces to create arguments array
    --- @type string[]
    local args = {}
    if type(message) == "string" then
      local parts = str.split(message, " ")
      for _, part in pairs(parts) do
        if part ~= nil and part ~= "" then
          table.insert(args, part)
        end
      end
    else
      -- If message is not a string, convert to string and use as single argument
      table.insert(args, tostring(message))
    end

    -- Execute the command locally
    local success, err = pcall(function()
      cli.parse(args, "local")
    end)

    if not success then
      printError("Error executing command: " .. tostring(err))
    end
  end
end
