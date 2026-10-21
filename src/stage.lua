-- Sala de treino do Reencor em perspectiva.
-- O quad do chao gira -90 no X, a parede do fundo fica em Z e as laterais giram no Y.
-- Aqui isso vira a projecao da mesma sala: o grid fecha o cubo e os pes ficam no chao.

local Screen = require "screen"

local Stage = {
  W = 960,
  GROUND = 236,
  GRAV = 0.30,
  MARGIN = 52,
}

-- Reencor nasce os lutadores em -300 e 300. A celula do Ryu e 150/640.
local SPAWN = 300 * (150 / 640)
Stage.P1_X = Stage.W / 2 - SPAWN
Stage.P2_X = Stage.W / 2 + SPAWN

local CAM_H = 101
local CAM_Z = 135
local FAR_Z = -220
local NEAR_Z = 50
local STEP = 80
local ASPECT = Screen.W / Screen.H

local function project(x, y, z, eye, cam)
  local depth = CAM_Z - z
  local ndc_x = (x - eye) / (depth * ASPECT)
  local ndc_y = (y - CAM_H) / depth
  local sx = (0.5 + ndc_x * 0.5) * Screen.W + cam
  local sy = (0.5 - ndc_y * 0.5) * Screen.H
  return sx, sy
end

local function bounds(cam)
  return cam, cam + Screen.W, 0, Screen.H
end

local function fill_rect(x1, y1, x2, y2, cam, color)
  if x1 > x2 then x1, x2 = x2, x1 end
  if y1 > y2 then y1, y2 = y2, y1 end
  local left, right, top, bottom = bounds(cam)
  if x1 < left then x1 = left end
  if x2 > right then x2 = right end
  if y1 < top then y1 = top end
  if y2 > bottom then y2 = bottom end
  if x2 - x1 < 1 or y2 - y1 < 1 then return end
  ui.rectfill(math.floor(x1), math.floor(y1), math.floor(x2), math.floor(y2), color)
end

local function span(y, x0, x1, cam, color)
  y = math.floor(y + 0.5)
  if y < 0 or y >= Screen.H then return end
  fill_rect(x0, y, x1, y + 1, cam, color)
end

local function clip_line(x1, y1, x2, y2, cam, color)
  local xmin, xmax, ymin, ymax = bounds(cam)
  xmax = xmax - 1
  ymax = ymax - 1
  local function code(x, y)
    local c = 0
    if x < xmin then c = c + 1 end
    if x > xmax then c = c + 2 end
    if y < ymin then c = c + 4 end
    if y > ymax then c = c + 8 end
    return c
  end
  local c1, c2 = code(x1, y1), code(x2, y2)
  for _ = 1, 8 do
    if c1 == 0 and c2 == 0 then
      ui.line(math.floor(x1 + 0.5), math.floor(y1 + 0.5), math.floor(x2 + 0.5), math.floor(y2 + 0.5), color)
      return
    end
    if (c1 & c2) ~= 0 then return end
    local c = c1 ~= 0 and c1 or c2
    local x, y
    if (c & 8) ~= 0 and y2 ~= y1 then
      x = x1 + (x2 - x1) * (ymax - y1) / (y2 - y1)
      y = ymax
    elseif (c & 4) ~= 0 and y2 ~= y1 then
      x = x1 + (x2 - x1) * (ymin - y1) / (y2 - y1)
      y = ymin
    elseif (c & 2) ~= 0 and x2 ~= x1 then
      y = y1 + (y2 - y1) * (xmax - x1) / (x2 - x1)
      x = xmax
    elseif x2 ~= x1 then
      y = y1 + (y2 - y1) * (xmin - x1) / (x2 - x1)
      x = xmin
    else
      return
    end
    if c == c1 then
      x1, y1 = x, y
      c1 = code(x, y)
    else
      x2, y2 = x, y
      c2 = code(x, y)
    end
  end
end

