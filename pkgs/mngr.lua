--- @alias pkgFile binFile|libFile
--- @alias binFile { type: "bin", name: string }
--- @alias libFile { type: "lib", name: string }

--- @param rootUrl string
--- @return pkgFile[]|nil
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

if type(rootUrl) ~= "string" then
  printError("Expected setting 'mngr.url' to be a valid URL.")
  return
end

if not http.checkURL(rootUrl) then
  printError("Invalid URL '" .. rootUrl .. "' in setting 'mngr.url'.")
  return
end

if not pcall(fs.makeDir, tempDir) then
  printError("Unable to create directory '" .. tempDir .. "'.")
  return
end

local packages = fetchPackages(rootUrl)
if packages == nil then
  printError("Unable to fetch packages.")
  return
end

for _, package in ipairs(packages) do
  if package.type == "bin" then
    local filePath = "/" .. fs.combine(tempDir, package.name)
    local fileContent = fetchFile(rootUrl, package.name)

    if not fileContent then
      printError("Unable to fetch file content for '" .. package.name .. "'.")
      return
    end

    local fileSuccess, file = pcall(fs.open, filePath, "w")

    if not fileSuccess or file == nil then
      printError("Unable to create file '" .. filePath .. "'.")
      return
    end

    file.write(fileContent)
    file.flush()
    file.close()

    print("Downloaded binary '" .. package.name .. "'.")
  elseif package.type == "lib" then
    local fileDir = "/" .. fs.combine(tempDir, fs.getDir(package.name))
    local fileContent = fetchFile(rootUrl, package.name)

    if not fileContent then
      printError("Unable to fetch file content for '" .. package.name .. "'.")
      return
    end

    if not pcall(fs.makeDir, fileDir) then
      printError("Unable to create directory '" .. fileDir .. "'.")
      return
    end

    local filePath = "/" .. fs.combine(fileDir, fs.getName(package.name))
    local fileSuccess, file = pcall(fs.open, filePath, "w")

    if not fileSuccess or file == nil then
      printError("Unable to create file '" .. filePath .. "'.")
      return
    end

    file.write(fileContent)
    file.flush()
    file.close()

    print("Downloaded library '" .. package.name .. "'.")
  end
end

if not pcall(fs.delete, mngrDir) then
  printError("Unable to delete directory '" .. mngrDir .. "'.")
  return
end

if not pcall(fs.move, tempDir, mngrDir) then
  printError("Unable to move directory '" .. tempDir .. "' to '" .. mngrDir .. "'.")
  return
end

if not pcall(fs.delete, tempDir) then
  printError("Unable to delete directory '" .. tempDir .. "'.")
  return
end
