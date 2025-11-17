local test = {}

--- @param string string
--- @param fn fun()
function test.describe(string, fn)
  print("  describe: " .. string)
  fn()
end

--- @param string string
--- @param fn fun()
function test.it(string, fn)
  print("    it: " .. string)
  fn()
end

return test
