
local SCREEN_W = 128
local SCREEN_H = 128
local DT = 1 / 30

local SHIP_HEIGHT = 8
local SHIP_HALF_NOSE_ANGLE = 15 / 360
local SHIP_HALF_BASE = SHIP_HEIGHT * 0.26794919243 -- tan(15deg)
local SHIP_THRUST_ACCEL = 20
local SHIP_DAMPING = 1
local SHIP_MAX_SPEED = 20
local SHIP_ROT_SPEED = 180 / 360

local BULLET_SPEED = 20
local BULLET_MAX_DISTANCE = 64
local BULLET_RADIUS = 1
local BULLET_COOLDOWN = 0.2

local UFO_SPEED = 15
local UFO_BULLET_SPEED = 16

local ASTEROID_RADIUS_BY_SIZE = {
    large = 8,
    medium = 6,
    small = 4,
}

local ASTEROID_POINTS_BY_SIZE = {
    large = 10,
    medium = 20,
    small = 30,
}

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function wrap_coord(v, limit)
    if v < 0 then
        v += limit
    elseif v >= limit then
        v -= limit
    end
    return v
end

local function wrap_position(obj)
    obj.x = wrap_coord(obj.x, SCREEN_W)
    obj.y = wrap_coord(obj.y, SCREEN_H)
end

local function torus_delta(a, b, limit)
    local d = b - a
    if d > limit / 2 then
        d -= limit
    elseif d < -limit / 2 then
        d += limit
    end
    return d
end

local function torus_dist_sq(x1, y1, x2, y2)
    local dx = torus_delta(x1, x2, SCREEN_W)
    local dy = torus_delta(y1, y2, SCREEN_H)
    return dx * dx + dy * dy
end

local function circles_collide(x1, y1, r1, x2, y2, r2)
    local rr = r1 + r2
    return torus_dist_sq(x1, y1, x2, y2) <= rr * rr
end

local function forward_vec(angle)
    return cos(angle), sin(angle)
end

local function random_angle()
    return rnd(1)
end

local Ship = {}
Ship.__index = Ship

function Ship.new(x, y)
    return setmetatable({
        x = x,
        y = y,
        vx = 0,
        vy = 0,
        angle = 0.75, -- up
        radius = SHIP_HEIGHT,
        fireCooldown = 0,
        thrusting = false,
        invulnTimer = 0,
    }, Ship)
end

function Ship:get_nose_position()
    local fx, fy = forward_vec(self.angle)
    return self.x + fx * SHIP_HEIGHT, self.y + fy * SHIP_HEIGHT
end

function Ship:update(dt)
    if btn(BUTTON_RIGHT) then
        self.angle += SHIP_ROT_SPEED * dt
    end
    if btn(BUTTON_LEFT) then
        self.angle -= SHIP_ROT_SPEED * dt
    end

    local fx, fy = forward_vec(self.angle)
    self.thrusting = btn(BUTTON_X)

    if self.thrusting then
        self.vx += fx * SHIP_THRUST_ACCEL * dt
        self.vy += fy * SHIP_THRUST_ACCEL * dt
    else
        local speed = sqrt(self.vx * self.vx + self.vy * self.vy)
        if speed > 0 then
            local decel = SHIP_DAMPING * dt
            if decel >= speed then
                self.vx = 0
                self.vy = 0
            else
                local nx = self.vx / speed
                local ny = self.vy / speed
                self.vx -= nx * decel
                self.vy -= ny * decel
            end
        end
    end

    local speed = sqrt(self.vx * self.vx + self.vy * self.vy)
    if speed > SHIP_MAX_SPEED then
        local s = SHIP_MAX_SPEED / speed
        self.vx *= s
        self.vy *= s
    end

    self.x += self.vx * dt
    self.y += self.vy * dt
    wrap_position(self)

    self.fireCooldown = max(0, self.fireCooldown - dt)
    self.invulnTimer = max(0, self.invulnTimer - dt)
end

function Ship:can_fire()
    return self.fireCooldown <= 0
end

function Ship:consume_fire_cooldown()
    self.fireCooldown = BULLET_COOLDOWN
end

function Ship:is_invulnerable()
    return self.invulnTimer > 0
end

