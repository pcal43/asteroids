-- shared gameplay constants

--[[const]] SCREEN_W = 128
--[[const]] SCREEN_H = 128
--[[const]] SCREEN_CX = 64
--[[const]] SCREEN_CY = 64
--[[const]] FRAME_DT = 1 / 30

--[[const]] TITLE_FLASH_PERIOD = 0.5
--[[const]] TITLE_FLASH_ON_TIME = 0.3
--[[const]] TITLE_SCALE = 2
--[[const]] TITLE_X = 8
--[[const]] TITLE_Y = 24
--[[const]] PROMPT_START_X = 34
--[[const]] PROMPT_START_Y = 106
--[[const]] PROMPT_CONTINUE_X = 30
--[[const]] PROMPT_CONTINUE_Y = 106
--[[const]] VERSION_X = 110
--[[const]] VERSION_Y = 121

--[[const]] COLOR_BACKGROUND = BLACK
--[[const]] COLOR_SHIP = WHITE
--[[const]] COLOR_SHIP_THRUST = ORANGE
--[[const]] COLOR_ASTEROID = WHITE
--[[const]] COLOR_PLAYER_BULLET = ORANGE
--[[const]] COLOR_UFO = GREEN
--[[const]] COLOR_UFO_BULLET = GREEN
--[[const]] COLOR_EXPLOSION = RED
--[[const]] COLOR_HUD_TEXT = WHITE
--[[const]] COLOR_GAMEOVER_TEXT = RED
--[[const]] COLOR_VERSION = DARK_GRAY
--[[const]] COLOR_TITLE = WHITE
--[[const]] COLOR_LIFE_ICON = WHITE

--[[const]] SHIP_START_X = 64
--[[const]] SHIP_START_Y = 64
--[[const]] SHIP_START_ANGLE = 0.25
--[[const]] SHIP_ROTATE_DEG_PER_SEC = 270
--[[const]] SHIP_ROTATE_TURNS_PER_SEC = SHIP_ROTATE_DEG_PER_SEC / 360
--[[const]] SHIP_THRUST_ACCEL = 50
--[[const]] SHIP_DAMP_PER_SEC = 1
--[[const]] SHIP_MAX_SPEED = 30
--[[const]] SHIP_COLLISION_RADIUS = 4
--[[const]] SHIP_TRIANGLE_ALTITUDE = 8
--[[const]] SHIP_NOSE_HALF_ANGLE_TAN = 0.41421356237
--[[const]] SHIP_THRUST_FLAME_SIDE = 4

--[[const]] PLAYER_BULLET_SPEED = 50
--[[const]] PLAYER_BULLET_MAX_DISTANCE = 64
--[[const]] PLAYER_BULLET_RADIUS = 1
--[[const]] PLAYER_FIRE_COOLDOWN = 0.2

--[[const]] UFO_BULLET_SPEED = 50
--[[const]] UFO_BULLET_RADIUS = 1
--[[const]] UFO_FIRE_MIN_DELAY = 1
--[[const]] UFO_FIRE_MAX_DELAY = 2

--[[const]] INITIAL_LIVES = 3
--[[const]] EXTRA_LIFE_SCORE_STEP = 10000
--[[const]] RESPAWN_DELAY = 3
--[[const]] RESPAWN_INVULN_TIME = 5
--[[const]] GAME_OVER_PROMPT_DELAY = 3
--[[const]] SPAWN_EDGE_MARGIN = 16
--[[const]] SPAWN_ASTEROID_CLEARANCE = 16

--[[const]] INITIAL_WAVE_ASTEROIDS = 6
--[[const]] MAX_WAVE_ASTEROIDS = 10
--[[const]] NEXT_WAVE_DELAY = 3
--[[const]] INITIAL_CENTER_SAFE_DISTANCE = 20
--[[const]] WAVE_SPAWN_SAFE_DISTANCE_FROM_SHIP = 30

--[[const]] ASTEROID_SPEED_MIN = 5
--[[const]] ASTEROID_SPEED_MAX = 10
--[[const]] ASTEROID_SPIN_DEG_MAX = 90
--[[const]] ASTEROID_SPIN_TURNS_MAX = ASTEROID_SPIN_DEG_MAX / 360
--[[const]] ASTEROID_VERTS_MIN = 6
--[[const]] ASTEROID_VERTS_MAX = 10
--[[const]] ASTEROID_RADIUS_JITTER = 0.25
--[[const]] ASTEROID_ANGLE_JITTER = 0.02
--[[const]] ASTEROID_LARGE_RADIUS = 8
--[[const]] ASTEROID_MEDIUM_RADIUS = 6
--[[const]] ASTEROID_SMALL_RADIUS = 4

--[[const]] SCORE_ASTEROID_LARGE = 25
--[[const]] SCORE_ASTEROID_MEDIUM = 50
--[[const]] SCORE_ASTEROID_SMALL = 100
--[[const]] SCORE_UFO = 500

--[[const]] UFO_SPEED = 15
--[[const]] UFO_WIDTH = 14
--[[const]] UFO_HEIGHT = 5
--[[const]] UFO_DOME_WIDTH = 7
--[[const]] UFO_DOME_HEIGHT = 3
--[[const]] UFO_DOME_Y_OFFSET = 3
--[[const]] UFO_COLLISION_RADIUS = 5
--[[const]] UFO_SPAWN_MIN_DELAY = 15
--[[const]] UFO_SPAWN_MAX_DELAY = 30
--[[const]] UFO_SPAWN_SAFE_DISTANCE = 20
--[[const]] UFO_MIN_Y = 12
--[[const]] UFO_MAX_Y = 116

--[[const]] EXPLOSION_DURATION = 0.5
--[[const]] EXPLOSION_RADIUS_START = 1
--[[const]] EXPLOSION_RADIUS_END = 10
--[[const]] EXPLOSION_LINE_START = 2
--[[const]] EXPLOSION_LINE_END = 12

--[[const]] HUD_SCORE_X = 78
--[[const]] HUD_SCORE_Y = 2
--[[const]] HUD_LIVES_X = 2
--[[const]] HUD_LIVES_Y = 5
--[[const]] HUD_LIVES_SPACING = 7

--[[const]] SHIP_INVULN_BLINK_HZ = 12

--[[const]] CADENCE_INTERVAL_SLOW = 2
--[[const]] CADENCE_INTERVAL_FAST = 0.5

--[[const]] SFX_CADENCE_A = 0
--[[const]] SFX_CADENCE_B = 1
--[[const]] SFX_FIRE = 2
--[[const]] SFX_HIT = 3
--[[const]] SFX_THRUST = 4
--[[const]] SFX_UFO_LOOP = 5
--[[const]] SFX_EXTRA_LIFE = 6

--[[const]] SFX_CHANNEL_CADENCE = 0
--[[const]] SFX_CHANNEL_THRUST = 1
--[[const]] SFX_CHANNEL_UFO = 2
--[[const]] SFX_CHANNEL_FX = 3

local v = split(VERSION,".")
--[[const]] VERSION_STRING = v[1].."\-f.\-f"..v[2].."\-f.\-f"..v[3]