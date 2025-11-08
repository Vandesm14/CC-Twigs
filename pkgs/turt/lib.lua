--- Shared library for turt package

local lib = {}

-- Get our computer name/ID
lib.OUR_NAME = os.getComputerLabel()
if lib.OUR_NAME == nil then
  lib.OUR_NAME = tostring(os.getComputerID())
end

return lib

