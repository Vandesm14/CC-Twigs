local pretty = require("cc.pretty")

local broadlink = require('net.broadlink')
local follownet = require("net.follownet")

local searchnet = {}

--- The Searchnet protocol ID that appears as the first item in the packet data.
searchnet.id = 179

searchnet.event = {}

--- The event name for received Searchnet packets.
searchnet.event.found = 'searchnet_found'
searchnet.event.search = "searchnet_search"

--- This contains everything related to the Searchnet daemon.
searchnet.scheduleStuff = {}
--- @type table<number, boolean | nil>
searchnet.scheduleStuff.queue = {}

--- Reverses a table
---
--- @generic T
--- @param table T[]
--- @return T[]
local function reverse(table)
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
--- @param event table
--- @param logs string[]
--- @return boolean consumedEvent
function searchnet.schedule(event, logs)
  return searchnet.scheduleStuff.receivePing(event, logs)
      or searchnet.scheduleStuff.receiveReply(event, logs)
      or searchnet.scheduleStuff.receiveSearch(event, logs)
end

--- Receives a Searchnet ping.
---
--- @param event table
--- @param logs string[]
--- @return boolean consumedEvent
function searchnet.scheduleStuff.receivePing(event, logs)
  if event[1] == broadlink.event then
    local _, side, _, packet = table.unpack(event)

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
          break
        end
      end

      -- If we haven't seen the message message, relay it
      if not alreadySeen then
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
          -- Reverse the trace since we want to go backwards
          local reversed = reverse(trace)
          -- Remove the origin from the beginning of the trace
          table.remove(reversed, 1)

          -- transmit via Follownet
          follownet.transmit(
            reversed,
            {
              packet[1],
              packet[2],
              trace
            }
          )

            logs[#logs + 1] = "SN FLLW:" .. reversed[#reversed]
        else
          -- Else, relay the package
          -- Send the packet to all sides
          --- @diagnostic disable-next-line: redefined-local
          for _, side in ipairs(peripheral.getNames()) do
            if peripheral.getType(side) == "modem" then
              broadlink.transmit(side, packet)
            end
          end

            logs[#logs + 1] = "SN RELAY:" .. side .. destination
        end
      else
          logs[#logs + 1] = "SN SEEN:" .. side .. destination
      end

      return true
    else
      return false
    end
  else
    return false
  end
end

--- Receives a reply from a destination, which is a follownet packet.
---
--- @param event table
--- @param logs string[]
--- @return boolean consumedEvent
function searchnet.scheduleStuff.receiveReply(event, logs)
  if event[1] == follownet.event then
    local _, _, _, packet = table.unpack(event)

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
      if searchnet.scheduleStuff.queue[destination] then
        -- Remove the destination from the watch queue
        searchnet.scheduleStuff.queue[destination] = false

        os.queueEvent(searchnet.event.found, trace)

        logs[#logs + 1] = "SN FIND:" .. pretty.render(pretty.pretty(trace))
        return true
      else
        -- Drop the packet.
        logs[#logs + 1] = "SN DROP"
        return true
      end
    else
      logs[#logs + 1] = "SN OTHR"
      return false
    end
  else
    return false
  end
end

--- Receives an event to start a search.
---
--- @param event table
--- @param logs string[]
--- @return boolean consumedEvent
function searchnet.scheduleStuff.receiveSearch(event, logs)
  if event[1] == searchnet.event.search then
    --- @diagnostic disable-next-line: param-type-mismatch
    local _, destination = table.unpack(event)

    searchnet.scheduleStuff.queue[destination] = true

    for _, side in ipairs(peripheral.getNames()) do
      broadlink.transmit(side, {
        searchnet.id,
        destination,
        { os.getComputerID() }
      })
    end

    return true
    -- TODO: elseif event[1] == "timer" then
  else
    return false
  end
end

--- Attemps to find a path to the destination.
---
--- @param destination integer
--- @return integer[]|nil path
function searchnet.search(destination)
  os.queueEvent(searchnet.event.search, destination)
  -- TODO: add a TTL arg and wait for a timeout
  --- @diagnostic disable-next-line: param-type-mismatch
  local _, path = os.pullEvent(searchnet.event.found)
  return path
end

return searchnet
