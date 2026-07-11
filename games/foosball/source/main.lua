import "CoreLibs/graphics"
import "CoreLibs/ui"
import "tests"
import "field"
import "player"
import "ball"
import "goalie"
import "render"
import "shots"

playdate.display.setRefreshRate(30)
math.randomseed(playdate.getSecondsSinceEpoch())

Render.init()
Player.init()
Ball.init()
Goalie.init()
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
    Ball.update(dt)
    Goalie.update(dt, 0) -- streak wiring lands in Task 8
    if Ball.state == "flightComplete" then
        Ball.resolve(Goalie.x)
    end
    Render.draw(dt)
    Shots.update(dt)
    if playdate.isCrankDocked() then
        playdate.ui.crankIndicator:draw()
    end
end
