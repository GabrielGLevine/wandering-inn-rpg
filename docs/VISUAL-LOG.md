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

- [ ] UI/BARK — trailing period on a short wrapped 2nd line clips under the
  bark panel's bottom-left decorative fold (DPF rotation: Yelra +
  Dresk shots, payload always carries it). The 2-line budget landed; the
  FOLD inset needs the same measured-band treatment on line 2. DPF close
  fix-wave candidate.
- [ ] UI/PICKER — the board/delivery picker paginates from the TOP,
  losing the header question + 2 of 3 postings' flavor (board_loop +
  delivery_loop shots). Board-centric milestone — severity with opus.
- [ ] MAP/UPSTAIRS — Lyonette's locked door reads as the same
  private-room zone as the PC's own bed (zone ambiguity; a rug/color
  cue would separate "yours" from "hers").
- [ ] ARENA/SEWERS — decorative cave props resemble the live Sewer Bat
  enemy silhouette in the dark arena (target-legibility compounding the
  standing dark-arena item, GH issue #28).

- [ ] SPRITE — **THE DELIVERY BOARD (`runner_board`, M-DEPTH DP5, Runner's
  Guild interior) still rides the `inn_sign` art + a cool blue-grey tint
  [0.65,0.72,0.8]** — the art-wiring task (2026-07-07) gave `guild_board`
  ("THE REQUEST BOARD") bespoke `request_board` art (item closed below),
  but no bespoke delivery-board asset was generated/parked this pass, so
  `runner_board` is now the ONLY board still on the old plank-crop stand-in
  (previously "the second board on the same stand-in" — now the last one).
  Wants a visibly different silhouette from the request board
  (slips-and-strings vs paper-layers), not just a retint, when a bespoke
  asset is generated. First seen: DP5 windowed read (dp5-shots/).
  CONTROLLER READ 2026-07-07 (art-wiring-shots/05): since `inn_sign`'s
  entry was repointed to the new bespoke signpost, `runner_board` now
  renders that art INDOORS — including the **grass tuft baked into the
  post's base**, a green patch sitting on the guild's wooden floor. Reads
  as a paste-in to a first-time player. Raises this item's priority: the
  bespoke delivery-board asset should also be the fix for the indoor-grass
  read (or an interim indoor variant/crop if the asset waits).
- [ ] UI/DIALOGUE — the dialogue panel's PAGE INDICATOR (bottom-center
  "N/M" counter) sits directly behind the field hotbar's slot-1 icon and
  is partially occluded on every paginated conversation — PRE-EXISTING
  (visible identically in DP2's `dp2-shots/01_board_browse.png` and
  DP5's `dp5-shots/02_delivery_board_browse.png`; first LOGGED at DP5's
  windowed read, systemic, not board-specific: any long dialogue).
  Related observation, disclosed not judged: the paginated board-browse
  panel opens showing the TAIL page (options visible), not page 1 — DP2
  parity, may be intentional (options-first), but a first-time reader
  meets the middle of a sentence; worth a taste pass together with the
  indicator occlusion.
- [ ] SPRITE — **a THIRD reproduction of the player-occludes-small-prop
  finding below (`bed`/`lyonette_door`), this time on a market-stall PROP**:
  M-DEPTH DP4's `bread_stall` (street, food_basket sprite, render_scale
  0.75) is fully hidden behind the player's own head/torso when approached
  the way `barracks_walkthrough` scripts it (stand one cell south at
  (11,3), face up, interact) — windowed-verified: cropping
  `qa_output/barracks_walkthrough/01_bread_stall.png` around the expected
  cell (computed from `world.gd`'s camera math, screen ≈(640,160)) shows
  only the player's own sprite; zero bread_stall pixels visible. Confirms
  the DP3 finding's root cause generalizes beyond beds/doors to ANY small
  floor prop approached from the south, not scale/sprite-specific. Non-
  blocking (the toast/accomplishment fire correctly and are asserted via
  the event log; no canonical asserts on-screen prop visibility) — same
  disclosed fix options as the bed entry (bigger crop / anchor-adjust
  small-south-approached props / accept it).
- [ ] UI/TOAST — **stale toast still on-screen at screenshot time, 2
  shots in a row** (`barracks_walkthrough`'s `06_zevaras_desk.png` and
  `07_the_cell.png` both show the EARLIER "Autosaved. (Esc — save/load
  anytime)" line, not that step's own toast — `Watch Captain's desk...`/
  `Barred, and empty...`). Root cause (read from `src/core/game.gd`):
  `barracks_door`'s `map_changed` event is this script's FIRST-EVER map
  transition, which triggers `Game._on_domain_event`'s `save_auto()` →
  the ONE-TIME "Autosaved" toast (`_autosave_announced` gate) — it fires
  a few actions before the desk/cell interacts, and the toast PANEL's
  display/rotation appears to lag behind the script's action rate, so the
  screenshot (taken immediately after each toast's own `wait_for_event`
  confirms it fired on the bus) still shows the older toast on screen.
  NOT a data/event bug — `barracks_walkthrough`'s assertions all pass
  (the exact right toast text is proven in the event log, in the right
  order); this is a presentation-timing artifact of running several
  toast-firing actions back-to-back faster than the panel visually
  rotates. Same class of consideration already flagged in
  `message_layer.gd`'s own doc comments (the class_gained/autosave-toast
  race) — disclosed here as its 3rd-hand consequence, not investigated
  further this task.
