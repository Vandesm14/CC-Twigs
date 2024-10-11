local Position = require "wherehouse.lib"

--- @alias orderType "input"|"output"

--- @class Order
--- @field item string
--- @field count number
--- @field pos Position
--- @field type orderType
local Order = {}

--- comment
--- @param item string
--- @param count number
--- @param pos Position
--- @param type orderType
--- @return table
function Order:new(item, count, pos, type)
  local self = setmetatable({}, Order)
  self.item = item
  self.count = count
  self.pos = pos
  self.type = type
  return self
end

return Order
