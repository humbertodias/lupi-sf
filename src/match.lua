-- Partida: rounds, projetil, empurrão e camera.

local Screen = require "screen"
local Stage = require "stage"
local Fighter = require "fighter"
local Cpu = require "cpu"
local Sheet = require "sheet"
local Defs = require "defs"

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
    match = self, id = "RYU", style = "ryu", x = Stage.P1_X, side = 1, face = 1, cpu = false,
  })
  self.p2 = Fighter.new({
    match = self, id = "KEN", style = "ken", x = Stage.P2_X, side = 2, face = -1, cpu = true,
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

function Match:spark(x, y, color, kind, flip)
  self.sparks[#self.sparks + 1] = {
    x = x,
    y = y,
    color = color or Screen.ORANGE,
    kind = kind or "spark",
    i = 1,
    t = 0,
    fresh = true,
    flip = flip and true or false,
  }
end

function Match:add_ball(owner, spawn)
  spawn = spawn or { state = "Jab", x = 53, y = 55 }
  local spec = Defs.ball.states[spawn.state] or Defs.ball.states.Jab
  local frame = spec.frames[1]
  local shinku = spawn.state == "Shinku" or spawn.state == "Denjin"
  local x = owner.x + owner.face * spawn.x
  local y = owner.y - spawn.y
  self.balls[#self.balls + 1] = {
    owner = owner,
    alive = true,
    x = x,
    y = y,
    vx = owner.face * (frame.vx or 0),
    face = owner.face,
    r = shinku and 12 or 7,
    hit = frame.hit,
    dmg = frame.dmg or 0,
    stun = frame.stun or 12,
    push = frame.push or 0,
    h = frame.h or "mid",
    stop = frame.stop,
    gain = frame.gain or frame.dmg or 0,
    kx = frame.kx,
    ky = frame.ky,
    tags = frame.tags,
    bstun = frame.bstun,
    bdmg = frame.bdmg,
    launch = frame.launch,
    sweep = frame.sweep,
    ball = shinku and "shinku" or "normal",
    anim = spec.frames,
    anim_i = 1,
    anim_t = 0,
  }
  self:spark(x, y, shinku and Screen.RED or Screen.ORANGE)
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

local function overlap(a, b)
  return a[1] < b[3] and a[3] > b[1] and a[2] < b[4] and a[4] > b[2]
end

function Match:boxes_hit(atk, def)
  local hits = atk:hit_boxes()
  local hurts = def:hurt_boxes()
  for i = 1, #hits do
    for j = 1, #hurts do
      if overlap(hits[i], hurts[j]) then return true end
    end
  end
  return false
end

function Match:ball_boxes(b)
  local out = {}
  local hits = b.hit or {}
  for i = 1, #hits do
    local box = hits[i]
    local x, y, w, h = box[1], box[2], box[3], box[4]
    local left = b.x + b.face * x
    if b.face < 0 then left = left - w end
    local bottom = b.y - y
    out[#out + 1] = { left, bottom - h, left + w, bottom }
  end
  return out
end

function Match:ball_hits(b, def)
  local hits = self:ball_boxes(b)
  local hurts = def:hurt_boxes()
  for i = 1, #hits do
    for j = 1, #hurts do
      if overlap(hits[i], hurts[j]) then return true end
    end
  end
  return false
end

function Match:connect(atk, def, move, projectile)
  if def.dead or def.invuln > 0 then return end
  if not projectile then
    if atk.did_hit then return end
    local gate = move.juggle or 1
    if (def.juggle or 100) <= gate then
      atk.did_hit = true
      return
    end
    atk.did_hit = true
  end
  move.face = move.face or atk.face
  local was_air = def.airborne
  if was_air then
    def.juggle = math.max(0, (def.juggle or 100) - (move.juggle or 1))
  end
  local dir = (def.x >= atk.x) and 1 or -1
  if def:try_block(move) then
    local chip = move.bdmg or 0
    if chip > 0 and def.hp > 1 then def.hp = math.max(1, def.hp - chip) end
    def.state = "block"
    def.stun = move.bstun or move.stun or 8
    def.move = nil
    def.phase = nil
    def.vx = (move.face or dir) * (move.kx or 1.1)
    def.flash = 2
    self.hitstop = 5
    self:fx("block")
    self:spark(def.x - dir * 10, def.y - 58, Screen.WHITE)
    self:push(atk, def, math.floor((move.push or 8) * 0.6))
    return
  end
  def:suffer(move, dir)
  atk.meter = math.min(atk.meter_max or 80, atk.meter + (move.gain or move.dmg or 0))
  atk.combo = (atk.combo or 0) + 1
  self.hitstop = move.stop or ((move.dmg or 0) >= 30 and 12 or 8)
  self.shake = 8
  self:fx("hit")
  self:spark(def.x - dir * 10, def.y - 58, Screen.ORANGE)
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
          move = {
            dmg = b.dmg, stun = b.stun, push = b.push, h = b.h or "mid",
            kind = "hadou", gain = b.gain, stop = b.stop,
            kx = b.kx, ky = b.ky, tags = b.tags, bstun = b.bstun, bdmg = b.bdmg,
            launch = b.launch, sweep = b.sweep, face = b.face,
          },
        }
      end
    end
  end
  for i = 1, #pending do
    local e = pending[i]
    if e.def.invuln > 0 or e.def.dead then
      if e.ball then e.ball.alive = false end
    else
      if e.ball then
        self:spark(e.ball.x, e.ball.y, Screen.ORANGE, "burst", e.ball.vx > 0)
        e.ball.alive = false
      end
      self:connect(e.atk, e.def, e.move, e.ball ~= nil)
    end
  end
end

function Match:move_balls()
  for i = 1, #self.balls do
    local b = self.balls[i]
    if b.alive then
      b.x = b.x + b.vx
      if b.anim then
        local fr = b.anim[b.anim_i]
        b.anim_t = (b.anim_t or 0) + 1
        if fr and b.anim_t >= (fr.dur or 1) then
          b.anim_t = 0
          local nxt = b.anim_i + 1
          if fr.rep then
            local back, times = fr.rep[1], fr.rep[2]
            b.repeats = (b.repeats or 0) + 1
            if times < 0 or b.repeats <= times then
              nxt = b.anim_i - back + 1
              if nxt < 1 then nxt = 1 end
            end
          end
          if nxt <= #b.anim and nxt ~= b.anim_i then
            b.anim_i = nxt
            fr = b.anim[b.anim_i]
            if fr.vx then b.vx = b.face * fr.vx end
            if fr.hit then b.hit = fr.hit end
            if fr.dmg then b.dmg = fr.dmg end
            if fr.kx then b.kx = fr.kx end
            if fr.ky then b.ky = fr.ky end
            if fr.tags then b.tags = fr.tags end
            if fr.stun then b.stun = fr.stun end
            if fr.bstun then b.bstun = fr.bstun end
            if fr.bdmg then b.bdmg = fr.bdmg end
          end
        end
      end
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
    if s.fresh then
      s.fresh = false
      sparks[#sparks + 1] = s
    else
      local frames = Sheet.Anims[s.kind or "spark"] or Sheet.Anims.spark
      local dur = (frames and frames[s.i] and frames[s.i][2]) or 1
      s.t = (s.t or 0) + 1
      if s.t >= dur then
        s.t = 0
        s.i = (s.i or 1) + 1
      end
      if not frames or s.i <= #frames then sparks[#sparks + 1] = s end
    end
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
      if winner.begin_state then winner:begin_state("Victory", { keep = true }) end
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
  self.p1:reset(Stage.P1_X, 1)
  self.p2:reset(Stage.P2_X, -1)
end

function Match:drift(f)
  f.t = f.t + 1
  if f.flash > 0 then f.flash = f.flash - 1 end
  f:advance_anim()
  f:physics()
end

function Match:tick_effects()
  if self.hitstop > 0 then
    self.hitstop = self.hitstop - 1
    return
  end
  self:move_balls()
  self:cleanup()
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
    self:tick_effects()
    self.outro_t = self.outro_t - 1
    if self.outro_t <= 0 then self:after_outro() end
    return
  end
  if self.mode == "done" then
    self:tick_effects()
    return
  end
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
    local cap = f.meter_max or 80
    local mw = math.floor(160 * f.meter / cap)
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
  local cam = math.floor(self:camera())
  ui.camera(cam, 0)
  Stage.draw_world(cam)
  local first, second = self.p1, self.p2
  if first.x > second.x then first, second = second, first end
  first:draw()
  second:draw()
  for i = 1, #self.balls do
    local b = self.balls[i]
    if b.alive then
      local fr = b.anim and b.anim[b.anim_i or 1]
      local spr = fr and fr.image and Sheet.get("fireballs", fr.image)
      if not spr then
        local frames = b.ball == "shinku" and Sheet.Anims.shinku or Sheet.Anims.fire
        spr = Sheet.get("fireballs", Sheet.frame_id(frames, self.frame))
      end
      if spr then
        ui.spr(spr, math.floor(b.x - spr.width / 2), math.floor(b.y - spr.height / 2), b.vx > 0)
      else
        local col = b.ball == "shinku" and Screen.RED or Screen.ORANGE
        ui.circfill(math.floor(b.x), math.floor(b.y), b.r, col)
        ui.circfill(math.floor(b.x), math.floor(b.y), math.max(2, b.r - 4), Screen.YELLOW)
      end
    end
  end
  for i = 1, #self.sparks do
    local s = self.sparks[i]
    local frames = Sheet.Anims[s.kind or "spark"] or Sheet.Anims.spark
    local fr = frames and frames[s.i or 1]
    local folder = s.kind == "burst" and "fireballs" or "hitsparks"
    local spr = fr and Sheet.get(folder, fr[1])
    if spr then
      ui.spr(spr, math.floor(s.x - spr.width / 2), math.floor(s.y - spr.height / 2), s.flip)
    else
      Screen.rect(s.x - 8, s.y - 3, 16, 6, s.color)
    end
  end
  ui.camera()
  self:draw_bars()
  self:draw_history(self.p1, false)
  self:draw_history(self.p2, true)
  self:draw_banner()
end

function Match:draw_history(f, from_right)
  local rows = f.history
  if not rows then return end
  local step = 17
  local y0 = 48
  for i = 1, #rows do
    local row = rows[i]
    local y = y0 + (i - 1) * step
    for j = 1, #row do
      local spr = Sheet.get("inputs", row[j])
      local x = from_right and (Screen.W - 4 - j * step) or (4 + (j - 1) * step)
      if spr then
        ui.spr(spr, x, y, false)
      end
    end
  end
end

return Match
