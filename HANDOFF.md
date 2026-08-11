# Wandering Inn RPG Handoff

Live current-state doc. Per-issue narrative in merged PR bodies
(`gh pr list --state merged`); adjudications in CHOICE-LOG; build
history in git. Fresh session read order: wi-start-here.

## DONE (2026-08-11): #429 ORPHAN DRAIN CLOSED (PR #433)

Six wires + hard-fail promotion; full record in PR #433 body + ledger
2026-08-11 entry + CHOICE-LOG 31-34. Follow-up #432 filed (unbounded
next_fight stacking class — needs a user balance ruling). pytest suites
now a preflight gate. Skill fold: lane refs push at spawn. USER-HELD:
#432 ruling; [Pick Lock] icon + shop eye-calls (VISUAL-LOG 2026-08-10).

## DONE (2026-08-10 evening): REACHABILITY WAVE — #417/#421/#423/#424 ALL CLOSED (PRs #425-#428)

User dispatch "address #417-424", two directives folded in: [Pick
Lock] locked contents keep virtuous-path route, Hedault-class
reachability defect gets systemic check. Per-issue narrative in four PR
bodies; rulings CHOICE-LOG 28-30 (+28-H).
- **#417** (PR #425): derive_qa_surfaces walks install_fixture (+ array-form
  fixture_save sibling hole); 11 new manifest rows.
- **#421** (PR #426): grace-end reconcile event (warning renders one step
  BEFORE re-ambush), UI_DANGERSENSE_CLEARED (same-map-only by ruling),
  dead COMBAT_STARTED arm collapsed, first combat-context dangersense
  canonical, [Firefly] stripped from 3 lying hints.
- **#424** (PR #427): advisory content-reachability lint (orphan graph +
  gate-carrier join incl. state_set traversal seams) + sim-truth
  interactable-adjacency suite (384/485 entities, 32 maps; beyond
  Hedault ZERO adjacency defects). Findings → **#429 orphan drain**
  (kindle, frost_touch, 3 item orphans, 1 dead node, GH#142 bead root
  cause).
- **#423** (PR #428): Hedault indoor Enchanter shop off boulevard (22,1) +
  work room; **[Pick Lock] debut** (rogue L2, one data-only
  door_when+requires_skill prop; pick OR rogue-free
  setting_commissioned trust beat; contents identical). Review caught
  lane re-shipping issue own defect class (C1 unreachable card prop —
  fixed, flood-fill-proven) + false present_when rationale (AGENTS.md
  stale clause SUPERSEDED) + landmark self-ruling (REVERSED, registry
  byte-identical to base).
- **Close bar:** composed main preflight --full ALL GREEN; steel-thread
  WINDOWED PASS seed 9 (63 plates, shop plate 06bb); first stale-waiver
  forced retirement fired in CI on merge commit, retired ON branch
  (skill fold shipped). Worktrees/branches cleaned.
- **USER-HELD:** GH#142 wardstone-bead yield (balance call, in #429);
  [Pick Lock] bespoke icon + work-room door sprite + shop-dressing
  eye-calls (VISUAL-LOG 2026-08-10 block). All wave work on main
  UNRELEASED — rides next tag with [Rope Arrow].

## DONE (2026-08-05): anti-duplication gate LIVE (PR #395, unmerged)

`check_prose_duplication` in data_lint HARD-FAILS: (a) any prose string
>20 chars duplicated in dialogue corpus or maps talk corpus, (b) any
raw copy of already-banked line ("use the @ref"). Both failure modes
probe-verified. Bank plumbing it flushed out, all shipped in e9aea87c:
- `data/maps/_shared_talk.json` — CROSS-map talk bank file (7 banks);
  `WISceneCatalog._expand_talk_banks` falls back local -> shared
  (shadowing shared name = lint error). Python mirror + lint resolve
  identically.
- Splice hazard ruled: solo line matching one MEMBER of multi-line bank
  cannot ref-swap (ref splices whole bank) — split member into own
  1-line bank (street.json krshia_corusdeer precedent).
- Dict-form text_variants expansion hole fixed (WIDialogueBanks +
  wi_data_lib); ksmvr_plates/selys_delivery stragglers banked.
- Voice gate maps mode walks _shared_talk banks as prose; BOTH baselines
  re-frozen (repo-root docs/dialogue-voice/{baseline,baseline-maps} —
  NOT wandering_inn_game/docs, easy to snapshot to wrong place).
- test_sim_core ack-precedence rows now come from compose(), not raw
  disk (raw rows carry @refs post-migration).
Proofs: both corpora byte-identical through expansion vs pre-migration
baselines; 33 unit suites PASS; sweep 207/207; leak_check clean.

**PR #395 note:** another session Riverfarm spec/plan commits
(c14efafb, 9044b9d0, 9554a334) were local-only on this branch, rode
along with push. Spec/plan docs only.

## DONE (2026-08-06): the 390/396/397 execution session (Fable)

Three issues executed across ~4 usage windows, ~50 Opus lanes/reviewers,
every lane adversarially reviewed + fix-waved. Per-issue narrative in
merged PR bodies; rulings in CHOICE-LOG (entries 1-23) +
docs/superpowers/2026-08-05-wave2-rulings-and-fix-specs.md.

- **#390 CLOSED** (PR #399): Wilovan combat set + Tier 2/3 drain;
  carried rows filed as #400. PixelLab rate corrected to ~$0.012/gen
  (was 5x overestimated); balance $0.46.
- **#396 CLOSED** (PR #401): full Riverfarm redesign — A Shepherd,
  a_winter_of_teeth, the_makings, briar solo re-gates, RETIRED
  registry, machine playtest 6/6, playtest states at
  qa/playtest_saves/2026-08-06-396-riverfarm/. Four new VISUAL-LOG rows
  carried (legend-band occlusion etc. — need route re-derivation).
- **#397 OPEN, PR #402 landed corpus pass** (NOT closing): Phases 0-4
  complete + riverfarm; all engineering criteria green (sweep 207/207,
  units 33/33, voice gates CLEAN, 29 keeps, advisory metrics).
  **Phase 5 blind read: EXIT NOT MET** — two independent readers put
  revised prose at 45/52 vs untouched control 53 (original audit scale:
  85); surviving engine is closer-templates + over-interpreted objects
  in MAP register. ROUND-2 DECISION IS USER'S:
  docs/prose-naturalization/phase5/phase5-reconciliation.md (rec:
  map-register-only re-authorship under zero-inference scenery default).

## DONE (2026-08-07): #398 CLOSED — skill-gated pocket areas, wave 1 (PR #405, 289d05e5)

Five pockets shipped, each teaching one field skill through
gate → payoff loop. Narrative in PR body; rulings in CHOICE-LOG
2026-08-07 block (spec §9 + 6 wave rulings). Highlights:
- Descriptive `skill_gates` registry + 5 data_lint arms; two-mode rule
  lint-enforced, QA walk legs stay reachability authority (negative legs
  WALK and assert player_blocked — never teleport).
- cuts WEAPON-GATED at field seam (one predicate, three call sites);
  10-slot armed bar ACCEPTED (windowed fit proof paid).
