
GameScreen = {}

local SCREEN_SIZE = 128
local SCREEN_CENTER = 64
local FIXED_DT = 1 / 30

local CADENCE_CHANNEL = 0
local ACTION_CHANNEL = 1
local UFO_CHANNEL = 2
local THRUST_CHANNEL = 3

local SHIP_ALTITUDE = 8
local SHIP_HALF_ALTITUDE = SHIP_ALTITUDE / 2
local SHIP_HALF_ANGLE = 1 / 16
local TAN_22_5 = 0.41421356237
local SHIP_HALF_BASE = SHIP_ALTITUDE * TAN_22_5
local SHIP_RADIUS = 5
local SHIP_ROTATION_SPEED = 0.5
local SHIP_THRUST = 20
local SHIP_DAMPING = 1
local SHIP_MAX_SPEED = 20
local SHIP_RESPAWN_DELAY = 3
local SHIP_INVULN_TIME = 2

local BULLET_SPEED = 20
local BULLET_MAX_DISTANCE = 64
local BULLET_RADIUS = 1
local FIRE_COOLDOWN = 0.2

local UFO_BULLET_SPEED = 10
local UFO_SPEED = 15
local UFO_RADIUS = 6

local ASTEROID_LARGE = 1
local ASTEROID_MEDIUM = 2
local ASTEROID_SMALL = 3

local ASTEROID_RADII = {
    8,
    6,
    4
}

local ASTEROID_POINTS = {
    10,
    20,
    30
}

local ASTEROID_THREAT = {
    4,
    2,
    1
}

local ASTEROID_SPEED_MIN = {
    5,
    7,
    9
}

local ASTEROID_SPEED_MAX = {
    10,
    12,
    14
}

local TITLE_LETTER_WIDTH = 8
local TITLE_LETTER_HEIGHT = 16
local TITLE_SPACING = 2
local TITLE_Y = 18

local function rand_range(min_value, max_value)
    return min_value + rnd(max_value - min_value)
end

local function clamp(value, min_value, max_value)
    if value < min_value then
        return min_value
    end
    if value > max_value then
        return max_value
    end
    return value
end

local function wrap_coord(value)
    while value < 0 do
        value += SCREEN_SIZE
    end
    while value >= SCREEN_SIZE do
        value -= SCREEN_SIZE
    end
    return value
end

local function shortest_delta(a, b)
    local delta = b - a
    if delta > SCREEN_SIZE / 2 then
        delta -= SCREEN_SIZE
    elseif delta < -SCREEN_SIZE / 2 then
        delta += SCREEN_SIZE
    end
    return delta
end

local function dist_sq(ax, ay, bx, by)
    local dx = bx - ax
    local dy = by - ay
    return dx * dx + dy * dy
end

local function wrapped_dist_sq(ax, ay, bx, by)
    local dx = shortest_delta(ax, bx)
    local dy = shortest_delta(ay, by)
    return dx * dx + dy * dy
end

local function vec_from_angle(angle, magnitude)
    return cos(angle) * magnitude, sin(angle) * magnitude
end

local function normalize(vx, vy)
    local magnitude = sqrt(vx * vx + vy * vy)
    if magnitude <= 0 then
        return 0, 0, 0
    end
    return vx / magnitude, vy / magnitude, magnitude
end

local function limit_velocity(vx, vy, max_speed)
    local nx, ny, speed = normalize(vx, vy)
    if speed > max_speed then
        return nx * max_speed, ny * max_speed
    end
    return vx, vy
end

local function add_object(collection, object)
    add(collection, object)
    return object
end

local function remove_dead(collection)
    for i = #collection, 1, -1 do
        if collection[i].dead then
            deli(collection, i)
        end
    end
end

local function fat_line(x1, y1, x2, y2, color)
    line(x1, y1, x2, y2, color)
    line(x1 + 1, y1 + 1, x2 + 1, y2 + 1, color)
