# I Spy — Lightweight Objective Layer

**Date:** 2026-07-10\
**Status:** Approved design, pending implementation plan\
**Target:** Playdate SDK 3.0.6 (Lua), simulator first, device later\
**Builds on:** `docs/superpowers/specs/2026-07-09-periscope-sim-design.md`

## Overview

The v1 periscope toy is purely observational — no objectives, no score. This
adds a light "I Spy" objective on top, aimed at a 6-year-old player: the right
side of the screen names something to find ("FIND A SHARK"), the player
rotates and cranks the periscope to line the crosshairs up on a matching
entity, holds it there briefly, and gets a quick celebratory flash + chime
before a new target appears. It's always on — this is now how the game plays,
not a toggle alongside the old ambient-only mode.

Five new world entities are added to support this: shark, whale, a rival
submarine, a plane, and a helicopter. Boats, the lighthouse, and fish schools
become spy targets too, using their existing types.

## Goals

- A read-at-a-glance objective a non-reading-fluent 6-year-old can act on
  without help: a short word plus an icon, not a sentence.
- Aiming and holding, not just glancing — reuses and reinforces the existing
  "heavy periscope" control feel rather than adding new controls.
- New creatures/vehicles that fit the existing one-way module architecture
  and code-drawn, no-asset constraint.

## Non-Goals (this pass)

- Scoring, timers, difficulty levels, or a win/end state — the loop is
  endless, matching the toy's ambient, no-pressure nature.
- A toggle back to pure ambient/no-objective play.
- New entities beyond the five listed (more can follow the same pattern
  later).
- Multiplayer, save state, or a running tally of finds across sessions.

## Spy Categories

Eight find-able categories. Existing multi-type entities are grouped so the
player reasons about one word, not sub-types:

| Category | Source entities |
|---|---|
| Boat | any of sail / trawler / cargo (existing, undistinguished) |
| Lighthouse | the existing fixed landmark |
| Fish school | either of the two existing schools |
| Shark | new |
| Whale | new |
| Submarine | new (rival sub) |
| Plane | new |
| Helicopter | new |

The two existing lone big fish remain ambient dressing, not a spy target —
keeping them out avoids a "wait, is that the shark?" mix-up right next to the
new shark.

**Target selection:** uniformly random across the 8 *categories* (not
weighted by instance count, so the single lighthouse comes up as often as the
five boats), never repeating the category just found.

## New Entities

All code-drawn 1-bit silhouettes, no image assets, following the existing
`world.lua` population pattern (fixed count, drift, wrap — nothing spawns or
despawns).

- **Rival submarine** — new `BOAT_DRAWERS` entry (low flat hull, small
  conning tower), placed in one of the existing boat lanes and driven by the
  same lane drift/bob logic as sailboat/trawler/cargo. One instance.
- **Plane** — sky layer alongside clouds, but faster, higher, and a simple
  wing-silhouette shape. Continuously circles the full 360° bearing range.
  One instance.
- **Helicopter** — sky layer, slower than the plane, two-frame rotor-blur
  animation (same sign-flip trick as the existing fish tail flap). One
  instance.
- **Shark** — underwater, structured like a lone fish (bearing, depth, drift,
  sine wiggle) but bigger, with a distinct dorsal-fin silhouette so it's
  visually unambiguous next to the ambient lone fish. One instance.
- **Whale** — underwater, the largest new silhouette. Depth oscillates slowly
  between a deep resting point and a near-surface point. Its body always
  renders in the existing underwater layer (same clip as fish/schools); when
  near-surface, a small dithered spout plume additionally draws in the
  above-water layer at its bearing — a surprise moment without needing the
  hull itself to cross the above/below clip boundary. For spy detection
  purposes the whale always counts as an underwater target, spout or not.

One instance each — enough variety without crowding the existing 5 boats + 2
schools + 2 lone fish + bubbles + clouds.

## Screen Layout

- The eyepiece circle shifts left: still radius 104 / centered at y=110, but
  `CENTER_X` moves from 200 to roughly 120 (leaves ~16px margin from the left
  edge — enough to still read as a porthole rather than looking clipped).
  This frees a right-hand rail roughly 175px wide.
- Rail content is plain white-on-black text/icon — the same treatment the
  existing `BRG 047°` HUD already uses on the black mask surround, so it's
  visually consistent with zero new color/contrast system. Layout, top to
  bottom: small "FIND A" label, a code-drawn icon silhouette of the target
  category, the category word in a large bold face.
