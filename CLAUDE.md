# CLAUDE.md

Guidance for Claude Code (claude.ai/code) when working in this repository.

## What this is

A monorepo of Playdate games (Lua, SDK 3.0.6) built by Alan Norton with his kid
("Dash"), plus shared Playdate development notes. Each game is self-contained
under `games/`; cross-game know-how lives in `docs/playdate/`.

## Layout

- `games/<name>/` — one Playdate game each, with its own `CLAUDE.md`, `Makefile`,
  `source/`, `docs/`, and tests. **Work on a game from inside its directory**
  (`cd games/foosball && make build`); that game's own `CLAUDE.md` is the
  authoritative guide for it.
- `docs/playdate/` — shared, game-agnostic Playdate notes. **Read these before
  hacking on any game:**
  - `architecture-style.md` — the house style (globals via `import`, one-way
    deps, `geom.lua` kept pure and unit-tested, the crank-drain gotcha)
  - `screenshot-harness.md` — the `Shots` deterministic-capture harness
  - `rendering-gotchas.md` — 1-bit rendering and float32 runtime gotchas
  - `asset-pipeline.md` — image pre-dithering and the synth-only audio rule
- `docs/superpowers/specs/` — cross-cutting design specs.

## Conventions

- Each game requires the Playdate SDK at `~/Developer/PlaydateSDK`.
- Plain, descriptive commit messages — no Conventional Commit prefixes.
- New shared gotchas go in `docs/playdate/`, not copied into each game's
  `CLAUDE.md`.
