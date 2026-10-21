-- Lutador. Normais, hadouken, shoryuken, tatsumaki, agarrão e bloqueio.

local Screen = require "screen"
local Stage = require "stage"
local Motion = require "motion"
local Input = require "input"

local HADOU = {
  lp = { dmg = 20, speed = 3.4, stun = 14, push = 8 },
  mp = { dmg = 28, speed = 4.4, stun = 16, push = 10 },
  hp = { dmg = 34, speed = 5.2, stun = 18, push = 12 },
}

local DP = {
  lp = { dmg = 36, hop = -5.3, stun = 16 },
  mp = { dmg = 44, hop = -6.2, stun = 18 },
  hp = { dmg = 52, hop = -7.0, stun = 20 },
}

local MOVES = {
  lp = { kind = "normal", limb = "punch", startup = 3, active = 3, recovery = 8, dmg = 12, stun = 12, push = 8, h = "high", reach = 48, y0 = 34, y1 = 52, cancel = true },
  mp = { kind = "normal", limb = "punch", startup = 6, active = 3, recovery = 12, dmg = 20, stun = 16, push = 10, h = "high", reach = 52, y0 = 32, y1 = 54 },
  hp = { kind = "normal", limb = "punch", startup = 10, active = 4, recovery = 18, dmg = 32, stun = 20, push = 14, h = "high", reach = 56, y0 = 30, y1 = 56 },
  lk = { kind = "normal", limb = "kick", startup = 4, active = 3, recovery = 8, dmg = 12, stun = 12, push = 8, h = "mid", reach = 50, y0 = 14, y1 = 34, cancel = true },
  mk = { kind = "normal", limb = "kick", startup = 7, active = 4, recovery = 13, dmg = 20, stun = 16, push = 10, h = "mid", reach = 56, y0 = 12, y1 = 36 },
  hk = { kind = "normal", limb = "kick", startup = 11, active = 4, recovery = 18, dmg = 30, stun = 20, push = 12, h = "mid", reach = 62, y0 = 16, y1 = 42 },
  clp = { kind = "normal", limb = "punch", crouch = true, startup = 3, active = 3, recovery = 7, dmg = 10, stun = 11, push = 6, h = "mid", reach = 46, y0 = 6, y1 = 24, cancel = true },
  cmp = { kind = "normal", limb = "punch", crouch = true, startup = 6, active = 3, recovery = 12, dmg = 18, stun = 15, push = 8, h = "low", reach = 50, y0 = 2, y1 = 22 },
  clk = { kind = "normal", limb = "kick", crouch = true, startup = 4, active = 3, recovery = 8, dmg = 10, stun = 11, push = 6, h = "low", reach = 48, y0 = 0, y1 = 16, cancel = true },
  cmk = { kind = "normal", limb = "kick", crouch = true, startup = 7, active = 3, recovery = 12, dmg = 18, stun = 15, push = 8, h = "low", reach = 54, y0 = 0, y1 = 18 },
  chk = { kind = "normal", limb = "kick", crouch = true, sweep = true, startup = 9, active = 4, recovery = 18, dmg = 26, stun = 8, push = 6, h = "low", reach = 64, y0 = 0, y1 = 14 },
  airp = { kind = "normal", limb = "punch", startup = 4, active = 6, recovery = 6, dmg = 14, stun = 14, push = 4, h = "mid", reach = 48, y0 = 24, y1 = 46 },
  airk = { kind = "normal", limb = "kick", startup = 5, active = 6, recovery = 6, dmg = 16, stun = 14, push = 4, h = "mid", reach = 54, y0 = 8, y1 = 30 },
  throw = { kind = "throw", limb = "punch", startup = 4, active = 2, recovery = 16, dmg = 28, stun = 1, push = 4, h = "throw", reach = 40, y0 = 0, y1 = 40 },
  hadou = { kind = "hadou", limb = "punch", startup = 8, active = 2, recovery = 16, dmg = 20, stun = 16, push = 10, h = "mid", speed = 3.4, ball = "normal", reach = 1, y0 = 0, y1 = 1 },
  dp = { kind = "dp", limb = "punch", startup = 3, active = 8, recovery = 6, dmg = 42, stun = 18, push = 8, h = "mid", reach = 40, y0 = 16, y1 = 76, launch = true, hop = -6.2 },
  tatsu = { kind = "tatsu", limb = "kick", startup = 4, active = 16, recovery = 10, dmg = 26, stun = 16, push = 10, h = "mid", reach = 34, y0 = 8, y1 = 40 },
}

