local unilink = require("net.unilink")

local exit = false

for _, modem in ipairs({peripheral.find("modem")}) do
  --- @cast modem Modem
  modem.open(unilink.pid)
end

local function cleanup()
  os.pullEventRaw("terminate")
  exit = true

  for _, modem in ipairs({peripheral.find("modem")}) do
    --- @cast modem Modem
    modem.close(unilink.pid)
  end
end

while not exit do
  parallel.waitForAny(cleanup, unilink.handle)
end
