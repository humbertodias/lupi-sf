-- Um teclado. J K L socos, M G H chutes, WASD anda. O segundo lutador e o CPU.

local Screen = require "screen"

local function pad(name, fallback)
  local value = rawget(_G, name)
  if type(value) == "number" then return value end
  return fallback
end

local Input = {}
Input.__index = Input

Input.LEFT = pad("LEFT", 4)
Input.RIGHT = pad("RIGHT", 2)
Input.UP = pad("UP", 1)
Input.DOWN = pad("DOWN", 3)
Input.LP = pad("BTN_X", 6)
Input.MP = pad("BTN_Z", 7)
Input.HP = pad("BTN_Q", 5)
Input.LK = pad("BTN_E", 8)
Input.MK = pad("BTN_F", 9)
Input.HK = pad("BTN_G", 11)

function Input.neutral()
  return {
    dir = 5,
    up = false,
    down = false,
    fwd = false,
    back = false,
    lp = false,
    mp = false,
    hp = false,
    lk = false,
    mk = false,
    hk = false,
  }
end

function Input.new()
  return setmetatable({ down = false, edge = false }, Input)
end

function Input:held(id)
  return id ~= nil and ui.btn(id)
end

function Input:tapped(id)
  return id ~= nil and ui.btnp(id)
end

function Input:confirm()
  return self:tapped(Input.LP) or self:tapped(Input.MP) or self.edge
end

function Input:fighter(face)
  local left = self:held(Input.LEFT)
  local right = self:held(Input.RIGHT)
  local up = self:held(Input.UP)
  local down = self:held(Input.DOWN)
  if left and right then left, right = false, false end
  local fwd = (face == 1 and right) or (face ~= 1 and left)
  local back = (face == 1 and left) or (face ~= 1 and right)
  local dir = 5
  if down and back then dir = 1
  elseif down and fwd then dir = 3
  elseif down then dir = 2
  elseif up and back then dir = 7
  elseif up and fwd then dir = 9
  elseif up then dir = 8
  elseif back then dir = 4
  elseif fwd then dir = 6
  end
  return {
    dir = dir,
    up = self:tapped(Input.UP),
    down = down,
    fwd = fwd and true or false,
    back = back and true or false,
    lp = self:tapped(Input.LP),
    mp = self:tapped(Input.MP),
    hp = self:tapped(Input.HP),
    lk = self:tapped(Input.LK),
    mk = self:tapped(Input.MK),
    hk = self:tapped(Input.HK),
  }
end

function Input:read()
  self.edge = false
  if not (ui and ui.pointer) then
    self.down = false
    return
  end
  local _, _, shot = ui.pointer()
  local down = shot and true or false
  self.edge = down and not self.down
  self.down = down
  if self.x and self.x < 0 then self.x = 0 elseif self.x and self.x > Screen.W - 1 then self.x = Screen.W - 1 end
end

return Input
