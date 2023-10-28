local pretty = require("cc.pretty")
local unilink = require("net.unilink")

--- Follownet is a network layer (OSI layer 3) protocol.
---
--- This is an unreliable protocol. It only attempts to forward packets to the
--- next host in the route via Unilink. Host discovery is not provided as part
--- of the protocol.
local follownet = {}

--- The unique ID for a Follownet packet.
follownet.pid = 2479
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
	--- @type UnilinkAddr[]
  local returnRoute = { destination, source }

  if source ~= nil and destination ~= nil then
    unilink.transmit(source, destination, {
    	follownet.pid,
    	route,
    	returnRoute,
    	data,
    })
  end
end

--- Receives a Follownet packet.
---
--- Pauses execution on the current thread.
---
--- @return "follownet" event
--- @return UnilinkAddr[] returnRoute
--- @return table data
function follownet.receive()
  --- @diagnostic disable-next-line: param-type-mismatch, return-type-mismatch
  return os.pullEvent(follownet.event)
end

--- Handles the next Follownet event.
---
--- If the Follownet event is not related to Follownet, then it's dropped.
---
--- Pauses execution on the current thread.
function follownet.handle()
  local _, _, _, packet = unilink.receive()

  if packet[1] == follownet.pid then
    --- @type UnilinkAddr[], UnilinkAddr[], table
    local route, returnRoute, data = table.unpack(packet, 2)
    --- @type UnilinkAddr|nil, UnilinkAddr|nil
    local source, destination = table.remove(route, 1), table.remove(route, 1)

    table.insert(returnRoute, 1, source)
    table.insert(returnRoute, 1, destination)

    if source ~= nil and destination ~= nil then
      unilink.transmit(source, destination, {
      	follownet.pid,
      	route,
      	returnRoute,
      	data,
      })
      print("SEND", pretty.render(pretty.pretty(route)))
    elseif source == nil and destination == nil then
      os.queueEvent(follownet.event, returnRoute, data)
      print("RECV")
    else
      print("DROP")
    end
  end
end

return follownet
