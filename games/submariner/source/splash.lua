Splash = { active = true }

function Splash.update()
    if playdate.buttonJustPressed(playdate.kButtonA) then
        Splash.active = false
    end
end

function Splash.draw()
    local gfx = playdate.graphics
    gfx.clear(gfx.kColorWhite)
    gfx.drawTextAligned("For Dash, Love Dad", 200, 100, kTextAlignment.center)
    gfx.drawTextAligned("Press A to submerge...", 200, 130, kTextAlignment.center)
end
