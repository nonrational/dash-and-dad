# The Shots screenshot harness

Both games carry a `source/shots.lua` for autonomous visual verification —
capturing deterministic frames without a human at the device.

## How it works

`Shots.plan` holds a list of entries:

```lua
{ after = <seconds>, target = <a global table>, set = { <field> = <value> },
  call = <function, optional>, path = "<absolute .png path>" }
```

`Shots.update(dt)` runs every frame (outside any splash gate). While an entry is
pending, its `set` fields are pinned onto `target` every frame so the captured
frame is deterministic; `call` runs once when the entry becomes active, for side
effects a field-pin can't express. After the last entry, the simulator writes
each frame to disk and exits.

Run it headless with the simulator binary directly, e.g.:

```
timeout -k 5 25 "$HOME/Developer/PlaydateSDK/bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator" <Game>.pdx
```

A clean run writes the PNGs then segfaults on teardown (expected). No PNGs plus
a SIGKILL means a boot error — the Lua error is invisible headless, so check the
simulator console.

## Rules

- **Committed code always has an empty plan** (`Shots.plan = {}`). Populate it to
  capture, revert before committing.
- **Real input can't be scripted.** `getCrankChange()` and `buttonJustPressed`
  don't replay through the harness. Verify anything gated on them by pinning the
  *downstream* state directly (force `Ball.state = "flight"`, or `Splash.active =
  false`), and defer the actual input feel to the human-acceptance checklist.
- **Keep captures deterministic.** Avoid `math.random` in rendering (submariner
  uses fixed jitter tables); pin any randomized field (foosball pins the serve
  lane) rather than relying on captured randomness.
