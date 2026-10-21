-- Maquina de estados. A troca acontece no mesmo frame, antes do desenho.

local State = {}
State.__index = State

function State.new()
  return setmetatable({ done = false, next = nil, persist = {} }, State)
end

function State:startup(persist)
  self.persist = persist or {}
end

function State:cleanup()
  self.done = false
  return self.persist
end

function State:update() end

function State:draw() end

function State:go(name, persist)
  self.next = name
  self.persist = persist or {}
  self.done = true
end

local Machine = {}
Machine.__index = Machine

function Machine.new(states, name)
  local self = setmetatable({ states = states, name = name }, Machine)
  self.state = states[name]
  return self
end

function Machine:update()
  self.state:update()
  if self.state.done then
    local persist = self.state:cleanup()
    self.name = self.state.next
    self.state = self.states[self.name]
    self.state:startup(persist)
  end
end

function Machine:draw()
  self.state:draw()
end

return { State = State, Machine = Machine }
