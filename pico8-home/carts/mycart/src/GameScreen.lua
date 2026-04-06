
GameScreen = {}

local WORLD_SIZE = 128
local DT = 1 / 30

local SHIP_HEIGHT = 12
local SHIP_HALF_BASE = 3.22 -- 12 * tan(15deg)
local SHIP_RADIUS = 5
local SHIP_ROT_SPEED = 0.5 -- turns per second (180 deg/s)
local SHIP_ACCEL = 10
local SHIP_DAMP = 1
local SHIP_MAX_SPEED = 20
local SHIP_INVULN_TIME = 2

local PLAYER_BULLET_SPEED = 20
local PLAYER_BULLET_MAX_DIST = 64
local PLAYER_BULLET_RADIUS = 1
local PLAYER_FIRE_COOLDOWN = 0.2

local UFO_BULLET_SPEED = 18
local UFO_BULLET_RADIUS = 1

local UFO_SPEED = 15
local UFO_SPAWN_MIN = 30
local UFO_SPAWN_MAX = 60
local UFO_FIRE_MIN = 1
local UFO_FIRE_MAX = 2
local UFO_RADIUS = 6

local WAVE_ASTEROID_COUNT = 10
local WAVE_DELAY = 3
local ASTEROID_SAFE_DIST = 20

local ASTEROID_SIZE_LARGE = 3
local ASTEROID_SIZE_MED = 2
local ASTEROID_SIZE_SMALL = 1

local ASTEROID_RADIUS = {
    [ASTEROID_SIZE_LARGE] = 8,
    [ASTEROID_SIZE_MED] = 6,
    [ASTEROID_SIZE_SMALL] = 4,
}

local ASTEROID_SCORE = {
    [ASTEROID_SIZE_LARGE] = 10,
    [ASTEROID_SIZE_MED] = 20,
    [ASTEROID_SIZE_SMALL] = 30,
}

local function rand_range(min_v, max_v)
    return min_v + rnd(max_v - min_v)
end

local function wrap_position(x, y)
    if x < 0 then x += WORLD_SIZE end
    if x >= WORLD_SIZE then x -= WORLD_SIZE end
    if y < 0 then y += WORLD_SIZE end
    if y >= WORLD_SIZE then y -= WORLD_SIZE end
    return x, y
end

local function torus_delta(a, b)
    local d = b - a
    if d > WORLD_SIZE / 2 then d -= WORLD_SIZE end
    if d < -WORLD_SIZE / 2 then d += WORLD_SIZE end
    return d
end

local function torus_distance(x1, y1, x2, y2)
    local dx = torus_delta(x1, x2)
    local dy = torus_delta(y1, y2)
    return sqrt(dx * dx + dy * dy)
end

local function circles_collide(x1, y1, r1, x2, y2, r2)
    return torus_distance(x1, y1, x2, y2) <= r1 + r2
end

local Ship = {}

function Ship.new(x, y)
    local self = {
        x = x,
        y = y,
        vx = 0,
        vy = 0,
        angle = 0.75,
        radius = SHIP_RADIUS,
        thrusting = false,
        alive = true,
        invuln_timer = 0,
    }
    setmetatable(self, { __index = Ship })
    return self
end

function Ship:reset(x, y)
    self.x = x
    self.y = y
    self.vx = 0
    self.vy = 0
    self.angle = 0.75
    self.thrusting = false
    self.alive = true
    self.invuln_timer = SHIP_INVULN_TIME
end

function Ship:destroy()
    self.alive = false
end

function Ship:is_invulnerable()
    return self.invuln_timer > 0
end

function Ship:nose_position()
    local dirx = cos(self.angle)
    local diry = sin(self.angle)
    return self.x + dirx * (SHIP_HEIGHT / 2), self.y + diry * (SHIP_HEIGHT / 2)
end

