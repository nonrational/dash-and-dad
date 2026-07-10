# Submariner Periscope Simulation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An ambient Playdate toy: d-pad rotates a submarine periscope 360°, the crank raises/lowers it through the waterline; boats and sky above, fish and murk below.

**Architecture:** Persistent 360° cylindrical world; entities keyed by bearing, projected to screen x by angular delta. One waterline y driven by crank height splits the view. Five Lua modules as globals (`Geom`, `Scope`, `World`, `Render`, `Ambience`) wired by `main.lua`.

**Tech Stack:** Playdate SDK 3.0.6 (Lua only), `pdc` compiler, Playdate Simulator. No image or audio assets — everything code-drawn and synthesized.

**Spec:** `docs/superpowers/specs/2026-07-09-periscope-sim-design.md`

## Global Constraints

- SDK lives at `~/Developer/PlaydateSDK`; compiler `~/Developer/PlaydateSDK/bin/pdc` (3.0.6); simulator `~/Developer/PlaydateSDK/bin/Playdate Simulator.app`.
- Playdate `import` is a compile-time, once-only textual include; it returns nothing. Modules therefore define globals: `Geom`, `Scope`, `World`, `Render`, `Ambience`, `runTests`.
- Screen constants (from spec, do not change): eyepiece center **(200, 110)**, radius **104**, **3.5 px/degree**, waterline swing **±120 px**, HUD strip below the circle.
- Control constants (from spec): rotation **25→55 °/s** ramping over **0.5 s** of hold; crank sweep **3 revolutions** for full height range `[-1, +1]`; `height = 0` is the waterline; positive = raised.
- Target **30 fps** (`playdate.display.setRefreshRate(30)`).
- No host Lua exists on this machine. Pure-math tests run at boot **inside the simulator** (`runTests()` guarded by `playdate.isSimulator`) and print to the simulator console. To see console output in your terminal, launch the simulator binary directly: `"$HOME/Developer/PlaydateSDK/bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator" Submariner.pdx`. A failed assertion calls `error()`, which the simulator surfaces as a crash screen — that is the "red" state.
- `playdate.graphics.setDitherPattern(alpha, ditherType)` has a documented quirk: alpha runs inverted vs. intuition for black ink. All dithered fills go through the `setInk(darkness)` helper defined in Task 3 — never call `setDitherPattern` directly elsewhere.
- Commit messages: plain descriptive sentences. **Never** use Conventional Commit prefixes (`feat:`, `fix:`, etc.). Pass `--no-gpg-sign` to every `git commit` (repo has signing on; the user is AFK and has authorized unsigned commits for this build).
- `screencapture` is blocked on this machine (no screen-recording permission). Visual verification instead uses the simulator-only screenshot harness `source/shots.lua` (created in Task 3): temporarily populate `Shots.plan` with entries `{ after = <seconds>, set = { <Scope field> = <value>, ... }, path = "<absolute .png path>" }`, then run:
  `make build && pkill -f "Playdate Simulator"; timeout 30 "$HOME/Developer/PlaydateSDK/bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator" Submariner.pdx`
  The harness pins the `set` fields onto `Scope` every frame, writes each PNG after its `after` delay, and exits the simulator after the last shot. Read each PNG and check it against the task's expected-image checklist. Write PNGs to `/Users/norton/wrk/supertinylabs/submariner/.superpowers/sdd/` (git-ignored). **Restore `Shots.plan = {}` before committing.**
- Checks that genuinely need human interaction (rotation ramp feel, crank feel, audio character) are deferred to the human acceptance pass in Task 9 — list them explicitly in your report as deferred, never skip them silently.
- Visual tasks end with the harness check above — this is an ambient toy; the checklist in each task is the acceptance test.

---

### Task 1: Project skeleton boots in the simulator

**Files:**
- Create: `source/pdxinfo`
- Create: `source/main.lua`
- Create: `Makefile`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: `make build` → `Submariner.pdx`; `make run` → opens simulator. `source/main.lua` with a `playdate.update` loop later tasks extend.

- [ ] **Step 1: Write `source/pdxinfo`**

```
name=Submariner
author=Super Tiny Labs
description=An ambient submarine periscope toy.
bundleID=com.supertinylabs.submariner
version=0.1
buildNumber=1
```

- [ ] **Step 2: Write minimal `source/main.lua`**

```lua
import "CoreLibs/graphics"

local gfx = playdate.graphics

playdate.display.setRefreshRate(30)

function playdate.update()
    gfx.clear(gfx.kColorWhite)
    gfx.drawTextAligned("SUBMARINER", 200, 112, kTextAlignment.center)
end
```

- [ ] **Step 3: Write `Makefile`**

```make
SDK = $(HOME)/Developer/PlaydateSDK
PDX = Submariner.pdx

build:
	"$(SDK)/bin/pdc" source $(PDX)

run: build
	open -a "$(SDK)/bin/Playdate Simulator.app" $(PDX)

clean:
	rm -rf $(PDX)

.PHONY: build run clean
```

(Indentation under each target must be a TAB, not spaces.)

- [ ] **Step 4: Build**

Run: `make build`
Expected: exits 0; `ls Submariner.pdx` shows `main.pdz` and `pdxinfo`.

- [ ] **Step 5: Run in simulator**

Run: `make run`
Expected: simulator opens showing a white screen with centered "SUBMARINER".

- [ ] **Step 6: Commit**

```bash
git add source Makefile
git commit -m "Add Playdate project skeleton that boots in the simulator"
```

---

### Task 2: Geom math module with boot-time test suite

**Files:**
- Create: `source/tests.lua` (first — this is the failing test)
- Create: `source/geom.lua`
- Modify: `source/main.lua`

**Interfaces:**
- Consumes: Task 1 skeleton.
- Produces the `Geom` global used by every later task:
  - `Geom.wrap360(deg) -> number` — wraps to `[0, 360)`.
  - `Geom.wrappedDelta(from, to) -> number` — signed shortest angle in `(-180, 180]`.
  - `Geom.clamp(v, lo, hi) -> number`
  - `Geom.bearingToScreenX(entityBearing, scopeBearing, centerX, pxPerDegree) -> number`
  - `Geom.waterlineY(height, centerY, swing) -> number`
  - `Geom.crossfadeMix(height) -> number` — above-water volume in `[0,1]`.
  - `Geom.rotationSpeed(holdSeconds) -> number` — 25→55 °/s over 0.5 s.
  - Global `runTests()` (asserts, then prints `geom tests: all passed`).

