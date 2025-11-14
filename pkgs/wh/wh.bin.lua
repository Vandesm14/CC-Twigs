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
      else
        printError("Failed to open modem " .. name .. ": " .. tostring(err))
      end
    end
  end

  return openedCount > 0
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

  return parseSuccess, adapter
end

-- Convert arg table to array format
--- @type string[]
local args = {}
for i = 1, #arg do
  args[i] = arg[i]
end

-- If arguments are provided, send command via both local OS events and remote rednet
-- Wait for first response from either source
if #args > 0 then
  -- Open modems for sending/receiving
  local hasModems = openAllModems()

  -- Queue OS event for local listeners
  local command = args[1]
  local param = nil
  if #args > 1 then
    -- If there are additional args, pass them as param
    if #args == 2 then
      param = args[2]
    else
      -- Multiple args: pass as table
      param = {}
      for i = 2, #args do
        table.insert(param, args[i])
      end
    end
  end
  os.queueEvent("wh", command, param)

  -- Also send via rednet if modems are available
  if hasModems then
    -- Broadcast the command via rednet
    cli.parse(args, "remote")
  end

  -- Listen for response messages from either local OS events or remote rednet
  -- First-come system: stop waiting once we get a response from either source
  --- @type [boolean, string][]|nil
  local receivedAdapter = nil
  local receivedDone = false
  local timeout = 10 -- seconds
  local responseSource = nil -- "local" or "remote"

  print("Waiting for response (local or remote)...")

  local startTime = os.clock()
  while (os.clock() - startTime) < timeout and not receivedDone do
    -- Listen for both OS events and rednet messages
    local eventData = { os.pullEventRaw() }
    local event = eventData[1]

    if event == "wh" then
      -- Check if this is a response OS event
      -- OS event responses come as: {"wh", "response", adapter, success}
      local responseCommand = eventData[2]
      if responseCommand == "response" then
        receivedAdapter = eventData[3]
        receivedDone = true
        responseSource = "local"
      end
    elseif event == "rednet_message" then
      -- Rednet message: eventData = {"rednet_message", senderId, message, protocol}
      local senderId = eventData[2]
      local message = eventData[3]
      local protocol = eventData[4]

      if protocol == "wh-response" and senderId ~= nil and message ~= nil and type(message) == "table" then
        if message.type == "adapter" then
          receivedAdapter = message.adapter
        elseif message.type == "done" then
          receivedDone = true
          responseSource = "remote"
        end
      end
    end
  end

  -- Display all received adapter messages
  if receivedAdapter ~= nil then
    if responseSource == "local" then
      print("Local response:")
    else
      print("Remote response:")
    end
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
else
  -- No arguments: run as server/listener mode
  -- Open modems for listening
  if not openAllModems() then
    printError("No modems found. Cannot listen for network commands.")
    return
  end

  print("Listening for 'wh' OS events and rednet protocol packets...")
  print("Press Ctrl+T to exit")

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
end
