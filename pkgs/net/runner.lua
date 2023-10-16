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
local defaultDaemons = {
  unilink.daemon,
  broadlink.daemon,
  follownet.daemon,
  searchnet.daemon.daemon,
}
--- @type boolean[]
local defaultLogs = { false, false, true, false }

local runner = {}

function runner.run(daemons, logs)
  print("Opening channels...")
  for _, modem in ipairs({ peripheral.find("modem") }) do
    --- @cast modem Modem
    modem.open(unilink.channel)
    modem.open(broadlink.channel)
  end

  -- Append daemons to defaultDaemons
  for _, daemon in ipairs(daemons) do
    defaultDaemons[#defaultDaemons + 1] = daemon
  end

  -- Append logs to defaultLogs
  for _, log in ipairs(logs) do
    defaultLogs[#defaultLogs + 1] = log
  end

  print("Starting daemons...")
  while true do
    local event = { os.pullEvent() }
    local consumedEvent = false

    for i, daemon in ipairs(defaultDaemons) do
      consumedEvent = daemon(event, defaultLogs[i])
      if consumedEvent then
        break
      end
    end
  end
end

return runner
