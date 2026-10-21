local State = require("state").State
local Input = require "input"
local Screen = require "screen"

local ITEMS = { "JOGAR", "COMO JOGAR", "CREDITOS" }

local Menu = setmetatable({}, { __index = State })
Menu.__index = Menu

function Menu.new(app)
  local self = setmetatable(State.new(), Menu)
  self.app = app
  self.index = 1
  self.title_x = -80
  return self
end

function Menu:startup()
  self.index = 1
  self.app.audio:music("menu", 8)
end

function Menu:update()
  self.app:update_decor()
  local target = (Screen.W - #"SF" * 6) / 2
  if self.title_x < target then self.title_x = self.title_x + 6 end
  local input = self.app.input
  if input:tapped(Input.UP) then
    self.index = self.index - 1
    if self.index < 1 then self.index = #ITEMS end
    self.app.audio:fx("hover")
  elseif input:tapped(Input.DOWN) then
    self.index = self.index + 1
    if self.index > #ITEMS then self.index = 1 end
    self.app.audio:fx("hover")
  elseif input:confirm() then
    self.app.audio:fx("enter")
    local item = ITEMS[self.index]
    if item == "JOGAR" then self:go("play")
    elseif item == "COMO JOGAR" then self:go("help")
    else self:go("credits") end
  end
end

function Menu:draw()
  self.app:draw_decor()
  ui.print("SF", math.floor(self.title_x), 40, Screen.WHITE)
  for i = 1, #ITEMS do
    local y = 108 + (i - 1) * 18
    local label = ITEMS[i]
    local color = (i == self.index) and Screen.GREEN or Screen.WHITE
    ui.print(label, math.floor((Screen.W - #label * 6) / 2), y, color)
  end
  Screen.print_c("J OU K CONFIRMA", Screen.H - 18, Screen.WHITE)
end

return Menu
