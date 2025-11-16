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
      else
        printError("Failed to open modem " .. name .. ": " .. tostring(err))
      end
    end
  end

  return openedCount > 0
end

-- Open modems for listening
if not openAllModems() then
  printError("No modems found. Cannot listen for network messages.")
  return
end

-- Create log file with timestamp
local fileTimestamp = os.date("%Y%m%d_%H%M%S", os.epoch("utc") / 1000)
local fileName = "netspy_" .. fileTimestamp .. ".jsonl"
local file = fs.open(fileName, "a")

print("Netspy started. Listening for all rednet messages...")
print("Logging to: " .. fileName)
print("Press Ctrl+T to exit")
print("")


while true do
  -- Listen for rednet messages
  local eventData = { (os.pullEventRaw()) }
  local event = eventData[1]

  if event == "terminate" then
    return
  elseif event == "rednet_message" then
    -- Rednet message: eventData = {"rednet_message", senderId, message, protocol}
    local senderId = eventData[2]
    local message = eventData[3]
    local protocol = eventData[4]

    -- Create a table with all message data
    local messageData = {
      event = "rednet_message",
      senderId = senderId,
      message = message,
      protocol = protocol,
      timestamp = os.epoch("utc") / 1000
    }

    -- Serialize to JSON
    local json = textutils.serializeJSON(messageData, false)

    -- Print the JSON
    print(json)

    -- Append to file
    if file ~= nil then
      file.writeLine(json)
      file.close()
    else
      printError("Failed to write to file: " .. fileName)
    end
  end
end
