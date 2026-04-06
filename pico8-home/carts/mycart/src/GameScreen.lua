GameScreen = {}

local function rand_range(a, b)
	return a + rnd(b - a)
end

local function clamp(v, lo, hi)
	return mid(lo, v, hi)
end

local function wrap_position(x, y)
	if x < 0 then
		x  = x  + SCREEN_W
	elseif x >= SCREEN_W then
		x  = x  - SCREEN_W
	end
	if y < 0 then
		y  = y  + SCREEN_H
	elseif y >= SCREEN_H then
		y  = y  - SCREEN_H
	end
	return x, y
end

local function wrapped_delta(a, b, span)
	local d = b - a
	if d > span / 2 then
		d  = d  - span
	elseif d < -span / 2 then
		d  = d  + span
	end
	return d
end

local function wrapped_distance(x1, y1, x2, y2)
	local dx = wrapped_delta(x1, x2, SCREEN_W)
	local dy = wrapped_delta(y1, y2, SCREEN_H)
	return sqrt(dx * dx + dy * dy)
end

local function draw_rotated_polygon(points, cx, cy, a, color)
	local c = cos(a)
	local s = sin(a)
	local first_x = nil
	local first_y = nil
	local prev_x = nil
	local prev_y = nil

	for i = 1, #points do
		local px = points[i][1]
		local py = points[i][2]
		local rx = px * c - py * s
		local ry = px * s + py * c
		local sx = cx + rx
		local sy = cy + ry
		if i == 1 then
			first_x = sx
			first_y = sy
		else
			line(prev_x, prev_y, sx, sy, color)
		end
		prev_x = sx
		prev_y = sy
	end
	if #points > 1 then
		line(prev_x, prev_y, first_x, first_y, color)
	end
end

Ship = {}

function Ship.new(x, y)
	local self = {
		x = x,
		y = y,
		vx = 0,
		vy = 0,
		angle = SHIP_START_ANGLE,
		radius = SHIP_COLLISION_RADIUS,
		thrusting = false,
		invuln_timer = 0,
		fire_cooldown = 0
	}
	setmetatable(self, { __index = Ship })
	return self
end

function Ship:update(dt)
	self.thrusting = false
	if btn(BUTTON_RIGHT) then
		self.angle  = self.angle  - SHIP_ROTATE_TURNS_PER_SEC * dt
	end
	if btn(BUTTON_LEFT) then
		self.angle  = self.angle  + SHIP_ROTATE_TURNS_PER_SEC * dt
	end

	local fx = cos(self.angle)
	local fy = sin(self.angle)

	if btn(BUTTON_X) then
		self.vx  = self.vx  + fx * SHIP_THRUST_ACCEL * dt
		self.vy  = self.vy  + fy * SHIP_THRUST_ACCEL * dt
		self.thrusting = true
	else
		local speed = sqrt(self.vx * self.vx + self.vy * self.vy)
		if speed > 0 then
			local new_speed = max(0, speed - SHIP_DAMP_PER_SEC * dt)
			if new_speed == 0 then
				self.vx = 0
				self.vy = 0
			else
				local k = new_speed / speed
				self.vx  = self.vx  * k
				self.vy  = self.vy  * k
			end
		end
	end

	local speed = sqrt(self.vx * self.vx + self.vy * self.vy)
	if speed > SHIP_MAX_SPEED then
		local k = SHIP_MAX_SPEED / speed
		self.vx  = self.vx  * k
		self.vy  = self.vy  * k
	end

	self.x  = self.x  + self.vx * dt
	self.y  = self.y  + self.vy * dt
	self.x, self.y = wrap_position(self.x, self.y)

	self.fire_cooldown = max(0, self.fire_cooldown - dt)
	self.invuln_timer = max(0, self.invuln_timer - dt)
end

function Ship:can_fire()
	return self.fire_cooldown <= 0
end