- [ ] **Step 1: Write the failing test — `source/tests.lua`**

```lua
import "geom"

function runTests()
    local function eq(actual, expected, msg)
        if math.abs(actual - expected) > 1e-9 then
            error(string.format("FAIL %s: expected %s, got %s",
                msg, tostring(expected), tostring(actual)))
        end
    end

    eq(Geom.wrap360(370), 10, "wrap360 over")
    eq(Geom.wrap360(-10), 350, "wrap360 negative")
    eq(Geom.wrap360(360), 0, "wrap360 exact")

    eq(Geom.wrappedDelta(350, 10), 20, "delta across zero")
    eq(Geom.wrappedDelta(10, 350), -20, "delta across zero, negative")
    eq(Geom.wrappedDelta(0, 180), 180, "delta opposite side")

    eq(Geom.clamp(5, 0, 1), 1, "clamp high")
    eq(Geom.clamp(-5, 0, 1), 0, "clamp low")
    eq(Geom.clamp(0.5, 0, 1), 0.5, "clamp inside")

    -- entity 10 deg clockwise of scope appears right of center: 200 + 10*3.5
    eq(Geom.bearingToScreenX(57, 47, 200, 3.5), 235, "entity right of scope")
    eq(Geom.bearingToScreenX(355, 5, 200, 3.5), 165, "entity left across zero")

    -- raised scope pushes the line below the circle; submerged above it
    eq(Geom.waterlineY(1, 110, 120), 230, "waterline fully raised")
    eq(Geom.waterlineY(-1, 110, 120), -10, "waterline fully submerged")
    eq(Geom.waterlineY(0, 110, 120), 110, "waterline at lens")

    eq(Geom.crossfadeMix(0), 0.5, "mix at surface")
    eq(Geom.crossfadeMix(0.3), 1, "mix fully above")
    eq(Geom.crossfadeMix(-0.3), 0, "mix fully below")

    eq(Geom.rotationSpeed(0), 25, "rotation base speed")
    eq(Geom.rotationSpeed(0.5), 55, "rotation fully ramped")
    eq(Geom.rotationSpeed(2), 55, "rotation capped")

    print("geom tests: all passed")
end
```

- [ ] **Step 2: Wire tests into `source/main.lua`** (full replacement)

```lua
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
```

- [ ] **Step 3: Run to verify it fails**

Run: `make build`
Expected: FAIL — `pdc` errors because `geom.lua` does not exist (`import "geom"` cannot resolve).

- [ ] **Step 4: Write minimal implementation — `source/geom.lua`**

```lua
Geom = {}

-- Wraps an angle to [0, 360).
function Geom.wrap360(deg)
    return deg % 360
end

-- Signed shortest angular distance from `from` to `to`, in (-180, 180].
function Geom.wrappedDelta(from, to)
    local d = (to - from) % 360
    if d > 180 then
        d = d - 360
    end
    return d
end

function Geom.clamp(v, lo, hi)
    if v < lo then
        return lo
    elseif v > hi then
        return hi
    end
    return v
end

-- Screen x for an entity at entityBearing seen from scopeBearing.
function Geom.bearingToScreenX(entityBearing, scopeBearing, centerX, pxPerDegree)
    return centerX + Geom.wrappedDelta(scopeBearing, entityBearing) * pxPerDegree
end

-- Screen y of the waterline. Raised scope (height +1) pushes the line down
-- (more sky); submerged (-1) pushes it above the eyepiece (all water).
function Geom.waterlineY(height, centerY, swing)
    return centerY + height * swing
end

-- Above-water ambience volume in [0,1]; below-water volume is 1 - mix.
function Geom.crossfadeMix(height)
    return Geom.clamp(0.5 + height * 2, 0, 1)
end

-- D-pad rotation speed: 25 deg/s ramping to 55 deg/s over 0.5 s of hold.
function Geom.rotationSpeed(holdSeconds)
    return 25 + 30 * Geom.clamp(holdSeconds / 0.5, 0, 1)
end
```

- [ ] **Step 5: Run to verify it passes**

Run: `make build && "$HOME/Developer/PlaydateSDK/bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator" Submariner.pdx`
Expected: console output includes `geom tests: all passed`; no crash screen. Quit the simulator.

- [ ] **Step 6: Commit**

```bash
git add source
git commit -m "Add pure-math geom module with boot-time tests"
```

---

### Task 3: Scope view shell — mask, crosshairs, HUD, waterline, sea

**Files:**
- Create: `source/render.lua`
- Create: `source/shots.lua`
- Modify: `source/main.lua`

**Interfaces:**
- Consumes: `Geom` (Task 2); a global `Scope` table with `bearing` and `height` fields (placeholder in `main.lua` until Task 4 replaces it).
- Produces the `Shots` global (screenshot harness, see Global Constraints): `Shots.update(dt)` called last in `playdate.update`; `Shots.plan` empty in committed code.
- Produces the `Render` global used by Tasks 4–7:
  - `Render.init()` — builds the mask image; call once.
  - `Render.draw(dt)` — draws the whole frame; call every update.
  - Constants: `Render.CENTER_X = 200`, `Render.CENTER_Y = 110`, `Render.RADIUS = 104`, `Render.PX_PER_DEG = 3.5`, `Render.SWING = 120`.
  - Internal helper `setInk(darkness)` — the only sanctioned path to `setDitherPattern`.

- [ ] **Step 1: Write `source/render.lua`**

