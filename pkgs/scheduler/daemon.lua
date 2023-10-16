--------------------------------------------------------------------------------
-- FIXME: This is very specific to the network stack and should be moved.

for _, modem in ipairs({ peripheral.find("modem") }) do
  --- @cast modem Modem
  modem.open(1035) -- unilink channel
  modem.open(1036) -- broadlink channel
end

--------------------------------------------------------------------------------

local scheduler = {}

--- @type table<string, { runner: (fun(event: table, logs: string[]): boolean), logs: string[] }>
scheduler.schedules = {}

--- @param event table
--- @param logs string[]
--- @return boolean
local function addSchedule(event, logs)
  local eventName, module = table.unpack(event)

  if eventName == "scheduler_add" then
    if
        type(module) == "string"
        and package.searchpath(module, package.path) ~= nil
    then
      local loaded = require(module)

      if type(loaded) == "table" and type(loaded.schedule) == "function" then
        scheduler.schedules[module] = { runner = loaded.schedule, logs = {} }
        logs[#logs + 1] = "Scheduler: Added schedule for '" .. module .. "'."
        os.queueEvent("scheduler_add_result", true)
        return true
      else
        os.queueEvent("scheduler_add_result", false)
        logs[#logs + 1] = "Scheduler: Unable to add schedule for '" .. module .. "'."
        return true
      end
    else
      os.queueEvent("scheduler_add_result", false)
      logs[#logs + 1] = "Scheduler: Unable to add schedule for '" .. module .. "'."
      return true
    end
  else
    return false
  end
end

--- @param event table
--- @param logs string[]
--- @return boolean
local function removeSchedule(event, logs)
  local eventName, module = table.unpack(event)

  if eventName == "scheduler_remove" then
    if type(module) == "string" and type(scheduler.schedules[module]) == "table" then
      scheduler.schedules[module] = nil
      os.queueEvent("scheduler_remove_result", true)
      logs[#logs + 1] = "Scheduler: Removed schedule for '" .. module .. "'."
      return true
    else
      os.queueEvent("scheduler_remove_result", false)
      logs[#logs + 1] = "Scheduler: Unable to remove schedule for '" .. module .. "'."
      return true
    end
  else
    return false
  end
end

local function logsSchedule(event, logs)
  local eventName, module = table.unpack(event)

  if eventName == "scheduler_logs" then
    if type(module) == "string" and type(scheduler.schedules[module]) == "table" then
      os.queueEvent("scheduler_logs_result", scheduler.schedules[module].logs)
      logs[#logs + 1] = "Scheduler: Got schedule logs for '" .. module .. "'."
      return true
    else
      os.queueEvent("scheduler_logs_result", nil)
      logs[#logs + 1] = "Scheduler: Unable to get schedule logs for '" .. module .. "'."
      return true
    end
  else
    return false
  end
end

function scheduler.run()
  while true do
    local event = table.pack(os.pullEvent())
    local consumedEvent = false

    for _, schedule in pairs(scheduler.schedules) do
      consumedEvent = schedule.runner(event, schedule.logs)

      while #schedule.logs > 10 do
        table.remove(schedule.logs, #schedule)
      end

      if consumedEvent then break end
    end
  end
end

if not package.loaded["scheduler.daemon"] then
  scheduler.schedules["scheduler.add"] = { runner = addSchedule, logs = {} }
  scheduler.schedules["scheduler.remove"] = { runner = removeSchedule, logs = {} }
  scheduler.schedules["scheduler.logs"] = { runner = logsSchedule, logs = {} }

  scheduler.run()
else
  return scheduler
end
