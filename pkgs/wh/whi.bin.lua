-- whi: minimal interactive TUI example for ordering items from the warehouse.
-- Type a query and/or amount ("stick 2" or "2 stick"), list filters live.
-- Enter with a valid match+amount adds it to the cart and loops for another
-- item. Enter on a blank query processes the whole cart and shows a receipt.

local lib = require "/pkgs.wh.lib"

--- @param counts table<string, number>
--- @param query string
--- @return { name: string, count: number }[]
local function filteredSorted(counts, query)
  local items = {}
  for name, count in pairs(counts) do
    if query == "" or string.find(name, query, 1, true) ~= nil then
      table.insert(items, { name = name, count = count })
    end
  end
  table.sort(items, function(a, b) return a.count > b.count end)
  return items
end

--- Splits "stick 2" or "2 stick" into query text and numeric amount.
--- @param buffer string
--- @return string query
--- @return number|nil amount
local function parseBuffer(buffer)
  local queryParts = {}
  local amount = nil
  for token in buffer:gmatch("%S+") do
    local n = tonumber(token)
    if n ~= nil and amount == nil then
      amount = n
    else
      table.insert(queryParts, token)
    end
  end
  return table.concat(queryParts, " "), amount
end

local function drawList(cache, buffer, cart)
  term.clear()
  term.setCursorPos(1, 1)

  if #cart > 0 then
    print("Cart:")
    for _, entry in ipairs(cart) do
      print("  " .. entry.name .. " x " .. entry.amount)
    end
    print("")
  end

  print("wh order> " .. buffer)
  print("")

  local query, amount = parseBuffer(buffer)
  local items = filteredSorted(cache.counts or {}, query)

  for i = 1, math.min(#items, 10) do
    print(items[i].name .. ": " .. items[i].count)
  end

  return query, amount
end

--- Reads one line of input while redrawing the filtered list on every
--- keystroke. Returns the finished buffer once Enter is pressed.
local function readQuery(cache, cart)
  local buffer = ""
  drawList(cache, buffer, cart)

  while true do
    local event, p1 = os.pullEvent()
    if event == "char" then
      buffer = buffer .. p1
      drawList(cache, buffer, cart)
    elseif event == "key" then
      if p1 == keys.enter then
        return buffer
      elseif p1 == keys.backspace then
        buffer = buffer:sub(1, -2)
        drawList(cache, buffer, cart)
      end
    end
  end
end

local function showReceipt(cart)
  term.clear()
  term.setCursorPos(1, 1)
  print("Receipt")
  print("-------")
  for _, entry in ipairs(cart) do
    print(entry.name .. " x " .. entry.amount)
  end
  print("")
  print("Press any key to start over.")
end

local function waitAnyKey()
  while true do
    local event = os.pullEvent()
    if event == "key" or event == "char" then
      return
    end
  end
end

local cart = {}
while true do
  local cache = lib.loadOrInitCache()
  local buffer = readQuery(cache, cart)
  local query, amount = parseBuffer(buffer)

  if query == "" and amount == nil then
    -- blank enter: process the cart if there's anything in it
    if #cart > 0 then
      for _, entry in ipairs(cart) do
        lib.order(cache, entry.name, entry.amount)
      end
      lib.saveCache(cache)
      showReceipt(cart)
      waitAnyKey()
      cart = {}
    end
  else
    local name = lib.matchQuery(cache, query)
    local available = name ~= nil and lib.countItem(cache, name) or 0

    if name ~= nil and amount ~= nil and amount > 0 and amount <= available then
      table.insert(cart, { name = name, amount = amount })
    end
    -- no valid match/amount: loop back and let them keep typing
  end
end