```lua
import "CoreLibs/graphics"
import "geom"

local gfx = playdate.graphics

Render = {
    CENTER_X = 200,
    CENTER_Y = 110,
    RADIUS = 104,
    PX_PER_DEG = 3.5,
    SWING = 120,
}

local mask = nil
local t = 0

-- setDitherPattern's alpha runs backwards for black ink (0 = solid black),
-- so express everything as "darkness" in [0,1] and invert here.
local function setInk(darkness)
    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(1 - darkness, gfx.image.kDitherTypeBayer8x8)
end

function Render.init()
    mask = gfx.image.new(400, 240, gfx.kColorBlack)
    gfx.pushContext(mask)
    gfx.setColor(gfx.kColorClear)
    gfx.fillCircleAtPoint(Render.CENTER_X, Render.CENTER_Y, Render.RADIUS)
    gfx.popContext()
end

local function waterY()
    return Geom.waterlineY(Scope.height, Render.CENTER_Y, Render.SWING)
end

-- Light surface tint below the line, with short wave strokes that hug the
-- line and drift with time and bearing so the sea feels world-locked.
local function drawSea(wy)
    setInk(0.12)
    gfx.fillRect(0, wy, 400, 240 - wy)
    gfx.setColor(gfx.kColorBlack)
    for row = 1, 5 do
        local y = wy + 8 + row * 14
        local phase = (t * (14 - row * 2) + row * 53
            - Scope.bearing * Render.PX_PER_DEG) % 40
        for x = 96 - phase, 304, 40 do
            gfx.drawLine(x, y, x + 12 - row, y)
        end
    end
end

local function drawWaterline(wy)
    gfx.setColor(gfx.kColorBlack)
    for x = 92, 308, 2 do
        local y = wy + math.sin(x * 0.08 + t * 3) * 2
        gfx.fillRect(x, y, 2, 2)
    end
end

local function drawCrosshairs()
    local cx, cy, r = Render.CENTER_X, Render.CENTER_Y, Render.RADIUS
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(1)
    gfx.drawLine(cx, cy - r, cx, cy - 6)
    gfx.drawLine(cx, cy + 6, cx, cy + r)
    gfx.drawLine(cx - r, cy, cx - 6, cy)
    gfx.drawLine(cx + 6, cy, cx + r, cy)
    for i = -4, 4 do
        if i ~= 0 then
            local x = cx + i * 20
            gfx.drawLine(x, cy - 3, x, cy + 3)
        end
    end
end

local function drawHUD()
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    local brg = math.floor(Scope.bearing + 0.5) % 360
    gfx.drawTextAligned(string.format("BRG %03d°", brg),
        Render.CENTER_X, 220, kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function Render.draw(dt)
    t = t + dt
    gfx.clear(gfx.kColorWhite)
    local wy = waterY()
    if wy < Render.CENTER_Y + Render.RADIUS then
        drawSea(wy)
    end
    drawWaterline(wy)
    mask:draw(0, 0)
    drawCrosshairs()
    drawHUD()
end
```

- [ ] **Step 2: Write `source/shots.lua`** (screenshot harness, see Global Constraints)

```lua
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
```

- [ ] **Step 3: Update `source/main.lua`** (full replacement)

```lua
import "CoreLibs/graphics"
import "tests"
import "render"
import "shots"

playdate.display.setRefreshRate(30)

-- Placeholder scope state; replaced by scope.lua in the next task.
Scope = { bearing = 47, height = 0.3 }

Render.init()
if playdate.isSimulator then
    runTests()
end

function playdate.update()
    local dt = playdate.getElapsedTime()
    playdate.resetElapsedTime()
    if dt <= 0 or dt > 0.25 then
        dt = 1 / 30
    end
    Render.draw(dt)
    Shots.update(dt)
end
```

- [ ] **Step 4: Verify via the screenshot harness**

Temporarily set in `source/shots.lua`:

```lua
Shots.plan = {
    { after = 1.5, set = { bearing = 47, height = 0.3 },
      path = "/Users/norton/wrk/supertinylabs/submariner/.superpowers/sdd/task-3-mid.png" },
    { after = 1.0, set = { height = 1 },
      path = "/Users/norton/wrk/supertinylabs/submariner/.superpowers/sdd/task-3-up.png" },
    { after = 1.0, set = { height = -1 },
      path = "/Users/norton/wrk/supertinylabs/submariner/.superpowers/sdd/task-3-down.png" },
}
```

Run the harness command from Global Constraints, then Read each PNG:
- `task-3-mid.png`: black surround with a clean white circular eyepiece centered slightly high; waterline band ~36 px below center (y ≈ 146) with 2 px chop; below the line a light Bayer-dither sea tint with short horizontal wave strokes; thin crosshairs with an open center gap and tick marks; white `BRG 047°` centered in the black strip under the circle. If the `°` glyph renders as a box, drop it from the format string.
- `task-3-up.png`: all white sky inside the circle — no waterline, no sea tint visible.
- `task-3-down.png`: sea tint fills the circle — no waterline, no white sky band.

Restore `Shots.plan = {}` before committing.

- [ ] **Step 5: Commit**

```bash
git add source
git commit --no-gpg-sign -m "Add scope view shell with mask, crosshairs, HUD, and waterline"
```

---

### Task 4: Live periscope controls

**Files:**
- Create: `source/scope.lua`
- Modify: `source/main.lua`

**Interfaces:**
- Consumes: `Geom` (Task 2); `Render.draw` reads the fields below.
- Produces the real `Scope` global (replaces the placeholder):
  - `Scope.bearing` — degrees `[0, 360)`.
  - `Scope.height` — `[-1, +1]`.
  - `Scope.update(dt)` — reads d-pad + crank, updates state.
  - `Scope.surfacedNow` — true only on the frame the lens breaks the surface upward (Task 8 consumes for the splash).
  - `Scope.surfacedProgress() -> number|nil` — droplet-effect progress `0..1` during the 0.5 s after surfacing, else `nil` (Task 7 consumes).

- [ ] **Step 1: Write `source/scope.lua`**

```lua
import "geom"

-- 3 crank revolutions sweep the full height range [-1, +1].
local HEIGHT_PER_CRANK_DEG = 2 / 1080
local DROPLET_WINDOW = 0.5

Scope = {
    bearing = 47,
    height = -0.4,   -- start submerged: cranking up reveals the surface
    holdTime = 0,
    surfacedTimer = 999,
    surfacedNow = false,
}

function Scope.update(dt)
    Scope.surfacedNow = false

    local dir = 0
    if playdate.buttonIsPressed(playdate.kButtonLeft) then
        dir = dir - 1
    end
    if playdate.buttonIsPressed(playdate.kButtonRight) then
        dir = dir + 1
    end
    if dir ~= 0 then
        Scope.holdTime = Scope.holdTime + dt
        Scope.bearing = Geom.wrap360(
            Scope.bearing + dir * Geom.rotationSpeed(Scope.holdTime) * dt)
    else
        Scope.holdTime = 0
    end

    if not playdate.isCrankDocked() then
        local change = playdate.getCrankChange()
        local prev = Scope.height
        Scope.height = Geom.clamp(
            Scope.height + change * HEIGHT_PER_CRANK_DEG, -1, 1)
        if prev < 0 and Scope.height >= 0 then
            Scope.surfacedTimer = 0
            Scope.surfacedNow = true
        end
    end

    Scope.surfacedTimer = Scope.surfacedTimer + dt
end

function Scope.surfacedProgress()
    if Scope.surfacedTimer < DROPLET_WINDOW then
        return Scope.surfacedTimer / DROPLET_WINDOW
    end
    return nil
end
```

