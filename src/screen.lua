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

local WANTED = {
  BLACK = 0x000000,
  WHITE = 0xFFFFFF,
  RED = 0xD23028,
  DARKRED = 0x801818,
  SKIN = 0xF0C496,
  HAIR = 0x1C1620,
  BLONDE = 0xF0CE48,
  GI = 0xECECE8,
  BELT = 0x201C24,
  BOOT = 0xB03020,
  SKY = 0x3868B0,
  SKY2 = 0x1C3A70,
  FLOOR = 0x5C442C,
  FLOOR2 = 0x402E20,
  GRID = 0x304868,
  YELLOW = 0xFFD640,
  GREEN = 0x40C860,
  ORANGE = 0xFF8C28,
  GRAY = 0x606470,
  METER = 0x4894FF,
  SHADOW = 0x14101C,
  KEN = 0xBC2424,
  BAND = 0xDC1C24,
  POST = 0xA88C60,
  FLASH = 0xFFF4DC,
}

local function rgb_of(rgb)
  return math.floor(rgb / 65536) % 256, math.floor(rgb / 256) % 256, rgb % 256
end

local function install_hex(palette)
  if palette.hex then return end
  function palette.hex(rgb)
    local r, g, b = rgb_of(rgb)
    local target = bgr555(r, g, b)
    local tr, tg, tb = target % 32, math.floor(target / 32) % 32, math.floor(target / 1024) % 32
    local limit = #palette
    if limit > 256 then limit = 256 end
    local best, best_d = 2, math.huge
    for i = 2, limit do
      local color = palette[i]
      local cr, cg, cb = color % 32, math.floor(color / 32) % 32, math.floor(color / 1024) % 32
      local dr, dg, db = cr - tr, cg - tg, cb - tb
      local d = dr * dr + dg * dg + db * db
      if d < best_d then
        best, best_d = i, d
        if d == 0 then break end
      end
    end
    return best - 1, best_d
  end
end

local function fallback_apply()
  ui.palset(0, 0)
  for i = 1, #Screen.PAL do
    local c = Screen.PAL[i]
    ui.palset(i, bgr555(c[1], c[2], c[3]))
  end
end

function Screen.apply()
  if not Palette then pcall(require, "palette") end
  if not Palette then
    fallback_apply()
    return
  end
  install_hex(Palette)
  local limit = #Palette
  if limit > 256 then limit = 256 end
  for i = 1, limit do
    ui.palset(i - 1, Palette[i])
  end
  -- Indices dos sprites ficam intactos. Cor de HUD que nao existe na paleta entra depois.
  local used = limit
  for name, rgb in pairs(WANTED) do
    local idx, dist = Palette.hex(rgb)
    if dist > 48 and used < 256 then
      local r, g, b = rgb_of(rgb)
      ui.palset(used, bgr555(r, g, b))
      idx = used
      used = used + 1
    end
    Screen[name] = idx
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
