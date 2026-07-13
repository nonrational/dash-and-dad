# Assets and audio

## Audio is always synthesized

No audio files. Both games build sound from `playdate.sound` synths and filters.
It's a deliberate constraint, not something we're working around.

## Images: pre-dither to 1-bit, or draw in code

Two valid stances, chosen per game:

- **`submariner` is zero-asset** — every graphic is code-drawn 1-bit, no image
  files at all (a v1 design rule).
- **`foosball` allows images** — but with a catch: **`pdc` thresholds images at
  50% and does not dither.** So any PNG must be **pre-dithered to 1-bit at its
  exact on-screen size** before it enters `source/`. Feed `pdc` a grayscale
  image and you get a hard-thresholded mess.

## The pre-dither recipe

`foosball` generates its 1-bit splash and launcher art from source art with an
`ffmpeg` pipeline (`scale → crop → gray → bayer-dither → monob`). The exact,
size-specific incantations live in `games/foosball/CLAUDE.md` — treat that as
the source of truth rather than copying the command around, since the scale/crop
values differ per target (splash 400×240, launcher card 350×155).

Two things that pipeline taught us:

- **Regenerate from the original art, at the final on-screen size.** Downscaling
  an already-dithered image re-dithers the dither into noise.
- **Tiny icons are the exception** — a 32×32 launcher icon turns to mush when you
  scale box art down to it. Draw those bold in code instead.