- [ ] **Step 2: Update `source/main.lua`** (full replacement)

```lua
import "CoreLibs/graphics"
import "CoreLibs/ui"
import "tests"
import "scope"
import "render"
import "shots"

playdate.display.setRefreshRate(30)

Render.init()
if playdate.isSimulator then
    runTests()
end

function playdate.update()
    local dt = playdate.getElapsedTime()
    playdate.resetElapsedTime()
    if dt <= 0 or dt > 0.25 then
        dt = 1 / 30
    end
    Scope.update(dt)
    Render.draw(dt)
    if playdate.isCrankDocked() then
        playdate.ui.crankIndicator:draw()
    end
    Shots.update(dt)
end
```

- [ ] **Step 3: Verify via the screenshot harness**

Temporarily set in `source/shots.lua`:

```lua
Shots.plan = {
    { after = 2.5,
      path = "/Users/norton/wrk/supertinylabs/submariner/.superpowers/sdd/task-4-boot.png" },
    { after = 1.0, set = { height = 0.6 },
      path = "/Users/norton/wrk/supertinylabs/submariner/.superpowers/sdd/task-4-raised.png" },
}
```

(The first shot sets nothing — it captures the real boot state.) Run the harness command, then Read each PNG:
- `task-4-boot.png`: waterline high in the view (height −0.4 → y ≈ 62), sea tint filling most of the circle, `BRG 047°`, and the SDK "use the crank" indicator visible (the simulator boots with the crank docked).
- `task-4-raised.png`: waterline low in the view (y ≈ 182), mostly sky.

Restore `Shots.plan = {}` before committing.

**Deferred to the Task 9 human pass (list in your report):** rotation ramp feel and 359→000 wrap while holding the d-pad; ~3 crank revolutions bottom-to-top with silent clamping at the stops; no glitches when cranking across the line.

- [ ] **Step 4: Commit**

```bash
git add source
git commit --no-gpg-sign -m "Wire d-pad rotation and crank height into the scope"
```

---

### Task 5: Above-water world — boats, lighthouse, clouds

**Files:**
- Create: `source/world.lua`
- Modify: `source/render.lua`
- Modify: `source/main.lua`

**Interfaces:**
- Consumes: `Geom`, `Scope`, `Render` constants.
- Produces the `World` global:
  - `World.init()` — builds the population; call once.
  - `World.update(dt)` — drifts everything.
  - `World.LANES` — `{ far|mid|near = { scale, yOff, drift } }`.
  - `World.boats` — list of `{ type = "sail"|"trawler"|"cargo", lane, bearing, dir, bobPhase }`.
  - `World.clouds` — list of `{ bearing, above, w, drift }` (`above` = px above waterline).
  - `World.lighthouse` — `{ bearing }`.
  - Task 6 will add `World.schools`, `World.fish`, `World.bubbles`.

- [ ] **Step 1: Write `source/world.lua`**

```lua
import "geom"

World = {
    LANES = {
        far  = { scale = 0.45, yOff = 0,  drift = 1.1 },
        mid  = { scale = 0.7,  yOff = 5,  drift = 2.0 },
        near = { scale = 1.0,  yOff = 11, drift = 3.2 },
    },
    boats = {},
    clouds = {},
    lighthouse = { bearing = 305 },
}

function World.init()
    World.boats = {
        { type = "sail",    lane = "near", bearing = 40,  dir = 1,  bobPhase = 0.0 },
        { type = "trawler", lane = "mid",  bearing = 130, dir = -1, bobPhase = 1.3 },
        { type = "cargo",   lane = "far",  bearing = 205, dir = 1,  bobPhase = 2.6 },
        { type = "sail",    lane = "far",  bearing = 255, dir = -1, bobPhase = 3.9 },
        { type = "trawler", lane = "near", bearing = 335, dir = 1,  bobPhase = 5.2 },
    }
    World.clouds = {
        { bearing = 20,  above = 62, w = 46, drift = 0.5 },
        { bearing = 150, above = 78, w = 64, drift = 0.35 },
        { bearing = 280, above = 55, w = 38, drift = 0.6 },
    }
end

function World.update(dt)
    for _, b in ipairs(World.boats) do
        b.bearing = Geom.wrap360(b.bearing + b.dir * World.LANES[b.lane].drift * dt)
        b.bobPhase = b.bobPhase + dt * 1.6
    end
    for _, c in ipairs(World.clouds) do
        c.bearing = Geom.wrap360(c.bearing + c.drift * dt)
    end
end
```

- [ ] **Step 2: Add the above-water layer to `source/render.lua`**

Insert after `drawSea` (boat drawers take the hull-baseline point, a scale, and a facing direction; `dir` mirrors x offsets):

