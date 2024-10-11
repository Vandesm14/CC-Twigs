local pretty = require "cc.pretty"
local Walker = require "turt.walker"

rednet.open("right")

---comment
---@param id number|nil
---@param message Message
local function handleMessage(id, message)
  print("Received message from " .. id .. ":")
  pretty.pretty_print(message)

  if message ~= nil and message.type == "order" then
    local order = message.value
    if order.item ~= nil then
      local walker = Walker:new(order)
      while true do
        if walker:step() then
          break
        end
      end
    end
  elseif message ~= nil and id ~= nil and message.type == "avail" then
    rednet.broadcast(
      {
        type = "status",
        value = {
          name = os.getComputerLabel(),
          fuel = turtle.getFuelLevel()
        }
      },
      "wherehouse"
    )
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
