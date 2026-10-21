-- Lutador. Os golpes, frames, caixas e velocidades vem de src/defs.lua,
-- gerado dos JSON em Assets/objects/SF3.

local Screen = require "screen"
local Stage = require "stage"
local Motion = require "motion"
local Input = require "input"
local Sheet = require "sheet"
local Defs = require "defs"

local PUNCH = { lp = "Jab", mp = "Strong", hp = "Fierce" }
local KICK = { lk = "Short", mk = "Forward", hk = "Roundhouse" }

local Fighter = {}
Fighter.__index = Fighter

local function has_token(list, token)
  if not list then return false end
  for i = 1, #list do
    if list[i] == token then return true end
  end
  return false
end

local function kind_of(name)
  name = name or ""
  if name:find("Hadouken", 1, true) then return "hadou" end
  if name:find("Shoryuken", 1, true) then return "dp" end
  if name:find("Tatsumaki", 1, true) then return "tatsu" end
  if name == "Grab" or name:find("Trow", 1, true) then return "throw" end
  if name:find("Dash", 1, true) then return "dash" end
  if name:find("Jump", 1, true) then return "jump" end
  return "normal"
end

local function slot_of(name)
  name = name or "Stand"
  if name == "Stand" or name == "Neutral Landing" or name == "Neutrallanding" then return "idle" end
  if name == "Walk Forward" or name == "Walk Backward" then return "walk" end
  if name == "Crouch" then return "crouch" end
  if name:find("Jump", 1, true) then return "jump" end
  if name:find("Dash", 1, true) then return "dash" end
  if name:find("Block", 1, true) then return "block" end
  if name:find("Hit", 1, true) or name:find("Tummble", 1, true) then return "hit" end
  if name == "Victory" then return "win" end
  if name:find("Landing", 1, true) or name == "Neutrallanding" then return "land" end
  return kind_of(name) == "normal" and "attack" or kind_of(name)
end

function Fighter.new(spec)
  spec = spec or {}
  local self = setmetatable({
    id = spec.id or "RYU",
    style = spec.style or "ryu",
    side = spec.side or 1,
    cpu = spec.cpu or false,
    match = spec.match,
    face = spec.face or 1,
    wins = 0,
    meter = 0,
    t = 0,
    motion = Motion.new(),
  }, Fighter)
  self:reset(spec.x or 320, self.face)
  return self
end

function Fighter:defs()
  return Defs[self.style]
end

function Fighter:reset(x, face)
  local defs = self:defs()
  self.x = x
  self.y = Stage.GROUND
  self.vx = 0
  self.vy = 0
  self.face = face
  self.hp_max = defs.hp
  self.meter_max = defs.meter_max
  self.hp = self.hp_max
  self.airborne = false
  self.dead = false
  self.move = nil
  self.phase = nil
  self.stun = 0
  self.invuln = 0
  self.flash = 0
  self.combo = 0
  self.did_hit = false
  self.air_used = false
  self.juggle = 100
  self.buf = nil
  self.kbuf = nil
  self.request = nil
  self.request_t = 0
  self.ai_wait = 0
  self.pad = Input.neutral()
  self.history = {}
  self.hist_dir = "5"
  self.hist_motion = {}
  self.motion:clear()
  self.jump_lock = false
  self.afx = 1
  self.afy = 1
  self.state_name = nil
  self:begin_state("Stand")
end

local HISTORY_BUTTONS = {
  { "lp", "p_b6" },
  { "mp", "p_b5" },
  { "hp", "p_b4" },
  { "lk", "p_b3" },
  { "mk", "p_b2" },
  { "hk", "p_b1" },
}

