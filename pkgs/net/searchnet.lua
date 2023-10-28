local pretty = require("cc.pretty")
local broadlink = require("net.broadlink")
local follownet = require("net.follownet")

local searchnet = {}

searchnet.id = 2480
searchnet.event = "searchnet"

--- @param destinationId integer
--- @return UnilinkAddr[] route
function searchnet.find(destinationId)
	for _, modem in ipairs({peripheral.find("modem")}) do
		--- @cast modem Modem
		local source = {
			id = os.getComputerID(),
			name = peripheral.getName(modem),
			isWireless = modem.isWireless(),
		}

		broadlink.transmit(source, {
			searchnet.id,
			destinationId,
			{},
		})
	end

	-- TODO: Add some kind of timeout. Should this be left up-to the caller?

	local _, route, packet = follownet.receive()
	while packet[1] ~= searchnet.id do
		_, route, packet = follownet.receive()
	end

	return route
end

function searchnet.handle()
	local _, source, destination, packet = broadlink.receive()

	if packet[1] == searchnet.id then
		--- @type integer, UnilinkAddr[]
		local destinationId, route = table.unpack(packet, 2)

		for _, seenAddr in ipairs(route) do
			if
				seenAddr.id == destination.id
				and seenAddr.name == destination.name
				and seenAddr.isWireless == destination.isWireless
			then
				print(
					"DROP",
					destinationId,
					pretty.render(pretty.pretty(route))
				)
				return
			end
		end

		route[#route + 1] = source
		route[#route + 1] = destination

		if destinationId == os.getComputerID() then
			for i = 0, #route / 2 do
				local temp = route[i]
				route[i] = route[(#route + 1) - i]
				route[(#route + 1) - i] = temp
			end

			follownet.transmit(route, { searchnet.id })
			print(
				"RECV",
				destinationId,
				pretty.render(pretty.pretty(route))
			)
		else
			for _, modem in ipairs({peripheral.find("modem")}) do
				--- @cast modem Modem
				local modemSource = {
					id = os.getComputerID(),
					name = peripheral.getName(modem),
					isWireless = modem.isWireless(),
				}

				if
					modemSource.name ~= destination.name
					or modemSource.isWireless ~= destination.isWireless
				then
					broadlink.transmit(modemSource, {
						searchnet.id,
						destinationId,
						route,
					})
					print(
						"SEND",
						destinationId,
						pretty.render(pretty.pretty(route))
					)
				end
			end
		end
	end
end

return searchnet
