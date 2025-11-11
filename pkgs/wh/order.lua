--- @alias ChestSlot { chest_id: number, slot_id: number }

--- @alias orderType "input"|"output"

--- @class Order
--- @field item string
--- @field count number
--- @field from ChestSlot
--- @field to ChestSlot
--- @field type orderType
local Order = {}
Order.__index = Order

--- comment
--- @param item string
--- @param count number
--- @param from ChestSlot
--- @param to ChestSlot
--- @param type orderType
--- @return Order
function Order:new(item, count, from, to, type)
  local o = {}
  o.item = item
  o.count = count
  o.from = from
  o.to = to
  o.type = type
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
  return setmetatable(o, self)
end

return Order