function Ship:update(dt)
    if not self.alive then
        return
    end

    if btn(BUTTON_LEFT) then
        self.angle -= SHIP_ROT_SPEED * dt
    end
    if btn(BUTTON_RIGHT) then
        self.angle += SHIP_ROT_SPEED * dt
    end

    self.thrusting = btn(BUTTON_X)
    local dirx = cos(self.angle)
    local diry = sin(self.angle)

    if self.thrusting then
        self.vx += dirx * SHIP_ACCEL * dt
        self.vy += diry * SHIP_ACCEL * dt
    else
        local speed = sqrt(self.vx * self.vx + self.vy * self.vy)
        if speed > 0 then
            local new_speed = max(0, speed - SHIP_DAMP * dt)
            if new_speed == 0 then
                self.vx = 0
                self.vy = 0
            else
                local scale = new_speed / speed
                self.vx *= scale
                self.vy *= scale
            end
        end
    end

    local speed = sqrt(self.vx * self.vx + self.vy * self.vy)
    if speed > SHIP_MAX_SPEED then
        local cap = SHIP_MAX_SPEED / speed
        self.vx *= cap
        self.vy *= cap
    end

    self.x += self.vx * dt
    self.y += self.vy * dt
    self.x, self.y = wrap_position(self.x, self.y)

    if self.invuln_timer > 0 then
        self.invuln_timer = max(0, self.invuln_timer - dt)
    end
end

function Ship:draw()
    if not self.alive then
        return
    end

    if self:is_invulnerable() and flr(time() * 10) % 2 == 0 then
        return
    end

    local dirx = cos(self.angle)
    local diry = sin(self.angle)
    local leftx = cos(self.angle + 0.5)
    local lefty = sin(self.angle + 0.5)

    local nose_x = self.x + dirx * (SHIP_HEIGHT / 2)
    local nose_y = self.y + diry * (SHIP_HEIGHT / 2)
    local rear_x = self.x - dirx * (SHIP_HEIGHT / 2)
    local rear_y = self.y - diry * (SHIP_HEIGHT / 2)

    local v1x = rear_x + leftx * SHIP_HALF_BASE
    local v1y = rear_y + lefty * SHIP_HALF_BASE
    local v2x = rear_x - leftx * SHIP_HALF_BASE
    local v2y = rear_y - lefty * SHIP_HALF_BASE

    line(nose_x, nose_y, v1x, v1y, WHITE)
    line(v1x, v1y, v2x, v2y, WHITE)
    line(v2x, v2y, nose_x, nose_y, WHITE)

    if self.thrusting then
        local flame_cx = rear_x - dirx * 3
        local flame_cy = rear_y - diry * 3
        local side = 5
        local half_h = side * 0.8660254 / 2
        local fx1 = flame_cx + leftx * (side / 2)
        local fy1 = flame_cy + lefty * (side / 2)
        local fx2 = flame_cx - leftx * (side / 2)
        local fy2 = flame_cy - lefty * (side / 2)
        local fx3 = flame_cx - dirx * (half_h * 2)
        local fy3 = flame_cy - diry * (half_h * 2)
        line(fx1, fy1, fx2, fy2, RED)
        line(fx2, fy2, fx3, fy3, RED)
        line(fx3, fy3, fx1, fy1, RED)
    end
end

local Bullet = {}

function Bullet.new(x, y, angle, speed, color, radius)
    local self = {
        x = x,
        y = y,
        vx = cos(angle) * speed,
        vy = sin(angle) * speed,
        distance = 0,
        max_distance = PLAYER_BULLET_MAX_DIST,
        color = color or ORANGE,
        radius = radius or PLAYER_BULLET_RADIUS,
        alive = true,
    }
    setmetatable(self, { __index = Bullet })
    return self
end

function Bullet:update(dt)
    if not self.alive then
        return
    end

    local dx = self.vx * dt
    local dy = self.vy * dt
    self.x += dx
    self.y += dy
    self.distance += sqrt(dx * dx + dy * dy)
    self.x, self.y = wrap_position(self.x, self.y)

    if self.distance >= self.max_distance then
        self.alive = false
    end
end

function Bullet:draw()
    if self.alive then
        circfill(self.x, self.y, self.radius, self.color)
    end
end

local Asteroid = {}

function Asteroid.new(x, y, size)
    local angle = rnd(1)
    local speed = rand_range(5, 10)
    local self = {
        x = x,
        y = y,
        vx = cos(angle) * speed,
        vy = sin(angle) * speed,
        size = size,
        radius = ASTEROID_RADIUS[size],
        alive = true,
    }
    setmetatable(self, { __index = Asteroid })
    return self
end

function Asteroid:update(dt)
    if not self.alive then
        return
    end

    self.x += self.vx * dt
    self.y += self.vy * dt
    self.x, self.y = wrap_position(self.x, self.y)
end

function Asteroid:draw()
    if self.alive then
        circ(self.x, self.y, self.radius, WHITE)
    end
end

local UFO = {}

