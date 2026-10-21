local State = require("state").State
local Match = require "match"

local Play = setmetatable({}, { __index = State })
Play.__index = Play

function Play.new(app)
  local self = setmetatable(State.new(), Play)
  self.app = app
  return self
end

function Play:startup()
  self.match = Match.new(self.app)
  self.app.audio:fx("start")
  self.app.audio:music("fight", 8)
end

function Play:update()
  self.match:update()
  if self.match.mode == "done" and self.match.victor then
    self:go("over", { name = self.match.victor.id })
  end
end

function Play:draw()
  self.match:draw()
end

return Play
