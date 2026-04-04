local currentScreen = nil

function init()
end

function update()
		if (self.currentScreen) self.currentScreen:update()
		Coroutine.resume(self.flow)
end
    
function draw()
	if (self.currentScreen) self.currentScreen:draw()
end