function Ship:fire()
	self.fire_cooldown = PLAYER_FIRE_COOLDOWN
	local fx = cos(self.angle)
	local fy = sin(self.angle)
	local nose = SHIP_TRIANGLE_ALTITUDE * 0.5
	return Bullet.new(
		self.x + fx * nose,
		self.y + fy * nose,
		fx * PLAYER_BULLET_SPEED,
		fy * PLAYER_BULLET_SPEED,
		PLAYER_BULLET_RADIUS,
		ORANGE,
		"player",
		PLAYER_BULLET_MAX_DISTANCE
	)
end

function Ship:draw()
	if self.invuln_timer > 0 and flr(self.invuln_timer * SHIP_INVULN_BLINK_HZ) % 2 == 0 then
		return
	end

	local fx = cos(self.angle)
	local fy = sin(self.angle)
	local rx = cos(self.angle + 0.25)
	local ry = sin(self.angle + 0.25)
	local altitude_half = SHIP_TRIANGLE_ALTITUDE * 0.5
	local base_half = SHIP_TRIANGLE_ALTITUDE * SHIP_NOSE_HALF_ANGLE_TAN

	local nx = self.x + fx * altitude_half
	local ny = self.y + fy * altitude_half
	local bx = self.x - fx * altitude_half
	local by = self.y - fy * altitude_half
	local lx = bx + rx * base_half
	local ly = by + ry * base_half
	local rx2 = bx - rx * base_half
	local ry2 = by - ry * base_half

	line(nx, ny, lx, ly, WHITE)
	line(nx, ny, rx2, ry2, WHITE)
	line(lx, ly, rx2, ry2, WHITE)

	if self.thrusting then
		local back_x = self.x - fx * (altitude_half + 1)
		local back_y = self.y - fy * (altitude_half + 1)
		local side = SHIP_THRUST_FLAME_SIDE
		local h = side * 0.8660254
		local tip_x = back_x - fx * h
		local tip_y = back_y - fy * h
		local b1_x = back_x + rx * (side * 0.5)
		local b1_y = back_y + ry * (side * 0.5)
		local b2_x = back_x - rx * (side * 0.5)
		local b2_y = back_y - ry * (side * 0.5)
		line(tip_x, tip_y, b1_x, b1_y, RED)
		line(tip_x, tip_y, b2_x, b2_y, RED)
		line(b1_x, b1_y, b2_x, b2_y, RED)
	end
end

Asteroid = {}

local function asteroid_radius_for_size(size)
	if size == "large" then return ASTEROID_LARGE_RADIUS end
	if size == "medium" then return ASTEROID_MEDIUM_RADIUS end
	return ASTEROID_SMALL_RADIUS
end

function Asteroid.new(size, x, y)
	local radius = asteroid_radius_for_size(size)
	local verts = flr(rand_range(ASTEROID_VERTS_MIN, ASTEROID_VERTS_MAX + 0.999))
	local points = {}
	for i = 1, verts do
		local base_a = (i - 1) / verts
		local a = base_a + rand_range(-ASTEROID_ANGLE_JITTER, ASTEROID_ANGLE_JITTER)
		local r = radius * rand_range(1 - ASTEROID_RADIUS_JITTER, 1 + ASTEROID_RADIUS_JITTER)
		add(points, { cos(a) * r, sin(a) * r })
	end

	local move_a = rnd(1)
	local speed = rand_range(ASTEROID_SPEED_MIN, ASTEROID_SPEED_MAX)
	local self = {
		x = x,
		y = y,
		vx = cos(move_a) * speed,
		vy = sin(move_a) * speed,
		angle = rnd(1),
		spin = rand_range(-ASTEROID_SPIN_TURNS_MAX, ASTEROID_SPIN_TURNS_MAX),
		radius = radius,
		size = size,
		points = points
	}
	setmetatable(self, { __index = Asteroid })
	return self
end

