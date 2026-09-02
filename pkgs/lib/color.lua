-- ANSI escape codes for coloring the test log. This has nothing to do with
-- CC's own terminal colors (term.setTextColor) -- the log is a plain file on
-- the host disk, read back with `cat`, so plain ANSI is what a real terminal
-- needs to render it in color.
local ESC = string.char(27)

return {
  reset = ESC .. "[0m",
  bold = ESC .. "[1m",
  dim = ESC .. "[2m",
  red = ESC .. "[31m",
  green = ESC .. "[32m",
  cyan = ESC .. "[36m",
}