end

local function draw_triangle_outline(x1, y1, x2, y2, x3, y3, color)
    line(x1, y1, x2, y2, color)
    line(x2, y2, x3, y3, color)
    line(x3, y3, x1, y1, color)
end

local Ship = {}

function Ship.new(game, x, y, invuln_time)
    local self = {
        game = game,
        x = x,
        y = y,
        angle = 0.25,
        vx = 0,
        vy = 0,
        fire_cooldown = 0,
        invuln_timer = invuln_time or 0,
        thrusting = false,
        dead = false
    }
    setmetatable(self, { __index = Ship })
    return self
end

function Ship:get_points(scale)
    scale = scale or 1
    local nose_x, nose_y = vec_from_angle(self.angle, SHIP_HALF_ALTITUDE * scale)
    local rear_x, rear_y = vec_from_angle(self.angle, -SHIP_HALF_ALTITUDE * scale)
    local right_x, right_y = vec_from_angle(self.angle + 0.25, SHIP_HALF_BASE * scale)
    return {
        self.x + nose_x,
        self.y + nose_y,
        self.x + rear_x + right_x,
        self.y + rear_y + right_y,
        self.x + rear_x - right_x,
        self.y + rear_y - right_y
    }
end

function Ship:get_nose_position()
    local dx, dy = vec_from_angle(self.angle, SHIP_HALF_ALTITUDE)
    return self.x + dx, self.y + dy
end

function Ship:update(dt)
    self.invuln_timer = max(0, self.invuln_timer - dt)
    self.fire_cooldown = max(0, self.fire_cooldown - dt)
    self.thrusting = false

    if btn(BUTTON_RIGHT) then
        self.angle -= SHIP_ROTATION_SPEED * dt
    end
    if btn(BUTTON_LEFT) then
        self.angle += SHIP_ROTATION_SPEED * dt
    end

    if btn(BUTTON_X) then
        local ax, ay = vec_from_angle(self.angle, SHIP_THRUST * dt)
        self.vx += ax
        self.vy += ay
        self.thrusting = true
    else
        local nx, ny, speed = normalize(self.vx, self.vy)
        if speed > 0 then
            local next_speed = max(0, speed - SHIP_DAMPING * dt)
            self.vx = nx * next_speed
            self.vy = ny * next_speed
        end
    end

    self.vx, self.vy = limit_velocity(self.vx, self.vy, SHIP_MAX_SPEED)
    self.x = wrap_coord(self.x + self.vx * dt)
    self.y = wrap_coord(self.y + self.vy * dt)

    if buttonWasPressed(BUTTON_O) and self.fire_cooldown <= 0 then
        self.fire_cooldown = FIRE_COOLDOWN
        self.game:spawn_player_bullet(self)
        self.game:play_action_sound(2)
    end
    self.game:set_thrust_sound_active(self.thrusting)
end

function Ship:draw()
    if self.invuln_timer > 0 and flr(self.invuln_timer * 10) % 2 == 0 then
        return
    end

    local points = self:get_points(1)
    draw_triangle_outline(points[1], points[2], points[3], points[4], points[5], points[6], WHITE)

    if self.thrusting then
        local rear_dx, rear_dy = vec_from_angle(self.angle, -SHIP_HALF_ALTITUDE)
        local flame_tip_dx, flame_tip_dy = vec_from_angle(self.angle, -6)
        local side_dx, side_dy = vec_from_angle(self.angle + 0.25, 2)
        local base_x = self.x + rear_dx
        local base_y = self.y + rear_dy
        draw_triangle_outline(
            self.x + flame_tip_dx,
            self.y + flame_tip_dy,
            base_x + side_dx,
            base_y + side_dy,
            base_x - side_dx,
            base_y - side_dy,
            RED
        )
    end
end

local Asteroid = {}