local function clip_poly(poly, cam)
  local xmin, xmax, ymin, ymax = bounds(cam)
  local function clip_edge(input, inside, cross)
    if #input == 0 then return {} end
    local out = {}
    local prev = input[#input]
    local prev_in = inside(prev)
    for i = 1, #input do
      local cur = input[i]
      local cur_in = inside(cur)
      if cur_in then
        if not prev_in then out[#out + 1] = cross(prev, cur) end
        out[#out + 1] = cur
      elseif prev_in then
        out[#out + 1] = cross(prev, cur)
      end
      prev, prev_in = cur, cur_in
    end
    return out
  end
  local function cross_x(edge, a, b)
    local dx = b[1] - a[1]
    if dx == 0 then return { edge, a[2] } end
    local t = (edge - a[1]) / dx
    return { edge, a[2] + (b[2] - a[2]) * t }
  end
  local function cross_y(edge, a, b)
    local dy = b[2] - a[2]
    if dy == 0 then return { a[1], edge } end
    local t = (edge - a[2]) / dy
    return { a[1] + (b[1] - a[1]) * t, edge }
  end
  poly = clip_edge(poly, function(p) return p[1] >= xmin end, function(a, b) return cross_x(xmin, a, b) end)
  poly = clip_edge(poly, function(p) return p[1] <= xmax end, function(a, b) return cross_x(xmax, a, b) end)
  poly = clip_edge(poly, function(p) return p[2] >= ymin end, function(a, b) return cross_y(ymin, a, b) end)
  poly = clip_edge(poly, function(p) return p[2] <= ymax end, function(a, b) return cross_y(ymax, a, b) end)
  return poly
end

local function fill_poly(poly, cam, color)
  poly = clip_poly(poly, cam)
  if #poly < 3 then return end
  local ox, oy = poly[1][1], poly[1][2]
  for i = 2, #poly - 1 do
    ui.trisfill(
      math.floor(ox + 0.5), math.floor(oy + 0.5),
      math.floor(poly[i][1] + 0.5), math.floor(poly[i][2] + 0.5),
      math.floor(poly[i + 1][1] + 0.5), math.floor(poly[i + 1][2] + 0.5),
      color
    )
  end
end

function Stage.backdrop()
  ui.camera()
  ui.cls(Screen.BELT)
end

function Stage.draw_world(cam)
  cam = cam or 0
  local eye = cam + Screen.W / 2
  local wall = Screen.WHITE
  local floor = Screen.GI
  local side = Screen.FLASH
  local ink = Screen.HAIR
  local x0, x1 = 0, Stage.W

  local function at(x, y, z)
    return project(x, y, z, eye, cam)
  end

  local function top(z)
    return CAM_H + (CAM_Z - z) * 1.15
  end

  local seam_x, seam_y = at(x0, 0, FAR_Z)
  local far_r = select(1, at(x1, 0, FAR_Z))
  local _, wall_top = at(x0, top(FAR_Z), FAR_Z)
  fill_rect(seam_x, wall_top, far_r, seam_y, cam, wall)

  local y = math.ceil(seam_y)
  while y < Screen.H do
    local ndc = 2 * y / Screen.H - 1
    if ndc > 0.02 then
      local depth = CAM_H / ndc
      local z = CAM_Z - depth
      if z >= FAR_Z and z <= NEAR_Z then
        local left = (0.5 + ((x0 - eye) / (depth * ASPECT)) * 0.5) * Screen.W + cam
        local right = (0.5 + ((x1 - eye) / (depth * ASPECT)) * 0.5) * Screen.W + cam
        span(y, left, right, cam, floor)
      end
    end
    y = y + 1
  end

  local function pt(x, y, z)
    local sx, sy = at(x, y, z)
    return { sx, sy }
  end

  local function side_wall(x)
    fill_poly({
      pt(x, 0, FAR_Z),
      pt(x, 0, NEAR_Z),
      pt(x, top(NEAR_Z), NEAR_Z),
      pt(x, top(FAR_Z), FAR_Z),
    }, cam, side)
  end
  side_wall(x0)
  side_wall(x1)

  local x = x0
  while x <= x1 do
    local ax, ay = at(x, top(FAR_Z), FAR_Z)
    local bx, by = at(x, 0, FAR_Z)
    local cx, cy = at(x, 0, NEAR_Z)
    clip_line(ax, ay, bx, by, cam, ink)
    clip_line(bx, by, cx, cy, cam, ink)
    x = x + STEP
  end

  local gy = 0
  while gy <= 1200 do
    local ax, ay = at(x0, gy, FAR_Z)
    local bx, by = at(x1, gy, FAR_Z)
    if ay < Screen.H + 2 and ay > -2 then
      clip_line(ax, ay, bx, by, cam, ink)
    end
    gy = gy + STEP
  end

  local function depth_line(z)
    local ax, ay = at(x0, 0, z)
    local bx, by = at(x1, 0, z)
    clip_line(ax, ay, bx, by, cam, ink)
  end
  depth_line(FAR_Z)
  local z = 0
  while z >= FAR_Z do
    depth_line(z)
    z = z - STEP
  end
  z = STEP
  while z <= NEAR_Z do
    depth_line(z)
    z = z + STEP
  end

  local function side_grid(x)
    local hz = FAR_Z
    while hz < NEAR_Z do
      local nz = math.min(NEAR_Z, hz + STEP)
      local hy = 0
      while hy <= 1200 do
        local ax, ay = at(x, hy, hz)
        local bx, by = at(x, hy, nz)
        if ay < Screen.H + 30 and ay > -30 then
          clip_line(ax, ay, bx, by, cam, ink)
        end
        hy = hy + STEP
      end
      local ax, ay = at(x, 0, hz)
      local bx, by = at(x, top(hz), hz)
      clip_line(ax, ay, bx, by, cam, ink)
      hz = nz
    end
    local ax, ay = at(x, 0, NEAR_Z)
    local bx, by = at(x, top(NEAR_Z), NEAR_Z)
    clip_line(ax, ay, bx, by, cam, ink)
  end
  side_grid(x0)
  side_grid(x1)
end

return Stage
