# Rendering and runtime gotchas

Hard-won 1-bit Playdate facts, shared across the games.

## `setDitherPattern` alpha runs backwards for black ink

For black ink, `0` is solid black and `1` is empty — the opposite of what you'd
expect. Don't call it directly; both games wrap it in a `setInk(darkness)`
helper in `render.lua`. Use the helper.

## Alpha masks need a transparent background

A Playdate image only carries an alpha mask when it's created on
`gfx.kColorClear`. Punching `kColorClear` into an image that was created on a
black background is a silent no-op — nothing gets cut out.

## The Lua runtime is single-precision

Playdate's Lua does math in float32. `math.cos(math.rad(90))` comes back ~`4e-8`,
not the ~`6e-17` you'd get on desktop Lua. Any boot test asserting on a
trig-derived value needs a loose tolerance (~`1e-4`), not exact equality — this
once hung boot when a rotation test compared against `1e-9`.

## Known cosmetic noise

`inverted rect in LCD_addUpdateRect()!` warnings in the simulator console are
harmless — no visual artifact. Don't chase them.