local Fighter = {}
Fighter.__index = Fighter

function Fighter.new(spec)
  spec = spec or {}
  local self = setmetatable({
    id = spec.id or "RYU",
    style = spec.style or "ryu",
    side = spec.side or 1,
    cpu = spec.cpu or false,
    match = spec.match,
    face = spec.face or 1,
    hp_max = 200,
    wins = 0,
    meter = 0,
    t = 0,
    motion = Motion.new(),
  }, Fighter)
  self:reset(spec.x or 320, self.face)
  return self
end

function Fighter:reset(x, face)
  self.x = x
  self.y = Stage.GROUND
  self.vx = 0
  self.vy = 0
  self.face = face
  self.hp = self.hp_max
  self.state = "idle"
  self.airborne = false
  self.dead = false
  self.move = nil
  self.phase = nil
  self.phase_t = 0
  self.stun = 0
  self.invuln = 0
  self.flash = 0
  self.combo = 0
  self.did_hit = false
  self.air_used = false
  self.buf = nil
  self.kbuf = nil
  self.request = nil
  self.request_t = 0
  self.ai_wait = 0
  self.dash_t = 0
  self.pad = Input.neutral()
  self.motion:clear()
end

function Fighter:fx(name)
  if self.match and self.match.app and self.match.app.audio then
    self.match.app.audio:fx(name)
  end
end

function Fighter:can_turn()
  return not self.dead and not self.airborne and not self.move
    and (self.state == "idle" or self.state == "walk" or self.state == "crouch")
end

function Fighter:actionable()
  if self.dead or self.stun > 0 or self.move then return false end
  if self.airborne then return self.state == "jump" and not self.air_used end
  return self.state == "idle" or self.state == "walk" or self.state == "crouch"
    or self.state == "dash" or self.state == "land"
end

function Fighter:can_cancel()
  return self.move and self.move.cancel and self.phase == "active" and not self.airborne
end

function Fighter:begin(name, extra)
  local m = {}
  local src = MOVES[name]
  for k, v in pairs(src) do m[k] = v end
  if extra then
    for k, v in pairs(extra) do m[k] = v end
  end
  self.move = m
  self.move_name = name
  self.phase = "startup"
  self.phase_t = 0
  self.did_hit = false
  self.state = (m.kind == "normal") and "attack" or m.kind
  if m.kind == "normal" or m.kind == "hadou" or m.kind == "throw" then self.vx = 0 end
  if m.kind == "dp" then self.invuln = math.max(self.invuln, 8) end
  if m.kind == "tatsu" and self.airborne then
    self.vy = 0.3
    self.air_used = true
  end
  self.motion:clear()
  self.buf = nil
  self.kbuf = nil
end

function Fighter:end_move()
  self.move = nil
  self.phase = nil
  self.did_hit = false
  if self.airborne then
    self.state = "jump"
  else
    self.vx = 0
    self.state = self.pad.down and "crouch" or "idle"
  end
end

function Fighter:on_active()
  local m = self.move
  if m.kind == "hadou" then
    if self.match then self.match:add_ball(self) end
    self:fx("hadou")
  elseif m.kind == "dp" then
    self.airborne = true
    self.vy = m.hop or -6.2
    self.vx = self.face * 2.3
    self:fx("swing")
  elseif m.kind == "tatsu" then
    self.vx = self.face * (self.airborne and 2.6 or 3.5)
    self:fx("swing")
  else
    self:fx("swing")
  end
