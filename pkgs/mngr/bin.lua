--- @param s string
--- @return string
local function trimSlash(s)
  if s:sub(s:len()) == "/" then
    s = s:sub(1, s:len() - 1)
  end
  return s
end

--- @param rootUrl string
--- @return string[]|nil packageNames
local function fetchPackages(rootUrl)
  local response = http.get(rootUrl, nil, false)
  if response == nil then return end

  --- @type string[]
  local names = {}

  local name = response.readLine(false)
  while name ~= nil do
    names[#names + 1] = name
    name = response.readLine(false)
  end

  response.close()
  return names
end

--- @param rootUrl string
--- @param packageName string
--- @return string[]|nil fileNames
local function fetchPackageFiles(rootUrl, packageName)
  local url = rootUrl .. "/" .. packageName

  local response = http.get(url, nil, false)
  if response == nil then return end

  --- @type string[]
  local names = {}

  local name = response.readLine(false)
  while name ~= nil do
    names[#names + 1] = name
    name = response.readLine(false)
  end

  response.close()
  return names
end

--- @param rootUrl string
--- @param packageName string
--- @param fileName string
--- @return string|nil fileContent
local function fetchPackageFileContent(rootUrl, packageName, fileName)
  local url = rootUrl .. "/" .. packageName .. "/" .. fileName

  local response = http.get(url, nil, false)
  if response == nil then return end

  local content = response.readAll()
  response.close()
  return content
end

if not package.loaded["mngr.bin"] then
  local mngrDir = "/.mngr"

  local tempDir = fs.combine("/.temp", mngrDir)
  if not pcall(fs.makeDir, tempDir) then
    printError("Unable to create '" .. tempDir .. "' directory.")
    return
  end

  local rootUrl = settings.get("mngr.url") or ""
  rootUrl = trimSlash(rootUrl)

  if not http.checkURL(rootUrl) then
    printError("Expected the 'mngr.url' setting to be a valid URL.")
    return
  end

  local packageNames = fetchPackages(rootUrl)
  if packageNames == nil then
    printError("Unable to fetch packages.")
    return
  end

  for _, packageName in ipairs(packageNames) do
    local packageDir = fs.combine(tempDir, packageName)

    local fileNames = fetchPackageFiles(rootUrl, packageName)
    if fileNames == nil then
      printError("Unable to fetch files for package '" .. packageName .. "'.")
      return
    end

    print("Fetching package '" .. packageName .. "'...")

    for _, fileName in ipairs(fileNames) do
      local fileContent = fetchPackageFileContent(rootUrl, packageName, fileName)
      if fileContent == nil then
        printError("Unable to fetch file '" .. fs.combine(packageName, fileName) .. "'.")
        return
      end

      local filePath = fs.combine(packageDir, fileName)

      local file = fs.open(filePath, "w")
      if file == nil then
        printError("Unable to create file '" .. filePath .. "'.")
        return
      end

      print("  Fetched '" .. fileName .. "'.")

      file.write(fileContent)
      file.close()
    end
  end

  -- Create bin directory for all package binaries
  local binDir = fs.combine(tempDir, "bin")
  if not pcall(fs.makeDir, binDir) then
    printError("Unable to create '" .. binDir .. "' directory.")
    return
  end

  -- Copy bin.lua files from packages to the bin directory for PATH access
  print("Setting up package binaries...")
  for _, packageName in ipairs(packageNames) do
    local binPath = fs.combine(tempDir, packageName, "bin.lua")
    if fs.exists(binPath) then
      local targetPath = fs.combine(binDir, packageName .. ".lua")
      
      local sourceFile = fs.open(binPath, "r")
      if sourceFile then
        local content = sourceFile.readAll()
        sourceFile.close()
        
        local targetFile = fs.open(targetPath, "w")
        if targetFile then
          targetFile.write(content)
          targetFile.close()
          print("  Added '" .. packageName .. "' binary.")
        else
          printError("Unable to create binary '" .. targetPath .. "'.")
        end
      end
    end
  end

  print("Committing '" .. tempDir .. "' to '" .. mngrDir .. "'...")

  fs.delete(mngrDir)
  fs.move(tempDir, mngrDir)
  fs.delete(tempDir)

  shell.setPath(shell.path() .. ":/.mngr/bin")

  if not fs.exists("/startup/mngr.lua") then
    print("Creating '/startup/mngr.lua'...")

    local file = fs.open("/startup/mngr.lua", "w")
    if not file then
      printError("Unable to create '/startup/mngr.lua' file.")
      return
    end

    file.writeLine("shell.setPath( shell.path() .. \":\" .. \"/.mngr/bin\")")
    file.close()
  end

  print("Done.")
end
