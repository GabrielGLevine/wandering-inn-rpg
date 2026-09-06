# Visual-Fix Log (living)

> **Standing directive (user, 2026-07-04):** log every visual /
> presentation defect here when seen; every milestone drains log as
> standard gate item. Baseline this stage: wrapping, clipping, readability,
> font choice SOLVED; interfaces standardized (add element must not need
> coordinate tweak); common-sense checks pass (animation/icon/sfx match
> action); incremental work ships max fidelity —
> best-candidate sprites from in-hand packs, never rectangles or recolours.

Insertion: tail — append new rows at end of file; closing a row deletes it
in place (same commit as the fix).
Format: `- [ ] **(Pn)** AREA — defect — evidence — fix direction`.
Close row = delete it in same commit as fix, cite evidence
in commit/PR body.

**Pruned 2026-08-10.** ~170 closed rows + wave narration removed;
full history in git (`git log -p -- docs/VISUAL-LOG.md`, pre-`ec57cbc6`).
Rows drained by #400 batch close (Pallass checkerboard, blue-brick forge,
inn_upstairs seam, night read-hierarchy, face-to-face merge, market creature),
#408/#409 art lanes (prop variety, idles, pond/shoreline, frozen_cache),
r3–r5 playtest waves — gone from this file.

## Standing lessons (do not re-learn)

- `ui_dialogue_rendered` / `ui_toast_rendered` fire on PAYLOAD, not
  pixels. Script that interacts right after fixture loads can
  screenshot empty slot and still go green. Eyes decide, events don't.
- Tint never disambiguation. Shade variants read as same object; tints
  grade only. Distinct things need distinct silhouettes.
- `invisible: true` = data_lint marker engine never reads. Renderer
  contract is `hide_sprite: true` — spriteless entity otherwise falls
  through to `ColorRect` of `PROP_COLOR`.
- `qa_output/` regenerated, not stored. Evidence path = claim about a
  COMMAND; always name run that produces it.
- Every QA fixture ships `times_slept` unset, so every windowed shot here
  taken with field-skill readout EXPANDED.
- Rig swap must re-read tint, never carry it — tints chosen against
  old rig's value, go near-silhouette on darker one.

## Open — HUD, panels, toasts