function Asteroid.new(game, size_index, x, y, angle, speed)
    local vx, vy = vec_from_angle(angle, speed)
    local self = {
        game = game,
        size = size_index,
        x = x,
        y = y,
        vx = vx,
        vy = vy,
        radius = ASTEROID_RADII[size_index],
        dead = false
    }
    setmetatable(self, { __index = Asteroid })
    return self
end

function Asteroid:update(dt)
    self.x = wrap_coord(self.x + self.vx * dt)
    self.y = wrap_coord(self.y + self.vy * dt)
end

function Asteroid:draw()
    circ(self.x, self.y, self.radius, WHITE)
end

local Bullet = {}

function Bullet.new(game, x, y, angle, speed, color, is_enemy)
    local vx, vy = vec_from_angle(angle, speed)
    local self = {
        game = game,
        x = x,
        y = y,
        vx = vx,
        vy = vy,
        color = color,
        is_enemy = is_enemy,
        travelled = 0,
        radius = BULLET_RADIUS,
        dead = false
    }
    setmetatable(self, { __index = Bullet })
    return self
end

function Bullet:update(dt)
    self.x = wrap_coord(self.x + self.vx * dt)
    self.y = wrap_coord(self.y + self.vy * dt)
    self.travelled += sqrt(self.vx * self.vx + self.vy * self.vy) * dt
    if self.travelled >= BULLET_MAX_DISTANCE then
        self.dead = true
    end
end

function Bullet:draw()
    circfill(self.x, self.y, self.radius, self.color)
end

local UFO = {}

function UFO.new(game, x, y, direction)
    local self = {
        game = game,
        x = x,
        y = y,
        direction = direction,
        vx = direction * UFO_SPEED,
        fire_timer = rand_range(1, 2),
        radius = UFO_RADIUS,
        dead = false
    }
    setmetatable(self, { __index = UFO })
    return self
end

function UFO:update(dt)
    self.x += self.vx * dt
    self.fire_timer -= dt
    if self.fire_timer <= 0 then
        self.fire_timer = rand_range(1, 2)
        self.game:spawn_ufo_bullet(self)
        self.game:play_action_sound(2)
    end

    if self.direction > 0 and self.x > SCREEN_SIZE + self.radius + 2 then
        self.dead = true
    elseif self.direction < 0 and self.x < -self.radius - 2 then
        self.dead = true
    end
end

function UFO:draw()
    local left = self.x - 6
    local right = self.x + 6
    local top = self.y - 2
    local bottom = self.y + 2
    line(left, top, right, top, GREEN)
    line(left, bottom, right, bottom, GREEN)
    line(left, top, left + 2, bottom, GREEN)
    line(right, top, right - 2, bottom, GREEN)
    line(self.x - 3, top - 2, self.x + 3, top - 2, GREEN)
    line(self.x - 5, self.y, self.x + 5, self.y, GREEN)
end

local Explosion = {}

function Explosion.new(x, y, angle)
    local self = {
        x = x,
        y = y,
        timer = 0.7,
        angle = angle,
        dead = false
    }
    setmetatable(self, { __index = Explosion })
    return self
end

function Explosion:update(dt)
    self.timer -= dt
    if self.timer <= 0 then
        self.dead = true
    end
end

function Explosion:draw()
    local progress = 1 - clamp(self.timer / 0.7, 0, 1)
    for i = 0, 2 do
        local shard_angle = self.angle + i / 3
        local inner_dx, inner_dy = vec_from_angle(shard_angle, progress * 2)
        local outer_dx, outer_dy = vec_from_angle(shard_angle, 3 + progress * 5)
        line(self.x + inner_dx, self.y + inner_dy, self.x + outer_dx, self.y + outer_dy, WHITE)
    end
    local ring = progress * 6
    if ring > 0 then
        circ(self.x, self.y, ring, RED)
    end
end

