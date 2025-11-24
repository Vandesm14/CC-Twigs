local tbl = require "/pkgs.lib.table"

local db = {}

--- @alias Slot { name: string, nbt: string, count: number }
--- @alias Inventories table<string, Slot[]>
--- @alias Transfer { item: string, count: number, from_chest: string, from_slot: number, to_chest: string, to_slot: number }
--- @alias TransferFragment { item: string, count: number, chest_id: string, slot_id: number }
--- @alias Database { inventories: Inventories, maxCounts: table<string, number>, counts: table<string, number> }

--- Create a new Database instance.
--- @return Database
function db.new()
  return {
    inventories = {},
    empty = {},
    maxCounts = {},
    counts = {},
  }
end

--- Scan current slot data into Database.
--- @param database Database
--- @param filter string[]|nil Filter chest IDs.
function db.scanInventories(database, filter)
  --- @type Inventories
  local inventories = {}
  --- @type table<string, number>
  local counts = {}

  local names = peripheral.getNames()
  for _, name in pairs(names) do
    local chest = peripheral.wrap(name)
    -- If not nil and is an inventory (has `.list`).
    if chest ~= nil and chest.list ~= nil then
      local slots = {}

      -- If no filter or is within our filter.
      if filter == nil or (filter ~= nil and tbl.contains(filter, name)) then
        local list = chest.list()
        for slot_id = 1, chest.size(), 1 do
          local item = list[slot_id]
          if item ~= nil then
            table.insert(slots, {
              name = item.name,
              nbt = item.nbt,
              count = item.count,
            })

            if database.maxCounts[item.name] == nil then
              local detail = chest.getItemDetail(slot_id)
              if detail ~= nil then
                database.maxCounts[item.name] = detail.maxCount
              end
            end
          else
            table.insert(slots, {
              name = "",
              nbt = "",
              count = 0,
            })
          end
        end
      end

      inventories[name] = slots
    end
  end

  tbl.merge(database.inventories, inventories)
  tbl.merge(database.counts, counts)
end

---comment
---@param database Database
---@param chest_id string
---@param slot_id number
---@return Slot|nil
function db.querySlot(database, chest_id, slot_id)
  local slot = database.inventories[chest_id][slot_id]
  if slot and slot.count == 0 then
    return nil
  end

  return slot
end

--- Transfer count from an inventory into another inventory.
--- @param count number count of items to transfer
--- @param from_chest string the name of the inventory to transfer from
--- @param from_slot number the slot of the inventory to transfer from
--- @param to_chest string the name of the inventory to transfer to
--- @param to_slot number the slot of the inventory to transfer to
--- @return boolean success
function db.transfer(count, from_chest, from_slot, to_chest, to_slot)
  local destination = peripheral.wrap(to_chest)
  if destination ~= nil then
    local success, _ = pcall(
      destination.pullItems,
      from_chest,
      from_slot,
      count,
      to_slot
    )

    return success
  end

  return false
end

--- Find stacks of an item in a database.
--- @param database Database
--- @param from_chests string[]
--- @param item string
--- @param count number The number of stacks to find
--- @return TransferFragment[]
function db.findStacks(database, from_chests, item, count)
  --- @type TransferFragment[]
  local fragments = {}

  local maxCount = database.maxCounts[item]
  local counter = count
  for chest_id, slot in pairs(database.inventories) do
    if tbl.contains(from_chests, chest_id) then
      for slot_id, stack in pairs(slot) do
        if counter == 0 then
          break
        end

        if stack.name == item and stack.count == maxCount then
          table.insert(fragments, {
            item = item,
            count = maxCount,
            chest_id = chest_id,
            slot_id = slot_id,
          })

          counter = counter - 1
        end
      end
    end
  end

  return fragments
end

-- ---comment
-- ---@param database Database
-- ---@param item string
-- ---@param count number
-- ---@param from_chests string[]
-- ---@param to_chest string
-- function db.calculateTransfers(database, item, count, from_chests, to_chest)
--   --- @type Transfer[]
--   local transfers = {}

--   local stackRemainder = count % database.maxCounts[item]
--   local isLessThanStack = count < database.maxCounts[item]
--   local requiredStacks = math.floor(count / database.maxCounts[item])

--   if requiredStacks > 0 then
-- end

return db
