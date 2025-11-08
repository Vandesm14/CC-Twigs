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
    -- [1] = "fix",
    [13] = "ffix",
    ["_"] = "x",
  },

  storage = {
    -- b1, s1
    [12] = "lx" .. XY(1, 1) .. "cxxl",
    -- [2]  = "lx" .. XY(2, 1) .. "cxxl",
    -- [3]  = "lx" .. XY(3, 1) .. "cxxl",
    -- [4]  = "lx" .. XY(1, 2) .. "cxxl",
    -- [5]  = "lx" .. XY(2, 2) .. "cxxl",
    [11] = "lx" .. XY(3, 2) .. "cxxl",

    -- b1, s2
    [5]  = "lxx" .. XY(1, 1) .. "cxl",
    -- [8]  = "lxx" .. XY(2, 1) .. "cxl",
    -- [9]  = "lxx" .. XY(3, 1) .. "cxl",
    -- [10] = "lxx" .. XY(1, 2) .. "cxl",
    -- [11] = "lxx" .. XY(2, 2) .. "cxl",
    [6]  = "lxx" .. XY(3, 2) .. "cxl",

    -- b2, s1
    [10] = "x" .. XY(1, 1) .. "cxx",
    -- [14] = "x" .. XY(2, 1) .. "cxx",
    -- [15] = "x" .. XY(3, 1) .. "cxx",
    -- [16] = "x" .. XY(1, 2) .. "cxx",
    -- [17] = "x" .. XY(2, 2) .. "cxx",
    [9]  = "x" .. XY(3, 2) .. "cxx",

    -- b2, s2
    [7]  = "xx" .. XY(1, 1) .. "cx",
    -- [20] = "xx" .. XY(2, 1) .. "cx",
    -- [21] = "xx" .. XY(3, 1) .. "cx",
    -- [22] = "xx" .. XY(1, 2) .. "cx",
    -- [23] = "xx" .. XY(2, 2) .. "cx",
    [8]  = "xx" .. XY(3, 2) .. "cx",
  },

  output = {
    [14] = "xfoxh",
    -- [2] = "xffoxh",
    ["_"] = "xxh"
  },
}

return branches
