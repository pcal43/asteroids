local TitleScreen = {}

local v = split(VERSION,".")
VERSION_STRING = v[1].."\-f.\-f"..v[2].."\-f.\-f"..v[3]

TitleScreen.new = function()
	local self = {}
	self.isDone = false
	self.blink_timer = 0
	music(0)
    setmetatable(self, { __index = TitleScreen })
	return self
end

function TitleScreen:update()
	self.blink_timer += 1
	if buttonWasPressed(BUTTON_X) then
		self.isDone = true
		music(-1, 2000)
	end
end

function TitleScreen:draw()
	cls(PEACH)
	if self.blink_timer % 30 < 20 then
		print("press ❎ to start", 30, 121, BLACK)
	end
	print(VERSION_STRING, 116, 122, DARK_GRAY)
end

