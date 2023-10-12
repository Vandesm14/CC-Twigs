--- Provides transaction-based filesystem APIs.
---
--- Since these operations must be stateless, they are more stict on the
--- existance and non-existance of paths. This is to ensure that unassociated
--- files and directories are not affected by these operations.
local tfs = {}

--- Creates a new file.
---
--- @param path string
--- @param mode openMode
--- @return ReadHandle|WriteHandle|BinaryReadHandle|BinaryWriteHandle|nil handle
--- @return fun(): nil revert
function tfs.createFile(path, mode)
  if fs.exists(path) then
    return nil, function() end
  end

  local success, handle = pcall(fs.open, path, mode)

  if success and handle ~= nil then
    return handle, function()
      handle.close()
      fs.delete(path)
    end
  end

  return nil, function() end
end

--- Copies a file to a destination.
---
--- @param path string
--- @param dest string
--- @return string|nil dest
--- @return fun(): nil revert
function tfs.copyFile(path, dest)
  if not fs.exists(path) or fs.exists(dest) then
    return nil, function() end
  end

  local success = pcall(fs.copy, path, dest)

  if success then
    return dest, function() fs.delete(dest) end
  end

  return nil, function() end
end

--- Creates a new directory.
---
--- Any sub-directories or files stored in the directory are lost on revert.
---
--- @param path string
--- @return string|nil path
--- @return fun(): nil revert
function tfs.createDir(path)
  if fs.exists(path) then
    return nil, function() end
  end

  local success = pcall(fs.makeDir, path)

  if success then
    return path, function() fs.delete(path) end
  end

  return nil, function() end
end

return tfs