function Asteroid:update(dt)
	self.x  = self.x  + self.vx * dt
	self.y  = self.y  + self.vy * dt
	self.x, self.y = wrap_position(self.x, self.y)
	self.angle  = self.angle  + self.spin * dt
end

function Asteroid:draw()
	draw_rotated_polygon(self.points, self.x, self.y, self.angle, WHITE)
end

Bullet = {}

function Bullet.new(x, y, vx, vy, radius, color, owner, max_dist)
	local self = {
		x = x,
		y = y,
		vx = vx,
		vy = vy,
		radius = radius,
		color = color,
		owner = owner,
		alive = true,
		travel_left = max_dist
	}
	setmetatable(self, { __index = Bullet })
	return self
end

function Bullet:update(dt)
	if not self.alive then return end
	local dx = self.vx * dt
	local dy = self.vy * dt
	self.x  = self.x  + dx
	self.y  = self.y  + dy
	self.x, self.y = wrap_position(self.x, self.y)
	if self.travel_left then
		self.travel_left  = self.travel_left  - sqrt(dx * dx + dy * dy)
		if self.travel_left <= 0 then
			self.alive = false
		end
	end
end

function Bullet:draw()
	circfill(self.x, self.y, self.radius, self.color)
end

UFO = {}

function UFO.new(x, y, dir)
	local self = {
		x = x,
		y = y,
		dir = dir,
		vx = dir * UFO_SPEED,
		vy = 0,
		radius = UFO_COLLISION_RADIUS,
		fire_timer = rand_range(UFO_FIRE_MIN_DELAY, UFO_FIRE_MAX_DELAY),
		alive = true
	}
	setmetatable(self, { __index = UFO })
	return self
end

function UFO:update(dt)
	if not self.alive then return end
	self.x  = self.x  + self.vx * dt
	self.y  = self.y  + self.vy * dt
	self.fire_timer  = self.fire_timer  - dt
	if self.fire_timer <= 0 then
		self.fire_timer = rand_range(UFO_FIRE_MIN_DELAY, UFO_FIRE_MAX_DELAY)
		return true
	end
	return false
end

function UFO:is_offscreen()
	local half_w = UFO_WIDTH * 0.5
	if self.dir > 0 then
		return self.x - half_w > SCREEN_W
	end
	return self.x + half_w < 0
end

function UFO:draw()
	local hw = UFO_WIDTH * 0.5
	local hh = UFO_HEIGHT * 0.5
	local x1 = self.x - hw
	local x2 = self.x + hw
	local y1 = self.y - hh
	local y2 = self.y + hh
	line(x1, y1, x2, y1, GREEN)
	line(x2, y1, x2, y2, GREEN)
	line(x2, y2, x1, y2, GREEN)
	line(x1, y2, x1, y1, GREEN)
end

Explosion = {}

function Explosion.new(x, y)
	local rays = {}
	for i = 1, 3 do
		add(rays, rnd(1))
	end
	local self = {
		x = x,
		y = y,
		t = 0,
		rays = rays,
		alive = true
	}
	setmetatable(self, { __index = Explosion })
	return self
end

function Explosion:update(dt)
	self.t  = self.t  + dt
	if self.t >= EXPLOSION_DURATION then
		self.alive = false
	end
end

function Explosion:draw()
	local p = clamp(self.t / EXPLOSION_DURATION, 0, 1)
	local r = EXPLOSION_RADIUS_START + (EXPLOSION_RADIUS_END - EXPLOSION_RADIUS_START) * p
	local l = EXPLOSION_LINE_START + (EXPLOSION_LINE_END - EXPLOSION_LINE_START) * p
	circ(self.x, self.y, r, RED)
	for i = 1, #self.rays do
		local a = self.rays[i]
		local x2 = self.x + cos(a) * l
		local y2 = self.y + sin(a) * l
		line(self.x, self.y, x2, y2, RED)
	end
end