```lua
-- Boat silhouettes. (x, y) is the hull baseline center; dir = ±1 facing.
local function drawSail(x, y, s, dir)
    local function px(dx) return x + dx * s * dir end
    gfx.setColor(gfx.kColorBlack)
    gfx.fillPolygon(px(-14), y, px(12), y, px(15), y - 4 * s, px(-16), y - 4 * s)
    gfx.drawLine(px(0), y - 4 * s, px(0), y - 30 * s)
    gfx.fillTriangle(px(1), y - 29 * s, px(13), y - 6 * s, px(1), y - 6 * s)
    gfx.fillTriangle(px(-1), y - 26 * s, px(-11), y - 6 * s, px(-1), y - 6 * s)
end

local function drawTrawler(x, y, s, dir)
    local function px(dx) return x + dx * s * dir end
    gfx.setColor(gfx.kColorBlack)
    gfx.fillPolygon(px(-16), y - 8 * s, px(16), y - 8 * s, px(13), y, px(-14), y)
    gfx.fillRect(math.min(px(-11), px(1)), y - 16 * s, 12 * s, 8 * s)
    gfx.drawLine(px(7), y - 8 * s, px(7), y - 22 * s)
    gfx.drawLine(px(7), y - 20 * s, px(14), y - 12 * s)
end

local function drawCargo(x, y, s, dir)
    local function px(dx) return x + dx * s * dir end
    gfx.setColor(gfx.kColorBlack)
    gfx.fillPolygon(px(-24), y - 7 * s, px(24), y - 7 * s, px(21), y, px(-22), y)
    gfx.fillRect(math.min(px(14), px(20)), y - 16 * s, 6 * s, 9 * s)
    gfx.fillRect(math.min(px(-18), px(8)), y - 12 * s, 26 * s, 5 * s)
    gfx.drawLine(px(17), y - 16 * s, px(17), y - 19 * s)
end

local BOAT_DRAWERS = { sail = drawSail, trawler = drawTrawler, cargo = drawCargo }
local LANE_ORDER = { "far", "mid", "near" }

local function drawLighthouse(x, y)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillPolygon(x - 3, y - 22, x + 3, y - 22, x + 5, y, x - 5, y)
    gfx.fillRect(x - 4, y - 27, 8, 5)
end

local function drawClouds(wy)
    setInk(0.4)
    for _, c in ipairs(World.clouds) do
        local x = Geom.bearingToScreenX(c.bearing, Scope.bearing,
            Render.CENTER_X, Render.PX_PER_DEG)
        if x > -60 and x < 460 then
            gfx.fillEllipseInRect(x - c.w / 2, wy - c.above, c.w, 14)
            gfx.fillEllipseInRect(x - c.w / 4, wy - c.above - 7, c.w / 2, 12)
        end
    end
end

-- Everything above the waterline, clipped to it so hulls sit "in" the water.
local function drawAbove(wy)
    gfx.setClipRect(0, 0, 400, wy)
    drawClouds(wy)
    local lx = Geom.bearingToScreenX(World.lighthouse.bearing, Scope.bearing,
        Render.CENTER_X, Render.PX_PER_DEG)
    if lx > -40 and lx < 440 then
        drawLighthouse(lx, wy)
    end
    for _, laneName in ipairs(LANE_ORDER) do
        local lane = World.LANES[laneName]
        for _, b in ipairs(World.boats) do
            if b.lane == laneName then
                local x = Geom.bearingToScreenX(b.bearing, Scope.bearing,
                    Render.CENTER_X, Render.PX_PER_DEG)
                if x > -80 and x < 480 then
                    local y = wy + lane.yOff
                        + math.sin(b.bobPhase) * 1.5 * lane.scale
                    BOAT_DRAWERS[b.type](x, y, lane.scale, b.dir)
                end
            end
        end
    end
    gfx.clearClipRect()
end
```

Then update `Render.draw` (full replacement of the function):

```lua
function Render.draw(dt)
    t = t + dt
    gfx.clear(gfx.kColorWhite)
    local wy = waterY()
    if wy > Render.CENTER_Y - Render.RADIUS then
        drawAbove(wy)
    end
    if wy < Render.CENTER_Y + Render.RADIUS then
        drawSea(wy)
    end
    drawWaterline(wy)
    mask:draw(0, 0)
    drawCrosshairs()
    drawHUD()
end
```

- [ ] **Step 3: Wire `World` into `source/main.lua`**

Add `import "world"` after `import "scope"`, add `World.init()` right after `Render.init()`, and add `World.update(dt)` between `Scope.update(dt)` and `Render.draw(dt)`:

```lua
import "CoreLibs/graphics"
import "CoreLibs/ui"
import "tests"
import "scope"
import "world"
import "render"
import "shots"

playdate.display.setRefreshRate(30)

Render.init()
World.init()
if playdate.isSimulator then
    runTests()
end

function playdate.update()
    local dt = playdate.getElapsedTime()
    playdate.resetElapsedTime()
    if dt <= 0 or dt > 0.25 then
        dt = 1 / 30
    end
    Scope.update(dt)
    World.update(dt)
    Render.draw(dt)
    if playdate.isCrankDocked() then
        playdate.ui.crankIndicator:draw()
    end
    Shots.update(dt)
end
```

- [ ] **Step 4: Verify via the screenshot harness**

Temporarily set in `source/shots.lua` (all paths under `/Users/norton/wrk/supertinylabs/submariner/.superpowers/sdd/`):

```lua
Shots.plan = {
    { after = 1.5, set = { height = 0.5, bearing = 40 },  path = ".../task-5-sail-near.png" },
    { after = 1.0, set = { height = 0.5, bearing = 130 }, path = ".../task-5-trawler-mid.png" },
    { after = 1.0, set = { height = 0.5, bearing = 205 }, path = ".../task-5-cargo-far.png" },
    { after = 1.0, set = { height = 0.5, bearing = 305 }, path = ".../task-5-lighthouse.png" },
    { after = 1.0, set = { height = 0.5, bearing = 335 }, path = ".../task-5-trawler-near.png" },
    { after = 1.0, set = { height = 0.5, bearing = 20 },  path = ".../task-5-cloud.png" },
    { after = 1.0, set = { height = -0.9, bearing = 40 }, path = ".../task-5-submerged.png" },
}
```

(Write the full absolute paths — `...` above is for readability only. Boats drift ~1–3°/s, so by capture time each is within a few degrees of its spawn bearing — near center of frame.) Read each PNG:
- `task-5-sail-near.png`: large sailboat silhouette (hull, mast, two sails) near center, sitting low against the line, hull partly clipped by the water.
- `task-5-trawler-mid.png`: mid-size trawler (hull, cabin block, angled boom line) slightly above-center-line placement, smaller than the near sail.
- `task-5-cargo-far.png`: long, low cargo silhouette with bridge block and container row, small, sitting right on the line.
- `task-5-lighthouse.png`: tapered tower with cap on the line at ~305°.
- `task-5-trawler-near.png`: large trawler near center.
- `task-5-cloud.png`: dithered two-lobe cloud high above the line (cloud spawns at bearing 20).
- `task-5-submerged.png`: no boats, clouds, or lighthouse — only sea tint and waterline high in view.

Restore `Shots.plan = {}` before committing.

**Deferred to the Task 9 human pass (list in your report):** near-lane boats visibly drifting faster than far-lane; gentle bobbing; rotating right moves the world left.

- [ ] **Step 5: Commit**

```bash
git add source
git commit --no-gpg-sign -m "Add above-water world with boats, lighthouse, and clouds"
```

---

### Task 6: Underwater world — fish, bubbles, light rays, murk

**Files:**
- Modify: `source/world.lua`
- Modify: `source/render.lua`

**Interfaces:**
- Consumes: `Geom`, `Scope`, `Render`, `World` (Task 5).
- Produces on `World`:
  - `World.schools` — list of `{ bearing, depth, dir, speed, count, members }`, `members` being `{ dBearing, dDepth, phase }` (depths in px below the waterline).
  - `World.fish` — lone big fish: `{ bearing, depth, dir, speed, size, phase }`.
  - `World.bubbles` — flat list of `{ bearing, depth, r, wobble }`, rising columns at 3 fixed bearings.

