local order = require "turt.order"

--- @param tags table<string, boolean>
--- @return string|nil
local function getColor(tags)
  for color, _ in pairs(tags) do
    if color:match("c:dyed/%a+") then
      return color:match("c:dyed/(%a+)")
    end
  end
end

--- @class Walker
--- @field ignore number
--- @field yield number
--- @field wait boolean
--- @field order Order
local Walker = {}
Walker.__index = Walker

--- comment
--- @param order Order
--- @return Walker
function Walker:new(order)
  local self = setmetatable({}, Walker)
  self.ignore = 0
  self.yield = 0
  self.wait = false
  self.order = order

  return self
end

function Walker:isWithinPosition()
  local x, _, z = gps.locate(2, false)
  return x == self.order.pos.x and z == self.order.pos.z
end

function Walker:chestMode()
  while ({gps.locate(2, false)})[2] < self.order.pos.y do
    turtle.up()
  end

  local inventory = peripheral.wrap("front")

  --- @cast inventory Inventory
  if inventory ~= nil then
    print("access chest")
  end

  while turtle.down() do end
end

--- Runs a step. Returns whether to break out of the loop.
--- @return boolean
function Walker:step()
  local obstruction = false
  if not self.wait then
    obstruction = not turtle.forward()
  end

  if obstruction then
    return false
  end

  local isBlock, info = turtle.inspectDown()
  if isBlock and info then
    local color = getColor(info.tags)

    if color ~= nil and self.ignore > 0 then
      self.ignore = self.ignore - 1
      return false
    end

    if color == "white" then
      turtle.turnRight()

      if self.yield > 0 then
        self.yield = self.yield - 1

        if turtle.detect() then
          turtle.turnLeft()
        end
      end
    elseif color == "black" then
      turtle.turnLeft()

      if self.yield > 0 then
        self.yield = self.yield - 1

        if turtle.detect() then
          turtle.turnRight()
        end
      end
    elseif color == "yellow" then
      self.ignore = self.ignore + 1
    elseif color == "lime" then
      self.yield = self.yield + 1
    elseif color == "green" then
      self.wait = true
    elseif color == "purple" then
      return true
    end

    if self.wait and color ~= "green" then
      self.wait = false
    end

    local barrel = peripheral.wrap("bottom")
    --- @cast barrel Inventory
    if barrel ~= nil then
      local first = barrel.getItemDetail(1)
      if first ~= nil then
        local name = first.displayName
        if name == "wp-storage-right" then
          if self:isWithinPosition() then
            turtle.turnRight()
            self:chestMode()
            turtle.turnLeft()
          end
        elseif name == "wp-storage-left" then
          if self:isWithinPosition() then
            turtle.turnLeft()
            self:chestMode()
            turtle.turnRight()
          end
        elseif name == "wp-input-right" then
          -- TODO: actually do something
        elseif name == "wp-input-left" then
          -- TODO: actually do something
        elseif name == "wp-output-right" then
          -- TODO: actually do something
        elseif name == "wp-output-left" then
          -- TODO: actually do something
        end
      end
    end
  end

  if not isBlock and self.wait then
    self.wait = false
  end

  return false
end

return Walker
