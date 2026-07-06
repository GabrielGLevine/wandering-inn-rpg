# Visual-Fix Log (living)

> **Standing directive (user, 2026-07-04):** accumulate every observed
> visual/presentation defect here as it's seen; every milestone includes a
> visual-fix pass that drains this log as a STANDARD gate item (F-task
> checklist). Baseline expectations at this stage of development: text
> wrapping/clipping, readability, and font selection are SOLVED classes of
> problem; interfaces are standardized (containers/anchors/shared
> components — adding a new element must not require coordinate tweaking);
> **common-sense checks** pass (animations/icons/sfx match the action
> semantically); incremental work ships at max fidelity (best-candidate
> sprites from in-hand packs — never rectangles/recolors as placeholders).

Format: `- [ ] AREA — defect — first-seen/source — notes`. Move to a
"Fixed" section with the commit hash when closed.

## Open

- [ ] FIELD — dormant (respawns:true) encounters look identical to live
  ones after defeat — a "resting/cleared" visual state would stop them
  reading as bugs — user playtest 2026-07-04.
- [ ] FIELD/TILES — world maps render BLOCKED cells as flat tiles while
  arenas render them as biome prop sprites (M6.5 structure map,
  2026-07-04) — props-over-tiles is a repo-wide mandate; field blocked
  cells that visually read solid should get the arena treatment. Content
  decision (changes field look) — NOT part of the M6.5 behavior-
  preserving refactor; the shared TileBoardBuilder makes the swap cheap
  afterward.
- [ ] PROP — `stew_pot` reuses the `grill` sprite at same scale directly
  beside the kitchen's existing grill/hearth decor — reads as "more
  kitchen equipment", not a distinct interactive prop — slice T2
  2026-07-04 — needs a distinct pot/cauldron region pick (Interior_Props
  candidates) at next art pass.

- [ ] UI/TEXT — tutor feed 4th line sits TIGHT against the parchment fold
  (descenders graze it; legible) — F fix-wave residual 2026-07-04 —
  acceptable now; M6.5's feed extraction should give the panel a real
  Container with art-safe padding.

- [x] COMBAT/ANIM — casting a spell triggers the SWORD swing animation —
  user report 2026-07-04 — FIXED by Track B1 (2026-07-06). ROOT CAUSE:
  `spell_damage`/`line_damage` (frost_bolt/flame_jet) route through the
  sim's `_resolve_hit(melee=false)` which reuses the `ATTACK_RESOLVED`
  event, and `combat_screen._play_event_visual` played `"slice"`
  unconditionally on that event. FIX: (1) generated a Body_A cast/gesture
  strip via PixelLab `/animate-with-text` (Body_A idle_side frame fed as
  the reference — 4 frames, raised hand + magic-glow arcs, already aligned
  to Body_A's y48 feet plane); added a `cast` animation to `body_a` in
  `sprites.json` (side sheet reused for down/up — combat renders side only,
  field never casts). (2) `_play_event_visual` now picks `"cast"` vs
  `"slice"` off the payload's `melee` flag (~2-line presentation change,
  under the 20-line threshold). AI-gen provenance: PixelLab, redistributable
  per ToS. Verified: `test_combat_visuals` + `test_sprite_registry` green,
  `mage_unlock_loop` (casts frost_bolt through the new path) green +
  windowed (`04_mage_kit_combat.png`). NOTE: the 0.35s cast frame is
  timing-fragile to catch in a scripted screenshot; the generated frames
  are archived in the Track B1 report / candidate park.
- [x] SPRITE — `a_hunter` (Relc stand-in) green tint darker than ideal —
  A2 report 2026-07-04 — SUPERSEDED/FIXED by Track B1 (2026-07-06): the
  green-tinted human hunter was a semantic mismatch for a Drake anyway.
  Generated a bespoke PixelLab Relc sprite (teal-green Drake guardsman with
  spear, PC16-adjacent, `no_background:true` transparent, non-directional
  idle+walk at `assets/sprites/relc/`), repointed both consumers
  (`skeleton_scene.json` npc + `combatants.json` chip) from `a_hunter` to
  `relc`, and REMOVED the `[0.6,1.0,0.6]` tint (sprite is already teal).
  AI-gen provenance: PixelLab `/generate-image-pixflux` + `/animate-with-text`,
  outputs user-owned/redistributable per PixelLab ToS. Windowed-verified:
  field (`04_gift_node.png` — Relc as Drake in floodplains) + combat
  (`02_second_fight.png` — Relc ally chip in chieftains_raid), both READ.
  NOTE for a future pass: sprite is NON-DIRECTIONAL (single facing all 4
  dirs) — `/rotate` drifted at 64px (doubled the spear), so a clean 4-dir
  set was parked; a directional upgrade is a nice-to-have, not a defect.
