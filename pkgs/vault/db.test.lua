local test = require "/pkgs.lib.test"
local db = require "/pkgs.vault.db"
local tbl = require "/pkgs.lib.table"
local file = require "/pkgs.lib.file"

periphemu.create("back", "modem", 0)
periphemu.create("minecraft:chest_0", "chest")
periphemu.create("minecraft:chest_1", "chest")
periphemu.create("minecraft:chest_2", "chest")

--- Clear all items from a chest.
--- @param chest_name string The name/ID of the chest to clear
local function clearChest(chest_name)
  local chest = peripheral.wrap(chest_name)
  if chest == nil then
    error("Chest not found: " .. chest_name)
  end

  local list = chest.list()
  for slot_id, item in pairs(list) do
    chest.setItem(slot_id, { name = item.name, count = -item.count })
  end
end

--- Clear all chests.
local function clearAllChests()
  local names = peripheral.getNames()
  for _, name in pairs(names) do
    clearChest(name)
  end
end

test.describe("scan tests", function()
  test.it("new db", function()
    local database = db.new()

    db.scanInventories(database)

    assert(tbl.len(database.inventories))
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

test.describe("clearChest helper", function()
  test.it("clears all items from chest", function()
    clearAllChests()

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
    clearChest("minecraft:chest_2")

    -- Verify all slots are empty
    db.scanInventories(database, { "minecraft:chest_2" })
    local chest_slots = database.inventories["minecraft:chest_2"]
    assert(chest_slots ~= nil, "Chest slots should exist")
    for slot_id = 1, chest.size() do
      local slot = chest_slots[slot_id]
      assert(slot.count == 0, "Slot " .. textutils.serializeJSON(slot) .. " should be empty")
    end
  end)
end)
