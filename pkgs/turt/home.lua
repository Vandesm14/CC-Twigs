local Walker = require "turt.walker"
local Order = require "turt.order"

local walker = Walker:new(Order:new("nil", 0, Position:new(0, 0, 0), "input"))
while true do
  if walker:step() then
    break
  end
end
