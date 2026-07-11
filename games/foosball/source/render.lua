import "CoreLibs/graphics"
import "geom"
import "field"
import "player"

local gfx = playdate.graphics

Render = {}

-- setDitherPattern's alpha runs backwards for black ink (0 = solid black),
-- so express everything as "darkness" in [0,1] and invert here.
local function setInk(darkness)
    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(1 - darkness, gfx.image.kDitherTypeBayer8x8)
end

function Render.init()
end

local NEAR_LEFT, NEAR_RIGHT = Field.TRACK_MIN - 30, Field.TRACK_MAX + 30
local FAR_LEFT, FAR_RIGHT = Field.GOAL_MIN - 20, Field.GOAL_MAX + 20

local function drawPitch()
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(2)
    gfx.drawLine(NEAR_LEFT, 240, FAR_LEFT, Field.GOAL_Y)
    gfx.drawLine(NEAR_RIGHT, 240, FAR_RIGHT, Field.GOAL_Y)
    gfx.setLineWidth(1)
end

local function drawGoal()
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(Field.GOAL_MIN, Field.GOAL_Y - 22, Field.GOAL_MAX - Field.GOAL_MIN, 22)
    setInk(0.15)
    gfx.fillRect(Field.GOAL_MIN, Field.GOAL_Y - 22, Field.GOAL_MAX - Field.GOAL_MIN, 22)
end

local function drawPlayerMarker()
    gfx.setColor(gfx.kColorBlack)
    local x, y = Player.x, Field.PLAYER_Y
    gfx.fillCircleAtPoint(x, y - 14, 8)
    gfx.fillTriangle(x - 12, y + 20, x + 12, y + 20, x, y - 4)
end

function Render.draw(dt)
    gfx.clear(gfx.kColorWhite)
    drawPitch()
    drawGoal()
    drawPlayerMarker()
end
