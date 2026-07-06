# Kenney + Junkala CC0 audio license verdict (M-JUICE E1)

Packs (all Creative Commons Zero / CC0 1.0 — public domain):
- **Kenney RPG Audio** — `potential_assets/research_2026-07-05/kenney_rpg-audio/`
  (License.txt: "License (Creative Commons Zero, CC0)"; credit appreciated, not
  mandatory).
- **Kenney Interface Sounds** — `.../kenney_interface-sounds/` (CC0, same terms).
- **Kenney Impact Sounds** — `.../kenney_impact-sounds/` (CC0, same terms).
- **Juhani Junkala — JRPG Towns** — `.../junkala_jrpg-towns/` (INFO.txt: "released
  under CC0 creative commons license. You can do anything you want with these
  tunes."). NOTE: this is a MUSIC pack (town-theme loops); NOT consumed by E1
  (E1 is the SFX layer only). Verdicted here for the record so a later
  public-music swap of the FORBIDDEN xDeviruchi tracks can reuse it.

## Verdict: SHIP-PUBLIC (CC0)

CC0 places these assets in the public domain: redistribution, modification, and
commercial use are all permitted with no attribution requirement. Unlike the
FORBIDDEN Minifantasy SFX / xDeviruchi music (bundle-only, `assets_manifest.json`),
**CC0 SFX ship in the public repo.** The 24 curated SFX below are therefore
committed to `assets/audio/sfx/` AND removed from the FORBIDDEN manifest (a
public checkout now hears real SFX, not silence).

## What E1 shipped

Re-sourced the entire SFX layer (19 ids) from Minifantasy → CC0 and added 5 new
juice events (door / pickup / equip / inventory open / close). Same curation
pipeline as M5-A3: downmix to mono 16-bit PCM @ 44.1 kHz, peak-normalize each to
−1.0 dBFS via a measured `ffmpeg volumedetect` gain (not guessed). Sources are
re-encoded (not byte-identical repacks) and used only inside this project's own
asset bundle, never resold standalone.

### id (wav) → CC0 source

| sfx file | CC0 source | pack |
|---|---|---|
| ui_tick.wav | click_001 | interface |
| ui_confirm.wav | confirmation_001 | interface |
| dialogue_open.wav | bookOpen | rpg |
| dialogue_choice.wav | select_001 | interface |
| toast.wav | pluck_001 | interface |
| footstep.wav | footstep_wood_000 | impact |
| attack_hit.wav | impactMetal_light_000 | impact |
| attack_miss.wav | knifeSlice | rpg |
| skill_physical.wav | impactMetal_heavy_000 | impact |
| skill_fire.wav | impactSoft_heavy_000 | impact |
| skill_frost.wav | impactGlass_light_000 | impact |
| skill_arcane.wav | impactBell_heavy_002 | impact |
| dash.wav | cloth1 | rpg |
| downed.wav | impactSoft_medium_000 | impact |
| victory.wav | confirmation_004 | interface |
| defeat.wav | impactBell_heavy_001 | impact |
| **level_up.wav (THE [ding!])** | **confirmation_002** | **interface** |
| quest_chime.wav | confirmation_003 | interface |
| save_chime.wav | bong_001 | interface |
| door_transition.wav (new) | doorClose_1 | rpg |
| item_pickup.wav (new) | handleSmallLeather | rpg |
| item_equip.wav (new) | metalLatch | rpg |
| ui_open.wav (new) | open_003 | interface |
| ui_close.wav (new) | close_003 | interface |

### The [ding!] — confirmation_002

Auditioned spectrally (no audible listen possible in this environment): a
level-up chime wants an ascending, bright, ~half-second sparkle. Windowed
spectral-centroid contour picked the winner cleanly:
- **confirmation_002 (0.54 s)** — centroid rises 1492 → 2499 → 3696 → 4978 Hz,
  a near-monotonic ascending sparkle = the JRPG level-up archetype. **CHOSEN**
  for both `level_up` and `class_gained`.
- Runner-up: confirmation_004 (0.49 s, rises 901 → 3493 Hz then resolves down to
  1472 — a warmer "ta-da"; now serves the `victory` SFX).
- Runner-up: impactBell_heavy_000 (1.48 s, ~600 Hz warm bell toll — ceremonial,
  very Liscor-bells, but long/low; a different identity than a snappy ding).

The packs DO sing — no dud, no commission needed. A human should still confirm
audibly (audio cannot be screenshot; QA proves the mapping fires, not the tone).

Credit line (cheap + courteous, though CC0 requires none): "SFX by Kenney
(kenney.nl) — CC0."
