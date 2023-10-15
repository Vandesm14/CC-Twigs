local strings = require("cc.strings")

--- Provides package manager APIs.
local mngr = {}

--- The base directory where all packages are stored.
mngr.baseDir = ".mngr"

--- Returns the URL parsed from the 'mngr.addr' setting.
---
--- @return string|nil url
function mngr.getUrlFromSettings()
  --- @type string|nil
  local url = settings.get("mngr.url")
  if url == nil or not http.checkURL(url) then return end
  return url
end

--- Returns the directory for a package.
---
--- @return string packageDir The package directory.
function mngr.getPackageDir(package)
  return fs.combine(mngr.baseDir, package)
end

--- Fetch the list of packages.
---
--- @param baseUrl string
--- @return string[]|nil packages
function mngr.fetchPackages(baseUrl)
  local res = http.get(baseUrl)
  if res == nil then return end

  --- @type string[]
  local names = {}

  local name = res.readLine(false)
  while name ~= nil do
    names[#names + 1] = name
    name = res.readLine(false)
  end

  return names
end

--- Fetch the list of files in a package.
---
--- @param baseUrl string
--- @param package string
--- @return string[]|nil files
function mngr.fetchPackageFiles(baseUrl, package)
  local url = baseUrl .. "/" .. package
  if url == nil then return end

  local res = http.get(url)
  if res == nil then return end

  --- @type string[]
  local names = {}

  local name = res.readLine(false)
  while name ~= nil do
    names[#names + 1] = name
    name = res.readLine(false)
  end

  return names
end

--- Fetch the list of dependency packages for a package file.
---
--- @param baseUrl string
--- @param package string
--- @param file string
--- @return string[]|nil packages
function mngr.fetchPackageFileDependencies(baseUrl, package, file)
  local url = baseUrl .. "/" .. package .. "/" .. file .. "/deps"
  if url == nil then return end

  local res = http.get(url)
  if res == nil then return end

  --- @type string[]
  local names = {}

  local name = res.readLine(false)
  while name ~= nil do
    names[#names + 1] = name
    name = res.readLine(false)
  end

  return names
end

--- Fetch the contents of a package file.
---
--- @param baseUrl string
--- @param package string
--- @param file string
--- @return string|nil content
function mngr.fetchPackageFile(baseUrl, package, file)
  local url = baseUrl .. "/" .. package .. "/" .. file
  if url == nil then return end

  local res = http.get(url)
  if res == nil then return end

  return res.readAll()
end

--- Installs a package and its dependencies recursively.
---
--- @param baseUrl string
--- @param package string
--- @return boolean success
function mngr.installPackage(baseUrl, package)
  local files = mngr.fetchPackageFiles(baseUrl, package)
  if files == nil then return false end

  fs.makeDir(mngr.getPackageDir(package))
  local packageDir = mngr.getPackageDir(package)

  for _, file in ipairs(files) do
    local content = mngr.fetchPackageFile(baseUrl, package, file)
    if content == nil then return false end

    local filePath = fs.combine(packageDir, file)
    local handle = fs.open(filePath, "w")
    if handle == nil then return false end

    handle.write(content)
    handle.flush()

    handle.close()

    local dependencyPackages = mngr.fetchPackageFileDependencies(
      baseUrl,
      package,
      file
    ) or {}

    for _, dependencyPackage in ipairs(dependencyPackages) do
      local dependencyPackageSuccess
      = mngr.installPackage(baseUrl, dependencyPackage)

      if not dependencyPackageSuccess then return false end
      break
    end
  end

  return true
end

if not package.loaded["mngr.mngr"] then
  -- This file was run as an executable.
  -- TODO: All of the stuff that mngr did, but better.
  -- TODO: Provide two modes, remote-to-computer and computer-to-computer.

  -- Update all installed packages.
  local url = mngr.getUrlFromSettings()
  if url == nil then
    printError(
      "Be sure to set the 'mngr.url' setting to the package server URL. For " ..
      "example, 'set mngr.url http://localhost:3000'."
    )
    return
  end

  local packages = mngr.fetchPackages(url)

  if packages == nil then
    printError("Unable to fetch packages from '" .. url .. "'.")
    return
  end

  -- Delete the .mgnr directory.
  fs.delete(mngr.baseDir)

  -- Create the .mngr directory.
  fs.makeDir(mngr.baseDir)

  for _, package in ipairs(packages) do
    local success = mngr.installPackage(url, package)
    if success then
      print("Updated '" .. package .. "' and its dependencies.")
    else
      -- TODO: This also occurs when the package was a dependency of a package
      --       that was previously installed. Filter those out so that this
      --       doesn't happen.
      printError("Unable to update '" .. package .. "' and its dependencies.")
    end
  end
end
