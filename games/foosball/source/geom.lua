Geom = {}

function Geom.clamp(v, lo, hi)
    if v < lo then
        return lo
    elseif v > hi then
        return hi
    end
    return v
end

function Geom.lerp(a, b, t)
    return a + (b - a) * t
end

-- True if x is within halfWidth of center — used both for "is the player
-- close enough to the ball to make contact" and "is the goalie close enough
-- to the shot's target to save it."
function Geom.inBand(x, center, halfWidth)
    return math.abs(x - center) <= halfWidth
end

-- Normalizes a measured crank angular velocity against a reference velocity
-- that maps to full power, clamped to [minPower, maxPower].
function Geom.flickPower(velocityDegPerSec, referenceVelocity, minPower, maxPower)
    return Geom.clamp(velocityDegPerSec / referenceVelocity, minPower, maxPower)
end

-- Harder shots (higher power) fly faster: this lerps from timeAtMin (at
-- powerMin) to timeAtMax (at powerMax).
function Geom.shotFlightTime(power, powerMin, powerMax, timeAtMin, timeAtMax)
    local t = (power - powerMin) / (powerMax - powerMin)
    return Geom.lerp(timeAtMin, timeAtMax, t)
end

-- Goalie reaction speed ramps with streak, capped at a max.
function Geom.goalieSpeed(streak, base, ramp, cap)
    return math.min(base + ramp * streak, cap)
end
