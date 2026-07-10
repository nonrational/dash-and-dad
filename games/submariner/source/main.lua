import "CoreLibs/graphics"

local gfx = playdate.graphics

playdate.display.setRefreshRate(30)

function playdate.update()
    gfx.clear(gfx.kColorWhite)
    gfx.drawTextAligned("SUBMARINER", 200, 112, kTextAlignment.center)
end