- [x] **(P2)** Ambient line invisible after load — `talk_pool` line served
  within ~1.5 s of `world_ready` renders NOTHING (panel rect `message_layer.gd:443`,
  x 36–736 / y 461–556, empty map) while `ui_dialogue_rendered` carries
  full string. Same-NPC/seed A/B: `_vlog_line_timing/01_interact_at_world_ready.png`
  vs `02_interact_90_frames_later_no_move.png`, only delta = 90 idle frames.
  Global and pre-existing; reach = any NPC adjacent to arrival cell.
  LEFT OPEN (fix/hud-copy-loss), not reached — recorded so the next pass does
  not re-walk it. The line reference has rotted (`message_layer.gd:443` is now
  the first-pickup-hint arm); the rect it names, x 36–736 / y 461–556, is
  `_dialogue_panel`'s, derived in `_resize_dialogue_panel` from
  `DIALOGUE_BOTTOM = -164.0`, so the panel geometry is right and the panel is
  not mis-placed. Ruled OUT as the cause: layer teardown — `main.gd
  swap_to_world` spawns the UI layers BEFORE the world emits `WORLD_READY`, so
  a line served after that event is on the live MessageLayer, not an orphaned
  one. The remaining suspects are both in `_show`: the panel is hidden for the
  rest of its hold by any `_clear_dialogue_line()` (the `MAP_CHANGED` /
  `DIALOGUE_STARTED` / `COMBAT_STARTED` arms) with no re-show, and the GH#324
  capture race that `_await_capture_release` was built for — whose own doc
  comment describes this exact symptom near `world_ready` and names the boot
  music crossfade (1.0s) as what pushes a capture past the hold. Next pass
  should A/B those two before touching anything.
  CLOSED (#509). The A/B was done and the panel WAS rendering: the line sat
  under FieldHotbar's expanded readout -- same canvas layer (1), added later,
  covering 81% of the line rect (`line_display_ab/01`, measured by the
  driver's `assert_dialogue_displayed`, which now FAILS on >=20% overlap by a
  visible panel on an equal-or-higher layer). FIX: the line panel is a child
  of the toast layer (12), like every other piece of feedback; tripwire in
  `test_message_layer._check_line_panel_on_toast_layer`.
- [x] **(P2)** Authored payoff prose queues behind housekeeping toasts — on
  `handoff_quiet` order is `Autosaved.` → `Quest updated:` → payoff line,
  and `PLAYER_MOVED` dismisses early, so walking player never reads it
  (`invrisil_hat_quiet/03_the_wrong_coat_on_the_way_out.png`; only `Autosaved.`
  reached `ui_toast_rendered`). Fix: authored prose wins queue, or save
  toast leaves strip.
  CLOSED (fix/hud-copy-loss). CAUSE: GH#325 reordered the QUEUE, which does
  nothing in the sequence it was written for — game.gd autosaves from inside its
  own `QUEST_BEAT_COMPLETED` listener, so the queue is still EMPTY when
  "Autosaved." arrives; it is popped and SHOWING by the time there is anything
  to insert ahead of, and `_authored_insert_index` never sees it. The re-checked
  `TOAST_QUEUE_HOLD_CAP_SECONDS` did not help either: under the windowed QA hold
  (0.4s) the 1.6s cap never binds at all, so every capture of that beat
  photographed the chore. FIX: a chore holding the strip now yields it OUTRIGHT
  (cap 0.0) the moment authored copy is queued behind it
  (`message_layer.gd _queue_has_authored`); chore-behind-chore keeps the 1.6s
  cap. COST, exactly: the chore loses not the tail of its hold but ALL of it —
  the cap collapses to `started_msec + int(0.0 * 1000.0)` == `started_msec`, a
  deadline already in the past, so the loop exits on its next check however long
  the chore has been up. Measured, same run: the two `ui_toast_rendered` events
  either side of the yield are 13–14 ms apart — the chore's whole on-screen
  life; the wave audit's panel-visibility probe put it at `visible_ms` 0 against
  7 and 8 for the authored toasts behind it. Nothing is LOST, which is the
  separate claim the safety case rests on: `record_message` runs in
  `_drain_toasts` before `_show` is awaited and `ui_toast_rendered` fires above
  the interruptible loop, so a yielding chore has already recorded and already
  rendered; no queue entry moves, no render is skipped, emission order
  byte-identical.
  EVIDENCE, `qa/run_qa.sh invrisil_hat_quiet windowed --seed=37`: the capture
  named for the payoff now reads authored copy ("Quest updated: Go back to the
  parlor and tell Wilovan how the evening went.") where it read
  "Autosaved. (Esc — save/load anytime)". Events, same run: BEFORE, `Autosaved.`
  was the only one of the beat's three toasts ever to reach
  `ui_toast_rendered`; AFTER, the chore renders and retires and the authored
  line renders 14 ms later. Guard: `tests/test_message_layer.gd`
  `_check_housekeeping_class` (behavioural, mutation-proven — stubbing
  `_queue_has_authored` to `return false` reds it).
  RESIDUAL, logged not hidden: the beat emits TWO authored toasts and the
  capture shows the FIRST (`Quest updated:`, itself sticky authored beat text);
  the payoff line renders behind it, past this script's last step. And the
  `PLAYER_MOVED` half is untouched — an unsticky authored toast is still
  dismissed by the next step, which is the shipped "I have read it" rule.
- [ ] **(P2)** Field-skill readout eats world's bottom rows — ships
  EXPANDED until first sleep (`field_hotbar.gd:220-222`), covers y≈480–600
  across x 285–1000, which in 8–9-row interiors = bottom two rows: PC
  half-buried (`adventurers_rest_loop/02`), exit doors hidden
  (`flood_ledger_talk/01`, `thicket_keeps_talk/01`), riverfarm rows 12–13 props
  (`winter_teeth_talk/01`, `winter_teeth_work/00`), and on `ruin_surface`
  whole briar-arch pocket incl. PC and coffer whose reward toast fires
  over frame that never showed it (`l398-playtest-evidence/briar_arch_fire/00`,
  `01`; same on `deep_tunnels`). Fix: world-clearance rule like hotbar's
  `HINT_BAND_CLEARANCE`, not per-map prop moves.
  LEFT OPEN (fix/hud-copy-loss). MEASURED: a world-clearance rule cannot close
  this on its own, and the arithmetic says why. The world renders into a
  320x180 SubViewport at `WORLD_SCALE` 4 (`main.gd`), so a cell is 64 screen px
  and 11.25 rows are visible in 720. `camera_controller.gd axis()` centres any
  map shorter than the view, so an 8-row interior (512px) sits y 72–648 — and
  the readout band alone is y≈445–572, with the slot row and toggle under it to
  712. There is no camera offset that puts 512px of content above 445px of
  clear screen: the reserve would have to be smaller than the content is tall.
  A real clearance therefore needs either a smaller world scale on short maps
  or the legend not shipping EXPANDED, and both are product calls, not layout
  bugs. The one honest lever inside the HUD is the default: `_expanded` comes
  from `WISettings.field_readout_expanded()` and only flips false at the first
  waking (`field_hotbar.gd` `WORLD_READY` / `UI_SLEEP_VEIL_FINISHED` arms), and
  only TWO QA scripts pin `expanded` at all (`field_skills_loop`,
  `hotbar_tab_loop`) — so flipping the boot default is cheap in pins and
  expensive in intent. Not taken unilaterally on a tag night.
  PARTIAL RELIEF this branch: the legend now sits x 80–800 instead of 280–1000
  (see the overdraw row below), so the world's bottom-RIGHT rows are clear —
  the covered AREA is unchanged, only which cells it covers.
- [x] **(P2)** Legend ↔ toast mutual overdraw still LOSES COPY at length —
  v0.17 fix moved short toasts to own band, but 4-line toast still
  clips legend mid-word ("…old timber in momen", "You have learned h";
  `property_seams/02,05,06`). Legend grows row per field skill, so overlap
  band deepens with progression. Fix: mutually exclusive, or legend
  collapsible/anchored clear of toast band.
  CLOSED (fix/hud-copy-loss), by the "mutually exclusive" arm. CAUSE:
  `TOAST_BAND_RESERVE` is measured at the strip's BASE height (96px), but a
  toast is exactly as tall as its copy wraps — a 4-line one tops out ~38px
  INSIDE the reserve and, drawing on CanvasLayer 12 against the field hotbar's
  default, paints straight through the legend's last row. A taller reserve is
  the same arithmetic one round later: nothing bounds a toast's line count. FIX:
  the exclusion is HORIZONTAL and therefore height-independent — two rects that
  do not share an x range cannot overdraw at any height. `readout_rect` takes a
  `right_limit`; `field_hotbar.gd` derives it from the strip's own live left
  edge (`viewport_size.x + MESSAGE_LAYER_SCRIPT.TOAST_LEFT`, never a copied
  number) minus `TOAST_BAND_CLEARANCE`. Centring yields, as it already does to
  the hint ribbon on the slot row: centring is cosmetic, the copy is
  information. Static, so nothing jumps under a reader.
  EVIDENCE, `qa/run_qa.sh property_seams windowed --seed=37` — the MECHANISM,
  measured, because no single frame in this script can show the cure: the
  readout plate's top edge measures x 80–799 off the PNG itself (same number in
  `02` and `05`) against a toast band that starts at x 808, an 8px clear
  matching `TOAST_BAND_CLEARANCE`; it was x 280–1000, 192px shared. The
  mutation's own RED quotes the pre-fix number back — "readout ends
  1000.000000, band starts 808.000000". `ui_field_hotbar_rendered`
  `bar_left`/`group_width` unchanged (422/436): the slot row does not move.
  NOT CITED AS PROOF, deliberately (it was, and it did not hold): the "moments."
  tail in `05_nook_cleared.png`. Legend row 4 sits at y 514–526 while that
  frame's toast tops out at y 560 — 34px clear — so that word reads whole with
  OR without the fix, in `02`, `05` and `06` alike. The row's original
  "…old timber in momen" came from a taller toast than any frame this script
  captures. Geometry is the evidence here; the PNG only shows the two plates no
  longer sharing a column. Guard: `tests/test_settings.gd`
  `_check_field_hotbar_layout`, mutation-proven — deleting the `right_limit`
  clamp reds it with "readout ends 1000.000000, band starts 808.000000".
  RESIDUAL: below ~1228px of viewport width the pair cannot both fit, and the
  readout degrades to "hard left" (strictly less overlap than centring) rather
  than excluding. `canvas_items` stretch keeps the shipped game at a 1280x720
  logical viewport, so only the mobile safe-area rows reach that branch.
- [ ] **(P2)** PC drawn under field chips on bottom-row cells — no HUD-safe
  area (`invrisil_house_name_talk/03`). `src/ui/**`; no sprite change can move
  chip off player.
  LEFT OPEN (fix/hud-copy-loss) — same missing model as the readout row above,
  and it fails for the same arithmetic. Confirmed there is no HUD-safe area at
  all: `field_hotbar_layout.viewport_safe_rect` is the DISPLAY notch inset
  (mobile/true-fullscreen only — `_current_safe_rect` returns the whole viewport
  otherwise) and nothing publishes an occupied-band rect to the world renderer,
  so `world.gd`/`camera_controller.gd` have no input to clear. The slot row is
  pinned to the viewport bottom (`offset_top = -SLOT_SIZE.y -
  CONTROLS_BOTTOM_MARGIN - safe_bottom`), i.e. y 658–712 at 1280x720, which is
  inside the last world row on every map. Closing it needs the same
  world-clearance model as the row above and should be taken with it, not
  separately.
- [ ] **(P2)** "Inventory" nav pill overflows at 115/130% text scale — sibling of
  shipped hint-ribbon fix, same cure (font-derived rect).
- [ ] **(P2)** "[Mixer] has become [Alchemist]!" enqueued, never rendered
  (15 enqueued / 10 rendered, shared FIFO with loot in `src/ui/message_layer.gd`).
  Class evolution's moment has no photograph; wants own lane or beat.
  LEFT OPEN (fix/hud-copy-loss) — deliberately, as out of tag-night reach.
  Re-measured `qa/run_qa.sh mixer_alchemist_loop headless --seed=37`: 13
  enqueued / 6 rendered, and the last render of the whole run is "Got: Solvent
  Phial" — a pickup from three steps earlier, landing AFTER the map change into
  `inn_upstairs`. Nothing is dropped (the queue is lossless); the strip is
  simply running a BACKLOG, and every toast from `[Mineral Distillation]` on —
  including the evolution line — is still queued when the script ends. So the
  cause is not the evolution toast: it is that `Got: X` loot receipts are
  classed AUTHORED, take a full `_toast_seconds` hold each, and the strip is
  therefore minutes behind the beat it is describing. The one-flag cure —
  reclassify loot receipts as `housekeeping`, which makes `_authored_insert_index`
  and the new `_queue_has_authored` yield both fire for the evolution line — is
  a semantic change to a shipped signal that 125 QA scripts wait on
  `ui_toast_rendered` for, and reordering renders against those cursors is
  exactly the failure `QA_TOAST_HOLD_HEADLESS_SECONDS`' own doc comment
  records. Wants the deliberate lane the row asks for, on a day with room to
  re-gate all 125.
- [ ] **(P2)** Difficulty + Quest Hints ship with no in-game explanation
  (`settings_loop/01_settings_help_panel` has 6 sections, neither is one;
  `00_settings_panel_rows` reads bare "Difficulty: Silver"). Knob's best
  property — damage TAKEN only, enemy stats/accuracy/fight shape identical at
  every rung — stated only in code comment. RESOLVED-BY-#447 route: the Help page's
  "Difficulty & Quest Hints" section now carries the explanation and the
  descriptor tails were deliberately removed (one-voice ruling) — verify the
  Help section suffices in an eye pass, then close this row.
- [ ] **(P2)** Settings row order buries gameplay knobs — #338/#345 appended
  after Export/Import Save to honour `settings_panel.gd`'s append-only index
  contract, so "Quest Thread" (row 11) and "Quest Hints" (row 15) split by
  four unrelated rows in 17 flat ungrouped rows. Re-order + section headers,
  re-pin `settings_loop`'s indices in same commit.
- [ ] **(P2)** Settings parchment fills 708 of 720 px (`PANEL_SIZE` 648→716 for
  two new rows) vs journal's y=82..635. Nothing clips, but bleeds off
  both edges with no room for own ornament. Next row needs scrolling list
  or second page — take it with row-order rework.
- [ ] **(P3)** Toast band's left parchment roller eats hotbar key numbers at 8+
  slots — `TOAST_BAND_RESERVE` honoured by READOUT rect only, so every
  slot inside x 808–1256 loses top of its coin and one under roller
  loses numeral (slot 8 at 100%, slot 7 at 130%).
  `l398-playtest-evidence/martial_field_loop/crop_09_slots7_10_5x.png`. Fix:
  y-clearance on slot row, or raise toast when bar reaches that band.
- [ ] **(P3)** 1-slot hotbar coin drops key number while 2+ slot coins keep
  it (`field_skills_loop/00_hotbar_boot_1slot`, `05_hotbar_remapped_1slot`). Boot
  is 1-slot state, so this is first-session case. Draw it unconditionally.
- [ ] **(P3)** Cooldown badge = bare 10 px default-colour digit at slot's
  top-right (`hotbar.gd:170-177`) — ~1.3:1 against plate, twin in size to
  key hint at top-left, no legend, hardcoded font size so ignores Text Scale,
  while AP pips and MP diamonds beside it carry deliberate colours. Photo:
  `class_evolution_loop/03_power_strike_cooldown_badge`. Wants
  `AP_PIP_COLOR`/`MP_DIAMOND_COLOR` treatment two lines above it.
- [ ] **(P3)** Journal sub-rows lose indent on wrap — continuation lines
  return flush-left, read as body text (`journal_quest_hints/00`,
  `journal_history/01`). One hanging-indent change on shared sub-row style.
- [ ] **(P3)** Skills-tab scroll can rest on orphan wrap fragment — top visible
  line is bare "L5" (`journal_categories/01`, `/02`). Cursor-follow should snap
  viewport to topmost whole row.
- [ ] **(P3)** Cooled Skills lose flavour text permanently
  (`combat_hud.gd:613-637`): when cooldown clause + description would wrap,
  description yields, never returns at readiness. Deliberate; logged so
  trade visible when readout budget next revisited.
- [ ] **(P3)** Character-creation pick step is only unlabelled step (six
  sprites, `options:[]`), and new steps' footer mixes casing
  ("…Esc to go back • change it any time in Settings").
- [ ] **(P3)** Bottom HUD cluster jumps ~25 px left, grows ~4% after Reduce
  Motion round trip (`feel_peek_night/01` vs `/03`) — every other 2-slot frame
  sits at 512/570/667 positions. Likely scale/anchor reduce_motion resets.
- [ ] **(P3)** Misc panel bleed: dialogue panel draws over hint ribbon's tail;
  Lady's coda orphans 92 chars on blank parchment; debug overlay has no
  backing plate (dev-only).
- [ ] **(P4)** Hint bar's left parchment ornament renders off-screen at x < 0 and
  "Esc" starts ~4 px from window edge, while right end keeps full
  ornament (`seal_open/08`, `arc_flow/07`). Cosmetic margin fix.

## Open — combat board

- [ ] **(P3)** Stacked HP bars — combatant one cell above another has BAR
  behind lower sprite; one on lower rows has it behind feed panel.
  Numerals survive, so nobody blind, but at-a-glance signal is the half
  that vanishes (`arc_flow/dd_06`, `sewers_walkthrough/01`, `riverfarm_fight/01`,
  `status_first_encounter/01`). Bars want own z-layer above combatants.
- [ ] **(P3)** HP numerals draw ON tinted body, so dark tints cost contrast
  warm ones don't (`door_chain_fight/00`: ember vermin reads, its violet
  and cold-blue siblings sit dark-on-dark). Fix: key numeral's outline off
  resting modulate's luminance.
