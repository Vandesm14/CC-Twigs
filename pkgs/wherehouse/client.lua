local pretty = require("cc.pretty")
local follownet = require("net.follownet")

local protocol = {}
protocol.pid = 3524

-- recv { pid, path: integer[], type: "list" }
-- send { pid, path: integer[], type: "list", data: tablewhatever }

while true do
  local _, _, packet = follownet.receive()
  local pid, path, type_, _ = table.unpack(packet)

  local items = {}

  if
      pid == protocol.pid
      and type(path) == "table"
      and type(type_) == "string"
  -- ...
  then
    -- If this is a list request
    if type_ == "list" then
      -- Scan each chest for items, until we hit the end-stop
      while turtle.forward() do
        --- @diagnostic disable-next-line: param-type-mismatch
        local chest = peripheral.find("minecraft:chest")
        --- @cast chest Inventory

        if not chest then
          printError("Not connected to a chest")
          return
        end

        -- Run through each item in the chest
        for slot, item in pairs(chest.list()) do
          local name, count = item.name, item.count
          -- Update or set the entry
          if items[name] ~= nil then
            items[name] = items[name] + count
          else
            items[name] = count
          end
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
    end
  end
end
