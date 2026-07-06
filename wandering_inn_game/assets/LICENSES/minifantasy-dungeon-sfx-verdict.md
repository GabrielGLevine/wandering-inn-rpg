# Minifantasy Dungeon SFX license verdict

Pack: Minifantasy_Dungeon_SFX
Source: potential_assets/Minifantasy_Dungeon_SFX/
Reviewed files:
- No license, readme, terms, PDF, or text file found by:
  `find potential_assets/Minifantasy_Dungeon_SFX -type f \( -iname "*license*" -o -iname "*readme*" -o -iname "*.txt" -o -iname "*.pdf" \)`

License text summary:
No shipped license text was present in the local Minifantasy SFX pack. Because
the M5 plan requires license verification before shipping extracted audio, no
Minifantasy audio files were copied into committed assets for this lane.

Verdict: SHIP-OK (user-attested; was ASK-USER)

Notes:
A1 used original generated WAV placeholders in `assets/audio/sfx/` so the audio
router, data map, settings API, and QA hooks could ship without committing
unverified third-party audio, pending the pack license.

**USER ATTESTATION (2026-07-02): all user-provided packs are fully licensed and usable, terms-file or not. Verdict upgraded to SHIP-OK (user-attested). xDeviruchi attribution line still ships in credits (cheap + courteous).**

## A3 update (2026-07-03): now actually used

A3 replaced all 19 distinct placeholder SFX WAVs at their existing
`assets/audio/sfx/*.wav` paths with real Minifantasy Dungeon SFX sources
(`potential_assets/Minifantasy_Dungeon_SFX/`), per this verdict's SHIP-OK
(user-attested) status. Corroborating evidence for the attestation: the
sibling pack from the same publisher/collection, `Minifantasy_Dungeon_Music`
(`potential_assets/Minifantasy_Dungeon_Music/Minifantasy_Dungeon_Music/
Licensing.txt`), does ship its terms locally and they are permissive
(commercial + personal use allowed; no reselling/redistributing the pack
itself; credit appreciated but not mandatory) — consistent with the standard
Leohpaz/Minifantasy itch.io terms and with this SFX pack's own attestation.

Curation pipeline: downmix to mono 16-bit PCM @ 44.1kHz, peak-normalize each
source to -1.0 dBFS via a measured `ffmpeg -af volumedetect` gain (not
guessed), convert the two `.mp3` sources (door open/close) to `.wav` since
`test_audio_data.gd` only whitelists `.wav`/`.ogg`. Full source-file → id
table and gain values: `.superpowers/sdd/m5-a3-report.md`. No redistribution
concern beyond A2's precedent (original files are re-encoded, not
byte-identical repacks, and only used inside this project's own asset
bundle, not resold standalone).
