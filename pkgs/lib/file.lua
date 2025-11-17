local file = {}

--- Write content to a file, overwriting any existing content
--- @param name string The path to the file
--- @param content string The content to write to the file
--- @return boolean success if the operation was successful
function file.write(name, content)
  local f = fs.open(name, "w")
  if f ~= nil then
    f.write(content)
    f.close()
    return true
  end
  return false
end

--- Append content to a file, preserving any existing content
--- @param name string The path to the file
--- @param content string The content to append to the file
--- @return boolean success if the operation was successful
function file.append(name, content)
  local f = fs.open(name, "a")
  if f ~= nil then
    f.write(content)
    f.close()
    return true
  end
  return false
end

return file
