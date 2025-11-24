local test = require "/pkgs.lib.test"
local db = require "/pkgs.vault.db"
local tbl = require "/pkgs.lib.table"
local file = require "/pkgs.lib.file"

periphemu.create("back", "modem", 0)
periphemu.create("minecraft:chest_0", "chest")
periphemu.create("minecraft:chest_1", "chest")
periphemu.create("minecraft:chest_2", "chest")

local maxCuonts = {
  ["minecraft:cobblestone"] = 64,
  ["minecraft:dirt"] = 64,
  ["minecraft:stone"] = 64,
}

-- Replace peripheral.wrap to inject mock getItemDetail for inventory peripherals
local originalPeripheralWrap = peripheral.wrap
peripheral.wrap = function(name)
  local wrapped = originalPeripheralWrap(name)
  if wrapped ~= nil and wrapped.list ~= nil then
    -- Store original function
    local originalGetItemDetail = wrapped.getItemDetail
    -- Replace with mock that adds maxCount
    wrapped.getItemDetail = function(slot_id)
      local detail = originalGetItemDetail(slot_id)
      if detail ~= nil and detail.maxCount == nil then
        detail.maxCount = maxCuonts[detail.name] or 64
      end
      return detail
    end
  end
  return wrapped
end

--- Get all inventory names.
--- @return string[]
local function getInventoryNames()
  --- @type string[]
  local inventory_names = {}
  for _, name in pairs(peripheral.getNames()) do
    if peripheral.getType(name) == "inventory" then
      table.insert(inventory_names, name)
    end
  end

  return inventory_names
end

--- Clear all items from a inventory.
--- @param name string The name/ID of the inventory to clear
local function clearInventory(name)
  local inventory = peripheral.wrap(name)
  if inventory == nil then
    error("Peripheral not found: " .. name)
  end

  if inventory.list == nil then
    error("Peripheral is not an inventory: " .. name)
  end

  local list = inventory.list()
  for slot_id, item in pairs(list) do
    inventory.setItem(slot_id, { name = item.name, count = -item.count })
  end
end

--- Clear all inventories.
local function clearAllInventories()
  local names = getInventoryNames()
  for _, name in pairs(names) do
    clearInventory(name)
  end
end

test.describe("scan tests", function()
  test.it("new db", function()
    local database = db.new()

    db.scanInventories(database)

    assert(tbl.len(database.inventories))
  end)
end)

test.describe("clearChest helper", function()
  test.it("clears all items from chest", function()
    clearAllInventories()

    local database = db.new()
    local chest = peripheral.wrap("minecraft:chest_2")
    assert(chest ~= nil, "Chest should exist")

    -- Add items to multiple slots
    chest.setItem(1, { name = "minecraft:cobblestone", count = 32 })
    chest.setItem(2, { name = "minecraft:dirt", count = 16 })
    chest.setItem(5, { name = "minecraft:stone", count = 64 })

    -- Verify items are there
    db.scanInventories(database)
    assert(db.querySlot(database, "minecraft:chest_2", 1) ~= nil)
    assert(db.querySlot(database, "minecraft:chest_2", 2) ~= nil)
    assert(db.querySlot(database, "minecraft:chest_2", 5) ~= nil)

    -- Clear the chest
    clearInventory("minecraft:chest_2")

    -- Verify all slots are empty
    db.scanInventories(database, { "minecraft:chest_2" })
    local chest_slots = database.inventories["minecraft:chest_2"]
    assert(chest_slots ~= nil, "Chest slots should exist")
    for slot_id = 1, chest.size() do
      local slot = chest_slots[slot_id]
      assert(slot.count == 0, "Slot " .. textutils.serializeJSON(slot) .. " should be empty")
    end
  end)

  test.it("clears all items but allows reinserting", function()
    clearAllInventories()

    local database = db.new()
    local chest = peripheral.wrap("minecraft:chest_2")
    assert(chest ~= nil, "Chest should exist")

    db.scanInventories(database)
    assert(db.querySlot(database, "minecraft:chest_2", 1) == nil)
    assert(db.querySlot(database, "minecraft:chest_2", 2) == nil)
    assert(db.querySlot(database, "minecraft:chest_2", 5) == nil)

    chest.setItem(1, { name = "minecraft:cobblestone", count = 32 })
    chest.setItem(2, { name = "minecraft:dirt", count = 16 })
    chest.setItem(5, { name = "minecraft:stone", count = 64 })

    db.scanInventories(database)
    assert(db.querySlot(database, "minecraft:chest_2", 1) ~= nil)
    assert(db.querySlot(database, "minecraft:chest_2", 2) ~= nil)
    assert(db.querySlot(database, "minecraft:chest_2", 5) ~= nil)
  end)
end)