local function draw_title_letter(ch, x, y, s, c)
	local w = 4 * s
	local h = 6 * s
	local m = x + 2 * s
	local y3 = y + 3 * s
	local y6 = y + 6 * s

	if ch == "A" then
		line(x, y6, m, y, c)
		line(m, y, x + w, y6, c)
		line(x + s, y3, x + w - s, y3, c)
	elseif ch == "I" then
		line(x, y, x + w, y, c)
		line(m, y, m, y6, c)
		line(x, y6, x + w, y6, c)
	elseif ch == "S" then
		line(x, y, x + w, y, c)
		line(x, y, x, y3, c)
		line(x, y3, x + w, y3, c)
		line(x + w, y3, x + w, y6, c)
		line(x, y6, x + w, y6, c)
	elseif ch == "T" then
		line(x, y, x + w, y, c)
		line(m, y, m, y6, c)
	elseif ch == "E" then
		line(x, y, x, y6, c)
		line(x, y, x + w, y, c)
		line(x, y3, x + w - s, y3, c)
		line(x, y6, x + w, y6, c)
	elseif ch == "R" then
		line(x, y, x, y6, c)
		line(x, y, x + w - s, y, c)
		line(x + w - s, y, x + w - s, y3, c)
		line(x, y3, x + w - s, y3, c)
		line(x + w - s, y3, x + w, y6, c)
	elseif ch == "O" then
		line(x, y, x + w, y, c)
		line(x + w, y, x + w, y6, c)
		line(x + w, y6, x, y6, c)
		line(x, y6, x, y, c)
	elseif ch == "D" then
		line(x, y, x, y6, c)
		line(x, y, x + w - s, y + s, c)
		line(x + w - s, y + s, x + w - s, y6 - s, c)
		line(x + w - s, y6 - s, x, y6, c)
	end
end

local function draw_title_text(x, y, s, c)
	local label = "AISTEROIDS"
	local step = 6 * s
	for i = 1, #label do
		draw_title_letter(sub(label, i, i), x + (i - 1) * step, y, s, c)
	end
end

local function draw_life_icon(x, y)
	local angle = SHIP_START_ANGLE
	local fx = cos(angle)
	local fy = sin(angle)
	local rx = cos(angle + 0.25)
	local ry = sin(angle + 0.25)
	local alt = SHIP_TRIANGLE_ALTITUDE * 0.5
	local base_half = SHIP_TRIANGLE_ALTITUDE * SHIP_NOSE_HALF_ANGLE_TAN
	local scale = 0.45

	alt  = alt  * scale
	base_half  = base_half  * scale

	local nx = x + fx * alt
	local ny = y + fy * alt
	local bx = x - fx * alt
	local by = y - fy * alt
	local lx = bx + rx * base_half
	local ly = by + ry * base_half
	local rx2 = bx - rx * base_half
	local ry2 = by - ry * base_half

	line(nx, ny, lx, ly, WHITE)
	line(nx, ny, rx2, ry2, WHITE)
	line(lx, ly, rx2, ry2, WHITE)
end

function GameScreen.new()
	local self = {
		isDone = false,
		state = "attract",
		flash_timer = 0,
		ship = nil,
		bullets = {},
		enemy_bullets = {},
		asteroids = {},
		ufos = {},
		explosions = {},
		wave_index = 1,
		wave_start_asteroid_count = 0,
		wave_clear_timer = -1,
		score = 0,
		lives = INITIAL_LIVES,
		next_extra_life_score = EXTRA_LIFE_SCORE_STEP,
		respawn_timer = -1,
		game_over = false,
		ufo_spawn_timer = rand_range(UFO_SPAWN_MIN_DELAY, UFO_SPAWN_MAX_DELAY),
		ufo_spawn_pending = false,
		ufo_loop_on = false,
		cadence_timer = 0,
		cadence_flip = false,
		thrust_sound_on = false
	}
	setmetatable(self, { __index = GameScreen })
	self:spawn_wave(true)
	return self
