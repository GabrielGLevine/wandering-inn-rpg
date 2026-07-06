# M5 Seed — Playable Demo / Game Feel (pre-brainstorm)

> Status: **seed, not a spec.** User directive (2026-07-02, mid-M4): "start moving towards
> a real playable demo that has the 'feel' of an actual game even if we're still building
> out features and logic (rather than something that's just serviceable for playtesting)."
> This doc collects the gap analysis + open questions; M5 gets the full
> brainstorm → spec → plan cycle against it once M4 closes.

## What "feels like a game" is missing after M4 ships

M4 delivers: tiled maps, PC/NPC/prop sprites, PC combat sprite, paced+skippable AI turns,
cast flashes, clean 1024×640 layout, dialogue hubs, discoverable save/load. Still missing,
roughly ordered by feel-per-effort:

1. **Audio — the single biggest absence.** Zero sound today. A title/inn/combat music bed +
   a small SFX set (menu move/confirm, footsteps, hit/miss, spell cast, level-up sting,
   quest chime) transforms perceived quality. Godot bus architecture per
   `godot-prompter:audio-system`. Needs sourced audio (Kenney CC0 / itch packs — sourcing list TBD).
2. **Game shell.** Boots straight into the sim today. Title screen (New Game / Continue /
   Quit), death→reload flow presented as a screen rather than a banner, map-transition
   fades, pause menu polish. Small code, huge "this is a real game" signal.
3. **UI theme + font.** Default Godot theme + default font everywhere. One pixel font
   (m5x7 / Kenney CC0) + a Theme resource (panel 9-slices from Pixel Crawler UI-adjacent
   art or Kenney UI pack) restyles every screen at once.
4. **Motion juice.** Grid moves currently teleport; lerp/tween steps (~0.1s), bump-on-blocked,
   screen shake on hits, HP-bar tween, toast slide-ins. `godot-prompter:tween-animation`.
5. **Combat cast/enemy presentation completeness.** Enemies are still colored chips until
   the sprite-sourcing decision (parked in M4 spec §0) is made: goblins/Cave Spider/Relc
   need bought or commissioned sprites, spell VFX needs a pack (BDragon1727/Pimen). This is
   the one lane where money/licensing blocks feel.
6. **Ambient life.** NPC idle wander within rooms, a second background villager or two,
   inn prop animations (fireplace from Bonfire sheets). Cheap, optional, big atmosphere.

## Explicitly NOT feel work (deferred unless user re-prioritizes)

- Action-driven classes vision (was the M5 candidate before this directive — needs its own
  interactive brainstorm; likely M6 now, pending user confirmation).
- New story content/maps beyond what demonstrates the demo loop.

## Proposed demo definition (to pressure-test in brainstorm)

"A stranger can sit down, see a title screen, play The Errand either path, fight both
street encounters with sound and readable feedback, level up, save, die, and reload —
and at no point does it feel like a test harness."

## Open questions for the user (brainstorm inputs)

1. **Sourcing budget/permission:** enemy sprites (goblin/spider/drakonid), spell VFX pack,
   audio packs, pixel font — OK to research + shortlist for purchase? (Licenses verified
   before any buy; CC0-first where quality allows.)
2. **Priority order within feel:** audio vs shell vs theme vs juice — gut ranking?
3. **Does action-driven classes slide to M6**, or does M5 need a slice of it (e.g. just
   action-counter groundwork) to make progression feel real in the demo?
4. **Scope guard:** is M5 feel-only (no new mechanics), or feel + the enemy-sprite sourcing
   integration (real goblins on the board)?

## Fable spike (user-designated, 2026-07-02): Wandering Inn wiki canon research

During M5 subagent downtime, the controller researches the TWI wiki (source of truth)
to ground M6: curate the ~8–12 playable class tree (canon names, evolution lines,
consolidation targets), map canon [Skills] onto the four locked M6 mechanics
(action counters, evolution, ~20–25% split friction, offered-at-sleep consolidation),
and produce `docs/superpowers/specs/<date>-m6-canon-class-taxonomy.md` as direct M6
spec input. Genuinely Fable-level: canon judgment × mechanical design, not lookup.

## Candidate parallel lanes (per the parallelism-first convention, 2026-07-02)

M5's feel workstreams are unusually lane-friendly — file-ownership sets are nearly
disjoint by nature. Sketch for the plan to formalize:

- **Lane A — Audio:** new `src/audio/` + `data/audio.json` + asset extracts; touches
  `game.gd`/bus listeners only at one wiring point (barrier task at lane end).
- **Lane B — Game shell:** new title-screen scene/script + boot flow in `game.gd`;
  owns `project.godot` main-scene setting.
- **Lane C — Theme/font:** one Theme resource + font assets; a single apply-point
  per UI file (small barrier task after A/B land to avoid file contention on
  `world.gd`/`combat_screen.gd`).
- **Lane D — Juice:** tween helpers in `world.gd`/`combat_screen.gd` — CONFLICTS with
  C's apply-points; sequence D after C (or same lane).
- Barrier: final layout/screenshot recapture + docs (controller).

Consultant checkpoint (new convention): send the drafted M5 spec to the external
Fable consultant for adversarial review before writing the plan — controller-authored
specs carried self-contradictions in M3 and M4 that a peer would catch.

## Notes

- QA-first convention continues: every feel feature gets a QA hook where assertable
  (`ui_*_rendered` confirmations, audio-played events on the bus; screenshots for visuals).
- Asset browsing without context cost: `docs/asset-index.md` (+ `tools/asset_index.py`).
