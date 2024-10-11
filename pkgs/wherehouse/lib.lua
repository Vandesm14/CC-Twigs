local lib = {}

--- @param chest Inventory
--- @return string|nil
function lib.getName(chest)

  -- Run through each item in the chest
  for slot, _ in pairs(chest.list()) do
    local nbt = chest.getItemDetail(slot)

    if nbt ~= nil then
      if nbt.name == "computercraft:disk" and nbt.displayName ~= nbt.name then
        return nbt.displayName
      end
    end
  end

  return nil
end

--- @class Position
--- @field x number
--- @field y number
--- @field z number
Position = {}

function Position:new(x, y, z)
  local self = setmetatable({}, Position)
  self.x = x
  self.y = y
  self.z = z
  return self
end

--- @class Chest
--- @field name string
--- @field items itemList
--- @field position Position
--- @field inventory Inventory
Chest = {}

--- Chest ID = `c{x}_{y}_{z}`
--- comment
--- @param str string
--- @return Position|nil
local function parseCoordinates(str)
  if str ~= nil then
    local x, y, z = str:match("c(%d+)_(%d+)_(%d+)")

    if x ~= nil and y ~= nil and z ~= nil then
      return { x = tonumber(x), y = tonumber(y), z = tonumber(z) }
    else
      return nil
    end
  end

  return nil
end

---comment
---@param chest Inventory
---@return Position|nil
function lib.getChestPosition(chest)
  local name = lib.getName(chest)
  if name ~= nil then
    return parseCoordinates(name)
  end

  return nil
end

function lib.scanItems()
  --- @type table<number, Chest>
  local chests = {}

  -- Scan each chest for items, until we hit the end-stop
  --- @diagnostic disable-next-line: param-type-mismatch
  for _, chest in ipairs({ peripheral.find("minecraft:chest") }) do
    --- @cast chest Inventory

    if chest ~= nil then
      local name = lib.getName(chest)
      if name ~= nil then
        table.insert(chests, {
          name = name,
          items = chest.list(),
          position = parseCoordinates(name),
          inventory = chest
        })
      end
    end
  end

  return chests
end

return lib
