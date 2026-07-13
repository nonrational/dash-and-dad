# Playdate house style

The shared engineering doctrine behind the games in this repo. Both `foosball`
and `submariner` follow it; new games should too.

## Modules are globals loaded with `import`

Each module is a Playdate-style global table (`Geom`, `Render`, `Ball`,
`Scope`, …), loaded via `import "render"`, not `require`. No module-local
returns, no package table. `main.lua` imports everything at the top.

## Dependencies run one way

Module dependencies are deliberately acyclic and one-directional. When a
mechanic is inherently mutual (e.g. foosball's ball vs. goalie), the mutual read
is brokered through `main.lua` passing an explicit parameter, rather than two
modules reading each other. Every file stays understandable on its own.

## `main.lua` wires init and one 30fps loop

`playdate.display.setRefreshRate(30)`. `main.lua` calls each module's `init()`
once, then drives a single `playdate.update()` that ticks the modules in a fixed
order (submariner: `Scope.update → World.update → Render.draw → Ambience.update`).
Event reactions are one-frame flags that `main.lua` reads and dispatches — no
module polls another's state machine.

## `geom.lua` is pure math, and it's the only unit-tested module

`geom.lua` contains no `playdate.*` calls — just `clamp`, `lerp`, projections,
band checks. That purity is load-bearing: `source/tests.lua` runs boot-time
assertions against it (via `runTests()` in `main.lua`), and a failure errors at
boot. There is no standalone test runner. Keep `playdate.*` out of `geom.lua` so
it stays testable.

## Gotcha: `getCrankChange()` drains an accumulator

`playdate.getCrankChange()` returns the delta *since it was last called*, not
since the last frame. Call it every frame unconditionally, even in states that
ignore the crank — otherwise motion during an idle phase accumulates and dumps
as one inflated reading the instant you start listening. (`getCrankPosition()`
is an absolute read with no accumulator, so it's exempt.)