- [ ] **Step 1: Add underwater population to `source/world.lua`**

Append inside `World.init()`:

```lua
    World.schools = {
        { bearing = 70,  depth = 45, dir = 1,  speed = 6,   count = 6 },
        { bearing = 220, depth = 95, dir = -1, speed = 4.5, count = 5 },
    }
    for _, s in ipairs(World.schools) do
        s.members = {}
        for i = 1, s.count do
            s.members[i] = {
                dBearing = i * 3.5 - (s.count + 1) * 1.75,
                dDepth = ((i * 7) % 20) - 10,
                phase = i * 0.9,
            }
        end
    end
    World.fish = {
        { bearing = 150, depth = 140, dir = 1,  speed = 2.2, size = 2.2, phase = 0 },
        { bearing = 20,  depth = 170, dir = -1, speed = 1.6, size = 2.8, phase = 2 },
    }
    World.bubbles = {}
    for _, colBearing in ipairs({ 95, 185, 300 }) do
        for i = 1, 5 do
            World.bubbles[#World.bubbles + 1] = {
                bearing = colBearing,
                depth = 30 + i * 34,
                r = 1 + (i % 3),
                wobble = i * 1.1,
            }
        end
    end
```

Append inside `World.update(dt)`:

```lua
    for _, s in ipairs(World.schools) do
        s.bearing = Geom.wrap360(s.bearing + s.dir * s.speed * dt)
        for _, m in ipairs(s.members) do
            m.phase = m.phase + dt * 6
        end
    end
    for _, f in ipairs(World.fish) do
        f.bearing = Geom.wrap360(f.bearing + f.dir * f.speed * dt)
        f.phase = f.phase + dt * 3
    end
    for _, bub in ipairs(World.bubbles) do
        bub.depth = bub.depth - dt * 22
        bub.wobble = bub.wobble + dt * 4
        if bub.depth < 4 then
            bub.depth = 175
        end
    end
```

- [ ] **Step 2: Add the underwater layer to `source/render.lua`**

Insert after `drawAbove`:

```lua
-- Fish: ellipse body plus a two-frame flapping tail.
local function drawFish(x, y, s, dir, phase)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillEllipseInRect(x - 5 * s, y - 2 * s, 10 * s, 4 * s)
    local up = (math.sin(phase) > 0) and 3 or 1
    local tx = x - 5 * s * dir
    gfx.fillTriangle(tx, y,
        tx - 4 * s * dir, y - up * s,
        tx - 4 * s * dir, y + (4 - up) * s)
end

local function drawLightRays(wy)
    if Scope.height < -0.6 then
        return
    end
    setInk(0.18)
    for i = -2, 2 do
        local x = Render.CENTER_X + i * 38 + math.sin(t * 0.4 + i) * 6
        gfx.fillPolygon(x - 3, wy, x + 3, wy, x + 14, wy + 90, x + 2, wy + 90)
    end
end

local function drawBubbles(wy)
    gfx.setColor(gfx.kColorBlack)
    for _, bub in ipairs(World.bubbles) do
        local x = Geom.bearingToScreenX(bub.bearing, Scope.bearing,
            Render.CENTER_X, Render.PX_PER_DEG) + math.sin(bub.wobble) * 3
        if x > -10 and x < 410 then
            gfx.drawCircleAtPoint(x, wy + bub.depth, bub.r)
        end
    end
end

-- Depth murk drawn over the fish so they dim as the scope sinks.
local function drawMurk(wy)
    local darkness = Geom.clamp(-Scope.height, 0, 1) * 0.5
    if darkness > 0.03 then
        setInk(darkness)
        gfx.fillRect(0, math.max(wy, 0), 400, 240)
    end
end

local function drawBelow(wy)
    gfx.setClipRect(0, math.max(wy + 1, 0), 400, 240)
    drawLightRays(wy)
    drawBubbles(wy)
    for _, s in ipairs(World.schools) do
        for _, m in ipairs(s.members) do
            local x = Geom.bearingToScreenX(s.bearing + m.dBearing, Scope.bearing,
                Render.CENTER_X, Render.PX_PER_DEG)
            if x > -20 and x < 420 then
                local y = wy + s.depth + m.dDepth + math.sin(m.phase * 0.5) * 2
                drawFish(x, y, 1, s.dir, m.phase)
            end
        end
    end
    for _, f in ipairs(World.fish) do
        local x = Geom.bearingToScreenX(f.bearing, Scope.bearing,
            Render.CENTER_X, Render.PX_PER_DEG)
        if x > -30 and x < 430 then
            local y = wy + f.depth + math.sin(f.phase * 0.4) * 3
            drawFish(x, y, f.size, f.dir, f.phase)
        end
    end
    drawMurk(wy)
    gfx.clearClipRect()
end
```

Then update `Render.draw` (full replacement — adds `drawBelow` after `drawSea`):

```lua
function Render.draw(dt)
    t = t + dt
    gfx.clear(gfx.kColorWhite)
    local wy = waterY()
    if wy > Render.CENTER_Y - Render.RADIUS then
        drawAbove(wy)
    end
    if wy < Render.CENTER_Y + Render.RADIUS then
        drawSea(wy)
        drawBelow(wy)
    end
    drawWaterline(wy)
    mask:draw(0, 0)
    drawCrosshairs()
    drawHUD()
end
```

- [ ] **Step 3: Verify via the screenshot harness**

Temporarily set in `source/shots.lua` (write full absolute paths under `/Users/norton/wrk/supertinylabs/submariner/.superpowers/sdd/`):

```lua
Shots.plan = {
    { after = 1.5, set = { height = -0.3, bearing = 70 },  path = ".../task-6-school.png" },
    { after = 1.0, set = { height = -0.5, bearing = 220 }, path = ".../task-6-school-deep.png" },
    { after = 1.0, set = { height = -0.3, bearing = 95 },  path = ".../task-6-bubbles.png" },
    { after = 1.0, set = { height = -1, bearing = 150 },   path = ".../task-6-murk.png" },
    { after = 1.0, set = { height = 0.05, bearing = 40 },  path = ".../task-6-split.png" },
}
```

