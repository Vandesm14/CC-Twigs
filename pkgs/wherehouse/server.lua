local pretty = require("cc.pretty")
local follownet = require("net.follownet")

local protocol = {}
protocol.pid = 3524

follownet.transmit({ 1 }, { 3524, { 0 }, "list" })

local side, source, packet = follownet.receive()
local pid, path, type_, data = table.unpack(packet)

if
    pid == protocol.pid
    and type(path) == "table"
    and type(type_) == "string"
    and type(data) == "table"
then
  pretty.pretty_print(data)
end
