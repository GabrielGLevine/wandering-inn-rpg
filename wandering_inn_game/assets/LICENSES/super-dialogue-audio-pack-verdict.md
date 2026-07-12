# Super Dialogue Audio Pack v1 license verdict

Pack: Super Dialogue Audio Pack v1
Source: `potential_assets/Super Dialogue Audio Pack v1/`
Author: **Dillon Becker**
License: **CC BY 4.0** (attribution required; commercial + modification
permitted)

## What's used

Issue #76 (audio identity wave) mined the pack's PC combat bark set (male
voice actor **Alex Brodie**) for four **wordless** files, downmixed/
peak-normalized via the same pipeline as the Minifantasy SFX (mono 16-bit
PCM @ 44.1kHz, peak-normalize to -1.0 dBFS via a measured `ffmpeg -af
volumedetect` gain) and staged through a gitignored `_curated/` dir under
the pack (`tools/sync_assets.py` MANIFEST, "Issue #76: Super Dialogue Audio
Pack v1" section):

| sfx file | data/audio.json id | usage |
|---|---|---|
| `assets/audio/sfx/pc_hurt_1.wav` | `pc_hurt` (round-robin variant 1/3) | PC takes damage in combat |
| `assets/audio/sfx/pc_hurt_2.wav` | `pc_hurt` (round-robin variant 2/3) | PC takes damage in combat |
| `assets/audio/sfx/pc_hurt_3.wav` | `pc_hurt` (round-robin variant 3/3) | PC takes damage in combat |
| `assets/audio/sfx/pc_death.wav` | `pc_death` | PC downed |

These four wav files ride a dedicated `Voice` audio bus (`data/audio.json`,
`WIAudio`'s `BUS_NAMES` 4th entry) so a bark is never touched by the Music
bus's dialogue duck or the SFX volume slider alone. All four are **SHIP-OK,
committed-direct**: unlike the FORBIDDEN/NEEDS-ATTESTATION rows in
`assets_manifest.json` (private-bundle-overlay-only), these wav files are
tracked straight in this public repo — CC BY 4.0 permits redistribution
outright, so there's no license reason to route them through the private
bundle.

## Usage ruling (CHOICES 21, wordless-voice-only)

The pack also ships **spoken colloquial lines** (English dialogue clips,
not wordless grunts/hits/shouts). Per the controller's binding audio-
scoping pass on issue #76 (`HANDOFF.md`, "CHOICES 21: wordless-voice-only
ruling"): the spoken lines are deferred as a **taste-gate**, even for Erin
(canon-plausible casting for her specifically, but a real spoken-English
voice clip dropped into an otherwise text-dialogue game is a build-level
taste call reserved for the user, not an agent). **Only wordless
hurt/death/shout sets are sanctioned for use by any combatant** — this
verdict covers exactly that subset (the 4 PC files above). Any future use
of this pack's spoken lines, or wordless sets for other combatants (e.g.
goblin-specific barks), needs its own dispatch under the same ruling — no
reachable payload hook distinguishes a goblin from any other enemy today
(`data/audio.json`'s `_comment` on the `pc_hurt` row), so PC-only is also
the current mechanical ceiling, not just the taste boundary.

## Verdict: SHIP-OK, committed-direct (CC BY 4.0)

Attribution shipped in `ATTRIBUTION.md` ("Super Dialogue Audio Pack by
Dillon Becker — CC BY 4.0") per the license's requirement. No
redistribution restriction beyond attribution — same standing as the CC0
Kenney/Junkala audio, except CC BY requires the credit line CC0 does not.

## Notes

Curation pipeline documented in `tools/sync_assets.py`'s MANIFEST comment
above the four rows; full source-file gain table follows the same
convention as the M5-A3/#76 Minifantasy Dungeon SFX report
(`.superpowers/sdd/m5-a3-report.md`). This file closes the missing-verdict
gap flagged by issue #86 (the #76 review noted attribution shipped in
`ATTRIBUTION.md` but the per-pack verdict file the project's pattern wants
was never filed).