- [ ] SPRITE — `sewer_grate` + `training_dummy` are semantic fallback
  placeholders (boulder/crate art) — A2 2026-07-04 — no grate/armor-stand
  art in-tree; content-pass to source or restyle labels to match visuals.
- [ ] SPRITE — A2 reported shipped boulder/crate regions wrong (watermark
  bleed / empty space) but controller's combat-cover read showed crates
  fine — discrepancy UNRESOLVED — verify in a windowed pass before
  touching.
- [ ] PC — field/combat PC is the unclothed Body_A base — outfit layer
  queued since M4 — max-fidelity rule says pick best candidate outfit
  composite now rather than waiting for a bespoke one.
- [ ] PROP — `inn_chest`'s `visual_states` "opened" signal is a TINT only
  (no open-lid frame exists on the wired `Interior_Props_01.png` region or
  its neighbors, checked by crop — M-BEAUTY R3 2026-07-05); a genuine
  open-lid sprite (sourced or authored) would read far more clearly than a
  cool-grey tint shift. Current tint (`[0.5,0.52,0.58]`, deliberately
  strong-contrast per R3's windowed iteration) is a legible "something
  changed" signal but not literally "the chest is open" — content-pass
  candidate.
- [ ] PROP — `dirty_table`'s pre-clean tint (`[0.62,0.56,0.46]` vs
  `table_brown`'s untinted look) reads as dirty at 3x zoom (verified,
  M-BEAUTY R3 2026-07-05, `.superpowers/sdd/fp-handoff/r3-shots/
  inn_00_start_no_labels.png` vs `inn_01_dirty_table_just_cleaned.png`)
  but is SUBTLE at normal 1x viewing scale in a screenshot — meets the
  distinct-at-a-glance contract but a future pass sourcing a genuinely
  different "cluttered/grimy" region (plates, stains) would read faster
  than a tint alone. Cheap fix shipped now per spec §8's "tint is a valid
  distinct-at-a-glance method" allowance; this is the stronger follow-up.
## Fixed