function UFO.new(from_left)
    local y = rand_range(16, WORLD_SIZE - 16)
    local vx = from_left and UFO_SPEED or -UFO_SPEED
    local x = from_left and 0 or WORLD_SIZE - 1
    local self = {
        x = x,
        y = y,
        vx = vx,
        radius = UFO_RADIUS,
        fire_timer = rand_range(UFO_FIRE_MIN, UFO_FIRE_MAX),
        lifetime = 14,
        alive = true,
    }
    setmetatable(self, { __index = UFO })
    return self
end

function UFO:update(dt, screen)
    if not self.alive then
        return
    end

    self.x += self.vx * dt
    self.x, self.y = wrap_position(self.x, self.y)
    self.lifetime -= dt

    if self.lifetime <= 0 then
        self.alive = false
        return
    end

    self.fire_timer -= dt
    if self.fire_timer <= 0 then
        self.fire_timer = rand_range(UFO_FIRE_MIN, UFO_FIRE_MAX)
        local angle = rnd(1)
        local bullet = Bullet.new(self.x, self.y, angle, UFO_BULLET_SPEED, GREEN, UFO_BULLET_RADIUS)
        bullet.max_distance = WORLD_SIZE
        add(screen.enemy_bullets, bullet)
    end
end

function UFO:draw()
    if not self.alive then
        return
    end

    circ(self.x, self.y, 5, LIGHT_GRAY)
    line(self.x - 6, self.y, self.x + 6, self.y, LIGHT_GRAY)
    line(self.x - 4, self.y - 3, self.x + 4, self.y - 3, WHITE)
    line(self.x - 4, self.y + 3, self.x + 4, self.y + 3, WHITE)
end

function GameScreen.new()
    local self = {
        isDone = false,
        ship = Ship.new(64, 64),
        asteroids = {},
        bullets = {},
        enemy_bullets = {},
        ufos = {},
        lives = 3,
        score = 0,
        wave = 1,
        wave_timer = 0,
        fire_cooldown = 0,
        ufo_spawn_timer = rand_range(UFO_SPAWN_MIN, UFO_SPAWN_MAX),
        game_over = false,
    }
    setmetatable(self, { __index = GameScreen })
    self:spawn_wave()
    return self
end

function GameScreen:spawn_wave()
    self.wave_timer = 0
    for i = 1, WAVE_ASTEROID_COUNT do
        local x = rnd(WORLD_SIZE)
        local y = rnd(WORLD_SIZE)
        while torus_distance(x, y, self.ship.x, self.ship.y) < ASTEROID_SAFE_DIST do
            x = rnd(WORLD_SIZE)
            y = rnd(WORLD_SIZE)
        end
        add(self.asteroids, Asteroid.new(x, y, ASTEROID_SIZE_LARGE))
    end
end

function GameScreen:spawn_ufo()
    if #self.ufos == 0 then
        add(self.ufos, UFO.new(rnd(1) < 0.5))
    end
end

function GameScreen:kill_ship()
    if not self.ship.alive or self.ship:is_invulnerable() then
        return
    end

    self.ship:destroy()
    self.lives -= 1

    if self.lives > 0 then
        self.ship:reset(64, 64)
    else
        self.game_over = true
    end
end

function GameScreen:fire_player_bullet()
    if self.fire_cooldown > 0 or not self.ship.alive then
        return
    end

    local bx, by = self.ship:nose_position()
    local bullet = Bullet.new(bx, by, self.ship.angle, PLAYER_BULLET_SPEED, ORANGE, PLAYER_BULLET_RADIUS)
    add(self.bullets, bullet)
    self.fire_cooldown = PLAYER_FIRE_COOLDOWN
end

function GameScreen:split_asteroid(asteroid)
    local next_size = asteroid.size - 1
    if next_size < ASTEROID_SIZE_SMALL then
        return
    end
    add(self.asteroids, Asteroid.new(asteroid.x, asteroid.y, next_size))
    add(self.asteroids, Asteroid.new(asteroid.x, asteroid.y, next_size))
end

function GameScreen:cleanup_dead(list)
    for obj in all(list) do
        if not obj.alive then
            del(list, obj)
        end
    end
end

