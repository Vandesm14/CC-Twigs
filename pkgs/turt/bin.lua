local Walker = require "turt.walker"

local walker = Walker:new()
while true do
  if walker:step() then
    break
  end
end
