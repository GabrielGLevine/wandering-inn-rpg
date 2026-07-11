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

- [ ] INN/EXTERIOR — the facade's dusk/night WINDOW GLOW is
  mechanism-verified (phase-gated light, 2-of-8 budget, the lantern
  precedent) but not yet eyeballed at dusk outside — no script frames the
  exterior at a non-day phase. One playtest look, or a future probe.
  (#37's one deferred exit-criterion line, 2026-07-08.) **#31 drain
  (2026-07-08) re-adjudication: still open, exactly as scoped** — this is
  a "look at it" item by its own description, nothing to fix without a
  windowed dusk-phase frame of the exterior. Controller shot request:
  a phase-crossing script (or a debug teleport) that frames the inn
  exterior at dusk/night, screenshot windowed.
- [ ] SPRITE/RIVERFARM — the witch's cell (3,8) sits close enough under
  witch_cottage_prop's (3,7) sprite that her figure visually overlaps the
  cottage wall/window rather than reading as clearly standing in front of
  it (riverfarm_walkthrough/05_witch_elder_day.png,
  06_witch_young_night.png). Still legible (both forms distinguishable),
  but a cleaner read would nudge the witch one cell further south or add a
  small field_y_sort_bias_px on the cottage. First seen: 8b Task R1
  windowed read, 2026-07-08. **#31 drain (2026-07-08) re-adjudication:
  still open, not attempted.** Already legible per its own text (not
  blocking); either candidate fix (moving the witch's cell, or biasing
  the cottage's sort key) changes what a windowed screenshot needs to
  confirm — left for a pass that can look at the result, consistent with
  the bed-family item's y-sort-bias caution above.
- [ ] SPRITE/RIVERFARM — the Farm.png crop-row decor (crop_row_orange/
  green/dark_green, tilled-plot dressing) reads as a row of rounded
  colored blobs at native zoom rather than a clearly legible planted-crop
  silhouette (riverfarm_walkthrough/01_arrived_riverfarm_village_day.png,
  03_charmed_villager_echo.png). Not a semantic mismatch (it IS a crop
  sprite, licensed pick per picks.md sec.3) but a fidelity/legibility
  flag worth a second look once a wiring pass has more of the field
  dressed. First seen: 8b Task R1 windowed read, 2026-07-08. **#31 drain
  (2026-07-08) re-adjudication: still open.** A different crop pick or a
  render_scale bump both need a windowed comparison to tell whether they
  actually read clearer, not just different — left open, no image-gen
  access in this lane to source an alternative anyway.

- [ ] ART/WATER — **every water surface renders as a flat, hard-edged,
  saturated-blue rectangle** — no bank/edge tiles, no depth gradient. In the
  near-black sewers the two channels are the brightest thing on screen and
  read as placeholder UI blocks / missing textures (playtest-2026-07-08-
  shots/sewers_walkthrough/00_sewers_landing.png); the floodplains pond
  shows the same flat read under the hotbar in field shots. The [Snap
  Freeze] ice patch is a slightly-lighter blue rectangle on the blue
  rectangle — the traversal seam's payoff is nearly invisible
  (04_ice_crossing.png; the wading player sprite half-sinks into the flat
  fill). Biome edge-tile or shader treatment wanted. **Issue #30
  (2026-07-08): ROOT CAUSE FOUND + FIXED, see the Fixed section entry
  below** — the water_shimmer.gdshader was already wired (both maps'
  segments were already using it) but its UV-wobble was sampling a
  perfectly flat-fill tile (verified: zero pixel variance across the
  whole 16x16 region), so the "shimmer" was structurally invisible on
  ANY map, not a sewers-specific gap. Windowed re-confirmation still
  wanted (headless-only lane) — controller shot list in the polish
  report.
- [ ] FIELD/ARC — Relc's descent-veto conversation (arc_flow dd_05) plays
  with NO Relc sprite anywhere on the field — he speaks from nowhere at the
  warren mouth, then exists in the fight roster. A walk-on cameo (guild
  DP1 idiom) at the warren mouth would ground the beat. Disclosed 2026-07-08
  playtest, design-level. **#31 drain (2026-07-08) re-adjudication: still
  open, deliberately not fixed here.** A walk-on cameo means a new
  entity/positioning wired into `arc_flow`'s own route — content work, not
  a presentation-only fix, and outside a headless-only lane's ability to
  windowed-confirm a new cameo reads right. Left for a content-touching
  pass with real windowed verification.
- [ ] UI/PICKER — the board/delivery picker paginates from the TOP,
  losing the header question + 2 of 3 postings' flavor (board_loop +
  delivery_loop shots). Board-centric milestone — severity with opus.
- [ ] MAP/UPSTAIRS — Lyonette's locked door reads as the same
  private-room zone as the PC's own bed (zone ambiguity; a rug/color
  cue would separate "yours" from "hers"). **#31 drain (2026-07-08)
  re-adjudication: still open.** A rug/color cue is a new decor pick that
  needs a windowed read to confirm it actually differentiates the zones
  rather than adding more clutter — a headless-only lane can place a
  sprite but can't judge the result, so left for a pass that can look at
  it.
