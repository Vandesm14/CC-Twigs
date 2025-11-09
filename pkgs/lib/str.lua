local str = {}

--- Split a string by a delimiter
--- @param text string The string to split
--- @param delimiter string The delimiter to split by
--- @return string[] An array of split strings
function str.split(text, delimiter)
  local result = {}
  local pattern = "(.-)" .. delimiter
  local last_end = 1
  local s, e, cap = text:find(pattern, 1)
  
  while s do
    if s ~= 1 or cap ~= "" then
      table.insert(result, cap)
    end
    last_end = e + 1
    s, e, cap = text:find(pattern, last_end)
  end
  
  if last_end <= #text then
    cap = text:sub(last_end)
    table.insert(result, cap)
  end
  
  return result
end

--- Get the part of a string after the last occurrence of a delimiter
--- Useful for getting the short name from "namespace:item_name"
--- @param text string The string to search
--- @param delimiter string The delimiter to search for
--- @return string|nil The part after the last delimiter, or nil if not found
function str.afterLast(text, delimiter)
  local parts = str.split(text, delimiter)
  if #parts > 0 then
    return parts[#parts]
  end
  return nil
end

--- Get the part of a string before the last occurrence of a delimiter
--- Useful for getting the namespace from "namespace:item_name"
--- @param text string The string to search
--- @param delimiter string The delimiter to search for
--- @return string|nil The part before the last delimiter, or nil if not found
function str.beforeLast(text, delimiter)
  local parts = str.split(text, delimiter)
  if #parts > 1 then
    -- Join all parts except the last one
    local result = parts[1]
    for i = 2, #parts - 1 do
      result = result .. delimiter .. parts[i]
    end
    return result
  elseif #parts == 1 then
    return parts[1]
  end
  return nil
end

--- Check if a string contains a substring
--- @param text string The string to search in
--- @param substring string The substring to search for
--- @return boolean True if the substring is found, false otherwise
function str.contains(text, substring)
  return string.find(text, substring, 1, true) ~= nil
end

--- Check if two strings are equal (case-sensitive)
--- @param a string First string
--- @param b string Second string
--- @return boolean True if strings are equal
function str.equals(a, b)
  return a == b
end

--- Trim whitespace from both ends of a string
--- @param text string The string to trim
--- @return string The trimmed string
function str.trim(text)
  return text:match("^%s*(.-)%s*$")
end

--- Check if a string starts with a prefix
--- @param text string The string to check
--- @param prefix string The prefix to check for
--- @return boolean True if the string starts with the prefix
function str.startsWith(text, prefix)
  return text:sub(1, #prefix) == prefix
end

--- Check if a string ends with a suffix
--- @param text string The string to check
--- @param suffix string The suffix to check for
--- @return boolean True if the string ends with the suffix
function str.endsWith(text, suffix)
  return text:sub(-#suffix) == suffix
end

return str

