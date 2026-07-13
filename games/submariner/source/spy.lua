import "geom"

local BEARING_TOLERANCE = 6
local HOLD_DURATION = 0.7
local FLASH_DURATION = 1.0

local function boatsOfType(kind)
    local out = {}
    for _, b in ipairs(World.boats) do
        if (kind == nil and b.type ~= "sub") or b.type == kind then
            out[#out + 1] = b
        end
    end
    return out
end

-- "lighthouse" is first so the game's opening target is a stationary
-- landmark — easy for a first-time player, and deterministic to test.
local CATEGORIES = {
    { name = "lighthouse",  above = true,  entities = function() return { World.lighthouse } end },
    { name = "boat",        above = true,  entities = function() return boatsOfType(nil) end },
    { name = "submarine",   above = true,  entities = function() return boatsOfType("sub") end },
    { name = "plane",       above = true,  entities = function() return World.planes end },
    { name = "helicopter",  above = true,  entities = function() return World.helicopters end },
    { name = "fish school", above = false, entities = function() return World.schools end },
    { name = "shark",       above = false, entities = function() return World.sharks end },
    { name = "whale",       above = false, entities = function() return World.whales end },
}

Spy = {
    FLASH_DURATION = FLASH_DURATION,
    targetIndex = 1,
    target = CATEGORIES[1].name,
    holdProgress = 0,
    foundNow = false,
    flashTimer = FLASH_DURATION,
}

local function pickNewTarget()
    local nextIndex = Spy.targetIndex
    if #CATEGORIES > 1 then
        repeat
            nextIndex = math.random(#CATEGORIES)
        until nextIndex ~= Spy.targetIndex
    end
    Spy.targetIndex = nextIndex
    Spy.target = CATEGORIES[nextIndex].name
    Spy.holdProgress = 0
end

function Spy.init()
    Spy.targetIndex = 1
    Spy.target = CATEGORIES[1].name
    Spy.holdProgress = 0
    Spy.flashTimer = FLASH_DURATION
end

function Spy.update(dt)
    Spy.foundNow = false

    if Spy.flashTimer < FLASH_DURATION then
        Spy.flashTimer = Spy.flashTimer + dt
        if Spy.flashTimer >= FLASH_DURATION then
            pickNewTarget()
        end
        return
    end

    local cat = CATEGORIES[Spy.targetIndex]
    local wy = Geom.waterlineY(Scope.height, Render.CENTER_Y, Render.SWING)
    local visible
    if cat.above then
        visible = Geom.aboveVisible(wy, Render.CENTER_Y, Render.RADIUS)
    else
        visible = Geom.belowVisible(wy, Render.CENTER_Y, Render.RADIUS)
    end

    local aligned = false
    if visible then
        for _, e in ipairs(cat.entities()) do
            if Geom.bearingAligned(e.bearing, Scope.bearing, BEARING_TOLERANCE) then
                aligned = true
                break
            end
        end
    end

    if aligned then
        Spy.holdProgress = Geom.clamp(Spy.holdProgress + dt / HOLD_DURATION, 0, 1)
        if Spy.holdProgress >= 1 then
            Spy.foundNow = true
            Spy.flashTimer = 0
            Spy.holdProgress = 0
        end
    else
        Spy.holdProgress = 0
    end
end