local function draw_title_letter(letter, x, y, color)
    local x0 = x
    local x1 = x + TITLE_LETTER_WIDTH / 2
    local x2 = x + TITLE_LETTER_WIDTH
    local y0 = y
    local y1 = y + TITLE_LETTER_HEIGHT / 2
    local y2 = y + TITLE_LETTER_HEIGHT

    if letter == "a" then
        fat_line(x0, y2, x1, y0, color)
        fat_line(x1, y0, x2, y2, color)
        fat_line(x0 + 2, y1, x2 - 2, y1, color)
    elseif letter == "i" then
        fat_line(x0, y0, x2, y0, color)
        fat_line(x1, y0, x1, y2, color)
        fat_line(x0, y2, x2, y2, color)
    elseif letter == "s" then
        fat_line(x0, y0, x2, y0, color)
        fat_line(x0, y0, x0, y1, color)
        fat_line(x0, y1, x2, y1, color)
        fat_line(x2, y1, x2, y2, color)
        fat_line(x0, y2, x2, y2, color)
    elseif letter == "t" then
        fat_line(x0, y0, x2, y0, color)
        fat_line(x1, y0, x1, y2, color)
    elseif letter == "e" then
        fat_line(x0, y0, x0, y2, color)
        fat_line(x0, y0, x2, y0, color)
        fat_line(x0, y1, x2 - 1, y1, color)
        fat_line(x0, y2, x2, y2, color)
    elseif letter == "r" then
        fat_line(x0, y0, x0, y2, color)
        fat_line(x0, y0, x2, y0, color)
        fat_line(x2, y0, x2, y1, color)
        fat_line(x0, y1, x2, y1, color)
        fat_line(x1, y1, x2, y2, color)
    elseif letter == "o" then
        fat_line(x0, y0, x2, y0, color)
        fat_line(x0, y2, x2, y2, color)
        fat_line(x0, y0, x0, y2, color)
        fat_line(x2, y0, x2, y2, color)
    elseif letter == "d" then
        fat_line(x0, y0, x0, y2, color)
        fat_line(x0, y0, x2 - 1, y0, color)
        fat_line(x0, y2, x2 - 1, y2, color)
        fat_line(x2, y0 + 2, x2, y2 - 2, color)
    end
end

function GameScreen.new()
    local self = {
        isDone = false,
        mode = "attract",
        score = 0,
        lives = 3,
        wave = 1,
        wave_clear_timer = nil,
        respawn_timer = 0,
        game_over_timer = 0,
        prompt_timer = 0,
        beat_timer = 0,
        next_beat = 0,
        ufo_spawn_timer = rand_range(30, 60),
        pending_ufo = false,
        asteroids = {},
        bullets = {},
        enemy_bullets = {},
        ufos = {},
        effects = {},
        ship = nil,
        wave_start_count = 6,
        wave_start_threat = 24,
        thrust_sound_active = false,
        ufo_sound_active = false
    }
    setmetatable(self, { __index = GameScreen })
    music(-1)
    self:reset_attract_mode()
    return self
end

function GameScreen:reset_attract_mode()
    self.mode = "attract"
    self.score = 0
    self.lives = 3
    self.wave = 1
    self.wave_clear_timer = nil
    self.respawn_timer = 0
    self.game_over_timer = 0
    self.prompt_timer = 0
    self.beat_timer = 0
    self.next_beat = 0
    self.ufo_spawn_timer = rand_range(30, 60)
    self.pending_ufo = false
    self.ship = nil
    self.asteroids = {}
    self.bullets = {}
    self.enemy_bullets = {}
    self.ufos = {}
    self.effects = {}
    self:set_thrust_sound_active(false)
    self:set_ufo_sound_active(false)
    self:spawn_wave(6, 20)
end