Read each PNG:
- `task-6-school.png`: several small fish in loose formation near center, dithered light rays fanning down from the line.
- `task-6-school-deep.png`: second school, visibly darker overall (more murk dither than the first shot).
- `task-6-bubbles.png`: a wobbling column of small circles rising toward the line.
- `task-6-murk.png`: heavy dither over everything; a large lone fish silhouette still readable (~y 130); no light rays; no waterline visible.
- `task-6-split.png`: waterline mid-view; sky and (possibly) a boat above; sea tint and underwater content below; no fish above the line, no boat parts below it beyond the line's own chop.
- Murk check across shots: `task-6-murk.png` clearly darker than `task-6-school.png`. If it's inverted (lighter when deeper), the `setInk` inversion is wrong on this SDK — flip `1 - darkness` to `darkness` in `setInk` and re-check the sea tint from Task 3 too.

Restore `Shots.plan = {}` before committing.

**Deferred to the Task 9 human pass (list in your report):** tail-flap animation, bubble recycling at the bottom, 30 fps hold while rotating with everything on screen.

- [ ] **Step 4: Commit**

```bash
git add source
git commit --no-gpg-sign -m "Add underwater world with fish, bubbles, light rays, and murk"
```

---

### Task 7: Surfacing droplet effect

**Files:**
- Modify: `source/render.lua`

**Interfaces:**
- Consumes: `Scope.surfacedProgress()` (Task 4).
- Produces: droplet streaks drawn inside the eyepiece for 0.5 s after surfacing.

- [ ] **Step 1: Add droplets to `source/render.lua`**

Insert after `drawBelow`:

```lua
-- Water streaks sliding down the lens just after it breaks the surface.
-- Fixed jitter tables keep it deterministic (no math.random in the loop).
local DROPLET_XS = { -70, -52, -31, -12, 4, 22, 47, 68, 86 }

local function drawDroplets(progress)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(2)
    for i, dx in ipairs(DROPLET_XS) do
        local stagger = (i % 3) * 0.12
        local p = Geom.clamp((progress - stagger) / (1 - stagger), 0, 1)
        if p > 0 then
            local x = Render.CENTER_X + dx
            local y0 = Render.CENTER_Y - Render.RADIUS
                + p * p * 150 + (i * 17) % 40
            gfx.drawLine(x, y0, x, y0 + 10 + (i % 4) * 3)
        end
    end
    gfx.setLineWidth(1)
end
```

Then in `Render.draw`, insert between `drawWaterline(wy)` and `mask:draw(0, 0)`:

```lua
    local sp = Scope.surfacedProgress()
    if sp then
        drawDroplets(sp)
    end
```

- [ ] **Step 2: Verify via the screenshot harness**

The harness can't turn the crank, but it can pin `Scope.surfacedTimer` directly to freeze the droplet animation mid-flight (`surfacedProgress()` reads it). Temporarily set in `source/shots.lua` (full absolute paths under `/Users/norton/wrk/supertinylabs/submariner/.superpowers/sdd/`):

```lua
Shots.plan = {
    { after = 1.5, set = { height = 0.15, surfacedTimer = 0.1 },  path = ".../task-7-early.png" },
    { after = 1.0, set = { height = 0.15, surfacedTimer = 0.35 }, path = ".../task-7-late.png" },
    { after = 1.0, set = { height = 0.15, surfacedTimer = 0.9 },  path = ".../task-7-gone.png" },
}
```

Read each PNG:
- `task-7-early.png`: several short vertical streaks in the upper part of the lens (first stagger wave started, later waves not yet).
- `task-7-late.png`: more streaks, clearly lower in the lens than in the early shot (they accelerate downward).
- `task-7-gone.png`: no streaks (timer past the 0.5 s window).

Restore `Shots.plan = {}` before committing.

**Deferred to the Task 9 human pass (list in your report):** live retrigger when cranking across the surface repeatedly; nothing triggers when crossing downward.

- [ ] **Step 3: Commit**

```bash
git add source
git commit --no-gpg-sign -m "Add droplet streaks when the scope breaks the surface"
```

---

### Task 8: Synthesized ambience

**Files:**
- Create: `source/ambience.lua`
- Modify: `source/main.lua`

**Interfaces:**
- Consumes: `Geom.crossfadeMix`, `Scope.height`, `Scope.surfacedNow`.
- Produces the `Ambience` global:
  - `Ambience.init()` — builds synths/channels; call once.
  - `Ambience.update(dt)` — crossfades beds, schedules one-shots; call every update.

- [ ] **Step 1: Write `source/ambience.lua`**

```lua
import "geom"

local snd = playdate.sound

Ambience = {}

local aboveChannel, belowChannel
local hum1, hum2, lap, ping, gull, splash
local pingClock = 4
local gullClock = 6
local lapPhase = 0

function Ambience.init()
    -- Below the surface: two detuned sines beating slowly, low-passed to a hum.
    -- Pitched at 110 Hz (not lower) so the device's small speaker can voice it.
    belowChannel = snd.channel.new()
    local belowFilter = snd.twopolefilter.new(snd.kFilterLowPass)
    belowFilter:setFrequency(320)
    belowChannel:addEffect(belowFilter)
    hum1 = snd.synth.new(snd.kWaveSine)
    hum2 = snd.synth.new(snd.kWaveSine)
    belowChannel:addSource(hum1)
    belowChannel:addSource(hum2)
    hum1:playNote(110, 0.25)      -- no length: sustains until noteOff
    hum2:playNote(112, 0.18)

    -- Above: filtered noise as wave wash, swelled from update().
    aboveChannel = snd.channel.new()
    local aboveFilter = snd.twopolefilter.new(snd.kFilterLowPass)
    aboveFilter:setFrequency(900)
    aboveChannel:addEffect(aboveFilter)
    lap = snd.synth.new(snd.kWaveNoise)
    aboveChannel:addSource(lap)
    lap:playNote(220, 0.2)
    gull = snd.synth.new(snd.kWaveSquare)
    gull:setADSR(0.02, 0.1, 0.3, 0.15)
    aboveChannel:addSource(gull)

    -- One-shots on the default channel so the bed filters don't muffle them.
    ping = snd.synth.new(snd.kWaveSine)
    ping:setADSR(0.001, 0.4, 0, 0.3)
    splash = snd.synth.new(snd.kWaveNoise)
    splash:setADSR(0.005, 0.25, 0, 0.1)
end

function Ambience.update(dt)
    local mix = Geom.crossfadeMix(Scope.height)
    aboveChannel:setVolume(mix * 0.8)
    belowChannel:setVolume((1 - mix) * 0.75)

    -- Slow, layered swell so the noise bed laps rather than hisses.
    -- (Base exceeds the sine amplitudes so the volume never goes negative.)
    lapPhase = lapPhase + dt
    lap:setVolume(0.16 + 0.1 * math.sin(lapPhase * 0.9)
        + 0.05 * math.sin(lapPhase * 2.3))

    pingClock = pingClock - dt
    if pingClock <= 0 and mix < 0.4 then
        ping:playNote(1100, 0.25, 0.5)
        pingClock = 6 + math.random() * 4
    end

    gullClock = gullClock - dt
    if gullClock <= 0 and mix > 0.6 then
        local now = snd.getCurrentTime()
        gull:playNote(1350, 0.18, 0.12, now)
        gull:playNote(1080, 0.15, 0.2, now + 0.15)
        gullClock = 8 + math.random() * 6
    end

    if Scope.surfacedNow then
        splash:playNote(400, 0.4, 0.25)
    end
end
```

