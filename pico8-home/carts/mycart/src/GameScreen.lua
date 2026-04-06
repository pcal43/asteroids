
GameScreen = {}

function GameScreen.new()
    local self = {
        isDone = false,

        -- ship state
        ship_x = 64,
        ship_y = 64,
        ship_angle_deg = 270,
        ship_vx = 0,
        ship_vy = 0,

        -- game state
        score = 0,
        shots = {},
        asteroids = {},
        asteroid_spawn_timer = 0,
    }
    setmetatable(self, { __index = GameScreen })

    for i = 1, 5 do
        add(self.asteroids, {
            x = rnd(128),
            y = rnd(128),
            size = "large",
            vx = 0,
            vy = 0,
        })
        local a = self.asteroids[#self.asteroids]
        local ang = rnd(1)
        local speed = 1 + rnd(4)
        a.vx = cos(ang) * speed
        a.vy = sin(ang) * speed
    end

    return self
end

function GameScreen:update()
    local dt = 1 / 30

    -- rotate ship in 5 degree increments
    if buttonWasPressed(BUTTON_LEFT) then
        self.ship_angle_deg -= 5
    end
    if buttonWasPressed(BUTTON_RIGHT) then
        self.ship_angle_deg += 5
    end
    self.ship_angle_deg %= 360

    local heading_turns = self.ship_angle_deg / 360
    local dir_x = cos(heading_turns)
    local dir_y = sin(heading_turns)

    -- thrust adds forward momentum, idle applies mild drag
    if btn(BUTTON_X) then
        self.ship_vx += dir_x * 5 * dt
        self.ship_vy += dir_y * 5 * dt
    else
        local speed = sqrt(self.ship_vx * self.ship_vx + self.ship_vy * self.ship_vy)
        if speed > 0 then
            local new_speed = max(0, speed - 1 * dt)
            if new_speed == 0 then
                self.ship_vx = 0
                self.ship_vy = 0
            else
                local k = new_speed / speed
                self.ship_vx *= k
                self.ship_vy *= k
            end
        end
    end

    -- ship movement with screen wrapping
    self.ship_x += self.ship_vx * dt
    self.ship_y += self.ship_vy * dt
    if self.ship_x < 0 then self.ship_x += 128 end
    if self.ship_x >= 128 then self.ship_x -= 128 end
    if self.ship_y < 0 then self.ship_y += 128 end
    if self.ship_y >= 128 then self.ship_y -= 128 end

    -- fire from ship nose on O press
    if buttonWasPressed(BUTTON_O) then
        add(self.shots, {
            x = self.ship_x + dir_x * 8,
            y = self.ship_y + dir_y * 8,
            vx = dir_x * 10,
            vy = dir_y * 10,
            dist = 0,
            max_dist = 64,
        })
    end

    -- update shots, remove after 64 px traveled
    for i = #self.shots, 1, -1 do
        local shot = self.shots[i]
        local dx = shot.vx * dt
        local dy = shot.vy * dt
        shot.x += dx
        shot.y += dy
        shot.dist += sqrt(dx * dx + dy * dy)

        if shot.x < 0 then shot.x += 128 end
        if shot.x >= 128 then shot.x -= 128 end
        if shot.y < 0 then shot.y += 128 end
        if shot.y >= 128 then shot.y -= 128 end

        if shot.dist >= shot.max_dist then
            deli(self.shots, i)
        end
    end

    -- randomly materialize additional asteroids over time
    self.asteroid_spawn_timer += dt
    if self.asteroid_spawn_timer >= 2 and #self.asteroids < 12 then
        self.asteroid_spawn_timer = 0
        local ang = rnd(1)
        local speed = 1 + rnd(4)
        add(self.asteroids, {
            x = rnd(128),
            y = rnd(128),
            size = "large",
            vx = cos(ang) * speed,
            vy = sin(ang) * speed,
        })
    end

    -- move asteroids
    for asteroid in all(self.asteroids) do
        asteroid.x += asteroid.vx * dt
        asteroid.y += asteroid.vy * dt
        if asteroid.x < 0 then asteroid.x += 128 end
        if asteroid.x >= 128 then asteroid.x -= 128 end
        if asteroid.y < 0 then asteroid.y += 128 end
        if asteroid.y >= 128 then asteroid.y -= 128 end
    end

    -- shot/asteroid collisions and splitting
    for si = #self.shots, 1, -1 do
        local shot = self.shots[si]
        local hit = false

        for ai = #self.asteroids, 1, -1 do
            local asteroid = self.asteroids[ai]
            local r = asteroid.size == "large" and 8 or (asteroid.size == "medium" and 6 or 4)
            local dx = shot.x - asteroid.x
            local dy = shot.y - asteroid.y

            if dx * dx + dy * dy <= (r + 1) * (r + 1) then
                deli(self.shots, si)
                hit = true

                if asteroid.size == "large" then
                    self.score += 10
                elseif asteroid.size == "medium" then
                    self.score += 20
                else
                    self.score += 30
                end

                local old_x = asteroid.x
                local old_y = asteroid.y
                local next_size = nil
                if asteroid.size == "large" then
                    next_size = "medium"
                elseif asteroid.size == "medium" then
                    next_size = "small"
                end

                deli(self.asteroids, ai)

                if next_size then
                    for k = 1, 2 do
                        local ang = rnd(1)
                        local speed = 1 + rnd(4)
                        add(self.asteroids, {
                            x = old_x,
                            y = old_y,
                            size = next_size,
                            vx = cos(ang) * speed,
                            vy = sin(ang) * speed,
                        })
                    end
                end

                break
            end
        end

        if hit then
            -- shot already removed
        end
    end

    -- ship/asteroid collision ends run and returns to title
    for asteroid in all(self.asteroids) do
        local r = asteroid.size == "large" and 8 or (asteroid.size == "medium" and 6 or 4)
        local dx = self.ship_x - asteroid.x
        local dy = self.ship_y - asteroid.y
        if dx * dx + dy * dy <= (r + 6) * (r + 6) then
            self.isDone = true
            break
        end
    end
end

function GameScreen:draw()
    cls(BLACK)

    -- draw asteroids as circles
    for asteroid in all(self.asteroids) do
        local r = asteroid.size == "large" and 8 or (asteroid.size == "medium" and 6 or 4)
        circ(asteroid.x, asteroid.y, r, LIGHT_GRAY)
    end

    -- draw shots as tiny circles
    for shot in all(self.shots) do
        circ(shot.x, shot.y, 1, WHITE)
    end

    -- draw ship as an isosceles triangle with 30 degree nose angle
    local heading_turns = self.ship_angle_deg / 360
    local fx = cos(heading_turns)
    local fy = sin(heading_turns)
    local px = -fy
    local py = fx

    local nose_x = self.ship_x + fx * 8
    local nose_y = self.ship_y + fy * 8
    local base_cx = self.ship_x - fx * 6
    local base_cy = self.ship_y - fy * 6
    local base_half_w = 3.75

    local left_x = base_cx + px * base_half_w
    local left_y = base_cy + py * base_half_w
    local right_x = base_cx - px * base_half_w
    local right_y = base_cy - py * base_half_w

    line(nose_x, nose_y, left_x, left_y, WHITE)
    line(nose_x, nose_y, right_x, right_y, WHITE)
    line(left_x, left_y, right_x, right_y, WHITE)

    -- score in upper-right corner
    local score_text = "score:" .. self.score
    print(score_text, 128 - #score_text * 4, 2, WHITE)
end
