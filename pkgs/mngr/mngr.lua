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

if not package.loaded["mngr.mngr"] then
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

  print("Committing '" .. tempDir .. "' to '" .. mngrDir .. "'...")

  fs.delete(mngrDir)
  fs.move(tempDir, mngrDir)
  fs.delete(tempDir)

  print("Done.")

  shell.setPath( shell.path() .. ":/.mngr/mngr")

  if not fs.exists("/startup/mngr.lua") then
    local file = fs.open("/startup/mngr.lua", "w")
    if not file then
      printError("Unable to create '/startup/mngr.lua' file.")
      return
    end

    file.writeLine("shell.setPath( shell.path() .. \":\" .. \"/.mngr/mngr\")")
    file.close()
  end
end
