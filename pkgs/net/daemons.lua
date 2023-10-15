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

  -- -- If nothing did anything with the event, requeue it for others
  -- if not consumedEvent then os.queueEvent(table.unpack(event)) end
end

--------------------------------------------------------------------------------

-- local unilink = require("net.unilink")
-- local broadlink = require("net.broadlink")
-- local follownet = require("net.follownet")
-- local searchnet = require("net.searchnet")

-- local exit = false

-- for _, modem in ipairs({ peripheral.find("modem") }) do
--   --- @cast modem Modem
--   modem.open(unilink.channel)
--   modem.open(broadlink.channel)
-- end

-- local function closeChannels()
--   os.pullEventRaw("terminate")
--   exit = true

--   for _, modem in ipairs({ peripheral.find("modem") }) do
--     --- @cast modem Modem
--     modem.close(unilink.channel)
--     modem.close(broadlink.channel)
--   end
-- end

-- --- @type (fun(): boolean)[]
-- local daemons = {
--   closeChannels,
--   unilink.daemon,
--   broadlink.daemon,
--   follownet.daemon,
--   searchnet.daemon.daemon,
-- }

-- while not exit do
--   --- @type (fun(): nil)[]
--   local runners = {}

--   for i, daemon in ipairs(daemons) do
--     runners[i] = function()
--       if daemon() then
--         for j, other in ipairs(daemons) do
--           if daemon == other then
--             daemons[#daemons] = table.remove(daemons, j)
--             break
--           end
--         end
--       end
--     end
--   end

--   parallel.waitForAny(table.unpack(runners))

--   daemons[#daemons] = table.remove(daemons, 1)
-- end
