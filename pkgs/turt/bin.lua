local pretty = require "cc.pretty"
local Walker = require "turt.walker"
local Order = require "turt.order"

-- Check for optional command-line actions
local actions = arg[1]

if actions ~= nil and type(actions) == "string" then
  -- Reverse the actions string before using (Order pops from the end)
  local reversed = string.reverse(actions)
  
  -- Create an order with the actions (using dummy values for item/count)
  local order = Order:new("", 0, reversed, "output")
  walker = Walker:new(order)
  
  -- Run the walker until completion
  print("Running actions: " .. actions)
  while walker ~= nil do
    if walker:step() then
      walker = nil
    end
  end
  
  print("Actions complete.")
end

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

  local isBlock, info = turtle.inspectDown()
  if isBlock and info then
    local color = Walker.getColor(info.tags)
    if color == "red" then
      if message ~= nil and message.type == "order" then
        local order = message.value
        if order.item ~= nil then
          walker = Walker:new(Order:new(order.item, order.count, order.actions:reverse(), order.type))
          return
        end
      elseif message ~= nil and id ~= nil and message.type == "avail" then
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
