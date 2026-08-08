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

### v0.16 MILESTONE CLOSE — composed cross-region machine playtest (2026-07-28)

Post-merge-train read on `main` (#319/#320/#321/#322 all landed), real asset
overlay, seed 9, windowed, every PNG opened. Evidence root:
`wandering_inn_game/qa_output/machine_playtest_2026-07-28_v016_close/`.
Runs: the eight named route canonicals (`flood_ledger_help`,
`thicket_keeps_skill`, `invrisil_setting_talk`, `invrisil_hat_quiet`,
`pallass_standards_fight`, `pallass_ledger_carry`, `floodplains_price_fight`,
`floodplains_price_talk`), six interior/gate loops (`stationer_room_loop`,
`adventurers_rest_loop`, `pallass_depth_gates_check`, `thicket_keeps_talk`,
`flood_ledger_talk`, `floodplains_price_help`), `thicket_keeps_fight`,
`witch_cottage_reachability`, plus six throwaway capture scripts (witch-hut
door phase ladder, nobility deep-pool reads, a line-panel A/B) that were
DELETED after capture — their PNGs live under the same evidence root
(`_vlog_hutdoor_{day,dusk,night}/`, `_vlog_nobility_{rest,stationer}/`,
`_vlog_line_timing/`, `_vlog_line_control/`). Every run green, zero
`SCRIPT ERROR`. Ranked player-visible first.

- [ ] **UI/AMBIENT-LINE-INVISIBLE-AFTER-LOAD (P2, NEW, cross-region, and it
  corrects the #305 `talk_pool` row below).** An NPC `talk_pool` line served
  within roughly the first 1.5 s after `world_ready` renders **nothing at
  all** — no panel, no text — while `ui_dialogue_rendered` fires carrying the
  full composed string. This is NOT the readout overdraw the #305 pass logged:
  the line panel's rect (`message_layer.gd:443`, x 36–736, y 461–556 at
  1280×720) is EMPTY MAP in the failing frames, including the quarter of it
  the readout never covers. Proven as a same-NPC, same-room, same-seed A/B:
  `_vlog_line_timing/01_interact_at_world_ready.png` (nothing) vs
  `_vlog_line_timing/02_interact_90_frames_later_no_move.png` (the same
  Scribe line renders perfectly), the only delta being 90 idle frames — no
  move, no state change. Reproduced on three separate maps and three
  timings (`_vlog_nobility_rest/01_…_expanded_readout.png`,
  `_vlog_nobility_stationer/01_…_expanded_readout.png`,
  `_vlog_line_control/01_hunter_pool_line_expanded.png` on the pre-v0.16
  `riverfarm_village` — so this is GLOBAL and PRE-EXISTING, not a v0.16
  regression). Player reach: any NPC standing adjacent to the cell you load
  or arrive on. **Verification-boundary lesson, which is the bigger half:**
  `ui_dialogue_rendered` is NOT proof a player saw the line, and every QA
  script that interacts immediately after its fixture loads has been
  screenshotting an empty line slot without anyone noticing.
- [ ] **TOAST/PAYOFF-QUEUED-BEHIND-AUTOSAVE (P2, NEW).** On `handoff_quiet`
  the beat emits three toasts in this order — `Autosaved. (Esc — save/load
  anytime)`, `Quest updated: …`, and only THEN the authored payoff prose
  ("The coat is already over the chair back. You lay yours beside it, take
  the wrong one on the way past, and nobody in this room has raised a voice
  or an eye."). The shot named for that payoff shows the housekeeping toast
  instead: `invrisil_hat_quiet/03_the_wrong_coat_on_the_way_out.png` renders
  "Autosaved." and nothing else, with the good line still queued
  (`qa_output/invrisil_hat_quiet/events.jsonl` t=3511/3514/3514 — only
  `Autosaved.` ever reached `ui_toast_rendered`). Since `PLAYER_MOVED`
  dismisses the current toast early, a player who walks on never reads the
  line the route exists to deliver. Fix direction: autosave/quest-updated
  toasts should yield to authored prose in the queue, or the save toast
  should not occupy the strip at all.
- [ ] **UI/READOUT-EATS-THE-NEW-INTERIORS (P3, NEW; supersedes the #305
  "overdrawn by the expanded field-hotbar readout" row below).** The
  field-skill readout ships EXPANDED until the first sleep
  (`field_hotbar.gd:220-222` only auto-collapses once `times_slept > 0`),
  and expanded it covers y≈480–600 across x 285–1000. In the seven new
  interiors — all of them 8–9 rows tall — that is the room's bottom two
  rows: `adventurers_rest_loop/02_the_common_hall.png` has the PC himself
  half-buried under the panel; `flood_ledger_talk/01_mill_interior_arrival.png`
  and `thicket_keeps_talk/01_witch_hut_interior.png` both hide the exit door.
  It also gets WORSE with skill count, and toasts land on top of it: in
  `thicket_keeps_skill/01_ward_scrap_lore_toast.png` the readout is four
  entries / five lines and the [Detect Magic] toast slices lines 3 and 4
  mid-word ("…breaks if you d", "You have learned h"). Every QA fixture ships
  `times_slept` unset, so every windowed shot in this log is taken in the
  expanded configuration.
- [x] **MAP/OLD-HUT-HAS-NO-HUT (P3) — DRAINED 2026-08-02 (PR #344).** codex_hut (Codex→PixelLab-pro hero art) wired at witch_hollow (1,7); controller windowed read: golden-thatch hut clearly its own building beside the cottage. Original row: The y-sort fix works (see the
  confirmations below), and now that the door is visible the next question
  lands: `witch_hut_door` (`witch_hollow` 1,7, display name "The Old Hut")
  renders as a **freestanding door frame standing in the treeline** at the
  west corner of Eloise's cottage, with a tree trunk behind it and no
  structure attached — while the cottage sprite two cells east carries a
  large arched entrance that is pure decor and does nothing on interact
  (`_vlog_hutdoor_day/02_hollow_wide.png`). A first-time player reads the
  arch as the way in and the lone frame as scenery or a portal. Cheapest
  fixes: a hut/lean-to sprite behind the door, or move the door onto a
  visible wall face.
- [x] **SPRITE/CAMP-WATCH-GOBLIN-INVISIBLE (P3) — DRAINED 2026-08-02 (v0.17 L4).** Value-axis tint [0.66,0.62,0.58] on the map row, no hue nudge: measured goblin_base mean luma ~78 against the camp grass tile's ~114, and the drop takes it to ~50. `goblin_spear_ally` is a COMBATANT tint and stays open (L2 owns combat data). Original row: `camp_watch_goblin`
  (`rags_camp` 2,6, `goblin_base`) is a small green-tinted goblin on the
  camp's bright green field and is genuinely unfindable at 1×
  (`floodplains_price_help/02_rags_camp_rack_hung.png` — the tangle at
  screen ≈(415,470); at 4× it resolves into a goblin, at 1× it reads as
  grass litter). Same root as the already-logged "`goblin_spear_ally` is the
  least legible unit on the board": the `goblin_base` green sits on top of
  green everywhere the goblins actually live. One value-axis re-tint (darker,
  not a hue nudge) would fix both at once.
- [x] **DECOR/REST-RUG-READS-AS-HOLE (P4) — DRAINED 2026-08-02 (v0.17 L4), together with DECOR/DEN-SHOP-RUG-READS-AS-HOLE below: ONE root, five sites.** The free-pack rug regions carry no border and no pattern, so any tint below the floor value reads as a gap in the boards. `rug_green`/`rug_tan` now point at owned PixelLab weaves with fringed borders (distinct artwork per id, not one sheet retinted) and all five crushing tints go near-identity. **First fix was WRONG and was itself a hole:** the cream weave shipped with its whole field keyed to alpha 0 (1405 of 3038 pixels inside the bbox transparent), so the rug still read as a gap in the boards with a border floating over it — worse, because the near-identity tints un-darkened the surviving border. Corrected in the v0.17 fix wave with a SOLID weave off the same paid generation (PixelLab object 485f2824), field holes 46.2% -> 4.7% (fringe only). Sixth site named for completeness: data/maps/liscor/guild.json:169. Evidence: qa_output/adventurers_rest_loop/02_the_common_hall.png, qa_output/pallass_ledger_offices/03_den_shop_arrival.png, qa_output/stationer_room_loop/01_the_stationers.png. Original row: (second instance of the
  den-shop row below).** `rug_green` at `adventurers_rest` (6,5) ships with
  `tint [0.42, 0.35, 0.3]`, which darkens it BELOW the floor value and kills
  what pattern the sprite had: it renders as a flat dark-olive square in the
  middle of the common hall and reads as a hole in the boards
  (`adventurers_rest_loop/02_the_common_hall.png`, `…/04_the_room_at_night.png`,
  `invrisil_hat_quiet/01_a_table_nobody_has_claimed.png`). The den shop's
  `rug_tan` has the same failure at the opposite end of the value scale
  (`pallass_ledger_carry/04_den_keeper_carried.png`) — a rug wants a border
  or a pattern, not a tint.
- [x] **PROP/WAX-TRAY-IS-A-CRATE (P4) — DRAINED 2026-08-02 (v0.17 L4), art corrected in the fix wave.** New owned `wax_seal_tray` sprite. The first sheet had the tray's backing board keyed to alpha 0, so the stationer floor showed between the wax sticks and the prop read as an open rack of spines beside `library_shelf`; replaced with a solid-floored tray off the same generation (PixelLab object 9eb62de9), holes 23.5% -> 0.2%. Evidence qa_output/stationer_room_loop/01_the_stationers.png. The other three CRATE-READS-AS-CLUTTER members stay open. Original row: `stationer_wax_tray` (10,5) is
  "Nine colours of wax and one blank seal for hire" and draws as the `crate`
  sprite — a thin dark sliver against the stationer's floor
  (`stationer_room_loop/01_the_stationers.png`, screen ≈(955,425)). Third
  member of the already-open PROP/CRATE-READS-AS-CLUTTER family (den-shop
  receiving dock, lift cargo pallet, forge reject bin); the shop's most
  characterful prop is its least legible one.
- [ ] **PROP/HUT-HERB-BUNDLE-OVER-THE-PC (P4, NEW).** The hanging herb bundle
  on `witch_hut` y-sorts above the player and completely covers the PC's head
  when he stands on the cell below it
  (`thicket_keeps_skill/01_ward_scrap_lore_toast.png`, screen ≈(800,230)).
  Defensible for a ceiling-hung prop, but it is the room's only tall sprite
  and it eats the player's silhouette; a small `field_y_sort_bias_px` would
  settle it either way.
- [x] **DECOR/FORGE-MOLTEN-SEAM-HARD-RECT (P4) — DRAINED 2026-08-02 (v0.17 L4).** Two `steam_vent` decor rows on the free cells flanking the band break the rectangle's ends, and the east one carries the seam's only warm flickering light so the glow reaches the floor. Seam cells untouched (still blocked + cover_skip); map light count 6 -> 7. Evidence qa_output/pallass_depth_gates_check/01_attendant_hub_three_rows.png. Original row:
  `pallass_forge`'s molten seam band renders as a perfectly rectangular flat
  orange block on the slate with no edge treatment and no light bleed onto
  the surrounding floor (`pallass_depth_gates_check/01_attendant_hub_three_rows.png`,
  screen x 450–770 / y 330–390). Same read as the closed ART/WATER
  hard-edged-rectangle entry — the tile is doing its job, the boundary is
  not.

**Existing rows RE-CONFIRMED still open by this pass** (evidence refreshed,
nothing changed): `line_stalker_a`/`_b` still merge into one two-headed
creature on `witch_hollow` — and the new shot adds that the north stalker's
HP BAR is occluded too, so the pair shows two `44/44` numerals over a single
visible bar (`thicket_keeps_fight/01_line_stalkers_board.png`); the three
`plains_scavenger_*` still read as one mass, separable only by their HP
numbers, and `goblin_spear_ally` is still the hardest unit on the board to
find (`floodplains_price_fight/02_camp_ground_press_board.png`); the
`forge_hall` board's `crate` cover still reads as small dark posts rather
than crates (`pallass_standards_fight/04_forge_hall_board_mid_combat.png`);
`forge_hall_temper_bench` is still one of three identical forge sprites in a
row (`pallass_depth_gates_check/03_temper_bench_locked.png`); the den shop's
`crystal_lamp` is still a municipal street lamp indoors and `rug_tan` still a
pale hole (`pallass_ledger_carry/04_den_keeper_carried.png`); the two
Invrisil facade doors are still lost in a band of identical windows
(`adventurers_rest_loop/01_two_doors_on_one_facade.png`,
`stationer_room_loop/04_back_on_the_boulevard.png`); `hearth` is still a cold
unlit oven (`adventurers_rest_loop/03_the_hearth.png`); Krshia's hub still
shows six rows over ~45% of the window with the last option ~26 px above the
fold (`floodplains_price_talk/01_krshia_hub_goblin_run.png`); and the
ally-announce still renders "Rags and **A** Goblin with a Spear wade in
beside you." with the raw display name mid-sentence
(`floodplains_price_fight/02_camp_ground_press_board.png`). The
`mercantile_alley` night row is WIDENED by this pass: it is not only the
arena — the `mercantile_alleys` OVERWORLD at night is near-black, with the
PC findable only because Hedault's shopfront lights him
(`invrisil_setting_talk/03_he_will_not_cut_a_mount_around_a_lie.png`).

**Read and found CLEAN — do not re-litigate:**
- **The `witch_hut_door` y-sort fix HOLDS at all three phases.** Shot from
  the (1,8) approach and from a clear cell at day / dusk / night
  (`_vlog_hutdoor_{day,dusk,night}/01_hut_door_from_approach.png` and
  `…/02_hollow_wide.png`): the door draws IN FRONT of `hollow_tree_7`'s trunk
  in every frame, the PC on the approach cell is never swallowed by canopy,
  and the warmed timber tint keeps the door separable from the treeline even
  at night. `witch_cottage_reachability` re-ran green windowed.
- **`witch_hollow`'s three-phase mood ladder is genuinely distinct** (bright
  green shade → deep green dusk → near-black night) and Eloise's own rig
  swaps to her hooded night presentation — the hollow reads different at each
  phase without any of them going flat.
- **The nobility layer renders and reads.** The Lady's pale gold silhouette
  separates instantly from the drab PC and the slate-tinted clerk
  (`invrisil_setting_talk/01_a_lady_with_a_ring_box.png`), her title is
  spoiler-safe, and her long nodes wrap without clipping. The two deep-pool
  nobility lines both render once the load-timing bug above is out of the way:
  "The Reinhart carriage went up the boulevard twice last month…"
  (`_vlog_nobility_rest/02_…_readout_collapsed.png` — via the Factor's
  conversation node) and "House paper is a third of the trade and all of the
  discretion. A crest on the envelope changes what the words inside are
  allowed to mean." (`_vlog_nobility_stationer/02_…_readout_collapsed.png`).
  NOTE for the content owner: both sit at pool indices 2 and 3, and a pool
  advances ONE line per waking, so the house/Reinhart texture is three and
  four wakings deep at the Rest and the stationer respectively.
- **`pallass_standards_fight` closes the v0.15 forge-hall debt cleanly.** The
  arrival frame reads warm-forge-against-slate with no flat white
  (`pallass_standards_fight/01_forge_hall_arrival.png`), the parley panel is
  clean, and mid-combat both combatants' bars and numerals (48/48 green,
  70/70 orange) are unambiguous on the slate board.
- **Ally-vs-enemy separation on the first goblin-ally fight is GOOD.** Green
  vs orange HP bars carry it at a glance and the turn banner names all six in
  initiative order; the legibility problem is scavenger-vs-scavenger and the
  green goblin, never ally-vs-enemy.
- **The den-shop keeper fix took.** She stands in the counter row and the
  route now walks the customer approach — bump her from (4,3) and the release
  node opens face to face (`pallass_ledger_carry/04_den_keeper_carried.png`).
- **The #308 rack fix took.** Bare poles become a hung rack in place and the
  meat reads as meat at 1× (`floodplains_price_help/01_rags_camp_arrival.png`
  → `…/02_rags_camp_rack_hung.png`).
- **All seven new interiors are dressed, not empty**, and every observe/toast
  in this pass rendered complete with no fold clipping — the copy is the
  strongest thing in the wave and it survives rendering everywhere except the
  two queue/timing bugs at the top of this section.

### v0.16 #305 Riverfarm depth — windowed pass (2026-07-28)

Shots: `qa_output/_vlog_{day,dusk,night,post}/` (temporary capture scripts,
deleted after reading) and the six new canonicals' own windowed runs
(`flood_ledger_{talk,help,fight}`, `thicket_keeps_{talk,skill,fight}`).

