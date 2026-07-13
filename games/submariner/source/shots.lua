-- Simulator-only screenshot harness for autonomous visual verification.
-- Each Shots.plan entry:
--   { after = <seconds>, set = { <Scope field> = <value>, ... }, path = "<absolute .png path>" }
-- While a shot is pending, its `set` fields are pinned onto Scope every frame
-- so the captured frame is deterministic. After the last shot the simulator
-- exits. Committed code always has an empty plan.
Shots = { plan = {}, t = 0, i = 1 }

function Shots.update(dt)
    if not playdate.isSimulator then
        return
    end
    local shot = Shots.plan[Shots.i]
    if not shot then
        if Shots.i > 1 then
            playdate.simulator.exit()
        end
        return
    end
    if shot.set then
        for k, v in pairs(shot.set) do
            Scope[k] = v
        end
    end
    Shots.t = Shots.t + dt
    if Shots.t >= shot.after then
        playdate.simulator.writeToFile(playdate.graphics.getDisplayImage(), shot.path)
        Shots.t = 0
        Shots.i = Shots.i + 1
    end
end
