-- Simulator-only screenshot harness for autonomous visual verification.
-- Each Shots.plan entry:
--   { after = <seconds>, target = <a Global table, e.g. Player>,
--     set = { <field> = <value>, ... }, call = <function, optional>,
--     path = "<absolute .png path>" }
-- While a shot is pending, its `set` fields are pinned onto `target` every
-- frame so the captured frame is deterministic. `call`, if present, runs
-- once the frame this entry becomes active, before any `set` pinning.
-- After the last shot the simulator exits. Committed code always has an
-- empty plan.
Shots = { plan = {}, t = 0, i = 1, called = false }

function Shots.update(dt)
    if not playdate.isSimulator then
        return
    end
    -- Guards against a stale Shots.i/t/called left over from a previous
    -- test run: an empty plan is always a no-op, regardless of what those
    -- fields were last set to. Without this, reverting only `Shots.plan`
    -- to `{}` (as every task's smoke test does) while `Shots.i` was left
    -- above 1 would make `make run` exit the simulator on its first frame.
    if #Shots.plan == 0 then
        return
    end
    local shot = Shots.plan[Shots.i]
    if not shot then
        if Shots.i > 1 then
            playdate.simulator.exit()
        end
        return
    end
    if shot.call and not Shots.called then
        shot.call()
        Shots.called = true
    end
    if shot.set and shot.target then
        for k, v in pairs(shot.set) do
            shot.target[k] = v
        end
    end
    Shots.t = Shots.t + dt
    if Shots.t >= shot.after then
        playdate.simulator.writeToFile(playdate.graphics.getDisplayImage(), shot.path)
        Shots.t = 0
        Shots.i = Shots.i + 1
        Shots.called = false
    end
end
