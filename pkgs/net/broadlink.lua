--- A data link layer protocol (OSI layer 2).
---
--- Broadlink is an unreliable broadcast protocol for transfer of data frames
--- between hosts connected to a modem.
local broadlink = {}

--- The channel that Broadlink data frames are transferred on.
broadlink.channel = 1036
--- The event name for received Broadlink data frames.
broadlink.event = "broadlink"

--- Sends a Broadlink data frame.
---
--- @generic T: table
--- @param side computerSide
--- @param data T
function broadlink.transmit(side, data)
  os.queueEvent(
    "modem_message",
    side,
    broadlink.channel,
    broadlink.channel,
    { os.getComputerID(), data }
  )
end

--- Receives a Broadlink data frame.
---
--- This pauses execution on the current thread.
---
--- @return computerSide side
--- @return integer source
--- @return table data
function broadlink.receive()
  --- @diagnostic disable-next-line: param-type-mismatch
  local _, side, source, data = os.pullEvent(broadlink.event)
  return side, source, data
end

--- Handles a possible Broadlink data frame transfer.
---
--- This pauses execution on the current thread.
---
--- @return boolean deprioritise
function broadlink.daemon()
  --- @type event, computerSide, integer, integer, table, integer
  local event, side, channel, replyChannel, frame, distance = os.pullEvent("modem_message")
  local revert = function() os.queueEvent(event, side, channel, replyChannel, frame, distance) end

  -- 1. If frame is a valid Broadlink data frame...
  -- 2. Otherwise...
  if
    channel == broadlink.channel
    and type(frame) == "table"
    and type(frame[1]) == "number"
    and type(frame[2]) == "table"
  then
    -- 1.1. ...Extract the source and data.
    --- @type integer, table
    local source, data = frame[1], frame[2]

    -- 1.2. If the source is this computer...
    -- 1.3. Otherwise the destination is this computer...
    if source == os.getComputerID() then
      -- 1.2.1. ...If the specified side is a modem...
      -- 1.2.2. ...Otherwise...
      if peripheral.getType(side) == "modem" then
        -- 1.2.1.1. ...Transmit the data frame.
        local modem = peripheral.wrap(side)

        --- @cast modem Modem
        modem.transmit(broadlink.channel, broadlink.channel, {
          source,
          data,
        })

        print("BL SEND:", data)
        return false
      end
      -- 1.2.2.1. ...Drop the data frame.

      print("BL DROP", data)
      return false
    else
      -- 1.3.1. ...Queue a Broadlink event.
      os.queueEvent(broadlink.event, source, data)

      print("BL RECV:", source, data)
      return false
    end
  else
    -- 2.1. ...Re-queue the event since it was not Broadlink related.
    revert()

    print("BL OTHR")
    return true
  end
end

return broadlink

--------------------------------------------------------------------------------

-- --- A data link layer protocol (OSI layer 2).
-- ---
-- --- Broadlink is an unreliable broadcast protocol for transfer of data frames
-- --- between hosts connected to a modem.
-- local broadlink = {}

-- --- The channel that Broadlink data frames are transferred on.
-- broadlink.channel = 1036
-- --- The event name for received Broadlink data frames.
-- broadlink.event = "broadlink"

-- --- @generic T: table
-- --- @param side computerSide
-- --- @param data T
-- --- @return boolean sent
-- function broadlink.transmit(side, data)
--   local modem = peripheral.wrap(side)

--   if modem ~= nil and peripheral.getType(modem) == "modem" then
--     --- @cast modem Modem
--     modem.transmit(broadlink.channel, broadlink.channel, {
--       os.getComputerID(),
--       data,
--     })
--     return true
--   end

--   return false
-- end

-- --- @return computerSide|nil side
-- --- @return table|nil data
-- function broadlink.receive()
--   local _, side, channel, _, frame = os.pullEvent("modem_message")

--   if channel == broadlink.channel and type(frame) == "table" then
--     local source = frame[1]
--     local data = table.unpack(frame, 2)

--     if type(source) == "number" then
--     end
--   end
-- end

--------------------------------------------------------------------------------

-- --- A data link layer protocol (OSI layer 2).
-- ---
-- --- Broadlink is an unreliable broadcast protocol for transfer of data frames
-- --- between hosts connected to a modem.
-- local broadlink = {}

-- --- The unique protocol ID for Broadlink.
-- broadlink.upid = 1036
-- --- The channel that Broadlink data frames are transferred on.
-- broadlink.channel = broadlink.upid
-- --- The event name for received Broadlink data frames.
-- broadlink.event = "broadlink"

