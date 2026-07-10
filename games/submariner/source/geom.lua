Geom = {}

-- Wraps an angle to [0, 360).
function Geom.wrap360(deg)
    return deg % 360
end

-- Signed shortest angular distance from `from` to `to`, in (-180, 180].
function Geom.wrappedDelta(from, to)
    local d = (to - from) % 360
    if d > 180 then
        d = d - 360
    end
    return d
end

function Geom.clamp(v, lo, hi)
    if v < lo then
        return lo
    elseif v > hi then
        return hi
    end
    return v
end

-- Screen x for an entity at entityBearing seen from scopeBearing.
function Geom.bearingToScreenX(entityBearing, scopeBearing, centerX, pxPerDegree)
    return centerX + Geom.wrappedDelta(scopeBearing, entityBearing) * pxPerDegree
end

-- Screen y of the waterline. Raised scope (height +1) pushes the line down
-- (more sky); submerged (-1) pushes it above the eyepiece (all water).
function Geom.waterlineY(height, centerY, swing)
    return centerY + height * swing
end

-- Above-water ambience volume in [0,1]; below-water volume is 1 - mix.
function Geom.crossfadeMix(height)
    return Geom.clamp(0.5 + height * 2, 0, 1)
end

-- D-pad rotation speed: 25 deg/s ramping to 55 deg/s over 0.5 s of hold.
function Geom.rotationSpeed(holdSeconds)
    return 25 + 30 * Geom.clamp(holdSeconds / 0.5, 0, 1)
end
