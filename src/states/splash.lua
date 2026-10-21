local State = require("state").State
local Screen = require "screen"

local Splash = setmetatable({}, { __index = State })
Splash.__index = Splash

function Splash.new(app)
  local self = setmetatable(State.new(), Splash)
  self.app = app
  self.t = 0
  return self
end

function Splash:startup()
  self.t = 0
  self.app.audio:music("menu", 8)
end

function Splash:update()
  self.t = self.t + 1
  self.app:update_decor()
  if self.t > 100 or self.app.input:confirm() then self:go("menu") end
end

function Splash:draw()
  self.app:draw_decor()
  Screen.print_c("SF", 72, Screen.WHITE)
  Screen.print_c("APERTE J", 148, Screen.GREEN)
end

return Splash
