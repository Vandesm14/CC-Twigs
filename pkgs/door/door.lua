local Setting = {
  Passcode = "door.passcode",
  Side = "door.side",
  OverrideSide = "door.overrideSide",
  HoldTime = "door.holdTime"
}

function Setting.passcode()
  return settings.get(Setting.Passcode)
end

function Setting.side()
  return settings.get(Setting.Side)
end

function Setting.overrideSide()
  return settings.get(Setting.OverrideSide)
end

function Setting.holdTime()
  return settings.get(Setting.HoldTime)
end

local function openDoor()
  local side = Setting.side()

  redstone.setOutput(side, true)
  os.sleep(Setting.holdTime())
  redstone.setOutput(side, false)
end

local function waitForPasscode()
  local passcode = tonumber(read("*"))

  if passcode == Setting.passcode() then
    openDoor()
  end
end

local function waitForOverride()
  os.pullEvent("redstone")

  local overrideSide = Setting.overrideSide()

  if overrideSide ~= nil and redstone.getInput(overrideSide) then
    openDoor()
  end
end

local function run()
  term.clear()

  term.setCursorPos(1, 1)
  term.write("Maintenance Access")

  local textColor = term.getTextColor()

  term.setCursorPos(1, 3)
  term.setTextColor(colors.yellow)
  term.write("WARNING:")
  term.setCursorPos(1, 4)
  term.write("Possibility of injury or death beyond this point.")
  term.setTextColor(textColor)

  term.setCursorPos(1, 6)
  term.write("Enter Passcode: ")

  parallel.waitForAny(waitForOverride, waitForPasscode)
end

settings.define(Setting.Passcode, {
  description = "The door passcode",
  type = "number"
})

settings.define(Setting.Side, {
  description = "The side the door is on",
  type = "string"
})

settings.define(Setting.OverrideSide, {
  description = "The side the door override is on",
  type = "string"
})

settings.define(Setting.HoldTime, {
  description = "The door hold time in seconds",
  type = "number",
  default = 3
})

while true do
  run()
end
