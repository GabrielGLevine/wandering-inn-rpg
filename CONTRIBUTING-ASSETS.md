# Contributing Art & Audio

Original art and music contributions are especially welcome — a portion of
the game's current art can't be redistributed with the repository (players
of the source build see it; the public repo ships fallback placeholders),
and community-made replacements let everyone see the real thing.

## Licensing (required, non-negotiable)

- Your contribution must be **your own original work** (or work you hold
  full rights to). No rips, no output traced from licensed packs.
- State a license in your PR: **CC-BY-4.0** or **MIT**. This grants the
  project redistribution rights; you keep authorship and get credited in
  `ATTRIBUTION.md`.
- AI-assisted work: disclose it in the PR. It's not banned, but disclosure
  is required so downstream users know provenance.

## Pixel art specs

The world renders at a 16px grid with 4× zoom (320×180 logical viewport).

- **Tiles / environment:** 16px-native, sheets aligned to a 16px grid.
  Hard-outline pixel style (the world backbone is in this family). Don't
  mix soft/painterly and hard-outline styles inside one scene layer.
- **Characters:** 64px frames on a sheet; the figure typically spans
  ~30–48px. **Measure the feet plane:** if your figure has transparent
  padding below the feet, note the lowest non-transparent row in the PR —
  the engine anchors sprites by a feet-plane fraction, and unmeasured
  padding makes characters float a cell above where they stand (a real
  bug we've shipped twice).
- **Directional characters:** separate down / side / up sheets per
  animation; the side sheet is mirrored for the fourth facing. Consistent
  frame counts per animation, note the intended fps.
- **Props / interactables:** a prop must read at a glance — fill most of
  the 16px cell or carry a clear marker. Furniture and obstacles are
  always prop sprites, never recolored floor tiles.
- **Palette:** each map has a color story (warm hearth interior, blue-hour
  road, cave dark). Check screenshots of the target map and keep your
  accent hues compatible; the day/dusk/night grade multiplies over your
  art, so avoid relying on very dark blues to read at night.
- **Skill icons:** small square icons, readable at 16–24px on dark UI
  chrome.

## Audio specs

- **Music:** OGG Vorbis, **loopable from sample 0** (no silent lead-in;
  the loop point is the file boundary). Note intended map/mood.
- **SFX:** OGG or WAV, short, normalized so peaks sit comfortably below
  clipping; a family of variations (3–4 takes of a hit/step) beats one.

## Submitting

Open a PR adding files under `wandering_inn_game/assets/` **or** attach
work to a "Map Suggestion"/idea issue if you'd rather not wire it in
yourself. If you do wire it: add the `data/sprites.json` entry and include
a windowed screenshot showing it in place (see `CONTRIBUTING.md`). We
verify every sprite with an in-game screenshot before merge — atlas
coordinates lie, screenshots don't.
