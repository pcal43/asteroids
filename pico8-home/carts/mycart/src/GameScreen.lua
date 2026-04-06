
GameScreen = {}

function GameScreen.new()
    local self = {
    }
    setmetatable(self, { __index = GameScreen })
    return self
end

function GameScreen:update()
    -- update the game state
end

function GameScreen:draw()
    cls(BLACK)
    -- draw the game state
end
