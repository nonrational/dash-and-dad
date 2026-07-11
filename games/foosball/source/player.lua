import "geom"
import "field"

Player = { x = 200 }

Player.SPEED = 260

function Player.init()
    Player.x = 200
end

function Player.update(dt)
    if playdate.buttonIsPressed(playdate.kButtonLeft) then
        Player.x = Player.x - Player.SPEED * dt
    end
    if playdate.buttonIsPressed(playdate.kButtonRight) then
        Player.x = Player.x + Player.SPEED * dt
    end
    Player.x = Geom.clamp(Player.x, Field.TRACK_MIN, Field.TRACK_MAX)
end
