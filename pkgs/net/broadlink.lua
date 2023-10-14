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

        print("BL SEND:", side, data)
        return false
      end
      -- 1.2.2.1. ...Drop the data frame.

      print("BL DROP", side, data)
      return false
    else
      -- 1.3.1. ...Queue a Broadlink event.
      os.queueEvent(broadlink.event, side, source, data)

      print("BL RECV:", side, source, data)
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