- Per-target counter overrides (counter_from/counter_key) kill
  cross-map counter-leak class; on_skill_use.accomplishment widened
  String|Array; RETIRED_ACCOMPLISHMENTS + staged_target_properties.
- Machine playtest headline: crate atlas region was mis-sliced sliver
  GAME-WIDE; bar_counter + stool drew NOTHING (invisible inn
  furniture); barrel was a pot. All four fixed by measurement, eye-read
  + windowed, combat-board regression clean (also closed carried
  forge_hall cover row).
- Process: five Codex lanes → five DO-NOT-MERGE reviews (each a
  different structural hole) → Opus fix waves. Division held. Doctrine
  fold (failure mode 6: STOP-suppression two-strikes) shipped to main
  mid-train; wi-writing-qa-scripts folds shipped at close
  (assert_field_skill_absent, append-last entities, coalesced toasts).
- Composed bar at merge: units ALL, harness 146 cells, tier sweep PASS
  (2 bronze flips whitelisted per alley_fence precedent), full sweep
  230/230, voice gates CLEAN, verify-untouched 0, census 14.97%.
- Follow-ups filed: #403 (wave-2 riverfarm pockets, now unblocked),
  #404 (lockpick canon-ACK). Playtest P2/P3 art rows in VISUAL-LOG.
- Known cosmetic: "Docs drift" advisory check reds on 398 plan lacking
  DONE/ACTIVE header — checker/format disagreement, needs one-line
  checker or plan-template fix, NOT real drift.

## DONE (2026-08-10): LOW-USAGE BATCH CLOSED — all six issues shipped

#400/#403/#404/#412/#413/#414 all CLOSED (PRs #415/#416/#418/#419/#420/
#422, each 7/7 checks + adversarial review + fix wave; per-issue record
in PR bodies). Composed main: import pass + preflight --full ALL GREEN +
steel-thread WINDOWED PASS (62-shot album at
wandering_inn_game/qa_output/steel_thread/, 19 maps, Dangersense
overlay visible live). Follow-ups filed: #417, #421. VISUAL-LOG
drained; skills folded (blast-radius, created-state negative legs,
codex direct dispatch). Lane worktrees/branches cleaned.
**v0.19.0 SHIPPED 2026-08-10** (tag at 9032b05f, release run
31406011609 green: full asset-overlay QA gate + wasm + butler to itch
+ desktop exports). Post-tag playtest verdicts applied pre-tag (crate
toast, VISUAL-LOG rows); #423 Hedault shop + #424 orphan lint filed.
**Batch-review verdicts (user, 2026-08-10):** parlor music PASSED ·
pond twins FINE · Coyle sign reads well (crate toast fixed pre-tag) ·
grimalkin → VISUAL-LOG follow-up row. **USER-HELD: none** — [Rope Work] resolved 2026-08-10 as [Rope Arrow]
(user overruled spoiler block, CHOICE-LOG 27; on main post-v0.19.0,
rides next tag).
**Watch line:** `wandering_inn_game/qa/run_qa.sh steel_thread windowed
--seed=9` (~5 min headless-measured + settle; 62 scenes).

## superseded RUNNING (2026-08-10 morning): batch back half — first train MERGED