function GameScreen:start_game()
    self.mode = "playing"
    self.score = 0
    self.lives = 3
    self.wave = 1
    self.wave_clear_timer = nil
    self.respawn_timer = 0
    self.game_over_timer = 0
    self.prompt_timer = 0
    self.bullets = {}
    self.enemy_bullets = {}
    self.ufos = {}
    self.effects = {}
    self.pending_ufo = false
    self.ufo_spawn_timer = rand_range(30, 60)
    self:set_ufo_sound_active(false)
    self.ship = Ship.new(self, SCREEN_CENTER, SCREEN_CENTER, 0)
end

function GameScreen:play_action_sound(sound_index)
    sfx(sound_index, ACTION_CHANNEL)
end

function GameScreen:set_thrust_sound_active(active)
    if active and not self.thrust_sound_active then
        sfx(4, THRUST_CHANNEL)
    elseif not active and self.thrust_sound_active then
        sfx(-1, THRUST_CHANNEL)
    end
    self.thrust_sound_active = active
end

function GameScreen:set_ufo_sound_active(active)
    if active and not self.ufo_sound_active then
        sfx(5, UFO_CHANNEL)
    elseif not active and self.ufo_sound_active then
        sfx(-1, UFO_CHANNEL)
    end
    self.ufo_sound_active = active
end

function GameScreen:get_active_ufo_count()
    local count = 0
    for ufo in all(self.ufos) do
        if not ufo.dead then
            count += 1
        end
    end
    return count
end

function GameScreen:get_asteroid_threat()
    local threat = 0
    for asteroid in all(self.asteroids) do
        if not asteroid.dead then
            threat += ASTEROID_THREAT[asteroid.size]
        end
    end
    return threat
end

function GameScreen:get_cadence_interval()
    if #self.asteroids <= 0 then
        return 2
    end
    if #self.asteroids == 1 then
        return 0.5
    end
    local threat_ratio = self:get_asteroid_threat() / self.wave_start_threat
    threat_ratio = clamp(threat_ratio, 0, 1)
    return 0.5 + 1.5 * threat_ratio
end

function GameScreen:update_cadence(dt)
    if self.wave_clear_timer or self.mode == "game_over" or #self.asteroids <= 0 then
        sfx(-1, CADENCE_CHANNEL)
        self.beat_timer = 0
        return
    end

    self.beat_timer -= dt
    local interval = self:get_cadence_interval()
    while self.beat_timer <= 0 do
        sfx(self.next_beat, CADENCE_CHANNEL)
        self.next_beat = 1 - self.next_beat
        self.beat_timer += interval
    end
end

function GameScreen:is_position_clear_from_asteroids(x, y, radius, use_wrap)
    for asteroid in all(self.asteroids) do
        if not asteroid.dead then
            local distance_sq = use_wrap and wrapped_dist_sq(x, y, asteroid.x, asteroid.y) or dist_sq(x, y, asteroid.x, asteroid.y)
            local min_distance = radius + asteroid.radius
            if distance_sq < min_distance * min_distance then
                return false
            end
        end
    end
    return true
end

function GameScreen:is_ship_spawn_safe(x, y, extra_radius)
    return self:is_position_clear_from_asteroids(x, y, extra_radius, true)
end

function GameScreen:is_ufo_spawn_safe(x, y)
    if not self:is_position_clear_from_asteroids(x, y, 20, false) then
        return false
    end
    if self.ship and not self.ship.dead then
        if dist_sq(x, y, self.ship.x, self.ship.y) < 20 * 20 then
            return false
        end
    end
    return true
end

function GameScreen:spawn_asteroid(size_index, x, y)
    local angle = rnd(1)
    local speed = rand_range(ASTEROID_SPEED_MIN[size_index], ASTEROID_SPEED_MAX[size_index])
    return add_object(self.asteroids, Asteroid.new(self, size_index, x, y, angle, speed))
end

