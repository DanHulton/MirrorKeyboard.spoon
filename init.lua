--- === MirrorKeyboard ===
---
--- Mirrors the keyboard input from one half of the keyboard to the other.
---
--- This can help when experiencing RSI or Carpal Tunnel pain in one hand.
---
--- Only right-to-left mirroring is supported at this time.

local obj={}
obj.__index = obj

-- Metadata
obj.name = "MirrorKeyboard"
obj.version = "0.1"
obj.author = "Dan Hulton <dan@danhulton.com>"
obj.homepage = "https://github.com/DanHulton/MirrorKeyboard.spoon"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- MirrorKeyboard.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log
--- level for the messages coming from the Spoon.
obj.logger = hs.logger.new('MirrorKeyboard','debug')

--- MirrorKeyboard.rightToLeft
--- Constant
--- Constant to pass to MirrorKeyboard:start(), indicating the user wants to
--- mirror the right half of the keyboard to the left half.
obj.rightToLeft = 'rtl'

-- obj.LEFT_TO_RIGHT -- Not implemented yet.

-- Internal variables
-- obj.menuBarItem = nil
-- obj.timer = nil
-- obj.menu = nil

function obj:toggle()
  self.logger.i('toggling!')
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
    toggle = hs.fnutils.partial(self.toggle, self),
  }

  hs.spoons.bindHotkeysToSpec(spec, mapping)

  return self
end

--- MirrorKeyboard:start()
--- Method
--- Mirrors the keyboard from one half of the keyboard to the other.
---
--- Parameters:
---  * orientation - A string constant indicating the direction to mirror the
---  keyboard.
---
--- Returns:
---  * The MirrorKeyboard object
function obj:start(orientation)
  if (orientation ~= self.rightToLeft) then
    self.logger.e('Orientation "' .. (orientation or 'nil') .. '" is not supported.')
    return self
  end

  self.logger.i('starting ' .. orientation .. '!')

  return self
end

--- MirrorKeyboard:stop()
--- Method
--- Stops mirroring the keyboard.
---
--- Parameters:
---  * none
---
--- Returns:
---  * The MirrorKeyboard object
function obj:stop()
  self.logger.i('stopping!')

  return self
end

return obj
