local pretty = require("cc.pretty")

--- Broadlink is a data-link layer (OSI layer 2) protocol.
---
--- This is an unreliable protocol. It only supports broadcast transfer of
--- data-frames between hosts directly connected to a modem.
local broadlink = {}

--- The unique ID for a Broadlink data-frame.
broadlink.pid = 1036
--- The unique name for a Broadlink data-frame receive event.
broadlink.event = "broadlink"

--- Transmits a Broadlink data-frame.
---
--- @param source UnilinkAddr
--- @param data table
function broadlink.transmit(source, data)
	os.queueEvent(
		"modem_message",
		nil,
		broadlink.pid,
		broadlink.pid,
		{ broadlink.pid, source, data }
	)
end

--- Receives a Broadlink data-frame.
---
--- Pauses execution on the current thread.
---
--- @return "broadlink" event
--- @return UnilinkAddr source
--- @return UnilinkAddr destination
--- @return table data
function broadlink.receive()
  --- @diagnostic disable-next-line: param-type-mismatch, return-type-mismatch
	return os.pullEvent(broadlink.event)
end

--- Handles the next modem event.
---
--- If the modem event is not related to Broadlink, then it's dropped.
---
--- Pauses execution on the current thread.
function broadlink.handle()
	--- @type event, computerSide|string, integer, integer, unknown
	local _, name, _, _, frame = os.pullEvent("modem_message")
	
	if type(frame) == "table" and frame[1] == broadlink.pid then
    --- @type UnilinkAddr, table
    local source, data = table.unpack(frame, 2)

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
          broadlink.pid,
          broadlink.pid,
          { broadlink.pid, source, data }
        )

        if success then
          print("SEND", pretty.render(pretty.pretty(source)))
        else
          print("FAIL", pretty.render(pretty.pretty(source)))
        end
      end
		else
			local modem = peripheral.wrap(name)
			local destination = {
				id = os.getComputerID(),
				name = name,
				isWireless = modem.isWireless(),
			}

			os.queueEvent(broadlink.event, source, destination, data)
      print(
        "RECV",
        pretty.render(pretty.pretty(source)),
        pretty.render(pretty.pretty(destination))
      )
    end
  end
end

return broadlink
