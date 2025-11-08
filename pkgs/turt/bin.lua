local pretty = require "cc.pretty"
local Walker = require "turt.walker"
local Order = require "turt.order"

rednet.open("right")

--- @type Walker|nil
local walker = nil
local OUR_NAME = os.getComputerLabel()
if OUR_NAME == nil then
  OUR_NAME = tostring(os.getComputerID())
end

---comment
---@param id number|nil
---@param message Message
local function handleMessage(id, message)
  print("Received message from " .. id .. ":")
  pretty.pretty_print(message)

  if message ~= nil and message.type == "order" then
    local order = message.value
    if order.item ~= nil then
      walker = Walker:new(Order:new(order.item, order.count, order.actions:reverse(), order.type))
      return
    end
  elseif message ~= nil and id ~= nil and message.type == "avail" then
    local isBlock, info = turtle.inspectDown()
    if isBlock and info then
      local color = Walker.getColor(info.tags)
      if color == "red" then
        rednet.broadcast(
          {
            type = "status",
            value = {
              name = OUR_NAME,
              fuel = turtle.getFuelLevel()
            }
          },
          "wh"
        )
      end
    end
  end
end

local function waitForGlobal()
  handleMessage(rednet.receive("wh"))
end

local function waitForSelf()
  handleMessage(rednet.receive("wh_" .. OUR_NAME))
end

while true do
  if walker ~= nil then
    if walker:step() then
      walker = nil
    end
  else
    parallel.waitForAny(waitForGlobal, waitForSelf)
  end
end
