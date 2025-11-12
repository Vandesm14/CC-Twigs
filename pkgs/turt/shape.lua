--- Contains functions for moving turtle and acting upon each block in a shape.
local shape = {}

--- @alias shape.Action fun(i: integer): continue: boolean

--- Moves the turtle forward or backward.
---
--- @param z integer How many blocks to move on the relative Z axis.
--- @param action shape.Action
--- @return boolean success
function shape.line(z, action)
  local back = z < 0
  z = math.abs(z)
  local move = back and turtle.back or turtle.forward

  for w = 1, z - 1, 1 do
    if not action(w) then
      return false
    end

    assert(move())
  end

  return action(z)
end

--- Moves the turtle forward or backward and left or right.
---
--- @param x integer How many blocks to move on the relative X axis.
--- @param z integer How many blocks to move on the relative Z axis.
--- @param action shape.Action
--- @return boolean success
function shape.area(x, z, action)
  local left = x < 0
  x = math.abs(x)
  local fb = left and turtle.back or turtle.forward
  local flip = false

  for u = 1, x - 1, 1 do
    if not shape.line(z, action) then
      return false
    end

    if not (
          flip and turtle.turnLeft() and fb() and turtle.turnLeft() or
          not flip and turtle.turnRight() and fb() and turtle.turnRight()
        ) then
      return false
    end

    flip = not flip
  end

  return shape.line(z, action)
end

return shape
