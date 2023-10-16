local subcommand = arg[1]

if subcommand == "start" then
  local module = arg[2]

  os.queueEvent("scheduler_add", module)
  --- @diagnostic disable-next-line: param-type-mismatch
  local _, success = os.pullEvent("scheduler_add_result")

  if success == true then
    print("Added schedule for '" .. module .. "'.")
  else
    printError("Unable to add schedule for '" .. module .. "'.")
    return
  end
elseif subcommand == "stop" then
  local module = arg[2]

  os.queueEvent("scheduler_remove", module)
  --- @diagnostic disable-next-line: param-type-mismatch
  local _, success = os.pullEvent("scheduler_remove_result")

  if success == true then
    print("Removed schedule for '" .. module .. "'.")
  else
    printError("Unable to remove schedule for '" .. module .. "'.")
    return
  end
elseif subcommand == "logs" then
  local module = arg[2]

  os.queueEvent("scheduler_logs", module)
  --- @diagnostic disable-next-line: param-type-mismatch
  local _, logs = os.pullEvent("scheduler_logs_result")

  if type(logs) == "table" then
    for _, log in ipairs(logs) do
      print(log)
    end
  else
    printError("Unable to schedule logs for '" .. module .. "'.")
    return
  end
else
  print("Usage:", arg[0], "<subcommand>")
  print()
  print("Subcommands:")
  print("  start <module>")
  print("   stop <module>")
  print("   logs <module> [limit]")
end