function Ship:draw()
    local fx, fy = forward_vec(self.angle)
    local bx = self.x - fx * SHIP_HEIGHT
    local by = self.y - fy * SHIP_HEIGHT

    local px, py = -fy, fx

    local nose_x = self.x + fx * SHIP_HEIGHT
    local nose_y = self.y + fy * SHIP_HEIGHT
    local left_x = bx + px * SHIP_HALF_BASE
    local left_y = by + py * SHIP_HALF_BASE
    local right_x = bx - px * SHIP_HALF_BASE
    local right_y = by - py * SHIP_HALF_BASE

    if not self:is_invulnerable() or (flr(time() * 12) % 2 == 0) then
        line(nose_x, nose_y, left_x, left_y, WHITE)
        line(left_x, left_y, right_x, right_y, WHITE)
        line(right_x, right_y, nose_x, nose_y, WHITE)
    end

    if self.thrusting then
        local cx = bx - fx * 2
        local cy = by - fy * 2
        local side = 3
        local h = side * 0.86602540378
        local tip_x = cx - fx * h
        local tip_y = cy - fy * h
        local lb_x = cx + px * (side / 2)
        local lb_y = cy + py * (side / 2)
        local rb_x = cx - px * (side / 2)
        local rb_y = cy - py * (side / 2)
        line(tip_x, tip_y, lb_x, lb_y, RED)
        line(lb_x, lb_y, rb_x, rb_y, RED)
        line(rb_x, rb_y, tip_x, tip_y, RED)
    end
end

local Bullet = {}
Bullet.__index = Bullet

function Bullet.new(x, y, angle, speed, color, owner)
    local fx, fy = forward_vec(angle)
    return setmetatable({
        x = x,
        y = y,
        vx = fx * speed,
        vy = fy * speed,
        distance = 0,
        maxDistance = BULLET_MAX_DISTANCE,
        radius = BULLET_RADIUS,
        color = color,
        owner = owner,
        dead = false,
    }, Bullet)
end

function Bullet:update(dt)
    local dx = self.vx * dt
    local dy = self.vy * dt
    self.x += dx
    self.y += dy
    self.distance += sqrt(dx * dx + dy * dy)
    wrap_position(self)

    if self.distance >= self.maxDistance then
        self.dead = true
    end
end

function Bullet:draw()
    circfill(self.x, self.y, self.radius, self.color)
end

local Asteroid = {}
Asteroid.__index = Asteroid

function Asteroid.new(x, y, size)
    local angle = random_angle()
    local speed = 5 + rnd(5)
    local fx, fy = forward_vec(angle)
    return setmetatable({
        x = x,
        y = y,
        vx = fx * speed,
        vy = fy * speed,
        size = size,
        radius = ASTEROID_RADIUS_BY_SIZE[size],
        dead = false,
    }, Asteroid)
end

function Asteroid:update(dt)
    self.x += self.vx * dt
    self.y += self.vy * dt
    wrap_position(self)
end

function Asteroid:draw()
    circ(self.x, self.y, self.radius, WHITE)
end

function Asteroid:split_children()
    if self.size == "large" then
        return "medium", 2
    elseif self.size == "medium" then
        return "small", 2
    end
    return nil, 0
end

local UFO = {}
UFO.__index = UFO

function UFO.new()
    local dir = rnd(1) < 0.5 and 1 or -1
    local x = dir == 1 and -6 or SCREEN_W + 6
    local y = 12 + rnd(SCREEN_H - 24)
    return setmetatable({
        x = x,
        y = y,
        vx = UFO_SPEED * dir,
        vy = 0,
        width = 10,
        height = 5,
        radius = 5,
        fireTimer = 1 + rnd(1),
        lifeTimer = 12,
        dead = false,
    }, UFO)
end

function UFO:update(dt)
    self.x += self.vx * dt
    self.y += self.vy * dt
    wrap_position(self)

    self.fireTimer -= dt
    self.lifeTimer -= dt
    if self.lifeTimer <= 0 then
        self.dead = true
    end
end

function UFO:draw()
    local x1 = self.x - self.width / 2
    local x2 = self.x + self.width / 2
    local y1 = self.y - self.height / 2
    local y2 = self.y + self.height / 2
    line(x1, y1, x2, y1, GREEN)
    line(x2, y1, x2, y2, GREEN)
    line(x2, y2, x1, y2, GREEN)
    line(x1, y2, x1, y1, GREEN)
end

GameScreen = {}

function GameScreen.new()
    local self = {
        isDone = false,
        ship = Ship.new(SCREEN_W / 2, SCREEN_H / 2),
        shipExplosion = nil,
        bullets = {},
        enemyBullets = {},
        asteroids = {},
        ufos = {},
        lives = 3,
        score = 0,
        respawnTimer = 0,
        waveTimer = 0,
        ufoSpawnTimer = 30 + rnd(30),
        gameOver = false,
    }

    setmetatable(self, { __index = GameScreen })
    self:spawn_asteroid_wave(10)
    return self
