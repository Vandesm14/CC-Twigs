local scheduler = require("scheduler.daemon")

scheduler.schedules[#scheduler.schedules + 1] = { runner = require("net.unilink").schedule, logs = {} }
scheduler.schedules[#scheduler.schedules + 1] = { runner = require("net.broadlink").schedule, logs = {} }
scheduler.schedules[#scheduler.schedules + 1] = { runner = require("net.follownet").schedule, logs = {} }
scheduler.schedules[#scheduler.schedules + 1] = { runner = require("net.searchnet").schedule, logs = {} }
scheduler.schedules[#scheduler.schedules + 1] = { runner = require("wherehouse.server").schedule, logs = {} }

scheduler.run()
