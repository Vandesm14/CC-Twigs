local Position = require "wherehouse.lib"

--- @class Order
--- @field item string
--- @field count number
--- @field pos Position
local Order = {}

--- comment
--- @param item string
--- @param count number
--- @param pos Position
--- @return table
function Order:new(item, count, pos)
  local self = setmetatable({}, Order)
  self.item = item
  self.count = count
  self.pos = pos
  return self
end

return Order