end

function Fighter:advance_move()
  local m = self.move
  if not m or self.phase == "fall" then return end
  local limit = m.recovery
  if self.phase == "startup" then limit = m.startup
  elseif self.phase == "active" then limit = m.active end
  self.phase_t = self.phase_t + 1
  if self.phase_t < limit then return end
  self.phase_t = 0
  if self.phase == "startup" then
    self.phase = "active"
    self:on_active()
  elseif self.phase == "active" then
    if m.kind == "dp" or (m.kind == "tatsu" and self.airborne) then
      self.phase = "fall"
    else
      if m.kind == "tatsu" then self.vx = self.vx * 0.25 end
      self.phase = "recovery"
    end
  else
    self:end_move()
  end
end

function Fighter:tick_stun()
  if self.stun <= 0 then return end
  self.stun = self.stun - 1
  if self.stun > 0 then return end
  if self.state == "down" then
    self.invuln = math.max(self.invuln, 16)
    self.state = "idle"
    self.vx = 0
  elseif self.state == "hit" or self.state == "block" or self.state == "land" then
    self.state = self.pad.down and "crouch" or "idle"
    self.vx = 0
  end
end

function Fighter:jump()
  local pad = self.pad
  self.state = "jump"
  self.airborne = true
  self.air_used = false
  self.move = nil
  self.vy = -6.35
  if pad.fwd then self.vx = self.face * 2.15
  elseif pad.back then self.vx = -self.face * 1.75
  else self.vx = 0 end
end

function Fighter:dash(sign)
  local speed = sign > 0 and 4.8 or 4.0
  self.state = "dash"
  self.vx = self.face * sign * speed
  self.dash_t = 9
  self.move = nil
  self.motion:clear()
  self:fx("dash")
  if self.match then self.match:spark(self.x - self.face * 6, self.y - 2, Screen.GI) end
end

function Fighter:fire_hadou(strength)
  if strength == "hp" and self.meter >= 80 then
    self.meter = self.meter - 80
    self:begin("hadou", { dmg = 70, speed = 5.6, ball = "shinku", stun = 22, push = 16, startup = 12 })
  else
    self:begin("hadou", HADOU[strength] or HADOU.lp)
  end
end

function Fighter:try_punch(strength)
  local act = self:actionable()
  local cancel = self:can_cancel()
  if not act and not cancel then return false end
  if not self.airborne and self.motion:dp() then
    self:begin("dp", DP[strength] or DP.mp)
    return true
  end
  if not self.airborne and self.motion:qcf() then
    self:fire_hadou(strength)
    return true
  end
  if not act then return false end
  if self.airborne then
    self.air_used = true
    self:begin("airp")
    return true
  end
  if self.pad.down then
    self:begin(strength == "lp" and "clp" or "cmp")
  else
    self:begin(strength)
  end
  return true
end

function Fighter:try_kick(strength)
  local act = self:actionable()
  local cancel = self:can_cancel()
  if not act and not cancel then return false end
  if self.motion:qcb() then
    self:begin("tatsu")
    return true
  end
  if not act then return false end
  if self.airborne then
    self.air_used = true
    self:begin("airk")
    return true
  end
  if self.pad.down then
    if strength == "hk" then self:begin("chk")
    elseif strength == "mk" then self:begin("cmk")
    else self:begin("clk") end
  else
    self:begin(strength)
  end
  return true
end

function Fighter:note_buttons()
  local pad = self.pad
  local punch = pad.hp and "hp" or pad.mp and "mp" or pad.lp and "lp"
  local kick = pad.hk and "hk" or pad.mk and "mk" or pad.lk and "lk"
  if punch then self.buf = { s = punch, t = 8 } end
  if kick then self.kbuf = { s = kick, t = 8 } end
end

