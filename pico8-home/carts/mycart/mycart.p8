pico-8 cartridge // http://www.pico-8.com
version 42
__lua__

#include version.lua

#include src/utils/Button.lua
#include src/utils/Color.lua
#include src/utils/Direction.lua
#include src/utils/Mouse.lua

#include src/TitleScreen.lua
#include src/GameScreen.lua
#include src/Controller.lua


CONTROLLER = Controller.new()


function _init()
    CONTROLLER.init()
end

function _update()
    CONTROLLER.update()
end

function _draw()
    CONTROLLER.draw()
end
