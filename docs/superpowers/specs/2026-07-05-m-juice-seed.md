# M-JUICE — Game-Feel & Audio Feedback (SEED)

Status: Fable-authored seed 2026-07-05 (the #1 gap vs first-class pixel
RPGs, per the session's gap analysis; user queued as NIGHT-GOAL stretch).
Seed-level: pillars + mechanisms + quality bars pinned; a full brainstorm
ratifies scope before execution unless the night reaches it (then:
execute conservatively within this seed, escalate taste calls).

## 1. Principle

Every player action gets a FELT response within 100ms: something moves,
flashes, or sounds. Systems are already deep — this milestone makes them
*legible to the hands*. Presentation-only throughout: the sim is never
touched; all juice consumes existing bus events.

## 2. Combat feel (the core)

- **Hit-stop:** 40-80ms freeze on melee connect (combat_playback is the
  seam — it already owns paced visual beats; a hit beat gains a hold).
  QA-safe: zero under TestDriver/headless (the M4 T10 pacing precedent).
- **Screenshake:** 2-4px, ~120ms on damage TAKEN by the PC + big hits
  dealt; camera seam (field Camera2D + combat board root offset). Budget:
  subtle — the 320×180 viewport makes 2px read strongly.
- **Impact flashes/particles:** white hit-flash on the struck sprite
  (modulate pulse, shipped cast-flash precedent), tiny directional spark
  burst (WIAmbience preset machinery reused — a one-shot `hit_sparks`
  preset, ≤8 particles).
- **Damage feedback stays PROSE + bars** (no floating damage numbers —
  the feed is the voice; numbers are already visible in the readout).
  Optional: bar "chip" ghost (white segment that drains after a beat).
- **Death/defeat beats:** brief slow-fade on a combatant's sprite instead
  of instant removal.

## 3. Audio feedback (the other half)

- SFX on: melee hit/miss, spell cast + resolve, dash, turn start (subtle
  tick), victory/defeat stingers, door transitions, pickup, equip,
  toast-worthy accomplishments, UI open/close/confirm/cancel, footsteps
  (field, throttled to step cadence, per-biome variant if cheap).
- **The [ding!]:** class_gained/class_level_up gets a distinct, canon-
  worthy level chime — the single most identity-carrying sound in the
  game. Candidates from the CC0 Kenney trio + Junkala; commission/gen
  later if none sing.
- Source: the audited CC0 set already on disk
  (`potential_assets/research_2026-07-05/` — Kenney RPG/Interface/Impact)
  — TIER-PUBLIC clean, so juice audio ships in the public repo too.
- Mechanism: `data/audio.json`-style event→sfx map consumed by a thin
  presentation listener (the music player precedent); volume ducking NOT
  in v1.

## 4. Field feel

- Footsteps + door sounds + pickup pop (tiny sprite scale-bounce on
  chest/loot pickup); screen fade on map transitions (150ms black dip —
  kills the teleport-pop).
- **The GDI sleep sequence (user directive 2026-07-06, promoted from
  "nice" to core):** sleeping fades to BLACK and the night's level/class
  announcements render as centered text in the darkness — the Grand
  Design's voice, exactly how leveling arrives in canon
  ("[Warrior Class Obtained!]" cadence, wiki-checked phrasing) — then
  morning fades in with a chime. Presentation-only: the same events
  fire; the black screen is a renderer for them, so every QA assertion
  holds. The SAME device opens a new game (M-ARC Act I owns that copy).

## 5. QA + bars

- Every juice effect: QA-neutral (zero under TestDriver/headless), event
  streams byte-identical (the M6.5 zero-behavior-change discipline);
  windowed shots can't prove FEEL — human playtest is the gate, but
  `audio_played` events assert coverage (which actions have a sound).
- Zero-warning; wasm-safe (compat renderer constraints per B3's list).

## 6. Non-goals

Damage numbers, hit-pause on AI-vs-AI beats (skippable playback already
covers pacing), music composition, volume settings UI (that's UX
table-stakes, separate), controller rumble.
