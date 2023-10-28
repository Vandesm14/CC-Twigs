local broadlink = require("net.broadlink")

local exit = false

for _, modem in ipairs({peripheral.find("modem")}) do
  --- @cast modem Modem
  modem.open(broadlink.pid)
end

local function cleanup()
  os.pullEventRaw("terminate")
  exit = true

  for _, modem in ipairs({peripheral.find("modem")}) do
    --- @cast modem Modem
    modem.close(broadlink.pid)
  end
end

while not exit do
  parallel.waitForAny(cleanup, broadlink.handle)
end
