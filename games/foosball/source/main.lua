import "CoreLibs/graphics"
import "tests"
import "field"
import "player"
import "render"
import "shots"

playdate.display.setRefreshRate(30)

Render.init()
Player.init()
if playdate.isSimulator then
    runTests()
end

function playdate.update()
    local dt = playdate.getElapsedTime()
    playdate.resetElapsedTime()
    if dt <= 0 or dt > 0.25 then
        dt = 1 / 30
    end
    Player.update(dt)
    Render.draw(dt)
    Shots.update(dt)
end
