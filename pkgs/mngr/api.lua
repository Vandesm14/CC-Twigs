local api = {
  --- Contains directory related items.
  dir = {},
  --- Contains package related items.
  pkg = {},
  --- Contains HTTP related items.
  http = {},
  --- Contains shell related items.
  shell = {},
}

--- The mngr base directory.
api.dir.base = "/.mngr"

--- Ensures that a directory exists.
---
--- @param path string
function api.dir.ensureExists(path)
  if not fs.exists(path) then
    fs.makeDir(path)
  end
end

--- Returns the mngr.url setting if it is a valid URL.
---
--- @return string|nil
function api.url()
  local url = settings.get("mngr.url")

  if not (type(url) == "string" and http.checkURL(url)) then return end

  if url:sub(-1) == "/" then
    url = url:sub(1, url:len() - 1)
  end

  return url
end

--- Install a package.
---
--- @param baseUrl string
--- @param package string
--- @return boolean
function api.pkg.installPackage(baseUrl, package)
  local files = api.http.getPackageFiles(baseUrl, package)

  if type(files) == "nil" then return false end

  local packageDir = api.dir.base .. "/" .. package

  api.dir.ensureExists(api.dir.base)
  api.dir.ensureExists(packageDir)

  for _, file in ipairs(files) do
    local packageFilePath = packageDir .. "/" .. file
    local content = api.http.getPackageFileContent(baseUrl, package, file)

    if type(content) == "nil" then return false end

    local f = fs.open(packageFilePath, "w")

    if type(f) == "nil" then return false end
    f.write(content)
    f.close()
  end

  return true
end

--- Uninstall a package.
---
--- @param package string
--- @return boolean
function api.pkg.uninstallPackage(package)
  local packageDir = api.dir.base .. "/" .. package

  if not fs.exists(packageDir) then return false end
  fs.delete(packageDir)

  return true
end

--- Returns all of the currently installed packages.
---
--- @return string[]
function api.pkg.installedPackages()
  local dirs = {}

  for _, fileOrDir in ipairs(fs.list(api.dir.base)) do
    if fs.isDir(fs.combine(api.dir.base, fileOrDir)) then
      dirs[#dirs + 1] = fileOrDir
    end
  end

  return dirs
end

--- Get the available packages.
---
--- @param baseUrl string
--- @return string[]|nil
function api.http.getPackages(baseUrl)
  local response = http.get(baseUrl, nil, false)

  if type(response) == "nil" then return end

  --- @type string[]
  local packages = {}

  local line = response.readLine()
  while not (type(line) == "nil") do
    packages[#packages + 1] = line
    line = response.readLine()
  end

  response.close()
  return packages
end

--- Get the files of a package.
---
--- @param baseUrl string
--- @param package string
function api.http.getPackageFiles(baseUrl, package)
  local response = http.get(baseUrl .. "/" .. package, nil, false)

  if type(response) == "nil" then return end

  --- @type string[]
  local files = {}

  local line = response.readLine()
  while not (type(line) == "nil") do
    files[#files + 1] = line
    line = response.readLine()
  end

  response.close()
  return files
end

--- Get the contents of a package file.
---
--- @param baseUrl string
--- @param package string
--- @param file string
function api.http.getPackageFileContent(baseUrl, package, file)
  local response = http.get(baseUrl .. "/" .. package .. "/" .. file, nil, false)

  if type(response) == "nil" then return end

  local content = response.readAll()
  response.close()
  return content
end

--- Setup completions for the current shell.
function api.shell.setupCompletions()
  shell.setCompletionFunction(".mngr/mngr/mngr.lua", function(_, i, curr, prevs)
    --- @cast prevs string[]
    prevs = prevs or {}

    if i == 1 then
      local subcommands = { "in ", "un ", "install ", "uninstall ", "up", "update", "run ", "completions", "startup" }
      --- @type string[]
      local matches = {}

      for _, subcommand in ipairs(subcommands) do
        if
          curr:len() < subcommand:len()
          and curr == subcommand:sub(1, curr:len())
        then
          matches[#matches + 1] = subcommand:sub(curr:len() + 1)
        end
      end

      --- @diagnostic disable-next-line
      return matches
    elseif
      i >= 2
      and (
        prevs[2] == "un"
        or prevs[2] == "uninstall"
        or prevs[2] == "in"
        or prevs[2] == "install"
      )
    then
      local packages = {}

      for _, package in ipairs(api.pkg.installedPackages()) do
        local found = false

        for j, prev in ipairs(prevs) do
          if j >= i and package == prev then
            found = true
            break
          end
        end

        if not found then
          packages[#packages + 1] = package
        end
      end

      --- @type string[]
      local matches = {}

      for _, package in ipairs(packages) do
        if
          curr:len() < package:len()
          and curr == package:sub(1, curr:len())
        then
          matches[#matches + 1] = package:sub(curr:len() + 1)
        end
      end

      --- @diagnostic disable-next-line
      return matches
    elseif i == 2 and prevs[2] == "run" then
      local packages = {}

      for _, package in ipairs(api.pkg.installedPackages()) do
        local found = false

        for j, prev in ipairs(prevs) do
          if j >= i and package == prev then
            found = true
            break
          end
        end

        if not found then
          packages[#packages + 1] = package .. " "
        end
      end

      --- @type string[]
      local matches = {}

      for _, package in ipairs(packages) do
        if
          curr:len() < package:len()
          and curr == package:sub(1, curr:len())
        then
          matches[#matches + 1] = package:sub(curr:len() + 1)
        end
      end

      --- @diagnostic disable-next-line
      return matches
    elseif i == 3 and prevs[2] == "run" then
      local files = {}

      for _, file in ipairs(fs.list(fs.combine(api.dir.base, prevs[3]))) do
        local found = false

        for j, prev in ipairs(prevs) do
          if j >= i and file == prev then
            found = true
            break
          end
        end

        if not found and file:sub(-4) == ".lua" then
          files[#files + 1] = file:sub(1, file:len() - 4)
        end
      end

      --- @type string[]
      local matches = {}

      for _, file in ipairs(files) do
        if
          curr:len() < file:len()
          and curr == file:sub(1, curr:len())
        then
          matches[#matches + 1] = file:sub(curr:len() + 1)
        end
      end

      --- @diagnostic disable-next-line
      return matches
    end
  end)
end

return api
