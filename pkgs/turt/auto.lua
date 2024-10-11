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
local yield = 0

local wait = false
local isObstruction = false

while true do
  if not wait then
    isObstruction = not turtle.forward()
  end

  if isObstruction then
    goto continue
  end

  local isBlock, info = turtle.inspectDown()
  if isBlock and info then
    local color = getColor(info.tags)

    if color ~= nil and ignore > 0 then
      ignore = ignore - 1
      goto continue
    end

    if color == "white" then
      turtle.turnRight()

      if yield > 0 then
        yield = yield - 1

        if turtle.detect() then
          turtle.turnLeft()
        end
      end
    elseif color == "black" then
      turtle.turnLeft()

      if yield > 0 then
        yield = yield - 1

        if turtle.detect() then
          turtle.turnRight()
        end
      end
    elseif color == "yellow" then
      ignore = ignore + 1
    elseif color == "lime" then
      yield = yield + 1
    elseif color == "green" then
      wait = true
    elseif color == "purple" then
      break
    end

    if wait and color ~= "green" then
      wait = false
    end

    local barrel = peripheral.wrap("bottom")
    --- @cast barrel Inventory
    if barrel ~= nil then
      local first = barrel.getItemDetail(1)
      if first ~= nil then
        local name = first.displayName
        if name == "wp-storage-right" then
          -- TODO: actually do something
        elseif name == "wp-storage-left" then
          -- TODO: actually do something
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

  if not isBlock and wait then
    wait = false
  end

  ::continue::
end
