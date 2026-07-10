import "CoreLibs/graphics"
import "CoreLibs/ui"
import "tests"
import "scope"
import "world"
import "render"
import "ambience"
import "shots"

playdate.display.setRefreshRate(30)

Render.init()
World.init()
Ambience.init()
if playdate.isSimulator then
    runTests()
end

function playdate.update()
    local dt = playdate.getElapsedTime()
    playdate.resetElapsedTime()
    if dt <= 0 or dt > 0.25 then
        dt = 1 / 30
    end
    Scope.update(dt)
    World.update(dt)
    Render.draw(dt)
    Ambience.update(dt)
    if playdate.isCrankDocked() then
        playdate.ui.crankIndicator:draw()
    end
    Shots.update(dt)
end
