local pretty = require "cc.pretty"

--- @alias orders table<number, Order>

--- @class Queue
--- @field orders orders
local Queue = {}
Queue.__index = Queue

---comment
---@param orders orders
---@return Queue
function Queue:new(orders)
  local self = setmetatable({}, Queue)
  self.orders = orders
  return self
end

---comment
---@return StatusMessage|nil
function Queue:findAvailableTurtle()
  --- @type AvailMessage
  local msg = {type = "avail"}

  local replies = {}
  local exit = false
  while not exit do
    rednet.broadcast(msg, "wherehouse")
    parallel.waitForAny(
      function ()
        while true do
          local _, reply = rednet.receive("wherehouse")

          --- @cast reply Message
          if reply ~= nil and reply.type == "status" then
            table.insert(replies, reply)
            exit = true
            return
          end
        end
      end,
      function ()
        local timer_id = os.startTimer(5)
        local _, id
        repeat
          _, id = os.pullEvent("timer")
        until id == timer_id

        print("Waiting for available turtle...")
      end
    )
  end

  if #replies == 0 then
    return nil
  end

  return replies[1]
end

function Queue:tryOrder(order)
  local avail = self:findAvailableTurtle()
  if avail ~= nil then
    --- @type OrderMessage
    local msg = { type = "order", value = order }

    if order ~= nil then
      print("Queued '" .. order.item .. "' to '" .. avail.value.name .. "'.")
      rednet.broadcast(msg, "wherehouse_" .. avail.value.name)
    end
  end
end

function Queue:run()
  for _, order in ipairs(self.orders) do
    self:tryOrder(order)
  end
end

return Queue