- [ ] **(P3)** At night ALLY's HP is the one number you cannot read — PC's
  and A Shepherd's numerals sit on own near-black sprites ("15/40" needed
  4× crop) while wolves' read white-on-dark
  (`winter_teeth_fight/01_night_watch_surrounded`). First fight where player
  must decide whether to protect ally.
- [ ] **(P3)** Spawn-cell overlaps: `line_stalker_a`/`_b` on `witch_hollow` merge
  into one two-headed creature (mothbear rig taller than cell);
  `granary_scavenger_a`/`_b` on `inn_cellar` same, milder. Contrast fine
  in both — spawn-cell choice, not tint one.
- [ ] **(P3)** `mercantile_alley` arena at DAY = large flat tan field with few
  scattered dark props — nothing says "alley": no wall line, no narrowing, no
  paving change, in city whose one traversal signature is alleys
  (`invrisil_house_name_fight/03`).
- [ ] **(P4)** Forge-hall cover renders as one legible `forge_station` plus four
  small dark `crate` cells that read as low stools against slate
  (`pallass_standards_fight/04`). Same root as crate-clutter row below.
- [ ] **(P4)** `side_vault_construct`'s combat-board read never shot —
  rogue route resolves headless-fast, script takes no board frame.
  Needs `screenshot` step inside combat window.

