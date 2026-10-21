local State = require("state").State
local Screen = require "screen"

local Over = setmetatable({}, { __index = State })
Over.__index = Over

function Over.new(app)
  local self = setmetatable(State.new(), Over)
  self.app = app
  return self
end

function Over:startup(persist)
  self.persist = persist or {}
  self.app.audio:music("menu", 8)
end

function Over:update()
  self.app:update_decor()
  if self.app.input:confirm() then self:go("menu") end
end

function Over:draw()
  self.app:draw_decor()
  local name = self.persist.name or "EMPATE"
  Screen.print_c(name .. " VENCEU", 78, Screen.YELLOW)
  Screen.print_c("J OU K VOLTA", 150, Screen.WHITE)
end

return Over
