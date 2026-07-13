# Ambient beds CC0 license verdict (issue #76 remainder)

Five per-map loop beds for the highest-dwell maps. Every source is
**CC0 / public domain** — redistributable, so the processed files are
committed directly to the PUBLIC tree (`assets/audio/ambience/`), never
the private bundle, and `test_audio_data.gd`'s ambience arm deliberately
does NOT apply the licensed-overlay manifest relaxation to them (a
missing bed file is a real regression).

Each license was verified on the source PAGE per file (not assumed from
a search result), fetched 2026-07-13.

## Verdict: SHIP-PUBLIC (CC0, all five)

| bed file | map | source | author | license (verified on page) |
|---|---|---|---|---|
| `inn_crowd_murmur.ogg` | inn | freesound.org/people/Breviceps/sounds/457043/ ("Busy Room Ambience / Small crowd / People talking in background") | Breviceps | CC0 ("Creative Commons 0" on the sound page) |
| `street_town_bed.ogg` | street | opengameart.org/content/park-ambiences (`park_ambience_birds.wav`) | Thimras | CC0 (page License(s): CC0) |
| `floodplains_river_bed.ogg` | floodplains | opengameart.org/content/park-ambiences (`park_ambience_river.wav`) | Thimras | CC0 (page License(s): CC0) |
| `dungeon_hum.ogg` | trapped_halls | opengameart.org/content/loopable-dungeon-ambience (`dungeon_ambient_1_0.ogg`) | JaggedStone | CC0 (page License(s): CC0) |
| `sewers_drip.ogg` | sewers | opengameart.org/content/dripping-water-loop (`atmosbasement.mp3_.flac`) | Independent.nu (submitted by qubodup) | CC0 (page License(s): CC0) |

## Processing (same curation discipline as the Kenney SFX pass)

All beds re-encoded (never byte-identical repacks): downmix to mono
44.1 kHz, segment trimmed where the raw recording is long (input-side
`-ss` seek — an OUTPUT-side seek leaves `afade` timestamps on the
original timeline and silently zeroes the segment; caught live when
`dungeon_hum` first encoded as digital silence), 60–400 ms edge fades to
soften the loop seam, loudness-normalized (`loudnorm` I=-20..-22, except
`dungeon_hum` where EBU gating measures a sub-bass drone as near-silent
and a measured plain `volume=2dB` gain was used instead), Vorbis q2 via
`oggenc`. Every output verified non-silent before commit (`astats` RMS
-22 to -30 dB, peaks -2 to -11 dB; `silencedetect` zero windows at
-60 dB/1 s).

Casting notes: the inn bed is wordless indoor crowd murmur (Erin's
common room); street reuses the birds/town-edge park recording (Liscor's
street is outdoor, low-traffic); floodplains gets the small-river
recording (the Floodplains ARE a river valley); trapped_halls gets the
low wind-and-drips dungeon drone; sewers gets the basement drip loop.
Sewers/trapped_halls remain music-TRACKLESS by design (see
`data/audio.json`'s `_comment_music_order`) — the bed replaces dead
silence with atmosphere without violating that mood ruling.

Credit line (courteous, not required by CC0): "Ambience by Breviceps
(freesound), Thimras, JaggedStone, Independent.nu (opengameart.org) —
CC0."
