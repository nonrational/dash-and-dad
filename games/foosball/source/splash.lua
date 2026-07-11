import "game"

Splash = { active = true }

function Splash.update()
    if playdate.buttonJustPressed(playdate.kButtonA) or playdate.buttonJustPressed(playdate.kButtonB) then
        Splash.active = false
    end
end

function Splash.draw()
    local gfx = playdate.graphics
    gfx.clear(gfx.kColorWhite)
    gfx.drawTextAligned("FOOSBALL SHOOTOUT", 200, 70, kTextAlignment.center)
    gfx.drawTextAligned("D-pad: line up   Crank: shoot", 200, 110, kTextAlignment.center)
    gfx.drawTextAligned(string.format("Best streak: %d", Game.bestStreak), 200, 140, kTextAlignment.center)
    gfx.drawTextAligned("Press A to kick off...", 200, 170, kTextAlignment.center)
end
