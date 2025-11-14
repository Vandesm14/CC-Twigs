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

-- Process command arguments and execute
-- @param args string[] Command arguments
-- @param senderId number|nil Sender ID for rednet response (nil for OS events)
-- @param fromOSEvent boolean Whether this command came from an OS event
local function processCommand(args, senderId, fromOSEvent)
  -- Execute the command locally and capture output
  local parseSuccess, adapter = cli.parse(args, "local")

  -- If senderId is provided, send response via rednet
  if senderId ~= nil then
    rednet.send(senderId, { type = "adapter", adapter = adapter }, "wh-response")
    rednet.send(senderId, { type = "done" }, "wh-response")
  end

  -- If this came from an OS event, send response via OS event
  if fromOSEvent then
    os.queueEvent("wh", "response", adapter, parseSuccess)
  end
end

-- Main server loop
if not openAllModems() then
  return
end

print("Listening for 'wh' OS events and rednet protocol packets...")

while true do
  -- Listen for both OS events and rednet messages
  local eventData = { os.pullEventRaw() }
  local event = eventData[1]

  if event == "wh" then
    -- OS event: eventData = {"wh", command, param, success, adapter}
    local command = eventData[2]
    local param = eventData[3]
    
    -- Ignore "response" events (those are responses, not commands)
    if command ~= "response" then
      print("Received OS event: wh " .. tostring(command))
      
      -- Convert OS event to args array
      --- @type string[]
      local args = {}
      if command ~= nil then
        table.insert(args, tostring(command))
        if param ~= nil then
          if type(param) == "table" then
            -- If param is a table (like args array), merge it
            for _, v in ipairs(param) do
              table.insert(args, tostring(v))
            end
          else
            table.insert(args, tostring(param))
          end
        end
      end
      
      processCommand(args, nil, true)
    end
  elseif event == "rednet_message" then
    -- Rednet message: eventData = {"rednet_message", senderId, message, protocol}
    local senderId = eventData[2]
    local message = eventData[3]
    local protocol = eventData[4]
    
    if protocol == "wh" and senderId ~= nil and message ~= nil then
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
      
        processCommand(args, senderId, false)
    end
  end
end
