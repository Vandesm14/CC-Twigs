local Walker = require "turt.walker"
local Order = require "turt.order"
local branches = require "branches.lua"

local walker = Walker:new(Order:new("minecraft:cobblestone", 1,
  branches.input[1] + branches.storage[1] + branches.output["_"], "input"))
while true do
  if walker:step() then
    break
  end
end