function GameScreen:spawn_wave(large_count, center_exclusion)
    self.wave_start_count = large_count
    self.wave_start_threat = large_count * ASTEROID_THREAT[ASTEROID_LARGE]
    self.wave_clear_timer = nil
    self.beat_timer = 0
    self.next_beat = 0

    for i = 1, large_count do
        local attempts = 0
        local x = rnd(SCREEN_SIZE)
        local y = rnd(SCREEN_SIZE)
        while attempts < 64 do
            x = rnd(SCREEN_SIZE)
            y = rnd(SCREEN_SIZE)
            local center_ok = true
            if center_exclusion and center_exclusion > 0 then
                center_ok = dist_sq(x, y, SCREEN_CENTER, SCREEN_CENTER) >= center_exclusion * center_exclusion
            end
            if center_ok and self:is_position_clear_from_asteroids(x, y, ASTEROID_RADII[ASTEROID_LARGE] + 4, false) then
                break
            end
            attempts += 1
        end
        self:spawn_asteroid(ASTEROID_LARGE, x, y)
    end
end

function GameScreen:spawn_player_bullet(ship)
    local x, y = ship:get_nose_position()
    add_object(self.bullets, Bullet.new(self, x, y, ship.angle, BULLET_SPEED, ORANGE, false))
end

function GameScreen:spawn_ufo_bullet(ufo)
    add_object(self.enemy_bullets, Bullet.new(self, ufo.x, ufo.y, rnd(1), UFO_BULLET_SPEED, GREEN, true))
end

function GameScreen:destroy_ship(ship)
    if not ship or ship.dead then
        return
    end
    ship.dead = true
    self.ship = nil
    self:set_thrust_sound_active(false)
    add_object(self.effects, Explosion.new(ship.x, ship.y, ship.angle))
    self.lives -= 1
    if self.lives > 0 then
        self.respawn_timer = SHIP_RESPAWN_DELAY
    else
        self.mode = "game_over"
        self.game_over_timer = 2.5
        self:set_ufo_sound_active(false)
    end
    end

function GameScreen:destroy_ufo(ufo, award_points)
    if ufo.dead then
        return
    end
    ufo.dead = true
    add_object(self.effects, Explosion.new(ufo.x, ufo.y, 0))
    if award_points then
        self.score += 100
    end
end

function GameScreen:destroy_asteroid_without_split(asteroid)
    if asteroid.dead then
        return
    end
    asteroid.dead = true
    add_object(self.effects, Explosion.new(asteroid.x, asteroid.y, rnd(1)))
    end

function GameScreen:split_asteroid(asteroid, award_points)
    if asteroid.dead then
        return
    end
    asteroid.dead = true
    self:play_action_sound(3)
    if award_points then
        self.score += ASTEROID_POINTS[asteroid.size]
    end

    if asteroid.size < ASTEROID_SMALL then
        local child_size = asteroid.size + 1
        for i = 1, 2 do
            local child = self:spawn_asteroid(child_size, asteroid.x, asteroid.y)
            if i == 2 then
                child.vx = -child.vx
                child.vy = -child.vy
            end
        end
    end
    add_object(self.effects, Explosion.new(asteroid.x, asteroid.y, rnd(1)))
end

function GameScreen:try_spawn_ufo()
    if #self.ufos > 0 or #self.asteroids <= 0 then
        return false
    end
    for attempt = 1, 32 do
        local direction = rnd(1) < 0.5 and 1 or -1
        local x = direction > 0 and -UFO_RADIUS or SCREEN_SIZE + UFO_RADIUS
        local y = rand_range(12, SCREEN_SIZE - 12)
        if self:is_ufo_spawn_safe(x, y) then
            add_object(self.ufos, UFO.new(self, x, y, direction))
            self:set_ufo_sound_active(true)
            return true
        end
    end
    return false
end

function GameScreen:update_ufo_spawns(dt)
    if self.mode ~= "playing" then
        return
    end
    if #self.ufos > 0 then
        return
    end
    if self.pending_ufo then
        if self:try_spawn_ufo() then
            self.pending_ufo = false
            self.ufo_spawn_timer = rand_range(30, 60)
        end
        return
    end
    self.ufo_spawn_timer -= dt
    if self.ufo_spawn_timer <= 0 then
        if self:try_spawn_ufo() then
            self.ufo_spawn_timer = rand_range(30, 60)
        else
            self.pending_ufo = true
        end
    end
    end

