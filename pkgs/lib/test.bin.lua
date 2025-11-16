--- Test runner that finds and executes all *.test.lua files recursively

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
print("Running tests from: " .. currentDir)

--- Recursively collect all files
print("Scanning directories recursively...")
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

print("Found " .. #testFiles .. " test file(s)\n")

-- Run all test files
local totalTests = 0
local passedTests = 0
local failedTests = 0

for _, testPath in ipairs(testFiles) do
  local relativePath = string.gsub(testPath, "^" .. currentDir .. "/", "")
  totalTests = totalTests + 1
  print("Running test: " .. relativePath)

  -- Run the test file
  local success = shell.run(testPath)

  if success then
    passedTests = passedTests + 1
    print("  Test passed: " .. relativePath)
  else
    failedTests = failedTests + 1
    print("  Test failed: " .. relativePath)
  end
  print()
end

-- Print summary
print(string.rep("=", 50))
print("Test Summary:")
print("  Total tests: " .. totalTests)
print("  Passed: " .. passedTests)
print("  Failed: " .. failedTests)
print(string.rep("=", 50))
