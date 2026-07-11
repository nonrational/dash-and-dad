import "game"

Splash = { active = true }

-- Pre-dithered 1-bit box art, exactly 400x240 (pdc thresholds at 50% and
-- does not dither — see the asset-regeneration note in CLAUDE.md).
local boxArt = playdate.graphics.image.new("images/splash")

function Splash.update()
    if playdate.buttonJustPressed(playdate.kButtonA) or playdate.buttonJustPressed(playdate.kButtonB) then
        Splash.active = false
    end
end

function Splash.draw()
    local gfx = playdate.graphics
    boxArt:draw(0, 0)
    -- The art is busy everywhere, so controls and the best streak ride in
    -- a black bar over the box's fine-print strip at the bottom.
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 222, 400, 18)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawTextAligned(
        string.format("D-pad aim - Crank shoot - A start - Best %d", Game.bestStreak),
        200, 224, kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end
