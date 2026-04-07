
-- top-level controller, manages overall flow of the game between screens

local currentScreen = nil

function _init()
	currentScreen = GameScreen.new()
end

function _update()
	if (currentScreen) currentScreen:update()
end
    
function _draw()
	if (currentScreen) currentScreen:draw()
end