- [ ] **Step 2: Wire into `source/main.lua`**

Add `import "ambience"` after `import "render"`, add `Ambience.init()` after `World.init()`, and add `Ambience.update(dt)` after `Render.draw(dt)`:

```lua
import "CoreLibs/graphics"
import "CoreLibs/ui"
import "tests"
import "scope"
import "world"
import "render"
import "ambience"
import "shots"

playdate.display.setRefreshRate(30)

Render.init()
World.init()
Ambience.init()
if playdate.isSimulator then
    runTests()
end

function playdate.update()
    local dt = playdate.getElapsedTime()
    playdate.resetElapsedTime()
    if dt <= 0 or dt > 0.25 then
        dt = 1 / 30
    end
    Scope.update(dt)
    World.update(dt)
    Render.draw(dt)
    Ambience.update(dt)
    if playdate.isCrankDocked() then
        playdate.ui.crankIndicator:draw()
    end
    Shots.update(dt)
end
```

- [ ] **Step 3: Verify stability via the screenshot harness (audio itself is deferred)**

Audio can't be verified headlessly, but the audio code paths can be exercised: a long submerged stretch fires the sonar-ping branch (~4 s in), a long raised stretch fires the gull branch, and the crossfade runs every frame. Any Lua error in those paths crashes the simulator, which the harness run would surface. Temporarily set in `source/shots.lua` (full absolute paths under `/Users/norton/wrk/supertinylabs/submariner/.superpowers/sdd/`):

```lua
Shots.plan = {
    { after = 6, set = { height = -0.8 }, path = ".../task-8-submerged.png" },
    { after = 9, set = { height = 0.8 },  path = ".../task-8-raised.png" },
}
```

Run the harness command (use `timeout 45` — this plan runs ~15 s plus load time). Expected: both PNGs written, console shows `geom tests: all passed` and no Lua errors; the images match their heights (mostly water / mostly sky).

Restore `Shots.plan = {}` before committing.

**Deferred to the Task 9 human pass (list in your report):** submerged hum + ping every 6–10 s; splash on surfacing; lapping swell + occasional two-note gull when raised; both beds faintly audible exactly at the line.

- [ ] **Step 4: Commit**

```bash
git add source
git commit --no-gpg-sign -m "Add synthesized ambience with waterline crossfade"
```

---

### Task 9: Acceptance pass, README, tuning

**Files:**
- Create: `README.md`
- Modify: `source/main.lua` (temporary FPS overlay, then remove)
- Modify: any tunables that fail the feel check (document what changed in the commit message)

**Interfaces:**
- Consumes: everything.
- Produces: v1 signed off against the spec's six acceptance criteria.

- [ ] **Step 1: Temporary FPS check (headless)**

Temporarily add as the last line of `playdate.update()`:

```lua
    if playdate.isSimulator and playdate.getCurrentTimeMilliseconds() > 4000 then
        print("fps", playdate.getFPS())
    end
```

Set a harness plan with one busy submerged shot (`{ after = 8, set = { height = -0.3, bearing = 70 }, path = ".../task-9-busy.png" }`) and one raised (`{ after = 4, set = { height = 0.5, bearing = 40 }, path = ".../task-9-raised.png" }`), run with `timeout 45`, and check the printed fps values.
Expected: values steady at ≈30 (29+ acceptable). Remove the print line and restore `Shots.plan = {}` afterwards.

- [ ] **Step 2: Walk the six acceptance criteria from the spec (autonomous forms)**

1. `make build` exits 0; the direct simulator launch prints `geom tests: all passed` and no Lua errors.
2. D-pad rotation logic: covered by geom tests (wrap, ramp curve); live feel is on the human checklist.
3. Line fully exits the circle at both extremes: re-check `task-3-up.png` / `task-3-down.png` equivalents with a fresh two-shot harness run at `height = 1` and `height = -1`.
4. Three boat types + lighthouse above; two schools, two lone fish, bubbles below; murk deepens with depth: verified by the Task 5/6 PNGs still in `.superpowers/sdd/` — spot-check they exist and match; re-shoot any that are missing.
5. Droplets on surfacing: Task 7 PNGs; splash sound is on the human checklist.
6. Ambience crossfade: code path exercised in Task 8; audible behavior is on the human checklist.

Fix anything that fails before proceeding; re-run the failing check after each fix.

- [ ] **Step 2b: Compile the human checklist**

Write `.superpowers/sdd/human-checklist.md` listing every deferred item from Tasks 4–8 reports (rotation ramp feel, crank sweep/clamp feel, wrap, live droplet retrigger, all audio items, live fps while rotating). This is handed to the user after the build — it is the final acceptance gate for feel and audio.

- [ ] **Step 3: Write `README.md`**

```markdown
# Submariner

An ambient submarine periscope toy for [Playdate](https://play.date).

Rotate the periscope with the d-pad. Raise and lower it with the crank —
three full turns sweep from the depths to high above the waves. Boats, gulls,
and a lighthouse above the waterline; fish, bubbles, and deepening murk below.
No objectives. Just watch the sea.

## Build

Requires the [Playdate SDK](https://play.date/dev/) at `~/Developer/PlaydateSDK`.

- `make build` — compile `Submariner.pdx`
- `make run` — build and launch in the Playdate Simulator

To play on a device, build then sideload `Submariner.pdx` via the simulator
(Device menu) or [play.date/account](https://play.date/account/).
```

- [ ] **Step 4: Final commit**

```bash
git add README.md source
git commit --no-gpg-sign -m "Add README and tune constants after acceptance pass"
```