function Fighter:try_commands()
  self:note_buttons()
  local punch = self.buf and self.buf.s
  local kick = self.kbuf and self.kbuf.s
  local fresh = self.buf and self.buf.t == 8 and self.kbuf and self.kbuf.t == 8
  local motion = self.motion:dp() or self.motion:qcf() or self.motion:qcb()
  if fresh and self:actionable() and not self.airborne and not motion then
    self:begin("throw")
    return
  end
  if punch and self:try_punch(punch) then return end
  if kick and self:try_kick(kick) then return end
  if self.buf then
    self.buf.t = self.buf.t - 1
    if self.buf.t <= 0 then self.buf = nil end
  end
  if self.kbuf then
    self.kbuf.t = self.kbuf.t - 1
    if self.kbuf.t <= 0 then self.kbuf = nil end
  end
end

function Fighter:take_request()
  if not self.request then return false end
  self.request_t = (self.request_t or 8) - 1
  local name, arg = self.request:match("^([^:]+):?(.*)$")
  if not name then
    self.request = nil
    return false
  end
  local special = name == "hadou" or name == "dp" or name == "tatsu"
  local grounded = not self.airborne or name == "tatsu"
  local allowed = (self:actionable() or (self:can_cancel() and special)) and grounded
  if allowed and special then
    if name == "hadou" then self:fire_hadou(arg ~= "" and arg or "lp")
    elseif name == "dp" then self:begin("dp", DP[arg] or DP.hp)
    else self:begin("tatsu") end
    self.request = nil
    return true
  end
  if name == "dash" and self:actionable() and not self.airborne then
    self:dash(1)
    self.request = nil
    return true
  end
  if name == "jump" and self:actionable() and not self.airborne then
    if arg == "fwd" then self.pad.fwd = true elseif arg == "back" then self.pad.back = true end
    self:jump()
    self.request = nil
    return true
  end
  if self.request_t <= 0 then self.request = nil end
  return false
end

function Fighter:locomotion()
  if self.move or self.airborne or self.dead or self.stun > 0 then return end
  if self.state == "ko" or self.state == "win" or self.state == "down" or self.state == "hit" or self.state == "block" then
    return
  end
  if self.state == "dash" then
    self.dash_t = (self.dash_t or 1) - 1
    if self.dash_t <= 0 then
      self.state = "idle"
      self.vx = 0
    end
    return
  end
  if self.state ~= "idle" and self.state ~= "walk" and self.state ~= "crouch" and self.state ~= "land" then
    return
  end
  local pad = self.pad
  if pad.up then
    self:jump()
    return
  end
  if self.motion:dash() and not pad.down then
    self:dash(1)
    return
  end
  if self.motion:backstep() and not pad.down then
    self:dash(-1)
    return
  end
  if pad.down then
    self.state = "crouch"
    if pad.fwd then self.vx = self.face * 0.85
    elseif pad.back then self.vx = -self.face * 0.85
    else self.vx = 0 end
    return
  end
  if pad.fwd or pad.back then
    self.state = "walk"
    self.vx = pad.fwd and self.face * 1.75 or -self.face * 1.45
    return
  end
  self.state = "idle"
  self.vx = 0
end

function Fighter:land()
  self.airborne = false
  self.y = Stage.GROUND
  self.vy = 0
  self.air_used = false
  if self.state == "win" then
    self.vx = 0
    self.move = nil
    return
  end
  if self.dead or self.state == "ko" then
    self.state = "ko"
    self.dead = true
    self.vx = 0
    self.move = nil
    self:fx("land")
    return
  end
  if self.state == "launch" or self.state == "down" then
    self.state = "down"
    self.stun = 32
    self.invuln = 10
    self.vx = 0
    self.move = nil
    self.phase = nil
    self:fx("land")
    return
  end
  self.move = nil
  self.phase = nil
  self.state = "land"
  self.stun = 4
  self.vx = 0
  self:fx("land")
end

