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

local _mirrorMapping = {
  q = { primary = "p", secondary = "\\", tertiary = nil }
}

-- Internal variables
local _orientation = obj.rightToLeft
local _enabled = false
local _deck
local _tap
local _modifierPrimary = false
local _modifierSecondary = false
local _modifierTertiary = false

-- Internal function to call when a Streamdeck button has been pressed.
-- Updates local modifier state.
local function _streamdeckButton(deck, buttonId, pressed)
  -- Primary (middle, F15, 0x71, 113)
  if buttonId == 2 then _modifierPrimary = pressed
  -- Secondary (right, F16, 0x6a, 106)
  elseif buttonId == 3 then _modifierSecondary = pressed
  -- Tertiary (left, F17, 0x40, 64)
  elseif buttonId == 1 then _modifierTertiary = pressed
  end

  log.d('Button #' .. buttonId .. " - " .. (pressed and 'down' or 'up'))
end

-- Internal function to call when a Streamdeck has been discovered
local function _streamdeckDiscovery(connected, deck)
  if connected then
    _deck = deck
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
  local remap = _mirrorMapping[key]

  -- If key is not remapped, just pass the event along.
  if remap == nil then
    return false
  end

  if _modifierPrimary then newKey = remap['primary']
  elseif _modifierSecondary then newKey = remap['secondary'] or key
  elseif _modifierTertiary then newKey = remap['tertiary'] or key
  else newKey = key
  end

  log.d(key .. ' remapped to ' .. newKey)

  local mods = _flagsToMods(event:getFlags())
  hs.eventtap.keyStroke(mods, newKey, 1000)

  -- Do not pass event along, we've already remapped the key
  return true
end

-- Internal function to toggle between keyboard active/inactive states,
-- triggered by keypress.
function obj:_toggle()
  _enabled = not _enabled

  if _enabled then
    _tap:start()
    _deck:buttonCallback(_streamdeckButton)
  else _tap:stop()
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
  _tap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, _keyDown)

  log.d('MirrorKeyboard initialized.')
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
function obj:setOrientation(orientation)
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
