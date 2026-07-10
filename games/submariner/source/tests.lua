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

    eq(Geom.wrap360(370), 10, "wrap360 over")
    eq(Geom.wrap360(-10), 350, "wrap360 negative")
    eq(Geom.wrap360(360), 0, "wrap360 exact")

    eq(Geom.wrappedDelta(350, 10), 20, "delta across zero")
    eq(Geom.wrappedDelta(10, 350), -20, "delta across zero, negative")
    eq(Geom.wrappedDelta(0, 180), 180, "delta opposite side")

    eq(Geom.clamp(5, 0, 1), 1, "clamp high")
    eq(Geom.clamp(-5, 0, 1), 0, "clamp low")
    eq(Geom.clamp(0.5, 0, 1), 0.5, "clamp inside")

    -- entity 10 deg clockwise of scope appears right of center: 200 + 10*3.5
    eq(Geom.bearingToScreenX(57, 47, 200, 3.5), 235, "entity right of scope")
    eq(Geom.bearingToScreenX(355, 5, 200, 3.5), 165, "entity left across zero")

    -- raised scope pushes the line below the circle; submerged above it
    eq(Geom.waterlineY(1, 110, 120), 230, "waterline fully raised")
    eq(Geom.waterlineY(-1, 110, 120), -10, "waterline fully submerged")
    eq(Geom.waterlineY(0, 110, 120), 110, "waterline at lens")

    eq(Geom.crossfadeMix(0), 0.5, "mix at surface")
    eq(Geom.crossfadeMix(0.3), 1, "mix fully above")
    eq(Geom.crossfadeMix(-0.3), 0, "mix fully below")

    eq(Geom.rotationSpeed(0), 25, "rotation base speed")
    eq(Geom.rotationSpeed(0.5), 55, "rotation fully ramped")
    eq(Geom.rotationSpeed(2), 55, "rotation capped")

    ok(Geom.bearingAligned(50, 47, 6), "bearing aligned within tolerance")
    ok(not Geom.bearingAligned(60, 47, 6), "bearing outside tolerance")
    ok(Geom.bearingAligned(2, 358, 6), "bearing aligned across zero wrap")

    ok(Geom.aboveVisible(50, 110, 104), "above visible when waterline below circle top")
    ok(not Geom.aboveVisible(-10, 110, 104), "above not visible when waterline above circle")

    ok(Geom.belowVisible(150, 110, 104), "below visible when waterline above circle bottom")
    ok(not Geom.belowVisible(230, 110, 104), "below not visible when waterline below circle")

    print("geom tests: all passed")
end
