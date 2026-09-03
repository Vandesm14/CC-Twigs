local test = require "/pkgs.lib.test"
local lib = require "/pkgs.rpc.lib"

test.describe("lib.resolve", function()
  test.it("walks a dotted path through nested tables", function()
    local root = { a = { b = { c = 42 } } }
    assert(lib.resolve("a.b.c", root) == 42)
  end)

  test.it("returns nil for a missing segment", function()
    local root = { a = {} }
    assert(lib.resolve("a.b.c", root) == nil)
  end)

  test.it("returns nil when a non-table segment is indexed into", function()
    local root = { a = 1 }
    assert(lib.resolve("a.b", root) == nil)
  end)

  test.it("defaults to _G when no root is given", function()
    _G.rpcTestGlobal = { value = "hi" }
    assert(lib.resolve("rpcTestGlobal.value") == "hi")
    _G.rpcTestGlobal = nil
  end)
end)

test.describe("lib.decodeRequest", function()
  test.it("decodes a valid request", function()
    local request = lib.decodeRequest('{"id":1,"method":"turtle.forward","args":[]}')
    assert(request.id == 1)
    assert(request.method == "turtle.forward")
  end)

  test.it("returns nil for invalid JSON", function()
    assert(lib.decodeRequest("not json") == nil)
  end)

  test.it("returns nil when id is missing", function()
    assert(lib.decodeRequest('{"method":"turtle.forward"}') == nil)
  end)

  test.it("returns nil when method is missing", function()
    assert(lib.decodeRequest('{"id":1}') == nil)
  end)
end)

test.describe("lib.dispatch", function()
  test.it("calls the resolved function and returns its first result", function()
    _G.rpcTestFn = function(a, b) return a + b end
    local ok, result = lib.dispatch("rpcTestFn", { 2, 3 })
    assert(ok == true)
    assert(result == 5)
    _G.rpcTestFn = nil
  end)

  test.it("returns ok=false with a message for an unknown method", function()
    local ok, message = lib.dispatch("no.such.method", {})
    assert(ok == false)
    assert(message == "no such method: no.such.method")
  end)

  test.it("returns ok=false when the call itself errors", function()
    _G.rpcTestFn = function() error("boom") end
    local ok, message = lib.dispatch("rpcTestFn", {})
    assert(ok == false)
    assert(message:find("boom") ~= nil)
    _G.rpcTestFn = nil
  end)
end)

test.describe("lib.encodeResult / lib.encodeError", function()
  test.it("round-trips a result through JSON", function()
    local json = lib.encodeResult(7, true)
    local decoded = textutils.unserialiseJSON(json)
    assert(decoded.id == 7)
    assert(decoded.result == true)
  end)

  test.it("round-trips an error through JSON", function()
    local json = lib.encodeError(7, "bad")
    local decoded = textutils.unserialiseJSON(json)
    assert(decoded.id == 7)
    assert(decoded.error == "bad")
  end)
end)
