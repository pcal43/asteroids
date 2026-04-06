
GameScreen = {}

local SCREEN_SIZE = 128
local SCREEN_CENTER = SCREEN_SIZE / 2
local GAME_DT = 1 / 30

local SHIP_ALTITUDE = 12
local SHIP_HALF_ALTITUDE = SHIP_ALTITUDE / 2
local SHIP_HALF_NOSE_ANGLE = 22.5 / 360
local SHIP_HALF_BASE = SHIP_ALTITUDE * abs(sin(SHIP_HALF_NOSE_ANGLE) / cos(SHIP_HALF_NOSE_ANGLE))
local SHIP_RADIUS = 7
local SHIP_ROTATION_SPEED = 180 / 360
local SHIP_THRUST_ACCEL = 20
local SHIP_DAMPING = 1
local SHIP_MAX_SPEED = 20
local SHIP_INVULNERABILITY = 2

local BULLET_SPEED = 20
local BULLET_RANGE = 64
local BULLET_RADIUS = 1
local BULLET_COOLDOWN = 0.2

local UFO_BULLET_SPEED = 10
local UFO_SPEED = 15
local UFO_RADIUS = 7

local RESPAWN_DELAY = 3
local WAVE_DELAY = 3

local ASTEROID_LARGE = "large"
local ASTEROID_MEDIUM = "medium"
local ASTEROID_SMALL = "small"

local ASTEROID_CONFIG = {
    [ASTEROID_LARGE] = {radius = 8, score = 10, split = ASTEROID_MEDIUM, threat = 1},
    [ASTEROID_MEDIUM] = {radius = 6, score = 20, split = ASTEROID_SMALL, threat = 0.5},
    [ASTEROID_SMALL] = {radius = 4, score = 30, split = nil, threat = 0.25},
}

local function clamp(value, min_value, max_value)
    return max(min_value, min(value, max_value))
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

local function torus_delta(a, b)
    local delta = b - a
    if delta > SCREEN_CENTER then
        delta -= SCREEN_SIZE
    elseif delta < -SCREEN_CENTER then
        delta += SCREEN_SIZE
    end
    return delta
end

