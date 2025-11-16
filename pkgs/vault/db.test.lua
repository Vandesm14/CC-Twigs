local test = require "/pkgs.lib.test"
local db = require "/pkgs.vault.db"

periphemu.create("back", "modem", 0)
periphemu.create("minecraft:chest_0", "chest")
periphemu.create("minecraft:chest_1", "chest")
periphemu.create("minecraft:chest_2", "chest")

test.describe("scan tests", function()
  test.it("hey", function()
    local database = db.new()

    db.scanSlots(database)

    assert(#database.slots == 0)
    assert(#database.empty == 9 * 3 * 3)
  end)
end)
