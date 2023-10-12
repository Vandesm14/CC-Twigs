local pretty = require("cc.pretty")
local render, pretty = pretty.render, pretty.pretty

--- A data link (OSI layer 2) protocol.
---
--- Unilink is an unreliable and unencrypted protocol that supports unicast
--- modem-to-modem data frame communication.
local unilink = {
  --- The unique Unilink protocol ID.
  pid = 1035,
  --- The Unilink OS event name.
  event = "unilink",
}

--- Sends a Unilink data frame.
---
--- @generic T : table
--- @param side computerSide
--- @param channel integer
--- @param destination integer
--- @param data T
function unilink.send(side, channel, destination, data)
  os.queueEvent(
    "modem_message",
    side,
    channel,
    channel,
    { unilink.pid, channel, os.getComputerID(), destination, data }
  )
end

--- Receives a Unilink data frame.
---
--- This pauses execution on the current thread.
---
--- @return computerSide side
--- @return integer channel
--- @return integer source
--- @return table data
function unilink.recv()
  --- @diagnostic disable-next-line
  local _, side, channel, source, data = os.pullEvent(unilink.event)
  return side, channel, source, data
end

--- Handles the Unilink protocol.
---
--- Takes control of the execution on the current thread.
function unilink.daemon()
  while true do
    --- @type event, computerSide, integer, integer, unknown
    local _, side, _, _, frame = os.pullEvent("modem_message")

    if
    -- - Frame is a table.
        type(frame) == "table"
        -- - PID is the Unilink PID.
        and frame[1] == unilink.pid
        -- - Channel is a number.
        and type(frame[2]) == "number"
        -- - Source is a number.
        and type(frame[3]) == "number"
        -- - Destination is a number.
        and type(frame[4]) == "number"
        -- - Data is a table.
        and type(frame[5]) == "table"
    then
      -- 1. If the above are true, this is a valid Unilink data frame.

      --- @type integer, integer, integer, table
      local channel, source, destination, data = table.unpack(frame, 2)

      if source == os.getComputerID() then
        -- 2. If the source is this computer, send the data frame.
        if peripheral.getType(side) == "modem" then
          local modem = peripheral.wrap(side)
          --- SAFETY: This is known to be true since we check above.
          --- @cast modem Modem
          modem.transmit(channel, channel, {
            unilink.pid,
            channel,
            source,
            destination,
            data
          })

          print("SEND:", side, channel, source, destination, render(pretty(data)))
        end
      elseif destination == os.getComputerID() then
        -- 3. If the destination is this computer, consume the data frame and
        --    re-queue it as a Unilink event.
        os.queueEvent(unilink.event, side, channel, source, data)

        print("RECV:", side, channel, source, destination, render(pretty(data)))
      end
    end
  end
end

if not package.loaded["net.unilink"] then
  -- This file was run as an executable.
  unilink.daemon()
else
  -- This file was loaded as a library.
  return unilink
end