function Fighter:physics()
  if self.state == "hit" or self.state == "block" then self.vx = self.vx * 0.72 end
  self.x = self.x + self.vx
  if not self.airborne then return end
  local glide = self.move and self.move.kind == "tatsu" and self.phase ~= "recovery" and self.phase ~= "fall"
  if not glide then self.vy = self.vy + Stage.GRAV end
  self.y = self.y + self.vy
  if self.y >= Stage.GROUND then self:land() end
end

function Fighter:update()
  self.t = self.t + 1
  if self.invuln > 0 then self.invuln = self.invuln - 1 end
  if self.flash > 0 then self.flash = self.flash - 1 end
  self.pad = self.pad or Input.neutral()
  self.motion:push(self.pad.dir or 5)
  if self.dead and not self.airborne then
    self.state = "ko"
    self.vx = 0
    self.vy = 0
    return
  end
  self:advance_move()
  self:tick_stun()
  if not self.dead then
    if not self:take_request() then self:try_commands() end
    self:locomotion()
  end
  self:physics()
end

function Fighter:try_block(move)
  if move.h == "throw" or self.airborne or self.invuln > 0 then return false end
  if self.state == "hit" or self.state == "launch" or self.state == "down" or self.state == "ko" then return false end
  if self.state == "attack" or self.state == "dash" or self.state == "dp" or self.state == "hadou"
    or self.state == "tatsu" or self.state == "throw" then
    return false
  end
  if not self.pad.back then return false end
  if move.h == "low" then return self.pad.down and true or false end
  if move.h == "high" then return not self.pad.down end
  return true
end

function Fighter:suffer(move, dir)
  self.hp = self.hp - (move.dmg or 0)
  if self.hp < 0 then self.hp = 0 end
  self.move = nil
  self.phase = nil
  self.did_hit = false
  self.flash = 4
  if move.launch or move.sweep then
    self.state = "launch"
    self.airborne = true
    self.vy = move.sweep and -2.6 or -5.1
    self.vx = dir * 2.4
    self.stun = move.stun or 16
  else
    self.state = "hit"
    self.stun = move.stun or 12
    self.vx = dir * 1.5
  end
end

function Fighter:ko(dir)
  self.hp = 0
  self.dead = true
  self.state = "ko"
  self.airborne = true
  self.vy = -4.2
  self.vx = dir * 2.4
  self.move = nil
  self.phase = nil
  self.stun = 0
end

function Fighter:hit_aabb()
  local m = self.move
  local near = self.x + self.face * 8
  local far = self.x + self.face * m.reach
  local x1, x2 = near, far
  if x1 > x2 then x1, x2 = x2, x1 end
  local y1 = self.y - m.y1
  local y2 = self.y - m.y0
  if y1 > y2 then y1, y2 = y2, y1 end
  return x1, y1, x2, y2
end

function Fighter:hurt_aabb()
  if self.state == "ko" or self.state == "down" then
    return self.x - 26, self.y - 12, self.x + 26, self.y
  end
  local h = 54
  local crouched = self.state == "crouch" or (self.move and self.move.crouch)
    or (self.pad and self.pad.down and not self.airborne and not self.move)
  if crouched then h = 30 end
  if self.airborne then h = 46 end
  return self.x - 16, self.y - h, self.x + 16, self.y
end

function Fighter:pose()
  if self.state == "ko" or self.state == "down" then return "down" end
  if self.state == "win" then return "win" end
  if self.state == "hit" or self.state == "launch" then return "hit" end
  if self.state == "block" then return self.pad.down and "crouch" or "block" end
  if self.move and (self.phase == "active" or self.phase == "startup" or self.phase == "fall") then
    local k = self.move.kind
    if k == "dp" then return "dp" end
    if k == "tatsu" then return "tatsu" end
    if k == "hadou" then return "hadou" end
    if k == "throw" then return "throw" end
    if self.phase == "active" then
      if self.move.limb == "kick" and self.move.crouch then return "sweep" end
      if self.move.limb == "kick" then return "kick" end
      if self.move.crouch then return "crouch_punch" end
      return "punch"
    end
  end
  if self.airborne then return self.vy < 0 and "rise" or "fall" end
  if self.state == "crouch" then return "crouch" end
  if self.state == "walk" or self.state == "dash" then return "walk" end
  return "idle"
