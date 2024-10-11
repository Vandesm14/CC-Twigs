local pretty = require "cc.pretty"
local Walker = require "turt.walker"

rednet.open("right")

local function handleMessage(id, message)
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

local function waitForGlobal()
  handleMessage(rednet.receive("wherehouse"))
end

local function waitForSelf()
  handleMessage(rednet.receive("wherehouse_" .. os.getComputerLabel()))
end

while true do
  parallel.waitForAny(waitForGlobal, waitForSelf)
end
