-- Quadros empacotados por tools/pack_sprites.py. Sem os PNG, o lutador volta aos retangulos.

local Anims = require "anims"

local Sheet = { Anims = Anims }

function Sheet.sprites()
  if Sprites then return Sprites end
  local ok, mod = pcall(require, "sprites")
  if ok and type(mod) == "table" then
    Sprites = mod
    return mod
  end
  return nil
end

function Sheet.get(folder, id)
  local sprites = Sheet.sprites()
  if not sprites or not sprites.img or not id then return nil end
  local group = sprites.img[folder]
  if not group then return nil end
  return group[id]
end

function Sheet.frame_id(frames, t)
  if not frames or #frames == 0 then return nil end
  local total = 0
  for i = 1, #frames do total = total + frames[i][2] end
  if total < 1 then return frames[1][1] end
  local n = ((t or 1) - 1) % total
  local acc = 0
  for i = 1, #frames do
    acc = acc + frames[i][2]
    if n < acc then return frames[i][1] end
  end
  return frames[1][1]
end

return Sheet
