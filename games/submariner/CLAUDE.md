# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

An ambient submarine periscope toy for the Playdate console (Lua, SDK 3.0.6). No objectives, no score — the acceptance test is "feels good to look around." The authoritative design spec (coordinate model, world population, audio design, v1 acceptance criteria) is `docs/superpowers/specs/2026-07-09-periscope-sim-design.md`.

## Commands

Requires the Playdate SDK at `~/Developer/PlaydateSDK`.

- `make build` — compile `source/` into `Submariner.pdx` with `pdc` (also catches Lua syntax errors; there is no separate linter)
- `make run` — build and launch in the Playdate Simulator
- `make clean` — remove the `.pdx`

## Testing and verification

- **Unit tests** live in `source/tests.lua` as boot-time assertions, run automatically when the game boots in the simulator (`runTests()` in `main.lua`). There is no standalone test runner; a failure errors at boot. They only cover `geom.lua`, which is kept free of `playdate.*` calls precisely so it stays testable — preserve that boundary.
- **Visual verification** uses the screenshot harness in `source/shots.lua`: temporarily populate `Shots.plan` with `{ after = <seconds>, set = { <Scope field> = <value> }, path = "<absolute .png path>" }` entries, `make run`, and the simulator writes each frame to disk then exits. `set` fields are pinned onto `Scope` every frame so captures are deterministic. **Committed code always has an empty plan** — revert before committing.
- `docs/human-acceptance-checklist.md` lists everything that can only be verified by live play (control feel, timing, audio) — anything you change in those areas lands there for a human pass, not in automated checks.

## Architecture

Modules are Playdate-style globals (`Geom`, `Scope`, `World`, `Render`, `Ambience`, `Shots`) loaded via `import`, not `require`. Dependencies are deliberately one-way:

- `main.lua` wires init and the 30fps update loop: `Scope.update → World.update → Render.draw → Ambience.update → Shots.update`
- `scope.lua` owns input state: `bearing` (degrees, wraps 0–360), `height` (∈ [-1, +1], crank-driven, 3 revolutions full sweep), and surfacing signals (`surfacedNow`, `surfacedProgress()`)
- `world.lua` is a fixed persistent population (boats in far/mid/near lanes, clouds, schools, lone fish, bubble columns) — nothing spawns or despawns, entities drift around the cylinder and wrap
- `render.lua` reads `Scope` + `World`; `ambience.lua` reads `Scope`
- `geom.lua` is pure math shared by all of the above

**Coordinate model** (the key thing to internalize): the world is a 360° bearing cylinder around the sub. `screenX = centerX + wrappedDelta(scopeBearing, entityBearing) * 3.5 px/deg`. The waterline's screen Y is `CENTER_Y + height * SWING` where SWING (120) deliberately exceeds the eyepiece radius (104), so fully raised shows no underwater and fully submerged no sky. Rotation has no parallax; depth cues come from lane scale, vertical offset, and drift speed.

**Render order** in `Render.draw`: above-water layers (clipped to the waterline, with per-lane clip extension so near hulls dip below it) → sea tint + underwater layers (clipped below) → waterline chop → droplet streaks → eyepiece mask → crosshairs → HUD.

## Constraints and gotchas

- Everything is code-drawn 1-bit graphics and synthesized audio — **no image or audio assets** (a v1 design rule, not an accident).
- `setDitherPattern`'s alpha runs backwards for black ink (0 = solid black). Use the `setInk(darkness)` helper in `render.lua` rather than calling it directly.
- Playdate images only carry an alpha mask when created on a transparent background (`gfx.kColorClear`); punching `kColorClear` into a black-background image is a silent no-op.
- Rendering avoids `math.random` (fixed jitter tables instead) so screenshot captures stay deterministic; `math.random` is fine for ambience timing.
- `inverted rect in LCD_addUpdateRect()!` simulator console warnings are known cosmetic noise with no visual artifact (investigated and documented in `docs/human-acceptance-checklist.md`) — don't chase them.
