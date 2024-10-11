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

          pretty.pretty_print(reply)

          --- @cast reply Message
          if reply ~= nil and reply.type == "status" then
            table.insert(replies, reply)
            exit = true
            return
          end
        end
      end,
      function ()
        local timer_id = os.startTimer(2)
        local _, id
        repeat
          _, id = os.pullEvent("timer")
        until id == timer_id
      end
    )
  end

  if #replies == 0 then
    return nil
  end

  return replies[1].value
end

function Queue:tryOrder()
  local avail = self:findAvailableTurtle()
  if avail ~= nil then
    local order = table.remove(self.orders, #self.orders)
    if order ~= nil then
      rednet.broadcast(order, "wherehouse_" .. avail.value.name)
    end
  end
end

return Queue
