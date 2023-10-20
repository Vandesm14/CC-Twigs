--- @param rootUrl string
--- @return { bins: string[], libs: table<string, string[]> }|nil
local function fetchPackages(rootUrl)
  if not http.checkURL(rootUrl) then return end

  local response = http.get(rootUrl, nil, false)
  if response == nil then return end

  local content = response.readAll()
  if content == nil then return end

  local json = textutils.unserialiseJSON(content, { parse_empty_array = false })
  if json == nil then return end

  response.close()

  return json
end

--- @param rootUrl string
--- @return string|nil
local function fetchFile(rootUrl, filePath)
  if not http.checkURL(rootUrl) then return end

  -- Remove the postfix forward-slash from the rootUrl, if it has one.
  if rootUrl:sub(rootUrl:len()) == "/" then
    rootUrl = rootUrl:sub(1, rootUrl:len() - 1)
  end

  -- Remove the prefix forward-slash from the filePath, if it has one.
  if filePath:sub(1, 1) == "/" then
    filePath = filePath:sub(2)
  end

  local url = rootUrl .. "/" .. filePath

  local response = http.get(url, nil, false)
  if response == nil then return end

  local content = response.readAll()
  if content == nil then return end

  response.close()

  return content
end

local mngrDir = "/.mngr"
local tempDir = "/" .. fs.combine("/.temp", mngrDir)
--- @type string|nil
local rootUrl = settings.get("mngr.url")

if type(rootUrl) ~= "string" or not http.checkURL(rootUrl) then
  printError("Expected setting 'mngr.url' to be a valid URL.")
  return
end

if not pcall(fs.makeDir, tempDir) then
  printError("Unable to create temporary directory.")
  return
end

local packages = fetchPackages(rootUrl)
if packages == nil then
  printError("Unable to fetch packages.")
  return
end

for lib, files in pairs(packages.libs) do
  print("Downloading library '" .. lib .. "'...")

  for _, file in ipairs(files) do
    local urlFilePath = fs.combine(lib, file)
    local filePath = "/" .. fs.combine(tempDir, urlFilePath)

    local fileContent = fetchFile(rootUrl, urlFilePath)
    if fileContent == nil then
      printError("  Unable to download file.")
      return
    end

    local fileOpened, fileHandle = pcall(fs.open, filePath, "w")
    if not fileOpened or fileHandle == nil then
      printError("  Unable to create file.")
      return
    end

    fileHandle.write(fileContent)
    fileHandle.flush()
    fileHandle.close()

    print("  Downloaded file '" .. urlFilePath .. "'.")
  end

  print("Downloaded library '" .. lib .. "'.")
end

for _, bin in ipairs(packages.bins) do
  print("Downloading binary '" .. bin .. "'...")

  local filePath = "/" .. fs.combine(tempDir, bin)

  local fileContent = fetchFile(rootUrl, bin)
  if fileContent == nil then
    printError("  Unable to download file.")
    return
  end

  local fileOpened, fileHandle = pcall(fs.open, filePath, "w")
  if not fileOpened or fileHandle == nil then
    printError("  Unable to create file.")
    return
  end

  fileHandle.write(fileContent)
  fileHandle.flush()
  fileHandle.close()

  print("Downloaded binary '" .. bin .. "'.")
end

print("Committing...")

if not pcall(fs.delete, mngrDir) then
  printError("  Unable to delete old mngr directory.")
  return
end

if not pcall(fs.move, tempDir, mngrDir) then
  printError("  Unable to replace mngr directory.")
  return
end

if not pcall(fs.delete, tempDir) then
  printError("  Unable to delete temporary directory.")
  return
end

print("Committed.")

if not fs.exists("/startup/mngr.lua") then
  print("Setting up startup...")
  shell.setPath(shell.path() .. ":" .. mngrDir)

  if not fs.isDir("/startup") then
    if not pcall(fs.makeDir, tempDir) then
      printError("  Unable to create startup directory.")
      return
    end
  end

  local fileOpened, fileHandle = pcall(fs.open, "/startup/mngr.lua", "w")
  if not fileOpened or fileHandle == nil then
    printError("  Unable to create startup file.")
    return
  end

  fileHandle.writeLine("shell.setPath(shell.path() .. \":" .. mngrDir .. "\")")

  fileHandle.flush()
  fileHandle.close()

  print("Startup setup.")
end
