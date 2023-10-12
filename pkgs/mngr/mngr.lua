local subcommand = arg[1]

if subcommand == "in" or subcommand == "install" then
  local api = require("mngr.api")
  local url = api.url()

  if type(url) == "nil" then
    print("Setting mngr.url is missing or an invalid URL.")
    return
  end

  for i, package in ipairs(arg) do
    if i > 1 then
      if not(type(package) == "string") then
        print("Usage: " .. arg[0] .. " install <...package>")
        return
      end

      if not api.pkg.installPackage(url, package) then
        print("Unable to install package " .. package .. ".")
      else
        print("Installed package " .. package .. ".")
      end
    end
  end
elseif subcommand == "un" or subcommand == "uninstall" then
  local api = require("mngr.api")

  for i, package in ipairs(arg) do
    if i > 1 then
      if not(type(package) == "string") then
        print("Usage: " .. arg[0] .. " uninstall <...package>")
        return
      end

      if not api.pkg.uninstallPackage(package) then
        print("Unable to uninstall package " .. package .. ".")
      else
        print("Uninstalled package " .. package .. ".")
      end
    end
  end
elseif subcommand == "up" or subcommand == "update" then
  local api = require("mngr.api")
  local url = api.url()

  if type(url) == "nil" then
    print("Setting mngr.url is missing or an invalid URL.")
    return
  end

  for _, package in ipairs(api.pkg.installedPackages()) do
    if not(type(package) == "string") then
      print("Usage: " .. arg[0] .. " update <...package>")
      return
    end

    if not api.pkg.installPackage(url, package) then
      print("Unable to update package " .. package .. ".")
    else
      print("Updated package " .. package .. ".")
    end
  end
elseif subcommand == "run" then
  local api = require("mngr.api")

  local package = arg[2]
  local file = arg[3]

  if not (type(package) == "string" and type(file) == "string") then
    print("Usage: " .. arg[0] .. " run <package> <file> [...args]")
    return
  end

  local foundPackage = false
  for _, installed in ipairs(api.pkg.installedPackages()) do
    if package == installed then
      foundPackage = true
      break
    end
  end

  if not foundPackage then
    print("Usage: " .. arg[0] .. " run <package> <file> [...args]")
    return
  end

  local foundFile = false
  for _, installed in ipairs(fs.list(fs.combine(api.dir.base, package))) do
    if file .. ".lua" == installed then
      foundFile = true
      break
    end
  end

  if not foundFile then
    print("Usage: " .. arg[0] .. " run <package> <file> [...args]")
    return
  end

  if not shell.run(fs.combine(api.dir.base, package, file), table.unpack(arg, 4)) then
    print("Unable to run " .. package .. "/" .. file .. ".")
    return
  end
elseif subcommand == "completions" then
  local api = require("mngr.api")
  api.shell.setupCompletions()
elseif subcommand == "startup" then
  fs.makeDir("/startup")

  local startup = fs.open("/startup/mngr.lua", "w")

  if type(startup) == "nil" then
    print("Unable to create startup/mngr.lua file.")
    return
  end

  startup.write("shell.setPath(shell.path() .. \":/.mngr/mngr\")")
  startup.write("shell.run(\"mngr\", \"completions\")")
  startup.close()
elseif not fs.exists("/.mngr") then
  print("It appears that mngr is not installed, would you like to install it? (y/N)")
  local input = read()

  if not (input:lower() == "y") then return end

  --- @type string
  local url = settings.get("mngr.url")

  if not (type(url) == "string" and http.checkURL(url)) then
    print("Setting mngr.url is missing or an invalid URL.")
    return
  end

  if url:sub(-1) == "/" then
    url = url:sub(1, url:len() - 1)
  end

  -- Create the mngr directory and mngr package.
  fs.makeDir("/.mngr/mngr")

  -- Download the temporary mngr install.
  local packageRequest = http.get(url .. "/mngr")

  if type(packageRequest) == "nil" then
    print("Unable to request the mngr package.")
    return
  end

  local file = packageRequest.readLine()
  while not (type(file) == "nil") do
    local fileRequest = http.get(url .. "/mngr/" .. file)

    if type(fileRequest) == "nil" then
      print("Unable to request the mngr/" .. file .. " file.")
      return
    end

    local content = fileRequest.readAll()

    fileRequest.close()

    if type(content) == "nil" then
      print("Unable to request the mngr/" .. file .. " file.")
      return
    end

    local f = fs.open("/.mngr/mngr/" .. file, "w")

    if type(f) == "nil" then
      print("Unable to open /.mngr/mngr/" .. file " file in write mode.")
      return
    end

    f.write(content)
    f.close()

    file = packageRequest.readLine()
  end

  packageRequest.close()

  print("Installed package mngr.")

  -- Since mngr proper is now installed, we can use its APIs.
  local api = require("mngr.api")

  api.shell.setupCompletions()
  shell.setPath(shell.path() .. ":/.mngr/mngr")
  shell.run("mngr", "startup")
else
  print("Usage: " .. arg[0] .. " <subcommand>")
  print()
  print("Subcommands:")
  print("  in,   install <...package>")
  print("  un, uninstall <...package>")
  print("  up,    update")
  print("            run <package> <file>")
  print("    completions")
  print("        startup")
end
