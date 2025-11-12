--- @type [string, string][]
local members = {}

print("Receipt of Trade")
print("----------------")

while true do
  print("")
  write("Member: ")
  local member = read()
  if member == "" then
    break
  end

  write("Provides: ")
  local provides = read()
  if provides == "" then
    provides = "XXXXX"
  end

  table.insert(members, { member, provides })
end

local fileTimestamp = os.date("%Y%m%d_%H%M", os.epoch("utc") / 1000)
local fileName = fileTimestamp .. ".txt"

local receiptTimestamp = os.date("%Y/%m/%d at %H:%M", os.epoch("utc") / 1000)

local f = fs.open(fileName, "w")
if f ~= nil then
  f.writeLine("Receipt of Trade")
  f.writeLine("----------------")
  for _, member in pairs(members) do
    f.writeLine("")
    f.writeLine("Member: " .. member[1])
    f.writeLine("Provides: " .. member[2])
  end
  f.writeLine("")
  f.writeLine("Date (utc): " .. receiptTimestamp)

  print("")
  print("Date (utc): " .. receiptTimestamp)

  f.close()
end

print("Saved to " .. fileName)
