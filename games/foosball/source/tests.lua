import "geom"

function runTests()
    local function eq(actual, expected, msg)
        if math.abs(actual - expected) > 1e-9 then
            error(string.format("FAIL %s: expected %s, got %s",
                msg, tostring(expected), tostring(actual)))
        end
    end

    local function ok(cond, msg)
        if not cond then
            error(string.format("FAIL %s: expected true", msg))
        end
    end

    eq(Geom.clamp(5, 0, 1), 1, "clamp high")
    eq(Geom.clamp(-5, 0, 1), 0, "clamp low")
    eq(Geom.clamp(0.5, 0, 1), 0.5, "clamp inside")

    eq(Geom.lerp(0, 10, 0), 0, "lerp at 0")
    eq(Geom.lerp(0, 10, 1), 10, "lerp at 1")
    eq(Geom.lerp(0, 10, 0.5), 5, "lerp at midpoint")
    eq(Geom.lerp(10, 0, 0.25), 7.5, "lerp descending")

    ok(Geom.inBand(100, 100, 45), "inBand at center")
    ok(Geom.inBand(145, 100, 45), "inBand exactly at boundary")
    ok(not Geom.inBand(146, 100, 45), "inBand just outside boundary")

    eq(Geom.flickPower(1800, 1800, 0.5, 1.0), 1.0, "flick power at reference velocity")
    eq(Geom.flickPower(900, 1800, 0.5, 1.0), 0.5, "flick power at threshold velocity")
    eq(Geom.flickPower(3600, 1800, 0.5, 1.0), 1.0, "flick power clamped at max")

    eq(Geom.shotFlightTime(0.5, 0.5, 1.0, 0.55, 0.22), 0.55, "shot time at min power")
    eq(Geom.shotFlightTime(1.0, 0.5, 1.0, 0.55, 0.22), 0.22, "shot time at max power")
    eq(Geom.shotFlightTime(0.75, 0.5, 1.0, 0.55, 0.22), 0.385, "shot time at half power")

    eq(Geom.goalieSpeed(0, 60, 4, 100), 60, "goalie speed at streak 0")
    eq(Geom.goalieSpeed(5, 60, 4, 100), 80, "goalie speed ramping")
    eq(Geom.goalieSpeed(50, 60, 4, 100), 100, "goalie speed capped")

    -- projectX: screen x of a track-space x at depth d (0 = player track,
    -- 1 = goal line), here mapping the real spans [50,350] -> [140,260].
    eq(Geom.projectX(200, 0, 50, 350, 140, 260), 200, "projectX identity at depth 0")
    eq(Geom.projectX(50, 1, 50, 350, 140, 260), 140, "projectX track min to goal min")
    eq(Geom.projectX(350, 1, 50, 350, 140, 260), 260, "projectX track max to goal max")
    eq(Geom.projectX(200, 1, 50, 350, 140, 260), 200, "projectX center is a fixed point")
    eq(Geom.projectX(60, 1, 50, 350, 140, 260), 144, "projectX wide lane at goal line")
    eq(Geom.projectX(60, 0.5, 50, 350, 140, 260), 102, "projectX wide lane at mid depth")
    eq(Geom.projectX(20, -0.25, 50, 350, 140, 260), -7, "projectX extrapolates below depth 0")

    print("geom tests: all passed")
end
