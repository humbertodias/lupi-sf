local State = require("state").State
local Screen = require "screen"

local LINES = {
  "CREDITOS",
  "",
  "SF",
  "",
  "MELHOR DE 3 ROUNDS",
  "",
  "J OU K VOLTA",
}

local Credits = setmetatable({}, { __index = State })
Credits.__index = Credits

function Credits.new(app)
  local self = setmetatable(State.new(), Credits)
  self.app = app
  self.y = Screen.H
  return self
end

function Credits:startup()
  self.y = Screen.H
end

function Credits:update()
  self.y = self.y - 0.45
  if self.y < -#LINES * 12 then self.y = Screen.H end
  if self.app.input:confirm() then self:go("menu") end
end

function Credits:draw()
  ui.cls(Screen.BLACK)
  for i = 1, #LINES do
    local y = math.floor(self.y + (i - 1) * 12)
    if y > -10 and y < Screen.H then
      Screen.print_c(LINES[i], y, Screen.WHITE)
    end
  end
end

return Credits
