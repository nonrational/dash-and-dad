# Dash & Dad Playdate monorepo — design

**Date:** 2026-07-13\
**Status:** approved, ready to implement\
**Repo:** `nonrational/dash-and-dad-playdate` (disk: `~/src/dash-and-dad-playdate`)

## What this is

A single parent repository to house the "Dash & Dad" Playdate games (made by
Alan Norton with his son, nickname "Dash"), plus all shared Playdate
development know-how under one roof. It absorbs two existing standalone repos:

- **foosball** — `~/wrk/supertinylabs/foosball` (45 commits, no remote)
- **submariner** — `~/src/submariner` (31 commits, public at
  `github.com/nonrational/submariner`)

## Goals

1. One browsable home for both games and future ones.
2. One home for cross-game Playdate tips and tricks, currently duplicated
   across both games' `CLAUDE.md` files.
3. Preserve each game's full commit history.
4. Keep each game independently buildable in place.

## Decisions

| Question | Decision |
| --- | --- |
| Topology | **Monorepo**, absorbing both games as subdirectories under `games/`. |
| History | **Preserved** via `git filter-repo --to-subdirectory-filter` then unrelated-history merge. |
| Shared code | **Docs/knowledge only.** No Lua extraction — games stay self-contained (their geom/render code has already diverged; YAGNI until a third game forces it). |
| Publishing | **Publish now** to `nonrational/dash-and-dad-playdate`; foosball goes public here for the first time. |
| Old submariner repo | **Archive** `nonrational/submariner` with a README pointer to the new home — *after explicit confirmation* (near-irreversible). |

## Target structure

```
dash-and-dad-playdate/
  games/
    foosball/                    # current foosball repo contents, history preserved
    submariner/                  # current submariner repo contents, history preserved
  docs/
    playdate/                    # the shared tips & tricks
      screenshot-harness.md      # the Shots harness pattern + "committed plan is always empty"
      asset-pipeline.md          # pdc no-dither thresholding, pre-dithered 1-bit PNGs, ffmpeg recipes
      rendering-gotchas.md       # backwards dither-alpha, float32 trig tolerances
      architecture-style.md      # globals-via-import, one-way module deps, geom kept playdate-free
    superpowers/specs/           # cross-cutting specs (this doc's canonical home)
  CLAUDE.md                      # root: monorepo map + index into docs/playdate/
  README.md                      # the collective's front page
  .gitignore                     # *.pdx/, .DS_Store
```

Each game keeps its own `CLAUDE.md`, `README.md`, `.gitignore`, and `Makefile`,
so it still builds standalone from inside its subdirectory.

## History merge

Both Makefiles use only relative paths plus `$HOME/Developer/PlaydateSDK`, so no
game needs editing to build from `games/<name>/`. The 90 MB SDK binaries in
submariner's `lib/` were never committed (`.gitignore` already excludes `lib/`),
so history is already clean — no blob-stripping required.

Per game:

1. Fresh clone of the game repo into a temp dir.
2. `git filter-repo --to-subdirectory-filter games/<name>` — rewrites every
   commit so its files live under `games/<name>/`. `git log games/<name>/` and
   `git blame` then read naturally.
3. Add the rewritten clone as a remote in the fresh monorepo and
   `git merge --allow-unrelated-histories`.

The original repos are left untouched as backups until the monorepo is verified.

*Alternative considered:* `git subtree add` needs no extra tool but leaves old
commits showing pre-move paths (`git blame` / `log --follow` get awkward).
Rejected in favor of filter-repo's clean result; the `brew install
git-filter-repo` cost is trivial.

## Knowledge hoist

Distill the game-agnostic know-how currently duplicated across both `CLAUDE.md`
files into `docs/playdate/` topic docs. Root `CLAUDE.md` becomes a map ("games
live in `games/`; read `docs/playdate/` before touching any game"); each game's
`CLAUDE.md` gets a one-line pointer up. Game `CLAUDE.md` files are otherwise
left intact this pass — de-duplicating them fully is a follow-up, not worth the
risk now.

## Migration sequence

1. `brew install git-filter-repo`; `git init ~/src/dash-and-dad-playdate`.
2. Filter-merge foosball, then submariner, into `games/`.
3. Verify: both build from new homes (`cd games/<name> && make build`); both
   histories present (`git log games/<name>/` shows the original commits).
4. Write root `README.md`, root `CLAUDE.md`, `docs/playdate/*`, root `.gitignore`.
5. `gh repo create nonrational/dash-and-dad-playdate`, push.
6. **Confirm, then** archive `nonrational/submariner` with a README pointer.

## Verification / success criteria

- `cd games/foosball && make build` and `cd games/submariner && make build` both
  exit 0.
- `git log --oneline games/foosball/` and `.../submariner/` each show the
  respective game's original commit subjects.
- Root `README.md` renders; links to both games resolve.
- The monorepo pushes cleanly to `nonrational/dash-and-dad-playdate`.

## Risks and rollback

- **Archiving the public submariner repo is near-irreversible.** Gated behind
  explicit confirmation; the new repo must be verified first. Archiving (not
  deleting) preserves the URL, stars, and the README's hosted demo image.
- The original working dirs (`~/wrk/supertinylabs/foosball`, `~/src/submariner`)
  are retained as backups until the user confirms the monorepo is good; only
  then are they optionally removed.

## Out of scope

- Extracting shared Lua into a common library.
- Aligning foosball's `pdxinfo` (`author=Super Tiny Labs`, `bundleID`) with the
  Dash & Dad brand — tracked separately; changing `bundleID` moves device
  save-data identity.
- Fully de-duplicating the per-game `CLAUDE.md` files.
