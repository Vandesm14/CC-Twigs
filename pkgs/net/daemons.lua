local unilink = require("net.unilink")
local broadlink = require("net.broadlink")

local exit = false

for _, modem in ipairs({peripheral.find("modem")}) do
  --- @cast modem Modem
  modem.open(unilink.channel)
  modem.open(broadlink.channel)
end

local function closeChannels()
  os.pullEventRaw("terminate")
  exit = true

  for _, modem in ipairs({peripheral.find("modem")}) do
    --- @cast modem Modem
    modem.close(unilink.channel)
    modem.close(broadlink.channel)
  end

  os.queueEvent("terminate")
end

--- @type (fun(): boolean)[]
local daemons = {closeChannels, unilink.daemon, broadlink.daemon}

while not exit do
  --- @type (fun(): nil)[]
  local runners = {}

  for i, daemon in ipairs(daemons) do
    runners[i] = function()
      if daemon() then
        for j, other in ipairs(daemons) do
          if daemon == other then
            daemons[#daemons] = table.remove(daemons, j)
            break
          end
        end
      end
    end
  end

  parallel.waitForAny(table.unpack(runners))
end