end

function GameScreen:get_wave_large_count()
	return min(MAX_WAVE_ASTEROIDS, INITIAL_WAVE_ASTEROIDS + self.wave_index - 1)
end

function GameScreen:spawn_wave(is_initial)
	self.asteroids = {}
	local count = self:get_wave_large_count()
	for i = 1, count do
		local ax = rnd(SCREEN_W)
		local ay = rnd(SCREEN_H)
		local attempts = 0
		while attempts < 200 do
			local safe_from_center = wrapped_distance(ax, ay, SHIP_START_X, SHIP_START_Y) >= INITIAL_CENTER_SAFE_DISTANCE
			local safe_from_ship = true
			if self.ship and not is_initial then
				safe_from_ship = wrapped_distance(ax, ay, self.ship.x, self.ship.y) >= WAVE_SPAWN_SAFE_DISTANCE_FROM_SHIP
			end
			if safe_from_center and safe_from_ship then break end
			ax = rnd(SCREEN_W)
			ay = rnd(SCREEN_H)
			attempts  = attempts  + 1
		end
		add(self.asteroids, Asteroid.new("large", ax, ay))
	end
	self.wave_start_asteroid_count = #self.asteroids
	self.wave_clear_timer = -1
	self.cadence_timer = 0
end

function GameScreen:begin_play()
	self.state = "play"
	self.ship = Ship.new(SHIP_START_X, SHIP_START_Y)
	self.ship.vx = 0
	self.ship.vy = 0
	self.ship.angle = SHIP_START_ANGLE
	self.ship.invuln_timer = 0
	self.cadence_timer = 0
	self.cadence_flip = false
end

function GameScreen:add_explosion(x, y)
	add(self.explosions, Explosion.new(x, y))
end

function GameScreen:award_points(points)
	self.score  = self.score  + points
	while self.score >= self.next_extra_life_score do
		self.lives  = self.lives  + 1
		self.next_extra_life_score  = self.next_extra_life_score  + EXTRA_LIFE_SCORE_STEP
		sfx(SFX_EXTRA_LIFE, SFX_CHANNEL_FX)
	end
end

function GameScreen:asteroid_points(size)
	if size == "large" then return SCORE_ASTEROID_LARGE end
	if size == "medium" then return SCORE_ASTEROID_MEDIUM end
	return SCORE_ASTEROID_SMALL
end

function GameScreen:split_asteroid(asteroid)
	if asteroid.size == "large" then
		add(self.asteroids, Asteroid.new("medium", asteroid.x, asteroid.y))
		add(self.asteroids, Asteroid.new("medium", asteroid.x, asteroid.y))
	elseif asteroid.size == "medium" then
		add(self.asteroids, Asteroid.new("small", asteroid.x, asteroid.y))
		add(self.asteroids, Asteroid.new("small", asteroid.x, asteroid.y))
	end
end

function GameScreen:destroy_asteroid(index, by_player)
	local asteroid = self.asteroids[index]
	if not asteroid then return end
	self:add_explosion(asteroid.x, asteroid.y)
	sfx(SFX_HIT, SFX_CHANNEL_FX)
	if by_player then
		self:award_points(self:asteroid_points(asteroid.size))
	end
	self:split_asteroid(asteroid)
	deli(self.asteroids, index)
end

function GameScreen:destroy_ship()
	if not self.ship then return end
	if self.ship.invuln_timer > 0 then return end
	self:add_explosion(self.ship.x, self.ship.y)
	sfx(SFX_HIT, SFX_CHANNEL_FX)
	self.ship = nil
	self.respawn_timer = RESPAWN_DELAY
	self.lives  = self.lives  - 1
	if self.lives <= 0 then
		self.game_over = true
		self.respawn_timer = -1
	end
	if self.thrust_sound_on then
		sfx(-1, SFX_CHANNEL_THRUST)
		self.thrust_sound_on = false
	end
end

