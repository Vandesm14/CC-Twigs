--- @alias orderType "input"|"output"

--- @class Order
--- @field item string
--- @field count number
--- @field type orderType
--- @field actions string
local Order = {}
Order.__index = Order

--- comment
--- @param item string
--- @param count number
--- @param actions string
--- @param type orderType
--- @return table
function Order:new(item, count, actions, type)
  local o = {}
  o.item = item
  o.count = count
  o.type = type
  o.actions = actions:reverse()
  return setmetatable(o, self)
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
