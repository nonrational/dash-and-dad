import "CoreLibs/graphics"
import "geom"

local gfx = playdate.graphics

Render = {
    CENTER_X = 200,
    CENTER_Y = 110,
    RADIUS = 104,
    PX_PER_DEG = 3.5,
    SWING = 120,
}

local mask = nil
local t = 0

-- setDitherPattern's alpha runs backwards for black ink (0 = solid black),
-- so express everything as "darkness" in [0,1] and invert here.
local function setInk(darkness)
    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(1 - darkness, gfx.image.kDitherTypeBayer8x8)
end

function Render.init()
    -- The image must be created clear: Playdate images only carry an alpha
    -- mask when built on a transparent background, so punching kColorClear
    -- into a black-background image is a no-op and the mask stays opaque.
    mask = gfx.image.new(400, 240, gfx.kColorClear)
    gfx.pushContext(mask)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, 400, 240)
    gfx.setColor(gfx.kColorClear)
    gfx.fillCircleAtPoint(Render.CENTER_X, Render.CENTER_Y, Render.RADIUS)
    gfx.popContext()
end

local function waterY()
    return Geom.waterlineY(Scope.height, Render.CENTER_Y, Render.SWING)
end

-- Light surface tint below the line, with short wave strokes that hug the
-- line and drift with time and bearing so the sea feels world-locked.
local function drawSea(wy)
    setInk(0.12)
    gfx.fillRect(0, wy, 400, 240 - wy)
    gfx.setColor(gfx.kColorBlack)
    for row = 1, 5 do
        local y = wy + 8 + row * 14
        local phase = (t * (14 - row * 2) + row * 53
            - Scope.bearing * Render.PX_PER_DEG) % 40
        for x = 96 - phase, 304, 40 do
            gfx.drawLine(x, y, x + 12 - row, y)
        end
    end
end

-- Boat silhouettes. (x, y) is the hull baseline center; dir = ±1 facing.
local function drawSail(x, y, s, dir)
    local function px(dx) return x + dx * s * dir end
    gfx.setColor(gfx.kColorBlack)
    gfx.fillPolygon(px(-14), y, px(12), y, px(15), y - 4 * s, px(-16), y - 4 * s)
    gfx.drawLine(px(0), y - 4 * s, px(0), y - 30 * s)
    gfx.fillTriangle(px(1), y - 29 * s, px(13), y - 6 * s, px(1), y - 6 * s)
    gfx.fillTriangle(px(-1), y - 26 * s, px(-11), y - 6 * s, px(-1), y - 6 * s)
end

local function drawTrawler(x, y, s, dir)
    local function px(dx) return x + dx * s * dir end
    gfx.setColor(gfx.kColorBlack)
    gfx.fillPolygon(px(-16), y - 8 * s, px(16), y - 8 * s, px(13), y, px(-14), y)
    gfx.fillRect(math.min(px(-11), px(1)), y - 16 * s, 12 * s, 8 * s)
    gfx.drawLine(px(7), y - 8 * s, px(7), y - 22 * s)
    gfx.drawLine(px(7), y - 20 * s, px(14), y - 12 * s)
end

local function drawCargo(x, y, s, dir)
    local function px(dx) return x + dx * s * dir end
    gfx.setColor(gfx.kColorBlack)
    gfx.fillPolygon(px(-24), y - 7 * s, px(24), y - 7 * s, px(21), y, px(-22), y)
    gfx.fillRect(math.min(px(14), px(20)), y - 16 * s, 6 * s, 9 * s)
    gfx.fillRect(math.min(px(-18), px(8)), y - 12 * s, 26 * s, 5 * s)
    gfx.drawLine(px(17), y - 16 * s, px(17), y - 19 * s)
end

local BOAT_DRAWERS = { sail = drawSail, trawler = drawTrawler, cargo = drawCargo }
local LANE_ORDER = { "far", "mid", "near" }

local function drawLighthouse(x, y)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillPolygon(x - 3, y - 22, x + 3, y - 22, x + 5, y, x - 5, y)
    gfx.fillRect(x - 4, y - 27, 8, 5)
end

local function drawClouds(wy)
    setInk(0.4)
    for _, c in ipairs(World.clouds) do
        local x = Geom.bearingToScreenX(c.bearing, Scope.bearing,
            Render.CENTER_X, Render.PX_PER_DEG)
        if x > -60 and x < 460 then
            gfx.fillEllipseInRect(x - c.w / 2, wy - c.above, c.w, 14)
            gfx.fillEllipseInRect(x - c.w / 4, wy - c.above - 7, c.w / 2, 12)
        end
    end
end

-- Everything above the waterline, clipped to it so hulls sit "in" the water.
local function drawAbove(wy)
    gfx.setClipRect(0, 0, 400, wy)
    drawClouds(wy)
    local lx = Geom.bearingToScreenX(World.lighthouse.bearing, Scope.bearing,
        Render.CENTER_X, Render.PX_PER_DEG)
    if lx > -40 and lx < 440 then
        drawLighthouse(lx, wy)
    end
    for _, laneName in ipairs(LANE_ORDER) do
        local lane = World.LANES[laneName]
        -- Extend the clip by the lane's dip so the lower hull stays visible
        -- below the line (the sea tint and chop draw over it afterwards);
        -- clipping exactly at wy would swallow near-lane hulls entirely.
        gfx.setClipRect(0, 0, 400, wy + lane.yOff)
        for _, b in ipairs(World.boats) do
            if b.lane == laneName then
                local x = Geom.bearingToScreenX(b.bearing, Scope.bearing,
                    Render.CENTER_X, Render.PX_PER_DEG)
                if x > -80 and x < 480 then
                    local y = wy + lane.yOff
                        + math.sin(b.bobPhase) * 1.5 * lane.scale
                    BOAT_DRAWERS[b.type](x, y, lane.scale, b.dir)
                end
            end
        end
    end
    gfx.clearClipRect()
