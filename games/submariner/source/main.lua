import "CoreLibs/graphics"
import "tests"

local gfx = playdate.graphics

playdate.display.setRefreshRate(30)

if playdate.isSimulator then
    runTests()
end

function playdate.update()
    gfx.clear(gfx.kColorWhite)
    gfx.drawTextAligned("SUBMARINER", 200, 112, kTextAlignment.center)
end