test.describe("transfer tests", function()
  test.it("transfer stack", function()
    local database = db.new()
    local cobblestone = { name = "minecraft:cobblestone", count = 64 }
    peripheral.wrap("minecraft:chest_0").setItem(1, cobblestone)

    db.scanInventories(database)
    assert(tbl.deepEqual(db.querySlot(database, "minecraft:chest_0", 1), cobblestone))
    assert(db.querySlot(database, "minecraft:chest_1", 1) == nil)

    assert(db.transfer(64, "minecraft:chest_0", 1, "minecraft:chest_1", 1))
    db.scanInventories(database)

    assert(tbl.deepEqual(db.querySlot(database, "minecraft:chest_0", 110), nil))
    assert(tbl.deepEqual(db.querySlot(database, "minecraft:chest_1", 1), cobblestone))
  end)
end)

test.describe("find tests", function()
  clearAllInventories()

  local database = db.new()

  local cobblestone = { name = "minecraft:cobblestone", count = 64 }
  peripheral.wrap("minecraft:chest_0").setItem(1, cobblestone)
  peripheral.wrap("minecraft:chest_0").setItem(2, cobblestone)
  peripheral.wrap("minecraft:chest_0").setItem(3, cobblestone)
  peripheral.wrap("minecraft:chest_0").setItem(4, { name = "minecraft:cobblestone", count = 32 })
  peripheral.wrap("minecraft:chest_0").setItem(5, { name = "minecraft:cobblestone", count = 1 })

  db.scanInventories(database)

  test.it("finds stacks of an item", function()
    local res = db.findStacks(database, { "minecraft:chest_0" }, "minecraft:cobblestone", 1)
    assert(tbl.deepEqual(res, { {
      item = "minecraft:cobblestone",
      count = 64,
      chest_id = "minecraft:chest_0",
      slot_id = 1,
    } }), "one stack")

    res = db.findStacks(database, { "minecraft:chest_0" }, "minecraft:cobblestone", 2)
    assert(tbl.deepEqual(res, { {
      item = "minecraft:cobblestone",
      count = 64,
      chest_id = "minecraft:chest_0",
      slot_id = 1,
    }, {
      item = "minecraft:cobblestone",
      count = 64,
      chest_id = "minecraft:chest_0",
      slot_id = 2,
    } }), "two stacks")
  end)

  test.it("finds partial stacks of an item", function()
    local res = db.findPartialStacks(database, { "minecraft:chest_0" }, "minecraft:cobblestone", 1)
    assert(tbl.deepEqual(res, { {
      item = "minecraft:cobblestone",
      count = 32,
      chest_id = "minecraft:chest_0",
      slot_id = 4,
    } }), "one partial stack")

    res = db.findPartialStacks(database, { "minecraft:chest_0" }, "minecraft:cobblestone", 2)
    assert(tbl.deepEqual(res, { {
      item = "minecraft:cobblestone",
      count = 32,
      chest_id = "minecraft:chest_0",
      slot_id = 4,
    }, {
      item = "minecraft:cobblestone",
      count = 1,
      chest_id = "minecraft:chest_0",
      slot_id = 5,
    } }), "two partial stacks")
  end)
end)
