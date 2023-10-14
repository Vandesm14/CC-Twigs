--- A data link layer protocol (OSI layer 2).
---
--- Unilink is an unreliable broadcast protocol for transfer of data frames
--- between hosts connected to a modem.
local unilink = {}

--- The channel that Unilink data frames are transferred on.
unilink.channel = 1035
--- The event name for received Unilink data frames.
unilink.event = "unilink"

--- Sends an Unilink data frame.
---
--- @generic T: table
--- @param side computerSide
--- @param destination integer
--- @param data T
function unilink.transmit(side, destination, data)
  os.queueEvent(
    "modem_message",
    side,
    unilink.channel,
    unilink.channel,
    { os.getComputerID(), destination, data }
  )
end

--- Receives an Unilink data frame.
---
--- This pauses execution on the current thread.
---
--- @return computerSide side
--- @return integer source
--- @return table data
function unilink.receive()
  --- @diagnostic disable-next-line: param-type-mismatch
  local _, side, source, data = os.pullEvent(unilink.event)
  return side, source, data
end

--- Handles a possible Unilink data frame transfer.
---
--- This pauses execution on the current thread.
---
--- @return boolean deprioritise
function unilink.daemon()
  --- @type event, computerSide, integer, integer, table, integer
  local event, side, channel, replyChannel, frame, distance = os.pullEvent("modem_message")
  local revert = function() os.queueEvent(event, side, channel, replyChannel, frame, distance) end

  -- 1. If frame is a valid Unilink data frame...
  -- 2. Otherwise...
  if
    channel == unilink.channel
    and type(frame) == "table"
    and type(frame[1]) == "number"
    and type(frame[2]) == "number"
    and type(frame[3]) == "table"
  then
    -- 1.1. ...Extract the source and data.
    --- @type integer, integer, table
    local source, destination, data = frame[1], frame[2], frame[3]

    -- 1.2. If the source is this computer...
    -- 1.3. If the destination is this computer...
    -- 1.4. Otherwise...
    if source == os.getComputerID() then
      -- 1.2.1. ...If the specified side is a modem...
      -- 1.2.2. ...Otherwise...
      if peripheral.getType(side) == "modem" then
        -- 1.2.1.1. ...Transmit the data frame.
        local modem = peripheral.wrap(side)

        --- @cast modem Modem
        modem.transmit(unilink.channel, unilink.channel, {
          source,
          destination,
          data,
        })

        print("UL SEND:", side, data)
        return false
      end
      -- 1.2.2.1. ...Drop the data frame.

      print("UL DROP", data)
      return false
    elseif destination == os.getComputerID() then
      -- 1.3.1. ...Queue an Unilink event.
      os.queueEvent(unilink.event, side, source, data)

      print("UL RECV:", side, source, data)
      return false
    end
    -- 1.4.1. ...Drop the data frame.

    print("UL DROP", data)
    return false
  else
    -- 2.1. ...Re-queue the event since it was not Unilink related.
    revert()

    print("UL OTHR")
    return true
  end
end

return unilink

--------------------------------------------------------------------------------

-- --- A data link layer protocol (OSI layer 2).
-- ---
-- --- Unilink is an unreliable unicast protocol for transfer of data frames
-- --- between hosts connected to a modem.
-- local unilink = {}

-- --- The unique protocol ID for Unilink.
-- unilink.upid = 1035
-- --- The channel that Unilink data frames are transferred on.
-- unilink.channel = unilink.upid
-- --- The event name for received Unilink data frames.
-- unilink.event = "unilink"

-- --- Sends a Unilink data frame.
-- ---
-- --- @generic T : table
-- --- @param side computerSide
-- --- @param destination integer
-- --- @param data T
-- function unilink.send(side, destination, data)
--   os.queueEvent(
--     "modem_message",
--     side,
--     unilink.channel,
--     unilink.channel,
--     { unilink.pid, os.getComputerID(), destination, data }
--   )
-- end

-- --- Receives a Unilink data frame.
-- ---
-- --- This pauses execution on the current thread.
-- ---
-- --- @return computerSide side
-- --- @return integer source
-- --- @return table data
-- function unilink.recv()
--   --- @diagnostic disable-next-line: param-type-mismatch
--   local _, side, source, data = os.pullEvent(unilink.event)
--   return side, source, data
-- end

-- --- Handles a possible Unilink data frame transfer.
-- ---
-- --- @param side computerSide
-- --- @param channel integer
-- --- @param frame table
-- function unilink.daemon(side, channel, frame)
--   local upid, source, destination, data = table.unpack(frame)

