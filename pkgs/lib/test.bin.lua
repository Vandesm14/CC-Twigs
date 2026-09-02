--- Test runner that finds and executes all *.test.lua files recursively

local color = require "/pkgs.lib.color"

local LOG_FILE = "test-results.log"

-- CraftOS-PC's headless renderer repaints the whole visible screen on every
-- update (as `\r`-separated fragments, only turning into a real line once it
-- scrolls off-screen), so piping its stdout to a file gives a noisy, lossy
-- transcript instead of a clean log. Sidestep that: write straight to a real
-- file on disk instead. Each shell.run'd test file gets its own sandboxed
-- environment (globals don't inherit from the caller), so this can't be done
-- by monkey-patching print/printError here -- it has to open/append/close on
-- every call, matching what pkgs/lib/test.lua does independently.
--- @param msg string
local function log(msg)
  print(msg)
  local file = fs.open(LOG_FILE, "a")
  if file ~= nil then
    file.writeLine(msg)
    file.close()
  end
end

fs.delete(LOG_FILE)

--- Recursively walk a directory and collect all files
--- @param path string The directory path to walk
--- @param files table|nil Optional table to collect files into (for recursion)
--- @return table Array of file paths found
local function walkDir(path, files)
  files = files or {}

  if not fs.exists(path) or not fs.isDir(path) then
    return files
  end

  local items = fs.list(path)

  for _, item in ipairs(items) do
    local itemPath = fs.combine(path, item)

    if fs.isDir(itemPath) then
      -- Recursively walk subdirectories
      walkDir(itemPath, files)
    else
      -- Add file to collection
      table.insert(files, itemPath)
    end
  end

  return files
end

local currentDir = shell.dir()
local currentScript = fs.getName(shell.getRunningProgram())
log(color.dim .. "Running tests from: " .. currentDir .. color.reset)

--- Recursively collect all files
log(color.dim .. "Scanning directories recursively..." .. color.reset)
local allFiles = walkDir(currentDir)

--- Filter to only test files
local testFiles = {}
for _, filePath in ipairs(allFiles) do
  local fileName = fs.getName(filePath)

  -- Check if it's a test file (ends with .test.lua) and not the current script
  -- Pattern: must have .test.lua as the extension (not .bin.lua or anything else)
  if fileName ~= currentScript and string.match(fileName, "^.+%.test%.lua$") then
    table.insert(testFiles, filePath)
  end
end

log(color.dim .. "Found " .. #testFiles .. " test file(s)" .. color.reset)
log("")

-- Run all test files
local totalTests = 0
local passedTests = 0
local failedTests = 0

for _, testPath in ipairs(testFiles) do
  local relativePath = string.gsub(testPath, "^" .. currentDir .. "/", "")
  totalTests = totalTests + 1
  log(color.bold .. "Running tests: " .. relativePath .. color.reset)

  -- Run the test file
  local success = shell.run(testPath)

  if success then
    passedTests = passedTests + 1
    log(color.green .. color.bold .. "  All passed" .. color.reset)
  else
    failedTests = failedTests + 1
    log(color.red .. color.bold .. "  Some failed" .. color.reset)
  end
  log("")
end

-- Print summary
log(color.bold .. string.rep("=", 50) .. color.reset)
log(color.bold .. "Test Summary:" .. color.reset)
log("  Total tests: " .. totalTests)
log("  " .. color.green .. "Passed: " .. passedTests .. color.reset)
log("  " .. (failedTests > 0 and color.red or color.dim) .. "Failed: " .. failedTests .. color.reset)
log(color.bold .. string.rep("=", 50) .. color.reset)
