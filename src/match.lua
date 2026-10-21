-- Partida: rounds, projetil, empurrão e camera.

local Screen = require "screen"
local Stage = require "stage"
local Fighter = require "fighter"
local Cpu = require "cpu"

local GAP = 30
local ROUND_TIME = 60 * 60

local Match = {}
Match.__index = Match

function Match.new(app)
  local self = setmetatable({
    app = app,
    mode = "intro",
    intro_t = 70,
    outro_t = 0,
    time = ROUND_TIME,
    round = 1,
    frame = 0,
    balls = {},
    sparks = {},
    hitstop = 0,
    shake = 0,
    cam = 0,
    round_winner = nil,
    victor = nil,
  }, Match)
  self.p1 = Fighter.new({
    match = self, id = "RYU", style = "ryu", x = 300, side = 1, face = 1, cpu = false,
  })
  self.p2 = Fighter.new({
    match = self, id = "KEN", style = "ken", x = 660, side = 2, face = -1, cpu = true,
  })
  return self
end

function Match:other(f)
  if f == self.p1 then return self.p2 end
  return self.p1
end

function Match:fx(name)
  if self.app and self.app.audio then self.app.audio:fx(name) end
end

function Match:read(f)
  if f.feed then return f.feed(self, f) end
  if f.cpu then return Cpu.pad(f, self:other(f)) end
  return self.app.input:fighter(f.face)
end

