local shape = require "turt.shape"

local function findAndSelectSeeds()
  for i = 1, 16, 1 do
    local info = turtle.getItemDetail(i)
    if info ~= nil and info.name == "minecraft:wheat_seeds" then
      turtle.select(i)
      return i
    end
  end

  return nil
end

local function plantSeeds()
  if findAndSelectSeeds() then
    turtle.placeDown()
  else
    error("No seeds found")
  end
end

local x = tonumber(arg[1])
local y = tonumber(arg[2])

shape.area(x, y, function()
  local success, info = turtle.inspectDown()
  if success then
    if info.state.age == 7 then
      turtle.digDown()
      plantSeeds()
    end
  else
    plantSeeds()
  end

  return true
end)