end

function GameScreen:spawn_asteroid_wave(count)
    local cx = SCREEN_W / 2
    local cy = SCREEN_H / 2
    local spawned = 0

    while spawned < count do
        local x = rnd(SCREEN_W)
        local y = rnd(SCREEN_H)
        if torus_dist_sq(x, y, cx, cy) >= 20 * 20 then
            add(self.asteroids, Asteroid.new(x, y, "large"))
            spawned += 1
        end
    end
end

function GameScreen:spawn_ship_if_safe()
    if self.ship or self.lives <= 0 then
        return
    end

    local sx = SCREEN_W / 2
    local sy = SCREEN_H / 2
    for asteroid in all(self.asteroids) do
        if circles_collide(sx, sy, 30, asteroid.x, asteroid.y, asteroid.radius) then
            return
        end
    end

    self.ship = Ship.new(sx, sy)
    self.ship.invulnTimer = 2
end

function GameScreen:kill_ship()
    if not self.ship then
        return
    end

    self.shipExplosion = {
        x = self.ship.x,
        y = self.ship.y,
        timer = 0.6,
        duration = 0.6,
    }

    self.ship = nil
    self.lives -= 1

    if self.lives <= 0 then
        self.gameOver = true
    else
        self.respawnTimer = 3
    end
end

function GameScreen:spawn_player_bullet()
    local ship = self.ship
    if not ship or not ship:can_fire() then
        return
    end
    local bx, by = ship:get_nose_position()
    add(self.bullets, Bullet.new(bx, by, ship.angle, BULLET_SPEED, ORANGE, "player"))
    ship:consume_fire_cooldown()
end

function GameScreen:spawn_ufo_bullet(ufo)
    local angle = random_angle()
    add(self.enemyBullets, Bullet.new(ufo.x, ufo.y, angle, UFO_BULLET_SPEED, GREEN, "ufo"))
end

function GameScreen:split_asteroid(asteroid)
    local childSize, count = asteroid:split_children()
    if childSize then
        for i = 1, count do
            local child = Asteroid.new(asteroid.x, asteroid.y, childSize)
            add(self.asteroids, child)
        end
    end
end

function GameScreen:destroy_asteroid(asteroid, awardPoints)
    if asteroid.dead then
        return
    end
    asteroid.dead = true
    self:split_asteroid(asteroid)
    if awardPoints then
        self.score += ASTEROID_POINTS_BY_SIZE[asteroid.size]
    end
end

function GameScreen:update_ship(dt)
    if not self.ship then
        return
    end

    self.ship:update(dt)

    if buttonWasPressed(BUTTON_O) then
        self:spawn_player_bullet()
    end
end

function GameScreen:update_asteroids(dt)
    for asteroid in all(self.asteroids) do
        asteroid:update(dt)
    end
end

function GameScreen:update_bullets(dt)
    for bullet in all(self.bullets) do
        bullet:update(dt)
    end
    for bullet in all(self.enemyBullets) do
        bullet:update(dt)
    end

    for i = #self.bullets, 1, -1 do
        if self.bullets[i].dead then
            deli(self.bullets, i)
        end
    end

    for i = #self.enemyBullets, 1, -1 do
        if self.enemyBullets[i].dead then
            deli(self.enemyBullets, i)
        end
    end
end

function GameScreen:update_ufos(dt)
    self.ufoSpawnTimer -= dt
    if self.ufoSpawnTimer <= 0 then
        add(self.ufos, UFO.new())
        self.ufoSpawnTimer = 30 + rnd(30)
    end

    for ufo in all(self.ufos) do
        ufo:update(dt)
        if ufo.fireTimer <= 0 then
            self:spawn_ufo_bullet(ufo)
            ufo.fireTimer = 1 + rnd(1)
        end
    end

    for i = #self.ufos, 1, -1 do
        if self.ufos[i].dead then
            deli(self.ufos, i)
        end
    end
end

