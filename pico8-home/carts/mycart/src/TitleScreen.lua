local TitleScreen = {}

local v = split(VERSION,".")
VERSION_STRING = v[1].."\-f.\-f"..v[2].."\-f.\-f"..v[3]

TitleScreen.new = function()
	local self = {}
	self.done = false
	self.blink_timer = 0

	function self.update()
		self.blink_timer += 1
		if btnp(4) or btnp(5) then
			self.done = true
		end
	end

	function self.draw()
		cls(PEACH)
		if self.blink_timer % 30 < 20 then
			print("press ❎ to start", 30, 121, BLACK)
		end
		print(VERSION_STRING, 1, 53, DARK_GRAY)
	end

	return self
end
