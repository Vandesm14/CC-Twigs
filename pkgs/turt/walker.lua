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

function Walker:pullFromChest()
  local chest = peripheral.wrap("front")

  --- @cast chest Inventory
  if chest ~= nil then
    for slot, item in pairs(chest.list()) do
      if item.name == self.order.item and item.count >= self.order.count then
        turtle.select(1)
        turtle.suck()

        local success, _ = pcall(
          chest.pullItems,
          "front",
          slot,
          self.order.count,
          1
        )

        if not success then
          error("failed to pull items")
        end

        turtle.suck(self.order.count)

        turtle.select(1)
        turtle.drop()

        turtle.select(2)
        turtle.transferTo(1)

        turtle.select(1)
      end
    end
  end

end

function Walker:dropAll()
  local index = 1
  while index <= 16 do
    turtle.drop()
    index = index + 1
  end

  turtle.select(1)
end

function Walker:downUntilBarrel()
  local isBarrel = false
  while not isBarrel do
    turtle.down()

    local isBlock, info = turtle.inspectDown()
    if isBlock and info then
      isBarrel = info.name == "minecraft:barrel"
    end
  end
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
            while ({gps.locate(2, false)})[2] < self.order.pos.y do
              turtle.up()
            end

            if self.order.type == "output" then
              self:pullFromChest()
            elseif self.order.type == "input" then
              self:dropAll()
            end

            self:downUntilBarrel()
            turtle.turnLeft()
          end
        elseif name == "wp-storage-left" then
          if self:isWithinPosition() then
            turtle.turnLeft()
            while ({gps.locate(2, false)})[2] < self.order.pos.y do
              turtle.up()
            end

            if self.order.type == "output" then
              self:pullFromChest()
            elseif self.order.type == "input" then
              self:dropAll()
            end

            self:downUntilBarrel()
            turtle.turnRight()
          end
        elseif name == "wp-input-right" then
          if self.order.type == "input" then
            turtle.turnRight()
            self:pullFromChest()
            turtle.turnLeft()
          end
        elseif name == "wp-input-left" then
          if self.order.type == "input" then
            turtle.turnLeft()
            self:pullFromChest()
            turtle.turnRight()
          end
        elseif name == "wp-output-right" then
          if self.order.type == "output" then
            turtle.turnRight()
            self:dropAll()
            turtle.turnLeft()
          end
        elseif name == "wp-output-left" then
          if self.order.type == "output" then
            turtle.turnLeft()
            self:dropAll()
            turtle.turnRight()
          end
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
