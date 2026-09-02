local test = require "/pkgs.lib.test"
local cli = require "/pkgs.wh.cli"
local branches = require "/pkgs.wh.branches"

local maxCounts = {
  ["minecraft:cobblestone"] = 64,
  ["minecraft:dirt"] = 64,
}

-- Create every barrel/chest referenced by branches.lua as an emulated chest
for _, name in pairs(branches.input) do
  periphemu.create(name, "chest")
end
for _, name in pairs(branches.storage) do
  periphemu.create(name, "chest")
end
for _, name in pairs(branches.output) do
  periphemu.create(name, "chest")
end

-- Mock getItemDetail to add maxCount, same as pkgs/vault/db.test.lua does,
-- since CraftOS-PC's emulated chests don't report maxCount on their own.
local originalPeripheralWrap = peripheral.wrap
peripheral.wrap = function(name)
  local wrapped = originalPeripheralWrap(name)
  if wrapped ~= nil and wrapped.list ~= nil then
    local originalGetItemDetail = wrapped.getItemDetail
    wrapped.getItemDetail = function(slot_id)
      local detail = originalGetItemDetail(slot_id)
      if detail ~= nil and detail.maxCount == nil then
        detail.maxCount = maxCounts[detail.name] or 64
      end
      return detail
    end
  end
  return wrapped
end

--- Empties every barrel/chest used by wh.
local function clearAllChests()
  for _, group in pairs({ branches.input, branches.storage, branches.output }) do
    for _, name in pairs(group) do
      local chest = peripheral.wrap(name)
      local list = chest.list()
      for slot_id, item in pairs(list) do
        chest.setItem(slot_id, { name = item.name, count = -item.count })
      end
    end
  end
end

--- Resets wh's on-disk state (cache, transaction log, ls output) so each
--- describe block starts from a clean slate.
local function resetWhState()
  for _, file in pairs({ "slots.json", "transactions.csv", "list.txt" }) do
    if fs.exists(file) then
      fs.delete(file)
    end
  end
end

--- @return number
local function countInChest(name, item)
  local chest = peripheral.wrap(name)
  local list = chest.list()
  local total = 0
  for _, slot in pairs(list) do
    if slot.name == item then
      total = total + slot.count
    end
  end
  return total
end

--- Sums an item's count across every chest in a branch group (order of
--- peripheral.getNames() isn't guaranteed to match branches.lua's order,
--- so a single pull/order can land in any storage chest).
--- @return number
local function countInGroup(group, item)
  local total = 0
  for _, name in pairs(group) do
    total = total + countInChest(name, item)
  end
  return total
end

test.describe("wh pull", function()
  clearAllChests()
  resetWhState()

  local input = branches.input[1]

  peripheral.wrap(input).setItem(1, { name = "minecraft:cobblestone", count = 32 })

  test.it("moves items from input into storage", function()
    local success = cli.parse({ "pull" }, "local")
    assert(success, "pull command should succeed")

    assert(countInChest(input, "minecraft:cobblestone") == 0, "input should be emptied")
    assert(countInGroup(branches.storage, "minecraft:cobblestone") == 32, "storage should receive the pulled items")
  end)
end)

test.describe("wh order", function()
  clearAllChests()
  resetWhState()

  local storageChest = branches.storage[1]
  local output = branches.output[1]

  peripheral.wrap(storageChest).setItem(1, { name = "minecraft:cobblestone", count = 64 })

  test.it("scans existing storage into the cache", function()
    local success = cli.parse({ "scan" }, "local")
    assert(success, "scan command should succeed")
  end)

  test.it("moves ordered items from storage into output", function()
    local success = cli.parse({ "order", "5", "cobblestone" }, "local")
    assert(success, "order command should succeed")

    assert(countInChest(output, "minecraft:cobblestone") == 5, "output should receive the ordered items")
    assert(countInChest(storageChest, "minecraft:cobblestone") == 59, "storage should be decremented")
  end)

  test.it("rejects orders larger than what is in stock", function()
    -- cli.parse still returns true here (the command itself ran fine); the
    -- rejection shows up as a failure message in the adapter instead, and
    -- stock must be left untouched.
    local before = countInChest(output, "minecraft:cobblestone")
    local _, adapter = cli.parse({ "order", "1000", "cobblestone" }, "local")

    local rejected = false
    for _, entry in ipairs(adapter) do
      if entry[1] == false and string.find(entry[2], "Not enough", 1, true) ~= nil then
        rejected = true
      end
    end
    assert(rejected, "adapter should report insufficient stock")
    assert(countInChest(output, "minecraft:cobblestone") == before, "output should be unchanged after a rejected order")
  end)
end)

test.describe("wh ls", function()
  clearAllChests()
  resetWhState()

  local storageChest = branches.storage[1]
  peripheral.wrap(storageChest).setItem(1, { name = "minecraft:cobblestone", count = 64 })

  test.it("lists scanned items to list.txt", function()
    cli.parse({ "scan" }, "local")
    local success = cli.parse({ "ls" }, "local")
    assert(success, "ls command should succeed")

    assert(fs.exists("list.txt"), "list.txt should be written")
    local file = fs.open("list.txt", "r")
    local content = file.readAll()
    file.close()

    assert(string.find(content, "cobblestone") ~= nil, "list.txt should mention cobblestone")
  end)
end)

clearAllChests()
resetWhState()