## Open — world art and sprites

- [ ] **(P2)** Collapsed gallery's three entrance faces do not read as three
  things — `deep_tunnels` (14,1)/(14,2)/(14,3). SHORING half paid (the
  `crate` region fix centres it in its reticle), but "Fallen Beam" is `boulder`
  at tint [0.55,0.38,0.24] and reads as rock — no length, no timber, no
  direction — and tints crush both into 13/255 world band. K5 copy carries
  pocket, so nobody stuck. Evidence
  `l398-playtest-evidence/collapsed_gallery_negative/crop_three_props_boost_4x.png`,
  `l398-art-evidence/crate_fix/`. Remaining: beam's silhouette + tint grade.
- [ ] **(P2)** `pressure_plate` carries THREE verbs on one map
  (`data/maps/dungeon/trapped_halls.json`): trap to trigger (6,7), mechanism
  to disarm (2,10), slab to lever out (7,10). Eye-check confirmed worse than
  row: `warded_side_vault_gate_check/00_both_modes_locked.png` puts (6,7) and
  (7,10) on ONE screen PIXEL-IDENTICAL — only facing-dependent reticle and
  observe text separate them. Fix is silhouette: wire/catch furniture on
  release, raised canted edge on pry plate.
- [ ] **(P2)** `side_vault_construct` is `ruin_warden` at tint [0.58,0.64,0.76] —
  and `seal_warden_alcove` is SAME rig at [0.42,0.42,0.46] IN SAME FRAME.
  Reads as guard (largest legible thing in 15.7/255 band), not as warded
  vault mechanism. Tint-is-not-disambiguation, photographed
  (`warded_side_vault_rogue/00_rogue_vault_open.png` + `boosted_00.png`). Wants
  silhouette pass (ward-line etching, narrower stance); tints stay grade.
