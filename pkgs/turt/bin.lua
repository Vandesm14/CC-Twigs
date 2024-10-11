local pretty = require "cc.pretty"
local Walker = require "turt.walker"
local Order = require "turt.order"

local x = tonumber(arg[1])
local y = tonumber(arg[2])
local z = tonumber(arg[3])

local order = Order:new("minecraft:diamond", 1, Position:new(x, y, z))
print("Order:")
pretty.pretty_print(order)

local walker = Walker:new(order)
while true do
  if walker:step() then
    break
  end
end
