--- === MirrorKeyboard ===
---
--- Mirrors the keyboard input from one half of the keyboard to the other.
---
--- This can help when experiencing RSI or Carpal Tunnel pain in one hand.
---
--- Only right-to-left mirroring is supported at this time.

local log = hs.logger.new('MirrorKeyboard', 'info')

local obj={}
obj.__index = obj

-- Metadata
obj.name = "MirrorKeyboard"
obj.version = "0.1"
obj.author = "Dan Hulton <dan@danhulton.com>"
obj.homepage = "https://github.com/DanHulton/MirrorKeyboard.spoon"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- MirrorKeyboard.rightToLeft
--- Constant
--- Constant to pass to MirrorKeyboard:start(), indicating the user wants to
--- mirror the right half of the keyboard to the left half.
obj.rightToLeft = 'rtl'

-- obj.leftToRight -- Not implemented yet.
-- obj.customOrientation -- Not implemented yet.

local _rtlMapping = {
  -- This is done via the system key eventtap event
  -- caps_lock = { default = "return", secondary = "caps_lock" },

  ["`"] = { default = "delete", tertiary = "`" },
  ["1"] = { default = nil, primary = "0", secondary = "=", tertiary = nil },
  ["2"] = { default = nil, primary = "9", secondary = "-", tertiary = nil },
  ["3"] = { default = nil, primary = "8", secondary = nil, tertiary = nil },
  ["4"] = { default = nil, primary = "7", secondary = nil, tertiary = nil },
  ["5"] = { default = nil, primary = "6", secondary = nil, tertiary = nil },

  q = { default = nil, primary = "p", secondary = "\\", tertiary = nil },
  w = { default = nil, primary = "o", secondary = "]", tertiary = "up" },
  e = { default = nil, primary = "i", secondary = "[", tertiary = nil },
  r = { default = nil, primary = "u", secondary = nil, tertiary = nil },
  t = { default = nil, primary = "y", secondary = nil, tertiary = nil },

  a = { default = nil, primary = ";", secondary = "'", tertiary = "left" },
  s = { default = nil, primary = "l", secondary = ";", tertiary = "down" },
  d = { default = nil, primary = "k", secondary = nil, tertiary = "right" },
  f = { default = nil, primary = "j", secondary = nil, tertiary = nil },
  g = { default = nil, primary = "h", secondary = nil, tertiary = nil },

  z = { default = nil, primary = ".", secondary = "/", tertiary = nil },
  x = { default = nil, primary = ",", secondary = ".", tertiary = nil },
  c = { default = nil, primary = "m", secondary = ",", tertiary = nil },
  v = { default = nil, primary = "n", secondary = nil, tertiary = nil },
}

-- local _ltrMapping = {} -- Not implemented yet
-- local _customMapping -- Not implemented yet

-- Internal variables
local _orientation = obj.rightToLeft
local _enabled = false
local _deck
local _keyDownTap
local _systemKeyDownTap
local _modifierPrimary = false
local _modifierSecondary = false
local _modifierTertiary = false

-- Internal function to call when a Streamdeck button has been pressed.
-- Updates local modifier state.
local function _streamdeckButton(deck, buttonId, pressed)
  if _enabled then
    -- Primary (middle, F15, 0x71, 113)
    if buttonId == 2 then _modifierPrimary = pressed
    -- Secondary (right, F16, 0x6a, 106)
    elseif buttonId == 3 then _modifierSecondary = pressed
    -- Tertiary (left, F17, 0x40, 64)
    elseif buttonId == 1 then _modifierTertiary = pressed
    end

    log.d('Button #' .. buttonId .. " - " .. (pressed and 'down' or 'up'))
  else
    if pressed then hs.alert("ℹ️ Keyboard mirroring not enabled.") end
  end
end

-- Internal function to call when a Streamdeck has been discovered
local function _streamdeckDiscovery(connected, deck)
  if connected then
    _deck = deck
    _deck:buttonCallback(_streamdeckButton)
    log.d('Streamdeck Pedal connected.')
  end
end

-- Internal function to call to convert from an eventtap event flag table to a
-- mods table for keyStroke.
local function _flagsToMods(flags)
  local mods = {}

  for k, v in pairs(flags) do
    table.insert(mods, k)
    log.d('With mod ' .. k)
  end

  return mods
end

