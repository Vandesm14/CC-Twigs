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
  for _, item in ipairs(chest.list()) do
    local name, count = item.name, item.count

    -- Update or set the entry
    if table[name] ~= nil then
      table[name] = table[name] + count
    else
      table[name] = count
    end
  end
end

while true do
  local _, _, packet = follownet.receive()
  local pid, path, type_, _ = table.unpack(packet)

  if
      pid == protocol.pid
      and type(path) == "table"
      and type(type_) == "string"
  then
    -- If this is a list request
    if type_ == "list" then
      local items = {}

      -- Scan each chest for items, until we hit the end-stop
      while turtle.forward() do
        --- @diagnostic disable-next-line: param-type-mismatch
        local chest = peripheral.find("minecraft:chest")
        --- @cast chest Inventory

        if chest then
          countItems(chest, items)
        end
      end

      -- Go back to the starting end-stop
      while turtle.back() do end

      follownet.transmit(path, {
        protocol.pid,
        path,
        type_,
        items
      })
    elseif type_ == "order" then
      --- @type table<string, integer>
      local myItems = {}
      --- @type table<string, integer>
      local order = {}

      -- Add 0's for all the order items
      for name, _ in ipairs(order) do
        myItems[name] = 0
      end

      -- Scan each chest for items, until we hit the end-stop
      while turtle.forward() do
        --- @diagnostic disable-next-line: param-type-mismatch
        local chest = peripheral.find("minecraft:chest")
        --- @cast chest Inventory

        -- If there is a chest, check for items
        if chest then
          -- Run through each item
          for _, item in ipairs(chest.list()) do
            -- If the order wants this item, and we don't have enough
            if order[item.name] and order[item.name] > myItems[item.name] then
              chest.pullItems()
            end
          end
        end
      end
    end
  end
end
