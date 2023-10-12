local pretty = require("cc.pretty")
local render, pretty = pretty.render, pretty.pretty

--- A data link (OSI layer 2) protocol.
---
--- Broadlink is an unreliable and unencrypted protocol
local broadlink = {
  --- The unique Broadlink protocol ID.
  pid = 1036,
  --- The Broadlink OS event name.
  event = "broadlink",
}

--- Sends a Broadlink data frame.
---
--- @generic T : table
--- @param side computerSide
--- @param channel integer
--- @param data T
function broadlink.send(side, channel, data)
  os.queueEvent(
    "modem_message",
    side,
    channel,
    channel,
    { broadlink.pid, channel, os.getComputerID(), data }
  )
end

--- Receives a Broadlink data frame.
---
--- This pauses execution on the current thread.
---
--- @return computerSide side
--- @return integer channel
--- @return integer source
--- @return table data
function broadlink.recv()
  --- @diagnostic disable-next-line
  local _, side, channel, source, data = os.pullEvent(broadlink.event)
  return side, channel, source, data
end

--- Handles the Broadlink protocol.
---
--- Takes control of the execution on the current thread.
function broadlink.daemon()
  while true do
    --- @type event, computerSide, integer, integer, unknown
    local _, side, _, _, frame = os.pullEvent("modem_message")

    if
    -- - Frame is a table.
        type(frame) == "table"
        -- - PID is the Broadlink PID.
        and frame[1] == broadlink.pid
        -- - Channel is a number.
        and type(frame[2]) == "number"
        -- - Source is a number.
        and type(frame[3]) == "number"
        -- - Data is a table.
        and type(frame[4]) == "table"
    then
      -- 1. If the above are true, this is a valid Broadlink data frame.

      --- @type integer, integer, table
      local channel, source, data = table.unpack(frame, 2)

      if source == os.getComputerID() then
        -- 2. If the source is this computer, send the data frame.
        if peripheral.getType(side) == "modem" then
          local modem = peripheral.wrap(side)
          --- SAFETY: This is known to be true since we check above.
          --- @cast modem Modem
          modem.transmit(channel, channel, {
            broadlink.pid,
            channel,
            source,
            data
          })

          print("SEND:", side, channel, source, render(pretty(data)))
        end
      else
        -- 3. Otherwise the destination is this computer, consume the data frame
        --    and re-queue it as a Broadlink event.
        os.queueEvent(broadlink.event, side, channel, source, data)

        print("RECV:", side, channel, source, render(pretty(data)))
      end
    end
  end
end

if not package.loaded["net.broadlink"] then
  -- This file was run as an executable.
  broadlink.daemon()
else
  -- This file was loaded as a library.
  return broadlink
end
