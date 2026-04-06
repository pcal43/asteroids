-- compatibility stub: title rendering now lives in GameScreen attract mode

TitleScreen = {}

local v = split(VERSION, ".")
VERSION_STRING = v[1].."\-f.\-f"..v[2].."\-f.\-f"..v[3]

function TitleScreen.new()
	local self = { isDone = true }
	setmetatable(self, { __index = TitleScreen })
	return self
end

function TitleScreen:update()
end

function TitleScreen:draw()
end
