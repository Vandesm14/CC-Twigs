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

--- Validates the turtle's state and handles errors
--- Broadcasts error, moves up to signal out of service, and stops execution if invalid
--- @param should_have_items boolean true if we should have items, false if inventory should be empty
--- @param context string description of the operation for error messages
function Walker:validateState(should_have_items, context)
  local item = turtle.getItemDetail(1)
  local is_valid = true
  local error_msg = nil

  if should_have_items then
    -- Assert we have the correct items in inventory
    if item == nil then
      is_valid = false
      error_msg = context .. ": no items in inventory"
    elseif item.name ~= self.order.item then
      is_valid = false
      error_msg = context .. ": got " .. item.name .. " instead of " .. self.order.item
    elseif item.count < self.order.count then
      is_valid = false
      error_msg = context .. ": got " .. item.count .. " but expected " .. self.order.count .. " of " .. self.order.item
    end
  else
    -- Assert inventory is empty (no loose items)
    if item ~= nil and item.count > 0 then
      is_valid = false
      error_msg = context .. ": inventory should be empty but still have " .. item.count .. "x " .. item.name
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

    turtle.dropDown()
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
    -- Action "i": Pull from chest (used at source for input orders, or at storage for output orders)
    self:pullFromChest()
    -- Assert: Should have the correct items after pulling
    self:validateState(true, "After pulling items (action 'i')")
  elseif self.action == "o" then
    -- Action "o": Drop to chest (used at destination for output orders)
    turtle.dropDown()
    -- Assert: Inventory should be empty after dropping (no loose items)
    self:validateState(false, "After dropping to destination (action 'o')")
  elseif self.action == "c" then
    -- Action "c": Context-dependent chest operation based on order type
    if self.order.type == "input" then
      -- INPUT order: Drop items into storage
      turtle.dropDown()
      -- Assert: Inventory should be empty after dropping (no loose items)
      self:validateState(false, "After dropping to storage (input order, action 'c')")
    elseif self.order.type == "output" then
      -- OUTPUT order: Pull items from storage
      self:pullFromChest()
      -- Assert: Should have the correct items after pulling
      self:validateState(true, "After pulling from storage (output order, action 'c')")
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