function GameScreen:update_respawn(dt)
    if self.mode ~= "playing" or self.ship or self.lives <= 0 then
        return
    end
    if self.respawn_timer > 0 then
        self.respawn_timer = max(0, self.respawn_timer - dt)
        return
    end
    if self:is_ship_spawn_safe(SCREEN_CENTER, SCREEN_CENTER, 15) then
        self.ship = Ship.new(self, SCREEN_CENTER, SCREEN_CENTER, SHIP_INVULN_TIME)
    end
    end

function GameScreen:update_wave_progress(dt)
    if self.mode ~= "playing" then
        return
    end
    if #self.asteroids > 0 then
        return
    end
    if not self.wave_clear_timer then
        self.wave_clear_timer = 3
        return
    end
    self.wave_clear_timer -= dt
    if self.wave_clear_timer <= 0 then
        self.wave += 1
        self:spawn_wave(min(5 + self.wave, 10), 0)
    end
    end

function GameScreen:update_collection(collection, dt)
    for object in all(collection) do
        if not object.dead then
            object:update(dt)
        end
    end
    end

function GameScreen:handle_collisions()
    for bullet in all(self.bullets) do
        if not bullet.dead then
            for asteroid in all(self.asteroids) do
                if not asteroid.dead then
                    local hit_radius = bullet.radius + asteroid.radius
                    if wrapped_dist_sq(bullet.x, bullet.y, asteroid.x, asteroid.y) <= hit_radius * hit_radius then
                        bullet.dead = true
                        self:split_asteroid(asteroid, true)
                        break
                    end
                end
            end
        end
        if not bullet.dead then
            for ufo in all(self.ufos) do
                if not ufo.dead then
                    local hit_radius = bullet.radius + ufo.radius
                    if dist_sq(bullet.x, bullet.y, ufo.x, ufo.y) <= hit_radius * hit_radius then
                        bullet.dead = true
                        self:destroy_ufo(ufo, true)
                        break
                    end
                end
            end
        end
    end

    for bullet in all(self.enemy_bullets) do
        if not bullet.dead then
            for asteroid in all(self.asteroids) do
                if not asteroid.dead then
                    local hit_radius = bullet.radius + asteroid.radius
                    if wrapped_dist_sq(bullet.x, bullet.y, asteroid.x, asteroid.y) <= hit_radius * hit_radius then
                        bullet.dead = true
                        self:split_asteroid(asteroid, false)
                        break
                    end
                end
            end
        end
        if self.ship and not bullet.dead and self.ship.invuln_timer <= 0 then
            local hit_radius = bullet.radius + SHIP_RADIUS
            if wrapped_dist_sq(bullet.x, bullet.y, self.ship.x, self.ship.y) <= hit_radius * hit_radius then
                bullet.dead = true
                self:destroy_ship(self.ship)
            end
        end
    end

    if self.ship and self.ship.invuln_timer <= 0 then
        for asteroid in all(self.asteroids) do
            if not asteroid.dead then
                local hit_radius = SHIP_RADIUS + asteroid.radius
                if wrapped_dist_sq(self.ship.x, self.ship.y, asteroid.x, asteroid.y) <= hit_radius * hit_radius then
                    self:destroy_ship(self.ship)
                    break
                end
            end
        end
    end

    for ufo in all(self.ufos) do
        if not ufo.dead then
            for asteroid in all(self.asteroids) do
                if not asteroid.dead then
                    local hit_radius = ufo.radius + asteroid.radius
                    if dist_sq(ufo.x, ufo.y, asteroid.x, asteroid.y) <= hit_radius * hit_radius then
                        ufo.dead = true
                        self:destroy_asteroid_without_split(asteroid)
                        add_object(self.effects, Explosion.new(ufo.x, ufo.y, 0))
                        break
                    end
                end
            end

            if self.ship and self.ship.invuln_timer <= 0 then
                local ship_hit_radius = ufo.radius + SHIP_RADIUS
                if dist_sq(ufo.x, ufo.y, self.ship.x, self.ship.y) <= ship_hit_radius * ship_hit_radius then
                    self:destroy_ufo(ufo, false)
                    self:destroy_ship(self.ship)
                end
            end
        end
    end
    end

