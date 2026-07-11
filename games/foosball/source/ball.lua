import "geom"
import "field"

Ball = {
    state = "approach",
    progress = 0,
    laneX = 200,
    result = nil,
    resultPending = false,
    resolvedTimer = 0,
}

Ball.T_SERVE = 1.6
Ball.WINDOW_START = 0.82
Ball.MISS_PAUSE = 1.5

local function randomLaneX()
    return Field.TRACK_MIN + math.random() * (Field.TRACK_MAX - Field.TRACK_MIN)
end

function Ball.startServe()
    Ball.state = "approach"
    Ball.progress = 0
    Ball.laneX = randomLaneX()
    Ball.result = nil
end

function Ball.init()
    Ball.startServe()
    Ball.resolvedTimer = 0
    Ball.resultPending = false
end

function Ball.update(dt)
    Ball.resultPending = false

    if Ball.state == "approach" or Ball.state == "window" then
        Ball.progress = Ball.progress + dt / Ball.T_SERVE
        if Ball.state == "approach" and Ball.progress >= Ball.WINDOW_START then
            Ball.state = "window"
        end
        if Ball.progress >= 1.0 then
            Ball.progress = 1.0
            Ball.result = "tooSlow"
            Ball.resultPending = true
            Ball.state = "resolved"
            Ball.resolvedTimer = 0
        end
    elseif Ball.state == "resolved" then
        Ball.resolvedTimer = Ball.resolvedTimer + dt
        if Ball.resolvedTimer >= Ball.MISS_PAUSE then
            Ball.startServe()
        end
    end
end

function Ball.screenX()
    return Ball.laneX
end

function Ball.screenY()
    return Geom.lerp(Field.GOAL_Y, Field.PLAYER_Y, Geom.clamp(Ball.progress, 0, 1))
end

function Ball.screenScale()
    return Geom.lerp(Field.BALL_MIN_SCALE, Field.BALL_MAX_SCALE, Geom.clamp(Ball.progress, 0, 1))
end
