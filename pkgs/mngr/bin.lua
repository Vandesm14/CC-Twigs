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

--- @param rootUrl string
--- @param filePath string
--- @param content string
--- @return boolean success
local function uploadFile(rootUrl, filePath, content)
  local computerId = tostring(os.getComputerID())
  local url = rootUrl .. "/upload/" .. computerId .. "/" .. filePath

  local response = http.post(url, content, nil, false)
  if response == nil then return false end

  response.close()
  return true
end

--- @param path string
--- @return string[]
local function getAllFiles(path)
  --- @type string[]
  local files = {}

  local function walk(dir)
    local items = fs.list(dir)
    for _, item in ipairs(items) do
      local itemPath = fs.combine(dir, item)
      if fs.isDir(itemPath) then
        walk(itemPath)
      else
        files[#files + 1] = itemPath
      end
    end
  end

  walk(path)
  return files
end

local args = { ... }

if args[1] == "upload" then
  -- Upload mode
  local rootUrl = settings.get("mngr.url") or ""
  rootUrl = trimSlash(rootUrl)

  if not http.checkURL(rootUrl) then
    printError("Expected the 'mngr.url' setting to be a valid URL.")
    return
  end

  print("Uploading files to server...")

  local allFiles = getAllFiles("/")
  local uploadedCount = 0
  local failedCount = 0

  for _, filePath in ipairs(allFiles) do
    -- Skip files in rom directory
    if not filePath:match("^.mngr/") and not filePath:match("^rom/") then
      local file = fs.open(filePath, "r")
      if file then
        local content = file.readAll()
        file.close()

        -- Remove leading slash for upload path
        local uploadPath = filePath:gsub("^/", "")

        print("Uploading '" .. filePath .. "'...")
        if uploadFile(rootUrl, uploadPath, content) then
          uploadedCount = uploadedCount + 1
        else
          printError("Failed to upload '" .. filePath .. "'.")
          failedCount = failedCount + 1
        end
      else
        printError("Unable to read file '" .. filePath .. "'.")
        failedCount = failedCount + 1
      end
    end
  end

  print("Upload complete: " .. uploadedCount .. " files uploaded, " .. failedCount .. " failed.")
elseif args[1] == "enable" then
  local bin = args[2]
  if not bin then
    error("Usage: mngr enable <pkg>")
  end

  local f = fs.open("startup/" .. bin .. ".lua", "w")
  if f ~= nil then
    f.write("shell.run(\"" .. bin .. "\")")
    f.close()
  end
elseif args[1] == "disable" then
  local bin = args[2]
  if not bin then
    error("Usage: mngr disable <pkg>")
  end

  fs.delete("startup/" .. bin .. ".lua")
elseif not package.loaded["mngr.bin"] then
  -- Download mode (original behavior)
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

  -- Fetch all package file lists in parallel
  print("Fetching package file lists...")
  --- @type table<string, string[]>
  local packageFiles = {}
  local fetchTasks = {}

  for _, packageName in ipairs(packageNames) do
    table.insert(fetchTasks, function()
      local fileNames = fetchPackageFiles(rootUrl, packageName)
      if fileNames ~= nil then
        packageFiles[packageName] = fileNames
      end
    end)
  end

  parallel.waitForAll(table.unpack(fetchTasks))

  -- Verify all package file lists were fetched
  for _, packageName in ipairs(packageNames) do
    if packageFiles[packageName] == nil then
      printError("Unable to fetch files for package '" .. packageName .. "'.")
      return
    end
  end

  -- Fetch all file contents in parallel
  print("Fetching all package files...")
  --- @type table<string, string>
  local fileContents = {}
  local contentFetchTasks = {}

  for _, packageName in ipairs(packageNames) do
    for _, fileName in ipairs(packageFiles[packageName]) do
      local key = packageName .. "/" .. fileName
      table.insert(contentFetchTasks, function()
        local content = fetchPackageFileContent(rootUrl, packageName, fileName)
        if content ~= nil then
          fileContents[key] = content
        end
      end)
    end
  end

  parallel.waitForAll(table.unpack(contentFetchTasks))

  -- Write all files to disk
  print("Writing files to disk...")
  for _, packageName in ipairs(packageNames) do
    local packageDir = fs.combine(tempDir, packageName)

    for _, fileName in ipairs(packageFiles[packageName]) do
      local key = packageName .. "/" .. fileName
      local fileContent = fileContents[key]

      if fileContent == nil then
        printError("Unable to fetch file '" .. key .. "'.")
        return
      end

      local filePath = fs.combine(packageDir, fileName)

      local file = fs.open(filePath, "w")
      if file == nil then
        printError("Unable to create file '" .. filePath .. "'.")
        return
      end

      print("  Wrote '" .. key .. "'.")

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

  if not fs.exists("/startup/mngr-path.lua") then
    print("Creating '/startup/mngr-path.lua'...")

    local f = fs.open("/startup/mngr-path.lua", "w")
    if f == nil then
      printError("Unable to create '/startup/mngr-path.lua' file.")
      return
    end

    f.writeLine("shell.setPath(shell.path() .. \":\" .. \"/.mngr/bin\")")
    f.close()
  end

  print("Done.")
end
