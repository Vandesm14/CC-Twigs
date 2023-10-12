--- A transactional filesystem API.
local tfs = {}

--- Create a new file via a transaction.
---
--- If the transaction fails, the file will not be written to the filesystem.
---
--- Be sure to flush written data by the end of the transaction, otherwise it
--- may be lost.
---
--- @param path string
--- @param mode openMode
--- @param func fun(handle: ReadHandle|WriteHandle|BinaryReadHandle|BinaryWriteHandle): boolean
--- @return boolean success
--- @return string|nil errorMessage
function tfs.createFile(path, mode, func)
  if fs.exists(path) then
    return false, "path already exists"
  end

  local handle, errorMessage = fs.open(path, mode)

  if handle == nil then
    return false, errorMessage
  elseif not func(handle) then
    if handle ~= nil then handle.close() end
    fs.delete(path)

    return false, "failed transaction operation"
  end

  return true
end

--- Create a new directory via a transaction.
---
--- If the transaction fails, the directory will not be written to the
--- filesystem. Any child files and directory are also lost.
---
--- @param path string
--- @param func fun(path: string): boolean
--- @return boolean success
--- @return string|nil errorMessage
function tfs.createDir(path, func)
  if fs.exists(path) then
    return false, "path already exists"
  end

  fs.makeDir(path)

  if not func(path) then
    fs.delete(path)
    return false, "failed transaction operation"
  end

  return true
end

return tfs
