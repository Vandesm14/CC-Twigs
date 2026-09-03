-- Connects to the Rust RPC server (see ../../remote) and executes whatever
-- dotted-path method calls it sends, e.g. {"id":1,"method":"turtle.forward","args":[]}.
--
-- Configure the server URL first:
--   set rpc.url ws://<host>:8080/ws
--
-- The computer's label (or its id, if unlabelled) is appended as the last
-- path segment (.../ws/<name>) so the server can address it by name.

local lib = require "/pkgs.rpc.lib"

local url = settings.get("rpc.url")
if url == nil then
  printError("Set the 'rpc.url' setting to the RPC server's ws:// URL first, e.g.:")
  printError("  set rpc.url ws://localhost:8080/ws")
  return
end

local name = os.getComputerLabel() or tostring(os.getComputerID())

local backoff = 1
local maxBackoff = 30

--- Opens a websocket and waits for the connect to succeed or fail.
--- Async + event wait (rather than the blocking http.websocket) since
--- that's what actually reports failures reliably across CC:Tweaked
--- versions.
--- @param wsUrl string
--- @return table|nil handle
--- @return string|nil errorMessage
local function connect(wsUrl)
  http.websocketAsync(wsUrl)
  while true do
    local event, eventUrl, handleOrMessage = os.pullEvent()
    if event == "websocket_success" and eventUrl == wsUrl then
      return handleOrMessage, nil
    elseif event == "websocket_failure" and eventUrl == wsUrl then
      return nil, handleOrMessage
    end
  end
end

while true do
  local wsUrl = url .. "/" .. textutils.urlEncode(name)
  local ws, err = connect(wsUrl)

  if ws == nil then
    printError("Connect failed: " .. tostring(err) .. ". Retrying in " .. backoff .. "s...")
    sleep(backoff)
    backoff = math.min(backoff * 2, maxBackoff)
  else
    print("Connected to " .. url .. " as '" .. name .. "'.")
    backoff = 1

    while true do
      local message = ws.receive()
      if message == nil then
        print("Disconnected. Reconnecting...")
        break
      end

      local request = lib.decodeRequest(message)
      if request ~= nil then
        local ok, result = lib.dispatch(request.method, request.args or {})
        if ok then
          ws.send(lib.encodeResult(request.id, result))
        else
          ws.send(lib.encodeError(request.id, tostring(result)))
        end
      end
    end

    ws.close()
  end
end