- [ ] ARENA/SEWERS — decorative cave props resemble the live Sewer Bat
  enemy silhouette in the dark arena (target-legibility compounding the
  standing dark-arena item, GH issue #28). Folded into issue #30's arena
  pass (2026-07-08) rather than fixed standalone here — see #30's section
  of the polish report.

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
  **#31 drain (2026-07-08) re-adjudication: still open, no PixelLab/image-
  gen access in this lane** — checked `docs/asset-index.md` for an
  in-tree substitute crop; nothing catalogued reads as an indoor
  bulletin board without the signpost's grass base. A crop-only interim
  (re-cropping the EXISTING signpost sheet tighter, above the grass tuft)
  was considered but the tuft is baked into the post's own base texture,
  not a separable region — cropping it out would also cut the post,
  leaving a floating plank. Left open for the next art-gen pass.
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
  indicator occlusion. **#31 drain (2026-07-08) re-adjudication: still
  open.** Both the z-order fix (hide/reflow the page indicator during the
  field hotbar's visible window) and the "which page opens first" call
  are UI decisions a controller should make with eyes on a screenshot,
  not guessed blind — a wrong default page (e.g. forcing page 1 when
  tail-first was actually deliberate) would be a regression dressed as a
  fix. Left open, not attempted.
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
  small-south-approached props / accept it). **#31 drain (2026-07-08):
  see the consolidated re-adjudication on the `bed` entry below — this is
  the same family (now 3 reproductions: bed/lyonette_door, bread_stall,
  and garden_bed further down), tracked together there rather than
  re-litigated per prop.**
- [x] UI/TOAST — **stale toast still on-screen at screenshot time, 2
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
  further this task. **#31 drain (2026-07-08) re-adjudication: CLOSED as
  not-a-bug, no commit.** The item's own text already proves this —
  every domain event/assertion is correct; the only "defect" is a
  documentation-run screenshot catching a real, expected presentation
  timing artifact (a script driving actions faster than a human would).
  No player-facing behavior to fix.
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
  **#31 drain (2026-07-08) re-adjudication: still open, consolidating this
  family (bed/lyonette_door here, bread_stall above, garden_bed below —
  4 reproductions of one root cause) into ONE tracked item.** A concrete
  tool now exists that didn't when this was first logged: Hotfix item 3
  (commit `b688470`, this same drain's audit turned it up) added
  `field_y_sort_bias_px` to `sprites.json` — a per-sprite Y-SORT-KEY-ONLY
  offset (net-zero visual position shift) built for exactly this
  "wrong figure draws on top" class, previously applied the other
  direction (pulling an oversized ENEMY's sort key north so the PC drew on
  top of it). Applying a small POSITIVE bias to `bed`/`bread_stall`/
  `garden_bed` (pushing their sort key south so they draw ON TOP of an
  adjacent player instead of under them) is the same mechanism run in the
  opposite direction and should close all 4 reproductions with one data
  change. NOT applied in this pass: the bias is a global sort-key shift
  versus every other y-sorted sibling, not scoped to "vs the player only"
  — a naive magnitude could flip an unrelated correct ordering against a
  different neighboring prop, and confirming it didn't requires a
  windowed read this headless-only lane can't take. Left as a concrete,
  scoped recommendation for the next pass that can look at the result.
- [ ] SPRITE — **`guild_notice_wall` (Adventurer's Guild interior) reuses
  `library_shelf`** (reads as a wardrobe/bookshelf, not a wall of papers)
  and sits close enough to `guild_board` + the Renn/Ilvo walk-on pair that
  the cluster reads a little dense at a glance (Renn/Ilvo also share a
  silhouette, tint-only differentiated). `guild_board` itself was closed
  by the art-wiring task (2026-07-07, bespoke `request_board` art) — this
  item survives unchanged, scoped to the notice-wall prop only, which that
  task did not touch. Worth a look together with the Renn/Ilvo tint-only
  pairing. **#31 drain (2026-07-08) re-adjudication: still open, no
  substitute found.** Checked `data/sprites.json` for any other
  in-tree sprite that reads as "a wall of pinned papers" distinct from
  both `library_shelf` and the already-used `request_board` (reusing
  `request_board` here too would make the notice wall and the guild
  board look identical, trading one mismatch for another) — nothing
  else catalogued fits. Needs new art, left open.

- [ ] SPRITE/REGION — **"PALETTE :" sheet label baked into every boulder**
  (machine playtest 2026-07-07): Rocks.png carries palette text at its
  top-left; the `boulder` region [0,0,32,40] includes it — renders as
  garbled floating text on 23 usages (17 map decor + 6 arena; visible in
  sewers, training yard, deep tunnels shots). Fix: shift the region below
  the label row (rock body starts ~y8) + windowed re-verify all three
  maps. NIGHT polish wave item 1. The mis-crop class the docs mandate
  windowed-verifying — slipped because boulders never sat in a canonical
  framed shot. **#31 drain (2026-07-08) re-adjudication: CLOSED, verified
  via data read, no commit needed.** `data/sprites.json`'s current
  `boulder` entry crops `[0, 19, 32, 43]` — already well below the label
  row this item names (`y8`), by a comfortable 11px margin. No commit in
  this repo's history ever touched the `boulder` region value (checked
  `git log -S'"boulder"'`), so either this was corrected before the item
  was logged and the log was never updated, or the label-inclusion never
  actually shipped in this v4 project (the description may describe the
  source PNG's general hazard, not a value this project ever used). This
  same root cause also likely explains the separately-logged "text-like
  artifact above the two sewers encounter mounds" item below (both
  encounter mounds sit near `boulder`-sprited decor) — closing that
  cross-reference here too rather than duplicating the investigation.
- [ ] UI/TUTOR — tutor panel clips Relc's "Earned, not given" line (the
  arc's thesis) at panel bottom in the ambush fight. Same budget class.
  NIGHT polish wave item 3. **#31 drain (2026-07-08) re-adjudication:
  left open, not closed outright.** Tutor lines render through the same
  combat feed (`combat_hud.gd`/`combat_screen.gd`) that CLAUDE.md's own
  Gotchas section documents as already carrying the wrapped-line
  evict/truncate budget (M-FP F) — that fix's introducing commit
  (`5508ecb`, 2026-07-06) predates this finding's playtest date
  (2026-07-07), so this specific clip is either already resolved by that
  generic mechanism and just never re-checked, or tutor lines hit some
  narrower edge the generic budget doesn't cover (e.g. eviction removing
  the thesis line before the player reads it, distinct from a fold-clip).
  Can't tell apart without a windowed read of the ambush fight — left
  open with this narrowed diagnosis rather than guessed closed.
- [ ] UI/DIALOGUE — page break splits mid-sentence with no continuation
  cue ("grip. Sword arm, spear arm —" as a page TOP). Fix: break at
  sentence boundary where possible + a continuation marker. NIGHT polish
  wave item 4. **#31 drain (2026-07-08) re-adjudication: still open.**
  Sentence-boundary pagination is a real copy-flow change to
  `dialogue_panel.gd`'s page-split logic, not a budget/margin tweak —
  risks shifting page counts on every existing multi-page conversation
  (any canonical asserting page N/M would need re-verification). Left for
  a pass that can windowed-confirm the new break points read naturally.
- [x] MAP/STREET — FIXED (issue #29, this pass, 2026-07-08, uncommitted)
  — the gate district read worst of all maps (grey brick floor-vs-wall
  ambiguity, saturated teal awnings vs muted palette, open dead space).
  All three named defects addressed, each measured (pixel-sampled), not
  eyeballed, since this is a headless-only lane: (1) floor-vs-wall —
  `facade_plaster`'s avg color (142,119,98) was only ~26 luminance units
  above the cobble floor's (116,106,95); brightened/warmed it to
  (182,136,88) via a data-only tint, staying warm/amber not neutral gray.
  (2) teal awnings — traced to `inn_roof` (avg (43,138,100), a genuinely
  saturated teal from its source sheet, street-map-only consumer,
  checked), retinted to a warm terracotta. (3) dead space — reviewed and
  ACCEPTED as deliberate (the gate plaza + the documented "clear transit
  lane" at y4), not dressed further. Bonus finding while fixing the
  "twin same-sprite vendors" companion complaint: the 3 market-row NPCs
  sharing one `citizen_f` sprite were ALSO canon/pronoun mismatches
  (Krshia is textually a Gnoll, the Peddler and Watch Sergeant are both
  textually "he") — swapped to `pc_gnoll_f`/`pc_human_m`/`pc_drake_m`.
  Verified: `load_gate`, `test_content`, `test_sprite_registry`, all 18
  unit suites, and every canonical touching the street/these NPCs
  (`gate_district_walkthrough`, `crate_fight/talk/light`, `economy_loop`
  *, `wrong_order_*`, `barracks_walkthrough`, `door_chain_*`,
  `delivery_loop`, `stages_loop`, `social_loop`, `olesm_chess_loop`,
  `stage3_perks_loop`) all green. * `economy_loop` fails, but this is a
  PRE-EXISTING regression bisected to BEFORE this lane's first commit
  (reproduces identically on a fresh worktree checked out at this lane's
  own base commit, `a038170`, with zero of this lane's changes present)
  — a fight's `loot_dropped`/`gold_changed` never fires, cascading into
  every later assertion; root cause not chased further (out of scope for
  #29/#30/#31/#45), flagged for the controller. No windowed
  re-confirmation performed (headless-only lane) — controller shot list
  in the polish report.
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
  Evocative-dressing pass candidate. **Issue #30 (2026-07-08): the named
  worst offender (`goblin_ambush`/`goblin_ambush_tutorial`, the floodplains
  ambush) got an 8-entry off-grid tree/bush frame mirroring
  `witch_hollow`'s own precedent shape, using the SAME sprite ids the
  floodplains field map already dresses with (field-to-arena continuity).
  Also closed a more severe gap the audit turned up: the `inn` biome
  (`inn_cellar`/`merchant_warehouse`, 10 blocked cells combined) had NO
  `BLOCKED_PROPS_BY_BIOME` pool at all — every blocked cell there was
  rendering the OLD flat recolored tile, not even props-over-tiles;
  added `"inn": ["crate", "barrel"]` (reusing the already single-cell-
  verified street pool). Remaining arenas (`cave_mouth`/`sewers_nest`/
  `deep_warren`/`ruin_court` all already have a `cave` pool + some
  off-grid decor; `mercantile_alley` has a `street` pool + 3 off-grid
  entries) were reviewed and left as-is — none reproduce the "flat
  fallback tile" defect this pass specifically hunted, and further
  off-grid decor density is a taste call a windowed read should make, not
  a blind addition. Verified: `load_gate`, `test_content`,
  `tutorial_flow`, `level_up_loop`, `defeat_ally_alive`, `crate_fight`,
  `wrong_order_fight`, `door_chain_fight` green; balance harness
  unaffected (decor is presentation-only, never read by `WICombat`).
  Windowed re-confirmation still wanted — controller shot list in the
  polish report.
- [ ] UI/FIELD-READOUT — (supersedes the K2 drop-row note) permanent
  legend furniture grows with progression; playtest recommends collapse
  to icons-only after first waking, expand on hold. K2b owns. **#31
  drain (2026-07-08) re-adjudication: still open.** K2b (commit
  `e121e5e`) shipped the loadout assign/unassign mechanics, not this
  visual collapse-to-icons behavior — checked the diff, no
  icons-only/expand-on-hold UI change is in it. A UI interaction-model
  change (collapse/expand on hold) needs windowed confirmation of the
  collapsed state actually reading clearly at icon-only size; left open
  for a pass that can look at it.

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
  windowed read 2026-07-06. Low priority. **#31 drain (2026-07-08):
  reviewed, left as-is — already correctly self-adjudicated as
  cosmetic/low-priority by its own description (nothing obscured), not
  worth a code change ahead of higher-severity items in this pass.**
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
  **#31 drain (2026-07-08): reviewed, left open — needs new art (no
  image-gen access in this lane), already correctly flagged low-priority.**

- [ ] FIELD/SEWERS — `nest_ledge` (Content Wave C3 Q1 SKILL-path [Observe]
  prop, sewers `(17,10)`) uses the `boulder` sprite as a stand-in for "a
  broken brick overlook lip" — consistent with the sewers' `drainage_marker`
  (also `boulder`), reads acceptably in the dark cave grade, but a bespoke
  ledge/broken-wall sprite (Track B / PixelLab) would read better. First-seen
  2026-07-06 (C3, uncommitted). Off the combat spine; low priority. **#31
  drain (2026-07-08): reviewed alongside issue #30's sewers dressing pass
  — decor-only, still needs new art, left open.**

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
  **#31 drain (2026-07-08): still open, needs new art, no image-gen access
  in this lane — also DEDUPES the near-identical "SPRITE — shield_spider
  ships on the bat sprite" entry further down this log (same defect,
  logged twice); that duplicate is removed, tracked here only.**
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
  afterward. **#31 drain (2026-07-08) re-adjudication: still open,
  deliberately not attempted.** This is a repo-wide field-rendering
  convention change (every map, every blocked cell) — genuinely too
  large for a drain-pass fix per #31's own charter ("promote it rather
  than force-fitting"), and a visual change at this scope needs windowed
  review across multiple maps before shipping, not a blind data edit.
  Recommend promoting to its own issue if it's still wanted; not
  promoted here since it's pre-existing design debt, not a new finding.
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
- [x] SPRITE — A2 reported shipped boulder/crate regions wrong (watermark
  bleed / empty space) but controller's combat-cover read showed crates
  fine — discrepancy UNRESOLVED — verify in a windowed pass before
  touching. **#31 drain (2026-07-08): partially resolved by this pass's
  data read for `boulder` — see the Fixed section's "PALETTE :" label
  closure above (current region `[0,19,32,43]` is clean, matching the
  controller's "crates fine" read, not A2's). Checked `crate` too: it
  reads from a DIFFERENT sheet entirely (`Furniture.png` region
  `[690,71,38,26]`, not Rocks.png) — structurally can't share Rocks.png's
  palette-label hazard, so A2's "watermark bleed" concern doesn't apply
  to the shipped `crate` region either. Closing this item alongside the
  boulder one: both objects check out clean via data read, matching the
  controller's read over A2's.
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
- [x] SEWERS — water channels read as FLAT solid-blue stripes under the
  dark mood pin (tile texture invisible) — C1 controller read 2026-07-06,
  `fp-handoff/c1-shots/00_sewers_landing.png` — shimmer overlay exists;
  candidate fixes: channel-adjacent light anchor or a lighter pin B channel.
  **FIXED by issue #30 (2026-07-08) — see the ART/WATER entry in the Fixed
  section above (same root cause, same fix: the shimmer's cap tile was a
  flat fill, swapped to a textured one).** "shimmer overlay exists" in
  this item's own text was the tell — the mechanism was never missing,
  it had nothing to shimmer.
- [ ] GARDEN/UI — GF rotation frictions (2026-07-08, gf-rotation-report),
  part (c) only (parts (a)/(b) resolved — see below): QA coverage note —
  no diagonal move leg exists INSIDE `garden_sanctuary` to re-check G1's
  Y-sort quirk near edges; a future `garden_walkthrough` revision should
  add one. **#31 drain (2026-07-08): left open — QA-script authoring is
  its own task (`wi-writing-qa-scripts`), not a presentation fix, and out
  of scope for a polish drain pass.** Part (a) (`garden_bed` occlusion) is
  tracked in the consolidated bed-family item above. Part (b)
  (`playtest_boot` mid-word truncation) is FIXED this pass — see
  `title_screen.gd`'s `_first_sentence`, now cuts at the last word
  boundary within budget instead of a raw char index; `playtest_boot`
  re-verified green.
- [x] SEWERS — small text-like artifact renders above the two encounter
  mounds in the same shot (mangled glyphs) — labels were removed
  repo-wide, so WHAT renders there? CF review hint; windowed zoom needed.
  POSSIBLE label-removal regression on new-map encounter entities. **#31
  drain (2026-07-08): CLOSED, cross-referenced to the boulder-region
  entry in the Fixed section above rather than re-investigated —** both
  sewers encounter mounds (`nest_ledge`/`drainage_marker`) sit on
  `boulder`-sprited decor, the exact sprite the PALETTE-label item names;
  no field-entity label-rendering path exists in `world.gd` for encounters
  (checked — field name tags were removed repo-wide in R3, grepped clean),
  so there is no separate label-removal regression to chase. Same root
  cause, already verified not currently present in the shipped crop.
- [ ] COMBAT/TEXT — terrain-sourced slow expiry reuses the generic
  STATUS_EXPIRED feed line "shakes it off", which reads odd while the
  combatant is STILL standing on [Ice Floor] ice (slowed again next
  turn) — GH#21 controller windowed read 2026-07-07,
  `qa_output/ice_floor_loop/01_standing_slow.png`. Candidate: a
  terrain-aware expiry line ("the ice still grips") keyed off the
  status's source. **#31 drain (2026-07-08) re-adjudication: still open.**
  A copy/design call (does the status system distinguish
  terrain-sourced expiry from every other kind of expiry?) rather than a
  presentation bug — left for a design pass, not attempted blind.
- [ ] COMBAT/TEXT — [Ice Floor]'s readout slot-info line truncates at
  "...for 2 rounds...." — the fitted 3-line budget eats the trailing
  "Slows." verb (full line rides `ui_slot_info_rendered` untruncated,
  the L5 contract) — GH#21 controller read,
  `qa_output/ice_floor_loop/00_icy_floor_cast.png`. Cosmetic; the feed
  shows the slow anyway on first application. **#31 drain (2026-07-08):
  reviewed, left as-is — already self-adjudicated cosmetic (the item's
  own text says the slow is legible anyway), and the untruncated payload
  contract means nothing is actually lost, just the last word off-screen.**
- [ ] SPRITE — `pantry_door`'s AWAKENED state still reads as barely-
  distinguishable from default/flicker at gameplay distance — DF fix wave
  (2026-07-07, issue #8 rotation item 3). Fired 4 PixelLab v1 `/inpaint`
  generations at the queued `docs/design/8a-asset-assembly.md` sec. 4 spec
  (target: the existing 34x44 `door` crop, wood-panel-only mask across a
  strength/prompt sweep 60-260) — full log in
  `potential_assets/pixellab_2026-07-07/manifest.md`. None passed the bar:
  the model either abandoned the door's silhouette entirely at high
  strength (gen1) or produced no visible glow/rune detail at all at lower
  strength (gen2-4) — the ~28x14px inpaint target is likely too small for
  legible rune linework at this model's resolution. Kept the shipped
  tint (`[1.05,0.9,0.6]`) + warm flickering `PointLight2D` (unchanged).
  Windowed-verified honestly (`qa_output/door_awakening/
  01_pantry_door_awakened_portal_menu.png`, cropped/zoomed): the warm tint
  IS present but subtle — a first-time player would likely NOT read this
  door as magically awakened from the tint alone; the light's flicker
  isn't visible in a single static frame either. Candidate fixes for a
  future pass: a brighter tint delta and/or larger light radius/energy
  (data-only, no art needed), or a re-attempt generating a LARGER
  reference frame (e.g. via `/v2/create-tileset` or a dedicated object
  endpoint) and downscaling, rather than inpainting directly at the
  shipped 34x44 size.
- [ ] MAP/RUIN — `ruin_surface`'s canonical route (`ruin_walkthrough`)
  never crosses the map's one dressed area (the fallen-rubble-column/
  broken-lintel `walls.segments` at x6-11,y8-11, deliberately "the
  untouched middle of the room" per that map's own D3 _comment) — so every
  screenshot this canonical actually produces
  (`qa_output/ruin_walkthrough/00_ruin_landing.png`,
  `01_pedestal_locked.png`) reads as a flat, uniform cave floor with two
  identical `boulder` decor props, not a ruin (DPF rotation F1, confirmed
  live in the DF fix wave rotation, 2026-07-07). Root cause: the map's
  `biome` is literally `"cave"` (reusing the verified cave-floor tile
  neighborhood, per D1's own _comment) and its only Albez-specific
  architectural dressing sits off the walked path. Candidate fixes (design
  call, not implemented this pass): (a) extend `ruin_walkthrough`'s route
  or add a screenshot beat through the rubble-column area so the existing
  dressing is at least visible to QA/players who walk there, or (b)
  relocate some of that dressing (or add ruin-specific floor variety, per
  `docs/design/8a-asset-assembly.md` sec. 1's Cemetery-pack candidates,
  never wired) along the edge-hugging route players actually walk. Not
  implemented here — DF's charter is fixes, not new map-dressing content;
  flagging for a future content pass. **#31 drain (2026-07-08): reviewed,
  left open unchanged — no new information changes the prior deferral;
  still a route/content decision, not a presentation fix.**

## Fixed

- [x] ART/WATER — FIXED (issue #30, this pass, 2026-07-08, uncommitted) —
  every water surface (floodplains pond, sewers channels) read as a flat,
  hard-edged, saturated-blue rectangle, worst in the near-black sewers
  where it read as a placeholder UI block. ROOT CAUSE, found by reading
  the actual pipeline rather than assuming a missing feature: BOTH maps'
  water segments already reference `water_shimmer.gdshader`
  (`world.gd`'s `_build_water_shimmer` is fully generic — keys off
  `sheet == Water_tiles.png`, no map-name check — and the sewers map's
  own `_comment` already says "auto shimmer overlay + blocking", meaning
  it was authored expecting the shimmer to just work). The shimmer WAS
  active; it just had nothing to shimmer — every water segment's `cap`
  tile was `Water_tiles.png`'s `(1,7)`, verified via a PIL alpha-scan to
  be a COMPLETELY FLAT fill (every pixel in the 16x16 region is the
  identical `(62,146,209)`, zero variance) — a UV-wobble shader sampling
  a uniform-color texture produces zero visible change at any offset, by
  definition. Scanned the rest of the sheet for a tile with real texture
  and picked `(1,5)` (5 distinct blue shades, a genuine subtle ripple
  pattern, still fully opaque/seamless-tileable). Swapped the `cap`
  coordinate on all 7 shipped water segments (5 floodplains + 2 sewers,
  `data/skeleton_scene.json`) from `[1,7]` to `[1,5]`, plus the two
  code-level defaults that mirror it: `world.gd`'s `ICE_CAP_COORD`
  (the [Snap Freeze] ice overlay reuses the water sheet's cap tile,
  tinted frost — same flat-tile problem, same fix) and
  `_build_water_shimmer`'s fallback default (defensive; every shipped
  segment sets its own `cap` explicitly today). Zero shader/code-logic
  change — this was a DATA pick, not a missing mechanism. Verified:
  `load_gate`, `test_content`, `test_sprite_registry`,
  `test_traversal_seams`, `tutorial_flow`, `sewers_walkthrough`,
  `ice_floor_loop`, `atmosphere_check`, `inn_walkthrough` all green;
  balance harness unaffected (55 cells x 100 seeds, PASS — this never
  touches combat data). NOT windowed-verified in this pass (headless-only
  lane) — see the polish report's controller shot list for the exact
  before/after frames to confirm the ripple actually reads at native
  zoom under both the day floodplains grade and the dark sewers grade.
- [x] UI/TOAST — FIXED (commit `da57786`, "ARCH track complete... +
  playtest polish wave") — 3-line toasts clipped their last line at the
  parchment fold, everywhere (the M-FP F wrapped-line budget had reached
  feed/dialogue/readout panels but never `message_layer`'s TOAST panel).
  `da57786` adds `TOAST_FOLD_DANGER_PX`/`_toast_panel_height_for(lines)`
  — a FULLY GENERIC per-wrapped-line growth formula (no hardcoded line
  count), applied unconditionally to every toast via
  `_resize_toast_panel(text)` before each show. **#31 drain (2026-07-08):
  this also closes the separately-logged "4-line toasts may not budget
  the auto-grown case" item above** (verified by reading the formula: it
  takes `lines` as a parameter and scales the panel height + fold margin
  for ANY count, not just 3 — there is no special-casing to outgrow).
  No windowed re-verification performed in this pass (headless-only
  lane); flagging for a windowed spot-check on a real 4-line toast if one
  exists in a canonical, but the code has no structural reason to fail
  past 3 lines.
- [x] UI/BARK — FIXED (Hotfix item 1, commit `8d7d1bb`, 2026-07-08) —
  trailing period on a short wrapped 2nd line clipped under the bark
  panel's bottom-left decorative fold (DPF rotation: Yelra + Dresk
  shots), and at severity, ate Erin's #9 Garden-unlock reveal line and
  the gate district Watch Guard bark entirely. Reused the toast panel's
  own measured `TOAST_FOLD_DANGER_PX` (same chrome texture/patch margin)
  and its "budget it twice for a vertically-centered label" rule.
  Windowed-reverified in the original commit: both barks read clean.
  **#31 drain (2026-07-08): relocated from Open, where it had sat as
  still-open despite already being fixed the same day — the drain's own
  danger list ("check git history before assuming an item is still
  open") caught this one.**
- [x] COMBAT/UI — FIXED (Hotfix item 4, commit `4757fdb`, 2026-07-08) —
  friend-vs-foe HP bars were all the same green, with the turn-order
  strip the only enemy cue (worst in arc_flow's 4-combatant boss fight).
  Bars now key off `c["side"]` (ally green / enemy red-orange — a
  colorblind-safe split, not pure red/green); GH#28's dark-arena
  brightness floor still applies to both. Windowed-reverified in the
  original commit against deep_descent's boss fight + a sewers vermin
  fight. **#31 drain (2026-07-08): relocated from Open — the item was
  never checked against the hotfix wave that landed the same day it was
  logged.**
- [x] UI/INVENTORY — FIXED (Hotfix item 2, commit `b99d881`, 2026-07-08)
  — full-pack inventory opened with the cursor's own row 0 scrolled past
  the top of the list (no `>` mark visible anywhere on screen,
  `gear_loop`'s 19-item pack). Scrolls to row 0 directly on a fresh
  `_open()` instead of relying on `ensure_control_visible`'s unreliable
  first-rebuild geometry read. **#31 drain (2026-07-08): this entry was
  ALREADY marked `[x] FIXED` in the Open section (citing "hotfix wave
  155ee5c") — that hash does not exist in this repo's history
  (`git rev-parse` fails on it); relocated here with the CORRECT commit
  (`b99d881`, confirmed by reading its actual diff/message).**
- [x] SPRITE — FIXED (Hotfix item 3, commit `b688470`, 2026-07-08) — a
  big 2-tall ENEMY sprite (the Awakened Raskghar) fully hid the PLAYER
  standing one row north of it through arc_flow's boss reveal + the
  Relc-veto dialogue (row-only y-sort put an oversized sprite's overhang
  ahead of an adjacent same-scale figure). Fixed via `sprites.json`'s new
  `field_y_sort_bias_px` (data-only, opt-in, net-zero visual position
  shift — pulls the SORT KEY only). Windowed-reverified in the original
  commit: PC and boss read as two distinct figures through the whole
  beat. **#31 drain (2026-07-08): same mis-citation as the inventory
  entry above (doc said "hotfix wave 155ee5c", which does not exist);
  relocated here with the CORRECT commit (`b688470`).**
- [x] UI/HOTBAR — FIXED (commit `6af2009`, M-DEPTH DP2 wave) — **[Stealth]
  slot rendered literal text, no icon glyph** (S2-close rotation
  2026-07-07, systemic across 4 shots/2 scripts) — the first thing a
  player sees after earning [Rogue]. `6af2009` adds the missing
  `icon_sneak` entry to `data/sprites.json` (a code-drawn glyph, the
  shipped pattern for all combat/field skill icons). **#31 drain
  (2026-07-08): this entry was already marked `[x] FIXED` in Open citing
  a NONEXISTENT commit (`783a733` — `git rev-parse` fails on it);
  relocated here with the real commit found by tracing `icon_sneak`'s
  actual introduction.**
- [x] UI/INVENTORY — FIXED (commit `6af2009`, M-DEPTH DP2 wave) — item
  card's last lore line rode the panel's bottom fold AND collided with
  the "Press I" toast (`tutorial_flow/03`). `6af2009` adds
  `SCROLL_BOTTOM_INSET := 30.0` (`inventory.gd`) — a measured fixed-height
  spacer reserving real art-safe clearance for the scroll area alone,
  same idiom as `message_layer.gd`'s `TOAST_FOLD_DANGER_PX`. **#31 drain
  (2026-07-08): same nonexistent-commit citation (`783a733`) as the
  hotbar entry above; relocated here with the real commit.**
- [x] SPRITE/REGION — CLOSED, not-a-bug, no commit (#31 drain,
  2026-07-08) — "PALETTE :" sheet label allegedly baked into every
  `boulder` usage (23 usages across sewers/training yard/deep tunnels).
  Verified via data read: `data/sprites.json`'s current `boulder` region
  is `[0, 19, 32, 43]`, already well clear (11px margin) of the label row
  the item itself names as the danger zone (`~y8`). No commit in this
  repo's history ever touched the `boulder` region value
  (`git log -S'"boulder"'` shows only the unrelated 2026-07-06 project
  directory rename) — the crop this project actually ships was never the
  bad one described. Closing rather than leaving open on a stale
  description; if a real garbled-label sighting recurs, it's a different
  root cause than this region.
- [x] SPRITE — FIXED (DF fix wave, 2026-07-07, commit `92cffcb`) —
  **`ruin_guardian` visually fused with the PC's own sprite at 2-cell
  range** (BLOCKING, DPF machine-playtest rotation B1,
  `qa_output/ruin_walkthrough/01_pedestal_locked.png`: "a small human head
  sitting directly on top of a tall gray monster torso"). Root cause: a
  mismeasured `raskghar_awakened` anchor (`data/sprites.json` had
  anchor.y=0.7823/97-124, but a PIL alpha-scan of the sprite's own
  `Idle_Down-Sheet.png` frame 0 finds the true feet at 87/124=0.7016) —
  the stale anchor dragged the whole figure ~8 rendered px too far north,
  on top of its own cell. Fixed the anchor AND nudged `ruin_guardian`'s
  `skeleton_scene.json` cell one row south (17,7 -> 17,8, `door_chain_fight.
  json`'s teleport target updated to match) to fully clear the remaining
  overlap at 2-cell PC range while preserving the sprite's intentionally-
  larger-than-Gnoll `render_scale` (shrinking it instead would have erased
  the "towers over Gnolls" read). Windowed-reverified: the two figures now
  read as distinct (small tan human vs. large blue-grey beast).
- [x] UI/TOAST — FIXED (DF fix wave, 2026-07-07, commit `0f5b5f0`) —
  **stale "You sleep soundly." toast still on screen when the awakened
  `pantry_door`'s portal menu opens** (FRICTION, DPF rotation F2,
  `qa_output/door_awakening/01_pantry_door_awakened_portal_menu.png`).
  The toast panel had no clear-on-transition treatment, unlike the ambient
  dialogue-line bark panel (which the Skills-wave fix already clears on
  DIALOGUE_STARTED/COMBAT_STARTED/MAP_CHANGED). Added `_clear_toast()`
  (`src/ui/message_layer.gd`) mirroring those exact three call sites — a
  fix at the CLASS level (any stale toast surviving into a dialogue/
  combat/map transition), not a bespoke one-off for this one toast.
  Windowed-reverified clean; regression-checked headless against the
  highest toast-volume canonicals (work_loop, tutorial_flow, arc_flow,
  deep_descent, field_skills_loop, barracks_walkthrough, portal_menu).
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

## 2026-07-08 — 8c C1 merge (controller windowed adjudication)
- [x] TINT — APPLIED (CF fix wave): Wilovan's parlor tint lifted [0.62,0.7,0.56] -> [0.75,0.8,0.68] (the reserve lever, adjudicated warranted for the marquee NPC). Windowed-verified, `invrisil_disagreement_fight`/`invrisil_walkthrough` seed 9. Judge live at the 8c gate.
- [x] SPRITE/REGION — CLOSED, not-a-bug (whole-8c review): streetlamp blocked-cell plinth read checked against `invrisil_walkthrough`'s frames `00_scale_shock_arrival`/`06_facade_scale_shock` — the base plate reads as an intentional lamp-base/glow-pad against the corrected boulevard paving, not as noise. No further action.

## 2026-07-09 — post-v0.4.0 machine playtest (4 parallel opus lanes, 13 scripts, all PASS; findings = screenshots)
### v0.4.1 fix wave (same day) — applied + windowed-verified
- [x] SPRITE/FRAME — APPLIED: `river_wolf_idle` was sliced at
  `frame_size: [32,32]`/6 frames against a 192x32 sheet that actually
  holds FOUR 48x32 wolves — every frame a dismembered chunk, strobing at
  6fps. Fixed to [48,32]/4 frames + PIL-measured anchor [0.443,1.0].
  Windowed-verified whole wolf: `08_village_night.png` re-shot (evidence
  kept at scratchpad v041-evidence/night_whole_wolf.png). Combat wolf was
  always a separate correct rig. Trap comment now in sprites.json.
- [x] UI/TOAST — APPLIED, root cause REVISED from the machine-playtest
  diagnosis: the toast panel DID have a grow-to-fit budget
  (`_resize_toast_panel`, measure was even correct: 6 lines) — the real
  bug was the 9-PATCH: Banner_Horizontal's fold art starts 29px above the
  region bottom but STRIP_PATCH_MARGIN is 20, so 9 source px of fold sat
  in the STRETCHED CENTER band and scaled with panel height (~41px fold at
  a 6-line toast vs the fixed 28px budget). Fix: STRIP_FOLD_PATCH_BOTTOM
  := 32 pins the whole fold in the unstretched bottom patch (toast +
  dialogue bark panels), DANGER_PX 28→30. Windowed-verified: the 343-char
  ledger toast renders all 6 lines clear of the fold
  (v041-evidence/toast_fold_fixed.png). LESSON for every 9-patch panel
  that GROWS: border-art measurements taken at one height do not survive
  center-stretch; border art belongs inside the patch margins.
- [x] SPRITE/REGION — APPLIED: crop_row_orange/green/dark_green regions
  moved off Farm.png's icon-labelled seed-sack columns (x0-64) onto the
  real planted rows (carrots [80,14], leafy [33,82], dark herbs [33,178]),
  cut at measured inter-plant gap columns. Windowed-verified: village plot
  reads as a garden, charmed villager no longer occluded
  (v041-evidence/day_no_wolf_real_crops.png, villager_unoccluded.png).
- [x] UI/DIALOGUE — APPLIED: empty-speaker lines no longer compose a
  leading `": "` (message_layer.gd DIALOGUE_LINE arm; no QA pin depended
  on the old form — repo-grepped). Windowed-verified on the Invrisil
  crowd-extra bark (v041-evidence/no_leading_colon.png).
- [x] DESIGN — APPLIED: the night-wolf field marker now day/dusk-HIDES via
  a new render-only `hidden` field in `visual_states` (world.gd; keys on
  the same phase shape the encounter gate uses), so the sprite can never
  again contradict its own "gone with the light" day toast. Sim-side
  interact/observe/gate behavior untouched at every phase.
  Windowed-verified both directions (v041-evidence/day_no_wolf_real_crops
  .png vs night_whole_wolf.png). CORRECTION to the machine-playtest entry:
  the "gravestone" beside the cot is actually `riverfarm_anchor_stone`
  (the portal waystone) — no gravestone exists; that claim is retracted.
- [x] SIGNPOSTING — APPLIED (the user's "can't find the witch's hollow"):
  the riverfarm↔hollow door pair wore `hollow_small_tree` — a door
  indistinguishable from ordinary forest edge. New owned PixelLab prop
  `trail_gap` (sunlit worn-footpath opening between two bent trunks) on
  BOTH sides. Windowed-verified: pops against the hollow's dark treeline
  (v041-evidence/hollow_trail_gap.png).
- [x] PROP — APPLIED (user directive, item 1): the inn pantry door's
  flicker/awakened `visual_states` now wear `anchor_waystone` — the SAME
  portal-arch prop as every region's anchor stone (cool-blue flicker,
  warm-gold awakened + light). Retired the `pantry_door_glow` placeholder
  and its missing-sheet fallback warning. Windowed-verified with the
  portal menu open (v041-evidence/inn_waystone.png).
- OPEN (COMBAT/LEGIBILITY, P2): sewer vermin fight — enemy bat sprites are
  near-invisible dark specks on the dark floor; players locate enemies by
  HP bars only, while ~6 bright purple fungus DECOR sprites out-compete
  the actual threats for attention. HP numerals themselves fine. Fix
  territory: brighten/outline the bat sprite or dim the fungus.
  Evidence: `qa_output/sewers_walkthrough/01_vermin_encounter.png`.
- OPEN → ISSUE #49 (PROP/DESIGN, the user-confirmed "bed outside"):
  `riverfarm_guest_cot` still floats on open lawn despite hotfix #7c (the
  longhouse sprite's visible extent ends south of it). RATIFIED fix
  (user, 2026-07-09): a longhouse INTERIOR re-homes the cot — an interim
  shift was deliberately skipped (it re-risks the occlusion family that
  burned placement #1 at this exact site, for a position #49 deletes).
  The systemic sleep-site presentation clause (garden_bed taste call,
  Invrisil crate-couch) also lives in #49.
  Evidence: `qa_output/riverfarm_walkthrough/09_guest_cot_sleep.png`.
- OPEN (QA-blindness note, reviewer finding): phase-keyed `visual_states`
  — including the new `hidden` field — have ZERO headless teeth: no bus
  event reflects entity visibility, so deleting the PHASE_CHANGED refresh
  hook would still sweep green. Every phase-keyed visual change is
  windowed-read-only verifiable (the witch two-form read always was; the
  wolf day-hide joins it). Any future headless pin would need a
  `ui_entity_visibility` confirmation event — log-worthy, not yet worth
  the machinery.
- OPEN (minor sweep, residuals): status readout numerals collide with a
  decor post right of the PC
  (`qa_output/status_first_encounter/01_first_encounter_feed.png`);
  upstairs `your_bed` pale-tan sprite barely reads as a bed on the hatched
  nook floor (`qa_output/upstairs_walkthrough/01_upstairs_hallway.png`).
  (Guest-couch-as-crate, identical Hired Blade triplets, and base-less day
  braziers moved to ISSUE #49's charter.)
- VERIFIED HOLDING (regression checks, don't break): L5 3-line readout
  budget exact (head+hint+truncated slot-info, full text in payload,
  `status_first_encounter/01`); toast 2-line fits everywhere outside the
  Invrisil long-line case; gear panel zero clipping end-to-end; village
  brighten payoff unmistakable (`riverfarm_talk/01`→`02`); night wolf
  ARENA legible; garden map identity lands; [Light] dark-map reveal lands;
  no baked-sheet artifacts anywhere; no payload-only punchlines.

## 2026-07-09 — hotfix wave 2 (item 8 fix-first rev)
- OPEN (art follow-up): riverfarm's river band tile — `Water_tiles.png[2,7]`
  is genuinely blue but PIXEL-FLAT: every pixel in the 16x16 region is the
  identical (62,146,209), zero variance (the SAME defect class as the
  documented ICE_CAP_COORD trap in world.gd — a flat fill reads as a flat
  rectangle regardless of hue). The hotfix-wave-2 cover_skip fix makes the
  blue SHOW; making it read as WATER needs a textured tile pick (the
  water sheet's rippled variants, e.g. the [1,5] family ICE_CAP_COORD
  uses) and/or extending the floodplains pond-shimmer overlay treatment
  (world.gd's water_shimmer, currently keyed to walls-segment water, not
  floor_layers water) to the riverfarm band. Deliberately not done in the
  hotfix lane — the shimmer overlay's cell source is a walls-segment
  derivation, so the floor_layers river needs its own small mechanism
  decision (windowed-judged, controller call).

## 2026-07-10 (#55 windowed retune pass)
- ruin_surface boulders: contact-shadow blob reads as a hard DARK SQUARE
  under the cave-dark grade (pre-existing, A/B-verified NOT the #55 tint
  thread — square present with tint code stashed). Likely the shadow
  texture's soft edge banding to nothing under the dark modulate. Fix
  idea: scale shadow alpha with the map grade, or swap to a smaller
  ellipse for tall thin props.
