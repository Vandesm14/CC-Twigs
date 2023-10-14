local broadlink = require('net.broadlink')
-- local follownet = require("net.follownet")

local searchnet = {}

--- The Searchnet protocol ID that appears as the first item in the packet data.
searchnet.id = 179
--- The event name for received Searchnet packets.
searchnet.event = 'searchnet'

--- This contains everything related to the Searchnet daemon.
searchnet.daemon = {}
searchnet.daemon.deprioritize = false
--- @type table<number, boolean | nil>
searchnet.daemon.queue = {}
--- @type table<number, number[]>
searchnet.daemon.routes = {}

-- Handles a possible Searchnet ping.
--
-- This pauses execution on the current thread.
--
-- @return boolean deprioritize
function searchnet.daemon.daemon()
  searchnet.daemon.deprioritize = false

  parallel.waitForAny(
    searchnet.daemon.receivePing,
    searchnet.daemon.receiveReply
  )

  return searchnet.daemon.deprioritize
end

function searchnet.daemon.receivePing()
  local side, source, packet = broadlink.receive()
  local revert = function() os.queueEvent(broadlink.event, side, source, packet) end

  -- 1. If packet is a valid Searchnet packet...
  -- 2. Otherwise...
  if
  -- Searchnet ID
      packet[1] == searchnet.id
      -- Destination ID
      and type(packet[2]) == "number"
      -- Trace (includes origin as first entry)
      and type(packet[3]) == "table"
  then
    --- @type number, number[]
    local destination, trace = packet[2], packet[3]

    -- If we haven't seen the message message, relay it
    if
        not trace[os.getComputerId()]
    then
      local trace = packet[3]

      -- Append our ID to the trace
      trace[#trace + 1] = os.getComputerId()

      -- Update the trace in the packet
      packet = {
        packet[1],
        packet[2],
        trace
      }

      -- If we are the destination, send it back to the origin
      if destination == os.getComputerId() then
        -- TODO: transmit via Follownet
        follownet.transmit()

        print("SN FLLW")
      else
        -- Else, relay the package
        -- Send the packet to all sides
        for _, side in ipairs(peripheral.getNames()) do
          if peripheral.getType(side) == "modem" then
            broadlink.transmit(side, packet)
          end
        end

        print("SN RELAY")
      end
    end
  else
    revert()

    print("SN OTHR")
    searchnet.daemon.deprioritize = true
  end
end

-- Receives a reply from a destination, which is a follownet packet.
function searchnet.daemon.receiveReply()
  local side, source, packet = follownet.receive()
  local revert = function() os.queueEvent(follownet.event, side, source, packet) end

  -- 1. If packet is a valid Searchnet packet...
  -- 2. Otherwise...
  if
  -- Searchnet ID
      packet[1] == searchnet.id
      -- Destination ID
      and type(packet[2]) == "number"
      -- Trace (includes origin as first entry)
      and type(packet[3]) == "table"
  then
    -- If we are awaiting a reply from this destination, handle it
    if searchnet.daemondata.queue[destination] then
      searchnet.daemondata.queue[destination] = false

      searchnet.daemondata.routes[destination] = trace
    else
      -- Drop the packet.
      print("SN DROP")
      return false
    end
  else
    revert()

    print("SN OTHR")
    searchnet.daemon.deprioritize = true
  end
end

-- Broadcasts a Searchnet ping
--
-- @param destination number
function searchnet.search(destination)
  for _, side in ipairs(peripheral.getNames()) do
    broadlink.transmit(side, {
      searchnet.id,
      destination,
      { os.getComputerId() }
    })
  end
end

function searchnet.receive()
  --- @diagnostic disable-next-line: param-type-mismatch
  local _, route = os.pullEvent(searchnet.event)
  return route
end

return searchnet
