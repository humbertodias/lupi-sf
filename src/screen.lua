-- Tela 480x270. A cor 0 do Lupi e transparente, entao o preto visivel e o indice 1.

local function bgr555(r, g, b)
  return math.floor(b / 8) * 1024 + math.floor(g / 8) * 32 + math.floor(r / 8)
end

local Screen = {
  W = 480,
  H = 270,
  BLACK = 1,
  WHITE = 2,
  RED = 3,
  DARKRED = 4,
  SKIN = 5,
  HAIR = 6,
  BLONDE = 7,
  GI = 8,
  BELT = 9,
  BOOT = 10,
  SKY = 11,
  SKY2 = 12,
  FLOOR = 13,
  FLOOR2 = 14,
  GRID = 15,
  YELLOW = 16,
  GREEN = 17,
  ORANGE = 18,
  GRAY = 19,
  METER = 20,
  SHADOW = 21,
  KEN = 22,
  BAND = 23,
  POST = 24,
  FLASH = 25,
  PAL = {
    { 0, 0, 0 },
    { 255, 255, 255 },
    { 210, 48, 40 },
    { 128, 24, 24 },
    { 240, 196, 150 },
    { 28, 22, 32 },
    { 240, 206, 72 },
    { 236, 236, 232 },
    { 32, 28, 36 },
    { 176, 48, 32 },
    { 56, 104, 176 },
    { 28, 58, 112 },
    { 92, 68, 44 },
    { 64, 46, 32 },
    { 48, 72, 104 },
    { 255, 214, 64 },
    { 64, 200, 96 },
    { 255, 140, 40 },
    { 96, 100, 112 },
    { 72, 148, 255 },
    { 20, 16, 28 },
    { 188, 36, 36 },
    { 220, 28, 36 },
    { 168, 140, 96 },
    { 255, 244, 220 },
  },
}

function Screen.apply()
  ui.palset(0, 0)
  for i = 1, #Screen.PAL do
    local c = Screen.PAL[i]
    ui.palset(i, bgr555(c[1], c[2], c[3]))
  end
end

function Screen.rect(x, y, w, h, color)
  w = math.floor(w)
  h = math.floor(h)
  if w < 1 or h < 1 or not color then return end
  local x1 = math.floor(x)
  local y1 = math.floor(y)
  ui.rectfill(x1, y1, x1 + w, y1 + h, color)
end

function Screen.print_c(text, y, color)
  ui.print(text, math.floor((Screen.W - #text * 6) / 2), math.floor(y), color)
end

return Screen
