local pretty = require("cc.pretty")
local unilink = require("net.unilink")

local follownet = {}

-- TODO: Also contruct the route back to the source whilst transmitting.

--- The unique ID for a Follownet packet.
follownet.pid = 1035
--- The unique name for a Follownet packet receive event.
follownet.event = "follownet"

--- Transmits a Follownet packet.
---
--- The source and destination must be present in the route.
---
--- @param route UnilinkAddr[]
--- @param data table
function follownet.transmit(route, data)
  --- @type UnilinkAddr|nil, UnilinkAddr|nil
  local source, destination = table.remove(route, 1), table.remove(route, 1)

  if source ~= nil and destination ~= nil then
    unilink.transmit(source, destination, { follownet.pid, route, data })
  end
end

--- Receives a Follownet packet.
---
--- Pauses execution on the current thread.
---
--- @return "unilink" event
--- @return table data
function follownet.receive()
  --- @diagnostic disable-next-line: param-type-mismatch, return-type-mismatch
  return os.pullEvent(follownet.event)
end

--- Handles the next Unilink event.
---
--- If the Unilink event is not related to Follownet, then it's dropped.
---
--- Pauses execution on the current thread.
function follownet.handle()
  local _, _, _, packet = unilink.receive()

  if packet[1] == follownet.pid then
    --- @type UnilinkAddr[], table
    local route, data = table.unpack(packet, 2)
    --- @type UnilinkAddr|nil, UnilinkAddr|nil
    local source, destination = table.remove(route, 1), table.remove(route, 1)

    if source ~= nil and destination ~= nil then
      unilink.transmit(source, destination, { follownet.pid, route, data })
      print("SEND", pretty.render(pretty.pretty(route)))
    elseif source == nil and destination == nil then
      os.queueEvent(follownet.event, data)
      print("RECV")
    else
      print("DROP")
    end
  end
end

return follownet
