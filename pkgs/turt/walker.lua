local pretty = require "cc.pretty"

-- local Order = require "turt.order"

--- @class Walker
--- @field ignore number
--- @field order Order
--- @field was_lime boolean
--- @field action string|nil
local Walker = {}
Walker.__index = Walker

--- comment
--- @param order Order
--- @return Walker
function Walker:new(order)
  local o = {}
  o.ignore = 0
  o.order = order
  o.was_lime = false
  o.action = ""
  return setmetatable(o, self)
end

--- @param tags table<string, boolean>
--- @return string|nil
function Walker.getColor(tags)
  for color, _ in pairs(tags) do
    if color:match("c:dyed/%a+") then
      local c = color:match("c:dyed/(%a+)")
      return c
    end
  end
end

function Walker:pullFromChest()
  local chest = peripheral.wrap("bottom")

  --- @cast chest ccTweaked.peripherals.Inventory
  if chest ~= nil then
    -- Get the item in the first slot of the chest
    turtle.select(2)
    turtle.suckDown()

    local item = turtle.getItemDetail()
    if item ~= nil and item.name == self.order.item and item.count >= self.order.count then
      turtle.transferTo(1)
      turtle.select(1)
      return
    end

    for slot, item in pairs(chest.list()) do
      print(item.name, item.count)
      if item.name == self.order.item and item.count >= self.order.count then
        -- Move the target item to the first slot of the chest
        local success, _ = pcall(
          chest.pullItems,
          "bottom",
          slot,
          self.order.count,
          1
        )

        if not success then
          error("failed to pull items")
        end

        -- Select our first slot
        turtle.select(1)
        -- Suck our intented item from the first slot of the chest
        turtle.suckDown(self.order.count)

        -- Select our second slot
        turtle.select(2)
        -- Drop the junk item back into the chest
        turtle.dropDown()

        -- Select our first slot with our item
        turtle.select(1)

        return
      end
    end

    error("Failed to find item '" .. self.order.item .. "' in chest.")
  end
end

--- Runs a step. Returns whether to break out of the loop.
--- @return boolean
function Walker:step()
  -- turtle.forward()
  if self.action == "x" then
    local isBlock, info = turtle.inspectDown()
    if isBlock and info then
      local color = self.getColor(info.tags)

      if color ~= nil and self.ignore > 0 then
        print("ignore")
        self.ignore = self.ignore - 1
        return false
      end

      print(color)
      if color ~= "lime" then
        self.was_lime = false
      end

      if color == "yellow" then
        print("STOP")
        return true
      elseif color == "orange" then
        -- We hit a checkpoint and can continue
        self.action = nil
      elseif color == "white" then
        turtle.turnRight()
      elseif color == "black" then
        turtle.turnLeft()
      elseif color == "pink" then
        -- Ignore the next action (color only)
        self.ignore = self.ignore + 1
      elseif color == "lime" then
        -- If the last block wasn't lime, turn left.
        if not self.was_lime then
          print("lime-left")
          turtle.turnLeft()
        end
        self.was_lime = true
      end
    end
  else
    self.action = self.order:next_action()
    print(self.action)
    if not self.action then
      return true
    end
  end

  if self.action == "l" then
    turtle.turnLeft()
  elseif self.action == "r" then
    turtle.turnRight()
  elseif self.action == "f" then
    turtle.forward()
  elseif self.action == "i" then
    self:pullFromChest()
  elseif self.action == "o" then
    turtle.dropDown()
  elseif self.action == "c" then
    if self.order.type == "input" then
      turtle.dropDown()
    elseif self.order.type == "output" then
      self:pullFromChest()
    else
      error("invalid order type: " .. self.order.type)
    end
  elseif self.action == "x" then
    turtle.forward()
    -- Then handled by the next call.
  elseif self.action == "h" then
    turtle.forward()
    return true
  end

  return false
end

return Walker
