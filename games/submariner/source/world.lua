import "geom"

World = {
    LANES = {
        far  = { scale = 0.45, yOff = 0,  drift = 1.1 },
        mid  = { scale = 0.7,  yOff = 5,  drift = 2.0 },
        near = { scale = 1.0,  yOff = 11, drift = 3.2 },
    },
    boats = {},
    clouds = {},
    lighthouse = { bearing = 305 },
}

function World.init()
    World.boats = {
        { type = "sail",    lane = "near", bearing = 40,  dir = 1,  bobPhase = 0.0 },
        { type = "trawler", lane = "mid",  bearing = 130, dir = -1, bobPhase = 1.3 },
        { type = "cargo",   lane = "far",  bearing = 205, dir = 1,  bobPhase = 2.6 },
        { type = "sail",    lane = "far",  bearing = 255, dir = -1, bobPhase = 3.9 },
        { type = "trawler", lane = "near", bearing = 335, dir = 1,  bobPhase = 5.2 },
    }
    World.clouds = {
        { bearing = 20,  above = 62, w = 46, drift = 0.5 },
        { bearing = 150, above = 78, w = 64, drift = 0.35 },
        { bearing = 280, above = 55, w = 38, drift = 0.6 },
    }
    World.schools = {
        { bearing = 70,  depth = 45, dir = 1,  speed = 6,   count = 6 },
        { bearing = 220, depth = 95, dir = -1, speed = 4.5, count = 5 },
    }
    for _, s in ipairs(World.schools) do
        s.members = {}
        for i = 1, s.count do
            s.members[i] = {
                dBearing = i * 3.5 - (s.count + 1) * 1.75,
                dDepth = ((i * 7) % 20) - 10,
                phase = i * 0.9,
            }
        end
    end
    World.fish = {
        { bearing = 150, depth = 140, dir = 1,  speed = 2.2, size = 2.2, phase = 0 },
        { bearing = 20,  depth = 170, dir = -1, speed = 1.6, size = 2.8, phase = 2 },
    }
    World.bubbles = {}
    for _, colBearing in ipairs({ 95, 185, 300 }) do
        for i = 1, 5 do
            World.bubbles[#World.bubbles + 1] = {
                bearing = colBearing,
                depth = 30 + i * 34,
                r = 1 + (i % 3),
                wobble = i * 1.1,
            }
        end
    end
end

function World.update(dt)
    for _, b in ipairs(World.boats) do
        b.bearing = Geom.wrap360(b.bearing + b.dir * World.LANES[b.lane].drift * dt)
        b.bobPhase = b.bobPhase + dt * 1.6
    end
    for _, c in ipairs(World.clouds) do
        c.bearing = Geom.wrap360(c.bearing + c.drift * dt)
    end
    for _, s in ipairs(World.schools) do
        s.bearing = Geom.wrap360(s.bearing + s.dir * s.speed * dt)
        for _, m in ipairs(s.members) do
            m.phase = m.phase + dt * 6
        end
    end
    for _, f in ipairs(World.fish) do
        f.bearing = Geom.wrap360(f.bearing + f.dir * f.speed * dt)
        f.phase = f.phase + dt * 3
    end
    for _, bub in ipairs(World.bubbles) do
        bub.depth = bub.depth - dt * 22
        bub.wobble = bub.wobble + dt * 4
        if bub.depth < 4 then
            bub.depth = 175
        end
    end
end
