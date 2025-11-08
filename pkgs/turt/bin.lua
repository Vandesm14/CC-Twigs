-- local pretty = require "cc.pretty"
-- local Walker = require "turt.walker"

-- rednet.open("right")

-- --- @type Walker|nil
-- local walker = nil

-- ---comment
-- ---@param id number|nil
-- ---@param message Message
-- local function handleMessage(id, message)
--   print("Received message from " .. id .. ":")
--   pretty.pretty_print(message)

--   if message ~= nil and message.type == "order" then
--     local order = message.value
--     if order.item ~= nil then
--       walker = Walker:new(order)
--       return
--     end
--   elseif message ~= nil and id ~= nil and message.type == "avail" then
--     local isBlock, info = turtle.inspectDown()
--     if isBlock and info then
--       local color = Walker.getColor(info.tags)
--       if color == "purple" then
--         rednet.broadcast(
--           {
--             type = "status",
--             value = {
--               name = os.getComputerLabel(),
--               fuel = turtle.getFuelLevel()
--             }
--           },
--           "wh"
--         )
--       end
--     end
--   end
-- end

-- local function waitForGlobal()
--   handleMessage(rednet.receive("wh"))
-- end

-- local function waitForSelf()
--   handleMessage(rednet.receive("wh_" .. os.getComputerLabel()))
-- end

-- while true do
--   if walker ~= nil then
--     if walker:step() then
--       walker = nil
--     end
--   else
--     parallel.waitForAny(waitForGlobal, waitForSelf)
--   end
-- end

local Walker = require "turt.walker"
local Order = require "turt.order"
local branches = require "wh.branches"

local walker = Walker:new(Order:new("minecraft:cobblestone", 1,
  branches.input["_"] .. branches.storage[1] .. branches.output[2], "input"))
while true do
  if walker:step() then
    break
  end
end
