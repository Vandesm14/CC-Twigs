local broadlink = require('net.broadlink')
local follownet = require("net.follownet")
local pretty = require("cc.pretty")

local searchnet = {}

--- The Searchnet protocol ID that appears as the first item in the packet data.
searchnet.id = 179

searchnet.event = {}

--- The event name for received Searchnet packets.
searchnet.event.found = 'searchnet_found'
searchnet.event.search = "searchnet_search"

--- This contains everything related to the Searchnet daemon.
searchnet.daemon = {}
searchnet.daemon.deprioritize = false
--- @type table<number, boolean | nil>
searchnet.daemon.queue = {}
--- @type table<number, number[]>
searchnet.daemon.routes = {}

--- Reverses a table
---
--- @generic T
--- @param table T[]
--- @return T[]
function reverse(table)
  local newTable = {}
  for i = #table, 1, -1 do
    newTable[#newTable + 1] = table[i]
  end

  return newTable
end

--- Handles a possible Searchnet ping.
---
--- This pauses execution on the current thread.
---
--- @return boolean deprioritize
function searchnet.daemon.daemon()
  searchnet.daemon.deprioritize = false

  parallel.waitForAny(
    searchnet.daemon.receivePing,
    searchnet.daemon.receiveReply,
    searchnet.daemon.receiveSearch
  )

  return searchnet.daemon.deprioritize
end

--- Receives a Searchnet ping.
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

    local alreadySeen = false
    for _, id in ipairs(trace) do
      if id == os.getComputerID() then
        alreadySeen = true
      end
    end

    -- If we haven't seen the message message, relay it
    if
      not alreadySeen
    then
      -- Append our ID to the trace
      trace[#trace + 1] = os.getComputerID()

      -- Update the trace in the packet
      packet = {
        packet[1],
        packet[2],
        trace
      }

      -- If we are the destination, send it back to the origin
      if destination == os.getComputerID() then
        -- Remove the origin from the beginning of the trace
        table.remove(trace, 1)
        -- Reverse the trace since we want to go backwards
        local reversed = reverse(trace)

        -- TODO: transmit via Follownet
        follownet.transmit(
          reversed,
          {
            packet[1],
            packet[2],
            trace
          }
        )

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

    print("SN SEEN")
  else
    revert()

    print("SN OTHR")
    searchnet.daemon.deprioritize = true
  end
end

--- Receives a reply from a destination, which is a follownet packet.
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
    local destination, trace = packet[2], packet[3]

    -- If we are awaiting a reply from this destination, handle it
    if searchnet.daemon.queue[destination] then
      searchnet.daemon.queue[destination] = false

      searchnet.daemon.routes[destination] = trace

      os.queueEvent(searchnet.event.found, trace)
    else
      -- Drop the packet.
      print("SN DROP")
    end
  else
    revert()

    print("SN OTHR")
    searchnet.daemon.deprioritize = true
  end
end

--- Receives an event to start a search.
function searchnet.daemon.receiveSearch()
  --- @diagnostic disable-next-line: param-type-mismatch
  local _, destination = os.pullEvent(searchnet.event.search)

  searchnet.daemon.queue[destination] = true

  for _, side in ipairs(peripheral.getNames()) do
    broadlink.transmit(side, {
      searchnet.id,
      destination,
      { os.getComputerID() }
    })
  end
end

--- Attemps to find a path to the destination.
---
--- @param destination number
--- @return path integer[]|nil
function searchnet.search(destination)
  os.queueEvent(searchnet.event.search, destination)
  local _, path = os.pullEvent(searchnet.event.found)
  return path
end

return searchnet
