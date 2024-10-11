--- @param tags table<string, boolean>
--- @return string|nil
local function getColor(tags)
  for color, _ in pairs(tags) do
    if color:match("c:dyed/%a+") then
      return color:match("c:dyed/(%a+)")
    end
  end
end

local ignore = 0
while true do
  turtle.forward()

  if ignore > 0 then
    ignore = ignore - 1
    turtle.forward()
  end

  local isBlock, info = turtle.inspectDown()
  if isBlock and info then
    local color = getColor(info.tags)
    if color == "white" then
      turtle.turnRight()
    elseif color == "black" then
      turtle.turnLeft()
    elseif color == "yellow" then
      ignore = ignore + 1
    elseif color == "purple" then
      break
    elseif color == "blue" then
      break
    elseif color == "red" then
      break
    end
  end
end