function Fighter:note_history()
  local pad = self.pad or Input.neutral()
  local dir = tostring(pad.dir or 5)
  local row = {}
  if dir ~= self.hist_dir then
    row[#row + 1] = dir
    self.hist_dir = dir
  end
  for i = 1, #HISTORY_BUTTONS do
    local key, icon = HISTORY_BUTTONS[i][1], HISTORY_BUTTONS[i][2]
    if pad[key] then row[#row + 1] = icon end
  end
  self.hist_motion = self.hist_motion or {}
  local motions = {
    { "DP", self.motion:dp() },
    { "QCF", self.motion:qcf() },
    { "QCB", self.motion:qcb() },
  }
  for i = 1, #motions do
    local name, on = motions[i][1], motions[i][2]
    if on and not self.hist_motion[name] then row[#row + 1] = name end
    self.hist_motion[name] = on and true or false
  end
  if #row == 0 then return end
  local history = self.history or {}
  history[#history + 1] = row
  while #history > 8 do table.remove(history, 1) end
  self.history = history
end

function Fighter:fx(name)
  if self.match and self.match.app and self.match.app.audio then
    self.match.app.audio:fx(name)
  end
end

function Fighter:cur_state()
  local defs = self:defs()
  if not defs or not self.state_name then return nil end
  return defs.states[self.state_name]
end

function Fighter:cur()
  local state = self:cur_state()
  if not state then return nil end
  return state.frames[self.anim_i or 1]
end

function Fighter:can_turn()
  return not self.dead and self.stun <= 0 and not self.airborne
    and (self.state == "idle" or self.state == "walk" or self.state == "crouch")
end

function Fighter:actionable()
  if self.dead or self.stun > 0 then return false end
  if self.airborne then return self.state == "jump" and not self.air_used end
  local name = self.state_name
  if name == "Stand" or name == "Walk Forward" or name == "Walk Backward" or name == "Crouch" then
    return true
  end
  return has_token(self:cur() and self:cur().cancel, "interrupt")
end

function Fighter:can_cancel()
  local frame = self:cur()
  return frame and frame.hit and has_token(frame.hcancel, "normal") and not self.airborne
end

function Fighter:begin_state(name, opts)
  opts = opts or {}
  local state = self:defs().states[name]
  if not state then return false end
  local cost = state.bar or 0
  if cost > 0 then
    if self.meter < cost then return false end
    self.meter = self.meter - cost
  end
  self.state_name = name
  self.kind = kind_of(name)
  self.state = slot_of(name)
  self.anim_i = 1
  self.anim_t = 0
  self.seen_hit = false
  self.swung = false
  self.did_hit = false
  self.ax = 0
  self.ay = 0
  self.repeats = 0
  -- No ar o golpe nao zera a velocidade: o arco do pulo continua, como no Reencor.
  if not opts.keep and not self.airborne then
    self.vx = 0
    self.vy = 0
  end
  if self.kind ~= "normal" and self.kind ~= "jump" and self.kind ~= "dash" and name ~= "Stand"
    and name ~= "Walk Forward" and name ~= "Walk Backward" and name ~= "Crouch" then
    self.motion:clear()
    self.buf = nil
    self.kbuf = nil
  end
  self:apply_frame()
  return true
end

function Fighter:apply_frame()
  local frame = self:cur()
  if not frame then
    self.move = nil
    self.phase = nil
    return
  end
  if frame.image then self.sprite = frame.image end
  if frame.go and frame.go ~= self.state_name and self:defs().states[frame.go] then
    self:begin_state(frame.go, { keep = true })
    return
  end
  if frame.ox then self.x = self.x + self.face * frame.ox end
  if frame.oy then self.y = self.y - frame.oy end
  if frame.avx then self.vx = self.vx + self.face * frame.avx end
  if frame.avy then self.vy = self.vy - frame.avy end
  if frame.ax ~= nil then self.ax = frame.ax end
  if frame.ay ~= nil then self.ay = frame.ay end
  if frame.afx then self.afx = frame.afx end
  if frame.afy then self.afy = frame.afy end
  if (frame.avy or 0) > 0 or (self:cur_state() and self:cur_state().air) then
    self.airborne = true
  end
  if frame.spawn and self.match then
    self.match:add_ball(self, frame.spawn)
    self:fx("hadou")
  end
  if frame.hit and not self.swung then
    self.swung = true
    self:fx("swing")
  end
  if frame.hit then
    self.seen_hit = true
    self.phase = "active"
    if frame.arm then self.did_hit = false end
    self.move = {
      dmg = frame.dmg or 0,
      stun = frame.stun or 8,
      push = frame.push or 0,
      h = frame.h or "mid",
      kind = self.kind,
      launch = frame.launch,
      sweep = frame.sweep,
      gain = frame.gain or frame.dmg or 0,
      stop = frame.stop,
      kx = frame.kx,
      ky = frame.ky,
      tags = frame.tags,
      bstun = frame.bstun,
      bdmg = frame.bdmg,
      juggle = frame.juggle,
    }
  elseif frame.take then
    self.phase = "active"
    self.move = { dmg = 0, stun = 1, push = 4, h = "throw", kind = "throw", gain = 0 }
  else
    self.move = nil
    self.phase = self.seen_hit and "recovery" or "startup"
  end
end

function Fighter:advance_anim()
  local state = self:cur_state()
  local frame = self:cur()
  if not state or not frame then return end
  self.anim_t = (self.anim_t or 0) + 1
  if self.anim_t < frame.dur then return end
  self.anim_t = 0
  if frame.rep then
    local back, times = frame.rep[1], frame.rep[2]
    self.repeats = (self.repeats or 0) + 1
    if times < 0 or self.repeats <= times then
      self.anim_i = self.anim_i - back + 1
      if self.anim_i < 1 then self.anim_i = 1 end
      self:apply_frame()
      return
    end
  end
  local last = #state.frames
  if self.anim_i >= last then
    if self.airborne or self.stun > 0 or state.hold or self.state == "win" or self.state == "ko" then
      self.anim_i = last
      return
    end
    if state.loop then
      self.anim_i = 1
      self:apply_frame()
      return
    end
    if not self.dead then
      self:begin_state(self.pad.down and "Crouch" or "Stand")
    end
    return
  end
  self.anim_i = self.anim_i + 1
  self:apply_frame()
end

function Fighter:tick_decor()
  if self.match then return end
  if self.state_name ~= "Stand" then self:begin_state("Stand") end
  self:advance_anim()
end

function Fighter:tick_stun()
  if self.stun <= 0 then return end
  self.stun = self.stun - 1
  if self.stun > 0 then return end
  if self.state == "ko" or self.dead or self.state == "launch" then return end
  if self.state_name and self.state_name:find("Tummble", 1, true) then return end
  self.vx = 0
  if self.state == "block" then return end
  if not self.airborne then
    self:begin_state(self.pad.down and "Crouch" or "Stand")
  end
end

function Fighter:try_punch(strength)
  if not self:actionable() and not self:can_cancel() then return false end
  local suffix = PUNCH[strength] or "Jab"
  if self.airborne then
    if self.air_used then return false end
    self.air_used = true
    return self:begin_state("Aerial " .. suffix)
  end
  if self.motion:dp() then return self:begin_state("Shoryuken " .. suffix) end
  if self.motion:qcf() then
    if strength == "hp" then
      local shinku = self:defs().states["Shinku Hadouken"]
      if shinku and self.meter >= (shinku.bar or 80) then
        return self:begin_state("Shinku Hadouken")
      end
    end
    return self:begin_state("Hadouken " .. suffix)
  end
  if self.pad.down then return self:begin_state("Crouch " .. suffix) end
  return self:begin_state("Stand " .. suffix)
end

function Fighter:try_kick(strength)
  if not self:actionable() and not self:can_cancel() then return false end
  local suffix = KICK[strength] or "Short"
  if self.airborne then
    if self.air_used then return false end
    self.air_used = true
    return self:begin_state("Aerial " .. suffix)
  end
  if self.motion:qcb() then return self:begin_state("Tatsumaki " .. suffix) end
  if self.pad.down then return self:begin_state("Crouch " .. suffix) end
  return self:begin_state("Stand " .. suffix)
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
    self:begin_state("Grab")
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
  local grounded = not self.airborne or name == "tatsu"
  local allowed = (self:actionable() or self:can_cancel()) and grounded
  if allowed and (name == "hadou" or name == "dp" or name == "tatsu") then
    if name == "hadou" then
      local suffix = PUNCH[arg] or "Jab"
      if arg == "hp" then
        local shinku = self:defs().states["Shinku Hadouken"]
        if shinku and self.meter >= (shinku.bar or 80) and self:begin_state("Shinku Hadouken") then
          self.request = nil
          return true
        end
      end
      self:begin_state("Hadouken " .. suffix)
    elseif name == "dp" then
      self:begin_state("Shoryuken " .. (PUNCH[arg] or "Fierce"))
    else
      self:begin_state("Tatsumaki " .. (KICK[arg] or "Short"))
    end
    self.request = nil
    return true
  end
  if name == "dash" and self:actionable() and not self.airborne then
    self:begin_state(arg == "back" and "Back Dash" or "Front Dash")
    self.request = nil
    return true
  end
  if name == "jump" and self:actionable() and not self.airborne then
    local jump = "Neutral Jump"
    if arg == "fwd" then jump = "Front Jump" elseif arg == "back" then jump = "Back Jump" end
    self:begin_state(jump)
    self.request = nil
    return true
  end
  if self.request_t <= 0 then self.request = nil end
  return false
end

function Fighter:jump_held()
  local pad = self.pad or {}
  local dir = pad.dir or 5
  return pad.up or dir == 7 or dir == 8 or dir == 9
end

function Fighter:locomotion()
  if self.dead or self.stun > 0 or self.state == "win" or self.state == "ko" then return end
  local name = self.state_name
  local free = name == "Stand" or name == "Walk Forward" or name == "Walk Backward"
    or name == "Crouch"
  local dashing = name == "Front Dash" or name == "Back Dash"
  if not self:jump_held() then self.jump_lock = false end
  if not free and not dashing then return end
  local pad = self.pad
  if self:jump_held() then
    if not self.jump_lock then
      local dir = pad.dir or 5
      local jump = "Neutral Jump"
      if dir == 9 or (dir ~= 7 and pad.fwd) then jump = "Front Jump"
      elseif dir == 7 or pad.back then jump = "Back Jump" end
      self:begin_state(jump)
      self.jump_lock = true
    end
    return
  end
  if dashing then return end
  if self.motion:dash() and not pad.down then
    self:begin_state("Front Dash")
    return
  end
  if self.motion:backstep() and not pad.down then
    self:begin_state("Back Dash")
    return
  end
  local want = "Stand"
  if pad.down then want = "Crouch"
  elseif pad.fwd then want = "Walk Forward"
  elseif pad.back then want = "Walk Backward"
  end
  if self.state_name ~= want then self:begin_state(want) end
end

function Fighter:land()
  self.airborne = false
  self.y = Stage.GROUND
  self.vy = 0
  self.vx = 0
  self.afx = 1
  self.afy = 1
  self.air_used = false
  self.juggle = 100
  self:fx("land")
  if self.state == "win" then
    self.vx = 0
    return
  end
  if self.dead then
    if self.state_name ~= "Defeated Tummble Landing" then
      self:begin_state("Defeated Tummble Landing", { keep = true })
    end
    self.state = "ko"
    self.stun = 0
    self.move = nil
    return
  end
  self.vx = 0
  local land = self:defs().land or {}
  local next_name = land[self.state_name]
  if not next_name and self.state_name and self.state_name:find("Tummble", 1, true) then
    next_name = "Tummble Landing"
  end
  next_name = next_name or land["*"] or "Stand"
  if not self:defs().states[next_name] then next_name = "Stand" end
  self:begin_state(next_name)
end

function Fighter:physics()
  local frame = self:cur()
  self.vx = self.vx + self.face * (self.ax or 0)
  self.vy = self.vy - (self.ay or 0)
  if not self.airborne and self.vy < 0 then self.airborne = true end
  if not self.airborne then
    if self.stun > 0 then
      self.vx = self.vx * 0.85
    else
      local fric = (frame and frame.fric) or 0.7
      if frame and frame.cvx then self.vx = self.vx + self.face * frame.cvx end
      self.vx = self.vx * fric
    end
    self.vy = 0
  end
  self.x = self.x + self.vx
  if self.airborne then
    self.y = self.y + self.vy
    self.vy = self.vy + self:defs().gravity
    self.vx = self.vx * (self.afx or 1)
    self.vy = self.vy * (self.afy or 1)
    if self.y >= Stage.GROUND and self.vy >= 0 then self:land() end
  else
    self.y = Stage.GROUND
  end
end

function Fighter:update()
  self.t = self.t + 1
  if self.invuln > 0 then self.invuln = self.invuln - 1 end
  if self.flash > 0 then self.flash = self.flash - 1 end
  self.pad = self.pad or Input.neutral()
  self.motion:push(self.pad.dir or 5)
  self:note_history()
  self:advance_anim()
  if not self.dead then
    self:tick_stun()
    if not self:take_request() then self:try_commands() end
    self:locomotion()
  end
  self:physics()
end

function Fighter:try_block(move)
  if move.h == "throw" or self.airborne or self.invuln > 0 then return false end
  if self.state == "hit" or self.state == "launch" or self.state == "ko" then return false end
  if self.state == "attack" or self.state == "dash" or self.state == "dp" or self.state == "hadou"
    or self.state == "tatsu" or self.state == "throw" then
    return false
  end
  if not self.pad.back then return false end
  if move.h == "low" and not self.pad.down then return false end
  if move.h == "high" and self.pad.down then return false end
  self:begin_state(self.pad.down and "Crouch Block" or "Stand Block")
  return true
end

function Fighter:react(move)
  local states = self:defs().states
  local function pick(name)
    if states[name] then return name end
    return "Middle Light Hit"
  end
  local tags = move.tags or {}
  local function tagged(token)
    return has_token(tags, token)
  end
  local flying = self.airborne or (move.ky or 0) > 0
  local tumble = {
    { "sidetummble", "Side Tummble Hit" },
    { "uptummble", "Up Tummble Hit" },
    { "triptummble", "Trip Tummble Hit" },
    { "upheadtummble", "Up Head Tummble Hit" },
    { "upabdomentummble", "Up Abdomen Tummble Hit" },
    { "sideabdomentummble", "Side Abdomen Tummble Hit" },
    { "uphead", "Up Head Hit" },
    { "sideabdomen", "Side Abdomen Hit" },
  }
  if flying then
    for i = 1, #tumble do
      if tagged(tumble[i][1]) then return pick(tumble[i][2]) end
    end
  end
  local heavy = tagged("heavy") or tagged("super")
  local medium = tagged("medium") or tagged("special")
  local crouch = self.state == "crouch" or (self.pad and self.pad.down)
  if crouch then
    if heavy or tagged("special") or tagged("super") then return pick("Crouch Heavy Hit") end
    if medium then return pick("Crouch Medium Hit") end
    return pick("Crouch Light Hit")
  end
  if tagged("low") then
    if medium and not heavy then return pick("Low Medium Hit") end
    return pick("Low Light Hit")
  end
  if heavy then return pick("Middle Heavy Hit") end
  if medium then return pick("Middle Medium Hit") end
  return pick("Middle Light Hit")
end

function Fighter:suffer(move, dir)
  self.hp = self.hp - (move.dmg or 0)
  if self.hp < 0 then self.hp = 0 end
  self.flash = 4
  self.did_hit = false
  local reaction = self:react(move)
  self:begin_state(reaction, { keep = true })
  self.stun = move.stun or 12
  local face = move.face or dir
  self.vx = face * (move.kx or 1.5)
  if (move.ky or 0) > 0 then
    self.airborne = true
    self.vy = -move.ky
    self.state = "launch"
  elseif reaction:find("Tummble", 1, true) or move.h == "throw" then
    self.state = "launch"
    self.airborne = true
  else
    self.state = "hit"
  end
end

function Fighter:ko(dir)
  self.hp = 0
  self.dead = true
  self.stun = 0
  self.move = nil
  self:begin_state("Side Tummble Hit", { keep = true })
  self.airborne = true
  self.vy = -4.7
  self.vx = dir * 2.4
end

function Fighter:place_box(box)
  local x, y, w, h = box[1], box[2], box[3], box[4]
  local left = self.x + self.face * x
  if self.face < 0 then left = left - w end
  local bottom = self.y - y
  return left, bottom - h, left + w, bottom
end

function Fighter:boxes_of(key)
  local frame = self:cur()
  local list = frame and frame[key]
  local out = {}
  if not list then return out end
  for i = 1, #list do
    local x1, y1, x2, y2 = self:place_box(list[i])
    out[#out + 1] = { x1, y1, x2, y2 }
  end
  return out
end

function Fighter:hit_boxes()
  local frame = self:cur()
  if frame and frame.take then return self:boxes_of("take") end
  return self:boxes_of("hit")
end

function Fighter:hurt_boxes()
  return self:boxes_of("hurt")
end

function Fighter:hit_aabb()
  local boxes = self:hit_boxes()
  if #boxes == 0 then return self.x, self.y, self.x, self.y end
  local x1, y1, x2, y2 = boxes[1][1], boxes[1][2], boxes[1][3], boxes[1][4]
  for i = 2, #boxes do
    local b = boxes[i]
    if b[1] < x1 then x1 = b[1] end
    if b[2] < y1 then y1 = b[2] end
    if b[3] > x2 then x2 = b[3] end
    if b[4] > y2 then y2 = b[4] end
  end
  return x1, y1, x2, y2
end

function Fighter:hurt_aabb()
  local boxes = self:hurt_boxes()
  if #boxes == 0 then return self.x - 16, self.y - 40, self.x + 16, self.y end
  local x1, y1, x2, y2 = boxes[1][1], boxes[1][2], boxes[1][3], boxes[1][4]
  for i = 2, #boxes do
    local b = boxes[i]
    if b[1] < x1 then x1 = b[1] end
    if b[2] < y1 then y1 = b[2] end
    if b[3] > x2 then x2 = b[3] end
    if b[4] > y2 then y2 = b[4] end
  end
  return x1, y1, x2, y2
end

function Fighter:pose()
  if self.state == "ko" or self.state == "down" then return "down" end
  if self.state == "win" then return "win" end
  if self.state == "hit" or self.state == "launch" then return "hit" end
  if self.state == "block" then return self.pad.down and "crouch" or "block" end
  if self.kind == "dp" then return "dp" end
  if self.kind == "tatsu" then return "tatsu" end
  if self.kind == "hadou" then return "hadou" end
  if self.kind == "throw" then return "throw" end
  if self.state == "crouch" then return "crouch" end
  if self.state == "walk" or self.state == "dash" then return "walk" end
  return "idle"
end

function Fighter:draw_sheet()
  local who = self:defs()
  local frame = self:cur()
  local id = (frame and frame.image) or self.sprite
  if not who or not id then return false end
  local cell = who.cell
  local spr = Sheet.get(who.folder, id)
  if spr then
    self.shown = id
  else
    spr = self.shown and Sheet.get(who.folder, self.shown)
  end
  if not spr then return false end
  local flipped = self.face > 0
  local x = self.x - (cell.w - cell.ax)
  if flipped then x = self.x - cell.ax end
  ui.spr(spr, math.floor(x), math.floor(self.y - cell.ay), flipped)
  return true
end

function Fighter:box(ox, bottom, w, h, color)
  if self.flash > 0 and self.flash % 2 == 0 and (color == Screen.GI or color == Screen.KEN) then
    color = Screen.FLASH
  end
  local left = self.x + self.face * ox
  if self.face < 0 then left = left - w end
  Screen.rect(left, self.y - bottom - h, w, h, color)
end

function Fighter:draw_body()
  local pose = self:pose()
  local gi = self.style == "ken" and Screen.KEN or Screen.GI
  local hair = self.style == "ken" and Screen.BLONDE or Screen.HAIR
  local bob = (math.floor(self.t / 18) % 2) == 0 and 0 or 1
  local step = (math.floor(self.t / 5) % 2) == 0 and 8 or -4
  if pose == "down" then
    self:box(-44, 0, 68, 20, gi)
    self:box(20, 4, 24, 22, Screen.SKIN)
    self:box(20, 22, 24, 8, hair)
    return
  end
  local crouch = pose == "crouch" or pose == "crouch_punch" or pose == "sweep"
  local leg_h = crouch and 20 or 36
  local body_y = crouch and 16 or 32
  local head_y = (crouch and 40 or 60) + bob
  if pose == "rise" or pose == "fall" then
    self:box(-16, 16, 14, 24, Screen.BOOT)
    self:box(2, 12, 14, 24, Screen.BOOT)
  elseif pose == "walk" or pose == "dash" then
    self:box(-16, 0, 12, leg_h, Screen.BOOT)
    self:box(4 + step, 0, 12, leg_h, Screen.BOOT)
  elseif pose == "kick" then
    self:box(-16, 0, 12, leg_h, Screen.BOOT)
    self:box(4, 28, 52, 12, Screen.BOOT)
  elseif pose == "sweep" then
    self:box(-16, 0, 12, 16, Screen.BOOT)
    self:box(0, 4, 60, 12, Screen.BOOT)
  else
    self:box(-14, 0, 12, leg_h, Screen.BOOT)
    self:box(2, 0, 12, leg_h, Screen.BOOT)
  end
  self:box(-16, body_y, 32, crouch and 24 or 32, gi)
  self:box(-12, body_y + 8, 24, 6, Screen.BELT)
  self:box(-12, head_y, 24, 24, Screen.SKIN)
  self:box(-14, head_y + 16, 28, 12, hair)
  if self.style == "ryu" then self:box(-14, head_y + 14, 28, 6, Screen.BAND) end
  self:box(4, head_y + 8, 4, 4, Screen.HAIR)
  if pose == "hadou" then
    -- A magia nasce em (53, 55). A luva fica nesse ponto, nao na cabeca.
    self:box(10, 48, 32, 12, gi)
    self:box(40, 48, 14, 14, Screen.RED)
  elseif pose == "punch" or pose == "crouch_punch" or pose == "throw" then
    self:box(12, body_y + 8, 44, 12, gi)
    self:box(52, body_y + 6, 12, 16, Screen.RED)
  elseif pose == "dp" or pose == "win" then
    self:box(4, head_y + 8, 12, 32, gi)
    self:box(4, head_y + 36, 12, 12, Screen.RED)
  elseif pose == "block" then
    self:box(8, body_y + 4, 16, 28, gi)
  elseif pose == "tatsu" then
    local spin = math.floor(self.t / 2) % 2
    self:box(-36, 20, 72, 16, spin == 0 and gi or Screen.RED)
  elseif pose == "hit" then
    self:box(-32, body_y + 12, 16, 12, gi)
  else
    self:box(12, body_y + 4, 12, 24, gi)
    self:box(-24, body_y + 4, 12, 24, gi)
  end
end

function Fighter:draw()
  Screen.rect(self.x - 28, self.y - 4, 56, 4, Screen.SHADOW)
  if not self:draw_sheet() then self:draw_body() end
end

return Fighter
