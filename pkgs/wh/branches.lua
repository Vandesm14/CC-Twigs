local function X(n)
  if n <= 1 then
    return ""
  else
    return "r" .. string.rep("f", n - 1) .. "l"
  end
end

local function Y(n)
  return string.rep("f", n)
end

local function XY(x, y)
  return X(x) .. Y(y)
end

--- @class Branches
--- @field input table<number|string, string>
--- @field storage table<number, string>
--- @field output table<number|string, string>
local branches = {
  -- L: Left
  -- R: Right
  -- F: Forward
  -- I: Input (take items)
  -- O: Output (put items)
  -- C: Chest (I/O based on order)
  -- X: Move until checkpoint (orange)
  -- H: Home (stack up and wait)
  --
  input = {
    [1] = "ffix",
    ["_"] = "x",
  },

  storage = {
    --
    [0]  = "lx" .. XY(1, 1) .. "c",
    [2]  = "lx" .. XY(2, 1) .. "c",
    [3]  = "lx" .. XY(3, 1) .. "c",
    --
    [4]  = "lx" .. XY(1, 2) .. "c",
    [5]  = "lx" .. XY(2, 2) .. "c",
    [6]  = "lx" .. XY(3, 2) .. "c",
    --
    [7]  = "lx" .. XY(1, 3) .. "c",
    [8]  = "lx" .. XY(2, 3) .. "c",
    [9]  = "lx" .. XY(3, 3) .. "c",
    --
    [10] = "lx" .. XY(1, 4) .. "c",
    [11] = "lx" .. XY(2, 4) .. "c",
    [12] = "lx" .. XY(3, 4) .. "c",
  },

  output = {
    [18] = "xfoxh",
    ["_"] = "xxh"
  },
}

return branches