-- --- Sends a Broadlink data frame.
-- ---
-- --- @generic T : table
-- --- @param side computerSide
-- --- @param data T
-- function broadlink.send(side, data)
--   os.queueEvent(
--     "modem_message",
--     side,
--     broadlink.channel,
--     broadlink.channel,
--     { broadlink.pid, os.getComputerID(), data }
--   )
-- end

-- --- Receives a Broadlink data frame.
-- ---
-- --- This pauses execution on the current thread.
-- ---
-- --- @return computerSide side
-- --- @return integer source
-- --- @return table data
-- function broadlink.recv()
--   --- @diagnostic disable-next-line: param-type-mismatch
--   local _, side, source, data = os.pullEvent(broadlink.event)
--   return side, source, data
-- end

-- --- Handles a possible Broadlink data frame transfer.
-- ---
-- --- @param side computerSide
-- --- @param channel integer
-- --- @param frame table
-- function broadlink.daemon(side, channel, frame)
--   local upid, source, data = table.unpack(frame)

--   if
--     channel == broadlink.channel
--     and upid == broadlink.pid
--     and type(source) == "number"
--     and type(data) == "table"
--   then
--     if source == os.getComputerID() then
--       if peripheral.getType(side) == "modem" then
--         local modem = peripheral.wrap(side)
--         --- SAFETY: This is known to be correct based on the check above.
--         --- @cast modem Modem
--         modem.transmit(broadlink.channel, broadlink.channel, {
--           broadlink.pid,
--           source,
--           data
--         })
--         print("BROADLINK SEND:", side, data)
--       end
--     else
--       os.queueEvent(broadlink.event, side, source, data)
--       print("BROADLINK RECV:", side, source, data)
--     end
--   end
-- end

-- return broadlink

--------------------------------------------------------------------------------

-- local pretty = require("cc.pretty")
-- local render, pretty = pretty.render, pretty.pretty

-- local common = require("net.common")

-- --- A data link (OSI layer 2) protocol.
-- ---
-- --- Broadlink is an unreliable and unencrypted protocol that supports broadcast
-- --- modem-to-modem data frame communication.
-- local broadlink = {
--   --- The unique Broadlink protocol ID.
--   pid = 1036,
--   --- The Broadlink OS event name.
--   event = "broadlink",
-- }

-- --- Sends a Broadlink data frame.
-- ---
-- --- @generic T : table
-- --- @param side computerSide
-- --- @param data T
-- function broadlink.send(side, data)
--   os.queueEvent(
--     "modem_message",
--     side,
--     common.channel,
--     common.channel,
--     { broadlink.pid, os.getComputerID(), data }
--   )
-- end

-- --- Receives a Broadlink data frame.
-- ---
-- --- This pauses execution on the current thread.
-- ---
-- --- @return computerSide side
-- --- @return integer source
-- --- @return table data
-- function broadlink.recv()
--   --- @diagnostic disable-next-line
--   local _, side, source, data = os.pullEvent(broadlink.event)
--   return side, source, data
-- end

-- --- Handles the Broadlink protocol.
-- ---
-- --- Takes control of the execution on the current thread.
-- function broadlink.daemon()
--   while true do
--     --- @type event, computerSide, integer, integer, unknown
--     local _, side, _, _, frame = os.pullEvent("modem_message")

--     if
--     -- - Frame is a table.
--         type(frame) == "table"
--         -- - PID is the Broadlink PID.
--         and frame[1] == broadlink.pid
--         -- - Source is a number.
--         and type(frame[2]) == "number"
--         -- - Data is a table.
--         and type(frame[3]) == "table"
--     then
--       -- 1. If the above are true, this is a valid Broadlink data frame.

--       --- @type integer, table
--       local source, data = table.unpack(frame, 2)

--       if source == os.getComputerID() then
--         -- 2. If the source is this computer, send the data frame.
--         if peripheral.getType(side) == "modem" then
--           local modem = peripheral.wrap(side)
--           --- SAFETY: This is known to be true since we check above.
--           --- @cast modem Modem
--           modem.transmit(common.channel, common.channel, {
--             broadlink.pid,
--             source,
--             data
--           })

--           print("SEND:", side, source, render(pretty(data)))
--         end
--       else
--         -- 3. Otherwise the destination is this computer, consume the data frame
--         --    and re-queue it as a Broadlink event.
--         os.queueEvent(broadlink.event, side, source, data)

--         print("RECV:", side, source, render(pretty(data)))
--       end
--     end
--   end
-- end

-- if not package.loaded["net.broadlink"] then
--   -- This file was run as an executable.
--   broadlink.daemon()
-- else
--   -- This file was loaded as a library.
--   return broadlink
-- end
