local strings = require("cc.strings")
local urlib = require("std.url")
local tfs = require("std.tfs")

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
  if url == nil or not urlib.parse(url) then return end
  return url
end

--- Returns the currently installed packages.
---
--- @return string[] installedPackages The package names.
function mngr.getInstalledPackages()
  --- @type string[]
  local names = {}

  for _, fileOrDir in ipairs(fs.list(mngr.baseDir)) do
    if fs.isDir(mngr.getPackageDir(fileOrDir)) then
      names[#names + 1] = fileOrDir
    end
  end

  return names
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
  local url = urlib.combine(baseUrl, package)
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
  local url = urlib.combine(baseUrl, package, file, "deps")
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
  local url = urlib.combine(baseUrl, package, file)
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
--- @return (fun(): nil)[] reverts
function mngr.installPackage(baseUrl, package)
  local reverts = {}

  local files = mngr.fetchPackageFiles(baseUrl, package)
  if files == nil then return false, reverts end

  local packageDir, packageDirRevert = tfs.createDir(mngr.getPackageDir(package))
  if packageDir == nil then return false, reverts end
  reverts[#reverts + 1] = packageDirRevert

  for _, file in ipairs(files) do
    local content = mngr.fetchPackageFile(baseUrl, package, file)
    if content == nil then return false, reverts end

    local filePath = fs.combine(packageDir, file)
    local handle = fs.open(filePath, "w")
    if handle == nil then return false, reverts end

    handle.write(content)
    handle.flush()

    handle.close()

    local dependencyPackages = mngr.fetchPackageFileDependencies(
      baseUrl,
      package,
      file
    ) or {}

    for _, dependencyPackage in ipairs(dependencyPackages) do
      local found = false
      for _, installedPackage in ipairs(mngr.getInstalledPackages()) do
        if installedPackage == dependencyPackage then
          found = true
          break
        end
      end

      if not found then
        local dependencyPackageSuccess, dependencyPackagesReverts
          = mngr.installPackage(baseUrl, dependencyPackage)

        for i = 1, #dependencyPackagesReverts do
          reverts[#reverts + 1] = dependencyPackagesReverts[i]
        end

        if not dependencyPackageSuccess then return false, reverts end
        break
      end
    end
  end

  return true, reverts
end

--- Uninstall a package.
---
--- @param package string
--- @return boolean success
function mngr.uninstallPackage(package)
  local packageDir = mngr.getPackageDir(package)

  if fs.exists(packageDir) then
    fs.delete(packageDir)
    return true
  end

  return false
end

if not package.loaded["mngr.mngr"] then
  -- This file was run as an executable.
  -- TODO: All of the stuff that mngr did, but better.
  -- TODO: Provide two modes, remote-to-computer and computer-to-computer.

  local subcommand = arg[1]

  if subcommand == "in" or subcommand == "install" then
    -- Install a package.
    local usage = "Usage: " .. arg[0] .. " in <...package>"
    local packages = {table.unpack(arg, 2)}

    if #packages == 0 then
      print(usage)
      return
    end

    local url = mngr.getUrlFromSettings()
    if url == nil then
      printError(
        "Be sure to set the 'mngr.url' setting to the package server URL. For " ..
        "example, 'set mngr.url http://localhost:3000'."
      )
      return
    end

    for _, package in ipairs(packages) do
      for _, installedPackage in ipairs(mngr.getInstalledPackages()) do
        if package == installedPackage then
          -- TODO: Use tfs.copyFile on the file and move it into a temp
          --       sub-directory in the package directory. Then delete the files and
          --       try to install them. If that fails, then we can revert the files
          --       in the temp sub-directory back into the package directory.
          mngr.uninstallPackage(package)
        end
      end
    end

    for _, package in ipairs(packages) do
      local success, reverts = mngr.installPackage(url, package)
      if success then
        print("Installed '" .. package .. "' and its dependencies.")
      else
        printError("Unable to install '" .. package .. "' and its dependencies.")

        for i = 0, #reverts - 1 do
          reverts[#reverts - i]()
        end
      end
    end
  elseif subcommand == "un" or subcommand == "uninstall" then
    -- Uninstall a package.
    local usage = "Usage: " .. arg[0] .. " un <...package>"
    local packages = {table.unpack(arg, 2)}

    if #packages == 0 then
      print(usage)
      return
    end

    for _, package in ipairs(mngr.getInstalledPackages()) do
      if mngr.uninstallPackage(package) then
        print("Uninstalled '" .. package .. "'.")
      else
        printError("Unable to uninstall '" .. package .. "'.")
      end
    end
  elseif subcommand == "up" or subcommand == "update" then
    -- Update all installed packages.
    local url = mngr.getUrlFromSettings()
    if url == nil then
      printError(
        "Be sure to set the 'mngr.url' setting to the package server URL. For " ..
        "example, 'set mngr.url http://localhost:3000'."
      )
      return
    end

    local packages = mngr.getInstalledPackages()

    for _, package in ipairs(packages) do
      -- TODO: Use tfs.copyFile on the file and move it into a temp
      --       sub-directory in the package directory. Then delete the files and
      --       try to install them. If that fails, then we can revert the files
      --       in the temp sub-directory back into the package directory.
      mngr.uninstallPackage(package)
    end

    for _, package in ipairs(packages) do
      local success, reverts = mngr.installPackage(url, package)
      if success then
        print("Updated '" .. package .. "' and its dependencies.")
      else
        -- TODO: This also occurs when the package was a dependency of a package
        --       that was previously installed. Filter those out so that this
        --       doesn't happen.
        printError("Unable to update '" .. package .. "' and its dependencies.")

        for i = 0, #reverts - 1 do
          reverts[#reverts - i]()
        end
      end
    end
  elseif subcommand == "ls" or subcommand == "list" then
    -- List all currently installed packages.
    local _, cursorY = term.getCursorPos()

    local list = table.concat(mngr.getInstalledPackages(), ", ")
    local lines = strings.wrap(list)

    for i, line in ipairs(lines) do
      term.write(line)
      term.setCursorPos(1, cursorY + i)
    end
  elseif subcommand == "rn" or subcommand == "run" then
    --- @type string|nil, string|nil
    local package, file = arg[2], arg[3]

    local found = false
    for _, installedPackage in ipairs(mngr.getInstalledPackages()) do
      if installedPackage == package then
        local packageDir = mngr.getPackageDir(installedPackage)

        for _, installledPackageFile in ipairs(fs.list(packageDir)) do
          if installledPackageFile == file .. ".lua" then
            found = true
            break
          end
        end
        break
      end
    end

    if not found then
      printError("Unknown package.file '" .. package .. "." .. file .. "'.")
      return
    end

    local filePath = fs.combine(mngr.getPackageDir(package), file .. ".lua")

    print(">", filePath, table.unpack(arg, 4))
    shell.run(filePath, table.unpack(arg, 4))
  elseif subcommand == "rrn" or subcommand == "rrun" then
  --- @type string|nil, string|nil
  local package, file = arg[2], arg[3]

    shell.run("mngr", "up")
    shell.run("mngr", "run", package, file, table.unpack(arg, 4))
  else
    -- Show usage.
    print("Usage: ".. arg[0] .. " <subcommand>")
    print()
    print("Subcommands:")
    print("  in,   install <...package>")
    print("  un, uninstall <...package>")
    print("  up,    update")
    print("  ls,      list")
    print("  rn,       run <package> <file>")
    print("  rrn,     rrun <package> <file>")
  end
else
  -- This file was loaded as a library.
  return mngr
end

-- TODO: Make this work with the new mngr code.
-- --- Setup completions for the current shell.
-- function api.shell.setupCompletions()
--   shell.setCompletionFunction(".mngr/mngr/mngr.lua", function(_, i, curr, prevs)
--     --- @cast prevs string[]
--     prevs = prevs or {}

--     if i == 1 then
--       local subcommands = { "in ", "un ", "install ", "uninstall ", "up", "update", "list", "run ", "completions", "startup" }
--       --- @type string[]
--       local matches = {}

--       for _, subcommand in ipairs(subcommands) do
--         if
--           curr:len() < subcommand:len()
--           and curr == subcommand:sub(1, curr:len())
--         then
--           matches[#matches + 1] = subcommand:sub(curr:len() + 1)
--         end
--       end

--       --- @diagnostic disable-next-line
--       return matches
--     elseif
--       i >= 2
--       and (
--         prevs[2] == "un"
--         or prevs[2] == "uninstall"
--         or prevs[2] == "in"
--         or prevs[2] == "install"
--       )
--     then
--       local packages = {}

--       for _, package in ipairs(api.pkg.installedPackages()) do
--         local found = false

--         for j, prev in ipairs(prevs) do
--           if j >= i and package == prev then
--             found = true
--             break
--           end
--         end

--         if not found then
--           packages[#packages + 1] = package
--         end
--       end

--       --- @type string[]
--       local matches = {}

--       for _, package in ipairs(packages) do
--         if
--           curr:len() < package:len()
--           and curr == package:sub(1, curr:len())
--         then
--           matches[#matches + 1] = package:sub(curr:len() + 1)
--         end
--       end

--       --- @diagnostic disable-next-line
--       return matches
--     elseif i == 2 and prevs[2] == "run" then
--       local packages = {}

--       for _, package in ipairs(api.pkg.installedPackages()) do
--         local found = false

--         for j, prev in ipairs(prevs) do
--           if j >= i and package == prev then
--             found = true
--             break
--           end
--         end

--         if not found then
--           packages[#packages + 1] = package .. " "
--         end
--       end

--       --- @type string[]
--       local matches = {}

--       for _, package in ipairs(packages) do
--         if
--           curr:len() < package:len()
--           and curr == package:sub(1, curr:len())
--         then
--           matches[#matches + 1] = package:sub(curr:len() + 1)
--         end
--       end

--       --- @diagnostic disable-next-line
--       return matches
--     elseif i == 3 and prevs[2] == "run" then
--       local files = {}

--       for _, file in ipairs(fs.list(fs.combine(api.dir.base, prevs[3]))) do
--         local found = false

--         for j, prev in ipairs(prevs) do
--           if j >= i and file == prev then
--             found = true
--             break
--           end
--         end

--         if not found and file:sub(-4) == ".lua" then
--           files[#files + 1] = file:sub(1, file:len() - 4)
--         end
--       end

--       --- @type string[]
--       local matches = {}

--       for _, file in ipairs(files) do
--         if
--           curr:len() < file:len()
--           and curr == file:sub(1, curr:len())
--         then
--           matches[#matches + 1] = file:sub(curr:len() + 1)
--         end
--       end

--       --- @diagnostic disable-next-line
--       return matches
--     end
--   end)
-- end
