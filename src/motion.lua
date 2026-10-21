-- Buffer de direcoes no numpad relativo a face. 6 e frente, 4 e tras, 2 e baixo.

local Motion = {}
Motion.__index = Motion

function Motion.new()
  return setmetatable({ hist = {}, frame = 0 }, Motion)
end

function Motion:push(d)
  self.frame = self.frame + 1
  local last = self.hist[#self.hist]
  if not last or last.d ~= d then
    self.hist[#self.hist + 1] = { d = d, f = self.frame }
    if #self.hist > 20 then table.remove(self.hist, 1) end
  end
end

function Motion:clear()
  self.hist = {}
end

function Motion:recent(window)
  local out = {}
  for i = 1, #self.hist do
    local e = self.hist[i]
    if self.frame - e.f <= window and e.d ~= 5 then
      if out[#out] ~= e.d then out[#out + 1] = e.d end
    end
  end
  return out
end

function Motion:ends_with(pattern, window)
  local r = self:recent(window)
  if #r < #pattern then return false end
  local start = #r - #pattern
  for i = 1, #pattern do
    if r[start + i] ~= pattern[i] then return false end
  end
  return true
end

function Motion:repeated(d, window)
  local n, prev = 0, nil
  for i = 1, #self.hist do
    local e = self.hist[i]
    if self.frame - e.f <= window then
      if e.d == d and prev ~= d then n = n + 1 end
      prev = e.d
    end
  end
  return n >= 2
end

function Motion:qcf()
  return self:ends_with({ 2, 3, 6 }, 18) or self:ends_with({ 2, 6 }, 18)
end

function Motion:qcb()
  return self:ends_with({ 2, 1, 4 }, 18) or self:ends_with({ 2, 4 }, 18)
end

function Motion:dp()
  return self:ends_with({ 6, 2, 3 }, 16)
    or self:ends_with({ 3, 2, 3 }, 16)
    or self:ends_with({ 6, 2, 6 }, 16)
end

local function fresh_dir(self, d)
  local last = self.hist[#self.hist]
  if not last or last.d ~= d then return false end
  if self.frame - last.f > 2 then return false end
  return self:repeated(d, 16)
end

function Motion:dash()
  return fresh_dir(self, 6)
end

function Motion:backstep()
  return fresh_dir(self, 4)
end

return Motion
