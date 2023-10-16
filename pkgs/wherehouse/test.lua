local pretty = require("cc.pretty")
local follownet = require("net.follownet")

local protocol = {}
protocol.pid = 3524

follownet.transmit({ 3, 4 }, { 3524, { 3, os.getComputerID() }, "order", { ["minecraft:cobblestone"] = 5 } })

local _, _, packet = follownet.receive()
local pid, path, type_, data = table.unpack(packet)

if
    pid == protocol.pid
    and type(path) == "table"
    and type(type_) == "string"
    and type(data) == "table"
then
  if type_ == "list" then
    pretty.pretty_print(data)
  elseif type_ == "order" then
    pretty.pretty_print(data)
  end
end