function GameScreen:can_respawn_now()
	for i = 1, #self.asteroids do
		local a = self.asteroids[i]
		if wrapped_distance(SHIP_START_X, SHIP_START_Y, a.x, a.y) < (RESPAWN_SAFE_DISTANCE + a.radius) then
			return false
		end
	end
	return true
end

function GameScreen:update_respawn(dt)
	if self.game_over then return end
	if self.ship then return end
	if self.respawn_timer < 0 then return end

	if self.respawn_timer > 0 then
		self.respawn_timer  = self.respawn_timer  - dt
		return
	end

	if self.lives > 0 and self:can_respawn_now() then
		self.ship = Ship.new(SHIP_START_X, SHIP_START_Y)
		self.ship.invuln_timer = RESPAWN_INVULN_TIME
		self.ship.vx = 0
		self.ship.vy = 0
		self.respawn_timer = -1
	end
end

function GameScreen:update_cadence(dt)
	if self.state ~= "play" then return end
	if self.game_over then return end
	if #self.asteroids == 0 then return end

	local count = #self.asteroids
	local start_count = max(1, self.wave_start_asteroid_count)
	local interval = CADENCE_INTERVAL_FAST
	if start_count > 1 then
		local t = (start_count - count) / (start_count - 1)
		t = clamp(t, 0, 1)
		interval = CADENCE_INTERVAL_SLOW + (CADENCE_INTERVAL_FAST - CADENCE_INTERVAL_SLOW) * t
	end

	self.cadence_timer  = self.cadence_timer  - dt
	if self.cadence_timer <= 0 then
		local sid = self.cadence_flip and SFX_CADENCE_B or SFX_CADENCE_A
		sfx(sid, SFX_CHANNEL_CADENCE)
		self.cadence_flip = not self.cadence_flip
		self.cadence_timer = interval
	end
end

function GameScreen:try_spawn_ufo()
	if self.state ~= "play" then return end
	if self.game_over then return end
	if #self.ufos > 0 then return end

	local dir = rnd(1) < 0.5 and 1 or -1
	local x = dir > 0 and (-UFO_WIDTH) or (SCREEN_W + UFO_WIDTH)
	local y = rand_range(UFO_MIN_Y, UFO_MAX_Y)

	local ok = true
	for i = 1, #self.asteroids do
		local a = self.asteroids[i]
		if wrapped_distance(x, y, a.x, a.y) < (UFO_SPAWN_SAFE_DISTANCE + a.radius + UFO_COLLISION_RADIUS) then
			ok = false
			break
		end
	end

	if ok and self.ship then
		if wrapped_distance(x, y, self.ship.x, self.ship.y) < (UFO_SPAWN_SAFE_DISTANCE + UFO_COLLISION_RADIUS + self.ship.radius) then
			ok = false
		end
	end

	if not ok then return false end

	add(self.ufos, UFO.new(x, y, dir))
	self.ufo_spawn_pending = false
	sfx(SFX_UFO_LOOP, SFX_CHANNEL_UFO, 0, -1)
	self.ufo_loop_on = true
	return true
end

function GameScreen:update_ufo_spawn(dt)
	if self.state ~= "play" then return end
	if self.game_over then return end

	if not self.ufo_spawn_pending then
		self.ufo_spawn_timer  = self.ufo_spawn_timer  - dt
		if self.ufo_spawn_timer <= 0 then
			self.ufo_spawn_pending = true
		end
	end

	if self.ufo_spawn_pending then
		self:try_spawn_ufo()
	end
end

function GameScreen:remove_ufo(index)
	deli(self.ufos, index)
	if #self.ufos == 0 and self.ufo_loop_on then
		sfx(-1, SFX_CHANNEL_UFO)
		self.ufo_loop_on = false
		self.ufo_spawn_timer = rand_range(UFO_SPAWN_MIN_DELAY, UFO_SPAWN_MAX_DELAY)
	end
end

