local color = require "/pkgs.lib.color"

local LOG_FILE = "test-results.log"

--- @param msg string
local function appendLog(msg)
  local file = fs.open(LOG_FILE, "a")
  if file ~= nil then
    file.writeLine(msg)
    file.close()
  end
end

--- @param ... any
--- @return string
local function toLine(...)
  local parts = {}
  for i = 1, select("#", ...) do
    parts[i] = tostring(select(i, ...))
  end
  return table.concat(parts, " ")
end

-- Each *.test.lua file is launched via shell.run, which gives it its own
-- isolated globals (a parent patching print/printError has no effect on it).
-- But require() does NOT re-isolate -- modules loaded from within that file
-- share its environment. So patching print/printError here, at require time,
-- makes every print() the test file (and anything it requires, e.g. the
-- library code actually under test) does from this point on land in the log
-- too, not just describe()/it() lines.
local originalPrint = print
local originalPrintError = printError

print = function(...)
  local msg = toLine(...)
  originalPrint(msg)
  appendLog(msg)
end

printError = function(...)
  local msg = toLine(...)
  originalPrintError(msg)
  appendLog(msg)
end

local test = {}

--- @param string string
--- @param fn fun()
function test.describe(string, fn)
  print(color.bold .. color.cyan .. "  describe: " .. string .. color.reset)
  fn()
end

--- @param string string
--- @param fn fun()
function test.it(string, fn)
  -- pcall so a failure (assertion or a plain runtime error, e.g. calling a
  -- function that doesn't exist) gets logged with its message before it's
  -- re-thrown -- re-thrown so shell.run still reports the file as failed and
  -- stops remaining it()s in it, same as before.
  local ok, err = pcall(fn)
  if ok then
    print(color.green .. "    \xe2\x9c\x93 " .. string .. color.reset)
  else
    print(color.red .. "    \xe2\x9c\x97 " .. string .. " (FAILED)" .. color.reset)
    print(color.red .. "      " .. tostring(err) .. color.reset)
    error(err, 0)
  end
end

return test
