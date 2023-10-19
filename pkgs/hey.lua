local broadlink = require("net.broadlink")

local _, termHeight = term.getSize()
--- @type ({ from: integer, message: string })[]
local messages = {}
local exit = false

term.clear()

local function displayMessages()
  for i = 1, termHeight - 1 do
    term.setCursorPos(1, (termHeight - 1) - i)
    term.clearLine()
    if #messages - (i - 1) >= 1 then
      local message = messages[#messages - (i - 1)]
      term.write(tostring(message.from) .. ": " .. message.message)
    end
  end
end

while not exit do
  parallel.waitForAny(
    function()
      term.setCursorPos(1, termHeight)
      term.clearLine()
      term.write("Chat: ")
      local message = read()
      term.scroll(-1)

      messages[#messages + 1] = { from = os.getComputerID(), message = message }

      for _, side in ipairs(peripheral.getNames()) do
        if peripheral.getType(side) == "modem" then
          broadlink.transmit(side, { message })
        end
      end

      displayMessages()
    end,
    function()
      local _, source, data = broadlink.receive()
      if type(data[1]) == "string" then
        messages[#messages + 1] = { from = source, message = data[1] }
      end

      displayMessages()
    end
  )
end
