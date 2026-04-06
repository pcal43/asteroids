local TitleScreen = {}

TitleScreen.new = function()
	local self = {
		isDone = true
	}
	setmetatable(self, { __index = TitleScreen })
	return self
end

function TitleScreen:update()
end

function TitleScreen:draw()
end