- [ ] SPRITE — **the `bed` prop (both the ground-floor inn bed and the new
  M-DEPTH DP3 `your_bed` upstairs) is fully occluded by the player's own
  sprite when approached the way every sleep interaction is scripted**
  (stand one cell south, face up/north, interact) — windowed-verified in
  `.superpowers/sdd/fp-handoff/dp3-shots/03_your_bed_sleep.png`: zoomed in,
  zero pixels of the bed sprite are visible behind the player's head/torso.
  Root cause: `bed`'s `render_scale` (0.375, frame 34x44 -> ~13x16px) is
  small relative to the player character rig, which visually extends
  upward past its own cell into the tile directly north when facing that
  way (the SAME approach geometry every sleep site uses) -- `lyonette_door`
  (DP3, `render_scale` 0.5, ~17x22px) shows a comparable but smaller
  occlusion (a visible sliver survives above the player's head, see
  `02_lyonette_door.png`), suggesting scale is the deciding factor, not a
  z-order/y-sort bug. PRE-EXISTING for the ground-floor bed (same sprite,
  same interaction convention, unchanged by this task) -- newly OBSERVED
  during DP3's windowed read, not introduced by it. Non-blocking: the sleep
  toast/mood card are both fully legible regardless, and no canonical QA
  script asserts on the bed's on-screen visibility. A fix would mean either
  a bigger bed crop, an anchor/y-sort adjustment for small props approached
  from the south, or accepting it as "the player is standing right where
  they'd sleep" — a design call for a future visual-fix pass, not this task.
