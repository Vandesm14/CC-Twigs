if fs.isDir("/.mngr") then
  fs.delete("/.mngr")
end

if fs.exists("/startup/mngr.lua") then
  fs.delete("/startup/mngr.lua")
end

--- @type string|nil
local url = settings.get("mngr.url")
if url == nil then
  printError(
    "Be sure to set the 'mngr.url' setting to the package server URL. For " ..
    "example, 'set mngr.url http://localhost:3000'."
  )
  return
end

-- These should be the bare-minimum and be kept in sync with the imports that
-- 'mngr.lua' depends on.
if not (
      shell.run("wget", url .. "/mngr/mngr.lua", "/.mngr/mngr/mngr.lua")
      and shell.run("wget", url .. "/std/url.lua", "/.mngr/std/url.lua")
      and shell.run("wget", url .. "/std/tfs.lua", "/.mngr/std/tfs.lua")
    ) then
  printError("Unable to wget all dependencies.")

  if fs.isDir("/.mngr") then
    fs.delete("/.mngr")
  end

  return
end

shell.setPath(shell.path() .. ":/.mngr/mngr")

local startup = fs.open("/startup/mngr.lua", "w")
if startup ~= nil then
  startup.writeLine("shell.setPath(shell.path() .. \":/.mngr/mngr\")")

  startup.flush()
  startup.close()
end