function Match:spark(x, y, color)
  self.sparks[#self.sparks + 1] = { x = x, y = y, t = 8, color = color or Screen.ORANGE }
end

function Match:live_ball(owner)
  for i = 1, #self.balls do
    local b = self.balls[i]
    if b.alive and b.owner == owner then return true end
  end
  return false
end

function Match:add_ball(owner)
  if self:live_ball(owner) then return end
  local m = owner.move
  local shinku = m.ball == "shinku"
  self.balls[#self.balls + 1] = {
    owner = owner,
    alive = true,
    x = owner.x + owner.face * 30,
    y = owner.y - 32,
    vx = owner.face * (m.speed or 3),
    r = shinku and 12 or 7,
    dmg = m.dmg,
    stun = m.stun or 16,
    push = m.push or 10,
    ball = m.ball or "normal",
  }
  self:spark(owner.x + owner.face * 24, owner.y - 32, shinku and Screen.RED or Screen.ORANGE)
end

function Match:turn()
  local function face(a, b)
    if not a:can_turn() then return end
    if a.x < b.x then a.face = 1 elseif a.x > b.x then a.face = -1 end
  end
  face(self.p1, self.p2)
  face(self.p2, self.p1)
end

function Match:separate()
  local a, b = self.p1, self.p2
  if a.airborne or b.airborne or a.dead or b.dead then return end
  if math.abs(b.x - a.x) >= GAP then return end
  local left, right = a, b
  if a.x > b.x then left, right = b, a end
  local mid = (left.x + right.x) / 2
  left.x = mid - GAP / 2
  right.x = mid + GAP / 2
  if left.x < Stage.MARGIN then
    left.x = Stage.MARGIN
    right.x = Stage.MARGIN + GAP
  end
  if right.x > Stage.W - Stage.MARGIN then
    right.x = Stage.W - Stage.MARGIN
    left.x = right.x - GAP
  end
end

function Match:bounds()
  local function clamp(f)
    if f.x < Stage.MARGIN then f.x = Stage.MARGIN end
    if f.x > Stage.W - Stage.MARGIN then f.x = Stage.W - Stage.MARGIN end
  end
  clamp(self.p1)
  clamp(self.p2)
end

function Match:push(atk, def, amount)
  amount = amount or 0
  if amount <= 0 then return end
  local dir = (def.x >= atk.x) and 1 or -1
  def.x = def.x + dir * amount
  atk.x = atk.x - dir * amount * 0.45
end

function Match:boxes_hit(atk, def)
  local x1, y1, x2, y2 = atk:hit_aabb()
  local u1, v1, u2, v2 = def:hurt_aabb()
  return x1 < u2 and x2 > u1 and y1 < v2 and y2 > v1
end

function Match:ball_hits(b, def)
  local u1, v1, u2, v2 = def:hurt_aabb()
  local r = b.r
  return (b.x - r) < u2 and (b.x + r) > u1 and (b.y - r) < v2 and (b.y + r) > v1
end

function Match:connect(atk, def, move, projectile)
  if def.dead or def.invuln > 0 then return end
  if not projectile then
    if atk.did_hit then return end
    atk.did_hit = true
  end
  local dir = (def.x >= atk.x) and 1 or -1
  if def:try_block(move) then
    if def.hp > 1 then def.hp = def.hp - 1 end
    def.state = "block"
    def.stun = math.max(6, math.floor((move.stun or 10) * 0.5))
    def.move = nil
    def.phase = nil
    def.vx = dir * 1.1
    def.flash = 2
    self.hitstop = 5
    self:fx("block")
    self:spark(def.x - dir * 8, def.y - 28, Screen.WHITE)
    self:push(atk, def, math.floor((move.push or 8) * 0.6))
    return
  end
  def:suffer(move, dir)
  atk.meter = math.min(80, atk.meter + (move.dmg or 0))
  atk.combo = (atk.combo or 0) + 1
  self.hitstop = (move.dmg or 0) >= 60 and 12 or 8
  self.shake = 8
  self:fx("hit")
  self:spark(def.x - dir * 8, def.y - 32, Screen.ORANGE)
  self:push(atk, def, move.push or 8)
  if def.hp <= 0 then
    def:ko(dir)
    self:fx("ko")
  end
end

function Match:melee(atk, def, pending)
  local m = atk.move
  if not m or atk.phase ~= "active" or atk.did_hit then return end
  if m.kind == "hadou" then return end
  if m.kind == "throw" then
    if math.abs(atk.x - def.x) <= 44 and not def.airborne and def.invuln <= 0 and not def.dead then
      pending[#pending + 1] = { atk = atk, def = def, move = m }
    end
    return
  end
  if self:boxes_hit(atk, def) then
    pending[#pending + 1] = { atk = atk, def = def, move = m }
  end
end

function Match:clashes()
  for i = 1, #self.balls do
    local a = self.balls[i]
    if a.alive then
      for j = i + 1, #self.balls do
        local b = self.balls[j]
        if b.alive and a.owner ~= b.owner and math.abs(a.x - b.x) < (a.r + b.r) then
          if a.ball == "shinku" and b.ball ~= "shinku" then b.alive = false
          elseif b.ball == "shinku" and a.ball ~= "shinku" then a.alive = false
          else a.alive, b.alive = false, false end
          self:spark((a.x + b.x) / 2, a.y, Screen.YELLOW)
        end
      end
    end
  end
end

function Match:collisions()
  self:clashes()
  local pending = {}
  self:melee(self.p1, self.p2, pending)
  self:melee(self.p2, self.p1, pending)
  for i = 1, #self.balls do
    local b = self.balls[i]
    if b.alive then
      local def = (b.owner == self.p1) and self.p2 or self.p1
      if self:ball_hits(b, def) then
        pending[#pending + 1] = {
          atk = b.owner,
          def = def,
          ball = b,
          move = { dmg = b.dmg, stun = b.stun, push = b.push, h = "mid", kind = "hadou" },
        }
      end
    end
  end
  for i = 1, #pending do
    local e = pending[i]
    if e.def.invuln > 0 then
      if e.ball then e.ball.alive = false end
    elseif not e.def.dead then
      if e.ball then e.ball.alive = false end
      self:connect(e.atk, e.def, e.move, e.ball ~= nil)
    end
  end
end

function Match:move_balls()
  for i = 1, #self.balls do
    local b = self.balls[i]
    if b.alive then
      b.x = b.x + b.vx
      if b.x < -40 or b.x > Stage.W + 40 then b.alive = false end
    end
  end
end

function Match:cleanup()
  local balls, sparks = {}, {}
  for i = 1, #self.balls do
    if self.balls[i].alive then balls[#balls + 1] = self.balls[i] end
  end
  for i = 1, #self.sparks do
    local s = self.sparks[i]
    s.t = s.t - 1
    if s.t > 0 then sparks[#sparks + 1] = s end
  end
  self.balls = balls
  self.sparks = sparks
end

function Match:relax_combo()
  for _, def in ipairs({ self.p1, self.p2 }) do
    local resting = (def.state == "idle" or def.state == "walk" or def.state == "crouch" or def.state == "dash")
      and def.stun <= 0 and not def.airborne
    if resting then self:other(def).combo = 0 end
  end
end

function Match:finish_round()
  if self.mode ~= "fight" then return end
  self.mode = "outro"
  self.outro_t = 110
  local winner
  if self.p1.dead and not self.p2.dead then winner = self.p2
  elseif self.p2.dead and not self.p1.dead then winner = self.p1
  elseif self.p1.hp > self.p2.hp then winner = self.p1
  elseif self.p2.hp > self.p1.hp then winner = self.p2
  end
  self.round_winner = winner
  if winner then
    winner.wins = winner.wins + 1
    if not winner.dead then
      winner.state = "win"
      winner.move = nil
      winner.phase = nil
      winner.vx = 0
    end
  end
  if not self.p1.dead and not self.p2.dead then self:fx("ko") end
end

function Match:after_outro()
  local winner = self.round_winner
  if winner and winner.wins >= 2 then
    self.mode = "done"
    self.victor = winner
    return
  end
  self.round = self.round + 1
  self.time = ROUND_TIME
  self.mode = "intro"
  self.intro_t = 70
  self.balls = {}
  self.sparks = {}
  self.hitstop = 0
  self.shake = 0
  self.p1:reset(300, 1)
  self.p2:reset(660, -1)
end

function Match:drift(f)
  f.t = f.t + 1
  if f.flash > 0 then f.flash = f.flash - 1 end
  if f.airborne then f:physics() end
end

function Match:fight()
  if self.shake > 0 then self.shake = self.shake - 1 end
  if self.hitstop > 0 then
    self.hitstop = self.hitstop - 1
    return
  end
  self.frame = self.frame + 1
  if self.time > 0 then self.time = self.time - 1 end
  self:turn()
  self.p1.pad = self:read(self.p1)
  self.p2.pad = self:read(self.p2)
  self.p1:update()
  self.p2:update()
  self:separate()
  self:bounds()
  self:move_balls()
  self:collisions()
  self:separate()
  self:bounds()
  self:cleanup()
  self:relax_combo()
  if self.p1.dead or self.p2.dead or self.time <= 0 then self:finish_round() end
end

function Match:update()
  if self.mode == "intro" then
    self.intro_t = self.intro_t - 1
    self.p1.t = self.p1.t + 1
    self.p2.t = self.p2.t + 1
    if self.intro_t <= 0 then
      self.mode = "fight"
      self:fx("start")
    end
    return
  end
  if self.mode == "outro" then
    self:drift(self.p1)
    self:drift(self.p2)
    self:bounds()
    self.outro_t = self.outro_t - 1
    if self.outro_t <= 0 then self:after_outro() end
    return
  end
  if self.mode == "done" then return end
  self:fight()
end

function Match:camera()
  local mid = (self.p1.x + self.p2.x) / 2
  local cam = mid - Screen.W / 2
  if cam < 0 then cam = 0 end
  local max_cam = Stage.W - Screen.W
  if cam > max_cam then cam = max_cam end
  local sx = 0
  if self.shake > 0 then sx = (self.shake % 2 == 0) and 2 or -2 end
  self.cam = cam
  return cam + sx
end

function Match:draw_bars()
  local function bar(x, f, from_right)
    Screen.rect(x, 16, 160, 8, Screen.GRAY)
    local w = math.floor(160 * math.max(0, f.hp) / f.hp_max)
    local col = (f.hp / f.hp_max) < 0.3 and Screen.YELLOW or Screen.RED
    if w > 0 then
      local bx = from_right and (x + 160 - w) or x
      Screen.rect(bx, 16, w, 8, col)
    end
    Screen.rect(x, 26, 160, 3, Screen.BELT)
    local mw = math.floor(160 * f.meter / 80)
    if mw > 0 then
      local mx = from_right and (x + 160 - mw) or x
      Screen.rect(mx, 26, mw, 3, f.meter >= 80 and Screen.YELLOW or Screen.METER)
    end
    for i = 1, 2 do
      local px = from_right and (x + 160 - i * 10) or (x + (i - 1) * 10)
      Screen.rect(px, 32, 7, 7, f.wins >= i and Screen.YELLOW or Screen.GRAY)
    end
  end
  ui.print(self.p1.id, 16, 4, Screen.WHITE)
  local name = self.p2.id
  ui.print(name, Screen.W - 16 - #name * 6, 4, Screen.YELLOW)
  bar(16, self.p1, false)
  bar(Screen.W - 176, self.p2, true)
  local secs = math.max(0, math.ceil(self.time / 60))
  local label = string.format("%02d", secs)
  ui.print(label, math.floor((Screen.W - #label * 6) / 2), 6, Screen.WHITE)
end

function Match:draw_banner()
  if self.mode == "intro" then
    if self.intro_t > 30 then
      Screen.print_c("ROUND " .. tostring(self.round), 108, Screen.WHITE)
    else
      Screen.print_c("LUTA", 108, Screen.YELLOW)
    end
  elseif self.mode == "outro" then
    local title = (self.p1.dead or self.p2.dead) and "K.O." or "TEMPO"
    Screen.print_c(title, 96, Screen.RED)
    if self.round_winner then
      Screen.print_c(self.round_winner.id, 116, Screen.YELLOW)
    else
      Screen.print_c("EMPATE", 116, Screen.WHITE)
    end
  end
  for _, def in ipairs({ self.p1, self.p2 }) do
    local atk = self:other(def)
    if atk.combo >= 2 and def.stun > 0 and def.state ~= "block" and def.state ~= "idle" then
      local text = string.format("%d HITS", atk.combo)
      ui.print(text, math.floor(def.x - self.cam - #text * 3), math.floor(def.y - 74), Screen.YELLOW)
    end
  end
end

function Match:draw()
  Stage.backdrop()
  ui.camera(math.floor(self:camera()), 0)
  Stage.draw_world()
  for i = 1, #self.sparks do
    local s = self.sparks[i]
    Screen.rect(s.x - s.t, s.y - 2, s.t * 2, 4, s.color)
  end
  local first, second = self.p1, self.p2
  if first.x > second.x then first, second = second, first end
  first:draw()
  second:draw()
  for i = 1, #self.balls do
    local b = self.balls[i]
    if b.alive then
      local col = b.ball == "shinku" and Screen.RED or Screen.ORANGE
      ui.circfill(math.floor(b.x), math.floor(b.y), b.r, col)
      ui.circfill(math.floor(b.x), math.floor(b.y), math.max(2, b.r - 4), Screen.YELLOW)
    end
  end
  ui.camera()
  self:draw_bars()
  self:draw_banner()
end

return Match
