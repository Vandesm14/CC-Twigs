--------------------------------------------------------------------------------
-- FIXME: This is very specific to the network stack and should be moved.

for _, modem in ipairs({ peripheral.find("modem") }) do
  --- @cast modem Modem
  modem.open(1035) -- unilink channel
  modem.open(1036) -- broadlink channel
end

--------------------------------------------------------------------------------

local scheduler = require("scheduler.daemon")

scheduler.schedules["net.unilink"] = { runner = require("net.unilink").schedule, logs = {} }
scheduler.schedules["net.broadlink"] = { runner = require("net.broadlink").schedule, logs = {} }
scheduler.schedules["net.follownet"] = { runner = require("net.follownet").schedule, logs = {} }
scheduler.schedules["net.searchnet"] = { runner = require("net.searchnet").schedule, logs = {} }

--- @type integer|nil
local logTimerId = nil

scheduler.schedules["scheduler.log"] = {
  runner = function(event, _)
    if logTimerId == nil then
      logTimerId = os.startTimer(0.5)
      return false
    elseif event[1] == "timer" and event[2] == logTimerId then
      for _, schedule in pairs(scheduler.schedules) do
        for _, log in ipairs(schedule.logs) do
          print(log)
        end
      end
      return true
    else
      return false
    end
  end,
  logs = {},
}

scheduler.run()
