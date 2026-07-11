import "CoreLibs/graphics"
import "tests"
import "field"
import "render"
import "shots"

playdate.display.setRefreshRate(30)

Render.init()
if playdate.isSimulator then
    runTests()
end

function playdate.update()
    local dt = playdate.getElapsedTime()
    playdate.resetElapsedTime()
    if dt <= 0 or dt > 0.25 then
        dt = 1 / 30
    end
    Render.draw(dt)
    Shots.update(dt)
end
