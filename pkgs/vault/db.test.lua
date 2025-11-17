local test = require "/pkgs.lib.test"
local db = require "/pkgs.vault.db"
local file = require "/pkgs.lib.file"
local tbl = require "/pkgs.lib.table"

periphemu.create("back", "modem", 0)
periphemu.create("minecraft:chest_0", "chest")
periphemu.create("minecraft:chest_1", "chest")
periphemu.create("minecraft:chest_2", "chest")

test.describe("scan tests", function()
  test.it("new db", function()
    local database = db.new()

    db.scanSlots(database)

    assert(tbl.len(database.slots))
  end)
end)

test.describe("transfer tests", function()
  test.it("transfer stack", function()
    local database = db.new()
    local cobblestone = { name = "minecraft:cobblestone", count = 64 }
    peripheral.wrap("minecraft:chest_0").setItem(1, cobblestone)

    db.scanSlots(database)
    assert(tbl.deepEqual(db.querySlot(database, "minecraft:chest_0", 1), cobblestone))
    assert(db.querySlot(database, "minecraft:chest_1", 1) == nil)

    assert(db.transfer(64, "minecraft:chest_0", 1, "minecraft:chest_1", 1))
    db.scanSlots(database)

    assert(tbl.deepEqual(db.querySlot(database, "minecraft:chest_0", 110), nil))
    assert(tbl.deepEqual(db.querySlot(database, "minecraft:chest_1", 1), cobblestone))
  end)
end)
