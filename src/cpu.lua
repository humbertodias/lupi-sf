-- O CPU olha a distancia e pede golpe, bloqueio ou aproximacao.

local Input = require "input"
local Stage = require "stage"

local Cpu = {}

local function hold(dir, fwd, back, down)
  return { dir = dir, fwd = fwd, back = back, down = down }
end

function Cpu.think(f, opp)
  local pad = Input.neutral()
  local dist = math.abs(opp.x - f.x)
  local roll = math.random()
  f.ai_hold = hold(5, false, false, false)
  f.ai_wait = 10
  f.request = nil

  local threat = opp.phase == "active" and dist < 96 and not opp.airborne
  if threat and roll < 0.4 then
    pad.back = true
    local low = opp.move and opp.move.h == "low"
    pad.down = low and true or false
    f.ai_hold = hold(low and 1 or 4, false, true, pad.down)
    f.ai_wait = 12
    return pad
  end

  if opp.airborne and dist < 120 and opp.y < Stage.GROUND - 28 and opp.vy > -1 and roll < 0.65 then
    f.request = "dp:hp"
    f.request_t = 8
    f.ai_wait = 18
    return pad
  end

  if dist > 190 then
    if roll < 0.5 then
      f.request = "hadou:lp"
      f.request_t = 10
    else
      pad.fwd = true
      f.ai_hold = hold(6, true, false, false)
    end
    f.ai_wait = 16
    return pad
  end

  if dist > 78 then
    if roll < 0.28 then
      pad.fwd = true
      f.ai_hold = hold(6, true, false, false)
    elseif roll < 0.5 then
      f.request = "hadou:mp"
      f.request_t = 10
    elseif roll < 0.75 then
      pad.hk = true
    else
      pad.mp = true
    end
    f.ai_wait = 12
    return pad
  end

  if roll < 0.22 then pad.lp = true
  elseif roll < 0.4 then pad.lk = true
  elseif roll < 0.55 then
    pad.down = true
    pad.hk = true
    f.ai_hold = hold(2, false, false, true)
  elseif roll < 0.7 then pad.hp = true
  elseif roll < 0.82 then
    f.request = "tatsu:mk"
    f.request_t = 8
  elseif roll < 0.92 then
    pad.lp = true
    pad.lk = true
  else
    pad.back = true
    f.ai_hold = hold(4, false, true, false)
  end
  f.ai_wait = 8
  return pad
end

function Cpu.pad(f, opp)
  if f.ai_wait and f.ai_wait > 0 then
    f.ai_wait = f.ai_wait - 1
    local h = f.ai_hold or hold(5, false, false, false)
    local pad = Input.neutral()
    pad.dir = h.dir
    pad.fwd = h.fwd
    pad.back = h.back
    pad.down = h.down
    return pad
  end
  return Cpu.think(f, opp)
end

return Cpu
