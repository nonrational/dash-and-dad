import "geom"

function runTests()
    local function eq(actual, expected, msg)
        if math.abs(actual - expected) > 1e-9 then
            error(string.format("FAIL %s: expected %s, got %s",
                msg, tostring(expected), tostring(actual)))
        end
    end

    eq(Geom.clamp(5, 0, 1), 1, "clamp high")
    eq(Geom.clamp(-5, 0, 1), 0, "clamp low")
    eq(Geom.clamp(0.5, 0, 1), 0.5, "clamp inside")

    eq(Geom.lerp(0, 10, 0), 0, "lerp at 0")
    eq(Geom.lerp(0, 10, 1), 10, "lerp at 1")
    eq(Geom.lerp(0, 10, 0.5), 5, "lerp at midpoint")
    eq(Geom.lerp(10, 0, 0.25), 7.5, "lerp descending")

    eq(Geom.flickPower(1800, 1800, 0.5, 1.0), 1.0, "flick power at reference velocity")
    eq(Geom.flickPower(900, 1800, 0.5, 1.0), 0.5, "flick power at threshold velocity")
    eq(Geom.flickPower(3600, 1800, 0.5, 1.0), 1.0, "flick power clamped at max")

    eq(Geom.shotFlightTime(0.5, 0.5, 1.0, 0.55, 0.22), 0.55, "shot time at min power")
    eq(Geom.shotFlightTime(1.0, 0.5, 1.0, 0.55, 0.22), 0.22, "shot time at max power")
    eq(Geom.shotFlightTime(0.75, 0.5, 1.0, 0.55, 0.22), 0.385, "shot time at half power")

    eq(Geom.goalieSpeed(0, 60, 4, 100), 60, "goalie speed at streak 0")
    eq(Geom.goalieSpeed(5, 60, 4, 100), 80, "goalie speed ramping")
    eq(Geom.goalieSpeed(50, 60, 4, 100), 100, "goalie speed capped")

    print("geom tests: all passed")
end