- The bearing HUD (`BRG 047°`) moves from bottom-center to sit under the
  (now off-center) circle instead of screen-center.

## Detection Mechanic

A find registers when, for the current target category, **any** matching
world entity satisfies both:

1. **Bearing alignment** — `Geom.wrappedDelta(scope.bearing, entity.bearing)`
   is within **±6°** (a bit wider than the crosshair's center gap — the gap
   between tick marks at ±20px / 3.5px-per-degree is ~5.7° — generous enough
   for a 6-year-old to land without frustration; tunable).
2. **Height/visibility match** — reuses the same test the renderer already
   applies to decide whether the above-water or underwater layer is drawing
   this frame (`wy` vs. `Render.CENTER_Y ± Render.RADIUS`), so "line it up"
   always means "you can actually see it" — never an invisible hitbox.

Both conditions must hold continuously for **~0.7s** before the find
registers — long enough to filter out an accidental sweep-past, short enough
not to feel unresponsive. While holding, the crosshair's tick marks fill in
progressively toward the hold target, giving the player visible "getting
closer" feedback rather than a silent wait. Breaking alignment before 0.7s
resets the hold progress.

## Find Feedback

On a successful hold: the rail word/icon briefly flashes (inverts), a short
cheerful synthesized chime plays, the flash holds for about a second so it
reads clearly as a win, then the rail fades into the next randomly-selected
target (excluding the category just found).

## Architecture

New module `spy.lua`, following the same shape as `scope.lua`:

```
Spy = {
    target = "shark",       -- current category
    holdProgress = 0,       -- 0..1 toward the 0.7s hold
    foundNow = false,       -- true for one frame on a successful find
    flashTimer = 999,       -- drives the rail flash + hold-before-advance
}

function Spy.update(dt) ... end
```

- Detection math (bearing-alignment check) lives in `geom.lua` alongside the
  existing wrap/delta/projection functions — pure, no `playdate.*` calls, so
  it's boot-time-testable the same way rotation and projection already are.
- Update loop gains a step:
  `Scope.update → World.update → Spy.update → Render.draw → Ambience.update → Shots.update`.
  `Spy.update` reads `Scope` (bearing/height) and `World` (entity bearings) —
  the same one-way read shape `Render` already has on those two modules.
- `Render` additionally reads `Spy` to draw the rail and the tick-fill
  progress.
- `Ambience` reads a new `Spy.foundNow` flag (mirrors the existing
  `Scope.surfacedNow` pattern already used for the splash one-shot) to
  trigger the find chime.

Module structure addition to the existing list:

```
source/
  spy.lua        -- NEW: target selection, aim/hold detection, find state
```

## Error Handling

Same philosophy as the base spec: clamping and wrapping are the whole story.
Hold progress clamps to [0, 1] and resets to 0 on misalignment; target
selection always has a valid category since categories are a fixed set of 8.
No failure states.

## Verification

- **Automated:** `geom.lua`'s new bearing-alignment check gets boot-time
  assertions in `tests.lua` alongside existing coverage (wrap, delta,
  projection, rotation ramp).
- **Manual (human acceptance checklist):** hold-timing feel, rail
  readability at a glance, tick-fill legibility while aiming, spout timing,
  chime character, and whether a 6-year-old can complete a find without
  adult help — added as new items alongside the existing control-feel/audio
  checklist.
- **Visual:** new entity silhouettes and rail layout checked via the
  existing `shots.lua` screenshot harness.

**Acceptance criteria for this pass:**

1. Eyepiece sits left-shifted with the rail visible and readable at a glance;
   bearing HUD reads correctly under the new circle position.
2. All 8 categories are reachable: aiming + holding on a matching, visible
   entity registers a find within ~0.7s; nothing else does.
3. Tick marks visibly fill in while aiming before a find registers.
4. Successful find flashes + chimes, then a new (different) category
   appears.
5. Five new entities (shark, whale, submarine, plane, helicopter) render
   with distinct, recognizable silhouettes; whale spouts occasionally near
   the surface.
6. A 6-year-old can complete several finds in a row without adult
   intervention (human acceptance pass).

## Stretch (not this pass)

- Per-instance-weighted or difficulty-scaled target selection.
- A soft session tally or celebratory milestone (e.g. every 10th find).
- More entity variety (dolphins, other planes, orcas, etc.) using the same
  pattern.