function GameScreen:fire_ufo_bullet(ufo)
	local a = rnd(1)
	local vx = cos(a) * UFO_BULLET_SPEED
	local vy = sin(a) * UFO_BULLET_SPEED
	add(self.enemy_bullets, Bullet.new(ufo.x, ufo.y, vx, vy, UFO_BULLET_RADIUS, GREEN, "ufo", nil))
	sfx(SFX_FIRE, SFX_CHANNEL_FX)
end

function GameScreen:update_objects(dt)
	for i = #self.asteroids, 1, -1 do
		self.asteroids[i]:update(dt)
	end

	for i = #self.bullets, 1, -1 do
		local b = self.bullets[i]
		b:update(dt)
		if not b.alive then
			deli(self.bullets, i)
		end
	end

	for i = #self.enemy_bullets, 1, -1 do
		local b = self.enemy_bullets[i]
		b:update(dt)
		if not b.alive then
			deli(self.enemy_bullets, i)
		end
	end

	for i = #self.ufos, 1, -1 do
		local ufo = self.ufos[i]
		local fired = ufo:update(dt)
		if fired then
			self:fire_ufo_bullet(ufo)
		end
		if ufo:is_offscreen() then
			self:remove_ufo(i)
		end
	end

	for i = #self.explosions, 1, -1 do
		local e = self.explosions[i]
		e:update(dt)
		if not e.alive then
			deli(self.explosions, i)
		end
	end
end

function GameScreen:resolve_player_fire()
	if not self.ship then return end
	if self.game_over then return end
	if buttonWasPressed(BUTTON_O) and self.ship:can_fire() then
		add(self.bullets, self.ship:fire())
		sfx(SFX_FIRE, SFX_CHANNEL_FX)
	end
end

function GameScreen:resolve_ship_sound()
	if self.ship and self.ship.thrusting and not self.game_over then
		if not self.thrust_sound_on then
			sfx(SFX_THRUST, SFX_CHANNEL_THRUST, 0, -1)
			self.thrust_sound_on = true
		end
	else
		if self.thrust_sound_on then
			sfx(-1, SFX_CHANNEL_THRUST)
			self.thrust_sound_on = false
		end
	end
end

function GameScreen:resolve_collisions()
	for bi = #self.bullets, 1, -1 do
		local b = self.bullets[bi]
		local hit = false
		for ai = #self.asteroids, 1, -1 do
			local a = self.asteroids[ai]
			if wrapped_distance(b.x, b.y, a.x, a.y) <= (b.radius + a.radius) then
				self:destroy_asteroid(ai, true)
				hit = true
				break
			end
		end
		if not hit then
			for ui = #self.ufos, 1, -1 do
				local u = self.ufos[ui]
				if wrapped_distance(b.x, b.y, u.x, u.y) <= (b.radius + u.radius) then
					self:add_explosion(u.x, u.y)
					sfx(SFX_HIT, SFX_CHANNEL_FX)
					self:award_points(SCORE_UFO)
					self:remove_ufo(ui)
					hit = true
					break
				end
			end
		end
		if hit then
			deli(self.bullets, bi)
		end
	end

	for bi = #self.enemy_bullets, 1, -1 do
		local b = self.enemy_bullets[bi]
		local hit = false
		for ai = #self.asteroids, 1, -1 do
			local a = self.asteroids[ai]
			if wrapped_distance(b.x, b.y, a.x, a.y) <= (b.radius + a.radius) then
				self:destroy_asteroid(ai, false)
				hit = true
				break
			end
		end
		if hit then
			deli(self.enemy_bullets, bi)
		elseif self.ship and self.ship.invuln_timer <= 0 then
			if wrapped_distance(b.x, b.y, self.ship.x, self.ship.y) <= (b.radius + self.ship.radius) then
				self:destroy_ship()
				deli(self.enemy_bullets, bi)
			end
		end
	end

	if self.ship and self.ship.invuln_timer <= 0 then
		for ai = #self.asteroids, 1, -1 do
			local a = self.asteroids[ai]
			if wrapped_distance(self.ship.x, self.ship.y, a.x, a.y) <= (self.ship.radius + a.radius) then
				self:destroy_ship()
				break
			end
		end
	end

	if self.ship and self.ship.invuln_timer <= 0 then
		for ui = #self.ufos, 1, -1 do
			local u = self.ufos[ui]
			if wrapped_distance(self.ship.x, self.ship.y, u.x, u.y) <= (self.ship.radius + u.radius) then
				self:add_explosion(u.x, u.y)
				sfx(SFX_HIT, SFX_CHANNEL_FX)
				self:remove_ufo(ui)
				self:destroy_ship()
				break
			end
		end
	end

	for ui = #self.ufos, 1, -1 do
		local u = self.ufos[ui]
		for ai = #self.asteroids, 1, -1 do
			local a = self.asteroids[ai]
			if wrapped_distance(u.x, u.y, a.x, a.y) <= (u.radius + a.radius) then
				self:add_explosion(u.x, u.y)
				sfx(SFX_HIT, SFX_CHANNEL_FX)
				self:remove_ufo(ui)
				self:destroy_asteroid(ai, false)
				break
			end
		end
	end
