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
local wait = false
while true do
  if not wait then
    turtle.forward()
  end

  local isBlock, info = turtle.inspectDown()
  if isBlock and info then
    local color = getColor(info.tags)

    if color ~= nil and ignore > 0 then
      ignore = ignore - 1
    else
      if color == "white" then
        turtle.turnRight()
      elseif color == "black" then
        turtle.turnLeft()
      elseif color == "yellow" then
        ignore = ignore + 1
      elseif color == "purple" then
        break
      elseif color == "blue" then
        -- break
      elseif color == "red" then
        -- break
      elseif color == "green" then
        wait = true
      end
    end

    if wait and color ~= "green" then
      wait = false
    end
  end

  if not isBlock and wait then
    wait = false
  end
end
