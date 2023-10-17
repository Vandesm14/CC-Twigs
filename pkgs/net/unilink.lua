local pretty = require("cc.pretty")

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
--- @param event table
--- @param logs string[]
--- @return boolean consumedEvent
function unilink.schedule(event, logs)
  if event[1] == "modem_message" then
    --- @type event, computerSide, integer, integer, table, integer
    local _, side, channel, _, frame, _ = table.unpack(event)

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

          -- pretty.render(pretty.pretty(data))
          logs[#logs + 1] = table.concat({ "UL SEND:", side, destination }, " ")
          return true
        else
          -- 1.2.2.1. ...Drop the data frame.
          -- pretty.render(pretty.pretty(data))
          logs[#logs + 1] = table.concat({ "UL DROP", side }, " ")
          return true
        end
      elseif destination == os.getComputerID() then
        -- 1.3.1. ...Queue an Unilink event.
        os.queueEvent(unilink.event, side, source, data)

        -- pretty.render(pretty.pretty(data))
        logs[#logs + 1] = table.concat({ "UL RECV:", side, source }, " ")
        return true
      else
        -- 1.4.1. ...Drop the data frame.
        -- pretty.render(pretty.pretty(data))
        logs[#logs + 1] = table.concat({ "UL DROP", side }, " ")
        return true
      end
    else
      -- 2.1. ...Re-queue the event since it was not Unilink related.
      return false
    end
  else
    return false
  end
end

return unilink
