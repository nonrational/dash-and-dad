import "CoreLibs/graphics"
import "CoreLibs/ui"
import "tests"
import "field"
import "player"
import "ball"
import "goalie"
import "game"
import "render"
import "shots"

playdate.display.setRefreshRate(30)
math.randomseed(playdate.getSecondsSinceEpoch())

Render.init()
Player.init()
Ball.init()
Goalie.init()
Game.init()
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
    Goalie.update(dt, Game.streak)
    if Ball.state == "flightComplete" then
        Ball.resolve(Goalie.x)
    end
    if Ball.resultPending then
        Game.onResult(Ball.result)
    end
    Render.draw(dt)
    Shots.update(dt)
    if playdate.isCrankDocked() then
        playdate.ui.crankIndicator:draw()
    end
end
