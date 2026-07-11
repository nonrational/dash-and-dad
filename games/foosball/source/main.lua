import "CoreLibs/graphics"
import "CoreLibs/ui"
import "tests"
import "field"
import "player"
import "ball"
import "render"
import "shots"

playdate.display.setRefreshRate(30)
math.randomseed(playdate.getSecondsSinceEpoch())

Render.init()
Player.init()
Ball.init()
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
    if Ball.state == "flightComplete" then
        -- No goalie until Task 7 — 9999 is outside Field.SAVE_RADIUS of any
        -- possible Ball.shotTargetX, so this always resolves as a goal.
        Ball.resolve(9999)
    end
    Render.draw(dt)
    Shots.update(dt)
    if playdate.isCrankDocked() then
        playdate.ui.crankIndicator:draw()
    end
end
