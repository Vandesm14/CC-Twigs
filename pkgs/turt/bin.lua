local pretty = require "cc.pretty"
local Walker = require "turt.walker"
local Order = require "wh.order"
local lib = require "turt.lib"

-- Check for optional command-line actions
local actions = arg[1]

if actions ~= nil and type(actions) == "string" then
  -- Reverse the actions string before using (Order pops from the end)
  local reversed = string.reverse(actions)

  -- Create an order with the actions (using dummy values for item/count)
  local order = Order:with_actions(reversed)
  local walker = Walker:new(order)

  -- Run the walker until completion
  print("Running actions: " .. actions)
  while not walker:step() do
  end

  print("Actions complete.")
end

rednet.open("right")

--- @type Walker|nil
local walker = nil

---comment
---@param id number|nil
---@param message Message
local function handleMessage(id, message)
  print("Received message from " .. id .. ":")

  local isBlock, info = turtle.inspectDown()
  if isBlock and info then
    local color = Walker.getColor(info.tags)
    if color == "red" then
      if message ~= nil and message.type == "order" then
        local order = message.value
        if order ~= nil then
          print("starting order for " .. order.count .. " " .. order.item)
          order = Order:from_order(order)
          order:reverse_actions()
          walker = Walker:new(order)
          return
        end
      elseif message ~= nil and id ~= nil and message.type == "avail" then
        rednet.broadcast(
          {
            type = "status",
            value = {
              name = lib.OUR_NAME,
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
  handleMessage(rednet.receive("wh_" .. lib.OUR_NAME))
end

local MIN_FUEL = 100

while true do
  if walker ~= nil then
    if walker:step() then
      walker = nil
      print("finished order.")
    end
  else
    if turtle.getFuelLevel() < MIN_FUEL then
      print("fueling.")
      while turtle.getFuelLevel() < MIN_FUEL do
        if not turtle.suckUp(1) then
        end
        turtle.refuel()
      end
    end
    print("idle.")
    parallel.waitForAny(waitForGlobal, waitForSelf)
  end
end
