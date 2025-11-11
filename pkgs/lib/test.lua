local test = {}

--- @param string string
--- @param fn fun()
function test.suite(string, fn)
  print("suite: " .. string)
  fn()
end

--- @param string string
--- @param fn fun()
function test.it(string, fn)
  print("it: " .. string)
  fn()
end

return test