**MERGED to main:** #412 (PR #419, field_weapon mechanism, CHOICE-LOG
22/25/26), #400 (PR #416, floors + night knob + dialogue separation),
#414 (PR #415, steel-thread instrument). All three issues CLOSED via
PRs; game-tree parity verified per lane. #404 closed earlier
([Pick Lock] ruled).
**IN FLIGHT:** PR #418 (lane C freeze pocket, partial #403) — CI-red
fixes pushed (ferry-tally effect-text pin + QA-notes regen, 84d7dd8e),
checks watch armed, merge on green. Lane D #413 Dangersense LIVE on
Codex (worktree /Users/gabriel/wi-lane-d, branched POST-merge so it has
412 pool + #400 world.gd; brief + report land on disk).
**NEXT:** briar pocket lane (witch_hollow, closes #403) dispatches
after #418 merges (shared items.json/manifest appends). Then close:
composed re-gates + preflight --full + steel-thread WINDOWED run (the
batch eye-read) + VISUAL-LOG drain + user-held items (v0.19.0 tag
overwrite, grimalkin two-palette continuity call, pond-sprite twin
read).

## superseded RUNNING (2026-08-09): low-usage batch #400/#403/#404/#412/#413/#414

Plan: docs/superpowers/plans/2026-08-09-low-usage-batch-400-403-404-412-413-414.md
(#406 PARKED per user ruling). Checkpoint tag **v0.19.0 stored LOCAL at
ffd0f960** (pre-batch head, deliberately NOT pushed — push triggers
deploy; user overwrites it if batch lands in-window).
- **Phase 0 SIGNED (user, same day — CHOICE-LOG 22-24):** #412 table +
  cut-mode **Option A** ([Basic Swordwork] gains field+cuts, both
  strikes retract field), [Basic Repair]→helper L2, #413 rogue L4 +
  passive APPROVED, #404 name ruled **[Pick Lock]** (ACTIVE skill,
  user name) — **#404 CLOSED**. Key facts: dangersense already exists
  (combat ctx) + warrior L5 already grants it; no attested lockpick
  skill ≤ Book 17 on wiki.
- **Lane A #414 DONE through review + fix wave: PR #415 OPEN** ([ci-full]
  head 5c39e50c). Merges with close train. Windowed run + album =
  batch-close eye-read (controller-owned).
- **412-apply RUNNING (Codex session 019fe906-c300-7933-84d8-581e17271734,
  worktree /Users/gabriel/wi-lane-412):** three STOPs adjudicated
  (CHOICE-LOG 25 + three ADJUDICATION ADDENDA in LANE-BRIEF.md there;
  key ruling: NEW `field_weapon` key + one authorized line in
  _field_skill_weapon_ready — combat kit untouched). Full
  implementation pass in flight. On return: adversarial review (trace
  field_weapon gate + fixture diff), fix wave, then MERGE FIRST before
  C/D.
  **LANDED + WIP-COMMITTED e495ed13 (pushed):** 25 files. 201/201
  touching + 14/14 smoke gameplay green; 32/34 units (2 sandbox-env
  reds: test_save_rename/test_settings user:// writes — RERUN
  CONTROLLER-SIDE before merge); three can-fail proofs incl. spear
  combat isolation. REVIEW FOCUS: field_weapon gate trace in
  wi_game.gd, fixture diff vs HEAD (must be zero), and lane ALSO
  edited qa/manifest.json + work_loop.json + wrong_order_loop.json —
  beyond my enumeration, allowed by standing rail, VERIFY their
  disposition rows in report before trusting. MERGE ORDER: this lane
  FIRST, then witch_hollow briar pocket (deferred #403 half) + lane D
  (#413) dispatchable.
- **Lane B #400 implementation COMPLETE (uncommitted in
  /Users/gabriel/wi-lane-b):** 9-file diff + new test_world_visuals.gd.
  Full 12-criterion report received; unmet items = sandbox CA-cert
  wrapper only (87/87 --touching, 14/14 smoke, all canonicals green on
  gameplay results). Adversarial reviewer (Opus) RUNNING on worktree —
  do NOT commit worktree until it returns (its git-diff reads depend on
  uncommitted state). After review: fix wave if needed, WIP/final
  commit, controller windowed crops at report rectangles (pallass_market
  [0,0,26,11]+[16,1,5,6], pallass_forge [0,0,26,11], forge_hall
  [0,0,12,9], inn_upstairs [7,1,4,6]), screenshot target
  inn_walkthrough/02_erin_dialogue (player (7,3) facing up, Erin (7,2)
  facing down), then PR.
  **REVIEW LANDED (during quiesce): sub-tasks 1-2 sound, sub-task 3
  REFUTED** (C1: 8px total vs ~14px overlap; C2: facing predicate
  misses 41/62 NPCs — facing is static data). FIX WAVE 1 adjudicated +
  dispatched to Codex (--resume-last, wi-lane-b): drop facing predicate,
  adjacency-only + 10px/side; attenuation applied at holder
  construction (root-cause); mercantile_alleys night triple darkened;
  behavioral test pins; lint divisor floor; M4 grimalkin two-palette
  continuity = USER CALL at close (VISUAL-LOG-worthy). Report lands at
  wi-lane-b/LANE-REPORT-FIX1.md. Full review text in this session
  transcript; verdict summary: all gates green, findings were
  gate-invisible.
  **FIX WAVE 1 LANDED + WIP-COMMITTED 4fec8fa8 (pushed,
  issue/400-carried-rows).** All fixes in, gameplay gates green (CA
  wrapper artifact only). REMAINING for lane B close: controller
  windowed crops (rectangles above) + Erin dialogue-separation
  screenshot + PR with [ci-full]. Note from fix report: call-order RED
  was superseded by construction-time root fix (call order no longer
  load-bearing) — accepted reasoning, spot-check behavioral assert at
  review of PR.
- **Lane C #403 PARTIAL dispatched during quiesce (user-sanctioned,
  Codex budget):** worktree /Users/gabriel/wi-lane-c (branch
  issue/403-riverfarm-pockets), FREEZE-BEAT POCKET ONLY — witch_hollow
  briar pocket DEFERRED (cut mode depends on 412 landing). Brief at
  LANE-BRIEF.md there; report lands on disk at
  /Users/gabriel/wi-lane-c/LANE-REPORT.md (self-contained, no live
  orchestrator needed). Lane D still parked: world.gd held uncommitted
  by lane B.
  **LANDED + WIP-COMMITTED 68956ed7 (pushed):** freeze pocket
  (riverfarm_village + items.json + 2 new fixtures + 3 QA legs
  islet_freeze/islet_blink/islet_negative, seed 9). 98/98 selective
  gameplay green, mutation proof shown, no STOPs. REMAINING: read
  LANE-REPORT.md fully, adversarial review (modes/gates/rewards +
  negative-leg walks + new-fixture audit — new fixtures WERE authorized
  by brief), fix wave, crops, PR. Note: lane touched items.json
  (reward rows — check anchored-append).
- **QUIESCE 2026-08-09 (session 86%, reset ~3h):** state saved; chained
  wakeups armed. On resume: usage_status --fresh, then act on whichever
  lane reports landed (review verdicts → fix waves → PRs; 412 merge;
  then C/D dispatch — C/D briefs not yet written; #403 = 1-2 riverfarm
  pockets per #398 spec post-412 pool; #413 = per signed spec, rogue L4
  + passive aura + render overlay from trigger radii).
- **Phase 1 LIVE (Codex, its own pool — week was 0%):** Lane A #414
  steel-thread in worktree /Users/gabriel/wi-lane-a (branch
  issue/414-steel-thread); Lane B #400 carried rows in
  /Users/gabriel/wi-lane-b (issue/400-carried-rows). Briefs at each
  worktree LANE-BRIEF.md; asset overlay copied (185 payloads each).
  Codex does NOT commit — controller commits/reviews/merges. NEXT on
  lane return: adversarial review per lane (method hints in briefs),
  fix wave, PR per issue, [ci-full] on final head.
- **Phase 2 (blocked on packet sign-off):** 412-apply merges FIRST,
  then #403 pockets ∥ #413 Dangersense (anchored-append).
- **Close:** merge train + preflight --full + steel-thread WINDOWED run
  (batch single composed eye-read) + VISUAL-LOG drain for #400.

## superseded RUNNING block (2026-08-08 night): #411/#409/#408 — ALL LANDED (see DONE 2026-08-09 below)
User overrode CAUTION ("Usage good. Proceed"); guard hit WINDDOWN at
76% mid-work. TWO LANE BRANCHES COMMITTED, NOT MERGED:
- issue/409-408-art @ 42afbec8 (/tmp/wi-art9): 4 NPC idles (v3
  identity-held frames + palette LUT), crate_submerged wired,
  6 new prop sprites, biome blocked_props variety (arena fix at the
  BIOME layer), census-trimmed. Sweep 182/182 + suites green in-lane.
  NEEDS: adversarial review (silhouette drift + windowed re-reads +
  fixture diff) -> merge -> main-tree import pass -> re-gate.
  Lane flags: cache occluded by pond crab (load-bearing cell,
  pre-existing), 2-frame fps6 idles read twitchy (5 identity frames
  exist server-side -- consider fps 3 or 4-frame widen at review),
  mercantile_alleys now worst crate map (out of #408 scope), #409
  data_lint advisory guard unbuilt.
- issue/411-water-shoreline @ 603f56cf (/tmp/wi-411): Codex edge
  picker (adversarially reviewed CLEAN: union/mutation/fallback/
  build-time all confirmed) SUPERSEDED same-session by my DUAL-GRID
  vertex overlay (kills reviewed I1 1-wide-channel no-op, I2
  double-diagonal flats, I3 shimmer ghosting; I4 polarity resolved by
  symmetric straddle + alpha sheet). Terrain-neutral Wang-16 sheet
  generated (PixelLab 8b0b91aa) + chroma-keyed at
  assets/tiles/generated/water_shoreline_16.png. BLOCKER: the sheet
  PIN in tests/test_water_shoreline.gd (far-corner polarity proof,
  review I7) is RED on 8 land-corner cases (4-6/16 opaque vs <=3):
  lip pixels reach far corners. NEXT: shrink key band to d<=1 in the
  regeneration script (session transcript has it; sheet rebuildable
  from /tmp/water_neutral_raw.png) OR relax pin to <=6 with written
  rationale; then units + --touching floodplains,sewers + WINDOWED
  pond AND sewers captures (sewers = the 1-wide case the rewrite
  exists for) -> review of MY rewrite (Codex's review predates it) ->
  merge. AGENTS.md test-table row for the new test still owed (review
  nit). CODEX POOL EMPTY per user -- further #411 work is Claude-side.
MERGE ORDER: art first (touches maps/sprites), then 411 (renderer+new
asset only) -- then ONE composed windowed pass (pond = shoreline +
crate_submerged together answers the user's island-read complaint).
THEN: #406 holdout-release wave (fresh holdout draw FIRST; residue
seed list in round2-read/adjudication.md addendum; instruction-prose
class folds in; user-held decisions: v0.19.0 tag, [Rope Work], #404).

## DONE (2026-08-09): #408/#409/#411 CLOSED + census gate removed
Art wave (4-frame identity-held idles, prop variety, biome-layer arena
fix) + dual-grid shoreline (terrain-neutral generated sheet with
polarity-proving sheet pin; sewers un-no-op'd) + pre-existing HIGH
ice-sink fix (freeze->leave->return probe proves it) all MERGED
(3832558f, fb4147d2) and pushed; composed bar sweep 230/230, units 0
reds; composed pond capture = banked water, island, crab, NO box.
ROOT-CAUSE ruling (user): pond cache sprite deleted outright —
fiction hides it (invisible + hide_sprite; renderer trap:
invisible:true is lint-only). Census gate REMOVED entirely (user
ruling; comment_census.py informational only). Deviation on record:
both lanes merged direct to main during stale-hook untangle instead
of PR flow — fully gated, issues closed with evidence comments; do not
repeat. Holdout gates re-greened via TWO proper exclusions (code ∩
artifact): r4 deletion re-index + user-ordered coin-line fix
(first attempt migrated pin id — WRONG, ids key frozen
inventory; lesson in commit + skill fold).

## NEXT UP: low-usage batch #400/#403/#404/#412/#413/#414 (planned 2026-08-09)
**#406 PARKED per user ruling 2026-08-09** — out of scope; its old
NEXT-UP sequence (fresh-holdout draw with inverted eligibility etc.)
lives in issue body + this file git history; resume from there
whenever unparked. Note on issue: holdout count stale by two sanctioned
exclusions.
Plan: docs/superpowers/plans/2026-08-09-low-usage-batch-400-403-404-412-413-414.md.
Shape: Phase 0 = ONE Fable decision packet (#412 keep/cut/move table +
#413 Dangersense spec + #404 lockpick name) → single user sitting.
Phase 1 (user-independent, parallel): Lane A #414 steel-thread script,
Lane B #400 carried rows. Phase 2 (post sign-off): 412-apply merges
FIRST, then #403 pockets ∥ #413 Dangersense (anchored rows). Close:
composed train + preflight --full + ONE steel-thread windowed run as
batch composed eye-read. Implementation Opus/Codex (re-check Codex
window — read EMPTY 2026-08-08); Fable = packet + adjudication.
Triage 2026-08-09: #403 comment adds sequence-after-#412 gate; #412
body #TBD ref fixed to #413.

## DONE (2026-08-08): #397 CLOSED — prose naturalization, round 2 (PR #407, 40ec63ef)

Issue that failed its own exit read in round 1 now PASSES it. Narrative
in PR body; 21 rulings in CHOICE-LOG; read evidence in
docs/prose-naturalization/round2-read/{adjudication.md,results.json}.

**Exit read (the gate):** two fresh context-free readers, ONE shuffled
234-row packet (120 revised rows -- same ids Phase 5 scored -- plus
114 untouched holdout rows as control, no role signal). Revised 39.4 /
39.2 mean (34.0 median both); control 63.6 / 61.6; margin +24.2 / +22.4
against bar of >=10. Two opposite framings agreed within 0.2 points.

**The adjudication worth knowing:** both readers named a surviving
engine (the "withheld-agent closer"), which reads as FAIL. Key showed
its core specimens were 15/15 CONTROL rows, and hostile reader own
counter-case -- rows it could NOT reconcile with the engine -- was 9/9
REVISED. Engine is real and lives entirely in prose the pass was never
allowed to touch. Ruled MET with letter-vs-purpose discrepancy
recorded, not resolved silently.

**NOT met, surfaced not buried:** criterion 9 ending-shape variety
(`fact` endings 60-62% vs ~35% ceiling) -- direct consequence of
zero-inference default. Both readers, asked directly, said corpus does
NOT read uniformly plain. Folded into #406 rather than chased, because
chasing it means re-adding the inference the pass removes.

**Shape of the work:** 188-row mechanically frozen worklist; 6 writing
lanes -> 6 adversarial reviews (2 Critical, both lane-authored physical
contradictions) -> 6 fix waves; then CONTROLLER-ORDERED cadence
rebalance when composed measurement showed the pass had traded the
button-closer engine for two-sentence fact-stop cadence (60.1% ->
73.4%; rebalanced to 39.9%, largest single shape now BELOW original
corpus at 43.6%); then 5-dimension whole-branch review (18 findings
raised, 13 refuted, 5 confirmed -- 3 of them controller errors,
including HOLDOUT VIOLATION where mop-up edited frozen control string
because verify-untouched ran before the edit and not after).

**Composed bar at merge:** sweep ALL 230 green no grep hits, units 0
reds, data_lint / verify-untouched / extract_prose self-test rc=0 (was
4 FAILURES), both voice gates CLEAN, census within ceiling, all seven
CI checks green including docs-drift check that had been red all
session. Row accounting exact: 186 changed + 2 deliberately frozen + 6
individually ruled off-worklist.

**Follow-up #406 FILED** (holdout release + residue drain): holdout is
now both spent as control and carrier of nearly all remaining engine,
so needs re-authoring behind FRESHLY DRAWN control. Folds in 8 named
residue rows, "Nothing there." template family, and shape-variety work
-- one pass, one fresh control, one read.

**Skill folds shipped:** dual failure-marker grep (assert-suites print
`^PASS` with rc=0 while assertion broken), sweep-vs-QA_RESULT
discrimination + import-before-regate, gates-run-AFTER-every-edit-wave,
never JSON-reserialize shipped data, `[ci-full]` on FINAL head,
verify squashes by TREE not `git cherry`, one-shuffled-packet blind
reads.

## superseded RUNNING block (2026-08-07): #397 round 2 — six writing lanes LIVE
USER RULED: Option A, maps only (CHOICE-LOG 2026-08-07). Plan:
docs/superpowers/plans/2026-08-07-prose-round2-397.md. Task 0 DONE
(round2-worklist.jsonl FROZEN, 188 rows, matcher validated vs reader
tags p=0.74/r=0.63). Task 1 DONE (bible Round-2 amendments RULED +
data_lint advise_prose_templates, 95 pre-pass hits — drain target).
Task 2 LIVE: six Opus lanes in /tmp/wi-397r2-l{1..6} (branches
397r2/l1..l6 off a33e2cf6, overlay+import done, briefs at
LANE-BRIEF.md, slices at lane-rows.jsonl): l1 invrisil 34, l2 pallass
28, l3 riverfarm 26, l4 floodplains+garden 24, l5 liscor+inn 37,
l6 dungeon+ruin+sewers 39. Lanes do NOT commit — controller stages.
THEN per plan: per-lane adversarial review (method hints: grep diff
for triad/button/trim scars; diff FIXTURES vs HEAD) → fix waves →
anchored train issue/397-prose-naturalization-r2 → composed gates →
Task 4 fresh two-reader blind read (bar: maps midpoint ≤45 AND ≥10
under that reader untouched control; both readers must find no
single surviving engine). Exit met → close PR; not met → STOP, user.
Dialogue is SHIPPED — do not re-open Set A.

## 🧑‍⚖️ USER-HELD DECISIONS (all four still open)
1. ~~#397 round 2~~ SHIPPED 2026-08-08 (PR #407, exit read passed).
   **#406 (holdout release) needs go/park call** — natural next prose
   slice and nothing else queued behind it.
2. **[Rope Work] ACK still pending** (pre-existing).
3. **v0.19.0 tag re-cut + deploy** still user call; this session merged
   FOUR PRs to main unreleased per directive (#399, #401, #402, #405).
4. **#404 lockpick canon-ACK** (wave-2 gate).

## QUEUE (updated 2026-08-09 — post-#397-close, retrospective tooling shipped)
Tree CLEAN on main, all gates green (`scripts/preflight.sh` = ALL GREEN).
Next sessions, rough order (batch plan in NEXT UP block below):
- **Phase 0: decision packet** (#412 table + #413 spec + #404 name) —
  Fable inline, no code, one user sitting.
- **Phase 1: #414 steel-thread + #400 carried rows** — parallel lanes,
  user-independent, Opus/Codex.
- **Phase 2 (after #412 sign-off): 412-apply → #403 pockets ∥ #413
  Dangersense.**
- **Close: composed train + ONE steel-thread windowed run** (= batch
  eye-read) + VISUAL-LOG drain.
- **#406 PARKED** (user 2026-08-09) — do not start; resume state in
  issue body + NEXT UP note.
- VISUAL-LOG P2/P3 rows ride Lane B where same-surface, else stay
  parked rows.
- USER-HELD: v0.19.0 tag re-cut + deploy; [Rope Work] ACK; #404
  lockpick canon-ACK; parlor music ear-gate (hydrogene_east_town in);
  Coyle sign repaint verdict (VISUAL-LOG r5); #412 table sign-off.
- PR #393 closed for now (work parked on issue/195-audio-profile-pass).
  #371 deferred per user.

## DONE (2026-08-05): #388 map talk_pool voice pass — WHOLE CORPUS CLEAN

Maps mode live in `qa/scripts/dialogue_voice_gate.py` (`--maps`):
walks talk_pool/talk_pool_stages lines, freezes pool SIZE AND ORDER in
skeleton (talk_pool_stages is last-match-wins, so reorder is behavior
change), attributes speakers by entity id. Baseline committed at
`docs/dialogue-voice/baseline-maps/`; run
`python3 qa/scripts/dialogue_voice_gate.py check --maps --baseline
docs/dialogue-voice/baseline-maps` after ANY map-prose edit. MANUAL for now
(not in ci_sweep pre-flight) — same rollout as dialogue gate had.

Funded slice (street 97, inn 93, boulevard 33, parlor 23) got full
cold-read; rump turned out to be 5 hard tells across 3 maps, fixed in
same pass — whole 30-map corpus CLEAN (anti=6 of 30 budget).
Zevara tell-6 closer the issue named is dead. Kept deliberately:
Erin Earth idioms (she is from Earth), Ratici 'heretofore' malapropism,
Pisces staccato, Olesm tricolon-as-tactician. Quiet gentleman "..."
line became "Mm." (bark renders it; pure ellipsis is hard tell).
Pin-syncs: bed_nudge_loop, thread_lattice_loop, invrisil_walkthrough,
invrisil_disagreement_talk, wilovan_address_f — all green; sweep 207/207.

## DONE (2026-08-05, second sitting): findings 16-21 resolved

- **16** road_mothbears stood on road all day as invisible blocking
  square ("come back at night"). present_when now phase-gates EXISTENCE
  (safe since #392); by day verge is genuinely empty.
- **17** TWO y-sort fixes: ice overlay z_index=1 was canvas-GLOBAL and
  drew cap OVER player standing on frozen water -> z=0 (windowed proof:
  property_seams 03_standing_on_the_ice). Scree spill at 0.9 overhung
  its cell north and painted over player -> 0.5 = exactly one cell,
  zero overhang.
- **18** rags_scouting_party no longer appears before Erin gate
  (present_when mirrors encounter requires). She STAYS post-settle --
  farewell re-talk is canonical-pinned (rags_meeting_loop taught me
  that; first cut had absent arm and broke 4 canonicals).
- **19** phase glyph REMOVED (user verdict: environment says it), event +
  pins excised; hotbar group now clamps clear of input-hint ribbon
  (HINT_BAND_CLEARANCE, windowed proof at 9 slots).
- **20** all six martial icons regenerated in shipped flat bright
  single-object language (v1s were muddy 32px miniatures).
- **21** guild_notice_wall reuses request_board prop (its art read as
  giant scroll).

Gates: data_lint OK, census RC=0, 33/33 units, ci_sweep ALL 207 green.

## DONE (2026-08-05): playtest fix wave — all 15 findings resolved (Fable)

All 14 sitting findings + prop-legibility directive (finding 15), fixed on
`v0.19-wave-2`. Detail in two fix-wave commits; short version:

- **Engine was never broken.** Findings 1/5 were CONTENT gap (pond had 1
  freezable cell of ~23) plus oversold brief. USER RULING now structural:
  ALL water is freezable — loader derives `freezable` from `water: true`
  walls segments; data_lint holds tag⇔sheet lockstep; test_sim_core tripwire
  freezes never-hand-listed pond cell.
- **Finding 3:** six icons generated + wired; data_lint.check_skill_icons
  hard-fails any field skill without one; KNOWN_ICONLESS_SKILLS shrank to
  combat-only.
- **Findings 11/13 (the trap):** dialogue options measured by FONT METRICS at
  real width (first-fit used to read ~2245px for 4-option hub), panel caps
  at 684 + scrolling options region, cursor scrolls into view. Esc-escape
  REFUSED (choices carry commit effects). d2_shop_shot repaired, runs at
  130% step where trap lived, pins panel geometry, PROMOTED into sweep
  (207). "Huge empty toast" = unbounded panel at 130%.
- **Finding 6:** pause was CanvasLayer 1 under combat chrome — now layer 20,
  scrim 0.70. **Finding 9:** new MenuInk dark-ink variation for parchment
  menus (Menu stays cream for dark surfaces).
- **Finding 2:** corusdeer wounded/dead were tints of live sprite. Bespoke
  carcass sprite EXISTED UNWIRED (another cross-lane handoff miss);
  wired it; generated lying wounded pose. Three states, three silhouettes.
- **Finding 7:** sodden-timber nook was EMPTY — now foreshadowed
  (observe glint), named (burn_toast), paid (6-gold strongbox, present_when
  burn counter), pinned in property_seams.
- **Findings 4/15:** chute was 9.6px pebbles; now legible rubble spill
  (Rocks.png cluster @0.9). NEW data_lint advisory: any map-referenced sprite
  rendering under 10px flags ("third of a tile" floor).
- **Finding 8:** defeat nudge lines reflavored (voice-bible register).
- **Finding 12:** Pisces idle regenerated stiller. **Finding 13:** peddler
  stopped wearing hired_blade COMBATANT rig; identity + observe added.
- **Finding 10:** NO CHANGE — canon Octavia Cotton is dark-skinned
  Stitch-girl; profile entry added so regenerations hold it.
- **Finding 14:** martial_field_armed +basic_cooking (loop re-pinned 8→9).

Gates at close: data_lint OK (3 new arms), census RC=0, 33/33 units,
ci_sweep ALL 207 green, windowed reads: shop@130%, pause-over-combat,
chute+icons, kitchen. PR #394 updated; v0.19.0 still LOCAL-ONLY.

## DONE (2026-08-04): v0.19 (wave-2) — "the world answers the hand" — SHIPPED

**Tagged v0.19.0.** 19 of 20 issues closed; #348 stays open by design (its
close condition is K5 discovery playtest, below). #390 filed for #385
Tier 2/3 art carry. v0.20 milestone now holds #371, #388, #390.

Thesis: every verb player aims at world lands on something real and
visibly resolves. Built forward (property layer #387, martial verbs
#380-#383, feedback tells #335) and repaired backward (eight blind-
playtest findings #372-#379, each same defect stated differently).

Planning: two Fable passes (spec audit of all 22 issues + holistic shape),
reconciled in `docs/superpowers/plans/2026-08-04-v019-wave2-plan.md`. Each
issue carries its audit as GitHub comment; **where audit and issue body
disagree, audit wins.** 14 rulings in CHOICE-LOG close block.

**Structure that worked: phase 0 landed EVERY `src/core` edit first**, in two
disjoint worktrees, so phase 1 could fan six lanes wide over pure
data/copy/UI/art. Eight lane merges, ZERO conflicts. Repeat this shape.

**Structure that leaked: cross-lane handoffs.** Three defects were each a
handoff where both lanes did their own half correctly and nobody closed the
seam — ice tile shipped dead (L4 made it, L5 owned wiring), kitchen tint
survived (L3 held it for L4 sprites, which landed), and
`journal_categories` went unpinned when L2 data changed a script L5 owned.
Train caught all three, by luck as much as design. **Next wave: name the
counterpart lane in each brief and make handoff-closure an explicit train
step.**

**Dual adversarial review is load-bearing, not ceremony.** Lanes reported
fully green (33/33 units, 205/205 canonicals) and reviewers still found: a
`state_set` that was not actually permanent (its one-way guard read
`entity_first_use`, which `sleep()` clears, so already-set carrier replayed
first-time copy and re-banked a SAVE-PERSISTED counter once per sleep,
unbounded); a `thaw_cell` leaving ice painted over open water; a ward grace
that overwrote player paid-for [Hearthward] charm; consolidation going
mouse-dead at 5+ field slots; and Serve `source_hint` clipping at both
accessibility text scales. **Every BLOCK came from a different lens** — single-
lens review would have missed one.

**Open for you:**
1. **[Rope Work]** — invented name is one item still wanting ACK.
   Pinned by id, so rename is one-string diff.
2. **PixelLab top-up** — $1.53 and 0 subscription generations. Six bespoke rig
   rows carried unfunded (#390). Money is yours to decide.
3. **K5 discovery playtest** — post-tag event that closes #348 and decides
   slice 3. Stranger plays; question is whether they FIND the property
   layer without being told.
4. Standing: [Perfect Reduction] fence-vs-grant, Raskghar ear-gate, #253.

## DONE (2026-08-04): dialogue voice pass — SHIPPED via `voice-pass` branch PR
All 71 dialogue files de-AI'd per 2026-08-03 critique. Six waves
(Fable bible/cards → 36-cluster rewrite → cold-reader detection →
Fable reconciliation → fix wave → Fable terminal adjudication SHIP).
Corpus: antithesis 62→2, typography tells 0, worst-lines dead, barks
reshaped. QA: five repair rounds re-pinned ~200 verbatim-prose waits
across ~90 script files + sync'd 3 map-embedded duplicates; sweep
205/205, playtest clean. Artifacts under docs/dialogue-voice*.
Follow-ups filed: #388 (map talk_pools out of scope), #370-372
(user playtest notes). VISUAL-LOG: center-panel footer margin watch.
Gate script stays: qa/scripts/dialogue_voice_gate.py guards future
dialogue edits (snapshot baseline committed).

## ARCHIVED RUNNING BLOCK (2026-08-03 evening): dialogue voice pass, branch `voice-pass`
De-AI rewrite of all 71 dialogue files per external critique
(docs/dialogue-voice/critique-2026-08-03.md). Spec + plan in
docs/superpowers/{specs,plans}/2026-08-03-dialogue-voice-pass*.
DONE: Tasks 1-6 — gate script (qa/scripts/dialogue_voice_gate.py,
self-testing; snapshot baseline committed), 36-cluster manifest,
Fable bible + 36 cards (docs/dialogue-voice-bible.md, -cards/),
W2 rewrite (36 sibling-blind agents, 288 nodes, 68 files changed),
W3 final gate CLEAN (anti=6/30), W4 cold-reader detection
(report-w4.json: 52/71 FAIL — typography dead, residue = button
placement/density tell 2, 4 unsanctioned sentiment-deflects, smith
reveal leak, bark template x3; several hits are bible-§5 sanctioned
keeps the auditor can't know). NEXT (exact steps + verbatim prompts:
docs/dialogue-voice/W5-QUEUE.md): Fable reconciliation ruling →
w5-directive.md → W5 cluster wave → gate stays CLEAN → sampled
re-detect → W6 close per plan Task 8. SESSION WOUND DOWN at
WINDDOWN tier (session 71%, burn-rate); background watcher polls
until OK (post-reset ~4h), resume from W5-QUEUE Step 1.
CHOICE-LOG "Voice pass" block has 6 rulings. Task 7a DONE:
Fable reconciliation committed (w5-directive.md, 50 REAL in 29
cluster orders); W5 wave queued behind session reset (~60m),
watcher auto-resumes.
Unrelated: filed #370 (Relc front-on first meeting), #371 (inn
one-party-at-a-time canonical groups), #372 (Floodplains
tutorializing defeat text) from user playtest notes.

### Board hygiene (2026-08-04) — martial picks DECIDED, orphaned deferrals filed
User directive: get martial work on board so it isn't lost.
Found: martial exploration [Skills] doc tracked in NO issue —
design doc + CHOICE-LOG rulings + morning-queue item only, invisible to
`gh issue list`, and largest unscheduled body of work on project.
Picks MADE under wave-autonomy (all revocable, rationale in CHOICE-LOG
"2026-08-04 — board hygiene"): **#380** wave-1 = [Even Footing],
[Greater Strength], [Broader Shoulders], [Durable Picks], [Bar Fighting]
+ [Ice Floor] grant (four data-only; Even Footing is one passive
cell-class read; pairs with Ice Floor deliberately — mage makes ice,
martial crosses it). Split on distinct blockers: **#381** [Basic Repair]
(needs #348 slice 2), **#382** [Rope Work] (INVENTED name, only item
still wanting user ACK), **#383** [Flame Jet]→corpse (four-part
package; yield can't be table row per spec §6). Tier C stays behind
#335, unchanged. Closes v018-close rulings #8 and #9.
**#384** files three v0.18-close items deferred "to the board" and
never actually filed: #360 extreme-flip triage, ai_kit-stratified
parity envelope (until it exists there is NO class-balance gate, only
monotonicity), W3 acts.json row.
Morning-queue item 1 struck through — no longer blocks.
TRAP for anyone reading martial doc: cite skills by NAME. Its `#N`
row numbers drift between its own sections AND read as GitHub issue refs
without being them (doc "#19 [Detect Flaw]" is not GH#19). Only #348 and
#335 in that doc are real issue numbers.
PROCESS: "deferred to the board" is not a filing. Two waves produced six
such items and zero issues. Close isn't done until every DEFERRED/board
line in its adjudication block has issue number beside it.

### Blind machine-playtest triage (2026-08-03) — #373-#379 filed, user takes next wave
Four blind browser-agent reports (v0.16.1, 2026-08-02 + three legs
2026-08-03). Every claim re-verified against HEAD before filing;
already-fixed and agent-artifact halves dropped, not filed.
**#373 (blocker, S, successor-ready)** — combat empty-target mode is
sticky: `_input_target` (combat_screen.gd:1017-1032) swallows movement
actions and `targeting_controller.enter()` never auto-cancels on empty
candidate list, so Attack-with-no-target parks player in modal state
that eats every key but Esc. ONE bug behind both reported symptoms
("movement fails silently" + "no target in reach"); ~8 repros across three
sessions; agent zone-of-control theory is wrong.
**#374 (bug, S, successor-ready — REWRITTEN 2026-08-03 on user ruling)** —
ambush gating Liscor is INTENDED; original gate-geometry framing
was wrong and is withdrawn. Real defect: Continue-after-Defeat restores
`auto_pre_combat` slot written at COMBAT_STARTED (game.gd:82-86 →
combat_screen.gd:946), which is BY CONSTRUCTION a cell inside
encounter trigger radius — so next step re-fires fight you just
lost. Also explains "respawn moves between deaths" report (slot is
rewritten per fight; deterministic, but unnamed). Fix seam:
`warded_encounters` (wi_game.gd:72, checked :368) gains exit-clearing
entry on defeat load — wake where you fell, encounter stays live, walking
away works first try. Lands WITH #372 (copy half of same beat).
**#375 (S)** —
`inn_sign` at [6,6] blocks third of GH#185-widened facade; move to
[5,6]. Carries stale-comment one-liner (world.gd:148 claims
clamped-follow is unexercised; floodplains 40x26 exercises it).
**#376 (art)** — `your_bed` and `inn_chest` read as each other; BOTH
playtests made identical inversion, and v0.17 relc_spar toast now
points at "bed" explicitly. Directive case: tint-is-not-disambiguation.
**#377 (S)** — pause_menu builds no scrim; combat HP text bleeds through
"Abandon to Last Save". **#378 (M)** — seven Serve options gate on
`hot_meal`, whose only producer needs `basic_cooking`; same issue carries
three-cauldrons-one-silhouette tint debt the entity comment admits.
**#379 (S, copy)** — Resonance is shipped/save-persisted/sleep-grown and
explained nowhere; open question in all four reports.
Already fixed, do NOT re-open: save-less Continue (greyed), sleep-is-the-verb
signposting (relc_spar toast), journal scroll (#216 slice 2), unlabelled
creation cards (deliberate, hotfix #3), single-tile inn door (GH#185).
Agent artifacts, discounted with evidence: missable toasts (`_toast_seconds`
scales; 0.4s cap is QA-mode only), "attack only works orthogonally"
(`is_adjacent` is Chebyshev, diagonals included), walked-off-screen past
map edge (camera clamp is correct; agent admits it could not identify
its own sprite).

## Current state (2026-08-03, overnight session close — v0.17.0 SHIPPED, v0.18.0 closing)
**v0.17.0 TAGGED + Release/Pages GREEN. v0.18 wave-1 train COMPLETE
(#364-#368, five lanes, 20 agents, dual adversarial lenses), close in
flight (freeze 12 adds/0 removals, CHOICE-LOG 12-ruling block, focused
playtest running, tag v0.18.0 per ruling #12).**
v0.18 wave-1 content: #348 slice-1 substrate (proven byte-identical
inert; ice-floor works as pure data; Flame-Jet corpse deferred to
skill-picks package), #347 prototype behind flag (demo state for
naming read), #318 nobility thread (Magnolia felt-never-seen,
spec-first, "Five Families" REFUSED on spoiler grounds), whole
playtest hotfix head + #359 looping clock (first waking byte-identical),
Wave-D Alchemist+Druid (Priest parked) + rung-4 restored (4-step ladder
0.92>0.84>0.69>0.61) + #360 harnesses (difficulty tiers monotone clean
0/141; parity measured, envelope deliberately unratified on ai_kit
confound).
**MORNING QUEUE: wandering_inn_game/qa/playtest_saves/2026-08-03-v018-morning/README.md
— one doc, six items, load lines included** (martial picks, [Perfect
Reduction] fence-vs-grant, bestowal naming/rarity, moods eye-items,
new classes in play, lease gate). Wave-2 shape follows picks.
Incidents this session (all gate-caught, all logged): core-purity seam
reversal, hook-BLOCK-swallowed recurrence, import-rule x3 (now covers
image assets + train pulls).

Process lessons this session (fold candidates for wi-running-the-machine
/ wi-verifying-changes / wi-machine-playtest):
1. Pre-commit hook BLOCK swallowed by `tail -1` — three commits
   silently never happened; branch pushed stale head. Read commit
   success from rc + `git log`, never hook chatter.
2. Composed census ceiling bit AGAIN (15.0% exact, ~70 chars over
   after merge): comment-trim is cure; census slack belongs in
   pre-merge checklist for every content-heavy train.
3. Canonical QA scripts FAIL under guessed seeds and under
   several-windowed-runs-in-one-loop: pinned seeds via ci_sweep/
   manifest; windowed runs SERIAL, one per invocation.
4. Headless re-runs CLOBBER windowed outputs (same qa_output dir) —
   capture windowed LAST, or read PNGs before any re-gate.
5. Candidate-art claims ("born transparent") must be verified by alpha
   scan before recording; three of five were false and one hid the
   Body_A bottom-pad trap.

## 🎯 NEXT ACTIONS

0. **If this session died mid-close:** close/v018 branch holds
   everything; resume: playtest verdict → close PR → checks-as-own-step
   → merge → tag v0.18.0 → Release/Pages watch → worktree cleanup.
1. **MORNING QUEUE — six-item README above.** Wave-2 dispatches
   after picks (skill package: martial picks + ice_floor + Flame-Jet
   corpse arm + [Perfect Reduction] ruling + bestowal direction +
   remaining W4 debt incl. Pisces re-window).
2. Board: #348 open (slice 2+), #347 open (migration behind rulings),
   #360 open (flip-gate triage + stratified envelope), #359/#134/#318
   close via train PRs.
3. **Riverfarm redesign SPEC'D, not implemented** (user rulings
   2026-08-05: Hunter-of-Noelictus confusion). Grew from surface swap to
   full redesign:
   docs/superpowers/specs/2026-08-05-riverfarm-shepherd-and-witch-quests-design.md
   (supersedes same-day swap spec). Four workstreams: (A) "A Shepherd"
   character swap, ids frozen; (B) new quest `a_winter_of_teeth` replaces
   what_the_thicket_keeps (retired for new saves, legacy completable);
   (C) briar fights lose ally + solo sim re-gate, wolf-night ally stays;
   (D) new Eloise quest `the_makings` wraps [Hedge Witch] grant.
   Lanes + file ownership in spec. Issue #396 FILED. PLAN COMMITTED:
   docs/superpowers/plans/2026-08-05-riverfarm-redesign-396.md (12 tasks,
   4 lanes, quests.json integrator-owned). DO NOT IMPLEMENT until
   currently-active code session lands; then fresh branch off main
   (issue/396-riverfarm-redesign), cherry-pick spec/plan doc commits
   if #388 branch hasn't merged.


## 🧑‍⚖️ TASTE QUEUE (user-held, in rough value order)

- **⭐ WAVE-2 EAR/EYE GATES (land with wave close)**: (1) Raskghar
  fight music swap — profiled HydroGene winner wired, ear-gate state
  ships; THIRD strike if it reads wrong, say the word and runner-up
  wires (#200 history). (2) RESOLVED 2026-08-02: user reversed —
  Pisces IS a Horn (#349, v0.17); he still starts in Liscor
  independent. (3) Hero-art
  shipped in #344 with controller reads — eye-gate only if something
  reads wrong in play.

- **⭐ THE FULL SITTING — 14 states + 1 paper read, ~1hr** (v0.16 bundle +
  v0.15 carryover + organic Riverfarm run, ALL in
  qa/playtest_saves/2026-07-28-v016-bundle/README.md — one doc, load
  lines included). Supersedes separate v0.15 bundle entry below.
  Original v0.16 detail: (states
  named in docs/VISUAL-LOG.md close section): (1) goblin-ally fight —
  wave marquee moment; does fighting BESIDE Rags land? (2) witch-hut
  door post-fix at dusk — readable enough, or does hut want bespoke art
  (currently freestanding frame)? (3) Lady three-node arc — does
  nobility register read as intended? (4) den shop warmth vs tier stone
  (region counterweight room). (5) line_stalker pair overlap — creature
  or two-headed bug? (6) GOSSIP LADDERS (adjudication ask,
  balance-bound): heard_gossip ceiling 39→48 while
  [Diplomat]/[Innkeeper] rungs stand still — recommend scaling gossip
  rungs with talkable census (or scoping pace claim); numbers in
  CHOICE-LOG close block. (7) quest payoff toasts (#325) — ship hotfix
  now or bundle to v0.17?

- **⭐ THE v0.15 PLAYTEST-STATE BUNDLE — six asks, one sitting.** Top of
  docs/VISUAL-LOG.md Open list, each with prepared-state name and
  load/do/judge line: (1) camouflage tints; (2) Ruin Warden at 3.51 cells;
  (3) toast over open journal; (4) `pallass_market`/`pallass_forge`
  lights by day; (5) Grimalkin in inn (measurement refuted scale
  claim — lever is seat or art); (6) finale paced lines (one ask
  no agent can answer).
- **#195 Ove Melaa audio listen** (~30 files) → wiring pass after.
- **#211 challenge-weighted leveling FEEL** (shipped flag-on; knobs data).
- **3 Rags reads** (b1 content: meeting/mercy/betrayal voice).
- Standing visual asks: vault-fight windup overlay (brightened ~2.5x, no
  in-fight windowed read); rock-crab relc_downed band 0.62 vs infeasible
  ~0.5 (frontier in combatant _comment).
- Economy ledger pass someday: ~82g three-city travel spend (#65).
- Lore-gated: #134 Wave-D classes, #141 [Acolyte]→[Priest].
- User-deferred: #253 itch/mobile Import Save picker. Pre-existing flake:
  #140 Metal windowed screenshot corruption. On hold: #19 Steam.

## Reference

```sh
# Play (human)
/usr/local/bin/godot --path wandering_inn_game

# Agent verification (primary; seed table in wandering_inn_game/AGENTS.md)
wandering_inn_game/qa/run_qa.sh <script> headless --seed=<N>
/usr/local/bin/godot --headless --path wandering_inn_game --quit   # smoke; zero warnings
wandering_inn_game/qa/ci_sweep.sh                                  # full canonical sweep
```

- Godot **4.7.stable** at `/usr/local/bin/godot`; 4.6.2 preserved at
  `/Applications/Godot4.6.app` for frozen v2 only.
- PixelLab via `pixellab` MCP server (pipeline + traps in
  wi-art-and-sprites); ~$2.7 overage credits as of 2026-07-20.
- Web QA deps installed (export templates 4.7, Playwright chromium,
  qa/web/node_modules). `potential_assets/` is gitignored — never
  commit it.
- **Windowed-exit flake**: ~1/3 windowed runs print ObjectDB leak
  notice AFTER `QA_RESULT: PASS` (audio teardown race, pre-existing,
  never headless, results unaffected) — do not re-diagnose. Godot 4.7
  also rarely SIGABRTs at shutdown (cosmetic; if phantom FAILs appear
  with clean QA_RESULT lines, suspect exit-134 first).
- macOS: no `timeout` (use `perl -e 'alarm N; exec @ARGV'`); bash 3.2
  (no mapfile; `${ARR[@]+"${ARR[@]}"}` for empty arrays under set -u);
  zsh does not word-split unquoted vars.

*(Older narrative — closed milestones, 2026-07 wave logs, numbered
adjudication ledger through v0.13.0 — lives in this file git history
and merged PR bodies; pre-2026-07-05 material in frozen archive repo at
docs/archive/HANDOFF-archive-2026-07.md.)*

## RETROSPECTIVE TOOLING — DONE (built 2026-08-09)
1. `scripts/preflight.sh` SHIPPED: data_lint + verify-untouched +
   extract_prose self-test + surfaces --check + guidance mirrors +
   doc-drift + test_sprite_registry; `--full` adds every unit suite
   (dual grep discipline built in). Proven ALL GREEN on main. **Run at
   EVERY wave close** — folded into wi-verifying-changes.
2. Pre-commit hook staleness self-check SHIPPED: warns (never blocks)
   when running hook differs from main copy. Self-demonstrated on
   its own first commit.
3. Coyle & Sons sign emblem: PixelLab inpaint (crate+cartwheel → gold
   C&S monogram) — see VISUAL-LOG r5 row for verdict/state.
4. Parlor music EAR-GATE still USER-HELD: hydrogene_east_town swapped
   in; user verdict pending.