function GameScreen:handle_collisions()
    for bullet in all(self.bullets) do
        if bullet.alive then
            for asteroid in all(self.asteroids) do
                if asteroid.alive and circles_collide(bullet.x, bullet.y, bullet.radius, asteroid.x, asteroid.y, asteroid.radius) then
                    bullet.alive = false
                    asteroid.alive = false
                    self.score += ASTEROID_SCORE[asteroid.size]
                    self:split_asteroid(asteroid)
                    break
                end
            end

            if bullet.alive then
                for ufo in all(self.ufos) do
                    if ufo.alive and circles_collide(bullet.x, bullet.y, bullet.radius, ufo.x, ufo.y, ufo.radius) then
                        bullet.alive = false
                        ufo.alive = false
                        self.score += 100
                        break
                    end
                end
            end
        end
    end

    for ebullet in all(self.enemy_bullets) do
        if ebullet.alive then
            for asteroid in all(self.asteroids) do
                if asteroid.alive and circles_collide(ebullet.x, ebullet.y, ebullet.radius, asteroid.x, asteroid.y, asteroid.radius) then
                    ebullet.alive = false
                    asteroid.alive = false
                    self:split_asteroid(asteroid)
                    break
                end
            end
        end
    end

    if self.ship.alive and not self.ship:is_invulnerable() then
        for asteroid in all(self.asteroids) do
            if asteroid.alive and circles_collide(self.ship.x, self.ship.y, self.ship.radius, asteroid.x, asteroid.y, asteroid.radius) then
                self:kill_ship()
                break
            end
        end

        if self.ship.alive then
            for ebullet in all(self.enemy_bullets) do
                if ebullet.alive and circles_collide(self.ship.x, self.ship.y, self.ship.radius, ebullet.x, ebullet.y, ebullet.radius) then
                    ebullet.alive = false
                    self:kill_ship()
                    break
                end
            end
        end
    end

    if self.ship.alive then
        for ufo in all(self.ufos) do
            if ufo.alive and circles_collide(self.ship.x, self.ship.y, self.ship.radius, ufo.x, ufo.y, ufo.radius) then
                ufo.alive = false
                self:kill_ship()
                break
            end
        end
    end
end

function GameScreen:update()
    local dt = DT

    if self.game_over then
        if buttonWasPressed(BUTTON_O) then
            self.isDone = true
        end
        return
    end

    if self.fire_cooldown > 0 then
        self.fire_cooldown = max(0, self.fire_cooldown - dt)
    end

    self.ship:update(dt)

    if buttonWasPressed(BUTTON_O) then
        self:fire_player_bullet()
    end

    for asteroid in all(self.asteroids) do
        asteroid:update(dt)
    end

    for bullet in all(self.bullets) do
        bullet:update(dt)
    end

    for ebullet in all(self.enemy_bullets) do
        ebullet:update(dt)
    end

    for ufo in all(self.ufos) do
        ufo:update(dt, self)
    end

    self:handle_collisions()

    self:cleanup_dead(self.asteroids)
    self:cleanup_dead(self.bullets)
    self:cleanup_dead(self.enemy_bullets)
    self:cleanup_dead(self.ufos)

    if #self.asteroids == 0 then
        self.wave_timer += dt
        if self.wave_timer >= WAVE_DELAY then
            self.wave += 1
            self:spawn_wave()
        end
    else
        self.wave_timer = 0
    end

    self.ufo_spawn_timer -= dt
    if self.ufo_spawn_timer <= 0 then
        self:spawn_ufo()
        self.ufo_spawn_timer = rand_range(UFO_SPAWN_MIN, UFO_SPAWN_MAX)
    end
end

function GameScreen:draw_life_icon(x, y)
    local h = 8
    local half_b = h * 0.26795
    local nose_x, nose_y = x, y - h / 2
    local rear_y = y + h / 2
    line(nose_x, nose_y, x - half_b, rear_y, WHITE)
    line(x - half_b, rear_y, x + half_b, rear_y, WHITE)
    line(x + half_b, rear_y, nose_x, nose_y, WHITE)
end

function GameScreen:draw_ui()
    print("score " .. self.score, 82, 4, WHITE)
    for i = 1, self.lives do
        self:draw_life_icon(8 + (i - 1) * 10, 8)
    end
end

function GameScreen:draw()
    cls(BLACK)

    for asteroid in all(self.asteroids) do
        asteroid:draw()
    end

    for bullet in all(self.bullets) do
        bullet:draw()
    end

    for ebullet in all(self.enemy_bullets) do
        ebullet:draw()
    end

    for ufo in all(self.ufos) do
        ufo:draw()
    end

    self.ship:draw()
    self:draw_ui()

    if self.game_over then
        print("game over", 47, 56, RED)
        print("press O", 44, 66, LIGHT_GRAY)
    end
end
