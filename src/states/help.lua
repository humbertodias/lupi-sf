local State = require("state").State
local Screen = require "screen"

local ROWS = {
  { "MOVER", "A D" },
  { "AGACHAR", "S" },
  { "PULAR", "W" },
  { "SOCOS", "J K L" },
  { "CHUTES", "M G H" },
  { "HADOUKEN", "BAIXO DIAG FRENTE + SOCO" },
  { "SHORYUKEN", "FRENTE BAIXO DIAG + SOCO" },
  { "TATSUMAKI", "BAIXO DIAG TRAS + CHUTE" },
  { "SUPER", "BARRA CHEIA E HADOUKEN L" },
  { "AGARRAO", "J + M PERTO" },
  { "CORRIDA", "FRENTE, FRENTE" },
  { "BLOQUEIO", "SEGURE TRAS" },
  { "GOLPE BAIXO", "AGACHE PARA DEFENDER" },
  { "RIVAL", "CPU" },
}

local Help = setmetatable({}, { __index = State })
Help.__index = Help

function Help.new(app)
  local self = setmetatable(State.new(), Help)
  self.app = app
  return self
end

function Help:update()
  if self.app.input:confirm() then self:go("menu") end
end

function Help:draw()
  ui.cls(Screen.BLACK)
  Screen.print_c("COMO JOGAR", 8, Screen.WHITE)
  for i = 1, #ROWS do
    local y = 24 + (i - 1) * 15
    ui.print(ROWS[i][1], 12, y, Screen.GREEN)
    ui.print(ROWS[i][2], 168, y, Screen.WHITE)
  end
  Screen.print_c("J OU K VOLTA", Screen.H - 12, Screen.YELLOW)
end

return Help
