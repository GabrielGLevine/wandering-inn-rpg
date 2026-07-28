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

- [ ] TOAST/MODAL-OVERLAP (P2, pre-existing layer order, MADE MORE FREQUENT by
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
- [ ] QA/SEWERS-WINDOWED-TIMING (P2, WAVE-AUTHORED at `50cbf6b`) —
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
- [ ] JOURNAL/ACT-IV-PENDING-ITINERARY (P3, PRE-WAVE copy, wave-changed
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
- [ ] COMBAT/FEED-FOLD (P2, REGRESSION of the Fixed-section item "message panels
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
- [x] COMBAT/HIRED-BLADE-NAMES (P2, Phase 9 made it matter) — all three
  warehouse enemies carried `display_name: "Hired Blade"`, so the turn banner
  read "Hired Blade A | Hired Blade B | Hired Blade C" and the feed named them
  the same way. Phase 9 gave `hired_blade_leader` `[Counter Strike]`: the fight
  now HAS a boss with its own mechanic and nothing on screen said which of the
  three it was. **FIXED fix round 1** — the leader is "Hired Blade Captain"
  (a unique name takes no auto-suffix, so the two knives stay A/B and the
  captain reads as their head). Zero churn: the literal appeared nowhere
  outside `combatants.json`. `invrisil_disagreement_fight/01`.
- [ ] COMBAT/GOLEM-NAME-SPLIT (P4) — the forge golem parleys as "Miscalibrated
  Golem" (`data/dialogue/forge_calibration_golem.json` speaker) and then fights
  as "Stone Golem" (`combatants.json:forge_golem` display_name, shared with both
  market watchgolems). The line you just read names a different thing from the
  one in the turn banner. Same shape as HIRED-BLADE-NAMES but one tier down: no
  mechanic hangs on telling them apart. Found on the fix-round-1 forge-golem
  probe (`03_forge_fight_open`).
- [ ] JOURNAL/HALF-ROW (P3) — the journal's scroll viewport admits a partial
  text row instead of clipping at a line boundary, so its bottom line renders
  sliced ("The Missing Crate — Complete." on both
  `climax_seal/02_journal_act4.png` and `spine_reach/02_journal_spine_beat.png`).
  The `▼` continuation cue is present so it IS scrollable, but a half-height row
  reads as a clipping bug, not as "more below".
- [ ] COMBAT/BRIAR-CAMOUFLAGE (P3, same family as the open COMBAT/CELLAR-VERMIN
  entry) — on `witch_hollow` the deep briar collectors are green foliage on a
  green floor under a green canopy. In `riverfarm_fight/02_briar_deep_wave.png`
  Collector A is findable only by its HP bar, and Collector B's foliage overlaps
  the Hunter's cloak so ally and enemy read as one mass with two bars.
- [ ] MAP/PALLASS-FORGE-FLOOR (P3, widened in fix round 1 to the ARENA) —
  `pallass_forge`'s walkable floor and its walls share one purple-grey brick
  texture with no floor/wall cue; the top rows are indistinguishable from the
  walkable middle (`pallass_walkthrough/07_forge_tier_arrival.png`). In the same
  shot the forge golem reads as machinery parked beside the lift rather than as
  a combatant. The `forge_hall` ARENA inherits it: on the fix-round-1 fight
  probe the two blocked-cell clusters read as decorative brick patterning, not
  as obstacles you must path around. The combatants themselves are fine there —
  see WHAT LANDS.
- [ ] SPRITE/GRIMALKIN-FIGURE-HEIGHT (P3, USER-GATED — root cause of the inn's
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
- CONFIRMED STILL OPEN: RUIN_WARDEN/RIG-SCALE (P3, logged in the mq4-act5 pass)
  — at `combat_scale` 1.15 the warden's crown is still cut by the turn banner
  on the vault arena's top row (`seal_open/06_the_warden.png`).
- TRANSIENT, NOT A FINDING: one windowed `journal_history` run exited with
  "8 ObjectDB instances were leaked at exit"; not reproducible on re-run (0
  noise), headless sweep clean. Windowed shutdown-order artifact.
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

- [ ] FINALE/LONG-LINE (P3) — the Invrisil region recap line renders **1114 px
  wide of a 1280 px viewport** (87%), roughly double every other line in the
  block. It does NOT clip (canvas_items stretch keeps the logical viewport at
  1280, and Labels here never wrap), but it visibly bursts the centered column
  the rest of the sequence forms, and it is the only two-sentence line in a
  block of one-thought lines. The copy is the wave plan's own verbatim text, so
  it was NOT rewritten here — this is a taste call for the controller. A
  shorter second sentence (or dropping "From him, that is a parade.") would put
  it back in the column.
- [ ] VEIL-COPY/UNMEASURED (P4, systemic) — `test_copy_fit` measures toasts,
  dialogue pages, pickers and help, but **nothing measures `sleep_veil.gd`'s
  own line tables** (opener / finale / region recap / path closes / the seal
  transition), which now hold the widest single-line strings in the game. The
  1114 px figure above was obtained with a throwaway measurement script, not a
  gate. A `_check_veil_lines()` in test_copy_fit (font-size 24, 1280 budget)
  would make the ceiling enforced instead of observed.
- [ ] SEAL-SLEEP/TOAST-MISMATCH (P4) — the seal's light transition line rides
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

- [ ] MAP-LIGHTS/DAY (P3, systemic, NOT Act V's own) — `moods.meta
  .light_energy_by_phase.day` is `0.0`, so every authored map light renders at
  zero energy during the day phase. For a SEALED map (no sky, no windows) that
  is the wrong default: the vault's three lights only exist from dusk, and its
  daytime read has to be carried by the grade alone. Worth a per-map opt-out
  (`lights_ignore_phase: true`) rather than brightening every dungeon grade.
  Same class affects pallass_market's crystal lamps by day.
- [ ] RUIN_WARDEN/RIG-SCALE (P3, pre-existing) — at `combat_scale` 1.15 (the
  shipped `ruin_guardian` value, which `seal_warden` now matches deliberately)
  the rig's head clips under the combat HUD's turn banner on the vault arena's
  top row. Not introduced here — the first pass shipped 1.35 and the windowed
  read pulled it back to the shipped precedent. A rig-anchor question for the
  art lane, not a data-value one.
- [ ] TOAST/LENGTH (P4) — the `[Detect Magic]` quartet payoff is the longest
  toast in the game (7 wrapped lines at 1280x720). It FITS (no clipping, top
  edge well inside the screen) and it is the beat's climax, but it is the new
  ceiling; `test_copy_fit` does not measure `skill_uses` variant toasts, so
  nothing enforces that ceiling automatically.


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
  The retirement counter is `horns_dig_joined`, NOT `horns_dig_started` as
  first specced: `horns_dig_started` banks mid-conversation with the player
  standing in the inn, and world.gd reconciles presence live on
  ACCOMPLISHMENT_RECORDED, so all three Horns popped out of the room in one
  frame while the invitation panel still read "Ceria" — the ruled version
  re-created the very defect below. `horns_dig_joined` banks at the CAMP, so
  the swap happens with the inn off-screen. Evidence:
  `AFTER_FIX/tmp_dig_inn_probe/01_MIDCONVO_after_bank.png` (all three still
  present mid-invitation) and `04_inn_during_dig_horns_free.png` (Horns-free
  inn once the dig is joined).
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
- [ ] RUIN/MIGRATED-DIORAMA (P2) — a pre-restructure save migrated by
  `save.gd:339` loads with `door_retrieved` + `door_mounted` banked, and then
  the ruin it walks into still has `ruin_guardian` alive and on its feet over
  the pedestal the save says was already breached and looted
  (`tmp_migrated_ruin_probe/00_migrated_deserted_ruin.png`). The deserted camp
  on its own reads acceptably — a struck camp with leftovers is ordinary ruin
  dressing, and the gated arrival toast correctly withholds "the Horns got here
  first" — but the live guardian is a direct contradiction of the migrated
  state. Consider adding `ruin_guardian` to the backfill's removed set.
- [ ] COPY/DASH-MIX (P2) — two toasts on the same map one beat apart disagree
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
- [ ] COMBAT/CELLAR-VERMIN (P2, pre-existing, re-observed on this wave's
  surface) — on the re-gated leak board
  (`door_chain_fight/00_rift_vermin_leak_board.png`) the Rift Vermin
  combatants are visually indistinguishable from the cellar's barrel decor;
  only the HP bars separate a monster from a barrel, so counting the enemy
  roster means reading the turn-order strip instead of the board. The feed
  panel's third line ("Rift Vermin B strikes Relc for 13!") is also clipped by
  the parchment fold in the same shot.
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
- [ ] COMBAT/DARK-ARENA (P1 acceptance drift) — the two Sewer Rats in
  `sewers_walkthrough/01_vermin_encounter.png` are effectively invisible at
  native scale; their HP numerals and orange bars reveal that enemies exist,
  but the bodies read as tiny dark pixels. The still-dark mood lands, but the
  closed GH#28 combatant-brightness treatment no longer clears its own
  first-time-player visibility bar on this roster.
- [ ] SPRITE/ARC-CLIMAX (P2) — deep-tunnel figures repeatedly occupy the same
  visual footprint. Relc/player/warren art collapse into one stack in
  `arc_flow/dd_03_warren_mouth.png` and `dd_04_awakened_field.png`; the boss and
  both scouts overlap heavily in `dd_06_boss_fight.png`, making count, identity,
  and threat hierarchy hard to parse. Restage field cameos and spread the
  climax roster's initial combat cells.
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
- [ ] (superseded) FIELD/DARK-MAPS — enemies/interactables on **field** (exploration, not
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
