local runner = require("net.runner")
local wherehouse = require("wherehouse.server")

runner.run({
  wherehouse.daemon
}, { true })
