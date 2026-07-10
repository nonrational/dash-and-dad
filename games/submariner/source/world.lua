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
end

function World.update(dt)
    for _, b in ipairs(World.boats) do
        b.bearing = Geom.wrap360(b.bearing + b.dir * World.LANES[b.lane].drift * dt)
        b.bobPhase = b.bobPhase + dt * 1.6
    end
    for _, c in ipairs(World.clouds) do
        c.bearing = Geom.wrap360(c.bearing + c.drift * dt)
    end
end
