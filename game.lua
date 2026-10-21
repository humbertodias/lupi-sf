-- sf no Lupi. Este arquivo so monta o jogo; a luta mora em src/.

local Screen = require "screen"
local Input = require "input"
local Audio = require "audio"
local Stage = require "stage"
local Fighter = require "fighter"
local Machine = require("state").Machine
local Splash = require "states.splash"
local Menu = require "states.menu"
local Help = require "states.help"
local Credits = require "states.credits"
local Play = require "states.play"
local Over = require "states.over"

local App = {}
App.__index = App

function App.new()
  local self = setmetatable({
    input = Input.new(),
    audio = Audio.new(),
  }, App)
  self.ryu = Fighter.new({ id = "RYU", style = "ryu", x = Stage.P1_X, face = 1 })
  self.ken = Fighter.new({ id = "KEN", style = "ken", x = Stage.P2_X, face = -1 })
  self.audio:music("menu", 8)
  self.machine = Machine.new({
    splash = Splash.new(self),
    menu = Menu.new(self),
    help = Help.new(self),
    credits = Credits.new(self),
    play = Play.new(self),
    over = Over.new(self),
  }, "splash")
  return self
end

function App:update_decor()
  self.ryu:tick_decor()
  self.ken:tick_decor()
  self.ryu.t = self.ryu.t + 1
  self.ken.t = self.ken.t + 1
end

function App:draw_decor()
  Stage.backdrop()
  local cam = math.floor(Stage.W / 2 - Screen.W / 2)
  ui.camera(cam, 0)
  Stage.draw_world(cam)
  self.ryu:draw()
  self.ken:draw()
  ui.camera()
end

function App:update()
  Screen.apply()
  ui.camera()
  ui.clip()
  self.input:read()
  self.audio:tick()
  self.machine:update()
  self.machine:draw()
end

math.randomseed(os.time())
local app = App.new()

function update()
  app:update()
end
