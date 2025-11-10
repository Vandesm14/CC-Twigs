--- @alias ChestSlot { chest_id: number, slot_id: number }

--- @alias orderType "input"|"output"

--- @class Order
--- @field item string
--- @field count number
--- @field from ChestSlot
--- @field to ChestSlot
--- @field type orderType
--- @field actions string
local Order = {}
Order.__index = Order

--- comment
--- @param item string
--- @param count number
--- @param from ChestSlot
--- @param to ChestSlot
--- @param actions string
--- @param type orderType
--- @return Order
function Order:new(item, count, from, to, actions, type)
  local o = {}
  o.item = item
  o.count = count
  o.from = from
  o.to = to
  o.type = type
  o.actions = actions
  return setmetatable(o, self)
end

--- comment
--- @param actions string
--- @return Order
function Order:with_actions(actions)
  local o = {}
  o.actions = actions
  return setmetatable(o, self)
end

--- comment
--- @param order Order
--- @return Order
function Order:from_order(order)
  local o = {}
  o.item = order.item
  o.count = order.count
  o.from = order.from
  o.to = order.to
  o.type = order.type
  o.actions = order.actions
  return setmetatable(o, self)
end

function Order:reverse_actions()
  self.actions = self.actions:reverse()
end

--- returns the next action in the string
--- @return string|nil
function Order:next_action()
  local len = self.actions:len()

  if len > 0 then
    local action = self.actions:sub(len)
    self.actions = self.actions:sub(1, len - 1)
    return action
  else
    return nil
  end
end

return Order
