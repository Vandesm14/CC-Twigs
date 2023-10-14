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
--- @return boolean deprioritise
function unilink.daemon()
  --- @type event, computerSide, integer, integer, table, integer
  local event, side, channel, replyChannel, frame, distance = os.pullEvent("modem_message")

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

        print("UL SEND:", side, pretty.render(pretty.pretty(data)))
        return false
      else
        -- 1.2.2.1. ...Drop the data frame.
        print("UL DROP", side, pretty.render(pretty.pretty(data)))
        return false
      end
    elseif destination == os.getComputerID() then
      -- 1.3.1. ...Queue an Unilink event.
      os.queueEvent(unilink.event, side, source, data)

      print("UL RECV:", side, source, pretty.render(pretty.pretty(data)))
      return false
    else
      -- 1.4.1. ...Drop the data frame.
      print("UL DROP", side, pretty.render(pretty.pretty(data)))
      return false
    end
  else
    -- 2.1. ...Re-queue the event since it was not Unilink related.
    os.queueEvent(event, side, channel, replyChannel, frame, distance)

    print("UL OTHR")
    return true
  end
end

return unilink
