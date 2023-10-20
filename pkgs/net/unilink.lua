local pretty = require("cc.pretty")

local unilink = {}

--- The unique ID for a Unilink data-frame.
unilink.pid = 1035
--- The unique name for a Unilink data-frame receive event.
unilink.event = "unilink"

--- An address the uniquely identifies a computer and modem.
---
--- @class UnilinkAddr
--- @field id integer The computer ID.
--- @field name computerSide|string The name or side of the modem.
--- @field isWireless boolean Whether the modem is wireless.

--- Transmits a Unilink data-frame.
---
--- @param source UnilinkAddr
--- @param destination UnilinkAddr
--- @param data table
function unilink.transmit(source, destination, data)
  os.queueEvent(
    "modem_message",
    nil,
    unilink.pid,
    unilink.pid,
    { unilink.pid, source, destination, data }
  )
end

--- Receives a Unilink data-frame.
---
--- Pauses execution on the current thread.
---
--- @return "unilink" event
--- @return UnilinkAddr source
--- @return UnilinkAddr destination
--- @return table data
function unilink.receive()
  --- @diagnostic disable-next-line: param-type-mismatch, return-type-mismatch
  return os.pullEvent(unilink.event)
end

--- Handles the next modem event.
---
--- If the modem event is not related to Unilink, then it's dropped.
---
--- Pauses execution on the current thread.
function unilink.handle()
  --- @type event, computerSide|string, integer, integer, unknown
  local _, name, _, _, frame = os.pullEvent("modem_message")

  if type(frame) == "table" and frame[1] == unilink.pid then
    --- @type UnilinkAddr, UnilinkAddr, table
    local source, destination, data = table.unpack(frame, 2)

    if source.id == os.getComputerID() then
      local modem = peripheral.wrap(source.name)
      --- @cast modem Modem|nil

      if
        modem ~= nil
        and peripheral.hasType(modem, "modem")
        and source.isWireless == modem.isWireless()
      then
        local success = pcall(
          modem.transmit,
          unilink.pid,
          unilink.pid,
          { unilink.pid, source, destination, data }
        )

        if success then
          print(
            "SEND",
            pretty.render(pretty.pretty(source)),
            pretty.render(pretty.pretty(destination))
          )
        else
          print(
            "FAIL",
            pretty.render(pretty.pretty(source)),
            pretty.render(pretty.pretty(destination))
          )
        end
      end
    elseif destination.id == os.getComputerID() then
      local modem = peripheral.wrap(destination.name)
      --- @cast modem Modem|nil

      if
        modem ~= nil
        and peripheral.hasType(modem, "modem")
        and destination.name == name
        and destination.isWireless == modem.isWireless()
      then
        os.queueEvent(unilink.event, source, destination, data)
        print(
          "RECV",
          pretty.render(pretty.pretty(source)),
          pretty.render(pretty.pretty(destination))
        )
      else
        print(
          "DROP",
          pretty.render(pretty.pretty(source)),
          pretty.render(pretty.pretty(destination))
        )
      end
    else
      print(
        "DROP",
        pretty.render(pretty.pretty(source)),
        pretty.render(pretty.pretty(destination))
      )
    end
  end
end

return unilink