function GameScreen:purge_dead()
    remove_dead(self.asteroids)
    remove_dead(self.bullets)
    remove_dead(self.enemy_bullets)
    remove_dead(self.ufos)
    remove_dead(self.effects)
    if self:get_active_ufo_count() == 0 then
        self:set_ufo_sound_active(false)
    end
    end

function GameScreen:update()
    local dt = FIXED_DT
    self.prompt_timer += dt

    if self.mode == "attract" then
        self:update_collection(self.asteroids, dt)
        self:update_collection(self.effects, dt)
        self:purge_dead()
        self:update_cadence(dt)
        if buttonWasPressed(BUTTON_X) then
            self:start_game()
        end
        return
    end

    if self.ship then
        self.ship:update(dt)
    else
        self:set_thrust_sound_active(false)
    end

    self:update_collection(self.asteroids, dt)
    self:update_collection(self.bullets, dt)
    self:update_collection(self.enemy_bullets, dt)
    self:update_collection(self.ufos, dt)
    self:update_collection(self.effects, dt)
    self:handle_collisions()
    self:purge_dead()
    self:update_respawn(dt)
    self:update_wave_progress(dt)
    self:update_ufo_spawns(dt)
    self:update_cadence(dt)

    if self.mode == "game_over" then
        self.game_over_timer -= dt
        if self.game_over_timer <= 0 then
            self:reset_attract_mode()
        end
    end
    end

function GameScreen:draw_lives()
    for i = 1, self.lives do
        local icon = Ship.new(self, 8 + (i - 1) * 10, 8, 0)
        icon.angle = 0.25
        local points = icon:get_points(0.6)
        draw_triangle_outline(points[1], points[2], points[3], points[4], points[5], points[6], WHITE)
    end
    end

function GameScreen:draw_score()
    local score_text = tostr(self.score)
    print(score_text, SCREEN_SIZE - #score_text * 4 - 2, 4, WHITE)
    end

function GameScreen:draw_title_overlay()
    local title = "aisteroids"
    local total_width = #title * TITLE_LETTER_WIDTH + (#title - 1) * TITLE_SPACING
    local x = flr((SCREEN_SIZE - total_width) / 2)
    for i = 1, #title do
        draw_title_letter(sub(title, i, i), x + (i - 1) * (TITLE_LETTER_WIDTH + TITLE_SPACING), TITLE_Y, WHITE)
    end
    if flr(self.prompt_timer * 2) % 2 == 0 then
        print("press x to start", 37, 104, WHITE)
    end
    end

function GameScreen:draw_game_over()
    print("game over", 43, 60, WHITE)
    end

function GameScreen:draw()
    cls(BLACK)

    for asteroid in all(self.asteroids) do
        asteroid:draw()
    end
    for bullet in all(self.bullets) do
        bullet:draw()
    end
    for bullet in all(self.enemy_bullets) do
        bullet:draw()
    end
    for ufo in all(self.ufos) do
        ufo:draw()
    end
    if self.ship then
        self.ship:draw()
    end
    for effect in all(self.effects) do
        effect:draw()
    end

    if self.mode ~= "attract" then
        self:draw_lives()
        self:draw_score()
    end

    if self.mode == "attract" then
        self:draw_title_overlay()
    elseif self.mode == "game_over" then
        self:draw_game_over()
    end
    end
