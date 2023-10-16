local find, amount = arg[1], tonumber(arg[2])

if amount == nil then
  printError("The specified amount is not a number.")
  return
end

--- @diagnostic disable-next-line: param-type-mismatch
local barrel = peripheral.find("minecraft:barrel")
--- @diagnostic disable-next-line: cast-type-mismatch
--- @cast barrel Inventory|nil

if barrel == nil then
  printError("No barrel connected.")
  return
end

--- @diagnostic disable-next-line: param-type-mismatch
local chests = { peripheral.find("minecraft:chest") }
--- @cast chests Inventory[]

local taken = 0

for _, chest in ipairs(chests) do
  if taken >= amount then break end

  local chestName = peripheral.getName(chest)
  print("Checking chest '" .. chestName .. "'...")

  for slot, item in pairs(chest.list()) do
    local left = amount - taken

    if left > 0 and item.name == find then
      local pulled = barrel.pullItems(chestName, slot, left)
      taken = taken + pulled

      if taken >= amount then
        print("  Pulled", pulled, item.name .. ", no more needed.")
        break
      elseif pulled > 0 then
        print("  Pulled", pulled, item.name .. ",", amount - taken, "more left.")
      end
    end
  end
end

if taken == amount then
  print("Order fully completed.")
elseif taken > amount then
  print("Order overly completed.")
elseif taken == 0 then
  printError("Order not completed.")
else
  printError("Order partially completed.")
end
