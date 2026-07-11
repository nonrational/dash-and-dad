import "geom"
import "field"

Player = { x = 200, crankAngle = 0 }

Player.SPEED = 260

function Player.init()
    Player.x = 200
    Player.crankAngle = 0
end

function Player.update(dt)
    if playdate.buttonIsPressed(playdate.kButtonLeft) then
        Player.x = Player.x - Player.SPEED * dt
    end
    if playdate.buttonIsPressed(playdate.kButtonRight) then
        Player.x = Player.x + Player.SPEED * dt
    end
    Player.x = Geom.clamp(Player.x, Field.TRACK_MIN, Field.TRACK_MAX)

    -- Absolute crank angle for the kick-leg pose. getCrankPosition() is
    -- independent of ball.lua's getCrankChange() drain — reading it here
    -- touches no accumulator. Guarded on dock state so a docked crank
    -- freezes the leg at its last pose — which also lets the Shots harness pin
    -- crankAngle for deterministic captures (the crank itself can't be scripted).
    if not playdate.isCrankDocked() then
        Player.crankAngle = playdate.getCrankPosition()
    end
end