end

-- Fish: ellipse body plus a two-frame flapping tail.
local function drawFish(x, y, s, dir, phase)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillEllipseInRect(x - 5 * s, y - 2 * s, 10 * s, 4 * s)
    local up = (math.sin(phase) > 0) and 3 or 1
    local tx = x - 5 * s * dir
    gfx.fillTriangle(tx, y,
        tx - 4 * s * dir, y - up * s,
        tx - 4 * s * dir, y + (4 - up) * s)
end

local function drawLightRays(wy)
    if Scope.height < -0.6 then
        return
    end
    setInk(0.18)
    for i = -2, 2 do
        local x = Render.CENTER_X + i * 38 + math.sin(t * 0.4 + i) * 6
        gfx.fillPolygon(x - 3, wy, x + 3, wy, x + 14, wy + 90, x + 2, wy + 90)
    end
end

local function drawBubbles(wy)
    gfx.setColor(gfx.kColorBlack)
    for _, bub in ipairs(World.bubbles) do
        local x = Geom.bearingToScreenX(bub.bearing, Scope.bearing,
            Render.CENTER_X, Render.PX_PER_DEG) + math.sin(bub.wobble) * 3
        if x > -10 and x < 410 then
            gfx.drawCircleAtPoint(x, wy + bub.depth, bub.r)
        end
    end
end

-- Depth murk drawn over the fish so they dim as the scope sinks.
local function drawMurk(wy)
    local darkness = Geom.clamp(-Scope.height, 0, 1) * 0.5
    if darkness > 0.03 then
        setInk(darkness)
        gfx.fillRect(0, math.max(wy, 0), 400, 240)
    end
end

local function drawBelow(wy)
    gfx.setClipRect(0, math.max(wy + 1, 0), 400, 240)
    drawLightRays(wy)
    drawBubbles(wy)
    for _, s in ipairs(World.schools) do
        for _, m in ipairs(s.members) do
            local x = Geom.bearingToScreenX(s.bearing + m.dBearing, Scope.bearing,
                Render.CENTER_X, Render.PX_PER_DEG)
            if x > -20 and x < 420 then
                local y = wy + s.depth + m.dDepth + math.sin(m.phase * 0.5) * 2
                drawFish(x, y, 1, s.dir, m.phase)
            end
        end
    end
    for _, f in ipairs(World.fish) do
        local x = Geom.bearingToScreenX(f.bearing, Scope.bearing,
            Render.CENTER_X, Render.PX_PER_DEG)
        if x > -30 and x < 430 then
            local y = wy + f.depth + math.sin(f.phase * 0.4) * 3
            drawFish(x, y, f.size, f.dir, f.phase)
        end
    end
    drawMurk(wy)
    gfx.clearClipRect()
end

-- Water streaks sliding down the lens just after it breaks the surface.
-- Fixed jitter tables keep it deterministic (no math.random in the loop).
local DROPLET_XS = { -70, -52, -31, -12, 4, 22, 47, 68, 86 }

local function drawDroplets(progress)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(2)
    for i, dx in ipairs(DROPLET_XS) do
        local stagger = (i % 3) * 0.12
        local p = Geom.clamp((progress - stagger) / (1 - stagger), 0, 1)
        if p > 0 then
            local x = Render.CENTER_X + dx
            local y0 = Render.CENTER_Y - Render.RADIUS
                + p * p * 150 + (i * 17) % 40
            gfx.drawLine(x, y0, x, y0 + 10 + (i % 4) * 3)
        end
    end
    gfx.setLineWidth(1)
end

local function drawWaterline(wy)
    gfx.setColor(gfx.kColorBlack)
    for x = 92, 308, 2 do
        local y = wy + math.sin(x * 0.08 + t * 3) * 2
        gfx.fillRect(x, y, 2, 2)
    end
end

local function drawCrosshairs()
    local cx, cy, r = Render.CENTER_X, Render.CENTER_Y, Render.RADIUS
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(1)
    gfx.drawLine(cx, cy - r, cx, cy - 6)
    gfx.drawLine(cx, cy + 6, cx, cy + r)
    gfx.drawLine(cx - r, cy, cx - 6, cy)
    gfx.drawLine(cx + 6, cy, cx + r, cy)
    for i = -4, 4 do
        if i ~= 0 then
            local x = cx + i * 20
            gfx.drawLine(x, cy - 3, x, cy + 3)
        end
    end
end

local function drawHUD()
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    local brg = math.floor(Scope.bearing + 0.5) % 360
    gfx.drawTextAligned(string.format("BRG %03d", brg),
        Render.CENTER_X, 220, kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function Render.draw(dt)
    t = t + dt
    gfx.clear(gfx.kColorWhite)
    local wy = waterY()
    if wy > Render.CENTER_Y - Render.RADIUS then
        drawAbove(wy)
    end
    if wy < Render.CENTER_Y + Render.RADIUS then
        drawSea(wy)
        drawBelow(wy)
    end
    drawWaterline(wy)
    local sp = Scope.surfacedProgress()
    if sp then
        drawDroplets(sp)
    end
    mask:draw(0, 0)
    drawCrosshairs()
    drawHUD()
end
