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

--[[const]] SHIP_START_X = 64
--[[const]] SHIP_START_Y = 64
--[[const]] SHIP_START_ANGLE = 0.25
--[[const]] SHIP_ROTATE_DEG_PER_SEC = 180
--[[const]] SHIP_ROTATE_TURNS_PER_SEC = SHIP_ROTATE_DEG_PER_SEC / 360
--[[const]] SHIP_THRUST_ACCEL = 30
--[[const]] SHIP_DAMP_PER_SEC = 1
--[[const]] SHIP_MAX_SPEED = 20
--[[const]] SHIP_COLLISION_RADIUS = 4
--[[const]] SHIP_TRIANGLE_ALTITUDE = 8
--[[const]] SHIP_NOSE_HALF_ANGLE_TAN = 0.41421356237
--[[const]] SHIP_THRUST_FLAME_SIDE = 4

--[[const]] PLAYER_BULLET_SPEED = 40
--[[const]] PLAYER_BULLET_MAX_DISTANCE = 64
--[[const]] PLAYER_BULLET_RADIUS = 1
--[[const]] PLAYER_FIRE_COOLDOWN = 0.2

--[[const]] UFO_BULLET_SPEED = 40
--[[const]] UFO_BULLET_RADIUS = 1
--[[const]] UFO_FIRE_MIN_DELAY = 1
--[[const]] UFO_FIRE_MAX_DELAY = 2

--[[const]] INITIAL_LIVES = 3
--[[const]] EXTRA_LIFE_SCORE_STEP = 10000
--[[const]] RESPAWN_DELAY = 3
--[[const]] RESPAWN_INVULN_TIME = 5
--[[const]] RESPAWN_SAFE_DISTANCE = 5

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

--[[const]] SCORE_ASTEROID_LARGE = 10
--[[const]] SCORE_ASTEROID_MEDIUM = 20
--[[const]] SCORE_ASTEROID_SMALL = 30
--[[const]] SCORE_UFO = 100

--[[const]] UFO_SPEED = 15
--[[const]] UFO_WIDTH = 12
--[[const]] UFO_HEIGHT = 6
--[[const]] UFO_COLLISION_RADIUS = 5
--[[const]] UFO_SPAWN_MIN_DELAY = 30
--[[const]] UFO_SPAWN_MAX_DELAY = 60
--[[const]] UFO_SPAWN_SAFE_DISTANCE = 20
--[[const]] UFO_MIN_Y = 12
--[[const]] UFO_MAX_Y = 116

--[[const]] EXPLOSION_DURATION = 0.5
--[[const]] EXPLOSION_RADIUS_START = 1
--[[const]] EXPLOSION_RADIUS_END = 10
--[[const]] EXPLOSION_LINE_START = 2
--[[const]] EXPLOSION_LINE_END = 12

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
