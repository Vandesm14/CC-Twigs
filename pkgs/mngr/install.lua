--- Creates a URL from its common components.
---
--- This is not specification compliant, but it works for most use-cases.
---
--- @param scheme "http"|"https"
--- @param host string
--- @param port number|nil
--- @param path string
--- @return string|nil url
local function createUrl(scheme, host, port, path)
  if
    host:find("^[%a%d%.%-]+$") == 1
    and (port == nil or (port >= 0 and port <= 65535))
  then
    local portString = ""
    if port ~= nil then
      portString = ":" .. tostring(port)
    end

    return scheme .. "://" .. host .. portString .. "/" .. fs.combine(path)
  end
end

--- Parses a URL into its common components.
---
--- This is not specification compliant, but it works for most use-cases.
---
--- @param url string
--- @return "http"|"https"|nil scheme
--- @return string|nil host
--- @return number|nil port
--- @return string|nil path
local function parseUrl(url)
  --- @type integer|nil, integer|nil, "http"|"https"|nil
  local _, schemeEnd, scheme = url:find("^(https?)://")
  if schemeEnd == nil or scheme == nil then return end
  url = url:sub(schemeEnd + 1)

  --- @type integer|nil, integer|nil, string|nil
  local _, hostEnd, host = url:find("^([%a%d%-%.]+)")
  if hostEnd == nil or host == nil then return end
  url = url:sub(hostEnd + 1)

  --- @type integer|nil, integer|nil, string|nil
  local _, portEnd, port_ = url:find("^:(%d+)")
  local port = tonumber(port_)
  if portEnd ~= nil and port ~= nil then
    url = url:sub(portEnd + 1)
  elseif url:find("^:") == nil then
    return
  end

  --- @type integer|nil, integer|nil, string|nil
  local _, pathEnd, path = url:find("^/?([%a%d%-%.%/]*)$")
  if pathEnd == nil or path == nil then return end
  url = url:sub(pathEnd + 1)

  if url:len() > 0 then return end

  return scheme, host, port, path
end

--- Combines multiple components of a path into a URL path.
---
--- @param url string
--- @param ... string
--- @return string|nil url
local function combineUrl(url, ...)
  local scheme, host, port, path = parseUrl(url)
  if scheme == nil or host == nil or path == nil then return end
  return createUrl(
    scheme,
    host,
    port,
    fs.combine(path, table.unpack(arg))
  )
end

if fs.isDir("/.mngr") then
  fs.delete("/.mngr")
end

if fs.exists("/startup/mngr.lua") then
  fs.delete("/startup/mngr.lua")
end

--- @type string|nil
local url = settings.get("mngr.url")
if url == nil or parseUrl(url) == nil then
  printError(
    "Be sure to set the 'mngr.url' setting to the package server URL. For " ..
    "example, 'set mngr.url http://localhost:3000'."
  )
  return
end

-- These should be the bare-minimum and be kept in sync with the imports that
-- 'mngr.lua' depends on.
if not (
  shell.run("wget", combineUrl(url, "mngr", "mngr.lua"), "/.mngr/mngr/mngr.lua")
  and shell.run("wget", combineUrl(url, "std", "url.lua"), "/.mngr/std/url.lua")
  and shell.run("wget", combineUrl(url, "std", "tfs.lua"), "/.mngr/std/tfs.lua")
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
