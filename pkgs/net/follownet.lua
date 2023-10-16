local pretty = require("cc.pretty")

local broadlink = require("net.broadlink")

--- A network layer protocol (OSI layer 3).
---
--- Follownet is an unreliable packet forwarding protocol for transfer of
--- packets between hosts on a network.
---
--- This only attempts to follow a route, it does not handle host discovery.
local follownet = {}

--- The Follownet protocol ID that appears as the first item in the packet data.
follownet.id = 2479
--- The event name for received Follownet packets.
follownet.event = "follownet"

--- Sends a Follownet data frame.
---
--- @generic T: table
--- @param path integer[]
--- @param data T
function follownet.transmit(path, data)
  for i = 1, #path / 2 do
    local temp = path[(#path + 1) - i]
    path[(#path + 1) - i] = path[i]
    path[i] = temp
  end

  for _, side in ipairs(peripheral.getNames()) do
    if peripheral.getType(side) == "modem" then
      broadlink.transmit(side, { follownet.id, path, data })
    end
  end
end

--- Receives a Follownet data frame.
---
--- This pauses execution on the current thread.
---
--- @return computerSide side
--- @return integer source
--- @return table data
function follownet.receive()
  --- @diagnostic disable-next-line: param-type-mismatch
  local _, side, source, data = os.pullEvent(follownet.event)
  return side, source, data
end

--- Handles a possible Follownet packet transfer.
---
--- This pauses execution on the current thread.
---
--- @param event table
--- @param logs string[]
--- @return boolean consumedEvent
function follownet.schedule(event, logs)
  if event[1] == broadlink.event then
    local _, side, source, packet = table.unpack(event)

    -- 1. If packet is a valid Follownet packet...
    -- 2. Otherwise...
    if
        packet[1] == follownet.id
        and type(packet[2]) == "table"
        and type(packet[3]) == "table"
    then
      -- 1.1. ...Extract the path and data.
      --- @type table, table
      local path, data = packet[2], packet[3]
      local nextId = table.remove(path, #path)

      -- 1.2. If the packet is for this computer...
      -- 1.3. If the packet is to be re-transmitted...
      -- 1.4. Otherwise...
      if #path == 0 and nextId == os.getComputerID() then
        -- 1.2.1. ...Queue a Follownet event.
        os.queueEvent(follownet.event, side, source, data)

        logs[#logs + 1] = "FN RECV:" .. side .. source .. pretty.render(pretty.pretty(data))
        return true
      elseif #path > 0 and nextId == os.getComputerID() then
        -- 1.3.1. ...Re-transmit the packet to the nextId via all modem.
        --- @diagnostic disable-next-line: redefined-local
        for _, side in ipairs(peripheral.getNames()) do
          if peripheral.getType(side) == "modem" then
            broadlink.transmit(side, { follownet.id, path, data })

            logs[#logs + 1] = "FN SEND:" .. side .. source .. pretty.render(pretty.pretty(data))
          end
        end

        return true
      else
        -- 1.4.1. ...Drop the packet.
        logs[#logs + 1] = "FN DROP" .. side .. nextId .. pretty.render(pretty.pretty(path)) .. pretty.render(pretty.pretty(data))
        return true
      end
    else
      -- 2.1. ...Re-queue the event since it was not Follownet related.
      return false
    end
  else
    return false
  end
end

return follownet
