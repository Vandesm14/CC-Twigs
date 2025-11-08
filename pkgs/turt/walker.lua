local pretty = require "cc.pretty"
local lib = require "turt.lib"

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

--- Validates the turtle's state after an operation and handles errors
--- @param operation_type string "pull" or "drop"
--- @return boolean true if state is valid, false if invalid (should stop execution)
function Walker:validateState(operation_type)
  local item = turtle.getItemDetail(1)
  local is_valid = true
  local error_msg = nil
  
  if operation_type == "pull" then
    -- After pulling, we should have the expected items
    if item == nil then
      is_valid = false
      error_msg = "Failed to pull items from chest: no items in inventory"
    elseif item.name ~= self.order.item then
      is_valid = false
      error_msg = "Failed to pull items from chest: got " .. item.name .. " instead of " .. self.order.item
    elseif item.count < self.order.count then
      is_valid = false
      error_msg = "Failed to pull items from chest: got " .. item.count .. " but expected " .. self.order.count .. " of " .. self.order.item
    end
  elseif operation_type == "drop" then
    -- After dropping, we should have no items
    if item ~= nil and item.count > 0 then
      is_valid = false
      error_msg = "Failed to drop all items into chest: still have " .. item.count .. "x " .. item.name .. " in inventory"
    end
  end
  
  if not is_valid then
    -- Broadcast the error
    rednet.broadcast(
      {
        type = "error",
        value = {
          name = lib.OUR_NAME,
          error = error_msg,
          order = self.order
        }
      },
      "wh_" .. lib.OUR_NAME .. "_error"
    )
    
    -- Try to move up to signal out of service
    turtle.up()
    
    -- Print the error and stop execution
    error("ASSERTION FAILED: " .. error_msg)
  end
  
  return is_valid
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
      if item.count > self.order.count then
        turtle.dropDown(item.count - self.order.count)
      end

      turtle.transferTo(1)
      turtle.select(1)
      return
    end

    for slot, item in pairs(chest.list()) do
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

    print("Failed to find item '" .. self.order.item .. "' in chest.")
  end
end

--- Runs a step. Returns whether to break out of the loop.
--- @return boolean
function Walker:step()
  if self.action == "x" then
    local isBlock, info = turtle.inspectDown()
    if isBlock and info then
      local color = self.getColor(info.tags)

      if color ~= nil and self.ignore > 0 then
        print("ignore")
        self.ignore = self.ignore - 1
        return false
      end

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
    while not turtle.forward() do
    end
  elseif self.action == "i" then
    self:pullFromChest()
    self:validateState("pull")
  elseif self.action == "o" then
    turtle.dropDown()
    self:validateState("drop")
  elseif self.action == "c" then
    if self.order.type == "input" then
      turtle.dropDown()
      self:validateState("drop")
    elseif self.order.type == "output" then
      self:pullFromChest()
      self:validateState("pull")
    else
      error("invalid order type: " .. self.order.type)
    end
  elseif self.action == "x" then
    while not turtle.forward() do
    end
    -- Then handled by the next call.
  elseif self.action == "h" then
    while not turtle.forward() do
    end
  end

  return false
end

return Walker