--   if
--     channel == unilink
--     and upid == unilink.upid
--     and type(source) == "number"
--     and type(destination) == "number"
--     and type(data) == "table"
--   then
--     if source == os.getComputerID() then
--       if peripheral.getType(side) == "modem" then
--         local modem = peripheral.wrap(side)
--         --- SAFETY: This is known to be correct based on the check above.
--         --- @cast modem Modem
--         modem.transmit(unilink.channel, unilink.channel, {
--           unilink.pid,
--           source,
--           destination,
--           data
--         })
--         print("UNILINK SEND:", side, destination, data)
--       end
--     elseif destination == os.getComputerID() then
--       os.queueEvent(unilink.event, side, source, data)
--       print("UNILINK RECV:", side, source, data)
--     end
--   end

--   -- if
--   --   channel == unilink.channel
--   --   and type(frame) == "table"
--   --   and frame[1] == unilink.pid
--   --   and type(frame[2]) == "number"
--   --   and type(frame[3]) == "number"
--   --   and type(frame[4]) == "table"
--   -- then
--   --   --- SAFETY: These are known to be correct based on the check above.
--   --   --- @type integer, integer, table
--   --   local source, destination, data = table.unpack(frame, 2)

--   --   if destination == os.getComputerID() then
--   --     os.queueEvent(unilink.event, side, source, data)
--   --     print("UNILINK RECV:", side, source, data)
--   --   elseif source == os.getComputerID() then
--   --     if peripheral.getType(side) == "modem" then
--   --       local modem = peripheral.wrap(side)
--   --       --- SAFETY: This is known to be correct based on the check above.
--   --       --- @cast modem Modem
--   --       modem.transmit(unilink.channel, unilink.channel, {
--   --         unilink.pid,
--   --         source,
--   --         destination,
--   --         data
--   --       })
--   --       print("UNILINK SEND:", side, destination, data)
--   --     end
--   --   end
--   -- end
-- end

-- return unilink

--------------------------------------------------------------------------------

-- local pretty = require("cc.pretty")
-- local render, pretty = pretty.render, pretty.pretty

-- local common = require("net.common")

-- --- A data link (OSI layer 2) protocol.
-- ---
-- --- Unilink is an unreliable and unencrypted protocol that supports unicast
-- --- modem-to-modem data frame communication.
-- local unilink = {
--   --- The unique Unilink protocol ID.
--   pid = 1035,
--   --- The Unilink OS event name.
--   event = "unilink",
-- }

-- --- Sends a Unilink data frame.
-- ---
-- --- @generic T : table
-- --- @param side computerSide
-- --- @param destination integer
-- --- @param data T
-- function unilink.send(side, destination, data)
--   os.queueEvent(
--     "modem_message",
--     side,
--     common.channel,
--     common.channel,
--     { unilink.pid, os.getComputerID(), destination, data }
--   )
-- end

-- --- Receives a Unilink data frame.
-- ---
-- --- This pauses execution on the current thread.
-- ---
-- --- @return computerSide side
-- --- @return integer source
-- --- @return table data
-- function unilink.recv()
--   --- @diagnostic disable-next-line
--   local _, side, source, data = os.pullEvent(unilink.event)
--   return side, source, data
-- end

-- --- Handles the Unilink protocol.
-- ---
-- --- Takes control of the execution on the current thread.
-- function unilink.daemon()
--   while true do
--     --- @type event, computerSide, integer, integer, unknown
--     local _, side, _, _, frame = os.pullEvent("modem_message")

--     if
--     -- - Frame is a table.
--         type(frame) == "table"
--         -- - PID is the Unilink PID.
--         and frame[1] == unilink.pid
--         -- - Source is a number.
--         and type(frame[2]) == "number"
--         -- - Destination is a number.
--         and type(frame[3]) == "number"
--         -- - Data is a table.
--         and type(frame[4]) == "table"
--     then
--       -- 1. If the above are true, this is a valid Unilink data frame.

--       --- @type integer, integer, table
--       local source, destination, data = table.unpack(frame, 2)

--       if source == os.getComputerID() then
--         -- 2. If the source is this computer, send the data frame.
--         if peripheral.getType(side) == "modem" then
--           local modem = peripheral.wrap(side)
--           --- SAFETY: This is known to be true since we check above.
--           --- @cast modem Modem
--           modem.transmit(common.channel, common.channel, {
--             unilink.pid,
--             source,
--             destination,
--             data
--           })

--           print("SEND:", side, source, destination, render(pretty(data)))
--         end
--       elseif destination == os.getComputerID() then
--         -- 3. If the destination is this computer, consume the data frame and
--         --    re-queue it as a Unilink event.
--         os.queueEvent(unilink.event, side, source, data)

--         print("RECV:", side, source, destination, render(pretty(data)))
--       end
--     end
--   end
-- end

-- if not package.loaded["net.unilink"] then
--   -- This file was run as an executable.
--   unilink.daemon()
-- else
--   -- This file was loaded as a library.
--   return unilink
-- end
