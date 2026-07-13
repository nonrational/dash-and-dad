# I Spy Objective Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an always-on "I Spy" objective to the periscope toy: a right-hand rail names a category ("FIND A SHARK"), the player aims and holds the crosshairs on a matching entity, and a successful find flashes/chimes before a new target appears.

**Architecture:** A new `spy.lua` module (mirrors `scope.lua`) owns target selection and aim/hold detection state. Detection math is pure and lives in `geom.lua` next to the existing wrap/delta helpers. `world.lua` gains five new entity types (rival submarine, plane, helicopter, shark, whale). `render.lua` shifts the eyepiece left, draws the five new entities, and draws the rail (icon + word + hold-progress crosshair fill). `ambience.lua` adds a find chime. `main.lua` wires `Spy.update` into the loop between `World.update` and `Render.draw`.

**Tech Stack:** Lua (Playdate SDK 3.0.6), `pdc` build, Playdate Simulator.

## Global Constraints

- Bearing alignment tolerance: **±6°** (`Geom.wrappedDelta` magnitude).
- Hold duration to register a find: **0.7s** of continuous alignment + visibility.
- Find flash/hold-before-advance duration: **1.0s**.
- Eyepiece `Render.CENTER_X` moves from **200 to 120** (radius 104, center Y 110 unchanged).
- 8 spy categories total; target selection is uniform random across *categories* (not weighted by instance count) and never repeats the category just found; the very first target at boot is fixed to `"lighthouse"` (a stationary landmark — also makes deterministic testing possible).
- One instance each of the five new entity types (rival submarine, plane, helicopter, shark, whale) — matches the existing "one lighthouse" scale.
- No image or audio assets — everything stays code-drawn 1-bit graphics and synthesized audio (carried over from the base spec).
- `geom.lua` stays free of `playdate.*` calls (the one module with boot-time unit tests); `spy.lua`/`world.lua` reference `Scope`/`World`/`Render`/`Geom` as plain Lua globals without `playdate.*` calls either, but are verified via the screenshot harness, not `tests.lua` — this matches the project's existing convention (only `geom.lua` gets unit assertions).
- **Smoke-test recipe** (used throughout this plan in place of GUI `make run`, so a subagent can verify without a human watching the simulator): build, then run the simulator binary directly with a timeout, then check whether the expected screenshot file was written.

  ```bash
  make build
  rm -f /tmp/submariner-<name>.png   # and any other paths this task's Shots.plan writes
  timeout -k 5 15 "$HOME/Developer/PlaydateSDK/bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator" Submariner.pdx > /tmp/submariner-<name>.log 2>&1
  ls -la /tmp/submariner-<name>.png
  ```

  Use `timeout -k 5 15 ...`, not plain `timeout 15 ...` — plain SIGTERM does not reliably kill this GUI simulator app (confirmed during Task 2's execution: a genuinely-erroring build left the process alive and unkillable by SIGTERM alone); `-k 5` forces a SIGKILL 5s after the deadline if it doesn't exit on its own.

  If `source/tests.lua`'s boot assertions fail, `runTests()` throws before the update loop (and thus `Shots.update`) ever runs — the simulator hangs on an error dialog with **no screenshot file written** until `timeout -k` kills it. If boot succeeds, `Shots` writes every configured screenshot and then calls `playdate.simulator.exit()`, which segfaults when the simulator is launched this way (bypassing the normal `.app` launch path) — **that segfault is expected and not a failure signal**; only the presence/absence and content of the screenshot file(s) matter. Note also: a Lua *runtime* error (as opposed to a syntax error `pdc` would catch) produces this exact same "no screenshot, needs SIGKILL" signature — the simulator pauses its render thread rather than crashing the process. If a task's world/render changes are meant to be tested independently but the new code is only safe once a *later* task's code lands (e.g. a new entity type with no renderer yet), say so explicitly in that task's brief so the smoke test isn't misread as an environment problem.
- Per the project's documented `shots.lua` convention: `Shots.plan` is edited to a temporary probe list to run a smoke test, then **reverted to `{}` before committing** — every task below does this explicitly.
- **Splash screen** (added after the original 7 tasks, per direct user request): on boot, before any gameplay, show a plain white screen with two centered lines of text — `"For Dash, Love Dad"` and `"Press A to submerge..."` — dismissed by pressing the A button, after which the game proceeds exactly as before. No image assets; same default font already used for the HUD.

---

### Task 1: Geom alignment/visibility helpers + tests

**Files:**
- Modify: `source/geom.lua`
- Modify: `source/tests.lua`
- Modify: `source/render.lua:259-266` (refactor to reuse the new helpers)
- Modify (temporary, reverted before commit): `source/shots.lua`

**Interfaces:**
- Produces: `Geom.bearingAligned(entityBearing, scopeBearing, toleranceDeg) -> bool`, `Geom.aboveVisible(waterY, centerY, radius) -> bool`, `Geom.belowVisible(waterY, centerY, radius) -> bool`. Later tasks (`spy.lua`) call these directly.

- [ ] **Step 1: Write the failing tests**

  In `source/tests.lua`, add an `ok` boolean-assertion helper alongside the existing `eq` helper, and add assertions for the three not-yet-implemented functions. Replace the whole file with:

  ```lua
  import "geom"

  function runTests()
      local function eq(actual, expected, msg)
          if math.abs(actual - expected) > 1e-9 then
              error(string.format("FAIL %s: expected %s, got %s",
                  msg, tostring(expected), tostring(actual)))
          end
      end

      local function ok(cond, msg)
          if not cond then
              error(string.format("FAIL %s: expected true", msg))
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

      ok(Geom.bearingAligned(50, 47, 6), "bearing aligned within tolerance")
      ok(not Geom.bearingAligned(60, 47, 6), "bearing outside tolerance")
      ok(Geom.bearingAligned(2, 358, 6), "bearing aligned across zero wrap")

      ok(Geom.aboveVisible(50, 110, 104), "above visible when waterline below circle top")
      ok(not Geom.aboveVisible(-10, 110, 104), "above not visible when waterline above circle")

      ok(Geom.belowVisible(150, 110, 104), "below visible when waterline above circle bottom")
      ok(not Geom.belowVisible(230, 110, 104), "below not visible when waterline below circle")

      print("geom tests: all passed")
  end
  ```

- [ ] **Step 2: Set up the smoke-test probe**

  In `source/shots.lua`, change line 7 from `Shots = { plan = {}, t = 0, i = 1 }` to:

  ```lua
  Shots = { plan = {
      { after = 0.1, path = "/tmp/submariner-task1.png" },
  }, t = 0, i = 1 }
  ```

- [ ] **Step 3: Run the smoke test, confirm it fails**

  ```bash
  make build
  rm -f /tmp/submariner-task1.png
  timeout 15 "$HOME/Developer/PlaydateSDK/bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator" Submariner.pdx > /tmp/submariner-task1.log 2>&1
  ls -la /tmp/submariner-task1.png
  ```

  Expected: `make build` succeeds (pdc only checks syntax, and calling an undefined `Geom.bearingAligned` is a runtime error, not a syntax error). `ls` reports "No such file or directory" — `runTests()` errored on the first `ok(...)` assertion before the update loop (and `Shots`) ever ran.

- [ ] **Step 4: Implement the minimal code to make the tests pass**

  In `source/geom.lua`, append after `Geom.rotationSpeed` (after the existing final line):

  ```lua

  -- True if entityBearing sits within toleranceDeg of scopeBearing (used by
  -- the spy-target aim check).
  function Geom.bearingAligned(entityBearing, scopeBearing, toleranceDeg)
      return math.abs(Geom.wrappedDelta(scopeBearing, entityBearing)) <= toleranceDeg
  end

  -- Mirrors the visibility gates Render.draw uses to decide whether the
  -- above/below layers render this frame, so spy detection only counts a
  -- target as found when it is actually on screen.
  function Geom.aboveVisible(waterY, centerY, radius)
      return waterY > centerY - radius
  end

  function Geom.belowVisible(waterY, centerY, radius)
      return waterY < centerY + radius
  end
  ```

- [ ] **Step 5: Reuse the helpers in Render.draw**

  In `source/render.lua`, in `Render.draw` (currently lines 256-275), replace:

  ```lua
      local wy = waterY()
      if wy > Render.CENTER_Y - Render.RADIUS then
          drawAbove(wy)
      end
      if wy < Render.CENTER_Y + Render.RADIUS then
          drawSea(wy)
          drawBelow(wy)
      end
  ```

  with:

  ```lua
      local wy = waterY()
      if Geom.aboveVisible(wy, Render.CENTER_Y, Render.RADIUS) then
          drawAbove(wy)
      end
      if Geom.belowVisible(wy, Render.CENTER_Y, Render.RADIUS) then
          drawSea(wy)
          drawBelow(wy)
      end
  ```

- [ ] **Step 6: Run the smoke test again, confirm it passes**

  ```bash
  make build
  rm -f /tmp/submariner-task1.png
  timeout 15 "$HOME/Developer/PlaydateSDK/bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator" Submariner.pdx > /tmp/submariner-task1.log 2>&1
  ls -la /tmp/submariner-task1.png
  ```

  Expected: `ls` shows `/tmp/submariner-task1.png` exists (tests passed, boot proceeded, the screenshot was written before the simulator exited/segfaulted).

- [ ] **Step 7: Revert the smoke-test probe**

  In `source/shots.lua`, change `Shots.plan` back to `{}`: `Shots = { plan = {}, t = 0, i = 1 }`.

- [ ] **Step 8: Commit**

  ```bash
  git add source/geom.lua source/tests.lua source/render.lua source/shots.lua
  git commit -m "Add bearing/visibility helpers to geom.lua for spy detection"
  ```

---

### Task 2: New world entities (rival submarine, plane, helicopter, shark, whale)

**Files:**
- Modify: `source/world.lua`
- Modify (temporary, reverted before commit): `source/shots.lua`

**Interfaces:**
- Consumes: `Geom.wrap360` (existing).
- Produces: `World.boats` gains one entry with `type = "sub"`. New tables `World.planes`, `World.helicopters`, `World.sharks`, `World.whales`, each a list of one entity table with a `.bearing` field (required by later tasks' detection and rendering code). Whale entities additionally expose `.depth` (updated every frame, oscillates between roughly 20 and 160) for the spout check in Task 3.

- [ ] **Step 1: Add the new entities to `World.init`**

  In `source/world.lua`, in `World.init` (currently lines 14-56), add a sixth boat after the existing five (inside the `World.boats = { ... }` table, after the `trawler`/`near`/`335` entry):

  ```lua
          { type = "sub",     lane = "mid",  bearing = 15,  dir = 1,  bobPhase = 4.4 },
  ```

  Then, after the closing of the `World.bubbles` loop (the `end` that closes `for _, colBearing in ipairs(...)`, right before `World.init`'s own closing `end`), add:

  ```lua
      World.planes = {
          { bearing = 100, above = 92, drift = 8,   dir = 1 },
      }
      World.helicopters = {
          { bearing = 260, above = 65, drift = 3.5, dir = -1, rotorPhase = 0 },
      }
      World.sharks = {
          { bearing = 190, depth = 70, dir = 1,  speed = 4.5, phase = 0 },
      }
      World.whales = {
          { bearing = 340, depth = 90, dir = -1, speed = 1.0, phase = 0, spoutPhase = 0 },
      }
  ```

- [ ] **Step 2: Drive the new entities in `World.update`**

  In `source/world.lua`, in `World.update` (currently lines 58-83), add before the final `end` that closes the function (after the existing `World.bubbles` loop):

  ```lua
      for _, p in ipairs(World.planes) do
          p.bearing = Geom.wrap360(p.bearing + p.dir * p.drift * dt)
      end
      for _, h in ipairs(World.helicopters) do
          h.bearing = Geom.wrap360(h.bearing + h.dir * h.drift * dt)
          h.rotorPhase = h.rotorPhase + dt * 14
      end
      for _, sh in ipairs(World.sharks) do
          sh.bearing = Geom.wrap360(sh.bearing + sh.dir * sh.speed * dt)
          sh.phase = sh.phase + dt * 3
      end
      for _, w in ipairs(World.whales) do
          w.bearing = Geom.wrap360(w.bearing + w.dir * w.speed * dt)
          w.spoutPhase = w.spoutPhase + dt * 0.3
          w.depth = 90 + math.sin(w.spoutPhase) * 70
          w.phase = w.phase + dt * 1.5
      end
  ```

- [ ] **Step 3: Smoke-test that the update loop doesn't error**

  In `source/shots.lua`, set:

  ```lua
  Shots = { plan = {
      { after = 2.0, path = "/tmp/submariner-task2.png" },
  }, t = 0, i = 1 }
  ```

  Run:

  ```bash
  make build
  rm -f /tmp/submariner-task2.png
  timeout 15 "$HOME/Developer/PlaydateSDK/bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator" Submariner.pdx > /tmp/submariner-task2.log 2>&1
  ls -la /tmp/submariner-task2.png
  ```

  Expected: file exists — 2 simulated seconds (~60 update frames) of the new drift/oscillation loops ran without a nil-index or arithmetic error. (The new entities aren't drawn yet, so the image itself looks unchanged from before this task — that's expected; Task 3 adds rendering.)

- [ ] **Step 4: Revert the smoke-test probe**

  In `source/shots.lua`, set `Shots.plan` back to `{}`.

- [ ] **Step 5: Commit**

  ```bash
  git add source/world.lua source/shots.lua
  git commit -m "Add rival submarine, plane, helicopter, shark, and whale to the world"
  ```

---

### Task 3: Shift the eyepiece left and render the new entities

**Files:**
- Modify: `source/render.lua` (full-file rewrite — many small, non-contiguous edits)
- Modify (temporary, reverted before commit): `source/shots.lua`

**Interfaces:**
- Consumes: `World.boats[*].type == "sub"`, `World.planes`, `World.helicopters`, `World.sharks`, `World.whales` (Task 2).
- Produces: `Render.CENTER_X = 120` (was 200) — later tasks (`spy.lua`, rail rendering) read this. No other new public interface; this task only changes drawing.

- [ ] **Step 1: Rewrite `source/render.lua`**

  Replace the entire file with:

  ```lua
  import "CoreLibs/graphics"
  import "geom"

  local gfx = playdate.graphics

  Render = {
      CENTER_X = 120,
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
      -- The image must be created clear: Playdate images only carry an alpha
      -- mask when built on a transparent background, so punching kColorClear
      -- into a black-background image is a no-op and the mask stays opaque.
      mask = gfx.image.new(400, 240, gfx.kColorClear)
      gfx.pushContext(mask)
      gfx.setColor(gfx.kColorBlack)
      gfx.fillRect(0, 0, 400, 240)
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
      local left = Render.CENTER_X - Render.RADIUS
      local right = Render.CENTER_X + Render.RADIUS
      for row = 1, 5 do
          local y = wy + 8 + row * 14
          local phase = (t * (14 - row * 2) + row * 53
              - Scope.bearing * Render.PX_PER_DEG) % 40
          for x = left - phase, right, 40 do
              gfx.drawLine(x, y, x + 12 - row, y)
          end
      end
  end

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

  -- Rival submarine: low flat hull, small conning tower.
  local function drawSub(x, y, s, dir)
      local function px(dx) return x + dx * s * dir end
      gfx.setColor(gfx.kColorBlack)
      gfx.fillPolygon(px(-20), y, px(20), y, px(24), y - 3 * s, px(-24), y - 3 * s)
      gfx.fillRect(math.min(px(-4), px(4)), y - 9 * s, 8 * s, 6 * s)
      gfx.drawLine(px(0), y - 9 * s, px(0), y - 13 * s)
  end

  local BOAT_DRAWERS = { sail = drawSail, trawler = drawTrawler, cargo = drawCargo, sub = drawSub }
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

  local function drawPlanes(wy)
      gfx.setColor(gfx.kColorBlack)
      for _, p in ipairs(World.planes) do
          local x = Geom.bearingToScreenX(p.bearing, Scope.bearing,
              Render.CENTER_X, Render.PX_PER_DEG)
          if x > -30 and x < 430 then
              local y = wy - p.above
              gfx.fillPolygon(x - 14, y, x + 14, y - 1, x + 16, y + 1, x - 13, y + 2)
              gfx.fillTriangle(x - 2, y, x - 2, y - 7, x + 4, y)
              gfx.fillTriangle(x - 2, y + 1, x - 2, y + 6, x + 3, y + 1)
          end
      end
  end

  local function drawHelicopters(wy)
      gfx.setColor(gfx.kColorBlack)
      for _, h in ipairs(World.helicopters) do
          local x = Geom.bearingToScreenX(h.bearing, Scope.bearing,
              Render.CENTER_X, Render.PX_PER_DEG)
          if x > -30 and x < 430 then
              local y = wy - h.above
              gfx.fillRoundRect(x - 9, y - 3, 18, 7, 3)
              gfx.fillRect(x + 7, y - 1, 8, 3)
              local spread = (math.sin(h.rotorPhase) > 0) and 16 or 10
              gfx.drawLine(x - spread, y - 6, x + spread, y - 6)
          end
      end
  end

  -- Whale spout: a small dithered plume drawn above the waterline at the
  -- whale's bearing while it's near-surface. The whale's body always draws
  -- in the underwater layer (drawWhales, below) regardless of spout state.
  local WHALE_SPOUT_DEPTH = 35

  local function drawWhaleSpouts(wy)
      setInk(0.3)
      for _, w in ipairs(World.whales) do
          if w.depth < WHALE_SPOUT_DEPTH then
              local x = Geom.bearingToScreenX(w.bearing, Scope.bearing,
                  Render.CENTER_X, Render.PX_PER_DEG)
              if x > -20 and x < 420 then
                  gfx.fillPolygon(x - 3, wy, x + 3, wy, x + 5, wy - 18, x - 5, wy - 18)
              end
          end
      end
  end

  -- Everything above the waterline, clipped to it so hulls sit "in" the water.
  local function drawAbove(wy)
      gfx.setClipRect(0, 0, 400, wy)
      drawClouds(wy)
      drawPlanes(wy)
      drawHelicopters(wy)
      drawWhaleSpouts(wy)
      local lx = Geom.bearingToScreenX(World.lighthouse.bearing, Scope.bearing,
          Render.CENTER_X, Render.PX_PER_DEG)
      if lx > -40 and lx < 440 then
          drawLighthouse(lx, wy)
      end
      for _, laneName in ipairs(LANE_ORDER) do
          local lane = World.LANES[laneName]
          -- Extend the clip by the lane's dip so the lower hull stays visible
          -- below the line (the sea tint and chop draw over it afterwards);
          -- clipping exactly at wy would swallow near-lane hulls entirely.
          gfx.setClipRect(0, 0, 400, wy + lane.yOff)
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

  -- Shark: bigger than a lone fish, with a distinct dorsal fin.
  local function drawShark(x, y, dir, phase)
      local function px(dx) return x + dx * dir end
      gfx.setColor(gfx.kColorBlack)
      gfx.fillEllipseInRect(math.min(px(-13), px(13)), y - 4, 26, 8)
      gfx.fillTriangle(px(-2), y - 4, px(2), y - 12, px(5), y - 4)
      local up = (math.sin(phase) > 0) and 5 or 2
      gfx.fillTriangle(px(-13), y, px(-20), y - up, px(-20), y + (6 - up))
  end

  local function drawSharks(wy)
      for _, sh in ipairs(World.sharks) do
          local x = Geom.bearingToScreenX(sh.bearing, Scope.bearing,
              Render.CENTER_X, Render.PX_PER_DEG)
          if x > -30 and x < 430 then
              local y = wy + sh.depth + math.sin(sh.phase * 0.4) * 3
              drawShark(x, y, sh.dir, sh.phase)
          end
      end
  end

  -- Whale body: the largest underwater silhouette.
  local function drawWhale(x, y, dir, phase)
      local function px(dx) return x + dx * dir end
      gfx.setColor(gfx.kColorBlack)
      gfx.fillEllipseInRect(math.min(px(-30), px(30)), y - 8, 60, 16)
      gfx.fillTriangle(px(-30), y, px(-42), y - 10, px(-42), y + 10)
      local flip = math.sin(phase) * 2
      gfx.fillTriangle(px(28), y + flip, px(28), y - 6 + flip, px(38), y - 10 + flip)
  end

  local function drawWhales(wy)
      for _, w in ipairs(World.whales) do
          local x = Geom.bearingToScreenX(w.bearing, Scope.bearing,
              Render.CENTER_X, Render.PX_PER_DEG)
          if x > -50 and x < 450 then
              local y = wy + w.depth
              drawWhale(x, y, w.dir, w.phase)
          end
      end
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
      drawSharks(wy)
      drawWhales(wy)
      drawMurk(wy)
      gfx.clearClipRect()
  end

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

  local function drawWaterline(wy)
      gfx.setColor(gfx.kColorBlack)
      local left = Render.CENTER_X - Render.RADIUS - 4
      local right = Render.CENTER_X + Render.RADIUS + 4
      for x = left, right, 2 do
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
      gfx.drawTextAligned(string.format("BRG %03d", brg),
          Render.CENTER_X, 220, kTextAlignment.center)
      gfx.setImageDrawMode(gfx.kDrawModeCopy)
  end

  function Render.draw(dt)
      t = t + dt
      gfx.clear(gfx.kColorWhite)
      local wy = waterY()
      if Geom.aboveVisible(wy, Render.CENTER_Y, Render.RADIUS) then
          drawAbove(wy)
      end
      if Geom.belowVisible(wy, Render.CENTER_Y, Render.RADIUS) then
          drawSea(wy)
          drawBelow(wy)
      end
      drawWaterline(wy)
      local sp = Scope.surfacedProgress()
      if sp then
          drawDroplets(sp)
      end
      mask:draw(0, 0)
      drawCrosshairs()
      drawHUD()
  end
  ```

  (This carries forward the `Geom.aboveVisible`/`belowVisible` refactor from Task 1 — the file is being fully rewritten here, so it's included rather than re-diffed.)

- [ ] **Step 2: Screenshot smoke test covering all new entities**

  In `source/shots.lua`, set:

  ```lua
  Shots = { plan = {
      { after = 0.1, set = { bearing = 15,  height = 0.3 },  path = "/tmp/submariner-task3-sub.png" },
      { after = 0.1, set = { bearing = 100, height = 0.6 },  path = "/tmp/submariner-task3-plane.png" },
      { after = 0.1, set = { bearing = 260, height = 0.6 },  path = "/tmp/submariner-task3-heli.png" },
      { after = 0.1, set = { bearing = 190, height = -0.3 }, path = "/tmp/submariner-task3-shark.png" },
      { after = 0.1, set = { bearing = 55,  height = 0.0 },  path = "/tmp/submariner-task3-waterline.png" },
  }, t = 0, i = 1 }
  ```

  Run:

  ```bash
  make build
  rm -f /tmp/submariner-task3-*.png
  timeout 15 "$HOME/Developer/PlaydateSDK/bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator" Submariner.pdx > /tmp/submariner-task3.log 2>&1
  ls -la /tmp/submariner-task3-*.png
  ```

  Expected: all five files exist. Use the Read tool to view each PNG and confirm:
  - `submariner-task3-sub.png`: the eyepiece circle sits left-shifted (touching close to the left edge, not centered), and a low-hull submarine silhouette with a small conning tower is visible in the mid lane.
  - `submariner-task3-plane.png`: a small wing-shaped silhouette in the sky.
  - `submariner-task3-heli.png`: a body + tail boom + rotor-bar silhouette in the sky.
  - `submariner-task3-shark.png`: a bigger fish-like silhouette with a dorsal fin, underwater.
  - `submariner-task3-waterline.png`: the sea-tint chop and waterline dot-texture fully fill the left-shifted circle's width with no visible gap on the left side where the old hardcoded 96-308px bounds used to fall outside the new circle position.

  If any entity is missing, oddly placed, or the chop/waterline texture has a visible gap, fix the corresponding coordinates in `source/render.lua` and re-run this step before proceeding. (Whale spout is intentionally not asserted here — it only appears when `depth < 35`, which the whale's slow oscillation may not reach in a 0.1s single-frame capture; it's covered qualitatively by the human acceptance checklist in Task 7.)

- [ ] **Step 3: Revert the smoke-test probe**

  In `source/shots.lua`, set `Shots.plan` back to `{}`.

- [ ] **Step 4: Commit**

  ```bash
  git add source/render.lua source/shots.lua
  git commit -m "Shift the eyepiece left and render the new spy entities"
  ```

---

### Task 4: Spy module — target selection, aim/hold detection, minimal rail

**Files:**
- Create: `source/spy.lua`
- Modify: `source/main.lua`
- Modify: `source/render.lua` (add a minimal text-only rail)
- Modify (temporary, reverted before commit): `source/shots.lua`

**Interfaces:**
- Consumes: `Geom.bearingAligned`, `Geom.aboveVisible`, `Geom.belowVisible` (Task 1); `Scope.bearing`, `Scope.height` (existing); `World.boats`, `World.lighthouse`, `World.planes`, `World.helicopters`, `World.schools`, `World.sharks`, `World.whales` (Task 2); `Render.CENTER_Y`, `Render.RADIUS`, `Render.SWING` (existing/Task 3).
- Produces: `Spy.init()`, `Spy.update(dt)`; public state `Spy.target` (string, one of `"lighthouse"`, `"boat"`, `"submarine"`, `"plane"`, `"helicopter"`, `"fish school"`, `"shark"`, `"whale"`), `Spy.holdProgress` (0..1), `Spy.foundNow` (bool, true for exactly one frame on a successful find), `Spy.flashTimer` (counts 0..`Spy.FLASH_DURATION` after a find), `Spy.FLASH_DURATION` (constant, 1.0). Task 5 (rail polish) and Task 6 (chime) read these.

- [ ] **Step 1: Create `source/spy.lua`**

  ```lua
  import "geom"

  local BEARING_TOLERANCE = 6
  local HOLD_DURATION = 0.7
  local FLASH_DURATION = 1.0

  local function boatsOfType(kind)
      local out = {}
      for _, b in ipairs(World.boats) do
          if (kind == nil and b.type ~= "sub") or b.type == kind then
              out[#out + 1] = b
          end
      end
      return out
  end

  -- "lighthouse" is first so the game's opening target is a stationary
  -- landmark — easy for a first-time player, and deterministic to test.
  local CATEGORIES = {
      { name = "lighthouse",  above = true,  entities = function() return { World.lighthouse } end },
      { name = "boat",        above = true,  entities = function() return boatsOfType(nil) end },
      { name = "submarine",   above = true,  entities = function() return boatsOfType("sub") end },
      { name = "plane",       above = true,  entities = function() return World.planes end },
      { name = "helicopter",  above = true,  entities = function() return World.helicopters end },
      { name = "fish school", above = false, entities = function() return World.schools end },
      { name = "shark",       above = false, entities = function() return World.sharks end },
      { name = "whale",       above = false, entities = function() return World.whales end },
  }

  Spy = {
      FLASH_DURATION = FLASH_DURATION,
      targetIndex = 1,
      target = CATEGORIES[1].name,
      holdProgress = 0,
      foundNow = false,
      flashTimer = FLASH_DURATION,
  }

  local function pickNewTarget()
      local nextIndex = Spy.targetIndex
      if #CATEGORIES > 1 then
          repeat
              nextIndex = math.random(#CATEGORIES)
          until nextIndex ~= Spy.targetIndex
      end
      Spy.targetIndex = nextIndex
      Spy.target = CATEGORIES[nextIndex].name
      Spy.holdProgress = 0
  end

  function Spy.init()
      Spy.targetIndex = 1
      Spy.target = CATEGORIES[1].name
      Spy.holdProgress = 0
      Spy.flashTimer = FLASH_DURATION
  end

  function Spy.update(dt)
      Spy.foundNow = false

      if Spy.flashTimer < FLASH_DURATION then
          Spy.flashTimer = Spy.flashTimer + dt
          if Spy.flashTimer >= FLASH_DURATION then
              pickNewTarget()
          end
          return
      end

      local cat = CATEGORIES[Spy.targetIndex]
      local wy = Geom.waterlineY(Scope.height, Render.CENTER_Y, Render.SWING)
      local visible
      if cat.above then
          visible = Geom.aboveVisible(wy, Render.CENTER_Y, Render.RADIUS)
      else
          visible = Geom.belowVisible(wy, Render.CENTER_Y, Render.RADIUS)
      end

      local aligned = false
      if visible then
          for _, e in ipairs(cat.entities()) do
              if Geom.bearingAligned(e.bearing, Scope.bearing, BEARING_TOLERANCE) then
                  aligned = true
                  break
              end
          end
      end

      if aligned then
          Spy.holdProgress = Geom.clamp(Spy.holdProgress + dt / HOLD_DURATION, 0, 1)
          if Spy.holdProgress >= 1 then
              Spy.foundNow = true
              Spy.flashTimer = 0
              Spy.holdProgress = 0
          end
      else
          Spy.holdProgress = 0
      end
  end
  ```

- [ ] **Step 2: Wire `spy.lua` into `source/main.lua`**

  Replace the whole file with:

  ```lua
  import "CoreLibs/graphics"
  import "CoreLibs/ui"
  import "tests"
  import "scope"
  import "world"
  import "spy"
  import "render"
  import "ambience"
  import "shots"

  playdate.display.setRefreshRate(30)

  Render.init()
  World.init()
  Spy.init()
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
      Spy.update(dt)
      Render.draw(dt)
      Ambience.update(dt)
      if playdate.isCrankDocked() then
          playdate.ui.crankIndicator:draw()
      end
      Shots.update(dt)
  end
  ```

- [ ] **Step 3: Add a minimal rail so the target is visible on screen**

  In `source/render.lua`, add `RAIL_CENTER_X = 312, -- (CENTER_X + RADIUS + 400) / 2` as a new field in the `Render = { ... }` table (after `SWING = 120,`).

  Then add this function right after `drawHUD` (before `function Render.draw`):

  ```lua
  local function drawSpyRail()
      gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
      gfx.drawTextAligned(string.upper(Spy.target), Render.RAIL_CENTER_X, 110, kTextAlignment.center)
      gfx.setImageDrawMode(gfx.kDrawModeCopy)
  end
  ```

  Then in `Render.draw`, add a call after `drawHUD()`:

  ```lua
      drawCrosshairs()
      drawHUD()
      drawSpyRail()
  end
  ```

- [ ] **Step 4: Screenshot smoke test proving the detect → advance cycle works**

  In `source/shots.lua`, set:

  ```lua
  Shots = { plan = {
      { after = 0.3, set = { bearing = 305, height = 0.3 }, path = "/tmp/submariner-task4-a.png" },
      { after = 1.6, set = { bearing = 305, height = 0.3 }, path = "/tmp/submariner-task4-b.png" },
  }, t = 0, i = 1 }
  ```

  `World.lighthouse.bearing` is a fixed 305 (no drift), matching `Spy.init()`'s deterministic first target ("lighthouse"), so this is fully reproducible.

  Run:

  ```bash
  make build
  rm -f /tmp/submariner-task4-a.png /tmp/submariner-task4-b.png
  timeout 15 "$HOME/Developer/PlaydateSDK/bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator" Submariner.pdx > /tmp/submariner-task4.log 2>&1
  ls -la /tmp/submariner-task4-a.png /tmp/submariner-task4-b.png
  ```

  Expected: both files exist. Use the Read tool to view them:
  - `submariner-task4-a.png` (captured 0.3s in, mid-hold, below the 0.7s threshold): rail text reads **"LIGHTHOUSE"**.
  - `submariner-task4-b.png` (captured 1.9s in — the hold completed at ~0.7s, the 1.0s flash/advance window completed by ~1.7s): rail text reads a **different** category word (any of the other 7 is a pass; "LIGHTHOUSE" reappearing would mean the find never registered or the category didn't advance — investigate `spy.lua` if so).

- [ ] **Step 5: Revert the smoke-test probe**

  In `source/shots.lua`, set `Shots.plan` back to `{}`.

- [ ] **Step 6: Commit**

  ```bash
  git add source/spy.lua source/main.lua source/render.lua source/shots.lua
  git commit -m "Add spy target selection and aim/hold detection, wired into the loop"
  ```

---

### Task 5: Rail polish — icons, label, flash, crosshair tick-fill

**Files:**
- Modify: `source/render.lua`
- Modify (temporary, reverted before commit): `source/shots.lua`

**Interfaces:**
- Consumes: `Spy.target`, `Spy.holdProgress`, `Spy.flashTimer`, `Spy.FLASH_DURATION` (Task 4).
- Produces: no new public interface — this is the final visual form of the rail and crosshairs; no later task depends on anything new here.

- [ ] **Step 1: Add the 8 icon drawers and the icon lookup table**

  In `source/render.lua`, insert this block immediately before the `drawSpyRail` function added in Task 4:

  ```lua
  local function drawBoatIcon(x, y)
      gfx.fillPolygon(x - 30, y + 14, x + 30, y + 14, x + 22, y - 2, x - 22, y - 2)
      gfx.drawLine(x, y - 2, x, y - 30)
      gfx.fillTriangle(x + 2, y - 28, x + 24, y - 4, x + 2, y - 4)
  end

  local function drawLighthouseIcon(x, y)
      gfx.fillPolygon(x - 8, y + 20, x + 8, y + 20, x + 14, y - 20, x - 14, y - 20)
      gfx.fillRect(x - 11, y - 30, 22, 12)
  end

  local function drawSchoolIcon(x, y)
      local offsets = { { -20, -10 }, { 0, -16 }, { 20, -8 }, { -10, 8 }, { 12, 12 } }
      for _, o in ipairs(offsets) do
          local fx, fy = x + o[1], y + o[2]
          gfx.fillEllipseInRect(fx - 8, fy - 3, 16, 6)
          gfx.fillTriangle(fx - 8, fy, fx - 14, fy - 3, fx - 14, fy + 3)
      end
  end

  local function drawSharkIcon(x, y)
      gfx.fillPolygon(x - 32, y + 6, x + 22, y + 10, x + 34, y, x + 20, y - 4, x - 30, y - 4)
      gfx.fillTriangle(x - 4, y - 4, x + 4, y - 22, x + 10, y - 4)
      gfx.fillTriangle(x + 20, y + 8, x + 34, y + 20, x + 20, y + 20)
  end

  local function drawWhaleIcon(x, y)
      gfx.fillPolygon(x - 34, y, x - 10, y - 16, x + 26, y - 10, x + 34, y + 2, x + 10, y + 14, x - 26, y + 12)
      gfx.fillTriangle(x + 30, y - 2, x + 44, y - 14, x + 44, y + 8)
  end

  local function drawSubmarineIcon(x, y)
      gfx.fillRoundRect(x - 32, y - 6, 64, 16, 8)
      gfx.fillRect(x - 4, y - 18, 10, 12)
      gfx.drawLine(x + 1, y - 18, x + 1, y - 24)
  end

  local function drawPlaneIcon(x, y)
      gfx.fillPolygon(x - 30, y, x + 30, y - 2, x + 34, y + 2, x - 28, y + 4)
      gfx.fillTriangle(x - 4, y, x - 16, y - 18, x - 4, y - 4)
      gfx.fillTriangle(x - 4, y + 2, x - 16, y + 18, x - 4, y + 4)
  end

  local function drawHelicopterIcon(x, y)
      gfx.fillRoundRect(x - 22, y - 6, 40, 16, 8)
      gfx.fillRect(x + 16, y - 1, 16, 5)
      gfx.drawLine(x - 30, y - 16, x + 30, y - 16)
      gfx.fillRect(x - 3, y - 16, 6, 10)
  end

  local RAIL_ICONS = {
      boat = drawBoatIcon,
      lighthouse = drawLighthouseIcon,
      ["fish school"] = drawSchoolIcon,
      shark = drawSharkIcon,
      whale = drawWhaleIcon,
      submarine = drawSubmarineIcon,
      plane = drawPlaneIcon,
      helicopter = drawHelicopterIcon,
  }

  local FLASH_BLINK_PERIOD = 0.12
  ```

- [ ] **Step 2: Replace the minimal `drawSpyRail` with the full version**

  Replace the `drawSpyRail` function added in Task 4:

  ```lua
  local function drawSpyRail()
      gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
      gfx.drawTextAligned(string.upper(Spy.target), Render.RAIL_CENTER_X, 110, kTextAlignment.center)
      gfx.setImageDrawMode(gfx.kDrawModeCopy)
  end
  ```

  with:

  ```lua
  local function drawSpyRail()
      local flashing = Spy.flashTimer < Spy.FLASH_DURATION
      local blinkOn = flashing and (math.floor(Spy.flashTimer / FLASH_BLINK_PERIOD) % 2 == 0)
      local cx = Render.RAIL_CENTER_X

      if blinkOn then
          gfx.setColor(gfx.kColorWhite)
          gfx.fillRoundRect(cx - 84, 30, 168, 180, 8)
          gfx.setColor(gfx.kColorBlack)
          gfx.setImageDrawMode(gfx.kDrawModeCopy)
      else
          gfx.setColor(gfx.kColorWhite)
          gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
      end

      gfx.drawTextAligned("FIND A", cx, 46, kTextAlignment.center)
      local iconDrawer = RAIL_ICONS[Spy.target]
      iconDrawer(cx, 110)
      gfx.drawTextAligned(string.upper(Spy.target), cx, 168, kTextAlignment.center)

      gfx.setImageDrawMode(gfx.kDrawModeCopy)
  end
  ```

- [ ] **Step 3: Add crosshair tick-fill**

  In `source/render.lua`, replace `drawCrosshairs`:

  ```lua
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
  ```

  with:

  ```lua
  local function drawCrosshairs(holdProgress)
      local cx, cy, r = Render.CENTER_X, Render.CENTER_Y, Render.RADIUS
      gfx.setColor(gfx.kColorBlack)
      gfx.setLineWidth(1)
      gfx.drawLine(cx, cy - r, cx, cy - 6)
      gfx.drawLine(cx, cy + 6, cx, cy + r)
      gfx.drawLine(cx - r, cy, cx - 6, cy)
      gfx.drawLine(cx + 6, cy, cx + r, cy)
      local filledCount = math.ceil((holdProgress or 0) * 4)
      for i = -4, 4 do
          if i ~= 0 then
              local x = cx + i * 20
              if filledCount > 0 and math.abs(i) <= filledCount then
                  gfx.setLineWidth(3)
                  gfx.drawLine(x, cy - 4, x, cy + 4)
                  gfx.setLineWidth(1)
              else
                  gfx.drawLine(x, cy - 3, x, cy + 3)
              end
          end
      end
  end
  ```

  Then update the call site in `Render.draw`: change `drawCrosshairs()` to `drawCrosshairs(Spy.holdProgress)`.

- [ ] **Step 4: Screenshot smoke test of the polished rail**

  In `source/shots.lua`, set:

  ```lua
  Shots = { plan = {
      { after = 0.1,  path = "/tmp/submariner-task5-idle.png" },
      { after = 0.35, set = { bearing = 305, height = 0.3 }, path = "/tmp/submariner-task5-aiming.png" },
      { after = 1.55, set = { bearing = 305, height = 0.3 }, path = "/tmp/submariner-task5-after-find.png" },
  }, t = 0, i = 1 }
  ```

  Run:

  ```bash
  make build
  rm -f /tmp/submariner-task5-*.png
  timeout 15 "$HOME/Developer/PlaydateSDK/bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator" Submariner.pdx > /tmp/submariner-task5.log 2>&1
  ls -la /tmp/submariner-task5-*.png
  ```

  Expected: all three files exist. Use the Read tool to view each:
  - `submariner-task5-idle.png`: rail shows "FIND A" / a lighthouse icon / "LIGHTHOUSE", crosshair ticks all thin (no hold yet).
  - `submariner-task5-aiming.png`: same "LIGHTHOUSE" target, but roughly the two innermost tick marks on each side of the crosshair are visibly thicker/bolder than the outer two (partial hold progress).
  - `submariner-task5-after-find.png`: rail word has changed to a category other than "LIGHTHOUSE" (the find-and-advance cycle completed, same check as Task 4 but now through the full icon/flash-capable rail code path).

  If the icon renders as a blank/garbled shape or overflows outside the black rail area, adjust that icon's coordinates and re-run.

- [ ] **Step 5: Revert the smoke-test probe**

  In `source/shots.lua`, set `Shots.plan` back to `{}`.

- [ ] **Step 6: Commit**

  ```bash
  git add source/render.lua source/shots.lua
  git commit -m "Add rail icons, find flash, and crosshair hold-progress fill"
  ```

---

### Task 6: Find chime

**Files:**
- Modify: `source/ambience.lua`
- Modify (temporary, reverted before commit): `source/shots.lua`

**Interfaces:**
- Consumes: `Spy.foundNow` (Task 4).
- Produces: no new public interface — audio only.

- [ ] **Step 1: Add the chime synth**

  In `source/ambience.lua`, change line 8 from:

  ```lua
  local hum1, hum2, lap, ping, gull, splash
  ```

  to:

  ```lua
  local hum1, hum2, lap, ping, gull, splash, chime
  ```

  Then in `Ambience.init`, after the existing `splash` setup (`splash:setADSR(0.005, 0.25, 0, 0.1)`), add:

  ```lua

      chime = snd.synth.new(snd.kWaveSquare)
      chime:setADSR(0.005, 0.15, 0.4, 0.2)
  ```

- [ ] **Step 2: Trigger the chime on a find**

  In `source/ambience.lua`, in `Ambience.update`, after the existing `if Scope.surfacedNow then ... end` block, add:

  ```lua

      if Spy.foundNow then
          local now = snd.getCurrentTime()
          chime:playNote(1500, 0.15, 0.12, now)
          chime:playNote(2000, 0.15, 0.18, now + 0.1)
      end
  ```

- [ ] **Step 3: Smoke test that a find doesn't crash the audio path**

  In `source/shots.lua`, set:

  ```lua
  Shots = { plan = {
      { after = 1.9, set = { bearing = 305, height = 0.3 }, path = "/tmp/submariner-task6.png" },
  }, t = 0, i = 1 }
  ```

  Run:

  ```bash
  make build
  rm -f /tmp/submariner-task6.png
  timeout 15 "$HOME/Developer/PlaydateSDK/bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator" Submariner.pdx > /tmp/submariner-task6.log 2>&1
  ls -la /tmp/submariner-task6.png
  ```

  Expected: file exists — a find fires around t=0.7s (per the Task 4 timing analysis) and `chime:playNote` runs without erroring during the following frames, all the way through to the 1.9s capture.

- [ ] **Step 4: Revert the smoke-test probe**

  In `source/shots.lua`, set `Shots.plan` back to `{}`.

- [ ] **Step 5: Commit**

  ```bash
  git add source/ambience.lua source/shots.lua
  git commit -m "Add a chime sound on a successful spy find"
  ```

---

### Task 7: Human acceptance checklist additions

**Files:**
- Modify: `docs/human-acceptance-checklist.md`

**Interfaces:** None — documentation only.

- [ ] **Step 1: Add a new checklist section**

  In `docs/human-acceptance-checklist.md`, add a new section after the existing "## Audio (Task 8)" section and before "## Notes from the Task 9 acceptance pass":

  ```markdown
  ## I Spy objective

  - [ ] **Rail readability at a glance**: glance at the rail without studying it —
    the icon and word should be readable/recognizable in under a second, since
    this is meant to work for a 6-year-old without adult help.
  - [ ] **Hold-to-confirm feel**: aim at a matching entity and hold — the
    crosshair tick marks should visibly fill in as progress toward the find,
    not feel like a silent/unresponsive wait.
  - [ ] **Sweep-past doesn't count**: quickly rotate past a matching entity
    without holding — it should NOT register as a find.
  - [ ] **Find flash + chime timing**: on a successful find, the flash and the
    chime should land together, not noticeably out of sync.
  - [ ] **Category never repeats immediately**: after several finds in a row,
    confirm the same category doesn't appear twice back to back.
  - [ ] **Whale spout timing**: watch the whale's bearing for a while — the
    spout should appear now and then near the surface, not so rarely it's
    never seen in a normal play session, and not so often it looks constant.
  - [ ] **New entity silhouettes read clearly**: the rival submarine, plane,
    helicopter, and shark should each look distinct from existing boats/fish
    at a glance, not like a reused/ambiguous shape.
  - [ ] **A 6-year-old can play it**: if possible, hand the device to a
    6-year-old (or someone unfamiliar with the game) and see whether they can
    find a few targets in a row without being told how.
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add docs/human-acceptance-checklist.md
  git commit -m "Add I Spy items to the human acceptance checklist"
  ```

---

### Task 8: Splash screen

**Files:**
- Create: `source/splash.lua`
- Modify: `source/main.lua` (full replacement)

**Interfaces:**
- Consumes: nothing new — only `playdate.buttonJustPressed`, `playdate.graphics`.
- Produces: `Splash.active` (bool, starts `true`), `Splash.update()`, `Splash.draw()`. Consumed only by `main.lua`. No other task in this plan depends on this module.

- [ ] **Step 1: Create `source/splash.lua`**

  ```lua
  Splash = { active = true }

  function Splash.update()
      if playdate.buttonJustPressed(playdate.kButtonA) then
          Splash.active = false
      end
  end

  function Splash.draw()
      local gfx = playdate.graphics
      gfx.clear(gfx.kColorWhite)
      gfx.drawTextAligned("For Dash, Love Dad", 200, 100, kTextAlignment.center)
      gfx.drawTextAligned("Press A to submerge...", 200, 130, kTextAlignment.center)
  end
  ```

- [ ] **Step 2: Wire the splash into `source/main.lua`**

  Replace the whole file with:

  ```lua
  import "CoreLibs/graphics"
  import "CoreLibs/ui"
  import "tests"
  import "scope"
  import "world"
  import "spy"
  import "render"
  import "ambience"
  import "shots"
  import "splash"

  playdate.display.setRefreshRate(30)

  Render.init()
  World.init()
  Spy.init()
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

      if Splash.active then
          Splash.update()
          Splash.draw()
      else
          Scope.update(dt)
          World.update(dt)
          Spy.update(dt)
          Render.draw(dt)
          Ambience.update(dt)
          if playdate.isCrankDocked() then
              playdate.ui.crankIndicator:draw()
          end
      end
      Shots.update(dt)
  end
  ```

  `Shots.update` deliberately stays outside the `if Splash.active` branch so it can capture the splash screen itself (Step 3 below). This does mean any *future* task wanting to screenshot-test gameplay will need to also set `Splash.active = false` as part of its temporary probe setup (a one-line, uncommitted diagnostic edit — the same pattern already used elsewhere in this plan for temporary verification state) — not a concern for this plan, since this is its last task.

- [ ] **Step 3: Screenshot-verify the splash screen**

  In `source/shots.lua`, set:

  ```lua
  Shots = { plan = {
      { after = 0.1, path = "/tmp/submariner-task8-splash.png" },
  }, t = 0, i = 1 }
  ```

  Run:

  ```bash
  make build
  rm -f /tmp/submariner-task8-splash.png
  timeout -k 5 15 "$HOME/Developer/PlaydateSDK/bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator" Submariner.pdx > /tmp/submariner-task8.log 2>&1
  ls -la /tmp/submariner-task8-splash.png
  ```

  Expected: file exists. Use the Read tool to view it and confirm both lines of text are present, centered, and legible: "For Dash, Love Dad" above "Press A to submerge...". No periscope view, HUD, or rail should be visible — the splash fully replaces the frame while active.

  The dismiss-on-A-press transition itself can't be captured by this screenshot harness (it has no way to simulate a button press) — verify it by reading `source/splash.lua` and `source/main.lua` directly: confirm `Splash.update` flips `Splash.active` to `false` on `playdate.buttonJustPressed(playdate.kButtonA)`, and that `playdate.update` correctly branches on `Splash.active` to run either the splash or the normal game loop, never both in the same frame. The live "press A, does the game actually start" check belongs on the human acceptance checklist (Step 5 below).

- [ ] **Step 4: Revert the smoke-test probe**

  In `source/shots.lua`, set `Shots.plan` back to `{}`.

- [ ] **Step 5: Add a human acceptance checklist item**

  In `docs/human-acceptance-checklist.md`, add a new section after the "## I Spy objective" section added in Task 7 and before "## Notes from the Task 9 acceptance pass":

  ```markdown
  ## Splash screen

  - [ ] **Dedication text reads correctly**: on boot, "For Dash, Love Dad" and
    "Press A to submerge..." should both be legible and centered before
    anything else appears.
  - [ ] **A dismisses cleanly**: pressing A should immediately drop into the
    normal periscope view with no flash, stutter, or stuck frame.
  ```

- [ ] **Step 6: Commit**

  ```bash
  git add source/splash.lua source/main.lua source/shots.lua docs/human-acceptance-checklist.md
  git commit -m "Add a splash screen dedication before gameplay starts"
  ```

---

## Self-Review

**Spec coverage:**
1. Eyepiece shifted, rail readable, HUD correct → Task 3 (shift + sea/waterline bound fix) + Task 4/5 (rail) + verified HUD auto-follows `Render.CENTER_X`.
2. All 8 categories reachable, 0.7s hold detection → Task 1 (geom helpers) + Task 2 (entities exist) + Task 3 (entities rendered/visible) + Task 4 (detection state machine).
3. Tick marks fill while aiming → Task 5, Step 3.
4. Find flashes + chimes, new category appears → Task 5 (flash) + Task 6 (chime) + Task 4 (advance logic), all screenshot-verified end to end.
5. Five new entities render distinctly, whale spouts → Task 2 (data) + Task 3 (rendering), spout qualitatively covered in Task 7.
6. 6-year-old can play without help → Task 7 checklist item.
7. Splash screen shows the dedication text and A dismisses into normal play → Task 8 (screenshot-verified text, code-reviewed dismiss logic, human checklist item for the live A-press check).

**Placeholder scan:** no TBD/TODO; every step has complete, runnable code; no "similar to Task N" shortcuts — each task's code blocks are self-contained.

**Type/name consistency check:** `Spy.target` (string) / `Spy.holdProgress` (number) / `Spy.foundNow` (bool) / `Spy.flashTimer` (number) / `Spy.FLASH_DURATION` (number) are introduced in Task 4 and used with those exact names in Task 5 (`drawSpyRail`, `drawCrosshairs(Spy.holdProgress)`) and Task 6 (`Spy.foundNow`) — consistent throughout. `Geom.bearingAligned`/`aboveVisible`/`belowVisible` (Task 1) are used with matching signatures in Task 4's `spy.lua`. `World.planes`/`helicopters`/`sharks`/`whales` (Task 2, each a list of one table with `.bearing`) match the iteration (`ipairs`) and field access (`.bearing`, `.depth`, `.above`, `.dir`, `.phase`, `.rotorPhase`, `.spoutPhase`) used in Task 3's `render.lua` and Task 4's `spy.lua` category table.
