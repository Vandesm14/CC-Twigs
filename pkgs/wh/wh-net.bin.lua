local cli = require "wh.cli"

-- Convert arg table to array format
--- @type string[]
local args = {}
for i = 1, #arg do
  args[i] = arg[i]
end

if #args == 0 then
  printError("Usage: wh-net <command> [arguments...]")
  return
end

-- Broadcast the command via cli.parse with remote mode
-- cli.parse will handle opening all modems
cli.parse(args, "remote")
