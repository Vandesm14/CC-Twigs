local shape = require "/pkgs.turt.shape"

local function findAndSelectBamboo()
  for i = 1, 16, 1 do
    local info = turtle.getItemDetail(i)
    if info ~= nil and info.name == "minecraft:bamboo" then
      turtle.select(i)
      return i
    end
  end

  return nil
end

local function plantBamboo()
  if findAndSelectBamboo() then
    turtle.placeDown()
  else
    print("No bamboo found")
  end
end

local x = tonumber(arg[1])
local y = tonumber(arg[2])

shape.area(x, y, function()
  local success, info = turtle.inspect()
  if success and info.name == "minecraft:bamboo" then
    turtle.dig()
    turtle.suckUp()
    turtle.suck()
    turtle.suckDown()
  end

  local success, _ = turtle.inspectDown()
  if not success then
    plantBamboo()
  end

  return true
end)