-- Internal function called when a key is pressed when mirroring is enabled.
local function _keyDown(event)
  -- Check if this event is from the keyboard or from us. We need to ignore
  -- events from us.
  local processId = event:getProperty(hs.eventtap.event.properties.eventSourceUnixProcessID)
  if processId > 0 then
    return false
  end

  local key = hs.keycodes.map[event:getKeyCode()]
  local remap = _rtlMapping[key]

  -- If key is not remapped, just pass the event along.
  if remap == nil then
    return false
  end

  if _modifierPrimary then newKey = (remap['primary'] or remap['default'] or key)
  elseif _modifierSecondary then newKey = (remap['secondary'] or remap['default'] or key)
  elseif _modifierTertiary then newKey = (remap['tertiary'] or remap['default'] or key)
  else newKey = (remap['default'] or key)
  end

  log.d(key .. ' remapped to ' .. newKey)

  local mods = _flagsToMods(event:getFlags())
  hs.eventtap.keyStroke(mods, newKey, 1000)

  -- Do not pass event along, we've already remapped the key
  return true
end

-- Internal function called whenever a system key is pressed when mirroring is enabled.
-- Used to catch caps lock and remap to return
local function _systemKeyDown(event)
  local table = event:systemKey()
  if table.down and table.key == "CAPS_LOCK" then
    if _modifierSecondary then
      -- Do nothing, if secondary is pressed, caps lock should work as normal
    else
      -- Send return instead of caps lock
      local mods = _flagsToMods(event:getFlags())
      hs.eventtap.keyStroke(mods, 'return', 1000)
      hs.hid.capslock.toggle() -- change caps lock back, effectively "disabling" it
    end
  end
end

-- Internal function to toggle between keyboard active/inactive states,
-- triggered by keypress.
function obj:_toggle()
  if _deck == nil then
    hs.alert("⚠️ Streamdeck Pedal not connected!")
    return
  end

  _enabled = not _enabled

  if _enabled then
    _keyDownTap:start()
    _systemKeyDownTap:start()
    _deck:buttonCallback(_streamdeckButton)
  else
    _keyDownTap:stop()
    _systemKeyDownTap:stop()
  end

  hs.alert(
    (_enabled and '✅' or '❌')
    .. ' Mirror Keyboard ' ..
    (_enabled and 'enabled.' or 'disabled.')
  )
end

--- MirrorKeyboard:init()
--- Method
--- Initialize Streamdeck pedal - always safe to do, even if keyboard mirroring
--- is disabled.
function obj:init()
  hs.streamdeck.init(_streamdeckDiscovery)
  _keyDownTap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, _keyDown)
  _systemKeyDownTap = hs.eventtap.new({hs.eventtap.event.types.systemDefined}, _systemKeyDown)

  log.i('MirrorKeyboard initialized.')
end

--- MirrorKeyboard:bindToHotkeys()
--- Method
--- Binds the toggle hotkey for this spoon.
---
--- Parameters:
---  * mapping - A table containing hotkey details for the toggle functionality.
---  Defaults to:
---  {
---    toggle = {{"cmd", "alt", "ctrl"}, "m"}
---  }
---
--- Returns:
---  * The MirrorKeyboard object
function obj:bindToHotkeys(mapping)
  local spec = {
    toggle = hs.fnutils.partial(self._toggle, self),
  }

  if mapping == nil then
    mapping = {
      toggle = {{"cmd", "alt", "ctrl"}, "m"}
    }
  end

  hs.spoons.bindHotkeysToSpec(spec, mapping)

  return self
end

--- MirrorKeyboard:setOrientation()
--- Method
--- Sets the orientation to mirror the keyboard along.
---
--- Parameters:
---  * orientation - A string constant indicating the direction to mirror the
---  keyboard.
---
--- Returns:
---  * The MirrorKeyboard object
function obj:setOrientation(orientation, customMapping)
  if (orientation ~= self.rightToLeft) then
    log.e('Orientation "' .. (orientation or 'nil') .. '" is not supported.')
    return self
  end

  _orientation = orientation

  return self
end

--- MirrorKeyboard:setLogLevel()
--- Method
--- Sets the log level for this Spoon.  Default for this Spoon is info, but it
--- can print out a lot of debug information if you like.
---
--- Parameters:
---  * level - The log level to set.
---
--- Returns:
---  * The MirrorKeyboard object
function obj.setLogLevel(_, newLevel)
  log.setLogLevel(newLevel)

  return self;
end

return obj
