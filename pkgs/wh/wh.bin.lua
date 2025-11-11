local cli = require "wh.cli"

rednet.open("back")

-- Convert arg table to array format
--- @type string[]
local args = {}
for i = 1, #arg do
  args[i] = arg[i]
end

cli.parse(args, "local")