- [x] UI/FIELD-HOTBAR — field skills had no `icon` ids so the overworld
  hotbar's 52px slots fell back to text labels, and "[Basic Cleaning]"
  overflowed the slot illegibly — P2 windowed read 2026-07-05,
  `qa_output/field_hotbar_probe/00_hotbar_boot.png` — fixed in PF VISUAL-LOG
  drain (commit PF wave, uncommitted): assigned `icon` ids to all 8
  field-tagged skills (basic_cleaning/light/basic_cooking/observe + P4's 4
  service skills soothe_clientele/unerring_aim/sweep_the_tables/
  servers_prescience) in `data/skills.json`, added matching `icon_*`
  entries to `data/sprites.json`, and generated distinct code-drawn glyph
  PNGs via `tools/sync_assets.py` (mirrors the SHIPPED skill-icon pattern —
  all ~20 combat skill icons are code-drawn `_draw_placeholder` glyphs, not
  ADMURIN crops; the asset-index has ZERO per-cell metadata for the Admurin
  icon sheets and the binding workflow forbids browsing pack PNGs blindly,
  so blind cell-picking would risk semantic mismatches — code-drawn glyphs
  keep field/combat visual grammar identical). The slot-number badge was
  ALREADY present via WIHotbar's shared `key_hint` render (field_hotbar
  passes `str(number)`); once the icon replaces the text fallback the badge
  reads in the corner exactly as combat's does. Also hardened the WIHotbar
  text fallback (`src/ui/hotbar.gd`) with `clip_text` + ellipsis so any
  future icon-less slot clips inside the 52px frame instead of overflowing.
  NEXT: a future unified art pass could upgrade ALL skill icons (combat +
  field) to real ADMURIN art in one sweep — that needs a human/controller
  cell-pick or an index enrichment first (the pack can't be browsed blind).
  Windowed-verified: `qa_output/field_skills_loop/00_hotbar_boot_1slot.png`
  (broom + "1") and `02_hotbar_grown_3slots.png` (broom/pot/eye with 1/2/3
  badges).
- [x] UI/TOAST — item toast "clipped at the window's right edge" (e.g.
  "Got: Relc's Spare Spear" gift toast) — OF cold-start read 2026-07-05,
  `qa_output/tutorial_flow/02_gift_teaching.png` — fixed in PF VISUAL-LOG
  drain (commit PF wave, uncommitted). ROOT CAUSE was NOT an off-screen
  clip (measured: the toast panel is a fixed 448×96 anchored BOTTOM_RIGHT,
  always fully on-screen at x[808,1256]). The wide conversation panel
  (`dialogue_panel.gd`, 720×232 CENTER_BOTTOM => x[280,1000]) is a later
  sibling CanvasLayer at the same layer, so it drew OVER the toast's left
  half and hid the "Got: " prefix — reading as a left-clip the OF logged as
  a right-edge clip. Fix (`src/ui/message_layer.gd`): while a conversation
  is open (DIALOGUE_STARTED..DIALOGUE_ENDED) the toast RAISES to the
  upper-right (bottom at y456, clearing the conversation panel's y470 top);
  it drops back to the resting bottom-right spot when the conversation ends.
  Pure y-shift, width/height unchanged, so the wrapped-line budget is
  identical (never a widen). Windowed-verified: the gift toast now reads in
  full, clear of the conversation panel, `02_gift_teaching.png`.
- [x] UI/COMBAT — turn-order banner text grazed the top window edge / hung
  onto the dark board below the parchment — OF cold-start read 2026-07-05,
  `tutorial_flow/04_ambush_warrior_spear.png` — fixed in PF VISUAL-LOG drain
  (commit PF wave, uncommitted). The order strip's old 42px height was too
  short for PARCHMENT_STRIP's 20px-margin 9-slice, so the strip art filled
  only a ~18px band in the panel's upper portion (the transparent-margin
  trap) and the turn text's lower half hung below the visible parchment
  while its top grazed the window edge. Fix (`src/combat/combat_hud.gd`):
  grew the panel to 56px (the proven dialogue/readout fill height) so the
  strip renders full-height, plus vertical-centered the text with a
  measured bottom-margin bias so it seats on the parchment's centre, not
  its lip. Windowed-verified: `04_ambush_warrior_spear.png` — "Turn: Relc |
  > Traveler | Goblin Shaman | Goblin Raider" fully on the parchment, no
  top graze, no descenders on the dark board.

## Fixed (earlier)

- [x] LISCOR — roofs misaligned in places — user playtest 2026-07-04 —
  fixed in M-BEAUTY Task R2 (commit hash pending, uncommitted): the
  4-wide building at street (18-21,15-16) had TWO `inn_roof` decor
  pieces ((19,15)/(21,15)) but only ONE `facade_plaster` wall beneath,
  at an unaligned x=20 that lined up under neither roof. Realigned to
  the Adventurer's Guild building's own precedent (two roof/facade
  pairs at MATCHING x, spaced 2 apart) — moved the facade to (19,16)
  and added a second at (21,16), one wall tile directly under each roof.
  Windowed before/after: `.superpowers/sdd/fp-handoff/r2-shots/
  before_01_roof_building.png` vs `after_01_roof_building.png`.
- [x] LISCOR — Dark Cellar door renders freestanding (not against a
  building face) — user playtest 2026-07-04 — fixed in M-BEAUTY Task R2
  (commit hash pending, uncommitted): `cellar_door` (street entity,
  `10,17`) is a quest interactable whose approach path in `crate_light`
  is a hardcoded step sequence ending at that exact cell, so the fix
  dressed AROUND it rather than moving it (checked the script's route
  first, per the task brief) — added one `facade_plaster` decor tile at
  `(11,17)`, immediately east of the door on a row/column the approach
  path never crosses, reading as the building wall the cellar is set
  into. `crate_light` re-verified green (decor is non-blocking; the
  door's cell/route are untouched). Windowed before/after:
  `before_02_cellar_door.png` vs `after_02_cellar_door.png`.
- [x] SCATTER — street-biome scatter includes dark disc props that read
  as repeated sewer grates across the south square — T3 shot
  2026-07-04 — fixed in M-BEAUTY Task R2 (commit hash pending,
  uncommitted), though the root cause was NOT the `scatter` pool: a
  live-instrumented render dump (temporary debug prints, reverted)
  proved the actual culprits are the street map's own two `campfire`
  DECOR entries (`[3,5]` and `[13,10]`) — `campfire` and `sconce` share
  the exact same source art (a stone fire-pit ring with red embers,
  `Bonfire_01-Sheet.png`), and both street campfires shipped UNLIT
  (M-BEAUTY B2 deliberately skipped them, "full gate-district night
  dressing is the rollout task's job") — a dark, glow-less ring with a
  red center reads exactly like `sewer_grate`'s own placeholder rock
  art at a glance. `pebble` (the literal scatter-pool member closest in
  name to the bug report) was cleared of suspicion empirically: removing
  it from the pool, and separately emptying the whole `scatter` array,
  left both fake-grate discs on screen unchanged; a direct GDScript
  render export confirmed `pebble` is a small brown clump, unrelated.
  Fix: added `light: {color:[1.0,0.55,0.25], energy:1.0, radius:34,
  flicker:true}` to both campfire entries, matching the warm palette of
  the other lit campfire/hearth/grill anchors — at dusk/night they now
  glow and flicker, unmistakably reading as fire rather than a cold iron
  grate (the REAL `sewer_grate` keeps its own distinct green, non-flicker
  glow, so it stays unique). NOTE: at DAY (light energy 0 by the
  ship-neutral-first convention) the base sprite's passive resemblance to
  `sewer_grate` is unchanged — that residual is the SAME root cause as
  the separately-logged, still-open "`sewer_grate`/`training_dummy` are
  semantic fallback placeholders" item below, not part of this fix.
  Windowed before/after: `before_03_scatter.png` vs `after_03_scatter.png`;
  real (non-staged) dusk proof via a genuine 40-action phase crossing:
  `02_street_dusk_roof_building.png`/`03_street_dusk_cellar_door.png`.

- [x] COMBAT/SPRITE — Relc combat chip → a_hunter sprite wired — fixed in
  wave A (4c984cd), windowed-verified in wave A2 + M7 E5 shots.

- [x] UI/TEXT — all three `_bb_escape` copies (journal.gd, combat_hud.gd,
  targeting_controller.gd) were self-colliding: the naive
  `.replace("[", "[lb]").replace("]", "[rb]")` chain's first output ("[lb]")
  contains a "]" the second replace re-matches, garbling every bracketed
  name ("[Power Strike]" → "[lb[rb]Power Strike[rb]"; reviewer-confirmed
  user-visible on the combat slot-info line, latent in the aim preview) —
  fixed in the UI wave review pass with the same placeholder-char technique
  in all three copies (kept as three cross-referenced per-file copies by the
  M6.5 zero-cross-dependency idiom; commit hash pending, uncommitted wave).
- [x] UI/TEXT — message panels clipped the last wrapped line (combat feed +
  world dialogue panel; height budgeted ENTRIES not wrapped lines) — fixed
  in M-FP F: wrapped-line budgeting + oldest-entry eviction + ellipsis
  truncation, never widening (D2-7 #6). On-screen truncation only — bus
  events carry full text. Controller re-read both windowed scripts clean.
- [x] UI — world-space entity name labels ("You", NPC nameplates) bled
  through OVER the journal's title ribbon — UI wave items 11/19 fixed the
  SYMPTOM with an explicit `layer = 10` on the journal's CanvasLayer (kept,
  still load-bearing for combat's surviving stats readout — see below).
  **M-BEAUTY R3 (2026-07-05, spec §8 addendum) removed the ROOT CAUSE
  entirely**: field name tags no longer render at all (`world.gd` no
  longer touches `WIWorldLabels`), so this exact bleed-through class can
  never recur on the field side. Windowed-verified across inn/street/
  floodplains (`.superpowers/sdd/fp-handoff/r3-shots/`) — zero floating
  name tags anywhere in the field.
- [x] COMBAT/UI — enemy name labels overlap the action menu when 3+
  enemies cluster at x≥9 — M3-deferred. **Obsoleted by M-BEAUTY R3
  (2026-07-05)**: combat name tags are retired entirely (spec §8 pt.3) —
  only the HP/MP numeral readout and green HP/MP bars survive (neither
  ever overlapped the hotbar), plus the turn-order strip at the top
  (`combat_hud.gd`) as the sanctioned name surface. Windowed-verified,
  `combat_walkthrough` seed 9: `.superpowers/sdd/fp-handoff/r3-shots/
  combat_01_no_name_tags_stats_survive.png`.
