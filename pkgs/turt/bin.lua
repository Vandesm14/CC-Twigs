local pretty = require "cc.pretty"
local Walker = require "turt.walker"

rednet.open("right")

while true do
  local id, message = rednet.receive("wherehouse")
  print("Received message from " .. id .. ":")
  pretty.pretty_print(message)

  --- @cast message Order
  if message ~= nil and message.item ~= nil then
    local walker = Walker:new(message)
    while true do
      if walker:step() then
        break
      end
    end
  end
end