- [x] **FIXED (fix wave, uncommitted at time of writing → see the fix-wave
  commit on `issue/305-riverfarm-depth`) — BLOCKER-CLASS `witch_hut_door`
  (witch_hollow 1,7) was INVISIBLE to a player.** `hollow_tree_8`
  (`hollow_canopy_tree`, cell (0,9)) y-sorted ABOVE the door (144 > 112) and
  its canopy covers rows 5-9 at x 0-2, so both the door AND the PC standing on
  the approach cell (1,8) were swallowed by dark canopy
  (`_vlog_day/17_hut_door_from_approach_day.png`).
  **Tint was measured NOT to be the lever** — the frame was visually unchanged
  at `[2.4, 2.4, 2.4]`, because the cause was occlusion, not contrast.
  **The lever was Y-SORT.** None of the three logged candidates was taken:
  (a) fails on geometry (the canopy is 5.1 cells tall drawn UP from a bottom
  anchor, so every column-0 base cell from y 9 to y 12 still covers the
  approach row, and moving south only raises the sort key); (b) is c-lane art;
  (c) helps at dusk/night only. Applied instead: the shipped, sort-only
  `field_y_sort_bias_px` key (`inn_roof`/`rug_green` mechanism; entity-level
  override precedent `inn_upstairs.json:235`, `street.json:1295`) at **-80.0**
  on `hollow_tree_6`/`_7`/`_8`, one cell clear of each canopy's own top edge.
  Pixels do not move. The door, the PC on (1,8), `hollow_offering_pot` (2,7)
  and `thicket_line_den` (2,2) now render IN FRONT; tree stacking survives
  (-32 < 16 < 64). The door's tint was then warmed to sunlit timber
  (`[1.18,1.02,0.78]`, inside `pallass_forge`'s shipped 1.18 precedent) — the
  plan's named lever, applied second, once occlusion stopped masking it.
  Re-shot windowed: the door reads as a standalone framed doorway at the
  hollow's west edge with the tree trunk drawn behind it, and the PC stands
  clear on the approach cell. Ruling 3 held — the door cell is untouched and
  `witch_cottage_reachability` re-ran green at seed 9.
- [ ] Same class, NOT fixed here (no interactive entity reported invisible, so
  out of the fix wave's scope): the SOUTH treeline `hollow_tree_3`/`_4`/`_5`
  ((2,13)/(5,13)/(8,13)) canopies cover rows 9-13 across x 1-10 and still
  y-sort above everything under them, including `briar_collectors_deep` (4,11)
  and `hollow_true_knot` (8,10). Same one-key fix if a later pass wants it.
- [ ] `line_stalker_a`/`_b` OVERLAP each other on the `witch_hollow` arena
  (`thicket_keeps_fight/01_line_stalkers_board.png`): the mothbear rig is
  taller than one cell, so the north stalker's body covers the south one's
  head and the pair reads as one two-headed creature until you find the two
  `44/44` labels. Contrast against the green field is FINE (brown body, grey
  wings). Same class as the FoTI Grimalkin crowding note — a spawn-cell
  choice, not a tint one.
- [ ] `granary_scavenger_a`/`_b` on `inn_cellar` have the same vertical
  overlap, milder (the `bat` rig is compact)
  (`flood_ledger_fight/01_granary_scavengers_board.png`). Their warm rust
  tint separates them from the grey-brown cellar stone cleanly; this pair
  reads well and only the stacking is worth revisiting.
- [ ] **NPC `talk_pool` line panel is overdrawn by the expanded field-hotbar
  readout** (`_vlog_post/32_hunter_post_quest_pool_line.png`): the line panel
  spans x 40-725 and the readout x 285-1000, and the readout wins, so about
  three quarters of "The Hunter: Herd's wintering at the north bend..." is
  covered. PRE-EXISTING and GLOBAL (the readout ships expanded by default and
  its width grows with the number of known field skills — a mid-game PC hides
  more of the line than an early one); surfaced here because v0.16 adds three
  reactive `talk_pool_stages` whose whole point is that line. Layering fix:
  line panel above the hotbar readout, or shrink/anchor the readout clear of
  the bottom-left line slot. Same family as the combat-HP-label-through-pause
  entry below.
  **PARTLY SUPERSEDED (v0.16 milestone-close pass, 2026-07-28):** the
  occlusion half is real and is now tracked as UI/READOUT-EATS-THE-NEW-
  INTERIORS at the top of this file, but the "line is three quarters
  covered" diagnosis is incomplete — a line served within ~1.5 s of
  `world_ready` renders NOTHING AT ALL, readout or no readout, in the
  quarter of the slot the readout never touches. See
  UI/AMBIENT-LINE-INVISIBLE-AFTER-LOAD for the A/B proof; fix that first,
  then re-measure this one.
- Confirmed GOOD, no action: both new mood rows LANDED — `riverfarm_mill`
  and `witch_hut` each render three visibly distinct phase grades and neither
  is identity white (`sheet_mill_phases`, `sheet_hut_phases`). The village
  mill door reads clearly as an enterable framed door at the windmill's stone
  foot from the WEST approach (18,5) (`_vlog_day/11_mill_door_west_day.png`);
  from the south approach (19,6) the PC's own sprite covers it, which is true
  of every door directly north of its approach. Ruling 6c holds on both
  doors: exactly ONE windmill and exactly ONE cottage on screen, no
  double-rendered building. `hut_ward_scrap`'s five-line [Detect Magic] lore
  toast renders complete with no fold clipping, and the tallyman's
  `tally_walk` node wraps to two lines well inside the panel.
- Watch, not a defect: `witch_hut` carries no light source of any kind, so at
  night the room is near-black except the ward scrap's own glow
  (`_vlog_night/15_hut_interior_night.png`). Deliberate for a shuttered
  abandoned hut, and the four observables are still findable by bumping, but
  if a later pass wants the room readable at night the fix is one `light`
  block on `hut_hearth_ash`, not a mood-row lift.
### v0.16 Pallass depth (#307) — windowed pass, 2026-07-28

Eight windowed runs at seed 9 (`pallass_standards_fight` / `_talk` /
`_skill`, `pallass_ledger_offices` / `_carry` / `_skill`,
`pallass_depth_gates_check`), every PNG read. Nothing here is a gate
failure — all seven canonicals are green and the full sweep is green.
Ranked player-visible first.

- [x] MAP/DEN-KEEPER-UNREACHABLE-FROM-COUNTER (P2, v0.16 #307 windowed
  pass) — **FIXED in the #307 fix wave**, adversarial-review finding. She
  now stands **at (4,2)**, IN the counter row between its two solid ends
  (3,2)/(5,2), which is the shipped Erin (7,2) / Selys (8,2) shape exactly:
  `counter_mid` decor at (4,2) removed, (4,2) dropped from `blocked` (the
  entity blocks on its own), and a top-level `_comment` on the map records
  why the cell must stay open to decor and closed to nothing else. The
  customer-side cell (4,3) is now the service point — walk straight up the
  shop floor and bump her. `pallass_ledger_offices` and
  `pallass_ledger_carry` were re-routed to the customer approach (up 3 from
  (4,6), bump (4,2)) so the gate now walks the route a player walks; the
  six-step trip round the counter's west end is gone from both. Original
  report follows.
  `den_shop_keeper` stood at (4,1) on `pallass_den_shop` behind
  a counter that occupies (3,2)/(4,2)/(5,2) as solid `blocked` cells, and
  `interact` resolves exactly ONE cell (`entity_at(player_cell +
  player_facing)`, `wi_game.gd:400`). A player who walks up to the counter
  face at (4,3) and presses interact therefore gets nothing at all — no
  toast, no refusal, no feedback. Her only approach is round the counter's
  west end (column 3 up to y=3, across to column 2, up to y=1, then (3,1)),
  which puts the player *behind* her serving counter; see
  `qa_output/pallass_ledger_offices/04_den_keeper_released.png`, where the
  PC stands shoulder to shoulder with her on the shop's own side. Every
  shipped NPC checked (Erin (7,2), Selys (8,2), Lyonette, Krshia…) has its
  CUSTOMER-side cell open. She is P2's terminal for two of three routes,
  so the failure mode is "I found the shop and could not hand anything
  over". Both P2 canonicals walk the real approach, so the quest is
  provably completable — this is an ergonomics defect, not a softlock.
  Fix candidates, cheapest first: open (4,2) as a serving gap in `blocked`
  (keeps the counter decor, gives a face-to-face cell); or move her to
  (5,1) and shorten the counter; or move the counter to y=3 and leave her
  at (4,2). Deliberately NOT changed inside the implementing lane: the
  cells were hand-audited when the room was authored, and moving them
  invalidates that audit, the `moods.json` row and the dynamism read.
- [x] PROP/TEMPER-BENCH-INDISTINGUISHABLE (P3) — DRAINED 2026-08-02 (v0.17 L4). New owned `temper_bench` sprite: a legged timber bench with a vise and a gauge, which is a distinct SILHOUETTE against the two dark stone forges beside it. The row's own "or a `tint`" suggestion is SUPERSEDED by the 2026-08-02 tint-is-not-disambiguation directive — a retint would have satisfied the checklist and not the player. Evidence qa_output/pallass_depth_gates_check/03_temper_bench_locked.png. Original row: —
  `forge_hall_temper_bench` (4,3) is P1's entire SKILL route and it uses
  the `forge_station` sprite, which `pallass_forge_hall`'s decor also
  places at (2,2) and (3,2) immediately beside it. In
  `qa_output/pallass_standards_skill/01_temper_bench_skill_toast.png` the
  three read as one bank of forges: nothing marks which one the quest
  means. The room's own copy calls it "a billet clamped mid-process, the
  quench beside it, a gauge nobody has reset" — none of that is on screen.
  Cheapest fix: give the bench a distinct sprite (or a `tint`) so the
  interactive one is the odd one out, the way `forge_temper_golem` already
  separates itself from `forge_calibration_golem` with an ember tint.
- [ ] PROP/CRATE-READS-AS-CLUTTER (P4, v0.16 #307 windowed pass) — the
  `crate` sprite carries three lane props whose copy describes something
  much more specific than it draws: `den_shop_receiving_dock` (8,5) is "a
  cleared square of floor with a chalk outline on it, the size of one
  crate" and renders as a small dark box with no outline
  (`pallass_ledger_carry/03_leg_three_receiving_dock.png`);
  `lift_cargo_pallet` (19,4) is "strapped and tagged, one hand's width
  outside the loading square"; `forge_reject_bin` (10,4) is a civic bin of
  tagged failures. All three read as generic background clutter at map
  scale, and the dock in particular is the HELP route's target. Same sprite
  is the board's cover in BOARD/CRATE-COVER-READ below. Not urgent; a
  chalk-outline floor decal or a distinct dock sprite would earn the copy.
- [ ] BOARD/CRATE-COVER-READ (P4, v0.16 #307 windowed pass) — carried out
  of the closed MAP/FORGE-TIER-FLAT item above. On the `forge_hall` board
  (`pallass_standards_fight/04_forge_hall_board_mid_combat.png`) the
  data-driven cover renders as one legible `forge_station` plus four small
  dark `crate` cells that read as low stools against the slate. They ARE
  drawn and they ARE distinguishable from floor on a careful look, which
  is what the v0.15 T5.1 fix promised — but a player reading the board for
  cover at a glance will find only the forge. Same root as
  PROP/CRATE-READS-AS-CLUTTER.
- [x] DECOR/DEN-SHOP-STREET-LAMP-INDOORS (P4) — DRAINED 2026-08-02 (v0.17 L4). New owned `shop_oil_lamp` (brass lamp on a small table). `crystal_lamp` could NOT simply be repointed: it is Pallass civic street furniture at ten outdoor sites across the market and forge tiers. The row's `light` block is untouched — only the fixture changed. Evidence qa_output/pallass_ledger_offices/03_den_shop_arrival.png. Original row: —
  `pallass_den_shop`'s `crystal_lamp` at (2,1) draws as a tall municipal
  street lamp on a post standing inside a family provisions den
  (`pallass_ledger_offices/03_den_shop_arrival.png`). Its warm light is
  doing the right job — the room's whole point is warm timber against the
  tier's slate, and that contrast lands — but the fixture itself is
  outdoor furniture. A hanging or counter-top lamp sprite would keep the
  light and lose the street.
- [x] DECOR/DEN-SHOP-RUG-READS-AS-HOLE (P4) — DRAINED 2026-08-02 (v0.17 L4), same fix as DECOR/REST-RUG-READS-AS-HOLE above. Original row: —
  `rug_tan` at (4,4) renders as a pale plus-shaped patch in the middle of
  the timber floor with no border or pattern; at a glance it reads as a
  gap in the boards rather than a rug (same shot as above). Low priority,
  but it is the room's visual centre.

**Read and found CLEAN** (recorded so a later pass does not re-litigate
them): the `forge_hall` interior's mood and embers ambience — warm forge
light against slate, no flat-white
(`pallass_standards_fight/01_forge_hall_arrival.png`); the
`forge_temper_golem` rig's ember `tint` at (8,6), clearly separated from
the shipped `forge_calibration_golem` a tier below
(`.../02_forge_temper_golem_on_map.png`); the parley panel's two-line body
and two options, no clipping (`.../03_calibration_rig_parley.png`); the
den shop's warm-vs-slate contrast, which is the entire reason the room
exists (`pallass_ledger_offices/03_den_shop_arrival.png`); the carry
route's third-leg toast, three lines, no overflow
(`pallass_ledger_carry/03_leg_three_receiving_dock.png`); the keeper's
release node and its quest-updated toast side by side, neither occluding
the other (`pallass_ledger_offices/04_den_keeper_released.png`); and both
3-row hubs with human eyes — nothing this lane added leaked into either
(`pallass_depth_gates_check/01_attendant_hub_three_rows.png`,
`.../02_smith_hub_three_rows.png`).

**On Grimalkin's new `text_variant` page split** (the `forge_runes`
orphan-page lesson the plan asked to re-read): the windowed shot
`pallass_standards_talk/02_grimalkin_standards_tempered_variant.png` shows
page 2 of 2, not page 1 — `dialogue_panel.gd:154` deliberately jumps a QA
run to the LAST page (`_page_idx = ... if _is_qa() else 0`), so a windowed
capture structurally cannot show page 1 and a human player always sees it
first. What the shot DOES answer is the question that matters: page 2 is
"Depth, then recovery, then the file. State your business." — 56
characters, two complete sentences, sitting cleanly above both options.
That is the opposite of the 12-character fragment `forge_runes` produced.
Page 1 (173 chars, ending at "Same measure as a squat.") is a real
sentence boundary and is pinned verbatim in `pallass_standards_talk`.


### ⭐ v0.15 Playtest-State bundle — SIX taste asks for the user (2026-07-28)

Every taste/FEEL call v0.15 accumulated, collected once so they can be
answered in a single sitting instead of six. **Review-after, never
block-before** — all six shipped; none is a defect claim. Each names the QA
fixture that already stands at the spot, so the state costs a copy, not a
navigation: cut it as `playtest_saves/2026-07-28-<name>.json` from that
fixture at tag time and hand the user the load line. Ordered by how much the
answer would change.

1. **The camouflage tints — do they read "magic-touched" or "recoloured"?**
   (P5 T5.1, the wave's biggest look call.) Three rosters got a real hue
   push because the subtle version demonstrably failed.
   *State* `2026-07-28-cellar-vermin` ← `door_chain_fight_start.json`; and
   `2026-07-28-briar-hollow` ← `riverfarm_fight_start.json`.
   *Do* fight both boards. *Judge* whether the creatures read as touched by
   what's leaking into the room, or as the same animal in three colours.
   **My close read, offered as input, not as the answer:** the vermin land —
   and one of them lands for a reason worth keeping, because the ember one is
   NAMED "Ember-Touched Vermin" in the turn banner
   (`door_chain_fight/00_rift_vermin_leak_board.png`), so the copy carries the
   hue. Its violet and cold-blue siblings are just "Rift Vermin A/B" and have
   no such cover. If the tints read as recolours anywhere, it will be there,
   and the cheap fix is a name, not a colour. The briar rust
   (`riverfarm_fight/01`) is the strongest push of the three: unmistakable
   against the green, but the collectors no longer read as *plants*.
2. **Does the Ruin Warden still land as a boss at 3.51 cells?** (P5 T5.2.)
   He fell from 7.62 — half the board's width — to a third of its height.
   *State* `2026-07-28-the-warden` ← `seal_open_start.json`. *Do* take the
   vault fight. *Judge* whether the drop cost him presence.
   Close read: `seal_open/06_the_warden.png` — still plainly the largest
   figure in the game, whole rig on the board, head clear of the turn banner.
   Reads as a boss to me; your eyes are the bar.
3. **Toast over an open journal — lively, or broken?** (P2 A3.) The
   information-losing TALL case is fixed (the queue now pauses while a modal
   is open). What remains is deliberate: a 1-line toast still draws over the
   journal's bottom-right corner, covering blank parchment and an ornament,
   zero text. *State* `2026-07-28-toast-over-journal` ←
   `climax_sealed_start.json`. *Do* open the journal and let a level-up or
   sleep toast land. *Judge* whether "the world kept moving" beats the
   ornament it hides. If it reads as broken, the lever is the toast's Y
   anchor, not the queue.
4. **`pallass_market` / `pallass_forge` lights by day.** (P5 T5.3.) The
   `lights_by_day` opt-out shipped and was applied to `seal_vault` only.
   These two are the same class — walled-city interiors whose day grades are
   near identity — but brightening them is a look call, not a defect fix, so
   they were deliberately NOT changed blind. *State* `2026-07-28-pallass-day`
   ← `near_pallass.json`. *Do* walk both tiers at day phase. *Judge* whether
   the crystal lamps should burn at noon. One data key per map if yes.
5. **Grimalkin in the inn.** (P5 T5.2 — REFUTED on measurement, nothing
   shipped.) He is 1.25x Relc, exactly as canon says; the logged "2.3x" was a
   frame-height error. What crowds the room is his 2.9-cell arms-out WIDTH,
   which no `render_scale` can change. *State* `2026-07-28-grimalkin-seated`
   ← `inn_guests_ext_start.json`. *Do* look at the (14,5) seat. *Judge* if he
   still FEELS too big — the lever is the seat or the art, never the scale.
   Close read: `inn_guests_ext_loop/05_wilovan_and_grimalkin_seated.png` — he
   buries nobody, though he is the most saturated figure in a warm-wood room.
6. **The finale's paced lines.** (Carried forward — structurally invisible to
   QA: `sleep_veil._is_qa()` skips the pacing, so no machine pass has ever
   seen them at speed.) *State* `2026-07-28-the-finale` ←
   `finale_merge_start.json`. *Do* sleep into the finale and watch it at real
   pace. *Judge* the RHYTHM only — the copy itself is measured and pinned by
   `test_copy_fit`. This is the one ask on this list no agent can answer.

### Machine playtest — v0.15 MILESTONE CLOSE: the full rotation (2026-07-28)

Source: `close/v015` at `ed24c4f` + this branch's record fixes, full asset
overlay in tree (654 PNGs, real art). Gates first: 30/30 unit suites green on
the three-check bar, `data_lint` clean, **full `ci_sweep.sh` 167/167 green
with zero grep hits**. Then the MILESTONE-CLOSE full rotation — **16 windowed
runs, every one `passed: true`**, read at native 1280x720:
`arc_flow`, `journal_history`, `board_loop`, `raskghar_entry_loop`,
`seal_fed`, `seal_open`, `door_awakening`, `status_first_encounter`,
`sewers_walkthrough`, `door_chain_fight`, `riverfarm_fight`,
`pallass_walkthrough`, `invrisil_walkthrough`, `horns_dig_flow`,
`inn_guests_ext_loop`, `inn_guests_full_loop`. Evidence collected under
`wandering_inn_game/qa_output/machine_playtest_2026-07-28_v015_close/`
(16 MB, 130 shots) — **and that path is GITIGNORED**, so it survives only in
this tree. Naming that rather than calling it "durable", because citing
gitignored evidence paths is itself a carried follow-up item (see HANDOFF):
every claim below is reproducible instead — each names its script, its seed
and its shot, and re-running that script windowed regenerates the frame.

**Commit key for every "FIXED v0.15 …" entry in this file.** The phase
reports cite BRANCH commits (`04b3e94`, `50cbf6b`, `3d49494`, `c9c6a37`,
`227292d`, `fef30e6`, …) and all five phases landed as SQUASH merges, so not
one of those hashes is an ancestor of `main` — they resolve only in a tree
that still has the wave branches. Cite these instead:
`a085cfb` P1 delivery (#310) · `63a431b` P2 viewports (#311) ·
`4a95a9c` P3 guest windows + hygiene (#312) · `60f1887` P4 population (#313) ·
`ed24c4f` P5 readability/rigs/lights (#314).

**`sewers_walkthrough` ran WINDOWED green** — the designated dark-map row of
the rotation was red windowed for the whole of Phase 1; P1's `from_start`
re-gate holds under real frame pacing. The rotation has no unrunnable row.

**Every v0.15 visual claim re-verified on my own shots, not on the phase
reports' word** (details in each entry below): warden rig whole and clear of
the banner (`seal_open/06`), bats readable as winged bodies
(`sewers_walkthrough/01`), three countable vermin (`door_chain_fight/00`),
rust-on-green collectors and two separable collector families
(`riverfarm_fight/01`,`02`), three separate silhouettes at the climax
(`arc_flow/dd_06`), forge wall/floor distinct with props reading as props
(`pallass_walkthrough/08`), the vault lit at day (`seal_open/08`), Grimalkin
burying nobody (`inn_guests_ext_loop/05`), the Lore tab newest-first with no
toast over it (`seal_fed/04b`), the combat feed at four full rows with the
wrapped "for 13!" whole (`riverfarm_fight/02`), and Act IV's beats all in
opening voice (`arc_flow/07`).

- [ ] HUD/LEGEND-OVERLAP (P2, NEW — the headline finding, and it LOSES COPY) —
  **the field-skill legend panel draws over the flavor/observe toast and eats
  the middle of the line.** Both live in the same bottom band; the legend
  (x 283–1000) is opaque and wins. `invrisil_walkthrough/01_extras_density.png`
  is the proof: the payload line in `events.jsonl` is *"A woman in a rose-dyed
  cloak checks a folded slip of paper against a shopfront number, unimpressed
  by both."*, and what a player actually reads is **"A woman in a rose-dyed
  cloak ch"** … **"unimpressed by both."** Fifty-two characters — the entire
  setup — sit behind an opaque panel; the punchline survives with nothing to
  land on. This is the MACHINE-PLAYTEST protocol's own named failure class
  (payload vs render) and the only NEW defect this rotation found that
  destroys authored content. **It worsens with progression**: the legend grows
  a row per field skill (one row on `pallass_walkthrough/08`, three here), so
  the overlap band deepens as the player levels. Distinct from UI/FIELD-READOUT
  (#115), which is about accumulation/clutter — this is text LOSS. The two
  share a cause and should probably share a fix: the legend needs to be either
  collapsible, bottom-anchored below the toast band, or mutually exclusive with
  a live toast.
- [ ] BOARD/STACKED-HP-BARS (P3, NEW — partly CAUSED by this wave) — a
  combatant standing one cell above another has its **HP bar** hidden behind
  the lower figure's sprite, and a combatant on the board's lower rows has its
  bar hidden behind the combat feed panel. The NUMERALS stay readable in every
  case, so nobody is blind — but the bar is the at-a-glance signal and it is
  the half that vanishes. Four instances in one rotation, which is what makes
  it systemic rather than a staging accident:
  `arc_flow/dd_06_boss_fight.png` (the scout P5 moved to (10,6) — its bar is
  behind the feed panel, so the restaging that fixed the silhouette overlap
  bought a bar occlusion), `sewers_walkthrough/01_vermin_encounter.png` (upper
  bat), `riverfarm_fight/01_briar_collectors_with_hunter.png` (upper
  collector), `status_first_encounter/01_first_encounter_feed.png` (upper
  dummy). **v0.15 made this more likely, honestly stated:** every figure the
  wave scaled UP (bats 0.38→1.26, wards, guardians) occludes more of the row
  above it than it used to. Candidate: draw the bar strip above the numerals
  at the cell's top edge, or give bars their own z-layer above combatants.
- [ ] HUD/HINT-BAR-BLEED (P4, NEW, pre-existing but never logged) — the
  bottom-left "Esc — menu (save/load)  J — journal  I — inventory" panel is
  positioned so its **left parchment ornament renders off-screen at x < 0**
  and "Esc" starts ~4px from the window edge, while the right end keeps its
  full ornament and padding. Visibly asymmetric in every field and journal
  shot (`seal_open/08_the_vault.png`, `arc_flow/07_journal_lead_survey.png`).
  It is also the thing every other bottom panel overdraws — the dialogue panel
  clips it at `horns_dig_flow/01_camp_hub.png`. Cosmetic; a margin fix.
- [ ] BOARD/TINT-NUMERAL-CONTRAST (P3, NEW, a cost of the T5.1 tints) — HP
  numerals draw ON the combatant's tinted body, so the DARK tints cost
  contrast the warm ones don't: on `door_chain_fight/00_rift_vermin_leak_board.png`
  the ember vermin's "34/34" reads cleanly against its red, while the violet
  and cold-blue siblings' numerals sit dark-on-dark and have to be hunted for.
  The tint fix is still plainly worth it (the roster went from uncountable to
  countable); this is the invoice, not a reason to revert. Candidate: the
  numeral's own outline/shadow should key off the resting modulate's luminance.
- [ ] MAP/FORGE-MOLTEN-BLOCK (P4, NEW, common-sense fidelity pass) — on
  `pallass_walkthrough/08_grimalkin_station_forge_tier.png` the molten trough
  is the **largest single object on the map and the least detailed**: a
  near-uniform saturated orange rectangle (~320x70px) beside forge stations,
  anvils and ember particles that are all pixel-detailed. It out-shouts every
  actual interactable on the tier. The T5.1 floor fix around it landed; this is
  the one element that did not come with it. Wants a real molten-metal
  treatment (banding, glow falloff, a lip) at the fidelity of its neighbours.
- NOTE, NOT A FINDING — the windowed ObjectDB-leak notice is **reproducible,
  contrary to the older TRANSIENT entry below**: it fired on 2 of 16 runs here
  (`journal_history`, `board_loop`), always AFTER `QA_RESULT: PASS`, never
  headless (the 167-script sweep was clean). That matches HANDOFF's
  windowed-exit flake note (~1/3 of runs, audio teardown race, results
  unaffected). Correcting the record: it is a known flake with a rate, not an
  unreproducible one-off. Do not re-diagnose.

### Machine playtest — wave/v015-p1-delivery, PHASE-1 CLOSE: the delivery layer (2026-07-28)

Source: `wave/v015-p1-delivery` at `70c002f` + this task's fixes, full asset
overlay in tree (654 PNGs, real art), 30/30 unit suites + the 166-script sweep
green first. Seven windowed runs read at native 1280x720 (`arc_flow`,
`seal_fed`, `door_awakening`, `raskghar_entry_loop`, `journal_history`,
`board_loop`, `sewers_walkthrough`). Targets: all five act pages, the Leads
strip at the mainline seams, the Lore tab, and the toast-over-journal FEEL
call the implementer flagged at T1.3.

**What reads correctly** (no entry needed, recorded so the next pass doesn't
re-litigate): all five act pages render their pending beats as authored
openings — Act I `journal_history/01`, Act II `board_loop/03b`, Act III
`raskghar_entry_loop/00`, Act IV `arc_flow/05`+`07`, Act V `seal_fed/01`.
18/18 beats carry an `opening`, so `WIActs.render_beats`' drop-arm never
fires in shipped content, and no opening states an outcome. Every one reads
forward ("Krshia's counter sees everything. Earn a look behind it."), not as
a summary. The Leads strip does its job at the seam: `door_awakening/00`
shows "Quests — No quests in progress." carrying **two** leads plus five
pending openings above it, where the pre-phase page was a dead end. The Lore
tab is newest-first and reads as a record worth keeping (`seal_fed/04b` — the
later Pisces line sits above the earlier one, full authored prose, not
truncated).

- [x] TOAST/MODAL-OVERLAP (P2, pre-existing layer order, MADE MORE FREQUENT by
  the v0.15 lossless queue) — **the FEEL call, answered both ways.** Toasts
  draw at layer 12 over the journal's 10 (deliberate, `message_layer.gd`).
  In the COMMON case this reads as *lively*, not broken: a 1-line toast
  (96px) occupies x 808–1256 / y 590–686 and the journal is 640x560 centred
  (x 320–960 / y 80–640), so the overlap is a 152x50 corner that covers only
  blank parchment margin and the panel's bottom-right ornament — zero text,
  zero controls, the scroll hint (`▼`, centred at x 640) and the scrollbar
  (x≈945) both clear. `arc_flow/07` ("[Diplomat Level 2]" arriving over an
  open journal) and `door_awakening/00` ("You sleep soundly.") are the
  evidence, and in both the world-kept-moving signal is worth more than the
  ornament it hides. The TALL case is a real defect: a 3-line toast is 122px
  (`_toast_panel_height_for`: `3*pitch - spacing + 2*TOAST_FOLD_DANGER_PX`),
  topping out at y≈564, which reaches the journal's last body rows — on the
  History tab `seal_fed/04b` clips Recent Messages mid-word ("…cut the inn's
  frame too. Find ou|") and truncates the line below it. Any journal row
  extending past x≈808 in the y 564–640 band is exposed; the Leads rows are
  the longest lines the panel draws (`door_awakening/00`'s Guild lead ends at
  x≈910), so this worsens as leads accumulate. Cosmetic in the 1-line case,
  information-losing in the 3-line case. Implementer's proposed fix stands and
  is now measured: pause the drain while a modal is open, never re-drop.
  **FIXED v0.15 Task 2.1** (`message_layer.gd`): `_drain_toasts` breaks on a
  non-empty `_open_modals` set (journal/inventory/pause/settings, keyed by their
  own SHOWN event) and the matching HIDDEN event kicks the drain again. The
  QUEUE pauses, never drops — the lossless-queue contract is untouched, so every
  pending toast lands the instant the panel closes. **Precise about the
  in-flight one:** a toast already ON SCREEN when the modal opens is still CUT,
  because opening routes through `_defer_toast_display()`, which shortens the
  current hold and hides the panel. That is pre-existing semantics, shared
  verbatim with dialogue open, map change and combat start, and it is what keeps
  the overlap from being visible for the first few frames; it is NOT new here and
  it is not lossless — the cut toast has already rendered, so it is spent, and
  only its remaining reading time is lost. Fixing the cut is a separate call
  about `sticky` re-queueing, deliberately out of scope (see the A3 entry's own
  rejected alternative). Windowed re-shot: `seal_fed/04b_journal_lore` now
  carries NO toast over the panel and Recent Messages reads to the end ("…cut
  the inn's frame too. Find out what the seal is FOR, there at the door in the
  halls."), where it previously clipped mid-word at "Find ou|".
- [x] QA/SEWERS-WINDOWED-TIMING (P2, WAVE-AUTHORED at `50cbf6b`) — **FIXED
  2026-07-28 on `wave/v015-p1-delivery`.** The prediction below held and then
  went red on CI too: PR #310's canonical sweep failed on exactly these two
  waits (`cursor=189`), because a loaded 4-job runner burns the same wall-clock
  holds the windowed run does. Both waits are now `from_start` scans at
  `timeout_sec: 20`, placed unchanged after `ui_combat_hidden` — delivery is
  asserted at that checkpoint regardless of which side of `combat_started` the
  render landed on. Verified 3x green headless AND green windowed at seed 9
  (windowed reproduces the ledgered 7-pre/1-post split exactly). See
  docs/CHOICE-LOG.md 2026-07-28.
  `sewers_walkthrough` PASSES headless (what `ci_sweep`/CI run) and FAILS
  windowed at its pinned seed 9: the two post-combat `ui_toast_rendered`
  waits Task 1.3 added as the drain-kick's live proof time out (5.0s each,
  cursor=190). Cause is frame pacing, not the feature — windowed real-time
  frames let the queue drain BEFORE `combat_started`, so [Firefly] and
  [Snap Freeze] render pre-combat (7 rendered pre / 1 post) and there is
  nothing banked for the post-combat waits to catch; headless collapses the
  holds, so 3 render pre and 4 are banked and delivered after
  `ui_combat_hidden`. The assertions are therefore headless-only. This
  matters because `sewers_walkthrough` is the designated dark-map script in
  the MACHINE-PLAYTEST rotation — the rotation now has a script that cannot
  be run windowed without a red result.json. Wants the two waits made
  pacing-independent (assert the queue's delivery via state, or gate the
  waits on the banked-count) rather than deleted.

### Machine playtest — wave/mq6-bands, MILESTONE CLOSE: the whole main line (2026-07-27)

Source: `wave/mq6-bands` after Tasks 9.1–9.3, full asset overlay in tree, 29/29
unit suites + the 163-script sweep green first. Thirteen windowed runs walking
the line start→finale (`tutorial_flow`, `gate_district_walkthrough`,
`sewers_walkthrough`, `climax_seal`, `horns_dig_flow`, `door_awakening`,
`spine_reach`, `riverfarm_fight`, `invrisil_disagreement_fight`,
`pallass_walkthrough`, `seal_open`, `finale_after_merge`, `journal_history`),
all `passed: true`, 63 screenshots read at native 1280x720. The finale's own
paced lines are structurally invisible to QA (`sleep_veil._is_qa()`) and were
read in the wave/mq5-finale pass above — not re-litigated here.

FIX ROUND 1 extended the pass to the **full MACHINE-PLAYTEST matrix** (the six
rows the first pass skipped: `char_creation`, `atmosphere_check`, `gear_loop`,
`social_loop`, `status_first_encounter`, `arc_flow` — all `passed: true`, 33
more shots) plus a throwaway windowed **forge-golem fight** probe at the
`t4_spellsword14_party` reference build, so Pallass's newly-gated band cell was
actually PLAYED and not only measured (probe script + fixture deleted before
commit; shots kept out-of-tree). Two entries below were corrected or closed by
what those runs showed.

- [x] JOURNAL/ACT-V-REVEAL-LEAK (P2, WAVE-AUTHORED at `14a8771`) — `acts.json`
  act_iv's `the_reach_mapped` beat read "Three regions have handed you the same
  word without noticing they were doing it. The Door has been teaching you what
  it is made of." `journal.gd:639` renders PENDING beats in full at `·`, so
  that stated Act V's entire lattice reveal from the moment Act IV opened
  (`climax_seal/02_journal_act4.png`, a 3-level fixture standing at the seal).
  It broke the rule act_v's own `_comment` states — "none may state more than
  the act's own title". **FIXED fix round 1** → "The Door's reach has outgrown
  the map you started with, and you have walked all of it." No region list, no
  reveal, reads right in both `·` and `✓` states; verified in render at
  `arc_flow/05_journal_sealed.png`. act_iv's `_comment` now carries the rule.
- [x] JOURNAL/ACT-IV-PENDING-ITINERARY (P3, PRE-WAVE copy, wave-changed
  VISIBILITY) — the audit that came with the fix above. act_iv's five region
  beats (`riverfarm_owed`, `invrisil_squared`, `pallass_tiers`,
  `the_horns_home`, `the_door_opens`) are unchanged since `e98e23f`, but they
  were authored when Act IV was the POST-GAME checklist act, where nothing was
  ever pending. The 2026-07-26 reframe moved Act IV's entry to the seal, so
  each now sits on the page in completed voice naming its own chain's outcome
  before the player has heard of it. NOT re-copied: stripping their specifics
  would gut the earned Act IV page, which this same playtest rates a strength.
  The real fix is render policy — hide unearned derived beats, or mark them as
  openings rather than outcomes. Controller call, `journal.gd:637-639`.
  **FIXED v0.15 P1 (`a085cfb`, #310) — verified at the wave close, not on the
  phase's word.** The fix was the opening pass itself: act_iv's five region
  beats no longer state outcomes, so the render-policy question the entry
  raised is moot. Read on my own re-shot, `arc_flow/07_journal_lead_survey.png`
  (seed 9): the earned beat carries `✓` ("The seal holds. Liscor counts you
  among its own."); every pending beat carries `·` and is a forward ASK —
  "The Horns are digging east, and they are short a pair of hands.",
  "Riverfarm's fields hold more trouble than wheat.", "The Walled City opens
  for paperwork, not heroics." Not one names its own chain's outcome, so the
  page reads as an itinerary rather than a spoiler, and the specifics that
  make the earned Act IV page good were kept. No render policy shipped and
  none is needed.
- [x] COMBAT/FEED-FOLD (P2, REGRESSION of the Fixed-section item "message panels
  clipped the last wrapped line") — **the combat feed's viewport admits exactly
  three full rows and a sliced fourth.** Corrected in fix round 1: the first
  pass called this "whenever the 4th entry WRAPS", which the extra matrix rows
  disproved. Wrapping is irrelevant — it is the ROW COUNT. Three surfaces, two
  of them unwrapped: `riverfarm_fight/02_briar_deep_wave.png` (wrapped, "…for
  13!" cut), `invrisil_disagreement_fight/01_warehouse_fight_wilovan_ally.png`
  (unwrapped, "Wilovan strikes Hired Blade B for 7!"), and the forge-golem
  probe's `04_forge_fight_mid` (unwrapped, "Traveler answers with [Battle
  Momentum]!"). `status_first_encounter/01_first_encounter_feed.png` is the
  control: two rows, no slice. So a kill line or a damage number is routinely
  the thing that vanishes. The re-budget counts wrapped lines for the EVICT
  decision, but the viewport height is not a whole multiple of the row height.
  NOT fixed here — it is a shared message-panel budget touching every panel
  class, which needs its own verification pass, not a drive-by in a balance PR.
  **FIXED v0.15 Task 2.1** (`combat_hud.gd`): the budget model was always right;
  the LABEL disagreed with it. Two defaults conspired — `UIChrome.make_label`
  leaves `vertical_alignment` at CENTER, and the label's `size_flags_vertical` is
  SHRINK_CENTER, which is the one that bit: the label rect was its CONTENT height
  (77px for four rows) parked in the middle of the 106px inner area, so text
  alignment had nothing to align inside. Measured on-screen: panel y514..636,
  fold band y607..636; centred put the four-row block at 536..613, five px INTO
  the fold. `SIZE_FILL` + `VERTICAL_ALIGNMENT_TOP` puts it at 522..599, clear by
  8px. Re-shot windowed, all three repros clean with four full rows each:
  `riverfarm_fight/02_briar_deep_wave` (wrapped — "for 13!" now whole),
  `invrisil_disagreement_fight/01_warehouse_fight_wilovan_ally` (unwrapped —
  "Wilovan strikes Hired Blade B for 7!" now whole), and the control
  `status_first_encounter/01_first_encounter_feed` still two clean rows.
- [x] COMBAT/HIRED-BLADE-NAMES (P2, Phase 9 made it matter) — all three
  warehouse enemies carried `display_name: "Hired Blade"`, so the turn banner
  read "Hired Blade A | Hired Blade B | Hired Blade C" and the feed named them
  the same way. Phase 9 gave `hired_blade_leader` `[Counter Strike]`: the fight
  now HAS a boss with its own mechanic and nothing on screen said which of the
  three it was. **FIXED fix round 1** — the leader is "Hired Blade Captain"
  (a unique name takes no auto-suffix, so the two knives stay A/B and the
  captain reads as their head). Zero churn: the literal appeared nowhere
  outside `combatants.json`. `invrisil_disagreement_fight/01`.
- [x] COMBAT/GOLEM-NAME-SPLIT (P4) — the forge golem parleys as "Miscalibrated
  Golem" (`data/dialogue/forge_calibration_golem.json` speaker) and then fights
  as "Stone Golem" (`combatants.json:forge_golem` display_name, shared with both
  market watchgolems). The line you just read names a different thing from the
  one in the turn banner. Same shape as HIRED-BLADE-NAMES but one tier down: no
  mechanic hangs on telling them apart. Found on the fix-round-1 forge-golem
  probe (`03_forge_fight_open`). **FIXED v0.15 T3.2** — `combatants.json`
  `forge_golem` takes the entity's name ("Miscalibrated Golem"). The market
  pair is untouched: both watchgolems keep "Stone Golem" under a "Stone Golems"
  parley, which already agreed. Zero churn outside that one literal; the six
  crossing canonicals (parley_gates_check, parley_talkdowns_loop,
  pallass_watchgolem_loop, bestiary_peek, dungeon_kingslayer_loop,
  invrisil_mothbear_loop) are green unchanged.
- [x] JOURNAL/HALF-ROW (P3) — the journal's scroll viewport admits a partial
  text row instead of clipping at a line boundary, so its bottom line renders
  sliced ("The Missing Crate — Complete." on both
  `climax_seal/02_journal_act4.png` and `spine_reach/02_journal_spine_beat.png`).
  The `▼` continuation cue is present so it IS scrollable, but a half-height row
  reads as a clipping bug, not as "more below".
  **FIXED v0.15 Task 2.1** (`journal.gd`): the body's EXPAND_FILL moved to a
  plain Control SLOT and the body is anchored full-rect inside it, so
  `_clip_body_to_line_boundary` can shorten it to a whole number of rows off the
  slot's own height (measured from the RichTextLabel's `normal_font` — 20px
  pitch). One-way dependency, no layout feedback; if the clip never runs the body
  fills the slot exactly as before. Re-shot windowed:
  `spine_reach/02_journal_spine_beat` — which is also the Leads worst case, four
  concurrent leads over six rendered lead rows — ends on a full 14px glyph band
  at y579..592 with the ▼ below it, and `seal_fed/04b_journal_lore` ends on a
  whole row too. Row bands measured at an exact 20px pitch, no partial band
  anywhere in the viewport.
  **AND one live bug it flushed out**: the clip moved the body's drag release
  point a few px and `field_skills_loop` went red — its drag-to-scroll let go
  over the `[Basic Cleaning]` row and TOGGLED it into the field loadout.
  RichTextLabel fires `meta_clicked` on button release over a meta region
  whatever the gesture did in between, so drag-reading the Skills tab has always
  been able to silently add or drop a hotbar skill. Fixed with a
  `_body_gesture_panned` latch; the canonical's own pins were right and were not
  touched. **Fix round 1** made the latch honest on touch: it ACCUMULATES |dy|
  across the gesture and trips past `BODY_PAN_SLOP_PX` (4.0), because latching on
  the first motion event of any magnitude would have eaten legitimate taps from a
  finger that never holds still — worse than the bug. It also resets on
  open/close/tab-switch, not only on press, so a latch set by a pan that ended
  elsewhere cannot swallow the next tap. `field_skills_loop` now carries BOTH
  halves: the drag's negative (`loadout: ["observe"]`, a single-element list any
  stray toggle breaks) and a positive control — two `tap_journal_body` taps at the
  drag's own release point, toggling `[Basic Cleaning]` on and back off, domain
  event and `ui_journal_loadout_rendered` both pinned.
- [x] COMBAT/BRIAR-CAMOUFLAGE (P3, same family as the open COMBAT/CELLAR-VERMIN
  entry) — on `witch_hollow` the deep briar collectors are green foliage on a
  green floor under a green canopy. In `riverfarm_fight/02_briar_deep_wave.png`
  Collector A is findable only by its HP bar, and Collector B's foliage overlaps
  the Hunter's cloak so ally and enemy read as one mass with two bars.
  **FIXED v0.15 T5.1 (2026-07-28):** the same `combat_tint` seam, pulled
  thorn-rust across all four collector ids. Re-shot:
  `riverfarm_fight/02_briar_deep_wave.png` (seed 9), read at a native crop —
  both collectors are rust-and-red against the flat green floor and the Hunter's
  dark-grey cloak is unmistakably a third mass. Zero stat edits.
- [x] MAP/PALLASS-FORGE-FLOOR (P3, widened in fix round 1 to the ARENA) —
  `pallass_forge`'s walkable floor and its walls share one purple-grey brick
  texture with no floor/wall cue; the top rows are indistinguishable from the
  walkable middle (`pallass_walkthrough/07_forge_tier_arrival.png`). In the same
  shot the forge golem reads as machinery parked beside the lift rather than as
  a combatant. The `forge_hall` ARENA inherits it: on the fix-round-1 fight
  probe the two blocked-cell clusters read as decorative brick patterning, not
  as obstacles you must path around. The combatants themselves are fine there —
  see WHAT LANDS.
  **FIXED v0.15 T5.1 (2026-07-28), all three halves.** (1) MAP: row 2 now takes
  the slate band row 9 already used, so the tier wall and the walkable brick stop
  being one texture — the floor is framed dark top and bottom, no blocking moved.
  (2) ARENA: the board used a HARDCODED biome->prop table that had never heard of
  `pallass_forge`, so its cover fell through to a flat recoloured tile (also a
  props-over-tiles violation). The board now reads `biomes.json`'s
  `blocked_props` — the key the FIELD renderer already consumed — with the const
  as fallback only, and blocked props take the GH#28 boost (dressing must never
  compete with the grid; a cell you must path around is not dressing). (3) The
  golem takes an ember field `tint` so it stops reading as parked machinery.
  Re-shot: `pallass_walkthrough/07_forge_tier_arrival.png` (seed 9). ~~NOTE: no
  QA script fights `forge_hall`, so the ARENA half is unit-proven (the pool now
  comes from data) but has no board screenshot — a pin is filed.~~ **CLOSED
  2026-07-28 (v0.16 #307):** `pallass_standards_fight` fights the arena on the
  board for real; board screenshot read at
  `qa_output/pallass_standards_fight/04_forge_hall_board_mid_combat.png` (seed
  9, windowed). The data-driven cover DOES render — one `forge_station` mid-
  board plus four `crate` cells — so the `blocked_props` half is now eye-proven,
  not only unit-proven. One nit carried forward as BOARD/CRATE-COVER-READ below.
- [x] SPRITE/KLBKCH-SILHOUETTE (v0.15 T5.2, VERIFIED then FILED) — read once
  against the silhouette contract in `docs/design/character-profiles.md`
  (wiki-verified 2026-07-10), the shipped rig fails **3 of its 4** points: TWO
  arms where canon's Vol-1-7 body needs FOUR, an orange/amber body where the
  contract says dark brown chitin, and one thin blade where it calls for twin
  sword hilts ("the one visual that separates him from every other Worker").
  Only the antennae hold. One bounded PixelLab v3 probe (2 generations, ~$0.18)
  came back HOLDING the four-arm read, the antennae and a dark rust chitin — the
  silhouette IS reachable at this scale, which was the open question. NOT
  shipped: the probe wears heavy armour the contract explicitly forbids ("he
  wears his blades, not a uniform"), carries one sword, and has no animations; a
  registry swap needs idle/walk/slice x 3 facings (~6-9 more generations,
  $0.54-0.81 — 3-4x the sanctioned budget), and a static rig would REGRESS a
  character who currently animates. Frames parked in
  `potential_assets/pixellab_2026-07-28_klbkch_probe/`. Decided in-wave, not
  gated (CHOICE-LOG 2026-07-28).
- [x] SPRITE/GRIMALKIN-FIGURE-HEIGHT (P3, USER-GATED — root cause of the inn's
  four-chair seat fight, ledgered by Phase 5 rather than fixed) — `sprites.json`
  `grimalkin` (`render_scale` 0.463, 224px frames) puts his on-screen figure near
  **98px**, about **2.3× Relc's** — and Relc's own catalog entry documents the
  convention verbatim: "render_scale preserves the approved on-screen figure
  height (43.4px)". Canon asks only for "bigger than Relc". He renders
  IDENTICALLY at his shipped Pallass post and reads fine there (open plaza); the
  inn is simply the first room tight enough to expose it — the first seat pass
  buried Wilovan behind his arm, and the shipped cell (14,5) was forced, taking
  two costs with it (his left arm crosses `pisces_mounting` at (13,5) in a state
  no save can hold, and on his two wakings in ten the Magical Door runs on the
  (13,6) approach alone). A `sprites.json` re-measure frees that seat choice
  entirely. Evidence + the exhaustive cell re-check:
  `.superpowers/sdd/2026-07-26-main-quest-foti-wave/task-5-report.md` and the
  `grimalkin_inn_guest` `_comment` in `data/maps/inn/inn.json`. NOT an inn edit —
  a shipped-character catalog change, so it waits on the user's eye.
  **REFUTED v0.15 T5.2 (2026-07-28), no change shipped.** Measured from the
  sheet's own alpha on `idle_down` (the facing his inn seat renders), bbox
  metric: his FIGURE is **49.1px** (106 rows x 0.463) = **1.25x** Relc's 39.3px — exactly canon's "bigger than Relc". The "98px, about
  2.3x Relc" above is FRAME height (224 x 0.463) compared against Relc's FIGURE
  height: apples to oranges, and the frame is mostly transparent margin. Setting
  him to the 43.4px convention would have made him the SAME height as Relc and
  broken canon. What actually crowds the inn is his **2.89-cell arms-out WIDTH**
  (Relc 1.82), intrinsic to the pose — no `render_scale` changes aspect. Re-shot
  at the shipped (14,5) seat: `inn_guests_ext_loop/05_wilovan_and_grimalkin_
  seated.png` (seed 3) — he is plainly the room's largest figure and buries
  nobody. The measurement now lives in his `sprites.json` `_comment` so the
  frame-vs-figure error cannot recur.
- [x] RUIN_WARDEN/RIG-SCALE (P3, logged in the mq4-act5 pass) — at
  `combat_scale` 1.15 the warden's crown was cut by the turn banner on the vault
  arena's top row (`seal_open/06_the_warden.png`).
  **FIXED v0.15 T5.2 (2026-07-28) — and it was far worse than a crown.**
  Measured (`idle_side`, alpha bbox: 106 rows), 1.15 put this 216px rig at
  **7.62 cells tall**: 2.5x the next-largest boss (`hired_blade_leader`, 3.05)
  and over half the board's width. It was never "a rig-anchor question" — it
  was a scale nobody had computed. `ruin_guardian`/`seal_warden` → **0.53**
  (3.51 cells, inside the 3.55 ceiling and still the biggest figure in the
  game); the three Lesser Wards → **0.42** (2.78). Visual only, no stat moved.
  **Fix round 1 correction:** the first pass used 103 rows off the wrong sheet
  and shipped 0.54, which is 3.58 — **over the ceiling its own test asserted**.
  Re-shot: `seal_open/06_the_warden.png` (seed 1).
- TRANSIENT, NOT A FINDING: one windowed `journal_history` run exited with
  "8 ObjectDB instances were leaked at exit"; not reproducible on re-run (0
  noise), headless sweep clean. Windowed shutdown-order artifact.
  **CORRECTED at the v0.15 close:** it IS reproducible — 2 of 16 windowed runs
  (`journal_history` again, plus `board_loop`), always after `QA_RESULT: PASS`,
  never headless. Known flake with a rate, not a one-off; see the milestone-close
  section's note and HANDOFF's windowed-exit entry. Do not re-diagnose.
- WHAT LANDS (keep this, do not regress): the Act V journal page is the best
  chronicle surface in the game — act header, three derived beats in the
  player's own voice, the live spine objective, then ten completed quests with
  region tags, all inside the panel (`seal_open/01_journal_act_v.png`). The
  `seal_open` eleven-shot sequence reads as one escalating scene (descent ask →
  the reading → the three-path choice → the warden → the vault → the anchor →
  the tally). The finale's consolidation offer correctly HOLDS the curtain
  rather than racing it (`finale_after_merge/00_merge_offer_holds_the_curtain.png`).
  Wilovan's own `[Counter Strike]` already prints by name in the feed, so the
  leader's new copy of it will read as a mirror, not as noise. **Pallass's band
  cell plays as well as it measures** (fix round 1): the forge golem is the most
  legible enemy in the region — dark metal with an orange forge-glow against the
  cold brick, unmistakable at a glance, and its parley→"[Strike first.]"→fight
  path is one clean beat. Its 0.71/median-4 reads as a real but fair wall at
  spellsword14; `[Power Strike]` into `[Battle Momentum]` is the shape of the
  win, which is exactly the T5 kit's own story.

### Machine playtest — wave/mq5-finale, the finale sequence (2026-07-27)

Source: `wave/mq5-finale` at the Task 8.1 commit, full asset overlay in tree,
all 29 unit suites green before the windowed pass. The GDI's paced sequences
COLLAPSE to an instant emit under any QA run (`sleep_veil._is_qa()`), so the
finale is structurally invisible to the normal windowed sweep — the four shots
below were taken with a temporary env-gated lift of that collapse
(`WI_PACED_GDI`), reverted before commit. All three path variants read at
native 1280x720, plus the seal's new light transition.

- [x] FINALE/LONG-LINE (P3) — the Invrisil region recap line renders **1114 px
  wide of a 1280 px viewport** (87%), roughly double every other line in the
  block. It does NOT clip (canvas_items stretch keeps the logical viewport at
  1280, and Labels here never wrap), but it visibly bursts the centered column
  the rest of the sequence forms, and it is the only two-sentence line in a
  block of one-thought lines. The copy is the wave plan's own verbatim text, so
  it was NOT rewritten here — this is a taste call for the controller. A
  shorter second sentence (or dropping "From him, that is a parade.") would put
  it back in the column.
  **FIXED v0.15 Task 2.1 WITHOUT touching the copy** (`sleep_veil.gd`): veil
  lines gain `AUTOWRAP_WORD_SMART` and a fixed `VEIL_LINE_TEXT_WIDTH` (880px —
  the widest authored one-thought line measures 867px, so every shipped
  one-thought line still draws on ONE row and only genuinely two-sentence copy
  folds). The 1114px line is now a measured, wrapped, two-row case inside the
  column. Its companion `_apply_line_budget` walks a separation ladder
  (18/14/10/6) so a long finale tightens instead of overflowing the 720px
  viewport, and evicts only if even the tightest rung overflows. The taste call
  this entry raised is therefore moot — the column holds either way.
- [x] VEIL-COPY/UNMEASURED (P4, systemic) — `test_copy_fit` measures toasts,
  dialogue pages, pickers and help, but **nothing measures `sleep_veil.gd`'s
  own line tables** (opener / finale / region recap / path closes / the seal
  transition), which now hold the widest single-line strings in the game. The
  1114 px figure above was obtained with a throwaway measurement script, not a
  gate. A `_check_veil_lines()` in test_copy_fit (font-size 24, 1280 budget)
  would make the ceiling enforced instead of observed.
  **FIXED v0.15 Task 2.1**: `_check_veil_lines()` exists. It source-parses
  sleep_veil.gd's own const tables (so a reworded line cannot rot a mirrored
  copy), measures with the **Header** variation's font at 24 — not the default
  label font — and carries two arms: every authored veil string wraps to at most
  two rows in the column, and the worst-case finale block fits the viewport at
  some rung of the separation ladder. Four drift tripwires pin
  VEIL_LINE_TEXT_WIDTH / VEIL_BLOCK_MAX_HEIGHT / LINE_FONT_SIZE /
  VEIL_LINE_SEPARATIONS. Proven live by temporarily dropping the row budget to 1:
  the Invrisil recap and the composed consolidation line were the two strings it
  named. The same commit also measures `<field>_variants` toast copy, which
  nothing had ever measured.
- [x] SEAL-SLEEP/TOAST-MISMATCH (P4) — **ALREADY FIXED, checkbox never
  flipped** (v0.15 T3.2 audit): `sleep_beat.gd:141-143` sets
  `anything_happened = true` on the `post_game` bank, and `test_sim_core`'s
  Phase 8 leg pins BOTH halves — no toast of the bank's own, and no
  "You sleep soundly." fallback co-rendering under the GDI's seal line. The fix
  landed with the Phase 8 line itself; only the ledger lagged. Original report
  follows. — the seal's light transition line rides
  the `post_game` bank, which `sleep_beat.gd` deliberately does NOT count as
  `anything_happened` (Task 1.2's silence contract, pinned in
  `test_sim_core`). On a sleep where nothing else lands, the player therefore
  sees the GDI say "[The warren is sealed. The record remains open.]" under the
  black and then a "You sleep soundly." toast on top of it. Not observed in
  `arc_flow` (its level-ups flip the flag), so it needs an otherwise-empty
  post-seal sleep to reproduce. One-line fix if wanted: flip
  `anything_happened` on that bank and re-pin the Task 1.2 silence leg.

### Machine playtest — wave/mq4-act5 Act V (2026-07-27)

Source: `wave/mq4-act5` after Tasks 7.1-7.4, full asset overlay in tree, all 29
unit suites + the 162-script sweep green before the windowed pass. Three
windowed runs (`seal_open` seed 1, `seal_fed` seed 9, `seal_reward` seed 9,
all `passed: true`), 25 screenshots read at native resolution.

- [x] MAP-LIGHTS/DAY (P3, systemic, NOT Act V's own) — `moods.meta
  .light_energy_by_phase.day` is `0.0`, so every authored map light renders at
  zero energy during the day phase. For a SEALED map (no sky, no windows) that
  is the wrong default: the vault's three lights only exist from dusk, and its
  daytime read has to be carried by the grade alone. Worth a per-map opt-out
  (`lights_ignore_phase: true`) rather than brightening every dungeon grade.
  Same class affects pallass_market's crystal lamps by day.
  **FIXED v0.15 T5.3 (2026-07-28)** as `moods.moods.<map>.lights_by_day: true`
  (not `lights_ignore_phase` — the shipped name says what it opts out of),
  honored by `WIAtmosphere`. Latched in `apply()` off the MAP grade before the
  refresh that consumes it; `apply_arena()` never touches it (an arena id is not
  a map id, and the lights on screen still belong to the map underneath).
  Implemented as a FLOOR, not an override, so a future phase that BRIGHTENS
  lights still reaches an opted-out map. Applied to `seal_vault`; re-shot at DAY
  phase: `seal_open/09_the_anchor.png` (seed 1) — the anchor plinth and both
  ward rings now cast visible cool pools instead of rendering at zero energy.
  NOT applied to `trapped_halls`: it authors ZERO lights, so the key would be
  dead config, and the PC's own [Light] lamp is not phase-gated at all.
  `pallass_market`/`pallass_forge` are the same class and stay OPEN for a taste
  read — they are walled-city interiors, but their day grades are near
  identity, so brightening them is a look call, not a defect fix.
- [x] RUIN_WARDEN/RIG-SCALE (P3, pre-existing) — at `combat_scale` 1.15 (the
  shipped `ruin_guardian` value, which `seal_warden` now matches deliberately)
  the rig's head clips under the combat HUD's turn banner on the vault arena's
  top row. Not introduced here — the first pass shipped 1.35 and the windowed
  read pulled it back to the shipped precedent. A rig-anchor question for the
  art lane, not a data-value one.
  **FIXED v0.15 T5.2 (2026-07-28) — and it WAS a data value.** Duplicate of the
  entry in the seal-open section above; measurements there (1.15 = 7.6 cells
  tall, 2.5x the next-largest boss). Guardian/seal_warden → 0.53 (3.51 cells),
  Lesser Wards → 0.42 (2.78), re-shot on `seal_open/06_the_warden.png`.
- [x] TOAST/LENGTH (P4) — the `[Detect Magic]` quartet payoff is the longest
  toast in the game (7 wrapped lines at 1280x720). It FITS (no clipping, top
  edge well inside the screen) and it is the beat's climax, but it is the new
  ceiling; `test_copy_fit` does not measure `skill_uses` variant toasts, so
  nothing enforces that ceiling automatically. **CLOSED v0.15 T3.2, no re-cut**
  — the copy was re-verified against the P2 budgets and still fits with room to
  spare, so the payoff ships whole. What changed is the enforcement: the
  skeleton-scene walk now measures `skill_uses.<skill>.toast` and its
  `variants[].toast`, proven live by ballooning that exact string until the arm
  named it ("66 wrapped lines … pushing its top 1119px off-screen"). The
  ceiling is a gate now, not a claim.


### Machine playtest — wave/mq2-dig "The Dig" close-out (2026-07-27)

Source: `wave/mq2-dig` at `dfc2ec3` + the Task 2.7 copy pass, full asset overlay
restored (746/746 files vs main) and re-imported; full sweep green (155/155)
before the windowed pass. Five windowed runs, 14 screenshots read at native
resolution: `horns_dig_flow`, `horns_dig_plates`, `door_chain_fight` (all
seed 9, `QA_RESULT: PASS`) plus two throwaway probes for the migrated-save and
pre-dig-hub reads. Durable evidence:
`wandering_inn_game/qa_output/machine_playtest_2026-07-27_mq2_dig/`.

- [x] RUIN/CAMP-DOUBLE (P1) — **FIXED 2026-07-27, controller-sanctioned,
  evidence below.** Was: the Horns were in two places at once for the whole of
  The Dig — `ceria_inn` (inn.json, 8,6) gated on `seal_kept_reported` ALONE
  while `ceria_dig_camp` (ruin_surface.json, 4,3) ran a live camp, so the
  player could take the invitation from Ceria at the inn, walk to the ruin and
  talk to Ceria at the camp, walk back and talk to Ceria at the inn again;
  `yvlon_inn`/`ksmvr_inn` carried the same bare gate while the breach toast had
  them "already down the gap". FIXED by splitting each inn row's window: the
  original retires at `horns_dig_joined` and a twin (`<id>_returned`, identical
  cell/sprite/facing/pool/conversation) brings them home at `door_mounted`.
  **SUPERSEDED 2026-07-28 (v0.15 T4.3 round 2) — the workaround became a real
  fix.** v0.14 chose `horns_dig_joined` over `horns_dig_started` because the
  started counter banks mid-conversation with the player standing in the inn
  and world.gd reconciled presence live on ACCOMPLISHMENT_RECORDED, so all
  three Horns popped out of the room in one frame while the invitation panel
  still read "Ceria" (evidence of the era:
  `AFTER_FIX/tmp_dig_inn_probe/01_MIDCONVO_after_bank.png`,
  `04_inn_during_dig_horns_free.png`). That bought the pop off at the price of
  a THREE-COPIES window: between the invitation and the camp join the Horns
  stood at the inn, at dungeon_approach, in trapped_halls AND at the camp.
  v0.15 fixed the renderer instead — `world.gd` now DEFERS a presence reconcile
  while a dialogue is open and flushes it exactly once at DIALOGUE_ENDED
  (`_presence_reconcile_deferred`, source-contract-pinned in
  `test_world_visuals` with a six-clause deletion battery). With the pop
  impossible, all six Horns presence rows moved to `absent horns_dig_started`
  (3 inn, 3 dungeon_approach, 1 trapped_halls) and the window collapsed:
  post-invitation the Horns are at the camp and nowhere else. New evidence,
  both live in `horns_dig_flow`:
  `qa_output/horns_dig_flow/00b_invitation_all_three_still_present.png` (the
  quest toast has fired, the panel is open, Yvlon/Ceria/Ksmvr all on screen)
  and `00c_after_dialogue_horns_gone_to_camp.png` (one clean frame later, all
  three gone). Behaviourally pinned in the same script: exactly ONE
  `ui_entities_rendered` before the panel closes and exactly two after
  (21 -> 18 sprites), and reverting the defer reds both assertions.
- [x] RUIN/REVEAL-DESPAWN (P1) — **FIXED 2026-07-27, controller-sanctioned.**
  Was: the reveal toast quoted an NPC who had left the screen one event
  earlier — `accomplishment_recorded door_retrieved` fires before the
  `toast "Below the pedestal: not treasure. A DOOR … Ceria, finally: 'That's
  wardwork…'"`, and `ceria_dig_camp`'s `absent: {door_retrieved: 1}` fired on
  that first event, emptying the camp corner on both breach routes. FIXED by
  moving the camp's retirement counter `door_retrieved` → `door_mounted`: the
  camp now lingers through the reveal and strikes its tents when the door is
  hung, which is also when the haul is genuinely over. Evidence:
  `AFTER_FIX/horns_dig_flow/02_the_reveal.png` and
  `AFTER_FIX/horns_dig_plates/03_the_reveal_no_fight.png` — Ceria is standing
  at the camp for her own line on both routes.
- [x] RUIN/CAMP-LEFTOVERS (P2) — **FIXED 2026-07-27, controller-sanctioned.**
  Was: `campfire` (3,3) and `crate` (5,3) were unconditional `decor` with two
  permanent `blocked` cells, so the camp's fire went on burning with live red
  coals over an empty corner after the Horns struck tents. FIXED by promoting
  both to presence-gated `prop` ENTITIES sharing the camp's exact window
  (`requires horns_dig_started`, `absent door_mounted`), and removing their two
  permanent `blocked` entries — an entity blocks only while present, so the
  cells free up with the camp instead of leaving invisible blockers (#149's
  class). Net blocking is strictly looser than shipped, so no prior-version
  save can be trapped. Evidence:
  `AFTER_FIX/tmp_migrated_ruin_probe/00_camp_struck_post_mount.png` (corner
  empty, no fire, no crate) vs `AFTER_FIX/tmp_dig_inn_probe/03_camp_present_with_fire.png`
  (same corner during the dig); `01_camp_corner_walkable.png` walks the player
  onto the old camp cell.
- [x] RUIN/MIGRATED-DIORAMA (P2) — **FIXED v0.15 T4.3**: the struck camp now leaves a `dig_camp_remnant` cold fire-ring on Ceria's exact cell (inverse window, so never co-present), and `ruin_guardian` gained a `door_retrieved`-keyed re-skin + observe rather than being deleted from the backfill — deleting it would strip the chance-1.0 `guardian_ward_fragment` Hedault's chain consumes, and the same contradiction is reachable by a FRESH plates/wardwork breach the backfill never touches (CHOICE-LOG). Proof: `door_chain_talk/90_cold_camp_remnant.png`, `91_spent_guardian_over_empty_cradle.png`. Original report follows. — a pre-restructure save migrated by
  `save.gd:339` loads with `door_retrieved` + `door_mounted` banked, and then
  the ruin it walks into still has `ruin_guardian` alive and on its feet over
  the pedestal the save says was already breached and looted
  (`tmp_migrated_ruin_probe/00_migrated_deserted_ruin.png`). The deserted camp
  on its own reads acceptably — a struck camp with leftovers is ordinary ruin
  dressing, and the gated arrival toast correctly withholds "the Horns got here
  first" — but the live guardian is a direct contradiction of the migrated
  state. Consider adding `ruin_guardian` to the backfill's removed set.
- [x] COPY/DASH-MIX (P2) — **FIXED v0.15 T3.2**: the em dash won on the count
  (283 player strings to 112), the 112 were swept across 32 data files, 21
  verbatim pins were re-cut in 12 canonicals, and
  `test_content._scan_player_strings` now forbids the ASCII form in player copy
  (`_comment` keys stay exempt — dev text keeps its dashes). Original report
  follows. — two toasts on the same map one beat apart disagree
  on dash glyph: `horns_dig_plates/02_the_plates_break_the_seal.png` renders a
  real em dash ("it was never the plates — it was whoever hadn't walked them")
  and `horns_dig_flow/02_the_reveal.png` renders ASCII double-hyphen ("A DOOR
  -- unhung"). Not a wave regression — a census of rendered copy fields across
  `data/**/*.json` finds 61 strings carrying `--` against 218 carrying `—`,
  spread over 25 files including long-shipped ones (bounties.json,
  trapped_halls.json, guild.json). Wants one normalization pass with the
  affected canonicals re-pinned, not piecemeal edits.
- [x] TOAST/QUEUE-DROP (P2, re-observed) — `horns_dig_flow` emits 17 distinct
  toast texts and renders 13; the pedestal's own flavor line ("The seam splits
  wider at your touch, cold air breathing up…") never reaches
  `ui_toast_rendered`, losing one of the two beats at the wave's biggest
  reveal. Same family as the open UI/QUEST-START entry below (queued toasts
  silently dropping payloads), now costing story copy rather than a pointer.
  **FIXED v0.15 Task 1.3 (2026-07-28):** the toast queue is lossless —
  `_clear_toast` is gone and map change / dialogue now defer the VISIBLE toast
  only, so undisplayed lines drain on the far side (combat alone banks the
  queue, and re-queues it at `ui_combat_hidden`). Measured on the script's own
  `events.jsonl` at seed 9: 19 toast payloads emitted, **14 rendered before /
  0 unrendered after**. The pedestal reveal is additionally `lore: true`, so it
  is banked to `Game.sim.lore_notes` at emit and readable in the journal even
  on a run that never renders it.
- [x] COMBAT/CELLAR-VERMIN (P2, pre-existing, re-observed on this wave's
  surface) — on the re-gated leak board
  (`door_chain_fight/00_rift_vermin_leak_board.png`) the Rift Vermin
  combatants are visually indistinguishable from the cellar's barrel decor;
  only the HP bars separate a monster from a barrel, so counting the enemy
  roster means reading the turn-order strip instead of the board. The feed
  panel's third line ("Rift Vermin B strikes Relc for 13!") is also clipped by
  the parchment fold in the same shot.
  **FIXED v0.15 T5.1 (2026-07-28):** `inn_cellar` has no `arena_moods` entry, so
  it falls back to the inn's identity grade and the GH#28 boost is a literal
  no-op there — brightness was never the lever. New per-combatant `combat_tint`
  (a `combatants.json` key applied to `spr.modulate`, while the boost keeps
  `self_modulate`, so the two multiply) gives a/b/c cold-blue, violet and ember,
  plus `combat_scale 0.56`. Round 1 shipped ~20% channel nudges and the windowed
  read REFUTED them (a hue nudge into a dark-brown sprite is still dark brown at
  1.3 cells); round 2 is a real hue shift. Re-shot:
  `door_chain_fight/00_rift_vermin_leak_board.png` (seed 9) — three coloured,
  countable creatures against plainly-duller brown barrels.
- WHAT LANDS (keep this, do not regress): the mounting scene stages correctly —
  `pisces_mounting` (13,5) reads as standing at the pantry door (14,6), his
  white robes are distinct against a crowded inn floor, and his two-line
  opening renders with no fold (`horns_dig_flow/03_the_mounting.png`). The
  day-one Liscor ride puts the player beside the gate-district arch in daylight
  with the arrival legible (`04_liscor_by_the_door.png`). The plates breach is
  the best copy in the wave and renders in full. Ceria's pre-dig hub line "It
  was guarding a door." reads as a backward callback to the vault construct and
  the `seal_kept_door` prop the player just walked past — not a leak of the
  dig's reveal, and the invitation option beneath it names no door.

### Machine playtest — quest-thread legibility (2026-07-19)

Source: detached `c33faac` build with the complete local asset overlay; clean
`load_gate`, then eight windowed seed-9 scripts, 50/50 screenshots read at
native resolution. Durable evidence:
`wandering_inn_game/qa_output/machine_playtest_2026-07-19_quest_legibility/`.

- [x] UI/QUEST-START (P1) — the main arc starts `something_beneath` and emits
  two toast payloads in the same tick: `New quest: Something Beneath` and the
  actionable `A Watch runner is looking for you.` Only the quest-title toast
  ever produces `ui_toast_rendered`; the runner pointer never reaches the
  screen. `arc_flow/01_tremor_pointer.png` therefore leaves a first-time
  player with a title but no person or destination to pursue. Queue both lines
  or combine them, then pin the directional copy in the screenshot/rendered
  event rather than only the domain log.
  **FIXED v0.15 Task 1.3 (2026-07-28):** both lines now queue and both render —
  `arc_flow` pins the pointer's own `ui_toast_rendered` before
  `01_tremor_pointer.png` and additionally asserts it landed in `lore_notes`,
  so the destination survives a player who walks off mid-toast. See the
  TOAST/QUEUE-DROP entry above for the queue mechanism.
- [x] COMBAT/DARK-ARENA (P1 acceptance drift) — the two Sewer Rats in
  `sewers_walkthrough/01_vermin_encounter.png` are effectively invisible at
  native scale; their HP numerals and orange bars reveal that enemies exist,
  but the bodies read as tiny dark pixels. The still-dark mood lands, but the
  closed GH#28 combatant-brightness treatment no longer clears its own
  first-time-player visibility bar on this roster.
  **FIXED v0.15 T5.1 (2026-07-28) — it was never a brightness bug.** Measured
  on the sheet the board actually plays (`idle_side`, alpha bbox, max over
  frames), the `bat` roster rendered at **0.38 cells** (36 rows x render_scale
  0.17 / CELL 16 = 0.3825; no `combat_scale` existed pre-wave) — a smudge, and
  the smallest figure the game shipped. Brightness could not have rescued it:
  `sewers_nest`'s legibility boost already sits at 2.93 of a hard 3.0 cap, and
  the boost lifts figure and floor together. `combat_scale 0.56` puts them at
  **1.26 cells**, just over the 1.25 floor a briar collector sets, and a warm
  `combat_tint` carries them off the blue-grey grade. Board-only — the field
  bat and every stat are untouched. **Fix round 1 correction:** the first pass
  measured off a non-resting sheet, published 0.55 cells, and shipped
  `combat_scale 0.40` — which is **0.90 cells, still under the floor its own
  test asserted**. The bar was mis-measuring its own subject. Re-shot after the
  correction: `sewers_walkthrough/01_vermin_encounter.png` (seed 9).
- [~] SPRITE/ARC-CLIMAX (P2) — deep-tunnel figures repeatedly occupy the same
  visual footprint. Relc/player/warren art collapse into one stack in
  `arc_flow/dd_03_warren_mouth.png` and `dd_04_awakened_field.png`; the boss and
  both scouts overlap heavily in `dd_06_boss_fight.png`, making count, identity,
  and threat hierarchy hard to parse. Restage field cameos and spread the
  climax roster's initial combat cells.
  **ARENA HALF FIXED v0.15 T5.1 (2026-07-28):** `deep_warren`'s three enemies
  shared adjacent cells while being 2.2-2.6 cells WIDE. The boss KEEPS (10,3)
  (engagement distance unchanged, so the canonical fight is not re-rolled); the
  scouts move to (10,6)/(8,4). Re-shot: `arc_flow/dd_06_boss_fight.png` (seed
  9) — three separate silhouettes with clear gaps; count, identity and
  hierarchy all legible. **FIELD HALF STILL OPEN:** the `dd_03`/`dd_04` cameo
  stacking cannot be fixed in data — Relc is a COMPANION, so his cell follows
  the player and no map edit separates him from the awakened field piece. Needs
  a presentation-side companion-offset rule, not a cell.
- NOTE: the existing board/picker and permanent field-readout concerns were
  re-observed, not re-opened as duplicate boxes. The Missing Recruit lead is
  one notice inside a 14-page Request Board read (`missing_recruit_loop`), and
  the expanded field legend plus queued toasts obscure the lower playfield in
  `sewers_walkthrough/00b_sewers_lit.png`; existing GH#114/GH#115 remain the
  right owners.

### Windowed map-tour findings (2026-07-15)

Source: full 10-region windowed walkthrough tour (seed 9, all scripts
`QA_RESULT: PASS`); screenshots ephemeral under `wandering_inn_game/qa_output/`.

- [x] FIELD/DARK-MAPS (a5 #205, 2026-07-19 — SHIPPED + user FEEL CONFIRMED "ship as-is" 2026-07-19; pixel-diff verified) — enemies/interactables on field dark-mood maps read
  near-invisible before [Light]. FIXED via a per-entity legibility boost
  (`atmosphere.field_entity_boost()` mirroring the combat board's floor,
  gentler target 0.5 / cap 1.9): the mood grade/floor is untouched, only
  encounter/prop/NPC holder self_modulate lifts, re-applied on every
  UI_MOOD_APPLIED (so dusk->night re-lifts). Windowed before/after read:
  `dungeon_peek/00` — the corner spider now reads (legs, eyes) vs. barely
  separable; `invrisil_walkthrough/07` — the shadowed alley NPCs legible;
  both keep their dark atmosphere (floors still shadowed, no wash-out).
  Bright maps render byte-identical (boost 1.0 no-op). Original box:
  > (SUPERSEDED, kept for provenance — NOT an open item; the checkbox was
  > removed at the v0.15 close because it scanned as unfixed.)
  FIELD/DARK-MAPS — enemies/interactables on **field** (exploration, not
  combat) dark-mood maps read near-invisible before the player casts [Light].
  Distinct from the CLOSED COMBAT/DARK-ARENAS entry (GH#28 fixed combatant
  chips/HP legibility on the combat board) and the sewers-arena-silhouette
  entry (fixed) — this is the pre-combat FIELD render. Reproduced this tour:
  `dungeon_peek/00_dungeon_approach_corner.png` (the field spider bottom-right
  is barely separable from the floor at 4x zoom — a 1x player would miss it)
  and `invrisil_walkthrough/07_alley_lantern_night.png` (shadowed NPCs
  bottom-right sit below the lantern pool, nearly black). Sewers reads fine
  once [Light] is cast (`sewers_walkthrough/04_ice_crossing.png`). Candidate:
  a small ambient-brightness floor on field maps that carry live encounters or
  interactables under the darkest mood pins, mirroring the combat-board
  `_legibility_modulate` floor already shipped for the arena side. First-seen:
  2026-07-15 windowed tour. Needs a windowed read of any fix (the dark IS the
  intended mood on stealth/dungeon maps — a floor must not wash out the
  atmosphere), so left for a pass that can look at the result.
- NOTE: the tour also re-observed the permanent field-skill detail legend
  growing with progression (expanded `[Basic Cleaning]…` panel on nearly every
  map). NOT re-logged — this is the existing UI/FIELD-READOUT entry, already
  PROMOTED to issue #115 (owner corrected to `field_hotbar.gd`).

### GH#113 evidence audit (2026-07-14)

All 20 open entries were rerun in real Godot 4.7 windowed sessions against
the complete 175/175 private-asset overlay. Every canonical/probe passed; the
judgments below are visual reads, not test inference. Durable screenshots,
events, and result files live in the gitignored
`wandering_inn_game/qa_output/visual_log_2026-07-14/before/` ledger.

| Open entry | Audit disposition |
|---|---|
| Skill icons | Reproduced by data audit: 12 player-visible and 3 enemy-only hotbar skills are iconless. Generate/integrate in this drain. |
| Rock Crab | Reproduced: it disappears on the field and becomes an oversized warm blurred shape in combat. Replace in this drain. |
| Dungeon trap tells | Reproduced: dart slit reads as a circular grate; illusory floor as a red debris stain. Replace in this drain. |
| Witch/cottage overlap | Reproduced: Eloise overlaps the facade and blocks its sole clear south approach. Restage in this drain. |
| Relc descent cameo | Reproduced: dialogue comes from off-field. Add the conditional cameo in this drain. |
| Picker | Reproduced as human paging friction: choices appear only on the final page. Promote; nine canonical consumers make it larger than this drain. |
| Upstairs zoning | Reproduced: hallway/rooms have no readable threshold or ownership cue. Restage in this drain. |
| Sewer arena silhouettes | Reproduced: purple decor competes with and outweighs the tiny live enemies. Tune in this drain. |
| Delivery board | Reproduced: an outdoor signpost and grass base sit on an indoor floor. Replace in this drain. |
| Small-prop occlusion | Reproduced at the bread stall and Lyonette's door. Add a per-entity render override and fix both in this drain. |
| Guild notice wall | Reproduced as a bookcase; the surrounding cluster is otherwise acceptable. Replace in this drain. |
| Sparse arenas | Mixed: deep warren/training/cellar pass; ruin court and the crab arena remain sparse. Dress only those two in this drain. |
| Field readout | Readable today, but the requested collapse/hold interaction state is absent. Promote as UI interaction work. |
| Deep-tunnel props | Reproduced: fissure/hearth/gnaw/warren stand-ins do not communicate their authored meanings. Replace in this drain. |
| Sewer nest ledge | Reproduced: it reads as another isolated boulder. Replace in this drain. |
| Shield Spider | Reproduced: field and combat both show tiny bat specks. Replace in this drain. |
| Field blocked cells | Reproduced in code and frames: fields render flat blocked tiles while combat deterministically chooses biome props. Promote as a repo-wide rendering migration. |
| Garden diagonal QA | Reproduced as a coverage gap only; the garden itself reads clean. Add one internal diagonal leg in this drain. |
| Slow-expiry copy | Reproduced exactly: “shakes it off” appears while the combatant still stands on active ice. Fix copy in this drain. |
| Ruin route | Reproduced: the canonical route shows generic cave floor and misses the ruin architecture. Restage in this drain. |

- [x] SKILL ICONS — class-foundation pass (#93/#95/#96, R1, 2026-07-12) added
  11 new player-facing skills (`directed_strike`/[Chosen Blow],
  `flanking_step`, `read_the_field`, `measured_words`, `soothing_presence`,
  `open_doors`, `find_trap`, `disarm_trap`, `sudden_strike`/[Sneak Attack],
  `called_shot`, `piercing_volley`) and ALL 11 ship iconless — every id in
  `data/sprites.json`'s `icon_*` set is already claimed by a shipped skill
  (checked: 30/30 claimed, `icon_attack`/`icon_dash` reserved for the innate
  hotbar slots), so none had an unclaimed icon to reuse (the #94 pattern:
  icon if any unclaimed fits, else iconless + this log line). Each degrades
  gracefully (hotbar/combat_hud/field_hotbar all already tolerate a missing
  icon id, per the dozen pre-existing iconless skills — mana_shield,
  dangersense, power_shot, flame_pillar, etc.) — disclosed here as a GROWING
  art-pass gap (#94 was "19/50 skills iconless"; this pass alone adds 11
  more, before R2-R5's own new skills), not a blocker for this pass's own
  exit criteria. Needs a real icon-commissioning pass (PixelLab or hand
  pack) sized to the new total once the whole class-foundation pass lands.
  **GH#94 (2026-07-13) partial drain**: the whole class-foundation pass
  (R1-R5, issue #98) has now landed — re-verified the debt in full: 34
  player-reachable + 3 enemy-only skills iconless (well past this entry's
  own "19/50" baseline). Closed 6 of the most player-visible via
  `tools/sync_assets.py::_draw_placeholder` (same code-drawn-glyph policy
  as every icon above, no PixelLab needed): the whole [Archer] kit
  (`power_shot`/`keen_eye`/`quick_nock`/`piercing_shot`), `spellbound_strike`
  ([Spellsword] L16, named in this entry's own original baseline), and
  `sudden_strike`/[Sneak Attack] (Rogue L7's marquee grant — #90's own new/
  enriched skills turned out enemy-exclusive, never rendering on any
  player hotbar, so not worth spending the 6 on). Added a DRIFT TRIPWIRE
  (`tests/test_combat_data.gd`'s `KNOWN_ICONLESS_SKILLS`) pinning the
  remaining 15 hotbar-visible (field:true OR ap_cost>0) iconless skills
  explicitly (a narrower predicate than the 34+3 total above -- passive/
  economy skills with neither flag never touch a hotbar, so aren't pinned) — a skill outside
  that pinned set shipping with no icon now fails the unit suite LOUD (no
  more silent growth), and an entry inside it that gains an icon also
  fails (forcing the allowlist to shrink, never rot). Still needs the real
  commissioning pass for the rest. **FIXED GH#113 Wave 1 (2026-07-14):**
  commissioned and integrated PixelLab icons for all 12 remaining
  player-visible hotbar skills; the allowlist now contains only the three
  enemy-only skills. A real Godot windowed gallery exposed undersized source
  crops; the production icons were alpha-cropped and refit to a 14 px live
  area, then accepted in a second native-scale read.
- [x] SPRITE/FLOODPLAINS — `rock_crab` (issue #24) ships a BAKED recolor of
  the Admurin crab (`assets/props/admurin/Crab_Idle.png`, multiply
  ~[1.05, 3.0, 2.6] against the source's red-brown shell) targeting the
  `boulder` prop's grey-stone palette (rgb ~(115,104,93)/(63,53,44) sampled
  from `assets/props/free_pack/Rocks.png`) — the PIL preview landed WARM
  BROWN-GREY, not a clean boulder grey, and no windowed screenshot has
  verified the two side by side in-scene. The boulder-mimicry read (canon:
  "shell EXACTLY palette-matched to the boulder prop" — the mimicry IS the
  mechanic) depends on this match, and the entity sits Chebyshev 3 from a
  real `boulder` decor at floodplains (24,19), so any mismatch is directly
  visible. The recolor is baked into the asset (combat sprites have no
  runtime tint hook), so a fix is a re-bake + bundle re-cut, not a data
  tweak. First seen: issue #24 review wave, 2026-07-12. Fix: controller
  windowed read of floodplains (21,16) beside the (24,19) boulder; re-bake
  the multiply factors toward the sampled greys if the warm cast breaks
  the read. **FIXED GH#113 Wave 1 (2026-07-14):** replaced by a cool-grey
  PixelLab boulder-crab with visible pink legs; windowed field and combat
  reads now match the boulder family without disappearing or overfilling the
  combat slot.
- [x] DUNGEON/TRAP TELLS — `dart_slit_a` (`trapped_halls`) reuses the
  registered `sewer_grate` sprite (tinted cool-dark) as a placeholder —
  the A3 pixellab `dart_slit.png` candidate drifted purple against the
  Cemetery family's olive-warm-grey palette and was never integrated.
  `illusory_floor_a` reuses a same-pack Cemetery `Props.png` debris crop
  (`illusory_floor_tell`, guaranteed palette match) instead of the A3
  `illusory_floor.png` candidate, which was already flagged "too
  uniform" at A3 and separately drifts navy-blue against this floor.
  Both mechanisms are fully wired and legible via toast text + tint
  swap (see `qa_output/dungeon_peek/06_dart_slit_disarmed.png` and
  `07_illusory_floor_revealed.png`); only the bespoke tell art is
  missing. First seen: 8d Phase B (issue #14), 2026-07-11. Fix: regen
  both candidates against the real Cemetery floor family (dark
  blue-grey brick, olive cast) via PixelLab, controller art pass.
  **FIXED GH#113 Wave 1 (2026-07-14):** generated and wired a masonry slit
  and cracked-floor seam; `delve_skill` windowed reads distinguish both
  mechanisms from the old grate/debris stand-ins.
- [x] INN/EXTERIOR — CLOSED, windowed-verified, no commit needed (GH#94,
  2026-07-13) — the facade's dusk/night WINDOW GLOW was mechanism-verified
  (phase-gated light, 2-of-8 budget, the lantern precedent) but never
  eyeballed at dusk outside. Controller shot request fulfilled: a
  throwaway probe (deleted) shuffled in place near the facade past both
  `moods.json` phase thresholds (dusk 200 / night 450 actions) and framed
  the exterior at each. Reads clearly: the lit window (warm blue-gold
  glow) and the entrance's warm torch/hearth light are both unmistakably
  lit against the darkened grass and treeline, at both dusk and night
  (visually identical between the two, matching the light's own
  energy-multiplier design). No fix needed — the mechanism was already
  correct, just never looked at.
- [x] SPRITE/RIVERFARM — the witch's cell (3,8) sits close enough under
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
  **FIXED GH#113 Wave 2 + review fix `385d12a` (2026-07-14):** Eloise moved
  to `[5,8]`, all canonical approaches moved with her, and the same-cell
  bush was removed after independent review. Graph/data tests require four
  open neighbors and a decor-free cell. Fresh elder/young windowed frames
  under `.superpowers/sdd/visual-log-113-after-wave2-fix/riverfarm_walkthrough/`
  show both forms separated from the cottage and readable at day/night.

- [x] FIELD/ARC — Relc's descent-veto conversation (arc_flow dd_05) plays
  with NO Relc sprite anywhere on the field — he speaks from nowhere at the
  warren mouth, then exists in the fight roster. A walk-on cameo (guild
  DP1 idiom) at the warren mouth would ground the beat. Disclosed 2026-07-08
  playtest, design-level. **#31 drain (2026-07-08) re-adjudication: still
  open, deliberately not fixed here.** A walk-on cameo means a new
  entity/positioning wired into `arc_flow`'s own route — content work, not
  a presentation-only fix, and outside a headless-only lane's ability to
  windowed-confirm a new cameo reads right. Left for a content-touching
  pass with real windowed verification.
  **FIXED GH#113 Wave 2 + review fix `385d12a` (2026-07-14):** a
  `present_when` Relc cameo now reconciles beside the warren mouth after
  `reached_the_warren`. Review caught and removed a reverse-door landing
  collision; tests now derive all incoming landings and the canonical route
  from live data. Fresh landing/cameo frames under
  `.superpowers/sdd/visual-log-113-after-wave2-fix/deep_descent/` show the
  arrival clear and Relc visibly grounding the later veto.
- [x] UI/PICKER — the board/delivery picker paginates from the TOP,
  losing the header question + 2 of 3 postings' flavor (board_loop +
  delivery_loop shots). Board-centric milestone — severity with opus.
  **GH#94 re-adjudication (2026-07-13): root cause is a QA-CAPTURE
  ARTIFACT, not a code bug** — traced `dialogue_panel.gd`'s own paging:
  `_page_idx = (_pages.size()-1) if _is_qa() else 0` (unchanged since
  paging's introduction, commit `3624119`) means EVERY QA/windowed
  screenshot (`_is_qa()` is true whenever `TestDriver.active()`, headless
  or windowed) jumps straight to the LAST page by design (the doc
  comment's own reason: deterministic injected-key counts across
  scripts) — a real interactive player always starts at page 1 (the
  header), same as day one. Re-simulated `_paginate` in Python against
  `board_loop_start`'s real 3-posting slate: page 1 IS "Which one looks
  worth doing? / 1. WATCH NOTICE..." (774 chars -> 4 pages) — the header
  is never lost for a human. A real, narrower friction remains: the
  `options_box` (the "Take: X" choices) only shows on the LAST page, so a
  4-page picker forces a player through the whole read before any postings
  1-2 flavor is visible alongside the choice — fixing THAT is a
  conversation-shape change (splitting the picker into per-posting nodes,
  or showing options on every page) touching every board/delivery
  canonical (`board_loop`, `delivery_loop`, `crab_cull_loop`,
  `renns_warhammer_loop`, `missing_recruit_loop`,
  `floodplains_bestiary_loop`, `invrisil_mothbear_loop`,
  `dungeon_kingslayer_loop`, `pallass_watchgolem_loop`) — too large a
  surface for a no-new-art mechanical pass; left open, re-scoped, for a
  windowed-tune/content pass that can taste-judge the redesign.
  **PROMOTED by GH#113 (2026-07-14):** issue #114 carries the current
  human-vs-QA paging diagnosis, affected canonical set, input-parity risks,
  explicit non-goals, and measurable scanability/overflow acceptance gates:
  https://github.com/GabrielGLevine/wandering-inn-rpg/issues/114
- [x] MAP/UPSTAIRS — Lyonette's locked door reads as the same
  private-room zone as the PC's own bed (zone ambiguity; a rug/color
  cue would separate "yours" from "hers"). **#31 drain (2026-07-08)
  re-adjudication: still open.** A rug/color cue is a new decor pick that
  needs a windowed read to confirm it actually differentiates the zones
  rather than adding more clutter — a headless-only lane can place a
  sprite but can't judge the result, so left for a pass that can look at
  it.
  **FIXED GH#113 Wave 2 (2026-07-14):** a distinct rug now zones Lyonette's
  locked door away from the player's bed. The canonical windowed frame under
  `.superpowers/sdd/visual-log-113-after-wave2/upstairs_walkthrough/` reads as
  two separate private-room areas without route obstruction.
- [x] ARENA/SEWERS — decorative cave props resemble the live Sewer Bat
  enemy silhouette in the dark arena (target-legibility compounding the
  standing dark-arena item, GH issue #28). Folded into issue #30's arena
  pass (2026-07-08) rather than fixed standalone here — see #30's section
  of the polish report.
  **FIXED GH#113 Wave 2 (2026-07-14):** the bat-like purple mushroom was
  replaced by a boulder in `sewers_nest`. The preserved combat-board frame
  under `.superpowers/sdd/visual-log-113-after-wave2/combat_boards/` shows
  the dedicated Shield Spiders distinct from every decorative silhouette.

- [x] SPRITE — **THE DELIVERY BOARD (`runner_board`, M-DEPTH DP5, Runner's
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
  **FIXED GH#113 Wave 1 (2026-07-14):** `runner_board` now uses a bespoke
  paper-and-route board with no outdoor post or grass; accepted in the
  windowed `delivery_loop` interior and browse frames.
- [x] SPRITE — **a THIRD reproduction of the player-occludes-small-prop
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
  re-litigated per prop.** **GH#94 (2026-07-13): still open, deliberately
  NOT fixed by the `bed` entry's own `field_y_sort_bias_px` fix below** —
  `bread_stall` uses the `food_basket` sprite, shared by 6 OTHER entities
  repo-wide (checked: `grep -rn '"sprite": "food_basket"'`); the bias
  schema is PER-SPRITE, not per-entity, so biasing `food_basket` to fix
  this ONE stall risks silently flipping the draw order for the other 6
  consumers, none of which were audited here. `lyonette_door` has the same
  problem, worse (`door`, 29 other consumers). Needs a per-entity override
  the current schema doesn't have, or a bigger crop/anchor tweak scoped to
  just these two entities.
  **FIXED GH#113 Wave 2 (2026-07-14):** entities now accept an optional
  `field_y_sort_bias_px` override without changing shared sprite entries;
  the holder sort key shifts while sprite and shadow pixels cancel the
  offset. `bread_stall` and `lyonette_door` use the scoped override. Accepted
  windowed frames live under `.superpowers/sdd/visual-log-113-after-wave2/barracks_walkthrough/`
  and `.superpowers/sdd/visual-log-113-after-wave2/upstairs_walkthrough/`.
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
- [x] SPRITE — **`guild_notice_wall` (Adventurer's Guild interior) reuses
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
  else catalogued fits. Needs new art, left open. **FIXED GH#113 Wave 1
  (2026-07-14):** replaced by a distinct wall of pinned and curled papers;
  the surrounding cluster remained readable in the canonical windowed run.

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
- [x] COMBAT/ARENAS — arenas read sparse (empty dirt + scattered buckets)
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
  **CLOSED GH#113 Wave 2 (2026-07-14):** the already-dressed floodplains,
  cave, sewers, and deep-warren boards were re-read windowed and accepted;
  `ruin_court` gained an off-grid statue/rubble architectural frame. Combat
  board evidence is preserved under
  `.superpowers/sdd/visual-log-113-after-wave2/combat_boards/`; further
  density is taste-level redesign, not an unchecked defect.
- [x] UI/FIELD-READOUT — (supersedes the K2 drop-row note) permanent
  legend furniture grows with progression; playtest recommends collapse
  to icons-only after first waking, expand on hold. K2b owns. **#31
  drain (2026-07-08) re-adjudication: still open.** K2b (commit
  `e121e5e`) shipped the loadout assign/unassign mechanics, not this
  visual collapse-to-icons behavior — checked the diff, no
  icons-only/expand-on-hold UI change is in it. A UI interaction-model
  change (collapse/expand on hold) needs windowed confirmation of the
  collapsed state actually reading clearly at icon-only size; left open
  for a pass that can look at it.
  **PROMOTED by GH#113 (2026-07-14):** issue #115 corrects the current owner
  to `field_hotbar.gd` (field labels were retired; `world_labels.gd` is now a
  combat-stats regression boundary) and specifies discoverable keyboard,
  gamepad, mouse, accessibility, persistence, and icon-fallback acceptance:
  https://github.com/GabrielGLevine/wandering-inn-rpg/issues/115

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
- [x] FIELD/DEEP_TUNNELS — the four M-ARC A2 flavor/threshold props
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
  **FIXED GH#113 Wave 1 (2026-07-14):** fissure, dead hearth, gnaw pile,
  and warren mouth now have separate PixelLab silhouettes. The warm hearth
  light was removed because it contradicted the new cold/dead prop; all four
  passed the windowed `deep_descent` read.

- [x] FIELD/SEWERS — `nest_ledge` (Content Wave C3 Q1 SKILL-path [Observe]
  prop, sewers `(17,10)`) uses the `boulder` sprite as a stand-in for "a
  broken brick overlook lip" — consistent with the sewers' `drainage_marker`
  (also `boulder`), reads acceptably in the dark cave grade, but a bespoke
  ledge/broken-wall sprite (Track B / PixelLab) would read better. First-seen
  2026-07-06 (C3, uncommitted). Off the combat spine; low priority. **#31
  drain (2026-07-08): reviewed alongside issue #30's sewers dressing pass
  — decor-only, still needs new art, left open.** **FIXED GH#113 Wave 1
  (2026-07-14):** replaced by a broad broken-brick ledge that reads as
  horizontal sewer architecture rather than another boulder.

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
- [x] COMBATANT/SPRITE — the new `shield_spider` (Content Wave C1, Liscor
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
  logged twice); that duplicate is removed, tracked here only.** **FIXED
  GH#113 Wave 1 (2026-07-14):** a dedicated black-and-silver, eight-legged
  PixelLab character now supplies directional idle/attack/hit/death sheets.
  Two windowed scale reads rejected 0.24 and accepted 0.30 in field and
  combat; it no longer shares the Sewer Bat silhouette.
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
- [x] FIELD/TILES — world maps render BLOCKED cells as flat tiles while
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
  **PROMOTED by GH#113 (2026-07-14):** issue #116 traces field `cover_skip`
  and the combat biome-prop precedent, then gates collision honesty,
  deterministic selection, migration, multi-biome windowed evidence, and
  rendering cost:
  https://github.com/GabrielGLevine/wandering-inn-rpg/issues/116
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
- [x] GARDEN/UI — GF rotation frictions (2026-07-08, gf-rotation-report),
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
  **FIXED GH#113 Wave 3 (commit `24ba03a`, 2026-07-14):**
  `garden_walkthrough` now moves diagonally `[7,10]`→`[9,9]`, captures
  `00b_garden_diagonal_y_sort`, and returns to the original route cell.
  Windowed evidence under `.superpowers/sdd/visual-log-113-after-wave3/garden_walkthrough/` shows honest fountain/statue clearance, stable camera
  centering, and correct Y-sort.
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
- [x] COMBAT/TEXT — terrain-sourced slow expiry reuses the generic
  STATUS_EXPIRED feed line "shakes it off", which reads odd while the
  combatant is STILL standing on [Ice Floor] ice (slowed again next
  turn) — GH#21 controller windowed read 2026-07-07,
  `qa_output/ice_floor_loop/01_standing_slow.png`. Candidate: a
  terrain-aware expiry line ("the ice still grips") keyed off the
  status's source. **#31 drain (2026-07-08) re-adjudication: still open.**
  A copy/design call (does the status system distinguish
  terrain-sourced expiry from every other kind of expiry?) rather than a
  presentation bug — left for a design pass, not attempted blind.
  **FIXED GH#113 Wave 3 (commit `24ba03a`, 2026-07-14):** terrain-applied
  status records and apply/expire events now retain `source_kind`; only
  `slowed` from `icy_floor` renders “is still gripped by the ice,” while
  generic expiry keeps “shakes it off.” Exact unit/event pins and the
  windowed `02_ice_reapplication_copy` frame verify the distinction under
  `.superpowers/sdd/visual-log-113-after-wave3/ice_floor_loop/`.
- [x] SPRITE — FIXED (commit `2472e27`, "v0.4.1 fix wave", relocated from
  Open — GH#94 re-adjudication, 2026-07-13) — `pantry_door`'s AWAKENED
  state read as barely-distinguishable from default/flicker at gameplay
  distance (DF fix wave 2026-07-07 found the tint-only approach too
  subtle, PixelLab inpaint attempts failed the legibility bar, candidate
  fixes left for a future pass: a brighter tint/light, data-only). The
  v0.4.1 fix wave replaced tint-only with a real distinct SPRITE swap:
  both `flicker` and `awakened` `visual_states` now wear `anchor_waystone`
  (the same portal-arch prop every region's anchor stone already uses —
  cool-blue flicker, warm-gold awakened + light), retiring the old
  `pantry_door_glow` placeholder. Windowed-verified with the portal menu
  open (`v041-evidence/inn_waystone.png`). This closure was simply never
  synced back to the original DF-wave entry — same drift class the
  toast/hotbar/inventory mis-citation entries below were caught by.
- [x] MAP/RUIN — `ruin_surface`'s canonical route (`ruin_walkthrough`)
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
  `docs/archive/design/8a-asset-assembly.md` sec. 1's Cemetery-pack candidates,
  never wired) along the edge-hugging route players actually walk. Not
  implemented here — DF's charter is fixes, not new map-dressing content;
  flagging for a future content pass. **#31 drain (2026-07-08): reviewed,
  left open unchanged — no new information changes the prior deferral;
  still a route/content decision, not a presentation fix.**
  **FIXED GH#113 Wave 2 + review fix `385d12a` (2026-07-14):** a solid
  ruin statue at `[14,4]` and low rubble at `[10,4]` bring architecture to
  the walked edge without blocking it. Tests derive door landings,
  encounters, and the actual canonical route before accepting those cells;
  the windowed route frame is under
  `.superpowers/sdd/visual-log-113-after-wave2/ruin_walkthrough/`.

## Fixed

- [x] SEAL_VAULT/GRADE (P2, Act V vault, `wave/mq4-act5`) — **FIXED
  `e94037c`.** Was: the new vault read as one more near-black dungeon cell; the castle floor chosen to
  say "this room never fell in" never arrived on screen (first windowed pass at
  mood 0.335). Fix: grade to 0.60/0.60/0.66 day-dusk, 0.50/0.50/0.58 night,
  vignette 0.44 — a cool tilt (ward-light, not a window), still a full step
  under the barracks' lived-in 0.68 and double the halls' 0.282. NOTE for the
  eye-gate: it is still on the dim side of "lit". If the user wants it warmer,
  the lever is this one mood row.
- [x] SEAL_VAULT/FOCAL (P2, Act V vault, `wave/mq4-act5`) — **FIXED
  `e94037c`.** Was: the two `cellar_wardwork` rings sat on the anchor's own neighbour cells (8,3)/(8,5)
  and read as the room's subject, with the plinth between them invisible. Fix:
  rings moved to the aisle ends (8,2)/(8,6), each carrying a faint cool light,
  and the anchor took the key light (energy 0.95, radius 40). The plinth now
  reads as the focal object on approach.

- [x] UI/TOAST — FIXED (GH#273, v0.13.1 hotfix, 2026-07-20) — the arc-start
  Watch-runner pointer (AND "New quest: Something Beneath") never rendered:
  they queue LAST at the wake beat behind bed/autosave/class toasts, and
  `_clear_toast()`'s transition wipe (MAP_CHANGED/DIALOGUE_STARTED/
  COMBAT_STARTED) discarded the whole pending queue — leaving the bedroom
  guaranteed the loss. REFINES the 2026-07-19 machine-playtest P1: the
  render arm was never missing; the queue tail was unreachable. Same class
  ate post-warren loot toasts (`Got: Mending Draught`/`Moonhide Fetish`) in
  arc_flow's log. Fix: sim flags narratively load-bearing toasts
  `sticky:true` (the pointer at sleep_beat.gd + all three quest lifecycle
  emits in wi_game.gd); message_layer re-queues pending sticky texts on a
  transition wipe instead of dropping (the `_first_wake_hint_pending`
  re-queue contract, generalized — panel still hides, so the stale-toast
  fix holds). QA: arc_flow/climax_chain/raskghar_entry_loop now assert the
  PINNED `ui_toast_rendered {Watch runner}` AFTER the street teleport (the
  old bare unpinned wait false-passed on the stale "Your own bed." render —
  the shipped-green mechanism); sim-side sticky pinned in test_sim_core.
  Event-order proof in all three canonicals: toast → map_changed → rendered-
  on-street. Container windowed capture races the 0.4s hold under software
  GL (screenshot catches the NEXT queued toast draining on-street — itself
  proof the re-queue is live); a real-rig windowed read of
  arc_flow/01_tremor_pointer will show the pointer text itself. Follow-up
  (out of hotfix scope, in #273): sticky for `Got:` loot toasts, sweep for
  other bare `ui_toast_rendered` waits.
- [x] UI/TEXT — SUPERSEDED, no commit needed (GH#94 re-adjudication,
  2026-07-13) — tutor feed 4th line sat tight against the parchment fold
  (descenders grazing it), dated 2026-07-04, already self-adjudicated
  "acceptable now" in its own text at the time. M-FP F (commit `5508ecb`,
  2026-07-06 — CLAUDE.md's own Gotchas entry, "Message panels budget
  WRAPPED LINES, not entries") landed a systemic evict/truncate budget
  for exactly this panel class (combat feed included) two days later,
  the SAME mechanism that closes the `04_ambush_warrior_spear` UI/TUTOR
  entry just above. Superseded, never re-checked until now.
- [x] UI/TUTOR — CLOSED, verified via a fresh windowed read, no commit
  needed (GH#94 re-adjudication, 2026-07-13) — tutor panel allegedly
  clipped Relc's "Earned, not given" line (the arc's thesis) at panel
  bottom in the ambush fight. The prior entry's own narrowed diagnosis
  (M-FP F's wrapped-line budget, commit `5508ecb`, predates this
  finding's 2026-07-07 playtest date) is confirmed correct: a fresh
  windowed `tutorial_flow` run (seed 9,
  `qa_output/tutorial_flow/04_ambush_warrior_spear.png`) shows the FULL
  line, "...You slept, so check your numbers: 3 and up are your [Skills]
  now. Earned, not given." rendering complete with margin to spare below
  it — no clip, no eviction. Already resolved by the generic mechanism;
  never re-checked until now.
- [x] COMBAT/TEXT — CLOSED as not-a-bug, no commit (GH#94 re-adjudication,
  2026-07-13, relocated from Open) — [Ice Floor]'s readout slot-info line
  truncates at "...for 2 rounds...." (the fitted 3-line budget eats the
  trailing "Slows." verb). The item's own prior text already reached this
  verdict ("cosmetic... the slow shows anyway on first application...
  nothing is actually lost, just the last word off-screen" — the L5
  untruncated-payload contract holds) — it had simply never been flipped
  to closed despite carrying its own closing argument, the same class of
  drift the toast/hotbar/inventory mis-citation entries below were
  caught by.
- [x] UI/FIELD-HOTBAR — FIXED (commit `fe2ad74`, "Field hotbar hides while
  a conversation is open", refined `c6839a3`) — the slot bar drew over an
  open dialogue panel's bottom parchment edge (candidate fix named in the
  entry's own text: "hide the whole bar during modals"). Git-history
  re-adjudication (GH#94, 2026-07-13) found the candidate fix already
  shipped — `field_hotbar.gd` now hides entirely whenever a conversation
  is open (`_dialogue_open` gate), the SAME fix that closes the
  UI/DIALOGUE page-indicator entry above (one root cause, two
  descriptions) — this exact edge-overlap can no longer happen at all.
- [x] SPRITE — FIXED (GH#94, 2026-07-13, occlusion-family y-sort bias) —
  the `bed` prop (`your_bed`, `garden_bed`, `riverfarm_guest_cot` — all 3
  consumers of the `bed` sprite id) was fully occluded by the player's own
  sprite when approached the way every sleep interaction is scripted
  (stand one cell south, face up/north, interact) — zero pixels of the bed
  visible behind the player's head/torso (`dp3-shots/03_your_bed_sleep.
  png`). Applied the drain's own concrete recommendation:
  `field_y_sort_bias_px: 20.0` on the `bed` sprite catalog entry (one
  cell + margin, `inn_roof`'s own magnitude) — pulls the bed's Y-SORT KEY
  south past a directly-adjacent south neighbor's key, with the render
  position compensated back out (net zero visual shift, `world.gd`'s
  `_make_entity_visual`), so the bed now draws AFTER (over) an adjacent
  south-standing player instead of under them. Scoped to `bed` only (NOT
  `lyonette_door`/`bread_stall`, whose sprites — `door`/`food_basket` —
  are shared by 29/6 other entities repo-wide; biasing those would be an
  unaudited blast radius, left open, see that entry above) — `bed` has
  exactly 3 consumers, all checked for neighboring entities/decor that
  could regress (none found on any of the 3 maps). WINDOWED-VERIFIED,
  before/after pixel-diffed (`upstairs_walkthrough`/`garden_walkthrough`/
  `longhouse_walkthrough`, seed 9): the bed's headboard+mattress silhouette
  now renders clearly on top at `your_bed` and `garden_bed` (diff bbox
  confirmed non-empty, a real pixel change) — TRADE-OFF, disclosed: the
  player's own HEAD is now partially covered by the headboard in that one
  adjacent-frame (torso/legs stay fully visible), the same swap-not-solve
  the sibling `raskghar_awakened` fix made in the opposite direction. Judged
  an improvement (the bed goes from totally invisible to unmistakably a
  bed; a momentary partial head-cover during a single interact frame is a
  smaller cost) — matches the drain's own anticipated outcome ("should
  close all 4 reproductions with one data change"). `riverfarm_guest_cot`
  approaches EAST-WEST (never triggered the north-south occlusion in the
  first place) — windowed-confirmed unaffected, both figures fully visible
  side by side. Verified: `test_sprite_registry`, `upstairs_walkthrough`/
  `garden_walkthrough`/`longhouse_walkthrough` all green (headless +
  windowed).
- [x] UI/DIALOGUE — FIXED (commit `fe2ad74`, "Field hotbar hides while a
  conversation is open", refined `c6839a3`) — the dialogue panel's page
  indicator/"more" hint sat directly behind the field hotbar's slot-1 icon,
  partially occluded on every paginated conversation (DP2/DP5 windowed
  reads, `dp2-shots/01_board_browse.png`, `dp5-shots/02_delivery_board_
  browse.png`). Root cause per the entry's own text: `dialogue_panel.gd`
  and `field_hotbar.gd` share CanvasLayer default layer 1, and
  `field_hotbar` is added to the tree AFTER `DialoguePanel`
  (`main.gd`'s `_spawn_ui_layers`), so at equal layer it drew on top —
  git-history re-adjudication (GH#94, 2026-07-13) found this was already
  fixed, NOT via a z-order/layer bump but by hiding `field_hotbar`
  entirely whenever a conversation is open (`_dialogue_open` gate,
  composed with the existing combat-hide gate via `_apply_visibility`) —
  "dialogue always wins" per the fix's own doc comment in
  `field_hotbar.gd`. **The "which page opens first" related observation
  is ALSO resolved, by investigation, not code** (GH#94, 2026-07-13): a
  real player has ALWAYS started at page 1 (`_page_idx = 0` when not
  `_is_qa()`, unchanged since paging's introduction at `3624119`) —
  the DP2/DP5 screenshots showing the tail page are a QA-CAPTURE
  ARTIFACT (`_is_qa()` force-jumps every TestDriver-driven run, headless
  or windowed, to the last page for injected-key-count determinism, by
  design), not what a human player sees. See the UI/PICKER entry above
  for the fuller trace (same root cause, the board/delivery picker's own
  complaint).
- [x] UI/DIALOGUE — FIXED (commit `da57786`, "ARCH track complete... +
  playtest polish wave") — a paginated conversation's page break could
  split mid-sentence with no continuation cue (e.g. relc_intro's "grip.
  Sword arm, spear arm —" opening a page after "...checks your" was cut
  off the prior page). Git-history re-adjudication (GH#94, 2026-07-13)
  found this NIGHT-polish-wave item ("break at sentence boundary where
  possible + a continuation marker") already shipped in the SAME commit
  that fixed the sibling UI/TOAST fold-clip below — `dialogue_panel.gd`'s
  `_paginate` now prefers a sentence-ending break (`.`/`!`/`?`) inside the
  last `SENTENCE_BOUNDARY_WINDOW_FRACTION` (20%) of `PAGE_CHAR_BUDGET`
  (see `_sentence_boundary_cut`), falling back to a word-boundary cut with
  "…"/"…" continuation markers on both sides when no clean sentence end is
  in range. The log entry was simply never updated to reflect it — this
  closure is documentation-only, verified by reading the live code (still
  present, unmodified since `da57786`) and confirmed via `git log -S`.
- [x] ART/WATER (RIVERFARM) — FIXED (GH#94, 2026-07-13) — riverfarm's own
  river band (`data/maps/riverfarm/riverfarm_village.json`, `floor_layers`
  water segment) used `Water_tiles.png` coord `[2,7]`, PIL-verified
  PIXEL-FLAT (1 unique color across the whole 16x16 region) — the exact
  defect class the original issue #30 ART/WATER fix (below) closed for
  floodplains/sewers, but this segment lives on `floor_layers`, a
  different data path the #30 sweep's `walls.segments` scan never
  touched (disclosed open, 2026-07-09 hotfix wave 2). Swapped to `[1,5]`
  — the SAME proven-textured tile (5 distinct blue shades, PIL-verified)
  the #30 fix and `ICE_CAP_COORD` already use, reused verbatim rather than
  picking a third variant. The shimmer OVERLAY extension (`world.gd`'s
  `water_shimmer`, currently keyed to `walls.segments` water only) stays
  a SEPARATE, still-open mechanism decision per the entry's own framing —
  this closes the flat-fill half only, not the no-shimmer half.
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

## 2026-07-11 (user playtest batch 2)
- (10) ruin_surface: the dormant ruin_guardian marker REUSES the
  Raskghar sprite — confusing (reads as a Raskghar, is a construct).
  Needs a distinct dormant-guardian/statue prop — fold into the 8d A3
  pixflux prop batch.
- (25) brothers_parlor: dress further with the Pixel Crawler hideout
  pack (user pointer) — catalog/index pass, then decor entries.
- (19) witch sprite grossly over-scale vs PC — rescale + regen rides
  the #63 canon pass (named witch profile first).
- [Flame Pillar] ships ICONLESS (every flame icon claimed) — needs a
  dedicated blast icon; hotbar degrades to text label gracefully.
- ruin_surface scores 50.77 on the #73 dynamism metric — BELOW the
  pre-feedback Brothers' Hideout brown box (54.58). Genuinely
  under-dressed 5-item exterior; wants a dressing pass (multi-family
  decor + off-center focal + border band).
- trapped_halls sits at the dark-legibility EDGE (8d E2 machine
  playtest): trap tells + toasts read when adjacent, but the wide shot
  is near-black (delve_fight 04/05 shots). The user's night-dimness
  taste (batch-2 finding 22) suggests lifting the grade ~10-15%; the
  windup danger overlay was already brightened for it. USER-EYES item.
- dungeon trap-tell art still on same-family placeholders
  (dart_slit = tinted sewer_grate; illusory_floor = Cemetery debris
  crop) — carried from 8dB; PixelLab candidates palette-drifted.

## 2026-07-13 (#97 bestiary review wave)
- watchgolem + mothbear large-sprite ADJACENCY OVERLAP: when the enemy
  pair fights in adjacent columns/rows, the rear unit is partially
  occluded by the front one and the HP readouts float over each other
  (pallass_watchgolem_loop watchgolems_combat + invrisil_mothbear_loop
  mothbears_combat shots). Candidates: nudge render_scale down a step
  (~0.55), or a combat_scale override per the contained-bar rule
  (wi-art-and-sprites). Windowed-judged, controller call.
- razorbeak SOFT SEMANTIC READ: the generated sprite reads lizard-like
  (green body, ambiguous folded wings) more than "leathery-winged
  toothed bird"; passable as Erin's "Dino Bird" nickname but a regen
  pass with wing/beak emphasis is worth one more candidate batch.
- razorbeak_nest resolves in the TRAINING_YARD arena — a wild-fauna
  fight among training dummies/pells reads wrong. Re-point to
  boulder_flats or a dedicated grass-scrape arena later (data-only,
  one field). **FIXED (GH#94, 2026-07-13)**: `arena` re-pointed
  `training_yard` -> `boulder_flats` (`data/maps/floodplains/
  floodplains.json`) -- same floodplains biome the encounter's field
  placement already lives in, open grass + scattered boulder cover, zero
  training dummies. `sim_combat_batch.gd`'s `razorbeak_nest_t1_solo`
  MEASURED cell re-pointed + re-run clean (win_rate=1.00). REVIEW
  CORRECTION (same day): an arena is NOT presentation-only — two
  sim-facing reads. (1) `blocked` cells feed combat walls/LoS
  (training_yard 0 → boulder_flats 4 cover boulders, real geometry, held
  at 1.00 anyway). (2) training_yard carries `trivial: true` (the spar
  arena's no-progression flag, inherited here by mistake at #97), which
  suppressed ALL action-tally banking on razorbeak kills — the re-point
  FLIPPED class-progression banking ON for wild culls (fiction-correct;
  the bounty's own `on_victory` counter was never gated either way).
  Disclosed in the encounter's `_comment` + the harness doc block.
  Windowed-verified via a throwaway teleport+autoplay probe (deleted):
  the pair now fights on open grass among boulders, no dummies/pells
  anywhere in frame.

## 2026-07-15 (user playtest report)
- Props y-sort OVER the player sprite in the inn — named repros: stairs,
  rugs, bed (rugs are floor decor and should never win the sort; stairs/
  bed likely need `field_y_sort_bias_px` or a below-sort floor band).
  Filed as GH#127; sweep other maps for the same class when fixing.

## 2026-07-16 (class expansion Wave A)
- PixelLab drain: replace the nine code-drawn placeholder skill icons for
  `hedge_remedy`, `evil_eye`, `bone_dart`, `deathbolt`, `detect_magic`,
  `advanced_cooking`, `signature_dish`, `eagle_eyes`, and `marked_quarry`.
  - DRAINED 2026-07-16 (#145): picked PixelLab reductions now replace all
    nine tracked placeholders.
- Prop-fit drain: replace the loose stock reads for `inn_witch_kettle`
  (`cauldron`), `inn_copper_pan`/`pallass_stall_burner` (`grill`),
  `cellar_wardwork` (`dusty_scroll`), `lift_overlook`/`rooftop_line`
  (`riverfarm_fence_ew`), `anchor_socket` (`pedestal`), and
  `hilltop_cairn` (`boulder`) with purpose-drawn sprites in a later art pass.

## 2026-07-16 (#133 parlor population)
- ratici sprite = pc_drake_m + brown tint PLACEHOLDER — canon wants a
  SHORT Drake with a floppy cap (neck-spines); bespoke PixelLab pass
  queued (pair silhouette vs tall Wilovan is the read).
  - DRAINED 2026-07-16 (#145): bespoke teal directional idle/walk rig wired.
- parlor_hat_stand sprite = crate PLACEHOLDER (no rack/hook stock
  registered) — the hats-off tell deserves a real hat-stand sprite.
  - DRAINED 2026-07-16 (#145): picked two-hat stand prop wired.
- unnamed gentlemen ride human_laborer/gnoll_traveler/drake_patron
  bases with tints; bowler/coat reads live in observe copy only.

## 2026-07-16 (class expansion Wave B)
- PixelLab drain: replace the five code-drawn placeholder skill icons for
  `double_step`, `flash_step`, `animate_dead`, `hearthward_charm`, and
  `greater_hearthward`.
  - DRAINED 2026-07-16 (#145): picked PixelLab reductions now replace all
    five tracked placeholders.

## 2026-07-17 — Wave D-2 (#156) placeholders

- **8 tamer/druid kit icons are crude generated glyphs** (`icon_healthy_rearing`,
  `icon_animals_basic_command`, `icon_lesser_bond`, `icon_beasts_mending`,
  `icon_wild_affinity`, `icon_pack_bond`, `icon_peace_of_the_wild`,
  `icon_thorn_hand`) — PixelLab pass user-gated, same drain class as the
  D-1 alchemist five.
- **wolf_den / razorbeak_chick / wounded_corusdeer props reuse ADULT
  combatant sheets** (river_wolf / razorbeak / corusdeer at prop scale) — a
  pup-sized wolf, a chick, and a LYING wounded corusdeer want bespoke
  frames (PixelLab, user-gated).
- **wolf_companion / razorbeak_companion follower visuals alias the same
  adult sheets at reduced render_scale** (0.26 / 0.6) — reads fine in
  motion; bespoke pup/chick idles would land with the prop pass above.
- [x] b1 #199: Rags INTERIM sprite RETIRED 2026-07-20 — bespoke child-sized v3 rig shipped (PR #267, user FEEL-approved); the goblin_sword reduction is gone
  entity tint — replace wholesale with the c3 bespoke (small frame, black
  hair, crimson eyes, rag-browns per profile); swap the sprites.json `rags`
  entry + test_sprite_registry count rows together.
- [ ] b5 #220: three boulevard shopfront observes (glazier/cordwainer/
  teahouse, wall cells 6,1 / 15,1 / 7,1) ship hide_sprite — optional
  c-lane decor sprites would give the wall fronts a visual read.
- **pond_edge (floodplains 9,17) is placeholder-grade** (b7 #214c,
  2026-07-19): grass_tuft + cool tint standing in for a reeds/ripple
  marker on the pond's water-wall cell. c-lane art pass: a bespoke
  reed-cluster or ripple sprite; keep it readable against the
  Water_tiles band and the pond-shimmer overlay if that lands.
- **Combat HP labels bleed through the pause panel** (seen in a3 #215's
  04b shot, pre-existing — the combat pause was always reachable via
  keyboard): the 32/32 / 21/21 combatant labels render OVER the pause
  parchment. Layering fix: pause layer above the board's label layer,
  or hide combat labels while paused.

### v0.16 Invrisil depth (#306) — windowed pass 2026-07-28

Nine new canonicals shot windowed on the real asset overlay (md5-censused
against main first, 370 files, spot-check identical). Every finding below
cites the shot it came from; the two that were CHEAP AND IN-LANE were fixed
in the same wave rather than logged as owed.

- [x] **`mercantile_alley` renders its board figures near-BLACK at night**
  (`invrisil_setting_fight/02_the_fence_pair_on_the_board.png`). Measured as
  a real before/after pair, same seed, same rigs, only the fixture's
  `actions_since_sleep` changed: at night the fence and the doorman are
  barely separable from the floor and from each other; at day all three
  silhouettes and every HP numeral read cleanly. **Fixed in-lane** by
  shipping `invrisil_setting_fight_start` at day — per ruling F that board
  shot is the ONLY legibility read the two new rigs get, so the phase that
  can be read wins. NOTE FOR THE ARENA OWNER: this is an ARENA finding, not
  a rig one. Every shipped alley fight runs at day (`near_invrisil` is
  `actions_since_sleep` 0), so this lane's fixture was the first to stage
  that arena at night and nothing else has hit it yet. The next night fight
  staged in the alleys will. `merchant_warehouse` at night is fine
  (`invrisil_hat_loud/02_the_bravos_on_the_board.png` — warm brick, both
  bravo rigs separable at a glance).
- [x] **The Rest's fight said THREE and the board showed TWO** — caught by
  adversarial review, not by the Task 5.5 windowed read, and that is the
  lesson: the shot above was read for tint/silhouette separation and passed,
  while nobody counted the figures against the copy. `rest_bravos` shipped
  `display_name` "Three at the Far Table", an `observe` and a
  `gate_closed_toast` all saying three men, against an `enemies` pair. Per
  ruling F this pair of rigs gets no `test_combat_visuals` measurement, so
  the windowed shot was the only gate and it was the wrong question.
  **Fixed in-lane** by re-wording all three strings to "two" (a third rig
  would have re-opened the measured 0.78 harness cell and the derived
  `rng_state`). **Standing check for every future board read: count the
  figures against the encounter's own copy**, not just their legibility.
- [x] **Both new interiors render FLAT at dusk** — the hearth pool, both
  sconce pools, the wall-band bounce and the `dust_motes` ambience were all
  invisible in the first dusk pass, and all four read at night. Cause: these
  interiors are mood-INVARIANT across phases by regional convention
  (`brothers_parlor` ships the same single tuple for day/dusk/night), so a
  1.1-energy radius-40 light has nothing to show against a flat 0.86 tint;
  `ui_lights_rendered` confirmed the lights were REGISTERED (count 3 in
  `adventurers_rest`) the whole time, just invisible. **Fixed in-lane** by
  shipping both loop fixtures at night. Left OPEN as a design question for
  the mood owner: a windowless interior that is phase-flat can never show
  its own lamps at dusk — either those interiors want a dusk tint a notch
  under their day one, or entity lights in flat-mood rooms want more energy.
- [ ] **The two new facade doors are easy to miss on the boulevard band**
  (`adventurers_rest_loop/01_two_doors_on_one_facade.png`): both use the
  generic `door` sprite and sit in a shopfront band of similarly sized
  window props, and the door the player is standing under is largely
  occluded by the player sprite itself. Not a blocker (bump + interact +
  the display_name), but a distinct shopfront-door sprite or a hanging sign
  would make the facade read "you can go in here" without standing on it.
  Same family as the open b5 #220 shopfront-observe entry above.
- [x] **`hearth` is a cold-grey iron sprite with no fire frame**
  (`adventurers_rest_loop/03_the_hearth.png`): at night the entity light
  sells it, but the sprite itself reads as an unlit oven against copy that
  says "kept fed accordingly". A lit-hearth frame (or a fire overlay prop)
  would close the gap between the art and the line.
  **DRAINED 2026-08-05 (#390).** The cause was worse than "unlit": the old
  region `[272,56,64,104]` on free_pack `Interior_Props_01` straddled TWO oven
  variants on that sheet, so the prop was a composite of two half-ovens and
  could never have held a fire. Replaced with an OWNED PixelLab lit hearth
  (stone surround, mantel, flame and embers in the mouth) on the SAME id, so
  all five consumers inherit it with no map edit; `cold_hearth` stays the
  separate dead-hearth sprite for `hut_hearth_ash`, whose copy says the ash is
  years cold. Evidence: real BEFORE at the lane base (path-limited `git stash`
  + re-import), AFTER on the branch, same script and seed --
  `lanes/l390-evidence/hearth_inengine_pair.png` (`lanes/l390-evidence/before_03_the_hearth.png` vs
  `after_03_the_hearth.png`, `adventurers_rest_loop windowed --seed=9`).
  The fire throws visible warm spill onto the boards, which is what makes
  "the chairs nearest it are the warmest in the house" true on screen.
- [ ] **Windowed capture stalled once mid-run** (`invrisil_hat_quiet`, first
  windowed attempt): the run reached its last banked counter and then hung
  before the final screenshot; the alarm killed `run_qa.sh` but left the
  godot child alive. Killing the child and re-running passed with all three
  shots. Headless is unaffected (green individually and in the full sweep).
  Logged as a harness flake to watch, not a script defect.
## 2026-07-28 (#308, v0.16 Floodplains) — three new rigs ship UNMEASURED by the board-figure bar

`goblin_spear_ally` reuses `goblin_base`, `rags_ally` reuses the bespoke `rags`
rig, and `plains_scavenger_a/b/lead` reuse `human_laborer` — all with NO
`combat_scale` key, so their board figures are byte-identical to what ships
today. **None of these sprites is in `FIGURE_ROWS` and none of these ids is in
the `audited` array**, so `test_combat_visuals` does not measure them; it passes
by exclusion. No figure number is asserted or claimed here. Filed for the
goblin-scale triage pass alongside `goblin_raider` / `goblin_shaman` /
`goblin_chieftain`, each of which needs its own windowed read before its scale
moves (HANDOFF.md:63-67). The FIRST evidence about these rigs' legibility is
this PR's windowed machine-playtest shot of the `camp_ground_press` board —
including whether the three `human_laborer` scavengers, which ship
near-identical warm tints (0.86/0.78/0.62, 0.80/0.74/0.60, 0.90/0.70/0.55) on
one board, separate by eye. Nothing in the suite checks that: the tint-uniqueness
assert at `tests/test_combat_visuals.gd:544-556` covers only the hard-coded
`camouflage` list.

## 2026-07-28 (#308, v0.16 Floodplains) — the windowed read those rigs were waiting on

Eleven windowed shots, seed 9, real asset overlay, read by eye
(`floodplains_price_talk` / `_help` / `_fight` windowed, plus four throwaway
shot scripts for the phase ladder, the can-fail mouth pair, and a synthetic
all-routes `winter` node; the throwaways were deleted after capture). Logic was
green before any of this — every row below is eyes-only, and none of it is a
blocker.

- **ANSWERED, the row above's open question: the three `plains_scavenger_*` DO
  read as one mass.** On the `camp_ground_press` board all three render the same
  `human_laborer` silhouette at the same height, and the shipped tint deltas
  (~0.06 in a channel) are below perceptual threshold at sprite size — the only
  thing separating them on screen is their HP numbers (30/30, 34/34, 30/30).
  Re-tint on a real axis (value, not hue nudge) or give the lead a distinct rig.
- **`goblin_spear_ally` is the least legible unit on the board** — a green-tinted
  `goblin_base` at a smaller figure height, on a `boulder_flats` arena that is
  mostly green. It is findable only by its ally-green HP bar.
- **Ally/enemy separability overall is GOOD.** Green vs orange HP bars carry it
  cleanly, and the turn banner names all six combatants in initiative order
  ("Turn — Rags | > Traveler | Plains Scavenger B | The Band's Lead | A Goblin
  with a Spear | Plains Scavenger A"). The goblin figures read fine beside the
  human rigs; the problem is scavenger-vs-scavenger, not goblin-vs-human.
- **`rags_camp_mouth` does not read as an entrance.** It renders as a small
  grey-green `boulder` — on the same screen as ordinary boulder decor it is
  indistinguishable from scenery, and it is the ONLY seam into the new interior.
  Rags's directions ("South. Cut in turf. Two stones.") are doing all the work.
  Wants a doorway-shaped sprite or a much stronger value contrast.
  **FIXED in the #308 fix wave (2026-07-28):** new owned PixelLab sprite
  `turf_cut_mouth` (stones leaning over a dark cut, grass over the lip). Read
  windowed at floodplains (17,20): it now carries a black opening at sprite
  size and separates cleanly from the `boulder` decor in the same frame.
- **Two props are semantically wrong for their own copy.** `camp_hide_racks`
  ("green hides pegged out on a lattice of spear-shafts") renders as
  `request_board`, a parchment notice board; `camp_meat_rack` ("a rack of split
  poles over a bed of ash") renders as `barrel`. The common-sense pass fails on
  both — the interact copy is right, the sprite argues with it.
  **FIXED in the #308 fix wave (2026-07-28):** three more owned PixelLab
  sprites — `hide_rack` (hides pegged between two posts), `drying_rack` (bare
  pole frame over an ash bed) and `drying_rack_hung` (the same frame under
  strips of cut meat), anchors measured off each alpha bbox. The rack's filled
  state is now a real second entity on the same cell, so the fill READS: the
  windowed pair `01_rags_camp_arrival` / `02_rags_camp_rack_hung` on
  `floodplains_price_help` shows bare poles becoming a hung rack in place.
- **The `rags_camp` mood row TOOK, all three phases.** Day / dusk / night are
  clearly distinct (bright green → muted olive+vignette → dark warm brown), and
  dusk/night carry the `dust_motes` ambience. Nothing renders flat white.
  **But the fire pit casts no light** — the mood `_comment` promises "firelight
  only after dusk" and the hollow has no light anchor, so at night the fire is
  embers on a dark field. One small warm light would sell the room.
- **Copy nit:** the ally-announce renders "Rags and A Goblin with a Spear wade in
  beside you." — a capital `A` mid-sentence, because the display name is used raw.
- **Dialogue panel load, for the merge train:** Krshia's hub now shows SIX
  visible rows and Rags's `winter` node FIVE (all three report rungs at once on a
  synthetic all-routes state). Nothing clips — the panel auto-grows upward — but
  at six rows it occupies ~45% of the window and fully occludes the speaker
  standing directly south of the player. Two more shipped rows on either hub and
  that is a real legibility call, not a nit.
- Confirmed by eye, the can-fail pair: at (17,21) the camp mouth is PRESENT on a
  settled fixture and ABSENT on `rags_gate_unmet_start` — bare grass, same frame.

## 2026-07-28 (v0.16.1 ART lane) — the pc_* sweep, what shipped and what is still owed

Six owned PixelLab v3 rigs landed (`invrisil_lady_client`, `master_coyle`,
`hedault`, `city_scribe`, `city_runner`, `coyle_shop_sign`) and all 16 map rows
that wore a `pc_*` id were re-cast. `test_sprite_registry.gd` now reds on any
`pc_*` reference from a map entity/decor/visual_states row, so this class cannot
regress. Read windowed at the stationer, the Rest, the boulevard facade, the
Guild and the Brothers' parlor — shots under `qa_output/v0161_art/`.

Residuals, deliberately left and logged rather than silently patched:

- [x] SPRITE/WILOVAN — `wilovan` is an ID, not yet bespoke ART. The sprites.json
  entry still points at `pc_gnoll_m`'s sheets, so a Gnoll-male PC still meets a
  copy of himself in the parlor and at the inn. Moving `brothers_parlor/wilovan`
  onto the `wilovan` id was still the right first step (one character, one rig,
  gate-clean, and `combatants.json` keys on it) — but the bespoke Gnoll rig the
  entry's own `_comment` promises is still owed. Same for `krshia`, now on
  `gnoll_traveler` + a brown tint: species-correct and no longer the PC's skin,
  but a canon named [Shopkeeper] sharing the generic traveler rig with Xif.
  **CARRIED (v0.19 L4) — await PixelLab top-up (user decision).** A named
  character needs the v2 4-direction character pipeline plus animate-character
  (walk + idle per facing); at the measured balance ($1.53 credits, 0
  subscription generations) one rig would consume the lane's whole envelope
  and still not finish. No pack rig passes the silhouette bar: the registry's
  Gnoll rigs are the PC's own skins, and reusing one is the exact defect this
  row records.
- [x] SPRITE/SPECIES — `selys` and `octavia` still wear `citizen_f`, a human
  woman, while Selys is a Drake and Octavia a Stitch-girl. Named in the triage
  as species errors; out of this lane's five-item budget, untouched here.
  **CARRIED (v0.19 L4) — await PixelLab top-up (user decision).** Two bespoke
  rigs (a Drake woman and a Stitch-girl); no pack in the tree ships either
  species, so pack-first has nothing to offer and the fix is generation-only.
- [x] SPRITE/ILVO — Ilvo wears `tier_clerk`, a Pallass civic rig (bronze guild
  sash), because the registry holds exactly two Drake civilian rigs and Renn
  needed the other one four cells away. It reads as a slim coated Drake beside
  Renn's bulk — the adjacency defect is gone — but a Liscor-native Drake rig
  would be the honest fix.
  **CARRIED (v0.19 L4) — await PixelLab top-up (user decision).** The honest
  fix is a third Drake civilian rig; the registry has two and both are spoken
  for, so this is generation-only at a balance that cannot fund a rig.
  **DRAINED 2026-08-04 (#390).** The "cannot fund a rig" arithmetic was wrong
  by roughly 12x: a v3 8-direction rig is **2 generations (~$0.13)**, not an
  envelope. Five bespoke rigs + a Pisces regeneration + idle animation cost
  ~$0.30 of the $1.44 balance. `selys`, `krshia`, `octavia`, `ilvo` and
  `wilovan` all ship as OWNED PixelLab v3 rigs with anchors measured from the
  alpha bbox; every stand-in tint is retired. Krshia took a SECOND pass on a
  user read (the first came back an armored brawler, not a merchant) and the
  reject was parked, then reused as `gnoll_ranger` for the Gnoll with a Bad
  Ankle. Wilovan is IDLE-ONLY: he is a fielded combatant, so his
  walk/slice/cast/hit/death set is still owed and tracked on #390.
- [ ] COPY-VS-ART — `gentleman_bowler` ("A broad man in a bowler hat") now wears
  `hired_blade`, which has a goatee and a burgundy coat and no bowler. Not a
  regression (`human_laborer` had no bowler either) and it reads well in a den
  of gentleman thieves, but the hat is still only in the prose.
- [ ] TINT — six NPC tints were re-tuned in this lane because they had been
  chosen against `human_laborer`'s light apron and went near-silhouette on the
  darker new rigs. Any future rig swap must re-read the tint, not carry it.

## 2026-07-29 — GH#330 Beast Tamer dynamism (windowed reads)

Read and passed:

- **The healed corusdeer stands.** `corusdeer_doe` (owned PixelLab rig,
  2026-07-06 expansion batch) is registered and rides `wounded_corusdeer`'s
  `visual_states` at `tended_beasts` 10. The windowed read
  (`qa_output/gh330/00_deer_standing.png`) shows an upright tawny deer where a
  dull lying one used to be — the stand-up beat lands without a line of copy.
  Scale matches the shipped `corusdeer` (0.7) so the animal does not change
  size when it changes posture; anchor measured off the alpha bbox.
- **The lamb pen.** Three `riverfarm_fence_ew` panels (entity + two decor
  flanks, both blocked) read as a continuous rail run beside the hunter's
  cottage, matching the map's own western fence line.
- **The wolf's cache** and **the razorbeak's vantage** both read at a glance
  (`gnaw_pile` bone scatter; `boulder` beside the pond, with the sunken crate
  visible in the same frame the vantage's hint names).

Residuals, logged rather than silently shipped:

- [x] PROP/BEDDED-GRASS — `worn_grass_bed` is the free-pack Vegetation grass
  tuft at prop scale (1.6) with a straw tint. The FIRST pick (`grass_tuft` at
  0.75) was invisible against the grass floor in the windowed read — a real
  fails-to-read defect, caught only by the shot. The scaled version is legible
  as an object but is still a clump of blades, not the body-shaped hollow the
  copy describes. A bespoke bedded-hollow prop (with the shed antler lying in
  it) is the honest fix.
  **DRAINED 2026-08-05 (#390)** — built exactly as this row specified, antler
  included: an oval of flattened dry stalks with the shed antler lying in it,
  so the pickup the copy names is IN the art. Anchor measured off the alpha
  bbox (53/64), scale holds the ~26px footprint the tuft-at-1.6 had.
  Evidence `lanes/l390-evidence/worn_grass_bed_pair_4x.png` (shipped tuft vs
  new prop, same compositor, real floodplains grass tile, 1x and 4x).
- [x] PROP/NO-LAMBS — the Hunter's Lamb Pen has fencing and no lambs. The
  animals live entirely in the display name, the observe, and the tend toasts.
  A small lamb sprite inside the rails would make the pen read as a pen rather
  than as a fence.
  **WIRED 2026-08-05 (#396 lane C) — the in-engine shot #390 owed.** The rail
  run now holds three animals on one visible row: `lamb_lying` at (15,11) and
  `lamb` at (17,11) as DECOR on the rail's own already-blocked cells (no
  walkability, entity-count or approach-cell change), and `makings_tend_lamb` —
  the limping third the observe names, and `the_makings`' tend beat — as a
  quest-gated prop at (18,11), under the east panel's own art. Windowed read
  (`lanes/l396c-evidence/02_pen_lambs_tend.png`, zoom
  `pen_lambs_zoom_2x.png`, from `makings_loop`): lying and standing read as
  two different animals at gameplay zoom, and the pen reads as a pen.
  Residual, not a blocker: the limping third reuses `lamb_lying`, so it is the
  standing ewe that separates the two lying silhouettes and the interactive
  lamb is told apart by its affordance and name, not its posture. A third
  posture rig (standing wrong on a foreleg) would close that inch.
  **SPRITE DRAINED 2026-08-05 (#390).** Two rigs, not one
  retint: `lamb` (standing) and `lamb_lying` (curled on the ground) — distinct
  silhouettes per the tint directive, and the pair matches #396's own observe
  copy ("two ewe lambs inside it, and a third that will not put weight on a
  foreleg"). Both scaled to sit UNDER the pen rail (~15px and ~11px).
  Controller ruling: this branch ships sprites only, because
  `riverfarm_village.json` belongs to #396's branch — whoever lands those rows
  owes the in-engine shot. Evidence `lanes/l390-evidence/lamb_pen_pair_4x.png`
  (bare rail vs rail + both lambs, on the real riverfarm grass tile).
- [x] SPRITE/DOE-VS-STAG — the healed animal swaps onto a DOE rig, so the
  antlers the observe line describes ("its antlers barely glow") become the
  doe's ember nubs at the moment it stands. Species and palette are right and
  the shed-antler pickup still reads; a stag-shaped standing rig would close
  the last inch.
  **DRAINED 2026-08-05 (#390).** `corusdeer_stag` — tall branching antlers,
  tawny to match both shipped corusdeer rigs, with the antler TIPS
  ember-warmed (58px, keyline pixels left dark) so "barely glow" still lands
  rather than being contradicted by a plain brown deer. Wired by swapping the
  `sprite` field inside `wounded_corusdeer`'s existing `visual_states` arm —
  same `when`/`counter`/`at`, same tint, nothing else in floodplains touched.
  Evidence `lanes/l390-evidence/corusdeer_stag_pair_4x.png` (live doe rig vs
  stag, same compositor and grass tile) plus the 8x tip read parked in
  `potential_assets/pixellab_2026-08-05_390/stag_ember_8x.png`. TRADE, stated:
  the doe rig is a 4-frame idle and the stag is 1 frame, so the standing deer
  no longer breathes — the same shape as the shipped `corusdeer` base rig
  (also fps 1), and species-correct-and-still beats wrong-species-and-moving.

## 2026-08-02 wave-2 art drain (PR #344, controller reads on file)
- ruin_gate wired at floodplains (38,11) — the note-6 "ruins look like a
  rock" cure; the #74-era hard-stall site finally has findable art.
- rune_door at trapped_halls seal (imposing = correct for the vault).
- wardstone_anchor on dungeon_approach (the new portal carrier).
- witch_cauldron in the inn kitchen — silhouette differentiation per the
  tint≠disambiguation directive; decor pots untouched.
- STILL OPEN from prior lists: readout-eats-interior-bottom-rows (P3),
  line_stalker two-headed overlap, scavenger-vs-scavenger sameness,
  stationer mood phase-flat, ward-scrap lore toast slicing — all queue
  for v0.17 L4 (art lane) with the tint-site audit (pot tints, blade
  banding).

## 2026-08-02 v0.17 L4 (art lane) — drain, tint audit, palette pass
<!-- v017-L4 -->

**Drained** (six rows, each windowed before/after; all six re-verified as
still reproducing on this tree BEFORE any fix — none were stale):
PROP/TEMPER-BENCH-INDISTINGUISHABLE, PROP/WAX-TRAY-IS-A-CRATE,
DECOR/DEN-SHOP-STREET-LAMP-INDOORS, DECOR/REST-RUG-READS-AS-HOLE +
DECOR/DEN-SHOP-RUG-READS-AS-HOLE (one root, five sites),
SPRITE/CAMP-WATCH-GOBLIN-INVISIBLE, DECOR/FORGE-MOLTEN-SEAM-HARD-RECT.
Three new owned sprites (temper_bench, wax_seal_tray, shop_oil_lamp) and
two new owned rug weaves; anchors measured off the alpha bbox with the
new `scripts/sprite_alpha_probe.py`, never off the frame.

**Tint-site audit** (directive: TINT IS NOT DISAMBIGUATION). 153 tint
rows across data/maps were enumerated and classified. Cosmetic variety
WITHIN one kind — dungeon_statue/dungeon_rubble/facade_plaster/inn_roof
crowd variation, the three note_pinned notes — is sanctioned and stays.
Sites where tint was carrying a FUNCTIONAL or IDENTITY difference, i.e.
the banned use:
- **FIXED**: `forge_hall_temper_bench` (was the same forge sprite as its
  two neighbours), the den-shop lamp, the rug family.
- **OPEN, and the sharpest remaining one**: `stew_pot` (4,1) and
  `short_order` (1,1) are BOTH the `cauldron` sprite in the inn's one
  kitchen band, both `basic_cooking` interactables, both banking
  different accomplishments — separated by nothing but a warm/cool
  tint. `inn_witch_kettle` already got its own silhouette in the wave-2
  drain; these two still need a second pot form (a flat short-order
  griddle is the obvious read for the copy: "three plates, one order").
  Needs a new sprite id, which needs the registry counts key — see the
  ownership note in .lane-progress.
- **OPEN, rig-sharing rather than tint per se**: `drake_patron` backs
  FIVE named characters (vess, renn, forge_apprentice, forge_smith,
  den_shop_keeper) and `royal_soldier` three, each separated only by
  tint. No two are co-visible on one map, so this is below the
  co-visibility bar the v0.16.1 policy sets — but it is the same class
  as the Lady-as-pc_human_f finding and wants bespoke rigs eventually.
- **OPEN, not ours**: `goblin_spear_ally` and the BOARD/TINT-NUMERAL-
  CONTRAST row are combatant tints (combat data, L2's ownership).

**Palette unification** — 271 tracked sheets re-seated on ramps derived
from PC16, 8 rigs excluded by the damage guard. Windowed before/after
pairs at `qa_output/_l4_palette_{before,after}/`:
`inn_common_room.png` (5.6% of pixels moved), `interior_rest_hall.png`
(5.1%), `exterior_rags_camp.png` (1.3%), `arena_forge_hall_board.png`
(81.5%). The arena pair is the one to open first: the forge-hall slate
moves off a warm brown-grey that fought the golem's embers and the
torch flames, onto a cool neutral stone, and the warm props stop
blending into the floor. No banding or identity loss in any pair.

**Scope note for whoever runs the palette pass next.** It only touches
git-TRACKED assets, by construction — the private bundle overlay is
gitignored and has no original in this repo, so it is out of scope and
must stay out. That means most painterly CUSTOM-HD rigs (the goblins,
bat, river_wolf, shield_spider) are NOT yet unified: they live in the
overlay. Finishing them needs a bundle-aware run with the bundle in
hand and its own preserved originals.

**Still open, art-addressable, NOT taken this wave**: the three
remaining PROP/CRATE-READS-AS-CLUTTER members (den-shop receiving dock,
lift cargo pallet, forge reject bin) and BOARD/CRATE-COVER-READ — all
want new sprite ids; `line_stalker_a`/`_b` and the `plains_scavenger_*`
overlap rows are spawn-cell choices in arena data, not art.

<!-- v017-R1 -->
## 2026-08-02 — #350 the room you buy (rider R1)

**WANTED, art-addressable, NOT blocking**: a `door_named` sprite — a
guest-room door with a name card in the frame — so the player's own door
is legible at a glance in the inn's upper hall. Today `hallway_door_a`,
`hallway_door_b` and `lyonette_door` all draw the SAME `door` sprite in
one row, and the only ownership tell after the purchase is the door's
`observe` line swapping through `visual_states`. A tint would not fix
this (tint is not disambiguation); it wants a distinct silhouette. The
gate, the copy and the QA proof all ship without it.

**Observed while shooting `player_room_loop` windowed, systemic and not
this room's to fix**: an interior `sconce` reads as a dark smudge at DAY
in every room that uses one (`moods.meta.light_energy_by_phase.day` is
0.0, and the `lights_by_day` opt-out is set on `seal_vault` alone). The
new room's own sconce is the shipped stationer idiom verbatim, so it
inherits the same flat daytime read.

**`inn_player_room` composition**: scene_dynamism composite **68.77**
(c1 21.98 / c2 23.50 / c3 23.30), the highest score in the report's
interior band — but c2 is inflated: the map has no `REGION_GROUPS` entry
in `tools/scene_dynamism.gd`, so it scored as its own singleton with
nothing to be distinct FROM. Seam filed for the train.
<!-- v017-R2 -->
### v0.17 R2 — moods/atmosphere re-tune (post-palette rider), 2026-08-02

Data-only pass except for one lint arm (`scripts/data_lint.py:check_moods`,
added in the fix wave — see the last row). Evidence:
`mood_sheet_{day,dusk,night}` — a new non-canonical windowed peek triptych that
teleports one fixture through SEVENTEEN maps (every exterior beside the
interior you reach from it) so the whole lighting language can be read in one
frame set. Archived at
`art-feel-review/v017-r2-moods/` (deliberately NOT under `qa_output/`, which
every full `ci_sweep.sh` flushes): `{before,after}/` are the pass's own 13-map
pair, `{fix_before,fix_after}/` the fix wave's 17-map pair, with
`measurements.csv` / `fixwave_measurements.csv` beside them (mean luma + mean
R−B per frame). NOTE on reading them: frames are reproducible to ±0.2 luma,
NOT byte-identical — idle sprite animation and light flicker are wall-clock
driven, so two runs of identical data differ on any map that has either.

THE LANGUAGE, stated once so the next pass does not re-derive it
(`t = r - b`, `v = mean(rgb)`, per mood card):
- **RULE 1 — a map WITH a sky** (day != dusk, world.gd's own `_map_has_sky`
  test): the sky owns the grade, so it cools and darkens monotonically —
  `t(day) > t(dusk) > t(night)` and `v` likewise.
- **RULE 2 — a map WITHOUT a sky** (day == dusk): the FLAME owns the warmth,
  never the grade. The grade may be cool or neutral, never warm (`t <= +0.03`),
  and a sealed room that owns light rows carries `lights_by_day: true` so those
  sources actually burn. This generalises seal_vault's shipped rationale.
  Which maps ARE sealed is an authored call — `_map_has_sky` reads the
  day-vs-dusk pin this same file writes — so the rules buy consistency after
  the call, not the call itself. Both are enforced by
  `scripts/data_lint.py:check_moods`, and RULE 2's ceiling is one-sided: it
  forbids a warm grade, it does not license a cold one (see the forge row).

Rows this pass closes or moves:

- [x] **LIGHT/INTERIORS-AND-DUSK-ARE-ONE-TEMPERATURE (the visual-next-level
  spec's §3 named defect) — DRAINED.** Measured on screen, before: at dusk the
  six warm interiors sat at `+63.9 / +55.9 / +82.6 / +42.1 / +77.8 / +51.1`
  mean R−B (inn, inn_upstairs, guild, riverfarm_longhouse, brothers_parlor,
  adventurers_rest) — one amber, six rooms, and `inn_upstairs`' card was
  literally the inn's DUSK triple reused verbatim. After: `+31.2 / +32.6 /
  +48.9 / +18.0 / +45.9 / +26.5`, against exteriors unchanged at `+14.3 / +1.4
  / +17.0 / −0.6`. The remaining interior warmth is now the WOOD, not a filter.
- [x] **LIGHT/NIGHT-IS-WARMER-THAN-DUSK (systemic, previously unlogged) —
  DRAINED.** `street`, `floodplains`, `invrisil_boulevard` and
  `mercantile_alleys` all finished the night WARMER than their own dusk (e.g.
  street t −0.30 → −0.24): the sun set and then came halfway back. RULE 1
  monotonicity now holds on all 29 cards, `guild`/`rags_camp` included.
- [x] **MOOD/RIVERFARM-LONGHOUSE-HAS-NO-CARD (NEW, found this pass) —
  DRAINED, and re-DRAINED in the fix wave.** The map had no `moods.json` entry
  at all, so it fell through `apply()`'s identity fallback at every phase while
  its hearth and two sconces switched on only at dusk — brighter in the middle
  of the night than the middle of the day, and the only interior in the game
  with no vignette. The card written for it then pinned day to identity against
  a blue dusk, which is a SKY pin: `_map_has_sky` returned true and the hall's
  hearth plus both sconces went dark at noon again
  (`fix_before/day/07_riverfarm_longhouse.png` — a bright room with a grey
  dead stove in it, the adventurers_rest defect on a fresh card). The hall has
  no window prop anywhere in its decor, so it is SEALED like every other
  windowless room: one pin `[.64,.68,.76]` + `lights_by_day`, hearth and
  sconces burning at every hour (`fix_after/day/07_riverfarm_longhouse.png`).
  Measured 54.1 / 54.2 / 54.2 luma at +14.3 R−B, flat across the clock by
  construction.
- [x] **MOOD/GARDEN-CARD-IS-DEAD-DATA (NEW, found this pass) — DRAINED.**
  `moods.moods.garden` names no map (the id is `garden_sanctuary`), so the
  sanctuary's carefully-authored "never dims" card has never once been read.
  Renamed. The rename alone would have flipped the map from has-sky to no-sky
  and un-gated the biome's fireflies into a day-identity frame, so
  `garden_sanctuary.json` gains an explicit ambience row stating today's
  effective behaviour — see its `_comment_ambience`.
- [x] **DECOR/RAGS-CAMP-FAKES-ITS-FIRELIGHT (NEW) — DRAINED.** The card said
  "firelight only after dusk" and delivered it by tipping the whole grade warm
  on a map with zero light rows. `camp_fire_pit` is now a light.
- [x] **DECOR/GUILD-HALL-HAS-NO-LIGHT-SOURCE (NEW) — DRAINED.** The flattest-lit
  room in the game: highest chroma of any map at every phase, warmer at
  midnight than the inn at noon, and not one lamp in it. Two wall sconces at
  (4,1)/(11,1); `blocked_cells` stays 57 (`guild_interior_walkthrough` green).
- [x] **DECOR/FORGE-HALL-HAS-NO-LIGHT-SOURCE (NEW) — DRAINED.** Same shape:
  t +0.42 at every phase, two `forge_station` decor rows, no light. One of the
  two now carries its twin's molten-orange flicker (one hot mouth reads as a
  working forge; a matched pair reads as a decal).
- [x] **USER-EYES item 4, `pallass_market` / `pallass_forge` lights by day —
  ANSWERED BY DERIVATION, no user gate spent** (wave-autonomy directive
  2026-07-28). **Forge YES, market NO.** The forge tier's day and dusk grades
  are identical, so by world.gd's own sky test it has no sky and seal_vault's
  rationale applies unchanged; the market's grade DOES track the sun, so the
  shipped "a lantern adds nothing at noon" default is right there. Same key,
  opposite answers, and the reason is in the data rather than in taste. If your
  eyes disagree on the market, the change is one key.
- [x] **LIGHT/FORGE-READS-COLD (NEW, fix wave) — DRAINED.** Trimming the two
  forge cards for RULE 2 overshot and pushed both rooms NET-COLD: measured
  −11.1 (`pallass_forge`) and −11.4 (`pallass_forge_hall`) mean R−B, colder
  than the sewers, on the two rooms whose fiction is banked coal. RULE 2 was
  satisfied the whole time — it bounds warm grades, not cold ones — which is
  the olive-interiors lesson in the opposite direction. Both cards are now
  NEUTRAL (`[.85,.85,.85]`; forge_hall's edit is hue-only at its existing
  value, so the room is exactly as dark as it was), `forge_station_a`'s banked
  mouth reaches the floor (0.8@26 → 1.05@42) and `forge_station_b` gains the
  tier's second mouth (0.9@34, seven cells away in a 26-wide hall — NOT the
  adjacent matched pair the forge_hall row refused). Light count 7 → 8 =
  `LIGHT_BUDGET` exactly, so pallass_forge is now FULL. Measured
  −11.1 → −3.2 and −11.4 → −8.9, against `pallass_market` at −29.2.
- [ ] **ART/PALLASS-BLUE-BRICK-CARRIES-THE-FORGE (NEW, fix wave) — OPEN, art.**
  With both forge grades at literal neutral the tier still measures ~−3 to −9
  R−B, and the reason is on screen in `fix_after/day/{10_pallass_forge,
  17_pallass_forge_hall}.png`: floor AND walls are the Pallass blue-brick
  tileset, so the room is blue before any grade touches it. No mood value can
  answer that without putting the amber wash back on. Wants a warm floor
  variant (soot/scale near the stations) or a hotter `forge_station` sprite.
- [x] **PROCESS/THE-LANGUAGE-WAS-PROSE-ONLY (fix wave) — DRAINED.** RULE 1 and
  RULE 2 were checked by a throwaway script with an absolute path in it, living
  outside version control: reverting the entire payload left every gate green.
  Both rules, plus the mood-key-names-a-real-map check, now live in
  `scripts/data_lint.py:check_moods` (pre-flight tier, no Godot boot).
  Mutation-proven: stripping every `lights_by_day`, restoring the inn's amber
  dusk, re-inverting `street`'s night, renaming `garden_sanctuary` back to the
  dead `garden` key, tipping a sealed grade warm, opting a sky map into day
  lights, and re-splitting the longhouse's day pin each fail the lint with a
  named row. A report-only advisory covers the remaining hole: a map with light
  rows and NO card at all reads as sky-bearing, so its lamps are dark at noon.
- [x] **`mercantile_alleys` night near-black (widened row) — PARTLY DRAINED.**
  Overworld night value 0.313 → 0.357 while temperature drops −0.24 → −0.36:
  colder, not darker. The arena half of that row is untouched (not this lane).
- [x] **`hearth` is still a cold unlit oven (`adventurers_rest`) — WAS HALF, NOW
  WHOLE (2026-08-05, #390).** The mechanical half was fixed here: the hearth and
  both sconces were switched OFF in every daytime frame of that room and now
  burn (`lights_by_day`). The SPRITE half landed 2026-08-05 — owned lit-hearth
  art on the same id, in-engine pair
  `lanes/l390-evidence/hearth_inengine_pair.png`. Both halves are now the same
  answer: the room's light and the room's art agree that the fire is fed.
- [~] **`witch_hut` "watch, not a defect" night readability — TAKEN, different
  anchor.** The log named `hut_hearth_ash`; this pass deliberately did not use
  it, because that prop's display name is "The Cold Hearth" and its toast says
  the ash "has been cold for years" — lighting the room by contradicting its
  own copy is not a fix. The light went on `hut_ward_scrap`, the thing the
  room's fiction already says glows: pale ward-green, low, steady, no flicker.

**Still open, NOT taken here** (all art or code, none of them data-tunable):
the `sconce` sprite reads as a small bracket box rather than a flame at 1x, so
the guild's two new pools have no visible source object; the
`wandering_inn_facade` light at radius 56 paints a visibly rectangular warm
patch on the floodplains grass at night (light-texture falloff, not a grade);
and `sewers`/`deep_tunnels` gained `lights_by_day` but their two lights sit at
the shaft mouth, far off-frame from any normal standing cell, so the opt-in is
correct-by-rule and invisible in practice (measured delta ±0.1 luma).

### v0.17 MILESTONE CLOSE — composed machine playtest (2026-08-03)

Three player-eyes agents, serial windowed runs on close/v017 (real overlay,
import-passed), every PNG read, payload-vs-render diffed. Verdicts: 3x
SHIP_WITH_ROWS, zero blockers. Cleans of record: GH#324 stays fixed
(line_display_ab both arms render), difficulty wiring live (4 push sites),
day-identity measured (lum 82.3->49.9->36.9 inn cycle), palette + room +
copy largely land. Triage: the two P1 legibility items + the starred P2s
head v0.18 W4 as HOTFIX-PRIORITY. Ranked player-visible-first.

- [x] **(P1)** **World hint ribbon overflows at Text Scale 115%/130%** (settings_loop 09_credits_tap_surface, vs char_creation_peek cc5_inn_after at 100%). `_hint_panel` is hardcoded `Vector2(400, 28)` (message_layer.gd:314) while its sibling `_dialogue_panel` derives its size from live font metrics via `_resize_dialogue_panel()`. At 115% the strip clips descenders — "J — journal" renders as a bare stroke indistinguishable from "I — inventory", so the player sees two identical "I —" keybinds — and truncates the tail mid-word ("I — inven"). `ui_hint_rendered` proves the payload is whole. Fix pattern already exists in the same file.
- [x] **(P1)** **Journal close hint renders outside the parchment, dark-on-dark** (journal_history 01_journal_history, journal_categories 00_skills_tab_categories, journal_quest_hints 00_journal_hint_on — same artifact all three). `_close_hint` is anchored `PRESET_BOTTOM_RIGHT` with a 10px margin on `_root` (journal.gd:255), but `_root` extends past the painted parchment, so "Esc or J to close" lands on the world background with its left third under the panel's bottom-right curl. Effectively invisible on wood and on brick. Needs an inset to the parchment's art-safe rect (the panel StyleBox's decorative fold is ~40px), not 10px off `_root`.
- [x] **(P1)** **Sewers is functionally a black screen at every phase** (mood_sheet_night 13_sewers): mean lum 13.2 / median 10.2, p95 = 19.1, 95.5% of pixels under lum 20. The shield_spider at [15,10], the player, the grates and the hex floor are only visible under a 1/3.2 gamma lift. `data/maps/sewers/sewers.json` carries `"lights": null` — the "shaft daylight + phosphor moss" the mood sheet claims has no light entity behind it, so grade+vignette are acting alone. Day grade [0.24,0.26,0.37] is only ~1.2x night's, so this is not a night-only case. Wants either real light entities (shaft, moss) or a floor-value lift before the next dungeon pass.
- [x] **(P2)** **Skills tab: an unchecked checkbox draws as two blank spaces** (journal_categories 00_skills_tab_categories). The header says "confirm on a checkbox row to swap it", but journal.gd:1062 emits "  " for unchecked and "✓ " for checked, so a category with nothing slotted (Combat — Active here, 7 rows) shows no box at all. Slottable-vs-passive is distinguishable only by the absence of the "·" glyph. An empty-box glyph ("☐ ") would cost the same two chars the design already reserves and make the promise true.
- [x] **(P2)** **Passive-row confirm refuses silently** (journal_categories 00_skills_tab_categories; events.jsonl carries only `ui_journal_loadout_rendered{slottable:false}` — no toast, no sfx, no `loadout_changed`). Correct mechanically, invisible to the player: a dropped keypress and a principled refusal look identical. One toast ("[Basic Swordwork] is always on — passives don't take a slot.") reuses the existing message_layer path and closes it.
- [x] **(P2)** **Character creation marks selection by tint only** (char_creation_peek cc4b_difficulty, cc4c_hints, cc2_pick_selected_drake_f). The chosen row/card is a desaturated copy of the same teal ribbon — no caret, border, weight or label change — against a near-black backdrop where three teal ribbons already read alike. Violates the tint-is-not-disambiguation directive and diverges from the project's own settings/pause idiom, which uses a "> " caret (settings_loop 00_settings_panel_rows). Add the caret to char_creation.gd's row build.
- [ ] **(P2)** **Difficulty + Quest Hints ship with no in-game explanation** (settings_loop 01_settings_help_panel — 6 sections, neither is one; 00_settings_panel_rows — rows read bare "Difficulty: Silver" / "Quest Hints: On" with char-creation's descriptor tail dropped). The knob's best property (damage TAKEN only; enemy stats, accuracy and the seeded fight shape identical at every rung) is stated only in a code comment. One Help section + carrying the creation-step tail onto the settings row closes it.
- [ ] **(P2)** **Settings row order buries the new gameplay knobs** (settings_loop 00_settings_panel_rows). #338/#345 appended "Quest Hints" and "Difficulty" AFTER "Export Save"/"Import Save…" to honour settings_panel.gd's append-only index contract, so gameplay settings now sit below file management, and "Quest Thread" (row 11) / "Quest Hints" (row 15) — near-identical labels — are split by four unrelated rows. 17 flat ungrouped rows. The index contract is a QA-pin concern, not a player concern: re-order plus section headers, and re-pin settings_loop's indices in the same commit.
- [ ] **(P2)** **GH#337 cooldown badge has zero QA coverage and reads as a second key number** (no screenshot exists — combat_walkthrough is shotless, `ui_hotbar_rendered` carries only `{slots}`, and `grep -rl "Recovering" qa/scripts/` is empty corpus-wide; behaviour from hotbar.gd:170-177). The badge is a bare theme-default numeral at the 52px chip's top-right, twin in size/weight/colour to the key-hint numeral at its top-left, with no legend — while the AP pips and MP diamonds beside it both carry explicit colours. Hardcoded `font_size 10`, so it ignores Text Scale. It is on the COMBAT bar only (field_hotbar.gd unchanged since v0.16.2). Needs (a) a colour + a shape/label cue, (b) a windowed shot of a cooling slot, (c) a pin on the "Recovering — ready in N rounds." readout.
- [ ] **(P2)** **Settings parchment now fills 708 of 720 px** (settings_loop 00_settings_panel_rows; measured y=5..713 vs the journal's y=82..635 in journal_history 01_journal_history). #338/#345 bumped `PANEL_SIZE` 648 → 716 for the two new rows; nothing clips, but the scroll reads as bleeding off both screen edges with no room for its own ornament. settings_panel.gd's comment already says the next row needs a scrolling list or a second page — the row-order rework in the sibling finding is the natural moment to take that, not another +36.
- [x] **(P2)** **Invrisil boulevard plaza slab sits outside the frame's value family at all three phases** (feel_peek_day 01_boulevard_day / feel_peek_night 01_boulevard_night): plaza vs adjacent cobble measures 231.9 vs 73.2 lum at day, 114.8 vs 40.8 at dusk, 77.6 vs 29.1 at night — 2.7-3.2x at every phase — with a quarter of the cobble's texture variance (sd 2.9-8.7 vs 11.3-19.5). Reads as a flat untextured rectangle with a hard edge at day and a glowing periwinkle pool at night (warmth R-B -91 vs cobble -19). Base value is at ceiling so the grade multiplies onto it ~3x harder than its neighbours. Wants the tile's base value pulled down + real texture, not a grade change.
- [x] **(P2)** **Toast is drawn over the field-skill legend and truncates a skill line mid-word** (thicket_keeps_talk 01_witch_hut_interior): slot 3 renders "[Invisibility] — ...until even a careful eye find" and stops at the toast plate's left edge; authored text is "...finds nothing worth watching." The legend plate had room (its right edge is ~185px further out) — this is z-order, not wrapping. The same toast also clips the "Hide details [H]" button's right end, and the same geometry recurs in field_skills_loop 01_field_clean_via_numberkey. Wants the toast to reserve space above the legend, or the legend to yield while a toast is live.
- [x] **(P2)** **Journal close-hint renders outside the panel at 2.85:1 contrast, half-occluded by the panel's own curl** (field_skills_loop 04_journal_observe_assigned, repeat in 06): "Esc or J to close" is drawn on the bare wood floor to the right of the parchment, glyph rgb ~(14,8,4) on ~(109,86,45) = 2.85:1, below the 3:1 large-text floor, with its left half behind the panel's bottom-right scroll curl. New players get no legible close affordance. Wants the hint moved inside the parchment (footer row) with panel-body ink.
- [x] **(P2)** **garden_sanctuary's out-of-bounds surround is the brightest thing in the frame** (mood_sheet_night 16_garden_sanctuary): letterbox mean lum 221.9 against 3.1-44.3 on the other 16 night cards (next brightest is pallass_market at 44.3). The dead zone outside the playfield outshines the play area and the top-right nav pills lose contrast against it. The map's identity grade ([1,1,1], vignette 0) is correct and should stay; the surround tile is what breaks the set.
- [ ] **(P2, CARRIED 2026-08-05 #390 — reason at the end of this row)** **Pallass market's green creature reads as a pasted-on style family** (mood_sheet_night 09_pallass_market, ~x940-1105 y55-250): fully-saturated chartreuse that stays the loudest colour on the frame even after the [0.62,0.68,0.88] night grade, ~195px tall against ~110px human NPCs in the same shot (1.8x), and soft-shaded with no black keyline while every neighbouring sprite carries one. Three axes of mismatch at once. Wants a desaturation pass + scale reconcile against the market's human NPC height, or a keyline to match the pack it sits in. **CARRIED 2026-08-05 (#390):** two of the three axes are cheap (scale is one `render_scale`, and a keyline can be dilated onto the sheet programmatically) but the third is a judgement call this lane should not make blind — the creature is a NAMED market beast whose saturation may be deliberate, and the only night evidence we have is a mood-sheet frame, not a run that walks up to it. Doing scale+keyline without a windowed read of the market at day AND night risks a second wrong answer on a row that already has one. Next art pass: shoot `pallass_market` day/night first, then take all three axes in one edit. |
- [ ] **(P2)** **`guild_notice_wall` renders as a featureless grey blob with a broken outline** (mood_sheet_night 05_guild, ~x240-340 y285-375; repeat silhouette in 11_brothers_parlor ~x900-960 y440-520): flat mid-grey disc, no shading/highlight/subject, dashed dark border that reads as a selection marquee. Sits directly under the fully-drawn `request_board` in the same frame, which makes the unfinished read unmissable. NOT the same case as pallass_market's `anchor_waystone_slate`, whose blankness is authored into its observe copy — leave that one alone.
- [x] **(P2)** | rug_woven_cream | inn_upstairs (6,2), stationer, pallass den-shop | Field is random speckle with red flecks — reads as a stain, not a weave; red medallion rug in the same build is the correct reference | v0.17 close machine-playtest, stationer_room_loop/01 + player_room_loop/06 | **DRAINED 2026-08-05 (#390).** Regenerated as an actual weave — warp/weft grid, fringed border, cream where the id says cream — and judged against `rug_woven_red`'s medallion in the same compositor frame, which is the reference this row named. Anchor is now the measured alpha bbox (58/64) instead of the frame bottom; scale 0.35 → 0.4151 keeps the old ~22px footprint. In-engine pair `lanes/l390-evidence/window_rug_inengine_pair.png` (real BEFORE at the lane base, `player_room_loop windowed --seed=9`, `00_door_shut`); RGB diff bbox (580,108)-(968,424) covers the rug and the window in the same frame and nothing else structural. WATCH: the new weave is PALER than the speckle it replaces — correct for "cream", but if a later pass reads it as too bright on dark boards, pull the value down rather than putting the speckle back. |
- [x] **(P2)** | Hedault workshop night grade | invrisil interiors | World-band mean luminance 22/255, p90 32 — roughly half the next-darkest night scene; floor/wall/NPC all indistinguishable | v0.17 close machine-playtest, invrisil_setting_talk/03 |
- [ ] **(P2)** | Pallass tier ground plane | pallass market + forge tiers | Full-screen saturated blue checkerboard (#1E3474 + #687EAE grid) reads as a debug grid; untextured navy block by the forge has hard unblended edges | v0.17 close machine-playtest, pallass_ledger_offices/01+02 | **CARRIED 2026-08-05 (#390), reason on the row:** this is not a sprite pick, it is the tier's FLOOR TILE plus the out-of-playfield surround — fixing it means rewriting `floor_layers` across two Pallass maps (and probably a new textured stone tile), which is map-structure work in files the art lane does not own this week (its fence is sprite/scale/mood fields). It also shares a root with the boulevard-plaza fix that already shipped (flat untextured fill at ceiling value), so it should be taken with that method by whoever owns the Pallass maps next, not bolted on here. |
- [x] **(P2)** | Invrisil boulevard plaza fill | invrisil_boulevard | Flat untextured #424FA3 rectangle, razor edge against cobbles, brighter than the lamplit street; no texture unlike the riverfarm water tile | v0.17 close machine-playtest, stationer_room_loop/04 |
- [x] **(P2)** | Toast vs field-skill legend | all maps, HUD | Toast panel occupies the same band as the legend and is drawn over it, truncating legend text mid-word ('...and files i') | v0.17 close machine-playtest, stationer_room_loop/02 |
- [x] **(P2)** | HUD chip bar | player room, den-shop, inn | Inventory/Journal/Pause chips absent for the whole first visit to the purchased room (chip-region max 53 vs 255 after a pause cycle) with no visible modal on screen; touch has no fallback | v0.17 close machine-playtest, player_room_loop/03+04 |
- [ ] **(P2)** | Face-to-face sprite overlap | inn, pallass den-shop, inn guest seats | Two-tile-tall sprites on one-tile cells merge the player and the speaker into one two-headed figure during dialogue | v0.17 close machine-playtest, inn_walkthrough/02 + pallass_ledger_offices/04 + inn_guests_loop/01 | **CARRIED 2026-08-05 (#390), reason on the row:** no art change fixes it. Every rig involved is already at the family height (~28-33px on-screen, measured this lane: a_hunter 33, citizen_f 30, human_laborer 30.2, wilovan 28), so shrinking sprites to stop the merge would break the whole cast's scale. The real fixes are engine or layout — a dialogue-time separation/dim of the non-speaker in `world.gd`, or moving the NPC cells so conversations happen across a counter — and both are outside a sprite lane's ownership. Needs a code owner, not a pack pick. |
- [x] **(P2)** | hunters_lamb_pen | riverfarm_village | No lamb sprites in or around the pen; the whole [Beast Tamer] door is a bare fence rail against empty grass while the copy describes handling three fleeces | v0.17 close machine-playtest, gh330_lamb_pen_loop/00 | **SPRITES DRAINED 2026-08-05 (#390): `lamb` + `lamb_lying`, evidence `lanes/l390-evidence/lamb_pen_pair_4x.png`. WIRED 2026-08-05 (#396 lane C):** `lamb_lying` (15,11) + `lamb` (17,11) as decor on the rail's own blocked cells, plus the quest-gated `makings_tend_lamb` at (18,11) as the limping third. Windowed read `lanes/l396c-evidence/02_pen_lambs_tend.png` (+ `pen_lambs_zoom_2x.png`) from `makings_loop`, which also re-gates the pen's own route; `gh330_lamb_pen_loop` re-run green at seed 7. |
- [x] **(P2)** | Pisces guest sprite | inn guest seats | No eye pixels and an all-grey robe/hood ramp — reads as a faceless bust next to guests who all have readable faces in the same frame | v0.17 close machine-playtest, inn_guests_loop/04 | **DRAINED 2026-08-04 (#390).** Fixed by REGENERATING the rig (2 gens) rather than inpainting it (20-40 gens) — the cheaper repair was the better one. Hood pushed BACK, explicit face, idle + walk regenerated to keep his shipped pin counts. |
- [ ] **(P3)** **Journal sub-rows lose their indent on wrap** (journal_quest_hints 00_journal_hint_on — the quest-hint line; journal_history 01_journal_history — the Postings detail rows, same shape). First line indents, continuation lines return flush-left and read as body text rather than as part of the sub-row. One hanging-indent change on the shared sub-row style covers both.
- [ ] **(P3)** **Skills-tab scroll can rest on an orphan wrap fragment** (journal_categories 01_skills_tab_curated + 02_skills_tab_cursor_follow — top visible line is a bare "L5", the tail of a wrapped [Quick Movement] — Warrior L5 row). Cursor-follow scrolls to the cursor row without snapping the viewport to a row boundary, so a wrapped row's tail can head the page. Snap to the wrapped-line start of the topmost whole row.
- [ ] **(P3)** **Cooled Skills lose their flavour text in the combat readout, permanently** (combat_hud.gd:613-637; pinned string at qa/scripts/combat_move_input.json:356, shot 03_power_strike_slot_info — outside this slice, not re-run). When the standing cooldown clause plus the description would wrap, the description yields and never returns at readiness, so [Power Strike] et al. read purely mechanically wherever the player picks them. Deliberate and correctly reasoned; logging it so the trade is visible when the readout budget is next revisited.
- [ ] **(P3)** **Character-creation pick step is unlabelled; new-step footer casing is inconsistent** (char_creation_peek cc1_pick_frame_a — six sprites, no names, `options:[]` in the payload; cc4b_difficulty / cc4c_hints — "Arrows to choose • Enter to confirm • Esc to go back • change it any time in Settings", three capitalised segments then one lowercase). The pick step is now the only labelless step in a flow whose two new steps label every option.
- [ ] **(P3)** **1-slot hotbar coin drops its key number; 2+ slot coins keep it** (field_skills_loop 05_hotbar_remapped_1slot and 00_hotbar_boot_1slot, line_display_ab 01 — all numberless; feel_peek_day/night 01 and thicket_keeps_talk 01 at 2-3 slots — all numbered). With details hidden the lone icon carries no cue that "1" fires it, and boot is a 1-slot state, so this is the first-session case. Wants the number drawn unconditionally.
- [ ] **(P3)** **Bottom HUD cluster jumps ~25px left and grows ~4% after the Reduce Motion round trip** (feel_peek_night 01_boulevard_night vs 03_boulevard_night_reduce_motion): icons move [512,556]/[570,614] -> [487,531]/[545,589], button [667,806] -> [654,793], cluster span 294px -> 306px, same map, no world change. Every other 2-slot frame this pass sits at the 512/570/667 positions, so 03 is the outlier. Likely a scale/anchor that reduce_motion resets rather than an animation frame. (Same shot's positive: the motes DO stop live, no rebuild needed.)
- [ ] **(P3)** **Night city maps invert the read hierarchy — weeds out-pop people** (mood_sheet_night 04_street, 15_mercantile_alleys): street mean lum 27.1 (27.7% of pixels <20), alleys 21.7 (57.1% <20). The saturated green foliage props at street ~(250,170)/(830,230)/(830,355) are the most salient objects in frame, while NPCs outside the sconce pools (street ~(55,350-420) and ~(380,80-130); alleys ~(595-640,265-385) and ~(130-175,285-390)) read as unresolvable silhouettes. The sconce pools themselves work. Wants either the foliage desaturated at night or a small rim/ambient lift on entity sprites. **CARRIED 2026-08-05 (#390), reason on the row:** neither fix exists as data today. Mood cards grade a WHOLE map, so there is no key that desaturates foliage at night without dragging the NPCs down with it, and "a rim/ambient lift on entity sprites" is a renderer feature (`entity_visual_factory` would need a night-aware modulate), not a sprite or a mood value. Desaturating the foliage SHEETS would fix night by wrecking day. This is a code row wearing an art row's clothes; it needs a per-layer night knob before any art answer is worth shooting. |
- [ ] **(P3)** **inn_upstairs corridor is split by an unmotivated floor-material seam** (mood_sheet_night 03_inn_upstairs, hard vertical edge at x~765): planks lum 59.8 left, olive diagonal-hatch lum 49.8 right, no threshold/rug/divider, and the room's only NPC stands on the olive side. Same tile is the stationer's whole floor (feel_peek_day 02) and a small corner patch in the inn (atmosphere_check 00_start_day, only a 10-lum delta there and harmless). Wants either a divider prop or the corridor unified to one material. **CARRIED 2026-08-05 (#390), reason on the row:** both candidate fixes leave the sprite lane's fence. Unifying the corridor rewrites `inn_upstairs.json`'s `floor_layers` (map structure, and the same tile is load-bearing in two other rooms), and a divider prop adds a decor ROW, which can move `blocked_cells` and re-pin every upstairs QA route. The window and rug fixes in this same room DID ship this lane because they are pure sprite swaps — this one is not. Take it with the Pallass ground-plane row: one owner, one floor-material pass, one re-pin. |
- [ ] **(P3)** **Stationer props read as holes, and the clerk/bracket/player stack crowds one 60px band** (line_display_ab 01_interact_at_world_ready): the barrel props at [10,1]/[2,1] carry a pure-black (0,0,0) outline over a body at lum 59 against a lum 48 floor — an 11-unit separation that reads as a shadow, not an object. Separately the clerk [8,1], its affordance bracket and the player [8,2] all occupy full y135-260, so the figures are ambiguous at 1x with only the bracket disambiguating. Both minor; noting for the next interior-contrast pass.
- [ ] **(P3)** | inn_player_room floor | inn_player_room | Warm plank tile in the bed corner meets the olive interior board over the rest on a bare 90-degree seam with no threshold or rug to justify it | v0.17 close machine-playtest, player_room_loop/05+06 |
- [ ] **(P3)** | inn_player_room sconce (night) | inn_player_room | Fixture renders as a cold grey bar with no lit core and its warm pool is offset to one side, so the light has no visible source | v0.17 close machine-playtest, player_room_loop/07 |
- [ ] **(P3)** | Erin opening lines | inn dialogue | Spaced hyphen ' - ' instead of the em dash used everywhere else in the build, on the game's first NPC line | v0.17 close machine-playtest, inn_walkthrough/02 |
- [x] **(P3)** | window_blue | inn_upstairs (10,4) | Reads as a dark grey slab with a blue edge rather than a window; doors in the same wall read correctly | v0.17 close machine-playtest, player_room_loop/00 | **DRAINED 2026-08-05 (#390).** It was never a window: a component scan of `Interior_Props_01` shows the old region `[224,4,16,28]` is a 16px-wide slice off the SIDE of a chest/bench block, which is exactly why it drew as a slab with one blue edge. The real four-pane window (wooden frame, cross mullion, blue glass) is on free_pack `Furniture.png` at `[132,355,24,25]` — the sheet `unlit_lantern` already uses, so no new licensing — at 0.85 ≈ 20x21px, matching the doors in the same wall. Pair: `lanes/l390-evidence/rug_inengine_pair.png` (tight crop, `player_room_loop/06_reentry`, diff bbox (664,180)-(744,264) = the window cell and nothing else); the same fix is visible in the adventurers_rest pair. |
- [ ] **(P3)** | Room register node | inn register dialogue | Speaker banner reads 'Lyonette' over body text that is third-person narration about her | v0.17 close machine-playtest, player_room_loop/01 |
- [ ] **(P3)** **pallass_ledger_offices run hygiene** (pallass_ledger_offices/04_den_keeper_released.png): Not player-visible, but pallass_ledger_offices is the only one of my seven runs that exits noisy: 'WARNING: 23 ObjectDB instances were leaked at exit' plus 'ERROR: 10 resources still in use at exit'. QA_RESULT is PASS with zero failures and all four screenshots land, so this is teardown noise rather than a route failure — flagging it because the other six runs (including two other three-map routes

<!-- v018-W4 -->
### v0.18 W4 — hotfix-head drain (2026-08-03)

Fourteen v0.17-close rows closed and checked above, each with the evidence
path and the measured before/after. Windowed runs serial, every PNG read.

**HOW TO REPRODUCE, and why the numbers below differ from the first draft of
this block.** `qa_output/` is a regenerated artifact directory, not a stored
one: any later run (a headless `ci_sweep`, a sibling lane) overwrites it, so an
evidence path is a claim about a COMMAND, not about a file that will still be
there. Every row's `qa/run_qa.sh <script> windowed --seed=<seed>` is named
below, and every number was re-measured on a fresh run of it. The BEFORE column
is the same shot from the v0.17-close windowed sweep at this lane's base
(`6b47c0d`), so before and after use one method and one framing. Method:
whole-frame Rec.709 luma unless a region is named; regions are pixel boxes on
the 1280x720 native shot, stated inline.

| row | run (windowed) | evidence shot | measured BEFORE → AFTER |
|---|---|---|---|
| Hint ribbon at 115/130% | `settings_loop` | `10_hint_ribbon_115.png`, `11_hint_ribbon_130.png` | panel 400x52 at 100/115% (width floor absorbs), 442x55 at 130% (was 424, text+28, label rect crossing the end-cap at x=410 against a paper edge at 404); `ui_hint_rendered{fits:true}` at every step, and `fits` now goes FALSE if the inset regresses (mutation-proven: `side := 14.0` fails the run headlessly) |
| Journal close hint | `journal_categories` | `00_skills_tab_categories.png` (repeat `field_skills_loop/04`) | BEFORE the string is not on the panel at all — off the parchment onto the wood; AFTER it sits in the panel footer, ink-on-paper, 8.8:1 (`jc/00`) and 9.2:1 (`fs/04`) by WCAG relative luminance over the hint's own box |
| Unchecked checkbox | `journal_categories` | `00_skills_tab_categories.png` | "□ " (U+25A1, inside the shipped symbol-fallback subset — renders, no tofu, on every Combat—Active row) |
| Passive refusal | `journal_categories` | `03_passive_refusal_toast.png` | "[Basic Swordwork] is always on — passives don't take a slot." renders over the open journal (`ui_toast_rendered` pinned in-script) |
| Creation caret | `char_creation` | `00_picker_grid_drake_f_selected.png`, `02_creation_difficulty.png` | "▶" on the selected card and on the selected setup row; tint demoted to secondary |
| HUD chips | `player_room_loop` | `03_room_day.png`, `04_room_after_sleep.png` | chip region (x980-1280, y0-40) max 52 → 255 in BOTH shots. ISOLATED: re-run with the lane's `field_chips.gd` and MAIN's unmodified script still reads 255, so the CODE is the cure and the script's `click_field_chip` pair is only the can-fail guard |
| Toast over legend | `field_skills_loop` | `01_field_clean_via_numberkey.png` | legend line 1 renders whole ("...with supernatural ease.") with the toast in its own band below-right; no overlap |
| Sewers | `mood_sheet_night` + `sewers_walkthrough` | `13_sewers.png`, `00_sewers_landing.png` | `13_sewers` mean 25.2 → 41.5, p90 28.0 → 49.9, under-lum-20 87.5% → 9.7%. Landing shot reads at mean 51.3 / 2.5% under 20: floor hexes, grates, water channels and the PC all legible without a gamma lift |
| Hedault workshop | `invrisil_setting_talk` | `03_he_will_not_cut_a_mount_around_a_lie.png` | world band (y0-430, above the dialogue plate) mean 28.1 → 32.9, p90 33.3 → 45.2, under-lum-20 55.4% → 35.5%. Modest but real: wall, floor, left-hand props and the standing NPC separate where they did not |
| Garden letterbox | `mood_sheet_night` | `16_garden_sanctuary.png` | surround band (x0-160 ∪ x1120-1280, y60-600) 221.9 → 102.6 while the playfield (x300-900, y60-420) holds at 76.6 → 77.2 — the map's identity grade is untouched, exactly as the row asked |
| Boulevard plaza | `feel_peek_day`, `feel_peek_night` | `01_boulevard_day.png`, `01_boulevard_night.png` | plaza (x180-340, y320-470) vs cobble (x40-140, same rows): day 234.9/77.4 = **3.03x → 1.87x** (120.6/64.5), night 79.2/26.6 = **2.98x → 1.84x** (40.7/22.1); plaza texture sd 25.7 → 17.1 day. Still above the cobble family, not yet inside it — see the residual below |

#359's own read is the continuous loop in `atmosphere_check`: the inn's
`ui_mood_applied` walks day → dusk → night → **dusk → day** with no sleep in
between, and the frames measure 72.5 → 56.6 → 41.3 → **51.1 → 72.4**
(`01d_dawn_dusk.png`, `01e_wrapped_to_day.png`). The wrapped day reads 72.4
against the opening day's 72.5 — same grade; the 0.1 delta is scene content
(1800 actions of walking), not the clock.

**#359 REGRESSION FOUND AND FIXED IN THIS LANE, worth its own row.** The wrap
emits `phase_changed{phase:"day"}` from `_tick_action`, which the monotone
clock structurally could not — and `sleep_veil.gd` read exactly that as "the
player slept". In the first draft of this lane the loop therefore fired a full
mid-field blackout on the 1800th un-slept action, and `_play_finale_off_the_bed`
spent the game's ONE ending cinematic there, banking `finale_played` so the bed
could never replay it. `sleep()` now tags its own emit `{"slept": true}` and
that flag is the whole trigger. Proof in the same run's `events.jsonl`: the
wrap at index 2098 is followed by NOTHING until the real sleep at 2114-2115,
where `accomplishment_recorded{slept}` → `phase_changed{day, slept:true}` →
`ui_sleep_veil_rendered` → `ui_sleep_veil_finished`. Pinned in
`test_sim_core` off a real 180-action walk over a real wrap (mutation-proven:
dropping the flag fails the suite).

RESIDUALS, logged not hidden (rows left `[ ]`):
- The plaza is **inside the value family but still the brightest slab in it**
  (1.87x day, 1.84x night, against the ~1.0-1.3x the neighbouring cobble
  variants hold). Closed as "outside the family" — it is not any more — but a
  second value pull is owed before it reads as pavement rather than as a
  lighter courtyard.
- The plaza's **edge** is still a razor rectangle. The value/texture half is
  fixed; the transition needs per-cell wang edge tiles, a bigger job than a
  tile repaint.
- The toast band is reserved at the strip's BASE height: a 3-line toast still
  tops out above it, and the bottom controls row can still reach the strip's
  own footprint at 3+ hotbar slots.
- The passive-refusal toast lands over the journal's own bottom-right corner
  and covers the "Esc or J to close" footer for its hold
  (`journal_categories/03_passive_refusal_toast.png`). Both are correct
  individually — the toast is the `modal_response` exemption, the footer is the
  P1 cure — but the one surface that had no close affordance is briefly the one
  the toast sits on.
- Hedault's workshop is LIFTED, not solved: 32.9 mean world-band still reads
  as the darkest interior in the set. Real light entities are the honest cure;
  this was a grade pull.

NEW ROW OPENED BY THIS LANE (`[ ]`, for the next drain):

- [ ] **(P3)** **`player_room_loop` exited windowed once with `6 ObjectDB
  instances were leaked` + `3 resources still in use`** — non-deterministic:
  clean on the two immediately following identical windowed runs, clean
  headless, and clean on main's own script under this lane's code, so it is
  neither the lane's added `click_field_chip` pair nor a route failure. Same
  teardown-noise class as the `pallass_ledger_offices` P3 above; logged rather
  than swallowed because COMMON's grep discipline is zero-tolerance and a
  once-in-three flake will read as a lane regression the next time it lands.
## 2026-08-03 — #318 Invrisil nobility thread, windowed reads (v0.18 W3)

<!-- v018-W3 --> Three new canonicals shot windowed at seed 9
(`invrisil_house_name_talk` 8 shots, `_skill` 4, `_fight` 5). The thread's
own surfaces read correctly: the Lady's new nodes, the scribe's counter
with one row greyed, the broker's five-row three-pillar node with two rows
greyed, the steward, and the day-phase alley board. Two shipped defects
already in this log recurred and are NOT re-filed (toast drawn over the
field-skill legend, `invrisil_house_name_talk/03`; two-tile sprites merging
in a vertical stack, `_talk/06`). New:

- [ ] **(P2)** | `invrisil_lady_client` rig | stationer, adventurers_rest, invrisil_boulevard | The rig now backs THREE Invrisil surfaces, TWO of them conversation-bearing: "A Lady with a Ring Box" (stationer) and "A Woman Who Came in a Carriage" (the Rest's steward), plus "A Lady in Plum Silk" on the boulevard. All three are `A `-prefixed extras, so the one-rig-one-named-character policy is not violated, and no tint is used to separate them (correctly — tint is not disambiguation). But two women who each hold a real conversation in the same region now share one silhouette, and only the speaker banner tells them apart. Wants a second gentlewoman rig with a distinct silhouette (the steward reads as gloves-indoors + no ring box, which is a real drawing difference) before either becomes a returning face | #318 W3, invrisil_house_name_talk/01 vs /06 |
- [ ] **(P3)** | `mercantile_alley` arena, DAY | invrisil combat | The day counterpart of the shipped night finding (which measured the same board as unreadable after dark). At day the board IS readable — every silhouette and HP numeral resolves, which is why this lane's fixture is staged at day — but the arena is a large flat tan field whose only structure is a handful of scattered dark props. Nothing in it says "alley": no wall line, no narrowing, no paving change, against a city whose one traversal signature is alleys-around-fronts | #318 W3, invrisil_house_name_fight/03 |
- [ ] **(P3)** | `boulevard_carriage_wake` | invrisil_boulevard (11,1) | The thread's one atmosphere beat (the pink carriage already gone, only the street's reaction left) is a `hide_sprite` facade prop on the blocked row, the shipped `boulevard_glazier`/`boulevard_teahouse` idiom. So its only on-screen affordance is the interact bracket, which draws over the player's own sprite from the bump cell below. Correct and consistent for a shopfront; thinner than it should be for a prop that carries a story beat and a counter. Wants a small ground mark (a wheel-track decal on the marble) so the beat has a thing to walk up to | #318 W3, invrisil_house_name_talk/03 |
<!-- v018-W5 -->
- [ ] **(P3)** **The cooldown badge is now photographed, and it is a small low-contrast digit** (class_evolution_loop 03_power_strike_cooldown_badge — the first shot of this UI in the repo; W5 added the leg because the v0.16.2 close flagged zero badge coverage). `hotbar.gd:170-177` draws `cooldown_remaining` as a bare 10px Label in the slot's top-right corner with NO colour override, so it inherits the default font colour over slot art rather than the deliberate AP-pip / MP-diamond treatment its two neighbours get. It is legible once you know to look for it. Whether a player who does not know to look ever finds it is the open question — the readout line beside it ("[Power Strike] — 3 AP — ×2 damage — Recovering — ready in 2 rounds.") is currently carrying the whole message. Wants the same colour+outline treatment AP_PIP_COLOR/MP_DIAMOND_COLOR already establish two lines above it.

<!-- v018-W1 -->
### v0.18 W1 — #348 property-table proof shots (2026-08-03)

Windowed `property_seams` at seed 9, six frames, evidence under
`wandering_inn_game/qa_output/property_seams/`.

- [ ] **(P2, TINT-ONLY — the lane that owns terrain art)** The frozen cell
  reads as a SHADE of water, not as ice. RETRACTION: this row's first draft
  filed the pale-blue slab as a POSITIVE "real render tell". That judgement
  contradicts the standing directive of 2026-08-02 — tint is NOT
  disambiguation, shade variants never read as separate things, distinct
  silhouettes are required — so it is re-filed as an OPEN row, because a row
  logged as a positive is a row nobody drains.
  Evidence `01_water_before_freeze` → `02_ice_floor_formed` →
  `03_standing_on_the_ice`: the frozen cell (3,5) is the same water tile at a
  lighter value — same silhouette, same texture, no rime, no fracture, no edge
  treatment. In `02` (the frame literally named "ice floor formed") the change
  is barely perceptible at all — a few white specks at the band's left edge —
  because the PC is still standing north of the cell.
  Why this is not cosmetic: `freeze_cell` is the one verb in the slice that
  flips WALKABILITY. A playtester who freezes the channel, sees the same blue
  band and reads the toast as flavour never tries to cross — K5 (discovery
  failure) firing on the slice's headline interaction. Cure is an ice tile
  with its own silhouette (rime edge / fracture lines), not a brighter blue.
  NOT fixable inside W1: the property table ships no art, and
  `sprites.json` + `assets/**` belong to the art lane this wave.
- **POSITIVE — the burn resolution reads.** `04_debris_blocks_the_nook` →
  `05_nook_cleared`: prop gone, nook open, prop-authored line spoken.
- **RUN HYGIENE — investigated, NOT a W1 regression.** `property_seams`
  windowed intermittently exits with `WARNING: 12 ObjectDB instances were
  leaked at exit` + `ERROR: 6 resources still in use at exit` — the
  `pallass_ledger_offices` teardown-noise class logged directly above.
  A/B'd rather than assumed: same tree, same script, same fixture, swapping
  ONLY the three edited `src/core` files — table engine 5 leaks/10 runs,
  pre-table engine 1 leak/5 runs, and the two engines' event streams are
  byte-identical (61 events, timestamps stripped). Headless is
  deterministically clean (0 grep hits, 3/3), which is what `ci_sweep`
  greps. Conclusion: pre-existing flaky windowed teardown; it deserves a
  real fix in whichever wave owns run hygiene, but it is not the property
  table's.
- [ ] **(P2, EVIDENCE FOR THE EXISTING ROW — W4 owns the fix)** Toast over
  field-skill legend, reproduced three times in this run
  (`02_ice_floor_formed`, `05_nook_cleared`, `06_untagged_prop_refused`): the
  toast panel overlaps the legend and truncates it mid-word ("...old timber in
  momen"). Same defect as the v0.17-close row; logging the extra frames
  because they show it at three different toast lengths.

### v0.18 wave-1 CLOSE — focused machine playtest (2026-08-03)

Single-agent serial pass, 13 runs, verdict SHIP_WITH_ROWS. All three W4
hotfixes VERIFIED HOLDING (ribbon 115/130%, journal close-hint,
creation caret); bestowal contract exact (flag-off provably silent);
clock loops with correct phase identity. Ranked.

- [ ] **(P1) ICE TILE IS TINTED WATER — HARD WAVE-2 ORDERING CONSTRAINT**
  (property_seams 02/03/05): _paint_ice_cell reuses WATER_SHEET under
  ICE_TINT (world.gd:956-962) — tint-as-disambiguation on a world
  surface; copy promises "grey-white ice", player sees brighter blue;
  cue weakest under the player's own light. SHIP-SAFE TODAY: frost_touch
  is the only freezes carrier and no class grants it — no player can
  reach this surface in v0.18.0. RULE: the bespoke ice tile (rime edge /
  fracture silhouette) + "the channel"→cell copy fix land BEFORE any
  freezes-granting skill (ice_floor picks included).
  **v0.19 L4 — ART LANDED, WIRING AND COPY OWED (row stays open).**
  `assets/tiles/ice/ice_floor_tiles.png` is on the tree (commit
  `88bde335`): a 16x16 fully-opaque frozen plate, rime rim + one
  fracture node + four seams, authored on the Pixel Crawler snow ramp
  and owned (no manifest row — a public checkout renders real ice).
  Contract pinned by `test_sprite_registry`'s
  `_assert_ice_tile_is_bespoke_and_opaque`. Cold-read evidence (tile at
  8x, tiled 3x3, and an L-shaped frozen patch over the real water cap
  at 1x and 4x, tinted-water BEFORE in the same frame):
  `lanes/l4-evidence/ice_tile_before_after_1x.png`, candidates in
  `ice_tile_candidates.png`. TWO residuals, neither in the art lane's
  files: (a) `src/world/world.gd:119/140/141/956-962` must point at the
  new sheet at coord (0,0) and DROP `ICE_TINT`; (b) the
  "the channel"→cell copy fix lives in `data/skills.json`
  (`frost_touch.freeze_toast`) and `data/interactions.json` (thaw +
  refusal toasts), with the string pinned twice in
  `qa/scripts/sewers_walkthrough.json`. The row closes when those land.
- [ ] **(P2)** Boulevard plaza razor-edge seam at day (1.47x lum, no
  transition tiles; inverts at night) — wants wang edges.
  **CARRIED (v0.19 L4): the fix is `floor_layers` rows in
  `data/maps/invrisil/invrisil_boulevard.json`, a file no v0.19 lane
  owns.** Not an art-asset gap — the free pack's own transition tiles
  already exist; what is missing is the map rows that place them.
- [ ] **(P2)** PC drawn under field chips on bottom-row cells — no
  HUD-safe area (invrisil_house_name_talk 03).
  **CARRIED (v0.19 L4): `src/ui/**` — the feedback/panels lane's file,
  fenced out of the art lane by ownership. No sprite change can move a
  HUD chip off the player.**
- [ ] **(P2)** Stacked-NPC burial of the reticled speaker in the
  thread's climax column (06) — conversation draw-order/nudge wanted.
  **CARRIED (v0.19 L4): draw-order/nudge lives in `src/world/world.gd`,
  not in `data/sprites.json`.** A per-sprite `field_y_sort_bias_px`
  cannot fix it: the burial is between two ENTITIES on adjacent cells,
  so any bias that lifts the speaker buries whoever is behind them.
- [ ] **(P2)** "Inventory" nav pill overflows at 115/130% — the ribbon
  fix's sibling widget, same cure (font-derived rect).
  **CARRIED (v0.19 L4): `src/ui/**`, the feedback/panels lane.**
- [ ] **(P2)** "[Mixer] has become [Alchemist]!" enqueued, never
  rendered in its own canonical (15 enqueued/10 rendered, shared FIFO
  with loot) — class evolution wants its own lane or beat; Wave-D's
  moment currently has no photograph.
  **CARRIED (v0.19 L4): the shared toast FIFO is
  `src/ui/message_layer.gd`, owned elsewhere this wave.**
- [ ] **(P3)** Cooldown badge ~1.3:1 vs plate (slot-dim carries the
  meaning; v0.16.2 row half-retired). **(P3)** legend clipped by 4-line
  toast (W4 residual, reproduced). **(P3)** dialogue panel over ribbon
  tail. **(P3)** Lady's coda orphans 92 chars on blank parchment.
  **(P3)** interiors phase-invariant (clock invisible indoors). **(P3)**
  day identity is brightness-only (no hue). **(P3)** debug overlay no
  backing plate (dev-only). **(P3)** sewers ladder scribble at 1x.

## Voice pass close (2026-08-04)
- WATCH: center dialogue panels (Lyonette intro, Zevara summons) sit
  flush against the footer hint bar — no clipping observed at current
  option counts, but zero margin. Pre-existing layout, not introduced
  by the text pass (verified same geometry pre-pass). Becomes a real
  bug the day any center-panel conversation gains a 4th option.

## v0.19 art & silhouettes lane (2026-08-04)

Three of this lane's four fixes exist because the previous answer was a
TINT. The acceptance gate was therefore not the windowed capture but the
COLD READ: render the pair at 1x, side by side, on the real floor tile,
and ask which one you sleep in / which one cooks the stew. Both
directions had to pass, because both blind playtests inverted bed and
chest in both directions.

**Method.** Candidate regions came from `docs/asset-catalog.md` →
`docs/asset-index.json` → a connected-component bbox scan, never from
guessed atlas coordinates; every anchor is a measured alpha bbox
(`scripts/sprite_alpha_probe.py`), never a frame edge. BEFORE frames are
the shipped sprite rendered by the same compositor as the AFTER, in one
image, so nothing is read against memory.

| row | fix | evidence |
|---|---|---|
| bed reads as a chest, chest reads as a bed (#376, both directions, two playtests) | `bed` → the sheet's tight bed bbox `[1,293,30,54]` at 0.55 (was `[0,296,34,44]` at 0.375 = 11x20px, pillow band 3px). `chest` → the admurin chest `chest_open` already used, `[2,12,28,20]` at 0.85, so closed and open are one object in two states | IN-ENGINE PAIR, real BEFORE run at the lane base `aabec4bd`: `qa/run_qa.sh player_room_loop windowed --seed=9` (03_room_day, 06_reentry) and `qa/run_qa.sh upstairs_walkthrough windowed --seed=9` (03_your_bed_sleep, 01_upstairs_hallway), kept at `lanes/l4-evidence/windowed/` with the read-side-by-side crop `bed_chest_windowed_pair.png`. RGB (not RGBA) diff: player_room bbox (416,144)-(564,268), 12592 px > 8 — the bed-and-chest corner and nothing else on the frame; upstairs bbox (580,104)-(916,492), 11632 px. The PC standing SOUTH of the taller bed still draws in front (GH#127 contract holding). Compositor cold-reads: `bed_chest_coldread.png`, `bed_chest_final.png` |
| three cauldrons, three gates, one silhouette (#378 arm 2) | `stew_pot` keeps `cauldron` as hero; new `short_order_range` (flat hotplate + firebox) and `witch_kettle_hook` (pot slung from a tall crane). Round pot on stones / wide flat-topped box / vertical hook — three shapes, and the vertical one is what separates the kettle from both pots at 1x | `lanes/l4-evidence/kitchen_trio_before_after.png` (the tint-only trio, then the shipped trio at two scales, 1x and 5x). NO in-engine pair yet, and it is not an oversight: the sprite ids exist but `inn.json`'s three rows still point at the old ones, so an engine shot would photograph the OLD trio. The pair is owed by whoever lands the map rows |
| corusdeer carcass prop had no sprite (#383) | `corusdeer_carcass` at 0.6, scaled against the live `corusdeer_doe` rig at 0.7 — a carcass reading smaller than its own species is the mismatch to avoid | `lanes/l4-evidence/carcass_scale.png` (two scales beside the live rig on the real floodplains grass tile). No in-engine pair: no map places the carrier prop yet |
| ice tile is tinted water (P1) | see the P1 row above — art landed, wiring and copy owed | `lanes/l4-evidence/ice_tile_before_after_1x.png` |

**Budget.** Measured at the start of the lane: $1.53 credits, 0
subscription generations (2040/2000 used) — not the ~$2.7 every art
issue in the milestone assumed. Pack-first was therefore mandatory and
it paid: the bed and chest cost nothing (both fixes are a region and a
scale on sheets already in the tree), and the ice tile cost nothing (it
is authored, not generated). ONE generation call was made — sanctioned
spend #3, the cauldron trio — for **$0.09**, and because a
`create_1_direction_object` pack bills per call rather than per subject,
the same call carried the kettle, the range AND the carcass at zero
marginal cost. Balance after: **$1.44**. The bespoke-rig rows above stay
carried; nothing here changes that they need a top-up.

**What a later art pass should NOT undo.** `bed`'s render_scale is a
legibility floor, not a taste knob — the 0.375 crop is what two
independent playtesters read as a chest. `chest` must stay on
`chest_open`'s sheet and scale. And the kitchen row must stay three
silhouettes: the tint that used to distinguish them predicted nothing
(a cooking PC read the kettle dead, a witch PC the reverse).

## #390 Tier 2/3 art drain (2026-08-05)

The lane the v0.19 section said it could not afford. It was affordable: the
budget number every art issue in this milestone reasoned from was wrong by
roughly an order of magnitude in our favour.

**Budget, measured.** Start $0.83 credits, 0 subscription generations
(2055/2000 used, so every generation bills as overage). Twelve generations
built the whole `a_shepherd` rig for **$0.15** (#396 Task 1 — that rig lands
on `issue/396-riverfarm-redesign`, not this branch); twelve more built Wilovan's
combat set for **$0.13**; one 16-candidate object pack (20 generations) carried
FIVE separate rows for **$0.09**. That is **~$0.012 per generation**, against
the ~$0.065 the #390 comment extrapolated and the "one rig would consume the
lane's whole envelope" ruling #385 was filed under. End balance **$0.46**, hard
floor $0.10 never approached. The lesson is procedural, not lucky: call
`get_balance` before and after the FIRST call of a new kind and re-derive the
rate — every stalled art row in this milestone was blocked by an estimate
nobody had measured.

**Method.** Pack-first still won where a pack had the art (`window_blue`),
and the win came from a connected-component scan rather than a region guess —
which is also how the row's real cause surfaced: the shipped "window" region
was a slice off the side of a chest, so no scale or tint could ever have saved
it. Where no pack had the art, ONE `create_1_direction_object` call with 16
`item_descriptions` produced lamb / lit hearth / bedded hollow / woven rug /
stag in a single billing event — the v0.19 "a pack bills per call, not per
subject" trick, used deliberately this time instead of opportunistically.
Every anchor is a measured alpha bbox; every scale is set from a target
on-screen height measured off the NEIGHBOURS the sprite has to live beside
(a_hunter 33px, citizen_f 30.0, human_laborer 30.2, wilovan 28.0), never from
a round number. Evidence is a real BEFORE at the lane base — for the in-engine
rows via a path-limited `git stash` + re-import + same script and seed, never
after-vs-memory — and windowed runs were serial with PNGs copied aside
immediately, since a re-run clobbers them.

| row | fix | evidence |
|---|---|---|
| Wilovan ships IDLE ONLY, attacks fall back to idle (the #390 comment's one named leftover) | `slice` (cane strike, ending on a swoosh), `hit` (recoil + impact stars), `death` (buckle → fall → prone), 3 kept facings each, feet plane holding at 95/128 so the measured anchor is unchanged. Only the states his kit can REACH: `combat_screen` picks `slice` for melee and `cast` for ranged, and basic_swordwork/quick_slash/counter_strike/quick_movement contains no spell, so `cast` stays an inert pin; nothing in `world.gd` or `board_renderer` plays `walk` for a non-player rig, so walk stays unbuilt on purpose rather than by budget | `lanes/l390-evidence/wilovan_combat_set.png` (all three clips, side facing — the one `play_anim`'s `%s_side` actually plays) |
| `hearth` cold-grey with no fire (carried since v0.16; the v0.18 pass fixed the light half and left this open) | owned lit hearth on the SAME id, so all five consumers inherit it with zero map edits | `lanes/l390-evidence/hearth_inengine_pair.png` |
| `window_blue` reads as a grey slab | the real four-pane window on `Furniture.png` `[132,355,24,25]` (already-licensed sheet), 0.85 | `lanes/l390-evidence/rug_inengine_pair.png` + visible again in the hearth pair |
| `rug_woven_cream` reads as a stain | regenerated as a real weave, judged against `rug_woven_red`'s medallion | `lanes/l390-evidence/window_rug_inengine_pair.png` |
| `worn_grass_bed` is a clump of blades, not a hollow | the bespoke bedded hollow this row asked for BY NAME, shed antler included | `lanes/l390-evidence/worn_grass_bed_pair_4x.png` |
| lamb pen has no lambs | `lamb` + `lamb_lying` (two silhouettes, not a retint); wired into the pen by #396 lane C, third lamb included | `lanes/l390-evidence/lamb_pen_pair_4x.png` + in-engine `lanes/l396c-evidence/02_pen_lambs_tend.png` |
| healed corusdeer stands up as a DOE while the copy names antlers | `corusdeer_stag`, antler tips ember-warmed so "barely glow" stays true; swapped inside the existing `visual_states` arm, sprite field only | `lanes/l390-evidence/corusdeer_stag_pair_4x.png` |

**What a later pass should NOT undo here.** `hearth` must stay one id: the
five rooms that use it are all rooms whose copy says the fire is fed, and
`cold_hearth` already exists for the dead one — splitting `hearth` into lit and
unlit variants would re-open the row it just closed. `lamb`/`lamb_lying` must
stay TWO sprites; a lying lamb is not a tinted standing lamb, and #396's observe
copy depends on the third animal reading as down. And the scales in this pass
are anchored to the measured neighbour heights above — moving one without
re-measuring the family is how the cast drifts.

**Rows carried, each with its reason written on the row** (Pallass tier ground
plane, Pallass market's green creature, face-to-face sprite overlap, night maps'
inverted hierarchy, `inn_upstairs` floor-material seam): three of the five are
NOT art rows at all — they need a floor-material pass across maps this lane does
not own, a per-layer night knob that does not exist in the mood schema, or a
dialogue-time separation in `world.gd`. Filing them as art kept them looking
cheap for three milestones. They are not.

## #396 close wave (2026-08-06) — `a_shepherd` eye-gate, PASSED

| row | verdict | evidence |
|---|---|---|
| `a_shepherd` must read as a DIFFERENT PERSON from `a_hunter` at gameplay zoom, not a re-dressed one (the v0.16.1 copy-only disambiguation failed exactly here, and the tint directive forbids shade variants standing in for distinct things) | **PASS — eye-gate read by the controller, recorded here.** The brimmed felt hat and the long crook carry the read at 1x: the hat breaks the head outline the whole village cast shares, and the crook puts a vertical line outside the body silhouette that no other Riverfarm figure has. Judged against the three neighbours he actually stands beside (`human_laborer` 30.2px, `citizen_f` 30.0px, retired `a_hunter` 33px) at the shipped `render_scale` 0.3837 = 33px, so he is the same size class and still a distinct shape | `potential_assets/pixellab_2026-08-05_396/silhouette_check_1x.png` (the gate shot — cold read at gameplay zoom) + `silhouette_check.png` (4x), `facings_8x.png`, `idle_filmstrip.png` / `walk_filmstrip.png` (all three kept facings, both clips), `rot_{north,east,south}.png`. In-engine, standing in the village beside the pen: `lanes/l396c-evidence/02_pen_lambs_tend.png` (+ `pen_lambs_zoom_2x.png`) |

**What a later pass should NOT undo.** `render_scale` 0.3837 and anchor
`[0.4946, 0.7337]` are both MEASURED, not chosen: the v3 canvas is 184px and
the anchor's x comes off the BOOT span, because the crook skews the full alpha
bbox and anchoring to it walks the figure sideways off its cell. The hat and
crook are the silhouette contract — a later re-cut may repaint him, but a
hatless or crookless shepherd re-opens the disambiguation row that the copy
alone could not close.

### #396 close machine playtest — new findings (2026-08-06)

Six scenes, windowed, serial, real overlay; evidence under
`lanes/l396-close-evidence/<script>/`. Every scene PASSED (verdicts in the
close-wave report); these are the rows the screenshots opened. One finding was
FIXED inside the wave and is recorded as fixed.

- [x] **(FIXED in-wave)** | `winter_topic` paged | `riverfarm_hunter.json` | The
  voice amendment pushed the node to 205 chars, one over `PAGE_CHAR_BUDGET`
  (200), with no sentence boundary in the last 20% — so it split into page 1
  plus a SECOND PAGE CONTAINING "…them." | `winter_teeth_talk/03_winter_topic`
  (the committed shot is the FIXED single-page render; the "…them." frame was
  the pre-fix capture) | **Trimmed to 186 chars, single page, retaken
  windowed.** Authoring rule this teaches: a T1 node past ~190 chars is a
  two-pager, and QA screenshots show the LAST page (`_is_qa()` jumps there), so
  a tiny tail page is invisible to a headless-green run and obvious in a shot.
- [ ] **(P2)** | village rows 12–13 sit inside the field-skill legend panel's
  band | `riverfarm_village` | With details expanded (the default — the button
  reads "Hide details [H]"), the bottom-anchored panel covers ~2 cell rows
  whenever the camera is bottom-clamped. Both of #396's non-combat route props
  live there: `wolf_sign_trail` [4,13] is two-thirds behind the panel at the
  moment of interaction, and `winter_fold_hurdles` [15,12] has only the top of
  its tall sprite showing — with the PC ITSELF fully occluded while standing at
  [14,12]. The target reticle and the toasts still read, so it is friction, not
  a blocker | `winter_teeth_talk/01_wolf_sign_before`,
  `winter_teeth_work/00_hurdles_stacked` | Fix candidates: move both props up a
  row (cheap, but re-derives two canonicals' routes), or give the panel a
  world-clearance rule like the hotbar's `HINT_BAND_CLEARANCE`. Lane C already
  paid this tax once — the tend prop sits at row 11 for exactly this reason.
  **WIDENED (#398 close playtest, 2026-08-07): a second map, and this time it
  eats a whole pocket.** On `ruin_surface` the briar-arch pocket sits at rows
  9–12, the camera is bottom-clamped there, and a 6-line expanded readout covers
  y≈405–570 — which is the pocket's entire interior. In both
  `lanes/l398-playtest-evidence/briar_arch_fire/00_briar_arch_closed.png` and
  `01_briar_arch_cache.png` the `briar_arch_wards` figures, the
  `briar_arch_cache` coffer AND THE PLAYER CHARACTER are all behind the panel;
  the coffer's own reward toast fires over a frame in which the coffer was never
  visible. Same on `deep_tunnels` (`collapsed_gallery_pick/…_pick_open.png`,
  PC behind the panel). This is no longer one map's prop placement — it is the
  panel needing the world-clearance rule. |
- [ ] **(P3)** | "Stacked Hurdles" reads as another fence post | `riverfarm_village`
  | `winter_fold_hurdles` borrows `riverfarm_fence_ns`, so the WORK route's
  material cache reads as one more upright beside the pen rail rather than
  hazel hurdles cut and stacked, which is what its observe promises. The
  sprite choice was deliberate (an EW panel merged INTO the rail run) — the
  answer is a stacked-bundle sprite, not another fence rotation |
  `winter_teeth_work/00_hurdles_stacked` (present) vs `01_fold_rebuilt`
  (consumed — the same frame minus the post) |
- [ ] **(P3)** | night watch: the ALLY's HP is the one number you cannot read |
  `river_wolf_pack` arena | The wolves' numerals are white-on-dark and legible;
  the PC's and A Shepherd's sit on their own near-black night sprites
  ("15/40" for the shepherd needed a 4x crop to read). New stakes, same
  carried "night maps' inverted hierarchy" row: this fight is the first where a
  player must decide whether to protect an ally, which means reading his HP |
  `winter_teeth_fight/01_night_watch_surrounded` |
- [ ] **(P3)** | `riverfarm_bank_washout` reads as an unrecognizable grey smear
  | `riverfarm_village` | The prop borrows `deep_fissure` (a dungeon sprite);
  at [20,9] it half-overhangs the river tiles and becomes the brightest-value
  object in that quadrant, pulling the eye to nothing. Its observe is a scoured
  trench down to the water — a bank-erosion sprite, or the fissure re-tinted to
  wet earth | visible in every village capture, clearest in
  `winter_teeth_talk/00_shepherd_hub_offer` |
- [ ] **(P4)** | the shepherd's hub opens on the exit line | `riverfarm_hunter.json`
  | With `heard_winter_teeth` unbanked the visible rows are
  "1. Just passing through." then "2. The wolves. Say what you need.", cursor
  defaulting to row 1 — a player who confirms on reflex leaves without hearing
  the quest exists. It is the cursor-pin rule's cost (the offer row was
  appended after the frozen ask slot), and reordering re-pins every legacy
  fixture's hub indices — ruling 11's exact hazard, so it needs a lane that can
  re-derive them | `winter_teeth_talk/00_shepherd_hub_offer`,
  `winter_teeth_prebank/00_prebank_hub` |

**What genuinely lands** (keep this — it tells the next session what not to
break): the hat-and-crook silhouette is unmistakable at gameplay zoom, even
half-lit at night; the three-lamb pen reads as a pen with sheep and the
reticle picks out the limping third; all three route toasts render their full
three lines with no fold clipping; and the PEAK line
("Wolves and me both, working round something neither of us can see.") lands
on one page with the quest-complete toast beside it.

## #398 Phase 0 — one windowed eye-check OWED at issue close (2026-08-06)

- [x] **(EYE-GATE, PAID 2026-08-07 — the bar FITS)** | a TEN-slot field bar vs
  the input-hint band | `field_hotbar.gd` `_layout_controls` | #398's weapon gate fields
  `[Power Strike]` off an equipped sword, so an armed warrior's AUTO bar grows
  by one and `martial_field_loop`'s armed phase now renders **10 slots**
  (previously 9). Finding 19 is the exact precedent: at NINE slots the centred
  group already ran under the bottom-left input-hint ribbon, and the clamp
  (`group_left = max(centred, safe.x + MESSAGE_LAYER_SCRIPT.hint_band_width +
  HINT_BAND_GAP)`) is what keeps it clear. A tenth slot widens the group by one
  `SLOT_SIZE.x` against a ribbon whose width is LIVE (device labels + text
  scale), so the clamp can push the group right until the far end runs into the
  bottom-right toast band instead — the other rect this layout has already lost
  a fight with. **Owed:** one windowed `martial_field_loop` capture at the
  armed-phase hotbar assert, read at 1x, at default AND 130% text scale, with
  the keyboard hint label showing. Headless is blind to it — the slot count
  asserts green either way | `lanes/l398-playtest-evidence/martial_field_loop/`
  `04_scree_crossed` + `crop_04_bar_2x` + `crop_04_hintband_2x`, and
  `martial_field_loop_130/04_scree_crossed` + `crop_130_bar_2x` |
  **PAID: it fits at both scales, on both maps, with the keyboard ribbon
  showing.** Measured from `ui_field_hotbar_rendered`: 10 slots,
  `group_width` 726 (bar 574 + gap 8 + toggle 144), `bar_left` 420 (dungeon) /
  462 at 130% — so the clamp is live, the ribbon clears with a visible ~20-30px
  gap at 100% and ~29px at 130%, and the group's far end lands at 1146 (100%) /
  1188 (130%), both inside 1280. Slots 9 and 10 both draw their key numerals;
  at 130% they are MORE legible than at 100% (where the tan-on-tan numeral is
  the weakest thing on the bar), though "10" starts crowding its own icon.
  Ruling context held: the 10-slot bar is ACCEPTED (slot 10 is cursor/mouse-
  reachable, number keys stay 1–9); this row was about whether it FITS.
  The row's OTHER prediction — "the clamp can push the group right until the far
  end runs into the bottom-right toast band" — is REAL but is a y-collision, not
  the x-overrun the row expected; it is split out as its own row below.
  Adjacent nit seen in the same 130% frame, no row opened: the top-right
  `Inventory` chip's label reaches the pill's inner border on both sides (fixed
  144px-class chip, scaling label) — zero padding, no clip. |

- [ ] **(P3, NEW)** | the toast band's bottom scroll-roller eats a hotbar
  slot's key number once the bar reaches 8+ slots | `field_hotbar.gd` +
  `message_layer.gd` | The slot row occupies y 658–710 (`offset_top =
  -SLOT_SIZE.y - CONTROLS_BOTTOM_MARGIN`); the toast panel is bottom-anchored at
  `TOAST_BOTTOM_DEFAULT -34` on `TOAST_CANVAS_LAYER 12`, above the bar, and its
  parchment's LEFT ROLLER dips ~28px below the panel body. `TOAST_BAND_RESERVE`
  is honoured by the READOUT rect only — the slot row has no reserve at all — so
  every slot whose x falls inside `TOAST_LEFT..TOAST_RIGHT` (808–1256) loses the
  top of its coin, and the one under the roller loses its numeral outright: at
  100% text scale slot 8's "8" is GONE and slot 7's is half-cut; at 130% (taller
  toast, `bar_left` 462) it is slot 7's that vanishes. The toggle pill draws
  ABOVE the toast and is unaffected, so the bar looks half-eaten rather than
  uniformly overlapped. Pre-#398 in mechanism (a 9-slot bar reaches x 808 too);
  #398 is what routinely renders 10 |
  `lanes/l398-playtest-evidence/martial_field_loop/crop_09_slots7_10_5x.png`
  (the "8" missing) and `martial_field_loop_130/crop_130_09_toast_vs_slots_5x.png`
  (the "7" missing) | Related, and the only prior note of it: the v0.18 W1
  residual bullet "the bottom controls row can still reach the strip's own
  footprint at 3+ hotbar slots" — this is that bullet, photographed, with the
  cost named. Cheapest honest fix is a `TOAST_BAND_RESERVE`-style y-clearance on
  the slot row (or raising the toast to `TOAST_BOTTOM_RAISED` whenever the bar
  is wide enough to reach the toast's x-band). |

## #398 close machine playtest — new findings (2026-08-07)

Six pockets, windowed, serial, real overlay (Furniture.png md5-matched against
main before any judgement), every PNG read at 1x plus gamma-boosted companions
for the two near-black maps. Evidence under
`lanes/l398-playtest-evidence/<script>/`. **K5 spot-read: uniformly excellent —
all five pockets' refusal/hint copy names the alternate mode(s) by skill name**
(pond reeds "Freeze that water, or cross it with [Double Step]"; all three
gallery faces name pick + [Greater Strength] + fire; the vault snare names
[Find Trap]/[Disarm Trap] AND the [Greater Strength] pry; the factor's hub node
names terms, side shutter and rear door in one breath; both briar halves name
burn AND cut with the weapon condition). A player who arrives holding only the
second mode is told so, every time.

- [x] **(P2, NEW — the headline) — FIXED 2026-08-07, and the two "lead" regions
  with it (see the verdict block at the end of this row).** | `crate`'s atlas
  region is mis-sliced, so
  every crate in the game renders as a ~14×41 dark sliver | `data/sprites.json`
  `crate` | `region [690, 71, 38, 26]` on `assets/props/free_pack/Furniture.png`
  has an alpha bbox of only `(30,2)-(38,25)` — the crate art on that sheet
  starts at x≈721, so the declared rectangle catches nothing but the left plank
  edge and the black open-top interior of the first crate. Scaled
  (`render_scale` 0.45 × the 4× world factor = 1.8) that 8×23 scrap draws as a
  14×41 near-black bar, offset to the RIGHT of its own cell because the anchor
  centres the empty 38×26 frame. Long-standing (the region traces to the
  project-dir-rename commit), and invisible for months because `crate` was only
  ever background dressing — **but #398 promoted it to reward-container duty on
  four pocket payoffs**: `floodplains` `frozen_cache`, `deep_tunnels`
  `collapsed_gallery_shoring`, `mercantile_alleys` `counting_room_trade_cache`,
  `ruin_surface` `briar_arch_cache`. There are ~40 placements across 17 maps
  plus 8 arena props plus 3 biome scatter pools |
  `lanes/l398-playtest-evidence/counting_room_social/crop_crate_sliver_A_8x.png`
  (the sliver at 8×, unmistakable), `.../crop_crate_sliver_B_8x.png`,
  `pond_island_freeze/crop_pond_black_bar_6x.png` (the same sliver floating on
  the pond as the Sunken Cache), `lanes/l398-playtest-evidence/crate_region_8x.png`
  (the region straight off the sheet) and `crate_neighbourhood_5x.png` (where
  the art actually is) | Fix is one region: ~`[721, 72, 31, 24]` for the single
  open crate, or ~`[721, 72, 31, 24]`/`[736, 72, 16, 24]` if the intent was the
  planked twin. **The same audit flags two more regions on this sheet as FULLY
  TRANSPARENT — `bar_counter [256,279,68,44]` and `stool [222,323,20,20]`,
  which would mean they render NOTHING** (used in `adventurers_rest`,
  `pallass_market`, and `inn`/`guild`/`barracks`/`stationer`/
  `brothers_parlor`/`riverfarm_longhouse` respectively) — plus `barrel
  [730,14,19,22]` at 39% fill and offset. Those three were not in this
  playtest's scenes, so they are a LEAD, not a claim: they want one windowed
  read of the inn common room and the Rest before anyone edits them.
  ——— **FIX, 2026-08-07. Four regions re-cut on drawn edges; all three leads
  CONFIRMED, none refuted.** The neighbourhood is a single alpha component
  (`x720-767`), so alpha bounds are useless here — the sheet draws two 16×23
  crates flush at `x720-751` sharing a DOUBLE dark divider (`x735` = the left
  crate's right outline, `x736` = the right crate's left) with a barrel flush
  at `x752`. Cuts are therefore on drawn outlines, verified against a per-pixel
  luminance dump, and every anchor came out of `sprite_alpha_probe.py`:

  | id | region BEFORE → AFTER | frame | rs | cells | anchor | eye-read verdict |
  |---|---|---|---|---|---|---|
  | `crate` | `[690,71,38,26]` (bbox `(30,2)-(38,25)`, 18.6% fill) → `[736,73,16,23]` | `[16,23]` | 0.45→1.0 | 1.00×1.44 | `[0.5,1.0]` measured (bbox `(0,0,16,23)`, pad 0/0) | reads as a planked wooden crate at 1× |
  | `bar_counter` | `[256,279,68,44]` (bbox **None** — 0% fill) → `[0,18,48,30]` | `[48,30]` | 0.25→0.35 | 1.05×0.66 | `[0.5,1.0]` measured (bbox `(0,0,48,30)`) | reads as a counter; drew NOTHING before |
  | `stool` | `[222,323,20,20]` (bbox **None** — 0% fill) → `[112,514,16,14]` | `[16,14]` | 0.6→0.75 | 0.75×0.66 | `[0.5,1.0]` measured (bbox `(0,0,16,14)`) | reads as a plank stool; drew NOTHING before |
  | `barrel` | `[730,14,19,22]` (bbox `(8,3)-(19,18)`, 32.5%, right-CLIPPED) → `[752,74,16,22]` | `[16,22]` | 0.7→1.0 | 1.00×1.38 | `[0.5,1.0]` measured (bbox `(0,0,16,22)`) | now a hooped barrel; was a POT, drawn ¼ cell off its own cell |

  **CLOSED vs OPEN crate — the choice, measured.** The row offered either twin.
  Took the CLOSED planked one (`x736-751`) over the open-top left one
  (`x720-735`): mean luminance **47.3 vs 32.3**, near-black pixels **29% vs
  48%**, and at 1× the open crate's 10×7 pure-black interior reads as a *hole
  or a doorway*, not a container — which is exactly the failure mode this row
  was opened for, and fatal in `deep_tunnels` (world band 13/255). Both twins
  rendered at final in-game size on a 64px cell grid with the anchor marked:
  `lanes/l398-art-evidence/crate_fix/prev_crate_closed_rs1.00.png` vs
  `prev_crate_open_rs1.00.png`; the sheet itself with pixel rulers at
  `sheet_crate_neighbourhood_labelled_8x.png` and `sheet_two_crates_14x.png`
  (the double divider is visible there). `render_scale` 1.0 is the pack's NATIVE 16px grid, so the
  crate is exactly one cell wide and its 0.44-cell overhang goes UP into air.

  **Both "render NOTHING" leads CONFIRMED, and the cause is the same for both:**
  `[256,279,…]` and `[222,323,…]` both land in `Furniture.png`'s door/window
  block, past the right edge of all art on those rows — they were never near a
  counter or a stool. The two counters and the stool now render:
  `lanes/l398-art-evidence/inn_leads/02_the_common_hall.png` +
  `crop_bar_counter_7_1_8x.png` (cell (7,1), "The Counter") +
  `crop_stool_8x.png` (cell (8,4)) + `crop_row1_counter_barrel_5x.png`
  (counter, barrel and shelf in one strip). The `barrel` lead is CONFIRMED
  worse than stated: not merely 39% fill but the wrong OBJECT (a small pot) and
  off-anchor — see `crop_barrel_8x.png`, in the counting room
  `lanes/l398-art-evidence/crate_fix/crop_barrel_insitu_6x.png`, and the
  before/after pair `prev_barrel_BEFORE_pot_rs0.70.png` (anchor dot sits OUTSIDE
  the art) vs `prev_barrel_AFTER_hooped_rs1.00.png`. Counter and stool at final
  size: `prev_barcounter_sideboard_rs0.35.png`, `prev_stool_bench_rs0.75.png`.
  Crate evidence: `lanes/l398-art-evidence/crate_fix/`
  `01_counting_room_trade_bale.png` + `crop_trade_cache_5x.png` (the trade
  cache at 5×, unmistakably a crate) + `crop_crates_pair_5x.png` (two crates in
  one frame) + `00_counting_room_factor.png` (the room at 1×).
  **The size increase was checked against the Relc lesson, and it is CLEAN.**
  `crate` backs 8 arena cover props and went from 0.22×0.64 to 1.00×1.44 cells,
  so the risk was a tall prop sprawling over combatants' HP bars. Shot the board:
  `lanes/l398-art-evidence/combat_check/04_forge_hall_board_mid_combat.png` +
  `crop_board_crates_vs_bars_3x.png` — three crates and the golem's `70/70` bar
  in one frame, zero occlusion, no `combat_scale` override needed. That capture
  also **closes the carried "`forge_hall` board's `crate` cover still reads as
  small dark posts rather than crates" bullet** (the residual list above, cited
  to this very screenshot): they now read as crates. Field equivalent, crate and
  barrel side by side: `combat_check/01_south_square_scavengers.png`.
  Gates: `data_lint` 0 · `test_sprite_registry` PASS post-import, 0 warnings ·
  `counting_room_social` / `pond_frozen_cache` / `collapsed_gallery_pick` /
  `briar_arch_fire` all PASS headless @ seed 9 · `adventurers_rest_loop`,
  `collapsed_gallery_negative`, `crate_fight`, `pallass_standards_fight` all
  PASS windowed @ seed 9 · `comment_census --check` 0 (the four `_comment`
  bodies had to be trimmed — the repo DATA comment ratio sits at 14.97% against
  a 15.00% cap, so a verbose sprites.json note is now a GATE, not free prose).
  Overlay `Furniture.png` md5-censused against main (`a10c8fd5…`) BEFORE
  measuring. |

- [ ] **(P2, NEW)** | the collapsed gallery's three entrance faces do not read
  as three things — two of them read as nothing | `deep_tunnels` (14,1)/(14,2)/
  (14,3) | At the locked state, world-band mean luminance is 13/255 (p90 12.9),
  and at 1x the entrance column is black. Boosted 4× the three resolve as: a
  pale grey lump (`dungeon_rubble`, "Mortared Rubble"), a brown rounded lump
  (`boulder` at tint [0.55,0.38,0.24], "Fallen Beam" — it reads as a rock, not
  as a beam: no length, no timber, no direction), and the `crate` sliver above
  at tint [0.32,0.24,0.2] ("Tarred Shoring" — invisible, and its visible pixels
  sit at the RIGHT EDGE of the interact reticle rather than inside it, so the
  reticle frames bare floor). It is P2 and not P1 only because the K5 copy
  carries the whole pocket: each face's refusal names all three verbs, so a
  player is never stuck — but nothing on screen distinguishes the three |
  `lanes/l398-playtest-evidence/collapsed_gallery_negative/collapsed_gallery_locked.png`,
  `crop_three_props_raw_4x.png` (what the player sees) vs
  `crop_three_props_boost_4x.png` (what is actually there) | Order of work:
  the `crate` region above fixes the shoring for free; the beam wants a long
  canted timber silhouette rather than a tinted boulder; the darkness itself is
  the carried "darkest cave grade" condition, not a new row.
  **PARTIALLY PAID 2026-08-07 by the `crate` region fix — the SHORING half is
  done, the row stays open on the other two.** Re-shot windowed
  (`collapsed_gallery_negative`, seed 9): the Tarred Shoring now draws a full
  crate silhouette CENTRED INSIDE its interact reticle — the row's sharpest
  complaint ("its visible pixels sit at the RIGHT EDGE of the reticle … so the
  reticle frames bare floor") is gone, because that offset was the empty 38×26
  frame, not the tint. It is now legible as a crate at 1× despite a 25.7/255
  world band. What did NOT change: the tint `[0.32,0.24,0.2]` still crushes it
  to a near-black box, so "three faces, three things" is still unmet — the
  remaining work is the BEAM's silhouette and the tint grade, not any region.
  Evidence `lanes/l398-art-evidence/crate_fix/collapsed_gallery_locked.png`,
  `crop_shoring_crate_reticle_7x.png` (raw 1× crop at 7×, crate inside the
  reticle brackets) and `crop_shoring_crate_reticle_7x_boost.png` (same, ×4.5). |

- [ ] **(P3, NEW)** | the floodplains pond does not read as water, and the
  island does not read as an island | `floodplains` (8–13, 17–21) | Flat cobalt
  rectangles with one diagonal stripe, razor 64px edges against the grass, no
  shore, no depth grade, no shimmer at this cap — at gameplay zoom it reads as
  blue floor tiles laid on the field. The re-sited island is a 3-cell notch
  ((10,20),(11,20),(11,19)) of the SAME grass texture as the mainland, so the
  destination reads as a gap in the blue rather than as land in water, and the
  guardian's own observe ("holds the dry crown of the island") has nothing on
  screen to point at | `lanes/l398-playtest-evidence/pond_island_freeze/`
  `crop_pond_island_2x.png`, `01_freeze_landing.png` | Same family as the
  already-open Invrisil plaza razor-edge row (wang transition tiles) and the
  #30 flat-fill history; the island half additionally wants a bank/shore cell
  so the crown is visibly dry. |

- **POSITIVE — the bespoke ice plate lands, and it lands under the player.**
  The (P1) ICE TILE row's residual (a) (`world.gd` off `WATER_SHEET`+`ICE_TINT`,
  onto `assets/tiles/ice/ice_floor_tiles.png` at (0,0)) is verifiably DONE:
  `ICE_TINT` is gone from `world.gd` and the frozen cell renders as an opaque
  pale plate with a rime rim and white fracture seams — unmistakably a
  different SURFACE from the water beside it, at 1x, in the same frame, and
  still readable with the PC standing on it. Evidence
  `pond_island_freeze/01_freeze_landing.png` (frozen (12,20) beside open water)
  and `pond_frozen_cache/crop_frozen_cache_4x.png` (the PC on the plate).
  Residual (b) — the "the channel locks to grey-white ice" wording in
  `skills.json` `frost_touch.freeze_toast` and the two `interactions.json` thaw
  lines — is UNCHANGED and now fires on a POND, where "channel" is the wrong
  noun. Still ship-safe: `frost_touch` remains a QA-fixture-only grant (no
  shipped class carries `freezes`; the pond's player-reachable mode is
  [Double Step]), so the row's ordering RULE is not yet violated. The row stays
  open on (b) alone.

## #398 P3 — the warded side vault: two art asks OWED (2026-08-07)

Both are sprite-legibility rows raised by the P3 fix-wave review, not bugs:
headless asserts green either way, so only an eye can settle them. They pair
with the standing directive that **tint is not disambiguation** (2026-08-02):
a shade variant never reads as a separate thing, distinct silhouettes do.

- [ ] **(ART, owed)** | `pressure_plate` now carries THREE distinct jobs on one
  map | `data/maps/dungeon/trapped_halls.json` | `pressure_plate_a` (6,7) is a
  *trap to trigger*, `warded_side_vault_snare_release` (2,10) is a *mechanism to
  disarm*, and `warded_side_vault_pry_plate` (7,10) is a *slab to lever out* —
  three different verbs behind one sprite id, two of them five cells apart on
  the same y-band. A player who has learned "flagstone = do not touch" from
  (6,7) meets the same art at (7,10) where the correct move is to heave it. The
  fix is silhouette, not tint: the release wants visible wire/catch furniture,
  the pry plate wants a raised, canted edge you can read a lever into.
  **Owed:** one windowed `warded_side_vault_warrior` capture at
  `00_warrior_vault_open`, plus one `dungeon_peek` at
  `04_trapped_halls_landing`, read at 1x — do the three plates read as three
  things? | **EYE-CHECK PAID 2026-08-07 — CONFIRMED, and the shot is worse than
  the row's own framing.** The named captures were the wrong ones: all three
  props carry `absent: warded_side_vault_open`, so by `00_*_vault_open` they are
  already consumed and the frame is empty. `warded_side_vault_gate_check`
  `00_both_modes_locked` is the frame that holds them, and it puts BOTH live
  plates on ONE screen three rows apart: (6,7) "A Loose Flagstone" (step on it
  and it fires) and (7,10) "A Warded Floor Plate" (heave it) are PIXEL-IDENTICAL
  — same grey cracked slab, no tint difference, no furniture. Only the reticle
  and the observe text separate them, and the reticle follows facing, so at rest
  nothing does. Mitigating: (2,10) shows `snare_coil` (a distinct wire ring)
  until [Find Trap] banks, so the third plate only appears after the first is
  solved — the row's "three at once" never happens; two-at-once does, in one
  frame. Severity stands at art-ask, not blocker. Evidence
  `lanes/l398-playtest-evidence/warded_side_vault_gate_check/`
  `00_both_modes_locked.png` + `crop_two_plates_boost_3x.png` (the two slabs
  side by side) + `crop_snare_coil_boost_4x.png` (the coil that DOES read) |
- [ ] **(ART, owed)** | the construct is `ruin_warden` at a warden tint |
  `data/combatants.json` `side_vault_construct`, `trapped_halls.json`
  `warded_side_vault_construct` | The entity carries `tint [0.58,0.64,0.76]` on
  the map and `combat_tint [0.72,0.8,0.88]` on the board over the SAME
  `ruin_warden` art the ruin guardians use. That is exactly the shade-variant
  pattern the tint directive rules out: on the field it must read as a warded
  vault mechanism, not "a ruin warden that is slightly bluer". Cheapest honest
  fix is a distinct silhouette pass (ward-line etching, a narrower stance) or a
  dedicated sprite; the tints stay as grade, never as identity. **Owed:** one
  windowed `warded_side_vault_rogue` capture at `00_rogue_vault_open` (field
  read) and one at the combat board, read beside a `ruin_guardian` fight |
  **EYE-CHECK PAID 2026-08-07 — split verdict.** It DOES read as a guard: at 1x
  in a 15.7/255 world band it is the largest, most legible thing on screen, a
  clear heavy armoured silhouette, and a player will read "something is standing
  in the doorway" without help. It does NOT read as a *warded vault mechanism*
  distinct from the ruin's own wardens — `seal_warden_alcove` (19,6) is the SAME
  `ruin_warden` rig at tint [0.42,0.42,0.46] and sits in the SAME FRAME as the
  vault construct at [0.58,0.64,0.76], so the one screenshot contains two
  identical silhouettes in two shades: the tint-is-not-disambiguation case,
  photographed. Art ask stands as written (silhouette pass, tints as grade).
  Combat-board half not shot — the rogue route's fight resolves headless-fast
  and the script takes no board frame; it needs a `screenshot` step added inside
  the combat window before that half can be judged. Evidence
  `lanes/l398-playtest-evidence/warded_side_vault_rogue/00_rogue_vault_open.png`
  + `boosted_00.png`, and both wardens in one frame at
  `warded_side_vault_gate_check/00_both_modes_locked.png` |

## 2026-08-08 — user playtest: Floodplains (3 findings, 2 generalize corpus-wide)
1. **P2 — frozen_cache renders as a dry crate ON the pond** (10,18).
   Prose says "on the pond floor under a coat of silt"; sprite is plain
   `crate`, newly BOLD since #398's atlas fix (was an invisible sliver).
   Art/prose contradiction class: needs a submerged/silted variant or
   water-tint treatment, not a prose fix. Same "suddenly visible art"
   class as the #398 bar_counter/stool fixes — eye-test those rooms too.
2. **DESIGN RULING (user): discovery over instruction.** floodplains
   [34].toast "Freeze that water, or cross it with [Double Step]" is too
   explicit — player should learn through exploration. Generalizes to
   the whole #398 K5 explicit-menu class (scan attached in HANDOFF):
   trapped_halls [17-19], mercantile_alleys [17-18], ruin_surface
   [28-29], deep_tunnels [9-11] (worst: "Select [Greater Strength] and
   use it on the beam" — pure UI-speak). Supersedes #398's explicit-
   teaching stance; re-author as diegetic capability cues (the round-2
   l3 idiom: "takes strength you have not learned yet"), never skill
   menus. [Skill] — receipt toasts are NOT in scope (outcome convention).
3. **P2 — pond island reads land-connected** (diagonal contact at its
   SE corner). Fix by widening water/pond so the island is fully ringed;
   route re-derivation owed on pond_island_freeze/pond_island_blink +
   pond_frozen_cache. Mechanical diagonal-scan inconclusive — eye-test
   the class: frozen_cache one-cell water strip, rope-gap lips
   (trapped_halls 13,0/13,1), briar-arch mouths, counting-room seal.
4. **P3 — decor crate/barrel scatter** reads random where unstaged:
   floodplains 4 (field/pond context — worst), street 10 (north wall
   line — eye-test), den_shop/forge_hall 2 each; mill/longhouse/alleys
   read plausibly staged. Audit placement context, not the sprite.
