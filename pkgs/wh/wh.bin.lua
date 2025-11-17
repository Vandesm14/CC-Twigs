local cli = require "/pkgs.wh.cli"

rednet.open("back")

-- Convert arg table to array format
--- @type string[]
local args = {}
for i = 1, #arg do
  args[i] = arg[i]
end

local success, messages = cli.parse(args, "local")
-- Messages are already printed by cli.parse in local mode