- [ ] **(P2)** `invrisil_lady_client` backs THREE Invrisil surfaces, two
  conversation-bearing ("A Lady with a Ring Box" at stationer, "A Woman Who
  Came in a Carriage" as Rest's steward) plus boulevard's "Lady in Plum
  Silk". Policy-legal (all `A `-prefixed extras, no tint separation), but two
  women who hold real conversations in one region share one silhouette. Wants
  second gentlewoman rig — gloves-indoors + no ring box is real drawing
  difference — before either becomes returning face.
- [ ] **(P2)** `guild_notice_wall` renders as featureless flat mid-grey disc with
  dashed dark border that reads as selection marquee, directly under
  fully-drawn `request_board` (`mood_sheet_night/05_guild`, repeat in
  `11_brothers_parlor`). NOT same case as `anchor_waystone_slate`, whose
  blankness authored into its observe copy — leave that one alone.
- [ ] **(P2)** Boulevard plaza razor-edge seam at day (1.47× luminance step, no
  transition tiles; inverts at night). Not asset gap — free pack's wang
  transition tiles exist; what missing = `floor_layers` rows in
  `data/maps/invrisil/invrisil_boulevard.json`.
- [ ] **(P2)** Stacked-NPC burial of reticled speaker in vertical
  conversation column (`invrisil_house_name_talk/06`). #400 batch shipped
  adjacency-only dialogue separation (10 px/side) — re-shoot this frame first; if
  it survives, fix is draw-order in `src/world/world.gd`, not per-sprite
  `field_y_sort_bias_px` (any bias that lifts speaker buries whoever behind).
- [ ] **(P3)** Stationer barrel props at [10,1]/[2,1] read as holes — pure-black
  (0,0,0) outline over body at lum 59 against lum 48 floor = 11-unit
  separation that reads as shadow. Separately clerk [8,1], its affordance
  bracket and player [8,2] all occupy y135–260, so figures ambiguous
  at 1× (`line_display_ab/01_interact_at_world_ready`).
- [ ] **(P3)** `inn_player_room`: bed corner's warm plank tile meets olive
  interior board on bare 90° seam with no threshold or rug; at night sconce
  is cold grey bar with no lit core and its warm pool offset to one side, so
  light has no visible source (`player_room_loop/05`, `/06`, `/07`).
- [ ] **(P3)** `winter_fold_hurdles` borrows `riverfarm_fence_ns`, so WORK
  route's material cache reads as one more upright beside pen rail rather
  than cut hazel hurdles. Wants stacked-bundle sprite, not another fence
  rotation (`winter_teeth_work/00_hurdles_stacked`).
- [ ] **(P3)** `riverfarm_bank_washout` borrows `deep_fissure` (dungeon sprite);
  at [20,9] it half-overhangs river tiles and becomes brightest object in
  quadrant, pulling eye to nothing. Wants bank-erosion sprite or
  wet-earth re-tint (`winter_teeth_talk/00_shepherd_hub_offer`).
- [ ] **(P3)** Two new Invrisil facade doors easy to miss — both use
  generic `door` sprite inside shopfront band of similarly sized window props,
  and one you stand under occluded by your own sprite
  (`adventurers_rest_loop/01_two_doors_on_one_facade`). Wants shopfront-door
  sprite or hanging sign.
- [ ] **(P3)** `boulevard_carriage_wake` (invrisil_boulevard 11,1) carries story
  beat and counter as `hide_sprite` facade prop, so its only affordance is
  interact bracket drawn over player. Wants small ground mark (wheel-track
  decal on marble) to walk up to.
- [ ] **(P3)** `coyle_runner_trail` (invrisil_boulevard 20,13, "A Hurrying Runner",
  `city_runner`) reads frozen — hurrying figure that never moves. Idle frames,
  or re-express as non-figure clue (skid marks, dropped satchel).
- [ ] **(P3)** `mercantile_alleys` = worst remaining crate map (3 decor + 3
  entities + 1 barrel = 7). Left out of #408, which named only floodplains /
  Liscor / arena.
- [ ] **(P3)** Grimalkin renders in two palettes — map-local market tint
  [0.78,0.70,0.72] vs untinted in inn (~25% brighter). User ruled minor
  follow-up: unify in future pass.
- [ ] **(P3)** #423 enchanter set ships on borrowed art: `enchanter_shop` /
  `enchanter_work_room` have NO `floor_layers` (inherit
  `brothers_parlor` biome default rather than take blind region pick);
  `enchanter_workbench` / `work_room_proof_bench` reuse Pallass forge's
  `temper_bench`; `alley_enchanter_card` reuses `price_board`. Each wants
  bespoke art + windowed verify.
- [x] **(P3)** ~~Shop right half SPARSE~~ FIXED 2026-08-11: `enchanter_stock_shelf` (8,1) + `enchanter_vial_case` (10,1), two distinct silhouettes (PixelLab). Windowed verify below.
- [x] **(P3)** ~~Enchanter work-room door reads as WINDOW~~ FIXED 2026-08-11: bespoke `door_locked_heavy` (dark planks, iron banding, brass latch; PixelLab, license-notes verdict). Dark-heavy read verified in enchanter_work_room/00 vs the blue exit door.
- [ ] **(P4)** `door_locked_heavy` unoccluded eye-read pending: the only canonical showing it has the PC + interact reticle over the door center; brass-latch legibility verified at render scale from the sheet, not in-scene. Next windowed pass that walks the shop unoccluded closes this.
- [ ] **(P3)** Interiors phase-invariant (clock invisible indoors);
  day identity brightness-only with no hue; sewers ladder is scribble at 1×.
- [ ] **(P4)** `crate` carries three lane props whose copy far more specific
  than art: `den_shop_receiving_dock` (8,5) is "a chalk outline the size of
  one crate" and draws as small dark box with no outline
  (`pallass_ledger_carry/03`), `lift_cargo_pallet` (19,4) is strapped and tagged,
  `forge_reject_bin` (10,4) is civic bin of tagged failures. Dock is
  HELP route's target. Wants chalk-outline floor decal / distinct dock sprite.
- [ ] **(P4)** `witch_hut` hanging herb bundle y-sorts above player and
  covers PC's head on cell below (`thicket_keeps_skill/01`). Defensible
  for ceiling prop, but it is room's only tall sprite; small
  `field_y_sort_bias_px` settles it either way.
- [ ] **(P4)** Riverfarm's SOUTH treeline `hollow_tree_3`/`_4`/`_5`
  ((2,13)/(5,13)/(8,13)) canopies cover rows 9–13 across x 1–10, y-sort above
  everything under them, incl. `briar_collectors_deep` (4,11) and
  `hollow_true_knot` (8,10). Same one-key fix as drained north-treeline rows.
- [ ] **(P4)** Forge molten trough = largest single object on Pallass
  tier and least detailed — near-uniform saturated orange ~320×70 rect
  beside pixel-detailed stations, anvils and ember particles
  (`pallass_walkthrough/08`). Wants banding, glow falloff, lip.
- [ ] **(P4)** Three boulevard shopfront observes (glazier / cordwainer / teahouse,
  wall cells 6,1 / 15,1 / 7,1) ship `hide_sprite` — decor sprites would give
  wall fronts visual read (b5 #220).
- [ ] **(P4)** `gentleman_bowler` ("A broad man in a bowler hat") wears
  `hired_blade` — goatee, burgundy coat, no bowler. Reads well in den of
  gentleman thieves, but hat only in prose.
- [x] **(P4)** ~~[Pick Lock] on `icon_open_doors` INTERIM~~ FIXED 2026-08-11: bespoke `icon_pick_lock` (gold padlock + pick, 16x16). Rogue-line siblings (sneak/find_trap/disarm_trap) already distinct.
- [ ] **(P4)** Undressed-blocked advisory inventory across 8 maps — drain
  map-by-map; footprint model approximate on layer-drawn art.
- [ ] **(P4)** Enchanter shop's centre floor mat reads as dropped sheet of
  paper at 1× zoom.

## Open — copy

- [ ] **(P2)** Explicit-instruction prose class (→ #406). User ruling: discovery
  over instruction. Toasts like floodplains [34] "Freeze that water, or cross it
  with [Double Step]" and deep_tunnels [9-11] "Select [Greater Strength] and use
  it on the beam" (pure UI-speak) too explicit; also trapped_halls [17-19],
  mercantile_alleys [17-18], ruin_surface [28-29]. Re-author as diegetic
  capability cues ("takes strength you have not learned yet"), never skill menus.
  Receipt toasts NOT in scope (outcome convention).
- [ ] **(P3)** `snap_freeze`'s `freeze_toast` still says "the channel"
  (`data/skills.json:633`) regardless of which cell froze. Bespoke ice tile
  and its wiring shipped (`world.gd` `ICE_SHEET`, no tint) — this is copy
  residual of that row, along with thaw/refusal toasts in
  `data/interactions.json`; string pinned twice in
  `qa/scripts/sewers_walkthrough.json`.
- [ ] **(P3)** Erin's opening lines use spaced hyphen ' - ' instead of em
  dash used everywhere else — on game's first NPC line
  (`inn_walkthrough/02`).
- [ ] **(P3)** Room-register node banners "Lyonette" over body text that is
  third-person narration ABOUT her (`player_room_loop/01`).
- [ ] **(P4)** Shepherd's hub opens on exit line — with
  `heard_winter_teeth` unbanked rows are "1. Just passing through." then
  "2. The wolves. Say what you need.", cursor on row 1, so reflex confirm
  leaves without learning quest exists (`riverfarm_hunter.json`). Reordering
  re-pins every legacy fixture's hub indices (ruling 11's hazard), so needs
  lane that can re-derive them.

## Awaiting a user eye

- [ ] Coyle & Sons sign repainted 2026-08-09 — crate+cartwheel emblem → gold
  "C&S" monogram (PixelLab inpaint, zero pixels changed outside emblem mask).
  Windowed read SKIPPED for usage; verdict = user's next boulevard look.

## Harness noise (watch, not defects)

- [ ] `pallass_ledger_offices` exits windowed with `WARNING: 23 ObjectDB instances
  were leaked` + `ERROR: 10 resources still in use`, QA_RESULT PASS and all shots
  landing. `player_room_loop` did it once (6/3), clean on two
  following identical runs. Teardown noise, but COMMON's grep discipline is
  zero-tolerance, so will read as lane regression next time it lands.
- [ ] Windowed capture stalled once mid-run (`invrisil_hat_quiet`): reached
  last banked counter, hung before final screenshot; alarm killed
  `run_qa.sh` but left godot child alive. Kill + re-run passed. Headless
  unaffected.
- [ ] **(P4)** vault arena cover cell [6,4] (#451) — blocks movement correctly but renders as flat fallback wall tile (dungeon biome has no cover-prop pool; board_renderer BLOCKED_PROPS_BY_BIOME lacks a dungeon row) — reads as brick patch, not fallen column — fix direction: add a dungeon cover prop to the pool or accept the vault look
- [ ] **(P4)** corusdeer_range dormant state (#443) — lying-deer sprite reads "resting" more than "defeated"; silhouette change is compliant, but check the in-play read beside the ambient standing deer — fix direction: accept, or swap to a starker carcass frame if the pack has one
- [ ] **(P4)** boulevard_duel_ring dormant bench (#443) — controller windowed frame was ambiguous (camera off-ring); verify in play that the bench reads as "ring wound down", not set-dressing clutter
- [ ] **(P3)** follower walks (#459) — user eye-gate on the three companion rigs now that they turn: wolf_companion / razorbeak_companion / skeleton_ally each got OWNED PixelLab directional idle+walk sheets and the world layer picks the sheet from the travel vector. Check at gameplay scale: (a) the down/side/up assignment reads right when the follower rounds a corner (wolf + razorbeak rotations came off SIDE-PROFILE references, so their direction labels were assigned BY EYE, not by the generator's names), (b) the razorbeak stands up out of its hunched idle when it starts walking — feet stay planted, but the body rises, (c) skeleton_ally is also the COMBAT ally record and now resolves idle_side there, so the raised skeleton faces the enemy line instead of the camera. Walk a companion N/S/E/W on street or inn.
- [ ] **(P4)** [Spellspear] kit icons (#449) — `icon_keener_point` + `icon_spellbound_thrust` ship as code-drawn 16x16 glyphs (tools/sync_assets.py shapes `keen_point`/`bound_spear`), the same no-new-art policy as every skill icon before them; PixelLab pass still user-gated — evidence: both are NEW shapes, not recolours of their [Spellsword] twins `edge`/`bound_blade` (tint-is-not-disambiguation, 2026-08-02), verified against those twins and against `icon_pierce_thrust`/`icon_sudden_strike` in an upscaled side-by-side, and `keener_point` READ IN PLAY at real hotbar scale (`qa/run_qa.sh spellspear_consolidation_loop windowed --seed=449` → `03_spellspear_kit_combat.png` slot 3: the cyan diagonal spear is distinct from all four bronze spear glyphs beside it) — `spellbound_thrust` is a L16 grant, above the canonical's floor-14 build, so its glyph is authored-and-compared but NOT yet eye-gated in a live kit — fix direction: fold into the next PixelLab icon pass, and read `spellbound_thrust` in play whenever a 16-level fixture next exists; the pair can never be co-held with their twins (consolidating retires the parents), so the read only has to hold against the spear family
- [ ] **(P4)** three-consolidation-family kit icons (#438) — `icon_grave_edge` + `icon_deathbound_strike` ([Deathknight]) and `icon_counsel_of_the_wild` + `icon_bramble_hand` ([Wild Sage]) ship as code-drawn 16x16 glyphs (tools/sync_assets.py shapes `grave_edge`/`death_bound`/`wild_counsel`/`briar_vine`), the same no-new-art policy as every skill icon before them; PixelLab pass still user-gated. ([Skirmisher] owes no icon: its own L14 grant [Steady Point] is an ap_cost 0 passive that never reaches a hotbar slot, mirroring its [Steady Draw] baseline, and its other L14 grant is [Dangersense] reused rather than twinned.) — evidence: all four are NEW SHAPES, not recolours of their twins `edge`/`bound_blade` and the two Wave D-2 placeholder squares (tint-is-not-disambiguation, 2026-08-02), each compared against its twin and against the neighbouring glyph families in an upscaled side-by-side; and `icon_grave_edge` is READ IN PLAY at real hotbar scale (`qa/run_qa.sh deathknight_consolidation_loop windowed --seed=438` → `03_deathknight_kit_combat.png` slot 3: the grey planted blade with its crossguard and mound reads distinctly against the blue/green squares, the orange flame, the green cross, the thin dagger, the green bolt and the blue orb beside it) — NOT YET EYE-GATED, three of four, each for a stated reason: `deathbound_strike` and `bramble_hand` are L16 grants sitting above their canonicals' floor-14 builds, so they are authored-and-compared but no live kit holds them yet (the [Spellbound Thrust] situation exactly); `counsel_of_the_wild` is EXPLORATION-context, so it never appears in the combat hotbar at all — the windowed wild_sage run confirms its seven slots are the combat kit only — and its read has to be gated on the OVERWORLD hotbar instead — fix direction: fold all four into the next PixelLab icon pass; read `counsel_of_the_wild` on an overworld hotbar frame, and the two L16 glyphs whenever a 16-level fixture next exists. None of the four can ever be co-held with its twin (consolidating retires the parents), so each read only has to hold against its own kit's neighbours
- [ ] **(P3)** floodplains + mercantile_alleys placement/aura batch (#474, #475) — user eye-gate on three reads this wave changed. (a) `goblin_night_patrol` was authored on a cell the pond was later painted over and rendered two goblins standing in the water; it moved (10,21) -> (7,21), the nearest bank cell whose whole sprite footprint clears water, with `present_when{phase:[night]}` so the new land cell is not an invisible day wall — check the NIGHT read that the patrol reads as ashore and the marker is not wading. (b) `road_mothbears` (23,12) was suspected of the same defect and is CLEAN (Chebyshev 10 from the nearest water, no floor layer) — confirm the wagon-road verge read at night so the earlier suspicion is closed on eyes, not only on data. (c) [Dangersense] now draws the ungated ambushes it used to drop: the Liscor gate-road aura (`goblin_encounter_1` r2) is the fix's whole point, and mercantile_alleys gains three — `alley_footpads_a`/`_b` on the open route plus `counting_room_guard`, which only lights once the #398 pocket opens — check the alleys do not read as aura soup at gameplay scale, and that the gate-road bloom still reads as a warning rather than as terrain. Evidence: windowed night captures 01/02 (floodplains), 03/04 (gate road), 07/08 (pocket sealed vs open) — fix direction: accept, or dial per-map aura density if the alleys read busy
- [ ] **(P3)** crypt Lich + Bone Thrall, and the CO-BOARD read (#460) — the summoner archetype ships two OWNED PixelLab v3 rigs (`crypt_lich` 64px @ render_scale 0.64 ≈ 2.36 cells, `bone_thrall` 48px @ 0.60 ≈ 1.65 cells, both anchored off a measured alpha bbox, idle-only because combat never plays `walk`). The binding constraint is that `bone_thrall` must read apart from `skeleton_ally` AT A GLANCE, because `bone_pile_ruin` sits nine cells from the crypt on the SAME map and a necromancer PC can stand its own raised skeleton on the same board — tint would not have carried that (2026-08-02 directive), so the separation is silhouette AND height AND palette: the ally is pale/tan, broad and upright at 1.94 cells; the thrall is dark rot-grey, narrow and hunched at 1.65; the Lich is dark, crowned, 2.36 and carries the only green spell-light on the board. Evidence: `qa/run_qa.sh crypt_lich_fight windowed --seed=1` → `02_thrall_raised_beside_ally.png` puts all three on one board with the feed line under them, and `01_board_opening.png` / `00_crypt_mouth.png` carry the opening and the overworld read. NOTE for whoever gates this: the local run has no private asset overlay, so the PC renders as its magenta fallback chip and covers the crypt entity in `00_crypt_mouth.png` — read the overworld Lich off a run with the overlay installed. — fix direction: accept, or ask for one more separating step on the thrall (see the row below)
- [ ] **(P4)** `bone_thrall` reads THIN at board scale (#460) — the rig is correct and clearly not the ally, but at 1.65 cells the hunched shroud reads as a narrow dark sliver next to the ally's broader frame, and it is the enemy the player has to count (up to two of them join mid-fight). It has no `combat_tint` and wants none — the whole point of the row is that tint is not the tell. — fix direction: one MASS step (a wider shroud/shoulder silhouette at the same height) on the next PixelLab pass, or accept if it reads fine in play at gameplay zoom
- [ ] **(P3)** death spells changed colour — [Bone Dart] and [Deathbolt] (#460) — `combat_screen._skill_flash_color` picked FLAME_FLASH for every non-frost `spell_damage`, so both shipped [Necromancer] casts threw an ORANGE FIRE projectile and flashed orange on the target. They now key on the authored `element: death` and read grave-green (`GRAVE_FLASH`, the same colour the summon's arrival cell flashes). This is a player-visible change to TWO ALREADY-SHIPPED player spells, not only to the new enemy kit, and it is the label-vs-art class this log exists for (a black-green lance that renders as fire). NOT YET EYE-GATED: no canonical fields a PC casting either one — `WICombatAI` defaults the PC's empty `ai` to the melee profile, so autoplay structurally cannot cast, and the only frames in hand are the Lich's own bolts (`qa/run_qa.sh crypt_lich_fight windowed --seed=1`, the enemy side of the same colour). — fix direction: read a PC death-cast whenever a necromancer fixture next plays under the competent policy; accept the hue, or dial it if green-on-cave-floor reads weakly against the frost blue
- [x] **(P3)** "Autosaved." is now a ~2-frame flash on EVERY quest beat —
  the deliberate, logged cost of the chore-yield fix in the "Authored payoff
  prose queues behind housekeeping toasts" row above. `game.gd:110` autosaves
  from inside its own `QUEST_BEAT_COMPLETED` listener, so the save toast
  ALWAYS coincides with a beat, and a beat is exactly when authored copy is
  queued behind it — which now collapses the chore's deadline to
  `started_msec` (a time already past) rather than capping it at 1.6s.
  Measured, `qa/run_qa.sh invrisil_hat_quiet windowed --seed=37`: 13–14 ms
  between the chore's `ui_toast_rendered` and the next one — its whole
  on-screen life; the wave audit's panel-visibility probe read it as
  `visible_ms` 0, against 7 and 8 for the authored toasts behind it. So
  "Autosaved. (Esc — save/load anytime)" — which is a FIRST-TIME-PLAYER
  affordance, the one place the game says where saving lives — is functionally
  unreadable at the moment it most reliably fires. A trade, not a loss: it
  still carries `record=true`, so it lands in the journal's Recent Messages
  every time, and the ruling stands that authored prose beats a chore.
  Fix direction: a MINIMUM-VISIBLE-SPAN floor on a chore that has already
  started showing (yield after N frames, not on the next check), so the strip
  still hands over promptly but never renders a toast no eye can catch.
  NOT taken in the same wave that introduced the yield — new timing behaviour
  needs its own measurement pass, and this one would move a hold that
  125 canonicals wait on `ui_toast_rendered` for.
  CLOSED (#509): the save status is no longer only a toast -- every slot
  write emits `game_saved` and the hint ribbon carries a "•  Saved" pill for
  4s (`ui_save_status_rendered`), off the strip entirely; the housekeeping
  toast keeps its chore-yield behaviour. Canonical: `message_lifecycle_loop`.
- [ ] **(P3)** Empty-interact flavor can be flashed AND unrecorded — authored
  interior-flavor prose (`biomes.json`, e.g. "Nothing there — just old boards,
  and the particular silence of a room with a roof on it.") is queued by
  `message_layer.gd:451` as `_queue_toast(text, false, true)`: `record=false`
  AND `housekeeping=true`. Since the chore-yield fix that pairing is newly
  load-bearing — as a chore the line can now be cut to ~2 frames, and with
  `record=false` it never reaches Recent Messages either, so an authored line
  could reach the player NOWHERE. Exactly the family this lane drains.
  LATENT TODAY, not live: a sweep of all 252 canonical event logs found 1885
  `interact_nothing` events and ZERO cases where one was actually cut short.
  BLOCKED on the obvious one-line cure (`record=true`): MEASURED to move a
  shipped pin — `mobile_tap_check` step 32 pins `ui_journal_shown`
  `recent_count: 1` and its own `_comment` states the case verbatim ("Unfixed
  message_layer records it and this pins 2"); flipping the flag turns that
  canonical RED at that step ("timeout (5.0s) waiting for event:
  ui_journal_shown subset={"recent_count":1.0}"), while
  `status_first_encounter` is unaffected. The pin encodes GH#202's own ruling
  (idle wall-poking must not push real history past `RECENT_MESSAGES_CAP` 30),
  so this is a ruling to revisit, not a flag to flip. Fix direction: decide
  whether flavor prose is history, then re-derive `mobile_tap_check`'s count in
  the same commit — or give the line a minimum-visible-span floor instead and
  leave GH#202 standing.
- [ ] **(P3)** Character-creation difficulty choices explain rank names but
  not their effect. `qa/run_qa.sh char_creation windowed` →
  `02_creation_difficulty.png` shows only Bronze Rank / Silver Rank / Gold
  Rank and the change-later footer. A new player cannot tell what changes
  or which experience each offers. Fix direction: add a short description
  for the selected rank, consistent with the damage-taken multipliers in
  `src/ui/wi_settings.gd`; keep the canon rank names.
