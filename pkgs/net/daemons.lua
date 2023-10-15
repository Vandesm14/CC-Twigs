local unilink = require("net.unilink")
local broadlink = require("net.broadlink")
local follownet = require("net.follownet")
local searchnet = require("net.searchnet")

-- local function closeChannels()
--   os.pullEventRaw("terminate")
--   exit = true

--   for _, modem in ipairs({ peripheral.find("modem") }) do
--     --- @cast modem Modem
--     modem.close(unilink.channel)
--     modem.close(broadlink.channel)
--   end
-- end

--- @type (fun(event: unknown, log: boolean): boolean)[]
local daemons = {
  unilink.daemon,
  broadlink.daemon,
  follownet.daemon,
  searchnet.daemon.daemon,
}
--- @type boolean[]
local logs = { false, false, true, true }

for _, modem in ipairs({ peripheral.find("modem") }) do
  --- @cast modem Modem
  -- modem.open(unilink.channel)
  modem.open(broadlink.channel)
end

while true do
  local event = { os.pullEvent() }
  local consumedEvent = false

  for i, daemon in ipairs(daemons) do
    consumedEvent = daemon(event, logs[i])
    if consumedEvent then
      break
    end
  end
end
