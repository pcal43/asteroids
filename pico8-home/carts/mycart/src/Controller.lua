
-- top-level controller, manages overall flow of the game between screens

local currentScreen = nil
local flow = nil

function _init()
	flow = cocreate(function()
		while true do
			currentScreen = TitleScreen.new()
			while not currentScreen.isDone do
				yield()
			end
			currentScreen = GameScreen.new()
			while not currentScreen.isDone do
				yield()
			end
		end
	end)	
end

function _update()
	if (currentScreen) currentScreen:update()
	assert(coresume(flow))
end
    
function _draw()
	if (currentScreen) currentScreen:draw()
end