function GameScreen:handle_collisions()
    for bullet in all(self.bullets) do
        if not bullet.dead then
            for asteroid in all(self.asteroids) do
                if not asteroid.dead and circles_collide(bullet.x, bullet.y, bullet.radius, asteroid.x, asteroid.y, asteroid.radius) then
                    bullet.dead = true
                    self:destroy_asteroid(asteroid, true)
                    break
                end
            end
        end
    end

    for bullet in all(self.enemyBullets) do
        if not bullet.dead then
            for asteroid in all(self.asteroids) do
                if not asteroid.dead and circles_collide(bullet.x, bullet.y, bullet.radius, asteroid.x, asteroid.y, asteroid.radius) then
                    bullet.dead = true
                    self:destroy_asteroid(asteroid, false)
                    break
                end
            end
        end
    end

    for bullet in all(self.bullets) do
        if not bullet.dead then
            for ufo in all(self.ufos) do
                if not ufo.dead and circles_collide(bullet.x, bullet.y, bullet.radius, ufo.x, ufo.y, ufo.radius) then
                    bullet.dead = true
                    ufo.dead = true
                    self.score += 100
                    break
                end
            end
        end
    end

    if self.ship and not self.ship:is_invulnerable() then
        for asteroid in all(self.asteroids) do
            if not asteroid.dead and circles_collide(self.ship.x, self.ship.y, self.ship.radius, asteroid.x, asteroid.y, asteroid.radius) then
                self:kill_ship()
                break
            end
        end
    end

    if self.ship and not self.ship:is_invulnerable() then
        for bullet in all(self.enemyBullets) do
            if not bullet.dead and circles_collide(self.ship.x, self.ship.y, self.ship.radius, bullet.x, bullet.y, bullet.radius) then
                bullet.dead = true
                self:kill_ship()
                break
            end
        end
    end

    if self.ship and not self.ship:is_invulnerable() then
        for ufo in all(self.ufos) do
            if not ufo.dead and circles_collide(self.ship.x, self.ship.y, self.ship.radius, ufo.x, ufo.y, ufo.radius) then
                ufo.dead = true
                self:kill_ship()
                break
            end
        end
    end

    for i = #self.asteroids, 1, -1 do
        if self.asteroids[i].dead then
            deli(self.asteroids, i)
        end
    end
end

function GameScreen:update_timers(dt)
    if self.shipExplosion then
        self.shipExplosion.timer -= dt
        if self.shipExplosion.timer <= 0 then
            self.shipExplosion = nil
        end
    end

    if not self.ship and not self.gameOver and self.lives > 0 then
        if self.respawnTimer > 0 then
            self.respawnTimer = max(0, self.respawnTimer - dt)
        else
            self:spawn_ship_if_safe()
        end
    end

    if #self.asteroids == 0 then
        self.waveTimer += dt
        if self.waveTimer >= 3 then
            self.waveTimer = 0
            self:spawn_asteroid_wave(10)
        end
    else
        self.waveTimer = 0
    end
end

function GameScreen:update()
    local dt = DT

    self:update_ship(dt)
    self:update_asteroids(dt)
    self:update_bullets(dt)
    self:update_ufos(dt)
    self:handle_collisions()
    self:update_timers(dt)
end

function GameScreen:draw_ship_explosion()
    if not self.shipExplosion then
        return
    end

    local t = 1 - (self.shipExplosion.timer / self.shipExplosion.duration)
    local r = 2 + t * 10
    local x = self.shipExplosion.x
    local y = self.shipExplosion.y

    circ(x, y, r, RED)
    line(x - r, y - r, x + r, y + r, ORANGE)
    line(x - r, y + r, x + r, y - r, ORANGE)
end

function GameScreen:draw_lives()
    local icon_h = 4
    local icon_half_base = icon_h * 0.26794919243
    for i = 1, self.lives do
        local cx = 8 + (i - 1) * 10
        local cy = 8
        local nose_x = cx
        local nose_y = cy - icon_h
        local left_x = cx - icon_half_base
        local left_y = cy + icon_h
        local right_x = cx + icon_half_base
        local right_y = cy + icon_h
        line(nose_x, nose_y, left_x, left_y, WHITE)
        line(left_x, left_y, right_x, right_y, WHITE)
        line(right_x, right_y, nose_x, nose_y, WHITE)
    end
end

function GameScreen:draw_hud()
    self:draw_lives()

    local scoreText = "score " .. flr(self.score)
    print(scoreText, SCREEN_W - #scoreText * 4 - 1, 2, WHITE)

    if self.gameOver then
        print("game over", 45, 60, RED)
    end
end

function GameScreen:draw()
    cls(BLACK)

    for asteroid in all(self.asteroids) do
        asteroid:draw()
    end

    for ufo in all(self.ufos) do
        ufo:draw()
    end

    for bullet in all(self.bullets) do
        bullet:draw()
    end

    for bullet in all(self.enemyBullets) do
        bullet:draw()
    end

    if self.ship then
        self.ship:draw()
    end

    self:draw_ship_explosion()
    self:draw_hud()
end