- [ ] SPRITE — **`guild_notice_wall` (Adventurer's Guild interior) reuses
  `library_shelf`** (reads as a wardrobe/bookshelf, not a wall of papers)
  and sits close enough to `guild_board` + the Renn/Ilvo walk-on pair that
  the cluster reads a little dense at a glance (Renn/Ilvo also share a
  silhouette, tint-only differentiated). `guild_board` itself was closed
  by the art-wiring task (2026-07-07, bespoke `request_board` art) — this
  item survives unchanged, scoped to the notice-wall prop only, which that
  task did not touch. Worth a look together with the Renn/Ilvo tint-only
  pairing.
- [x] UI/HOTBAR — FIXED 783a733 (code-drawn boot glyph, isolation-verified) — **[Stealth] slot renders literal text, no icon glyph**
  (S2-close rotation 2026-07-07, systemic across 4 shots / 2 scripts:
  s2close-playtest-shots/rogue_earn_loop/01-03 + social_loop/01). The
  first thing a player sees after earning [Rogue]. Check skills.json's
  sneak icon id resolves against sprites.json (K3's rename may have
  orphaned it) or pick/generate a semantically-right stealth glyph (the
  K3 brief's glyph pattern). NIGHT fix wave after DP1 releases
  sprites.json.
- [x] UI/INVENTORY — FIXED 783a733 (30px scroll inset inside the measured band) — item card's last lore line rides the panel's bottom
  fold AND collides with the "Press I" toast in tutorial_flow/03 (frame
  illegible at that line). The scroll area's bottom margin vs the
  art-safe band class + the toast's new layer-12 position over that
  corner. Same fix wave.

- [ ] SPRITE/REGION — **"PALETTE :" sheet label baked into every boulder**
  (machine playtest 2026-07-07): Rocks.png carries palette text at its
  top-left; the `boulder` region [0,0,32,40] includes it — renders as
  garbled floating text on 23 usages (17 map decor + 6 arena; visible in
  sewers, training yard, deep tunnels shots). Fix: shift the region below
  the label row (rock body starts ~y8) + windowed re-verify all three
  maps. NIGHT polish wave item 1. The mis-crop class the docs mandate
  windowed-verifying — slipped because boulders never sat in a canonical
  framed shot.
- [ ] UI/TOAST — **3-line toasts clip their last line at the parchment
  fold, everywhere** (machine playtest 2026-07-07): the M-FP F wrapped-
  line budget reached feed/dialogue/readout panels but never
  message_layer's TOAST panel. Best copy lines die at the fold ("…she
  remembers faces, and debts.", the burn toast). Fix: same budget
  discipline (measure wrapped lines vs art-safe height, grow-height like
  L2's dialogue panel or cut). NIGHT polish wave item 2.
- [ ] UI/TUTOR — tutor panel clips Relc's "Earned, not given" line (the
  arc's thesis) at panel bottom in the ambush fight. Same budget class.
  NIGHT polish wave item 3.
- [ ] UI/DIALOGUE — page break splits mid-sentence with no continuation
  cue ("grip. Sword arm, spear arm —" as a page TOP). Fix: break at
  sentence boundary where possible + a continuation marker. NIGHT polish
  wave item 4.
- [ ] MAP/STREET — the gate district reads worst of all maps (grey brick
  floor-vs-wall ambiguity, saturated teal awnings vs muted palette, open
  dead space). It's the hub players crisscross most. Design-level —
  M-DEPTH-adjacent map polish task.
- [x] COMBAT/DARK-ARENAS — enemy HP numerals + small dark sprites hard to
  pick out in sewers/deep-tunnel fights. Mood pin is right; add rim/
  outline on combatant chips or brighten HP labels under dark grades.
  **FIXED (GH #28, 2026-07-07):** traced how the mood grade actually reaches
  combat first — `combat_board_root()` is a bare Node2D with no CanvasLayer
  of its own inside the world SubViewport, so WIAtmosphere's single
  CanvasModulate (per its own B1 EMPIRICAL FINDING) darkens combatant
  sprites/chips/HP-bars right along with the arena tiles; the HP/MP
  NUMERAL readout (`WIWorldLabels`) is a separate CanvasLayer added
  directly under `WIMain`, native-res and outside the SubViewport, so it
  was NEVER touched by the grade (already had a black-fill/white-outline
  treatment) — the numerals read weak mainly because the sprites around
  them melted into the background, not because of their own contrast.
  Fixed with a uniform self_modulate brightness floor on every combatant's
  sprite/chip + HP/MP bars (`board_renderer.gd`'s `_legibility_modulate`/
  `_resolved_mood_rgb`), computed once per `build()` from the arena's
  resolved mood color (own read of `data/moods.json`, never touches
  `atmosphere.gd`'s actual grading): identity (no change) whenever the
  arena's average brightness already clears 0.85, otherwise scaled up
  toward that target, clamped at 3x boost for the darkest pins
  (deep_tunnels/deep_warren, avg ~0.25). Bright-arena pixel-diff
  (`combat_move_input` windowed, before vs. after) is byte-identical —
  zero regression. Windowed before/after:
  `.superpowers/sdd/fp-handoff/dark-arena-shots/01_sewers_vermin_BEFORE.png`
  vs. `01_sewers_vermin_AFTER.png` (sewers vermin fight, PC/enemy sprites
  now read as distinct figures instead of a near-black blob) and
  `06_deep_warren_boss_AFTER.png` (the darkest pin — Relc/Raskghar/boss all
  clearly legible against the still-dark board). Bright control:
  `combat_move_input_BRIGHT_AFTER.png` (goblin_ambush, day) unaffected.
- [ ] COMBAT/ARENAS — arenas read sparse (empty dirt + scattered buckets)
  vs the strong field maps; floodplains ambush arena especially.
  Evocative-dressing pass candidate.
- [ ] UI/FIELD-READOUT — (supersedes the K2 drop-row note) permanent
  legend furniture grows with progression; playtest recommends collapse
  to icons-only after first waking, expand on hold. K2b owns.

- [x] UI/SHOP — Krshia's greyed buy options read a doubled price: the
  authored option copy already carries "(5 gold)" and the affordability
  lock appends "(costs 5 gold)" (M-LEGIBILITY L2 windowed read,
  `.superpowers/sdd/fp-handoff/l2-shots/shop_broke_effect_lines_greyed.png`).
  Pre-existing since Economy v1 (not an L2 regression). **FIXED by
  M-LEGIBILITY L5 (2026-07-06, uncommitted):** `dialogue_panel.gd`'s
  `_requirement_suffix` already had a dedup mechanism (skip the suffix
  when the option text already names the requirement) but only trimmed a
  "requires " lead-in from the requirement string before checking — gold's
  requirement text is "costs N gold" (`WIDialogue._requirement_text`), so
  the "costs " word never matched and the suffix rendered anyway. Fixed by
  also trimming "costs " (`requirement.trim_prefix("requires
  ").trim_prefix("costs ")`) — a strict fix, not a regression risk: every
  shipped `requires: {gold: ...}` option (the 4 Krshia buys, the only
  sites in the game) already authors its price inline, so no option loses
  its only price surface. Kept the authored-copy-carries-the-price design
  (did not strip prices from copy + always-render the suffix) since it's
  the smaller, lower-risk footprint and the existing dedup idiom already
  existed for exactly this class of double-up (skill/class options already
  relied on it). The domain event's `requirement` field is UNCHANGED
  ("costs N gold" still emitted exactly, QA's `economy_loop`/`d2_shop_shot`
  pins on it untouched) — only the ON-SCREEN Label text lost the
  duplicate. Windowed-verified:
  `.superpowers/sdd/fp-handoff/l5-shots/shop_price_dedup_03_shop_all_greyed_broke.png`
  shows every option reading its price exactly once.
- [ ] UI/FIELD-HOTBAR — the slot bar (bottom-center) draws OVER an open
  dialogue panel's bottom parchment edge (z-order: hotbar CanvasLayer above
  message_layer). Nothing is obscured (verified by pixel crop — the "1"
  reading as hidden text is the slot's own key-hint label), purely cosmetic.
  Candidate: hide the whole bar during modals the way the L5 fix wave hides
  the readout panel (number keys are inert then anyway). First-seen L2
  windowed read 2026-07-06. Low priority.
- [ ] FIELD/DEEP_TUNNELS — the four M-ARC A2 flavor/threshold props
  (`deep_fissure` sewers `(8,12)`, `cold_hearth`/`gnaw_pile`/`warren_mouth`
  in deep_tunnels) all use the `boulder` sprite as a stand-in (a collapsed
  fissure, a fire-pit, a bone midden, a gallery mouth). Reads acceptably as
  rubble in the darkest cave grade and is consistent with the sewers'
  `drainage_marker`/`nest_ledge` (also `boulder`), but bespoke sprites
  (Track B / PixelLab) would read far better — the warren_mouth especially
  wants a real widened-gallery/pillar-mouth tile. First-seen 2026-07-06
  (A2, uncommitted). Off the combat spine; low priority. The two Raskghar
  COMBATANTS themselves are real bespoke PixelLab sprites (not stand-ins).

- [ ] FIELD/SEWERS — `nest_ledge` (Content Wave C3 Q1 SKILL-path [Observe]
  prop, sewers `(17,10)`) uses the `boulder` sprite as a stand-in for "a
  broken brick overlook lip" — consistent with the sewers' `drainage_marker`
  (also `boulder`), reads acceptably in the dark cave grade, but a bespoke
  ledge/broken-wall sprite (Track B / PixelLab) would read better. First-seen
  2026-07-06 (C3, uncommitted). Off the combat spine; low priority.

- [x] FIELD — dormant (respawns:true) encounters look identical to live
  ones after defeat — a "resting/cleared" visual state would stop them
  reading as bugs — user playtest 2026-07-04 — FIXED by Track B2 item 6
  (2026-07-06, uncommitted). Presentation-only seam: added a third
  `visual_states` `when` shape `{"dormant": true}` to `world.gd`'s
  `_visual_state_active` (reads `Game.sim.dormant_encounters.has(id)` — no sim
  change), plus a `_refresh_entities_watching_dormant()` scan fired on
  `UI_COMBAT_HIDDEN` (post-combat the field re-shows WITHOUT a rebuild, so the
  just-defeated encounter needs an in-place re-render; the sleep-beat re-arm
  needs no hook — it clears the set on a different map and the encounter's map
  rebuilds on the next MAP_CHANGED). Wired `goblin_encounter_1` (the only
  respawns:true encounter) with a cool blue-grey resting tint
  `[0.42,0.5,0.55]`. Windowed-verified via throwaway probe (deleted): defeated
  goblin_encounter_1 reads clearly dimmed/cleared while the adjacent live
  goblin_encounter_2 stays vivid (`.superpowers/sdd/fp-handoff/b2-shots/
  b2_dormant_00_live.png` vs `b2_dormant_01_resting.png`).
- [ ] COMBATANT/SPRITE — the new `shield_spider` (Content Wave C1, Liscor
  sewers) uses the `bat` sheet as a STAND-IN — there is no arachnid sprite
  in-tree — so a Shield Spider currently renders as a bat, and shares that
  sheet with `sewer_vermin` ("Sewer Bat", which IS sprite-honest). Needs a
  dedicated banded-carapace spider sprite (Track B / PixelLab per the B
  recipes) so the nest fight reads as spiders, not a second bat swarm.
  Overworld tokens are tinted apart (spider cold blue-grey, vermin warm
  grey) but combat sprites are identical. First-seen: C1 build 2026-07-06.
- [x] CONTENT/SPRITE — Content Wave C2 characters **Olesm** + **Zevara**
  shipped WITH real PixelLab pixflux Drake sprites (2026-07-06, uncommitted):
  `olesm` = a slim sky-blue Drake holding a rolled map (guild frontage);
  `zevara` = an armored light-blue Drake Watch officer (the gate). Each is a
  single static 64×64 idle frame (relc/pisces non-directional precedent;
  `no_background`, `side`/`low top-down` views), render_scale 0.5/0.55, anchor
  [0.5,0.97]. Windowed-read in-world at the gate + guild frontage
  (`.superpowers/sdd/fp-handoff/c2-shots/01_zevara_pool.png`,
  `04_olesm_pool.png`) — both read clearly as blue Drakes. Minor follow-up
  (not a defect): idle-only (no walk cycle) and no directional facings —
  acceptable for stationary NPCs, matches relc/pisces fallback behaviour.
  **RESOLVED by the sprite-upgrade wave (2026-07-06):** Olesm + Zevara are
  now DIRECTIONAL + animated (idle+walk, down/side/up) via the v2 character
  pipeline; windowed field reads at
  `.superpowers/sdd/fp-handoff/upgrade-shots/` (`03_olesm_pisces_field.png`,
  `02_zevara_field.png`, `zoom_olesm_pisces.png`, `zoom_zevara.png`).
- [ ] FIELD/TILES — world maps render BLOCKED cells as flat tiles while
  arenas render them as biome prop sprites (M6.5 structure map,
  2026-07-04) — props-over-tiles is a repo-wide mandate; field blocked
  cells that visually read solid should get the arena treatment. Content
  decision (changes field look) — NOT part of the M6.5 behavior-
  preserving refactor; the shared TileBoardBuilder makes the swap cheap
  afterward.
- [x] PROP — `stew_pot` reuses the `grill` sprite at same scale directly
  beside the kitchen's existing grill/hearth decor — reads as "more
  kitchen equipment", not a distinct interactive prop — slice T2
  2026-07-04. (B2 parked for lack of pack art.) **FIXED by Track B3
  (2026-07-06): new `cauldron` PixelLab sprite** (`assets/sprites/cauldron/
  Idle-Sheet.png`, render_scale 0.4, anchor [0.5,0.94], shadow) — a black
  iron cauldron with a rising flame on a log fire; `stew_pot` entity
  repointed `grill`→`cauldron`. Windowed-verified reading distinct from the
  adjacent grill at a glance: `.superpowers/sdd/fp-handoff/b3-shots/
  b3_cauldron_stewpot.png` (+ `b3_inn_start_dirty.png`).

- [ ] UI/TEXT — tutor feed 4th line sits TIGHT against the parchment fold
  (descenders graze it; legible) — F fix-wave residual 2026-07-04 —
  acceptable now; M6.5's feed extraction should give the panel a real
  Container with art-safe padding.

- [x] UI/COMBAT — the readout panel's slot-info line, when it wraps to 2
  lines (a long skill's full "cost — effect — description", e.g. frost_bolt),
  rides the parchment's bottom fold — first-seen in L4's windowed shot
  (`.superpowers/sdd/fp-handoff/l4-shots/01_first_encounter_feed.png`), the
  same "Control rect > art-safe band" panel class the feed/dialogue panels
  were already fixed for (M-FP F) but the readout never got. **FIXED by
  M-LEGIBILITY L5 (2026-07-06, uncommitted):** `combat_hud.gd`'s
  `_compose_readout` now fits the slot-info segment to whatever wrapped-line
  budget remains after the head/hint lines (capacity 3 total), cutting words
  + an ellipsis rather than widening (design D2-7 #6) — see the CLAUDE.md
  Gotchas entry (Message panels budget WRAPPED LINES) for the full
  derivation. `ui_slot_info_rendered` still carries the FULL untruncated
  line (`combat_move_input.json`'s exact pin for `[Power Strike]` is
  unaffected). Windowed-reverified via `status_first_encounter`:
  `.superpowers/sdd/fp-handoff/l5-shots/readout_panel_fix_01_first_encounter_feed.png`
  shows frost_bolt's line now truncating cleanly inside the parchment.

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
  **RESOLVED by the sprite-upgrade wave (2026-07-06):** Relc is now
  DIRECTIONAL + animated (idle/walk/slice, down/side/up) via the v2
  character pipeline (`create-character-pro` 8-facing base kills the
  `/rotate` drift; `lead-jab` slice reads as a clean spear thrust); the
  canon-tall field presence + `combat_scale` containment are preserved
  (re-tuned 0.4→0.3875 for the 124px frame). Windowed reads:
  `.superpowers/sdd/fp-handoff/upgrade-shots/01_relc_field.png`,
  `zoom_relc.png`, `01_relc_combat_containment.png`.
- [x] SPRITE — `sewer_grate` was a semantic fallback placeholder (boulder art)
  — A2 2026-07-04 — FIXED by Track B2 item 1 (2026-07-06, uncommitted):
  repointed to the round copper-rimmed barred manhole grate in the (already
  shipped) `assets/props/sewer/Props.png` region `[112,39,16,18]`,
  render_scale 0.9, shadow dropped (a flat floor grate). Keeps the green
  glow light wiring. Windowed-verified reading as an iron drain/grate,
  distinct from the nearby campfire stone-rings
  (`.superpowers/sdd/fp-handoff/b2-shots/b2_sewer_grate_03_south_square.png`).
- [x] SPRITE — `training_dummy` is a semantic fallback placeholder (crate art)
  — A2 2026-07-04. (B2 parked for lack of pack art.) **FIXED by Track B3
  (2026-07-06): new `training_dummy` PixelLab sprite** (`assets/sprites/
  training_dummy/Idle-Sheet.png`, render_scale 0.5, anchor [0.5,0.92], shadow)
  — a straw pell with a burlap head, outstretched straw arms, on a wooden
  post. Applies to BOTH consumers of the `training_dummy` sprite id (the
  `training_yard` arena/combatant dummies in `combatants.json`/`arenas.json`
  and the `skeleton_scene` decor). Windowed-verified reading unmistakably as
  a straw dummy at combat scale AND as decor: `.superpowers/sdd/fp-handoff/
  b3-shots/b3_training_dummy_spar.png` + `b3_training_dummy_targeting.png`.
- [ ] SPRITE — A2 reported shipped boulder/crate regions wrong (watermark
  bleed / empty space) but controller's combat-cover read showed crates
  fine — discrepancy UNRESOLVED — verify in a windowed pass before
  touching.
- [x] PC — field/combat PC was the unclothed Body_A base — outfit layer
  queued since M4 — FIXED by Track F2 (2026-07-06, uncommitted): the naked
  Body_A skin-tone base is REPLACED by a fully clothed, directional, animated
  PC built via the **PixelLab v2 character pipeline** (Tier-1 subscription).
  `create-character-pro` (template `mannequin`, `low top-down`, 8 consistent
  facings — solves the v1 `/rotate` identity drift) generated an earth-tone
  traveler (olive-tan tunic, brown trousers, leather belt, short brown hair —
  a nobody-yet arrival, NOT armor); `animate-character` (template mode) built
  all six anims from the closest mannequin templates: idle=`breathing-idle`(4),
  walk=`walking`(6), slice=`lead-jab`(3), hit=`taking-punch`(6),
  death=`falling-back-death`(7), cast=`fireball`(6, glowing-flame-in-hand — a
  bonus VFX that reads as spellcasting). Frames export at 104×104 (PixelLab's
  animation canvas), so `sprites.json` body_a gained `render_scale: 0.62`
  (64/104 ≈ old on-screen footprint) + `frame_size:[104,104]`; feet plane is a
  rock-solid y≈78 across every standing anim/frame/direction, so `anchor`
  stays `[0.5,0.75]` (78/104) UNCHANGED. `cast` now ships real down/side/up
  sheets (was side-reused). `test_sprite_registry` counts updated to the new
  per-anim frame counts. Originals parked in
  `potential_assets/pixellab_2026-07-06/body_a_original/`. Verified: import
  clean; 14 units green; full ci_sweep (41) green; windowed field + combat
  READ (`.superpowers/sdd/fp-handoff/f2-shots/f2_field_pc_clothed.png`,
  `f2_combat_pc_clothed.png`, `f2_base_8dir.png`, `f2_all_anims_side.png`).
- [x] PROP — `inn_chest`'s `visual_states` "opened" signal was a TINT only
  (no open-lid frame on the PC16 `Interior_Props_01.png` chest region) —
  M-BEAUTY R3 2026-07-05 — FIXED by Track B2 item 4 (2026-07-06, uncommitted):
  added a `chest_open` sprite (Admurin Animated Chests, `assets/props/admurin/
  Chests.png` region `[50,41,30,23]`, the wide-open-lid frame) and swapped the
  `container_opened` visual_state from the grey tint to `sprite: chest_open`.
  Admurin is TIER-PRIVATE/no-standalone-redistribution, so Chests.png ships in
  assets/ but is listed in `assets_manifest.json` as NEEDS-ATTESTATION /
  bundle:true (public checkout falls back to the placeholder chip). Mild style
  mix (Admurin open vs PC16 closed) is confined to the transient post-open
  reveal and reads unmistakably as an open chest. Windowed-verified after the
  leather_jerkin pickup (`.superpowers/sdd/fp-handoff/b2-shots/
  b2_chest_open_01.png`).
- [x] PROP — `dirty_table`'s pre-clean look was a TINT only
  (`[0.62,0.56,0.46]` vs `table_brown`'s untinted look) — subtle at 1x —
  M-BEAUTY R3 2026-07-05. (B2 parked for lack of pack art.) **FIXED by
  Track B3 (2026-07-06): new `dirty_table` PixelLab sprite** (`assets/
  sprites/dirty_table/Idle-Sheet.png`, render_scale 0.46, anchor [0.5,0.81],
  shadow) — a flat top-down wooden table cluttered with dirty plates, mugs,
  and food scraps, now the visual_states BASE (pre-clean); the existing
  `cleaned_the_inn>=1` swap to `table_brown` (clean) is UNCHANGED. Sprite
  render_scale + anchor were tuned so the on-screen footprint matches
  `table_brown` (both ~24px wide, base-anchored to the cell bottom, centered
  — heights 19px vs 22px), so the clean-swap does not jump. The base tint
  on the entity was dropped (the sprite now carries the dirt). Windowed-
  verified distinct-at-a-glance from the inn's clean tables, and the swap
  verified non-jarring: `.superpowers/sdd/fp-handoff/b3-shots/
  b3_inn_start_dirty.png` (dirty) vs `b3_dirty_table_cleaned.png` (clean).
- [ ] SEWERS — water channels read as FLAT solid-blue stripes under the
  dark mood pin (tile texture invisible) — C1 controller read 2026-07-06,
  `fp-handoff/c1-shots/00_sewers_landing.png` — shimmer overlay exists;
  candidate fixes: channel-adjacent light anchor or a lighter pin B channel.
- [ ] SEWERS — small text-like artifact renders above the two encounter
  mounds in the same shot (mangled glyphs) — labels were removed
  repo-wide, so WHAT renders there? CF review hint; windowed zoom needed.
  POSSIBLE label-removal regression on new-map encounter entities.
- [ ] SPRITE — `shield_spider` ships on the `bat` sprite (flagged
  stand-in, C1) — needs a real arachnid via the next PixelLab batch.

## Fixed

- [x] SPRITE/CANON — FIXED (art-wiring task, 2026-07-07, commit pending,
  uncommitted) — **Lyonette** used the `citizen_f` sprite with a pink tint,
  a human-woman stand-in with the wrong hair (wiki canon: bright RED hair
  + blue eyes; the C2 task/spec's "blonde" was a canon miss). Replaced with
  a bespoke PixelLab directional+animated sprite (`lyonette_c1`, the winning
  candidate of 3 generated; `_c2`/`_c3` rejected) matching canon exactly —
  bright red hair, blue eyes, worn-but-fine green dress. The pink tint hack
  is gone entirely (no `tint` field on the entity anymore). Windowed-
  verified adjacency read: `.superpowers/sdd/fp-handoff/art-wiring-shots/
  01_lyonette_adjacency.png` (dialogue_walkthrough, `01_lyonette_intro`) —
  red hair clearly visible, PC standing directly adjacent (feet-plane
  anchor measured, no one-cell-off gap), plus the same shot in
  `02_inn_common_room_cast_variety.png` (inn_walkthrough, `01_start`).
- [x] SPRITE — FIXED (art-wiring task, 2026-07-07, commit pending,
  uncommitted) — **THE REQUEST BOARD (`guild_board`)** reused the `inn_sign`
  hanging-plank crop and read small/low-contrast against the wood-plank
  wall. Replaced with bespoke `request_board` art (a proper wood-framed
  corkboard with visible pinned parchment sheets), the old `tint` hack
  removed (no longer needed once the board had its own distinct
  silhouette/colors). Windowed-verified:
  `.superpowers/sdd/fp-handoff/art-wiring-shots/04_the_request_board.png`
  (guild_interior_walkthrough, `03_the_board`) — the board now reads as a
  real bulletin board with distinct parchment layers, clearly bigger/more
  legible than the old plank-crop stand-in. (The Runner's Guild delivery
  board, `runner_board`, still rides the old `inn_sign` art — no bespoke
  delivery-board asset was generated this pass — see the Open item above.)
- [x] SPRITE — FIXED (art-wiring task, 2026-07-07, commit pending,
  uncommitted) — **`inn_sign`** (the "No Killing Goblins" sign, floodplains
  `(6,6)`) was a Furniture.png hanging-plank-on-chains crop, the closest
  semantic match available since no dedicated signpost asset existed in
  any in-hand pack. Replaced with a bespoke PixelLab signpost (text-free
  tankard/mug plank on a planted post — the sign's wording still lives
  entirely in toast/observe copy, unchanged, by design). Windowed-verified:
  `.superpowers/sdd/fp-handoff/art-wiring-shots/03_inn_sign_out_front.png`
  (tutorial_flow, `00b_inn_sign`) — a real standing signpost next to the
  inn's door, legible at a glance.
- [x] FIELD/RUNNERS_GUILD — FIXED (art-wiring task, 2026-07-07, commit
  pending, uncommitted) — the staged resting-runner copy proposed "flat on
  a bench, legs up the wall"; no bench sprite existed in any in-hand
  catalog, so the Runner's Guild shipped a `stool` stand-in next to the
  resting `pc_gnoll_m` walk-on. Replaced the `stool` decor entry (cell
  `[1,5]`) with a bespoke `bench` prop (a real wooden bench, wider/more
  legible than the stool). The resting-runner's STANDING pose is unchanged
  (a lying-down runner frame would need a bespoke animation, out of scope)
  — this closes the "no bench asset exists" half of the item only.
  Windowed-verified: `.superpowers/sdd/fp-handoff/art-wiring-shots/
  05_bonus_bench_and_runner_board.png` (delivery_loop, `01_runners_guild_
  interior`) — a proper bench, clearly legible, beside the resting runner.
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