end

function GameScreen:update_wave_progress(dt)
	if #self.asteroids > 0 then
		self.wave_clear_timer = -1
		return
	end

	if self.wave_clear_timer < 0 then
		self.wave_clear_timer = NEXT_WAVE_DELAY
		return
	end

	self.wave_clear_timer  = self.wave_clear_timer  - dt
	if self.wave_clear_timer <= 0 then
		self.wave_index  = self.wave_index  + 1
		self:spawn_wave(false)
	end
end

function GameScreen:update_attract(dt)
	self.flash_timer  = self.flash_timer  + dt
	self:update_objects(dt)
	if buttonWasPressed(BUTTON_X) then
		self:begin_play()
	end
end

function GameScreen:update_play(dt)
	if self.ship then
		self.ship:update(dt)
	end
	self:resolve_player_fire()
	self:update_ufo_spawn(dt)
	self:update_objects(dt)
	self:resolve_collisions()
	self:update_respawn(dt)
	self:update_wave_progress(dt)
	self:update_cadence(dt)
	self:resolve_ship_sound()
end

function GameScreen:update()
	local dt = FRAME_DT
	if self.state == "attract" then
		self:update_attract(dt)
	else
		self:update_play(dt)
	end
end

function GameScreen:draw_hud()
	print("score "..flr(self.score), 78, 2, WHITE)
	for i = 1, max(0, self.lives) do
		draw_life_icon(7 + (i - 1) * 7, 8)
	end
	if self.game_over then
		print("game over", 46, 62, RED)
	end
end

function GameScreen:draw_attract_overlay()
	draw_title_text(TITLE_X, TITLE_Y, TITLE_SCALE, WHITE)
	if (self.flash_timer % TITLE_FLASH_PERIOD) < TITLE_FLASH_ON_TIME then
		print("press x to start", 34, 106, WHITE)
	end
	if VERSION_STRING then
		print(VERSION_STRING, 1, 121, DARK_GRAY)
	end
end

function GameScreen:draw()
	cls(BLACK)

	for i = 1, #self.asteroids do
		self.asteroids[i]:draw()
	end
	for i = 1, #self.ufos do
		self.ufos[i]:draw()
	end
	for i = 1, #self.bullets do
		self.bullets[i]:draw()
	end
	for i = 1, #self.enemy_bullets do
		self.enemy_bullets[i]:draw()
	end
	if self.ship then
		self.ship:draw()
	end
	for i = 1, #self.explosions do
		self.explosions[i]:draw()
	end

	if self.state == "attract" then
		self:draw_attract_overlay()
	else
		self:draw_hud()
	end
end