local function distance_sq(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return dx * dx + dy * dy
end

local function torus_distance_sq(x1, y1, x2, y2)
    local dx = torus_delta(x1, x2)
    local dy = torus_delta(y1, y2)
    return dx * dx + dy * dy
end

local function collision_distance_sq(a, b)
    if a.wrap and b.wrap then
        return torus_distance_sq(a.x, a.y, b.x, b.y)
    end

    if a.wrap or b.wrap then
        local wrapped = a.wrap and a or b
        local direct = a.wrap and b or a
        local best = 32767
        for ox = -SCREEN_SIZE, SCREEN_SIZE, SCREEN_SIZE do
            for oy = -SCREEN_SIZE, SCREEN_SIZE, SCREEN_SIZE do
                local value = distance_sq(wrapped.x + ox, wrapped.y + oy, direct.x, direct.y)
                if value < best then
                    best = value
                end
            end
        end
        return best
    end

    return distance_sq(a.x, a.y, b.x, b.y)
end

local function circles_overlap(a, b)
    local radius = a.radius + b.radius
    return collision_distance_sq(a, b) <= radius * radius
end

local function limit_speed(vx, vy, max_speed)
    local speed = sqrt(vx * vx + vy * vy)
    if speed > max_speed and speed > 0 then
        local scale = max_speed / speed
        return vx * scale, vy * scale
    end
    return vx, vy
end

local function random_angle()
    return rnd(1)
end

local function random_velocity(min_speed, max_speed)
    local angle = random_angle()
    local speed = min_speed + rnd(max_speed - min_speed)
    return cos(angle) * speed, sin(angle) * speed
end

local function triangle_points(cx, cy, angle, altitude, half_base)
    local fx = cos(angle)
    local fy = sin(angle)
    local rx = -fy
    local ry = fx
    local nose_x = cx + fx * (altitude * 0.5)
    local nose_y = cy + fy * (altitude * 0.5)
    local base_cx = cx - fx * (altitude * 0.5)
    local base_cy = cy - fy * (altitude * 0.5)
    local left_x = base_cx - rx * half_base
    local left_y = base_cy - ry * half_base
    local right_x = base_cx + rx * half_base
    local right_y = base_cy + ry * half_base
    return nose_x, nose_y, left_x, left_y, right_x, right_y, base_cx, base_cy
end

local function draw_triangle(cx, cy, angle, altitude, half_base, color)
    local nose_x, nose_y, left_x, left_y, right_x, right_y = triangle_points(cx, cy, angle, altitude, half_base)
    line(nose_x, nose_y, left_x, left_y, color)
    line(left_x, left_y, right_x, right_y, color)
    line(right_x, right_y, nose_x, nose_y, color)
end

local function draw_wrapped(x, y, radius, draw_fn)
    draw_fn(x, y)

    local x_offsets = {0}
    local y_offsets = {0}

    if x < radius then
        add(x_offsets, SCREEN_SIZE)
    elseif x > SCREEN_SIZE - radius then
        add(x_offsets, -SCREEN_SIZE)
    end

    if y < radius then
        add(y_offsets, SCREEN_SIZE)
    elseif y > SCREEN_SIZE - radius then
        add(y_offsets, -SCREEN_SIZE)
    end

    for i = 1, #x_offsets do
        for j = 1, #y_offsets do
            local ox = x_offsets[i]
            local oy = y_offsets[j]
            if ox ~= 0 or oy ~= 0 then
                draw_fn(x + ox, y + oy)
            end
        end
    end
end

local Explosion = {}

function Explosion.new(x, y, color)
    local rays = {}
    for i = 1, 6 do
        add(rays, {angle = random_angle(), length = 3 + rnd(4)})
    end

    local self = {
        x = x,
        y = y,
        color = color or WHITE,
        timer = 0.5,
        age = 0,
        radius = 0,
        rays = rays,
        wrap = true,
    }
    setmetatable(self, { __index = Explosion })
    return self
end

function Explosion:update(dt)
    self.age += dt
    self.timer -= dt
    self.radius = 2 + self.age * 18
    if self.timer <= 0 then
        self.dead = true
    end
end

function Explosion:draw()
    local fade = self.timer > 0.2 and self.color or RED
    draw_wrapped(self.x, self.y, self.radius, function(draw_x, draw_y)
        circ(draw_x, draw_y, self.radius, fade)
        for i = 1, #self.rays do
            local ray = self.rays[i]
            local inner = self.radius * 0.25
            local outer = self.radius + ray.length
            local x1 = draw_x + cos(ray.angle) * inner
            local y1 = draw_y + sin(ray.angle) * inner
            local x2 = draw_x + cos(ray.angle) * outer
            local y2 = draw_y + sin(ray.angle) * outer
            line(x1, y1, x2, y2, fade)
        end
    end)
end

local Bullet = {}

function Bullet.new(x, y, angle, speed, color, radius, range, owner)
    local self = {
        x = x,
        y = y,
        vx = cos(angle) * speed,
        vy = sin(angle) * speed,
        color = color,
        radius = radius,
        ttl = range / speed,
        wrap = true,
        owner = owner,
    }
    setmetatable(self, { __index = Bullet })
    return self
end

function Bullet:update(dt)
    self.x = wrap_coord(self.x + self.vx * dt)
    self.y = wrap_coord(self.y + self.vy * dt)
    self.ttl -= dt
    if self.ttl <= 0 then
        self.dead = true
    end
end

function Bullet:draw()
    draw_wrapped(self.x, self.y, self.radius + 1, function(draw_x, draw_y)
        circfill(draw_x, draw_y, self.radius, self.color)
    end)
end

local Asteroid = {}

function Asteroid.new(size, x, y, vx, vy)
    local config = ASTEROID_CONFIG[size]
    local self = {
        size = size,
        x = x,
        y = y,
        vx = vx,
        vy = vy,
        radius = config.radius,
        score = config.score,
        split = config.split,
        threat = config.threat,
        wrap = true,
    }
    setmetatable(self, { __index = Asteroid })
    return self
end

function Asteroid:update(dt)
    self.x = wrap_coord(self.x + self.vx * dt)
    self.y = wrap_coord(self.y + self.vy * dt)
end

function Asteroid:draw()
    draw_wrapped(self.x, self.y, self.radius + 1, function(draw_x, draw_y)
        circ(draw_x, draw_y, self.radius, WHITE)
    end)
end

local UFO = {}

function UFO.new(from_left, y)
    local self = {
        x = from_left and -12 or 140,
        y = y,
        vx = from_left and UFO_SPEED or -UFO_SPEED,
        vy = 0,
        width = 14,
        height = 6,
        radius = UFO_RADIUS,
        wrap = false,
        fire_timer = 1 + rnd(1),
    }
    setmetatable(self, { __index = UFO })
    return self
end

function UFO:update(dt, screen)
    self.x += self.vx * dt
    self.fire_timer -= dt
    if self.fire_timer <= 0 then
        screen:spawn_ufo_bullet(self)
        self.fire_timer = 1 + rnd(1)
    end

    if self.vx > 0 and self.x - self.width * 0.5 > SCREEN_SIZE then
        self.dead = true
        self.left_screen = true
    elseif self.vx < 0 and self.x + self.width * 0.5 < 0 then
        self.dead = true
        self.left_screen = true
    end
end

function UFO:draw()
    local left = self.x - self.width * 0.5
    local right = self.x + self.width * 0.5
    local top = self.y - self.height * 0.5
    local bottom = self.y + self.height * 0.5
    line(left, top, right, top, GREEN)
    line(right, top, right, bottom, GREEN)
    line(right, bottom, left, bottom, GREEN)
    line(left, bottom, left, top, GREEN)
    line(left + 3, top - 2, right - 3, top - 2, GREEN)
    line(left + 1, self.y, right - 1, self.y, GREEN)
end

local Ship = {}

function Ship.new(x, y)
    local self = {
        x = x,
        y = y,
        angle = 0.25,
        vx = 0,
        vy = 0,
        radius = SHIP_RADIUS,
        wrap = true,
        fire_cooldown = 0,
        invulnerability = 0,
        thrusting = false,
    }
    setmetatable(self, { __index = Ship })
    return self
end

function Ship:get_nose_position()
    local nose_x, nose_y = triangle_points(self.x, self.y, self.angle, SHIP_ALTITUDE, SHIP_HALF_BASE)
    return nose_x, nose_y
end

function Ship:update(dt, screen, fire_pressed)
    self.thrusting = false

    if btn(BUTTON_RIGHT) then
        self.angle -= SHIP_ROTATION_SPEED * dt
    end
    if btn(BUTTON_LEFT) then
        self.angle += SHIP_ROTATION_SPEED * dt
    end

    if self.angle < 0 then
        self.angle += 1
    elseif self.angle >= 1 then
        self.angle -= 1
    end

    if btn(BUTTON_X) then
        local fx = cos(self.angle)
        local fy = sin(self.angle)
        self.vx += fx * SHIP_THRUST_ACCEL * dt
        self.vy += fy * SHIP_THRUST_ACCEL * dt
        self.thrusting = true
    else
        local speed = sqrt(self.vx * self.vx + self.vy * self.vy)
        if speed > 0 then
            local reduced = max(0, speed - SHIP_DAMPING * dt)
            if reduced == 0 then
                self.vx = 0
                self.vy = 0
            else
                local scale = reduced / speed
                self.vx *= scale
                self.vy *= scale
            end
        end
    end

    self.vx, self.vy = limit_speed(self.vx, self.vy, SHIP_MAX_SPEED)
    self.x = wrap_coord(self.x + self.vx * dt)
    self.y = wrap_coord(self.y + self.vy * dt)

    self.fire_cooldown = max(0, self.fire_cooldown - dt)
    self.invulnerability = max(0, self.invulnerability - dt)

    if fire_pressed and self.fire_cooldown <= 0 then
        screen:spawn_player_bullet(self)
        self.fire_cooldown = BULLET_COOLDOWN
    end
end

function Ship:draw()
    if self.invulnerability > 0 and flr(self.invulnerability * 10) % 2 == 0 then
        return
    end

    draw_wrapped(self.x, self.y, SHIP_ALTITUDE, function(draw_x, draw_y)
        if self.thrusting then
            local flame_altitude = 4
            local flame_half_base = flame_altitude / sqrt(3)
            local fx = cos(self.angle)
            local fy = sin(self.angle)
            local flame_x = draw_x - fx * (SHIP_HALF_ALTITUDE + flame_altitude * 0.5)
            local flame_y = draw_y - fy * (SHIP_HALF_ALTITUDE + flame_altitude * 0.5)
            draw_triangle(flame_x, flame_y, self.angle + 0.5, flame_altitude, flame_half_base, RED)
        end

        draw_triangle(draw_x, draw_y, self.angle, SHIP_ALTITUDE, SHIP_HALF_BASE, WHITE)
    end)
end

function GameScreen.new()
    local self = {
        isDone = false,
        score = 0,
        lives = 3,
        ship = nil,
        asteroids = {},
        bullets = {},
        enemyBullets = {},
        ufos = {},
        effects = {},
        respawn_timer = 0,
        wave_timer = 0,
        ufo_timer = 30 + rnd(30),
        beat_timer = 0,
        next_beat = 0,
        thrust_sound_timer = 0,
        ufo_hum_timer = 0,
        awaiting_game_over = false,
        game_over = false,
    }
    setmetatable(self, { __index = GameScreen })
    self.ship = Ship.new(SCREEN_CENTER, SCREEN_CENTER)
    self:spawn_wave()
    music(-1)
    return self
end

function GameScreen:add_effect(x, y, color)
    add(self.effects, Explosion.new(x, y, color))
end

function GameScreen:play_sound(sound, channel)
    if channel ~= nil then
        sfx(sound, channel)
    else
        sfx(sound)
    end
end

function GameScreen:stop_channel(channel)
    sfx(-1, channel)
end

function GameScreen:spawn_player_bullet(ship)
    local nose_x, nose_y = ship:get_nose_position()
    local bullet = Bullet.new(
        wrap_coord(nose_x),
        wrap_coord(nose_y),
        ship.angle,
        BULLET_SPEED,
        ORANGE,
        BULLET_RADIUS,
        BULLET_RANGE,
        "player"
    )
    add(self.bullets, bullet)
    self:play_sound(2, 2)
end

function GameScreen:spawn_ufo_bullet(ufo)
    local angle = random_angle()
    local bullet = Bullet.new(
        wrap_coord(ufo.x),
        wrap_coord(ufo.y),
        angle,
        UFO_BULLET_SPEED,
        GREEN,
        BULLET_RADIUS,
        BULLET_RANGE,
        "ufo"
    )
    add(self.enemyBullets, bullet)
    self:play_sound(2, 2)
end

function GameScreen:spawn_asteroid(size, x, y)
    local vx, vy = random_velocity(5, 10)
    add(self.asteroids, Asteroid.new(size, x, y, vx, vy))
end

function GameScreen:spawn_split_asteroids(parent)
    if not parent.split then
        return
    end

    for i = 1, 2 do
        local vx, vy = random_velocity(6, 11)
        add(self.asteroids, Asteroid.new(parent.split, parent.x, parent.y, vx, vy))
    end
end

function GameScreen:can_spawn_at(x, y, min_distance)
    for i = 1, #self.asteroids do
        local asteroid = self.asteroids[i]
        local radius = asteroid.radius + min_distance
        if torus_distance_sq(x, y, asteroid.x, asteroid.y) < radius * radius then
            return false
        end
    end
    return true
end

function GameScreen:spawn_wave()
    local avoid_x = self.ship and self.ship.x or SCREEN_CENTER
    local avoid_y = self.ship and self.ship.y or SCREEN_CENTER

    for i = #self.bullets, 1, -1 do
        deli(self.bullets, i)
    end
    for i = #self.enemyBullets, 1, -1 do
        deli(self.enemyBullets, i)
    end

    for i = 1, 10 do
        local attempts = 0
        local placed = false
        while attempts < 200 and not placed do
            local x = rnd(SCREEN_SIZE)
            local y = rnd(SCREEN_SIZE)
            if torus_distance_sq(x, y, avoid_x, avoid_y) >= 20 * 20 then
                self:spawn_asteroid(ASTEROID_LARGE, x, y)
                placed = true
            end
            attempts += 1
        end

        if not placed then
            self:spawn_asteroid(ASTEROID_LARGE, rnd(SCREEN_SIZE), rnd(SCREEN_SIZE))
        end
    end

    self.wave_timer = 0
    self.beat_timer = 0
end

function GameScreen:spawn_ufo()
    local from_left = rnd(1) < 0.5
    local y = 16 + rnd(96)
    add(self.ufos, UFO.new(from_left, y))
    self.ufo_hum_timer = 0
end

function GameScreen:destroy_asteroid(asteroid, award_points)
    if asteroid.dead then
        return
    end

    asteroid.dead = true
    self:add_effect(asteroid.x, asteroid.y, WHITE)
    self:spawn_split_asteroids(asteroid)
    self:play_sound(3, 2)

    if award_points then
        self.score += asteroid.score
    end
end

function GameScreen:destroy_ufo(ufo, award_points)
    if ufo.dead then
        return
    end

    ufo.dead = true
    self:add_effect(ufo.x, ufo.y, GREEN)
    if award_points then
        self.score += 100
    end
end

function GameScreen:destroy_ship()
    if not self.ship then
        return
    end

    self:add_effect(self.ship.x, self.ship.y, WHITE)
    self.ship = nil
    self.lives -= 1
    self.respawn_timer = self.lives > 0 and RESPAWN_DELAY or 0
    self.thrust_sound_timer = 0
    self:stop_channel(1)

    if self.lives <= 0 then
        self.awaiting_game_over = true
    end
end

function GameScreen:update_objects(objects, dt)
    for i = 1, #objects do
        objects[i]:update(dt, self)
    end
end

function GameScreen:prune_dead(objects)
    for i = #objects, 1, -1 do
        if objects[i].dead then
            deli(objects, i)
        end
    end
end

function GameScreen:handle_ship_respawn(dt)
    if self.ship or self.game_over or self.awaiting_game_over or self.lives <= 0 then
        return
    end

    self.respawn_timer = max(0, self.respawn_timer - dt)
    if self.respawn_timer <= 0 and self:can_spawn_at(SCREEN_CENTER, SCREEN_CENTER, 15) then
        self.ship = Ship.new(SCREEN_CENTER, SCREEN_CENTER)
        self.ship.invulnerability = SHIP_INVULNERABILITY
    end
end

function GameScreen:get_beat_interval()
    if #self.asteroids == 0 then
        return nil
    end

    local threat = 0
    for i = 1, #self.asteroids do
        threat += self.asteroids[i].threat
    end
    threat = clamp(threat, 1, 10)

    local t = (threat - 1) / 9
    return 0.5 + t * 1.5
end

function GameScreen:update_cadence(dt)
    if self.game_over or self.awaiting_game_over or self.wave_timer > 0 or #self.asteroids == 0 then
        self:stop_channel(0)
        self.beat_timer = 0
        return
    end

    self.beat_timer -= dt
    if self.beat_timer <= 0 then
        self:play_sound(self.next_beat, 0)
        self.next_beat = self.next_beat == 0 and 1 or 0
        self.beat_timer = self:get_beat_interval()
    end
end

function GameScreen:update_thrust_audio(dt)
    if self.ship and self.ship.thrusting then
        self.thrust_sound_timer -= dt
        if self.thrust_sound_timer <= 0 then
            self:play_sound(4, 1)
            self.thrust_sound_timer = 0.12
        end
    else
        self.thrust_sound_timer = 0
        self:stop_channel(1)
    end
end

function GameScreen:update_ufo_audio(dt)
    if #self.ufos > 0 then
        self.ufo_hum_timer -= dt
        if self.ufo_hum_timer <= 0 then
            self:play_sound(5, 3)
            self.ufo_hum_timer = 0.5
        end
    else
        self.ufo_hum_timer = 0
        self:stop_channel(3)
    end
end

function GameScreen:handle_collisions()
    for i = 1, #self.bullets do
        local bullet = self.bullets[i]
        if not bullet.dead then
            for j = 1, #self.asteroids do
                local asteroid = self.asteroids[j]
                if not asteroid.dead and circles_overlap(bullet, asteroid) then
                    bullet.dead = true
                    self:destroy_asteroid(asteroid, true)
                    break
                end
            end
        end
    end

    for i = 1, #self.bullets do
        local bullet = self.bullets[i]
        if not bullet.dead then
            for j = 1, #self.ufos do
                local ufo = self.ufos[j]
                if not ufo.dead and circles_overlap(bullet, ufo) then
                    bullet.dead = true
                    self:destroy_ufo(ufo, true)
                    break
                end
            end
        end
    end

    for i = 1, #self.enemyBullets do
        local bullet = self.enemyBullets[i]
        if not bullet.dead then
            for j = 1, #self.asteroids do
                local asteroid = self.asteroids[j]
                if not asteroid.dead and circles_overlap(bullet, asteroid) then
                    bullet.dead = true
                    self:destroy_asteroid(asteroid, false)
                    break
                end
            end
        end
    end

    for i = 1, #self.ufos do
        local ufo = self.ufos[i]
        if not ufo.dead then
            for j = 1, #self.asteroids do
                local asteroid = self.asteroids[j]
                if not asteroid.dead and circles_overlap(ufo, asteroid) then
                    self:destroy_ufo(ufo, false)
                    self:destroy_asteroid(asteroid, false)
                    break
                end
            end
        end
    end

    if self.ship and self.ship.invulnerability <= 0 then
        for i = 1, #self.asteroids do
            if not self.asteroids[i].dead and circles_overlap(self.ship, self.asteroids[i]) then
                self:destroy_ship()
                break
            end
        end

        if self.ship then
            for i = 1, #self.enemyBullets do
                if not self.enemyBullets[i].dead and circles_overlap(self.ship, self.enemyBullets[i]) then
                    self.enemyBullets[i].dead = true
                    self:destroy_ship()
                    break
                end
            end
        end

        if self.ship then
            for i = 1, #self.ufos do
                if not self.ufos[i].dead and circles_overlap(self.ship, self.ufos[i]) then
                    self:destroy_ufo(self.ufos[i], false)
                    self:destroy_ship()
                    break
                end
            end
        end
    end
end

function GameScreen:update_wave_state(dt)
    if #self.asteroids == 0 then
        if self.wave_timer <= 0 then
            self.wave_timer = WAVE_DELAY
        else
            self.wave_timer -= dt
            if self.wave_timer <= 0 then
                self:spawn_wave()
            end
        end
    else
        self.wave_timer = 0
    end
end

function GameScreen:update_ufo_spawns(dt)
    if self.game_over or self.awaiting_game_over then
        return
    end

    if #self.ufos == 0 then
        self.ufo_timer -= dt
        if self.ufo_timer <= 0 then
            self:spawn_ufo()
            self.ufo_timer = 30 + rnd(30)
        end
    end
end

function GameScreen:update()
    local dt = GAME_DT
    local restart_pressed = buttonWasPressed(BUTTON_X)
    local fire_pressed = buttonWasPressed(BUTTON_O)

    if self.game_over then
        self:update_objects(self.effects, dt)
        self:prune_dead(self.effects)
        self:update_ufo_audio(dt)
        self:update_cadence(dt)
        if restart_pressed then
            self.isDone = true
            self:stop_channel(0)
            self:stop_channel(1)
            self:stop_channel(2)
            self:stop_channel(3)
        end
        return
    end

    if self.ship then
        self.ship:update(dt, self, fire_pressed)
    end

    self:update_objects(self.asteroids, dt)
    self:update_objects(self.bullets, dt)
    self:update_objects(self.enemyBullets, dt)
    self:update_objects(self.ufos, dt)
    self:update_objects(self.effects, dt)

    self:handle_collisions()

    self:prune_dead(self.asteroids)
    self:prune_dead(self.bullets)
    self:prune_dead(self.enemyBullets)
    self:prune_dead(self.ufos)
    self:prune_dead(self.effects)

    self:handle_ship_respawn(dt)
    self:update_wave_state(dt)
    self:update_ufo_spawns(dt)
    self:update_thrust_audio(dt)
    self:update_ufo_audio(dt)
    self:update_cadence(dt)

    if self.awaiting_game_over and #self.effects == 0 then
        self.awaiting_game_over = false
        self.game_over = true
        self:stop_channel(0)
        self:stop_channel(1)
    end
end

function GameScreen:draw_lives()
    local altitude = 6
    local half_base = SHIP_HALF_BASE * (altitude / SHIP_ALTITUDE)
    for i = 1, self.lives do
        draw_triangle(8 + (i - 1) * 10, 8, 0.25, altitude, half_base, WHITE)
    end
end

function GameScreen:draw_score()
    local text = tostring(self.score)
    print(text, SCREEN_SIZE - #text * 4 - 2, 2, WHITE)
end

function GameScreen:draw_respawn_notice()
    if not self.ship and self.lives > 0 and not self.game_over then
        print("respawning", 42, 60, LIGHT_GRAY)
    end
end

function GameScreen:draw()
    cls(BLACK)

    for i = 1, #self.asteroids do
        self.asteroids[i]:draw()
    end
    for i = 1, #self.bullets do
        self.bullets[i]:draw()
    end
    for i = 1, #self.enemyBullets do
        self.enemyBullets[i]:draw()
    end
    for i = 1, #self.ufos do
        self.ufos[i]:draw()
    end
    for i = 1, #self.effects do
        self.effects[i]:draw()
    end

    if self.ship then
        self.ship:draw()
    end

    self:draw_lives()
    self:draw_score()
    self:draw_respawn_notice()

    if self.wave_timer > 0 and #self.asteroids == 0 then
        print("wave clear", 44, 54, LIGHT_GRAY)
    end

    if self.game_over then
        print("game over", 44, 54, RED)
        print("press ❎", 48, 64, LIGHT_GRAY)
    end
end