end

function Fighter:box(ox, bottom, w, h, color)
  if self.flash > 0 and self.flash % 2 == 0 and (color == Screen.GI or color == Screen.KEN) then
    color = Screen.FLASH
  end
  local left = self.x + self.face * ox
  if self.face < 0 then left = left - w end
  Screen.rect(left, self.y - bottom - h, w, h, color)
end

function Fighter:draw()
  local pose = self:pose()
  local gi = self.style == "ken" and Screen.KEN or Screen.GI
  local hair = self.style == "ken" and Screen.BLONDE or Screen.HAIR
  local bob = (math.floor(self.t / 18) % 2) == 0 and 0 or 1
  local step = (math.floor(self.t / 5) % 2) == 0 and 4 or -2
  Screen.rect(self.x - 14, self.y - 3, 28, 3, Screen.SHADOW)
  if pose == "down" then
    self:box(-22, 0, 34, 10, gi)
    self:box(10, 2, 12, 11, Screen.SKIN)
    self:box(10, 11, 12, 4, hair)
    return
  end
  local crouch = pose == "crouch" or pose == "crouch_punch" or pose == "sweep"
  local leg_h = crouch and 10 or 18
  local body_y = crouch and 8 or 16
  local head_y = (crouch and 20 or 30) + bob
  if pose == "rise" or pose == "fall" then
    self:box(-8, 8, 7, 12, Screen.BOOT)
    self:box(1, 6, 7, 12, Screen.BOOT)
  elseif pose == "walk" or pose == "dash" then
    self:box(-8, 0, 6, leg_h, Screen.BOOT)
    self:box(2 + step, 0, 6, leg_h, Screen.BOOT)
  elseif pose == "kick" then
    self:box(-8, 0, 6, leg_h, Screen.BOOT)
    self:box(2, 14, 26, 6, Screen.BOOT)
  elseif pose == "sweep" then
    self:box(-8, 0, 6, 8, Screen.BOOT)
    self:box(0, 2, 30, 6, Screen.BOOT)
  else
    self:box(-7, 0, 6, leg_h, Screen.BOOT)
    self:box(1, 0, 6, leg_h, Screen.BOOT)
  end
  self:box(-8, body_y, 16, crouch and 12 or 16, gi)
  self:box(-6, body_y + 4, 12, 3, Screen.BELT)
  self:box(-6, head_y, 12, 12, Screen.SKIN)
  self:box(-7, head_y + 8, 14, 6, hair)
  if self.style == "ryu" then self:box(-7, head_y + 7, 14, 3, Screen.BAND) end
  self:box(2, head_y + 4, 2, 2, Screen.HAIR)
  if pose == "punch" or pose == "crouch_punch" or pose == "hadou" or pose == "throw" then
    local len = pose == "hadou" and 16 or 22
    self:box(6, body_y + 4, len, 6, gi)
    self:box(4 + len, body_y + 3, 6, 8, Screen.RED)
  elseif pose == "dp" or pose == "win" then
    self:box(2, head_y + 4, 6, 16, gi)
    self:box(2, head_y + 18, 6, 6, Screen.RED)
  elseif pose == "block" then
    self:box(4, body_y + 2, 8, 14, gi)
  elseif pose == "tatsu" then
    local spin = math.floor(self.t / 2) % 2
    self:box(-18, 10, 36, 8, spin == 0 and gi or Screen.RED)
  elseif pose == "hit" then
    self:box(-16, body_y + 6, 8, 6, gi)
  else
    self:box(6, body_y + 2, 6, 12, gi)
    self:box(-12, body_y + 2, 6, 12, gi)
  end
end

return Fighter
