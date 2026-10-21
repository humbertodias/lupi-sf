-- Dojo de treino. O chao fica numa faixa mais larga que a tela.

local Screen = require "screen"

local Stage = {
  W = 960,
  GROUND = 236,
  GRAV = 0.30,
  MARGIN = 52,
}

function Stage.backdrop()
  ui.camera()
  ui.cls(Screen.SKY2)
  Screen.rect(0, 0, Screen.W, 156, Screen.SKY)
end

function Stage.draw_world()
  Screen.rect(0, Stage.GROUND, Stage.W, 80, Screen.FLOOR)
  Screen.rect(0, Stage.GROUND, Stage.W, 4, Screen.FLOOR2)
  for x = 0, Stage.W, 48 do
    ui.line(x, Stage.GROUND - 78, x, Stage.GROUND, Screen.GRID)
  end
  ui.line(0, Stage.GROUND - 40, Stage.W, Stage.GROUND - 40, Screen.GRID)
  Screen.rect(64, Stage.GROUND - 118, 16, 118, Screen.POST)
  Screen.rect(Stage.W - 80, Stage.GROUND - 118, 16, 118, Screen.POST)
  Screen.rect(60, Stage.GROUND - 128, 24, 12, Screen.YELLOW)
  Screen.rect(Stage.W - 84, Stage.GROUND - 128, 24, 12, Screen.RED)
end

return Stage
