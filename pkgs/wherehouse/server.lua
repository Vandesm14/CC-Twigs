local pretty = require("cc.pretty")
local follownet = require("net.follownet")

local protocol = {}
protocol.pid = 3524

-- recv { pid, path: integer[], type: "list" }
-- send { pid, path: integer[], type: "list", data: table }

-- recv { pid, path: integer[]. type: "order", data: table }
-- send { pid, path: integer[]. type: "order", data: table }

--- @param chest Inventory
--- @param table table
local function countItems(chest, table)
  -- Run through each item in the chest
  for _, item in pairs(chest.list()) do
    local name, count = item.name, item.count

    -- Update or set the entry
    if table[name] ~= nil then
      table[name] = table[name] + count
    else
      table[name] = count
    end
  end
end

--- Receives a reply from a destination, which is a Wherehouse packet.
---
--- @param event table
--- @param logs string[]
--- @return boolean consumedEvent
function protocol.schedule(event, logs)
  if event[1] == follownet.event then
    local _, _, _, packet = table.unpack(event)
    local pid, path, type_, order = table.unpack(packet)

    if
        pid == protocol.pid
        and type(path) == "table"
        and type(type_) == "string"
    then
      -- If this is a list request
      if type_ == "list" then
        local items = {}

        -- Scan each chest for items, until we hit the end-stop
        --- @diagnostic disable-next-line: param-type-mismatch
        for _, chest in ipairs({ peripheral.find("minecraft:chest") }) do
          --- @cast chest Inventory

          if chest ~= nil then
            countItems(chest, items)
          end
        end

        -- Relay back to the client
        follownet.transmit(path, {
          protocol.pid,
          path,
          type_,
          items
        })
      elseif type_ == "order" and type(order) == "table" then
        --- @type table<string, integer>
        local myItems = {}

        --- The distribution chest MUST be a single chest
        --- and the storage chests MUST be double chests
        --- @diagnostic disable-next-line: param-type-mismatch
        local distributionChest = peripheral.find("minecraft:barrel")
        --- @cast distributionChest Inventory

        if distributionChest == nil then
          printError("No distribution chest found.")
          return true
        end

        -- Add 0's for all the order items
        for name, _ in pairs(order) do
          myItems[name] = 0
        end

        -- Scan each chest for items, until we hit the end-stop
        --- @diagnostic disable-next-line: param-type-mismatch
        for _, chest in ipairs({ peripheral.find("minecraft:chest", function(_, chest) return chest.size() == 54 end) }) do
          --- @cast chest Inventory
          local chestName = peripheral.getName(chest)

          print("Found chest '" .. chestName .. "'...")

          -- Check for items. Run through each item
          for slot, item in pairs(chest.list()) do
            if item ~= nil then
              -- If the order wants this item...
              if order[item.name] ~= nil then
                local need = order[item.name] - myItems[item.name]

                -- ...and we don't have enough
                if need > 0 then
                  -- Move the items into our distribution chest
                  local success, got = pcall(
                    distributionChest.pullItems,
                    chestName,
                    slot,
                    need
                  )

                  if success then
                    -- Add this action to our running totals
                    myItems[item.name] = myItems[item.name] + got
                    print(
                      "  Got",
                      tostring(got),
                      item.name .. ", need",
                      tostring(need - got),
                      "more."
                    )
                  else
                    printError("  Unable to pull from it.")
                    break
                  end
                end
              end
            end
          end
        end

        -- Relay back to the client
        follownet.transmit(
          path, {
            protocol.pid,
            path,
            type_,
            myItems,
          }
        )
      end

      return true
    else
      return false
    end
  else
    return false
  end
end

return protocol
