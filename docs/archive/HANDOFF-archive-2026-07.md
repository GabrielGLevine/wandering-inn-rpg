# HANDOFF archive — 2026-07 (M0 through M6.5-era, superseded playtest triage)

Archived 2026-07-07 as part of the repo-cleanup pass (issue #36).
Verbatim closed-milestone narrative moved out of `HANDOFF.md` to keep the
live handoff under budget. Nothing here is still open — every still-open
item (⚑ flags, playtest checklists, RESOLVED rulings cited by GitHub
issues) stayed in `HANDOFF.md`. Original line numbers noted per section
for `git log --follow`/blame continuity.

## SOCIAL-2 build narrative (Phases A-D, was HANDOFF.md lines 5-121)

## SOCIAL-2 (relationship progression, LINEAR stages) — Phases A+B+C+partial D LANDED (2026-07-07)

Ledger checked (`.superpowers/sdd/progress.md`, HANDOFF RESOLVED blocks) before
starting — no social-adjacent item was already ruled on; nothing re-flagged
below duplicates a closed RESOLVED entry.

**Landed, 51 canonicals green (was 50 — new `stages_loop`), zero-warning:**
- **Phase A (seam + Lyonette retrofit):** `talk_pool_stages` (ORDERED
  `{id, requires_accomplishment, lines}`, last-met-wins) generalizes the old
  one-shot `talk_pool_post` in `social.gd`'s `talk_pool_line`. Lyonette's
  shipped `talk_pool_post` migrated verbatim to a one-entry
  `talk_pool_stages` (rename, zero copy changes — implementer's call per the
  staging note, disclosed). New pure unit (`test_sim_core.gd`) proves
  unmet→base / one-leg→stage2 / both-legs→stage3 (last-wins, not
  "hardest"); a NEW content validator (`test_content.gd`,
  `_validate_talk_pool_stages_ascending`) REJECTS out-of-order authoring at
  test time (the "rejected or normalized" unit requirement — rejected,
  disclosed) rather than tolerating it at runtime.
- **Phase B (5 pooled NPCs):** Krshia/Selys/Pisces/Olesm/Zevara all got
  `talk_pool_stages` + their `dialogue_unlocks` (hub topics + nodes) lifted
  verbatim from `docs/design/social-2-staging/*` (staging_note/_flag/
  _comment* stripped). New counters: `heard_krshia_plans`,
  `claimed_bounty_{crate,cisterns,warren}`. **Krshia's shop discount is
  built** (the pin-hazard item): 4 stage-gated duplicate buy options
  (charm 5→4, knife 15→13, cloak 18→16, jerkin 24→22) + `hide_when`-retired
  full-price rows. Pin analysis: grepped every canonical for
  `chatted_with_krshia` — max ever reached is 2 (`social_loop`'s own
  negative assertion); nothing reaches the stage-3 gate (`chatted_with_krshia:4`
  + `crate_returned:1`), so the shipped pins hold untouched. **Engine
  change, disclosed:** `dialogue.gd`'s `_meets()` was a first-match-wins
  chain (one gate type per call); the discount options need
  `requires:{gold, accomplishment}` together (met-stage but broke must show
  GREYED not hidden — window-shopping is content), so `_meets()` is now a
  full compound AND across recognized keys, and a new `_meets_progress()`
  reads ONLY the accomplishment leg for hide-until-met visibility.
  100% backward compatible (every pre-existing option uses a single key).
  `test_content.gd`'s `_validate_requires` gained the ONE sanctioned
  compound carve-out ({gold, accomplishment} only — every other combo still
  rejected). **Index-shift safety:** every new hub option was appended at
  the END of its array (after the existing always-visible "farewell"
  option), so it can only ever appear LAST in any visible list — proven
  safe by construction regardless of accomplishment state, verified by a
  full 51-script sweep (zero reds).
- **Phase D (the two items that don't depend on Erin/Relc):** Selys' perk
  (one-time vetted-job pointer, `claimed_board_pick` + 5g, NOT the
  repeatable-board variant — flagged below) and Olesm's chess perk
  (option + a short acknowledgment frame node ONLY — per the brief, the
  actual match/wager is NOT built, a follow-up writing task). Zevara's
  watch-bounty perk and Krshia's discount (both "authorable now") shipped
  in Phase B.
- QA: new canonical `stages_loop` (FIXTURE-FIRST, `krshia_stage3_pre` —
  pre-banks `crate_returned:1, chatted_with_krshia:3`, one leg short),
  registered in `qa/manifest.json` + `wandering_inn_game/CLAUDE.md`'s
  compact table. Proves the BEFORE absence (exact 3-option array), banks
  the last leg via one real first-talk-of-a-new-waking pool line (exact
  staged `krshia_fair_weight` line — the gate reads pre-bump so it's still
  stage 1, not stage 2, at that moment), the AFTER presence (exact 4-option
  array), the unlocked topic firing + `heard_krshia_plans`, and the shop
  perk surface (full-price rows gone, friend's-price rows in their place,
  affordability greying still independent). Windowed shots read:
  `.superpowers/sdd/fp-handoff/social2-shots/01_stage_swap_pool_line.png`
  (the swapped pool line on-screen), `02_unlocked_topic.png` (the necklace
  reveal panel).

**Phase C LANDED (this session).** Re-derived the true blast radius fresh
against the CURRENT 51-script manifest instead of trusting the S2-era
"~28" (Erin 12, Relc 22) estimate — the real number is smaller because
ONBOARDING O5 already routes most canonicals through a single Relc/Erin
encounter with no repeat first-talk, and because several new-since-S2
canonicals (`gear_loop`/`stealth_loop`/`rogue_earn_loop`/`stages_loop`/
`char_creation` etc.) never touch either NPC at all. Erin/Relc's
dropped-but-authored S2 pool copy (`.superpowers/sdd/fp-handoff/task-s2-social-report.md`
§Dropped-but-authored) landed VERBATIM as their base `talk_pool`, then the
**true red set measured 8 canonicals**: `inn_walkthrough`,
`dialogue_walkthrough`, `dialogue_hub_loop`, `quest_errand_fight`,
`quest_errand_parley`, `save_load_roundtrip`, `combat_walkthrough`, plus a
LATE find in the second full-sweep pass — `quest_errand_fight`'s and
`quest_errand_parley`'s Erin epilogue report-back (after their internal
sleep beat re-arms her pool) had no explicit `dialogue_started` wait my
first static grep could catch; the empirical full sweep is what surfaced
it, confirming the brief's "land the data, run the sweep, don't just
guess" instruction. Counting every first-talk-of-a-waking absorb point
(some scripts talk to Relc/Erin twice, or even three times, across an
internal sleep), **21 canonicals needed 29 total re-path insertions** —
the S4/O5 idiom exactly
(`wait_for_event dialogue_line` `payload_contains{speaker}` + a second
`interact`), zero parks, zero scripts resisted. `tutorial_flow` and
`relc_tutorial` (the brief's named highest-value routes) were hand-traced
FIRST before any other file: `tutorial_flow` needed 2 insertions (initial
meet + the post-sleep gift re-talk), `relc_tutorial` needed exactly 1 (its
decline→re-talk→gift sequence never sleeps, so only the very first
interact is a fresh pool absorb — verified against `WIGame`'s
`social_talked` reset, which only clears on `sleep()`). Two pure-sim units
also needed updating for the SAME reason (Erin's talk_pool changed
`game.interact()`'s raw return shape on a fresh boot from `{speaker,text}`
to the pool-absorb `{talked,index}`, and added 2 `accomplishment_recorded`
events ahead of a previously-fixed count): `tests/test_sim_core.gd`'s
"npc interact returns dialogue line" case (now asserts on the emitted
`dialogue_line` event's speaker via a new `_last_dialogue_speaker()`
helper, not on `interact()`'s own return value) and two downstream
`accomplishment_recorded` count pins (1→3, 2→4). Then assembled BOTH
NPCs' `talk_pool_stages` + hub-topic unlocks verbatim from
`docs/design/social-2-staging/{erin,relc}_stages.json` into
`skeleton_scene.json`/`data/dialogue/{erin_errand,relc_intro}.json`, using
the SAME index-safety mitigation as Phase B (new options appended at the
absolute END of each options array, after the existing ungated exit).
Full report: `.superpowers/sdd/fp-handoff/task-social2c-report.md`.

**Pre-existing, NOT this lane's work (found at session start, flagging for
the controller so it isn't swept into a Social-2 commit):** `git status`
shows 7 files with tiny uncommitted `[Sneak]`→`[Stealth]` comment-only
diffs (`docs/ARCHITECTURE-HISTORY.md`, `docs/QA-SCRIPT-NOTES.md`,
`src/combat/targeting_controller.gd`, `src/core/combat/skill_effects.gd`,
`src/core/combat/wi_combat.gd`, `src/core/effect_text.gd`,
`src/core/field_skills.gd`) — leftover from the K3 rename wave, untouched
by this session, staged separately if committed.


## M-LEGIBILITY execution log (was HANDOFF.md lines 166-217)

## M-LEGIBILITY execution log (2026-07-06 — Fable)

- **L1** fc3317e: `WIEffectText` pure formatter (items/skills/statuses, generated
  from mechanical data; forbidden-vocab grep extended). Caught: `spell_damage.effect.die`
  is VESTIGIAL (sim rolls the caster's weapon_die) — adjudication queued at L5.
- **K1 (Skills wave, early via worktree)** 33f68b1: frost/burn traversal seams —
  freezable water cells (walkable ice until sleep) in sewers + floodplains
  (frozen-pond secret cache), burnable debris nook. Seams key on data TAGS;
  K3 renames the provisional [Frost Touch]/[Kindle] to canon.
- **L2** 600b112: item cards + Krshia shop options carry generated effect lines;
  5-option stall overflow fixed grow-height. (Controller caught the K1 merge
  clobbering L2's uncommitted wi_game.gd hunk — re-applied, re-gated.)
- **Voice fix wave** e84be6d: all 8 pre-audit findings (Krshia Hrr 11→3, Zevara
  dedupe, Olesm observe de-purpled + chess unspoiled, Pisces pool fix, gnaw_pile
  "somehow"). GDI Gnoll opener untouched — ⚑ yours.
- **L3** 01f4436: journal reveal content + combat slot-info + NEW field-hotbar
  readout panel all carry generated cost/effect lines ([Power Strike] pin now
  "3 AP — ×2 damage — Everything behind one blow.").
- **L4** 75a7cde: status glossary (journal "Effects" section) + first-encounter
  status lines on the combat feed (traced: a toast would paint behind the
  readout parchment mid-combat); sim-side seen_statuses, additive save field;
  47th canonical `status_first_encounter` (real-input frost_bolt cast — autoplay
  never casts for the PC).
- **L5** 5eba49c: spell-die honesty (effect.die was vestigial — the sim rolls
  the caster's weapon_die; ice_shard/flame_scythe/calming_touch cards corrected
  to the 1d6 they actually roll), extended_sweep reach overclaim reworded,
  doubled shop price fixed (dedup suffix), forbidden-vocab sweep now recursive
  over all player-string data, combat readout wrap budget. + controller fix
  5d8f1d8: field readout hides while modal panels are open (it was covering
  Krshia's buy options).
- **LF fix wave** fc28732 (ghost-line suppression, catalog threading, doc rot,
  dash guards, message_layer teardown-race guard — the save_load_roundtrip
  flake's root cause). **M-LEGIBILITY CLOSED — READY TO SHIP** (opus
  whole-branch verdict: 0 Critical / 1 Important [the ghost skills — verdict:
  correctly made honest here, wiring is the Skills wave's charter] / 5 Minor
  [M1/M3/M4/M5 fixed at close; M2 = code-composed UI strings sit outside the
  data vocab sweep, noted-acceptable]). Playtest checklist above is live.

**HOTBAR OVERFLOW (you raised 2026-07-06) — plan amended, one ⚑ call:**
Skills-wave plan gained Task K2b (lands BEFORE K3 widens kits): a
player-managed slotted loadout — journal skills panel assigns/reorders which
known skills sit on the bars; empty loadout = AUTO (today's behavior,
byte-identical); combat keeps Attack/Dash pinned at 1/2. **Recommended over
paging** (Shift-cycled bar rows): 9 direct keys with player intent beats 18+
keys behind a mode toggle, and it doubles as build expression. ⚑ Veto point:
if you'd rather have paging (all skills always reachable, no management), or
BOTH (loadout + a page-2 spillover), say so before the Skills wave executes.
One rule choice inside the model needs your eye too: unslotted skills are NOT
usable in combat that fight (slots = the verb surface) — alternative is
"unslotted still castable via targeting menu", which weakens the choice but
never locks a tool away.

**Resolution note (2026-07-07 archive pass): this veto point was RATIFIED**
— K2b shipped as the slotted-loadout model per the Skills Wave close
(`HANDOFF.md`'s "SKILLS WAVE CLOSED" section: "K2b your slotted loadout
(AUTO byte-parity proven)"). Archived here as closed, not carried forward.


## Current State (stale M0-M4 narrative, was HANDOFF.md lines 402-411)

## Current State

- Branch: `main` (all work happens directly on `main`, no worktrees, per explicit user preference).
- **Active project: `wandering_inn_game/`** (Godot 4.7, QA-first rebuild — read its `CLAUDE.md` before working there). `wandering_inn_game_v2/` is FROZEN as reference (Godot 4.6.2 only, `/Applications/Godot4.6.app`); the abandoned v1 was removed from the working tree 2026-07-02 (recoverable from git history if ever needed).
- **M0 (agent-QA loop), M1 (tactical combat + progression), M2 (story spine), M3 (combat depth) are all complete, final-reviewed READY TO SHIP, and committed** — M2 and M3 both with zero Criticals. M3's fix wave `866a3c7` closed its final-review findings and re-verified green.
- **Human playtests DONE (2026-07-02)** — results + triage in the "Human playtest results" section below; defeat-reset bug hotfixed (`a9b4dc2`). Save/load still human-untested (discoverability blocked it).
- Overnight-run report for the user: `MORNING_SUMMARY.md` (delete after review).
- **M4 CLOSED — READY TO SHIP** (Opus final review: zero Critical, zero Important, zero fix-before-ship Minors — first fully-clean final verdict; range `feecf4f..594fb48`). All carried Minors triaged to M5. Playtest checklist below is the next gate.
- **M4 tasks 1–11 ALL COMPLETE + review-approved** (spec `304bfc9` [D] calls still awaiting user skim; plan `d43ea9d`). Delivered: dialogue gating split + per-node ctx refresh + hubs, dirty-table cleaning rewire, defeat_reload QA (seed 1) + discoverability hint, affordability greying, sprite registry + curated assets + 1024×640 + 64px cells, tile codegen (3 biomes), field sprites w/ NPC tints, combat PC sprite + cast flashes, paced skippable AI playback (enqueue-time state capture), layout pass + outlined labels + journal/pause backdrops. **Remaining: Opus whole-branch final review + fix wave.** Deferred to M5+: action-driven classes (M6 per roadmap), sprite sourcing decision (goblins/spider/Relc/VFX — parked in spec §0), PC outfit layer. Living roadmap: `docs/ROADMAP.md` (4 open user questions). M5 seed: `docs/superpowers/specs/2026-07-02-m5-demo-feel-seed.md` (4 open user questions).


## R6-STATE — public-push day, self-marked superseded (was HANDOFF.md lines 494-519)

**R6 STATE (2026-07-05 night): PUBLIC EXPORT READY — push is your move.** *(superseded above)*
The curated fresh-history tree is at `../wandering-inn-rpg-public`
(commit one = 4f374f2; 600 files, 64MB; zero manifest leaks, secrets
scan clean, boots headless with fallback art). Gates resolved this
session: pirateaba policy CHECKED (fetch-verified: credit +
non-commercial + never-claim-official; README now says unendorsed
explicitly); user blanket-attested all non-Pixel-Crawler packs —
xDeviruchi + Minifantasy stay EXCLUDED anyway (audit holds their
explicit no-redistribution text; conservative wins). Workflows now
verify the engine against the official SHA512-SUMS at run time (no
placeholder hashes); butler pinned 15.27.0. Wasm artifact re-proven
(export → headless Chromium green). **Your 3 commands:**
```sh
cd ../wandering-inn-rpg-public
gh repo create GabrielGLevine/wandering-inn-rpg --private --source=. --push
# then on github.com: Settings→Secrets: ANTHROPIC_API_KEY (triage),
#   PRIVATE_ASSETS_TOKEN + BUTLER_API_KEY (release); tag protection v*;
#   flip to PUBLIC whenever you're satisfied.
```
First push fires ci.yml (full QA gate on the runner — its first real
run; PIN-ME risk is gone but watch it). Deploy = push a v0.1.0 tag
AFTER creating the itch project + adding BUTLER_API_KEY + filling
ITCH_TARGET/PRIVATE_ASSETS_REPO placeholders in release.yml (or ask a
session to). Re-sync the export after new work: re-run
`scripts/prepare_public_export.sh` (it rebuilds; history stays fresh
until first push — after that, sync = a task for a session).

## Milestones detail M0-M3 (was HANDOFF.md lines 579-592)

## Milestones (details: specs/plans in `docs/superpowers/`, ledger `.superpowers/sdd/progress.md`)

**M0 — Agent-QA foundation (READY TO SHIP).** Pure sim core (`WIGame`), ObservableBus JSONL event log, TestDriver declarative JSON playtests with injected input + screenshots agents read, load gate (needs `can_instantiate()` — Godot 4.7 `load()` returns non-null uncompilable scripts), fully-headless web QA loop (Playwright + wasm). The BRIEFING-era claim "agents cannot playtest" is dead; human playtests are the feel gate, not the correctness gate.

**M1 — Tactical combat + progression (READY TO SHIP; playtest-confirmed by user).** `WICombat` pure sim (12×8, 4 AP, initiative, riposte/momentum reactions, seeded), BFS combat AI, balance harness, `classes.json` sleep-beat leveling (canon), menu combat screen. Final review caught a Critical no per-task pass saw: turn-1 AI double-fire stealing the human's turn (QA autoplay masked it) — recurring lesson: **bugs that only manifest for HUMAN input hide behind autoplay; the whole-branch review on a capable model is what catches them; keep it mandatory.**

**M2 — Story spine (READY TO SHIP, zero Critical).** Multi-map world (Inn + Liscor street, doors), `WIDialogue` (possession-gated visible skill checks, `hide_when` retirement), counter-derived quests + journal (J), `WISave` versioned save/load (autosave + manual via Esc), "The Errand" (fight OR intimidate, keep-or-return reward, two epilogues, defer supported). Harness caught reward re-collection + a deliver-exit softlock in authored content pre-human.

**M3 — Combat depth (READY TO SHIP, zero Critical; spec/plan were DELEGATED — flagged for user review, [D] marks the calls).** Movement economy (3 free steps + Dash 1 AP→+3; slowed −2 min 1), supercover LoS + cardinal line spells with real friendly fire (AI fires only ally-free ≥2-enemy lines; player UI previews allies greyed), MP pool + EARNED [Mage] multiclass (Dusty Scroll → `used_magic` → granted at sleep; kit: [Frost Bolt] slow / [Flame Jet] line / [Mana Shield] 1:1 absorb / [Quick Cast] first-spell −1 AP), Cave Spider + Goblin Chieftain + `cave_mouth` arena + `chieftains_raid` encounter, 400-fight rebalance (win 0.61–0.91, medians 4; thin 0.61 cell deliberate — the hard fight wants the mage kit), QA since-marker + 2 new scripts + web seed threading. Fix wave `866a3c7`: range-filtered spell targeting (out-of-range confirm was a silent no-op — human-input-only bug again), `action_refused` feed lines, `check_class_gains` empty-requirements guard, harness exit code, pinned movement constants.

**Balance caveat (final-review note):** the sim matrix never exercises PC *active* casts (autoplay PC is melee-profile) — the mage build's +0.26 win rate is entirely [Mana Shield] passive. Active spell feel is exactly what the human playtest measures.

**Deferred minors parked for M4:** enemy name labels overlap the action menu when enemies spawn at x≥9 (`qa_output/mage_unlock_loop/03_mage_kit_combat.png`); epilogue spoiler surface in dialogue data; M2 final-review minor list in ledger.


## M4 through Human-playtest-results-2026-07-02 (was HANDOFF.md lines 593-1113)

Everything from M4 status through the 2026-07-02 human playtest results —
M4, M5 (both playtest waves), M6 (status/night-summary/playtest-results),
M-FP (Floodplains integration, full execution log + its own playtest
checklist + user questions, all superseded — held-key movement shipped,
the goblin_parley gate question was answered, the Helper name question
is carried forward live in HANDOFF's M-RELEASE section), MORNING
DECISIONS, M-RELEASE SEEDED (superseded by the OPENED-CONCURRENTLY
section kept live), M-BEAUTY CLOSED, the field held-key movement
directive (shipped, confirmed in `world.gd`), M7 playtest/M7
weapons+equipment closure, the M7 night-run prep note, M6.5 CLOSED,
the M-FP+slice playtest triage / playtest-content slice, the second
user session and M7 brainstorm resolutions, and the M4/M4.1 and
2026-07-02 human playtest results.

## M4 status (2026-07-02, end of task execution)

**All 11 tasks complete and per-task-review approved** (T1–T5 playtest fixes, T6–T9 art
pipeline, T10 paced playback, T11 layout/docs — ledger has commit ranges + fix waves).
Remaining gate: Opus whole-branch final review + fix wave. Screenshot baselines were
recaptured post-art — **do not diff new screenshots against pre-M4 PNGs.**

## M5 mid-milestone playtest (2026-07-02 late night) — user played worktree @ 3cd292e

**Confirmed good:** movement smoothness, combat enemy visuals + attack animations,
music selection/ambiance per map. User saw assorted bugs but explicitly deferred them
(mid-milestone, work in flight) — F1 audit + final review + next playtest catch those.

**Triage:**
- **Window scaling BUG → FIXED (0136bcd):** viewport stayed fixed when window grew,
  cropped when it shrank. Cause: `window/stretch/scale_mode="integer"` (only rescales
  at whole multiples — needs 2560×1440 before 2×). Now fractional canvas_items stretch
  (default aspect=keep): fills any window size incl. fullscreen. Trade-off: slight
  non-integer pixel unevenness. NOT playtest-verified at fullscreen yet — checklist item.
- **Environment design still below bar → NEW TASK E3 (environment art pass).** User
  supplied 6 Pixel Crawler showcase scenes as the expectation bar. Gap analysis: we only
  ever extracted the OLD free pack; "Free Pack 2.1" (tavern mockups, Interior_Props,
  Furniture, Meat/food, buildings w/ shadows, trees ×3 models, vegetation, farm) plus
  dedicated Cave pack Props sheet sit unused in potential_assets. Engine gap: `walls`
  renderer only paints a band above row 0 — no interior partitions, so no room
  segmentation (kitchen/bar/bedrooms in the tavern showcase). Spec addendum: immersion
  design doc §6.
- **Street music possible looping issue** (user unsure) → F1 checklist: verify street
  track `loop_offset_sec` + seam by ear in windowed run.

## M5 late-session status (2026-07-03)

H1 hotbar + H2 movement-first input + H3 Tiny Swords UI chrome: COMPLETE,
merged, per-task reviews clean (H1 MEETS SPEC+fix aab6914; H2 PASS/Approved;
H3 review in flight at writing). E3 environment pass COMPLETE (scene work):
inn 16x10 w/ 4-side walls-v2 perimeter + zoned floors + kitchen/bar/dining
dressing; street cobble road + facades + market + trees + seeded scatter;
cave arena mushroom rim. Window-fill fixed (fractional stretch). Music loop
seams fixed (loopable edits re-loop from 0; title_theme custom cut = ear
check). Consultant ARCHITECTURE REVIEW triaged: cheap wins (class_name/
injection, WIDataRegistry, WIEvents consts) queued as task; decomposition of
combat_screen/world (findings 1/4/5) deliberately deferred to post-M6 task
(M6 plan is locked against current layout); finding 6 folded into H3 (done).
**M5 CLOSED — READY TO SHIP** (Opus final review 2026-07-03: zero Critical;
ship fix 74791f4 bumped save VERSION->2 + title Continue feedback). Arch
cheap-wins + F1 audit shipped and review-clean. Windowed baselines recaptured
14/14. Consultant Floodplains world-map design received (+ Relc road-intro
addendum) — integration is the controller lane parallel to M6. M6 T0 next.

## M6 status (2026-07-04, live — Opus controller)

Executing per plan `docs/superpowers/plans/2026-07-02-wandering-inn-m6-action-classes.md`
(spec REV 2026-07-03: additive stat_growth). COMPLETE + review-clean: T0 (caster
spike), T1 (tally+tags), T2 (counter leveling + save v2→v3), T3 (evolution),
T4 (k-norm split penalty, k=1.55), T4b (additive stat_growth — T4's known-red
mage_unlock_loop seed 9 now green), T5 (consolidation), T6 (class tree + kits).
T7 (QA scripts + fixtures) DONE + REVIEW-CLEAN (`2252c4f` + fix-wave `b03bda5`;
godot-code-reviewer verdict: nothing blocking, 2 Minors fixed):
class_evolution_loop(9)/consolidation_flow(9)/save_migration(1) all green + a
`load_slot` sim fix (trial-apply-then-swap so a rejected/old-version load is a
true no-op instead of silently discarding the live game — surfaced by
save_migration, user-approved). T8 (UI: consolidation prompt + toasts + hotbar
kit) DONE + reviewed + fix-waved (`37a5881`/`0f33b79`); journal hints queued
below. T9 (fighter→warrior rename; warrior supersedes the legacy fighter base,
save remap no version bump) DONE `18845c2`. F1 (calibration + docs + seed
verification) DONE. **Opus whole-branch final review DONE** — no Critical, one
Important (Generalist grants never reached the combat kit) FIXED + QA-proven
`b8b4c75`; Minors handled/noted. **M6 IS FEATURE-COMPLETE, REVIEW-CLEAN, AND POLISH-PASSED — READY FOR THE HUMAN
PLAYTEST.** The polish/playability capstone (charter step 5) is DONE (see NIGHT
SUMMARY below). **Morning playtest blockers FIXED `e65754c` + `440a48a` (Fable):** the inn
door was a ~9×11px speck with no empty-interact feedback (now render_scale 0.5
+ shadow + "Nothing there." toast); solid-looking decor (center table, grill)
was walkable (now blocked tiles; stools stay walkable by choice). ROOT CAUSE
(second report): Body_A/Citizen_F frames carry 16px padding under the feet, so
every character drew ONE CELL above its logical cell — aligning with the door
visual put you a row off, facing wall. Fixed with measured anchors
(`anchor [0.5, 0.75]`, `440a48a`). Sim + input were verified correct throughout
— all defects were presentation/data, structurally invisible to event-asserting
QA (handover §8 lesson 1 + addendum). Retry the playtest.
Parallel controller lane: Floodplains
integration (L0 unreachable-integrated da89286; Liscor gate + Relc tutorial
adjudicated, needs writing-plans pass). Ledger: `.superpowers/sdd/progress.md`.

## NIGHT SUMMARY (autonomous run, Opus — 2026-07-04)

**Outcome: M6 (action-driven classes) is feature-complete, whole-branch
review-clean, and polish-passed — ready for your playtest.** Commit range this
night: `b3572cc..210b8a5` (16 commits). Every task ran the full machine
(implement → verify green → per-task review → fix → commit).

- **Shipped:** T7 (evolution/consolidation/migration QA + `load_slot`
  safe-reject fix) · T8 (consolidation offer prompt UI + reconstruct-on-load) ·
  T9 (fighter→warrior rename, save remap, no version bump) · F1 (calibration
  confirmed, M6 docs, seed verification, web parity) · whole-branch final review
  (one Important finding — generalist grants never reaching the combat kit —
  FIXED + QA-proven `b8b4c75`) · polish capstone (`210b8a5`).
- **Green state:** 18 canonical + `generalist_loop` QA scripts, 12/12 unit
  suites, smoke zero-warning, balance harness (14 cells in-bounds), web parity
  (combat_walkthrough). Canonical combat seeds held through the fighter→warrior
  change (outcomes byte-unchanged).
- **Polish capstone results** (full detail in the ledger): quest paths CLEAN,
  map linkage CLEAN, icons CLEAN, readability CLEAN, dialogue logic CLEAN;
  text-in-containers FIXED (long-toast clipping, `210b8a5`); one stale QA
  comment FIXED. Carried non-blocker minors: enemy-name-label overlap when 3+
  enemies cluster (M3-deferred), `liscor_gate` placeholder (Floodplains lane).
- **Next step for you:** play the M6 build (focus the checklist items under
  "M6 playtest additions" below), then answer the two decisions here. After the
  playtest, the ladder is the Floodplains integration plan (writing-plans pass)
  and the M7 content brainstorm (needs you — content taste).

## M6 PLAYTEST RESULTS (2026-07-04 morning) — triage

User played post-M6. Verdicts:
1. ✅ Rendering + door interact fixed (`e65754c`+`440a48a` confirmed in play).
2. **Hotbar lacks skill identification** — no way to tell what a symbol is or
   does. DIRECTIVE → in-flight fix (combat UI: skill name/cost/effect readout).
3. ✅ **Props-over-tiles (user-mandated, repo-wide)** — combat cover now
   renders as biome prop sprites (crate/barrel; boulder/mushroom) `bfd4e27`;
   convention recorded in the wi-art-and-sprites + wi-adding-a-scene skills.
4. Liscor street barricade can be walked around — LOGGED ONLY (encounter moves
   to Floodplains; fix belongs to that lane's plan).
5. ✅ Fullscreen fill, music seams, movement-first all positive — closed.
6. **First Goblin Ambush too hard for a tutorial fight** (multiple attempts
   needed; should be winnable first try). DIRECTIVE → in-flight data tune via
   the balance harness (note: the harness's gated cells measure warrior2;
   the actual first fight is a warrior1 PC — measure that profile explicitly).

## M-FP CLOSED (2026-07-04 — Fable): READY FOR HUMAN PLAYTEST

Range b847caa..ccd7e08, whole-branch review (opus) discharged. Its one
fix-first finding — v3 street saves softlocking on the relaid-out 32×20
street — fixed via save VERSION 4 composing migration (ccd7e08). Also
shipped in the F wave: wrapped-line panel contract (3f4c2f5), Silent
Forest floodplains music (7fe02c1). Full gate 36/36 + harness green.
**Playtest checklist below ("M-FP playtest checklist additions").**
NEXT: playtest-content slice (Three Pillars spec §4) → M6.5 → M7.

## M-FP (Floodplains integration) — execution log (2026-07-04)

Plan `docs/superpowers/plans/2026-07-04-floodplains-integration.md` (b847caa),
SDD execution, waves 1+2 FULLY review-closed: S1 sim flags (persistent +
ally_requires), P1 tutor_lines handler (+fix wave), A1/A2 assets with measured
anchors + controller-read region verdicts, C1 dummies/training_yard/tutor data,
C2 dialogue (graphs PARKED — restored in W2). Range b847caa..cfbe9d0 + a568f42
T9 save-guard bonus fix. Paused BEFORE W1 (world lane) for a new user tool.

W1 DONE `da53c60` (32×20 gate district, review-clean, region shots read).
W2 DONE `e31cb73` (THE FLIP: inn_door→floodplains, encounters migrated
byte-identical + ally_requires met_relc gate, relc/relc_spar landed, parked
graphs restored; review SPEC✅ — its one HIGH, test_sim_core relc
assumptions, fix-waved green in the same commit). **EXPECTED-RED WINDOW
LIVE: ~15 canonical scripts red until Q1 — do NOT "fix" them.**
Q1 DONE `99f4049` (quiet window closed, ZERO seed re-derivations). GATE
AUDIT: zero violations; ONE USER QUESTION below. Q2 DONE `b212bb5`
(gate_district_walkthrough + relc_tutorial, opacity/persistence teeth,
street-music assert restored). F: fix wave DONE (message panels now
budget WRAPPED LINES — evict/truncate, never widen; controller re-read
clean) + **FULL GATE GREEN 36/36** + balance harness PASS. **FINAL
REVIEW (opus) VERDICT: FIX-FIRST on one Important** — street relayout
with no save VERSION bump lets pre-M-FP v3 street saves load into the
32×20 street (13 cells now blocked, 2 hard softlocks; the v1-reject
class, invisible to fresh-save QA). Fix in flight: VERSION 4 + v3→v4
migration (street saves relocate to [1,3]). Also in flight: floodplains
music (Silent Forest — user's queued road-map pick; map was silent and
is now the marquee crossing). All other compositions traced CLEAN;
minors adjudicated ship-with-note. M-FP closes when both land.
Runway: slice → M6.5 → M7 weapons plan+execute (user-locked 2026-07-04).

**M-FP playtest checklist additions (next human playtest):**
1. Relc tutorial FEEL: talk to Relc on the floodplains road, decline once,
   re-talk, spar — do the 8 tutor beats land at the right moments? Is the
   feed readable through the whole spar (wrapped-line fix)? Does re-talk
   re-spar feel natural?
2. Gate district readability: can a stranger find Krshia's stall, the
   Guild (Selys outside), a sewer grate, the Watch guard unprompted?
3. Road pacing: inn→floodplains→Liscor walk length — does the road feel
   like a journey or a corridor? Goblin encounters on the road: fair
   ambush spots? Fighting WITHOUT Relc (before meeting him) vs WITH him —
   noticeable, fair?
4. Known cosmetics (logged, don't re-report): unclothed PC, a_hunter tint
   dark, grate/dummy stand-in art, tutor feed 4th line tight vs fold.
5. **NIGHT-COMBAT ENEMY READABILITY (M-BEAUTY final-review file):** the
   cave arena pins dark and open-air night fights are genuinely dark —
   are green goblins readable enough against it? HP bars carry position;
   judge whether sprites need a rim/emphasis treatment.

**USER QUESTION (gate audit — NOW TIME-SENSITIVE, 2026-07-05):**
goblin_parley's "Stand aside… (Warrior)" gates on class.warrior:1.
Onboarding O1's classless start makes that bypass UNREACHABLE at fresh
boot — 7 of the 19 expected-red scripts die on it. O5 will re-path
them around the spar-first prologue either way, but if you want the
gate REWORKED per your in-conversation-actions policy, deciding BEFORE
O5 runs means one re-path instead of two. Options: (a) keep the gate
(post-spar players qualify; the bypass becomes a tutorial-reward
moment), (b) rework to an in-conversation choice. Controller
recommendation: (a) — the classless start accidentally makes the gate
GOOD design (earn the intimidation).

**Resolution note (2026-07-07 archive pass): resolved.** The gate stayed
class.warrior:1-gated (option (a)) and O5 re-pathed around it — confirmed
still shipping as-is in `data/dialogue/goblin_parley.json`.

**USER QUESTION (slice T1, non-blocking):** [Helper] class name is not
attested in the local wiki-spike files (spec flagged it; fallbacks
[Worker]/[Assistant] also unattested locally). Shipped as "Helper" —
generic enough to be canon-plausible, and the fighter→warrior rename
proved id swaps are a cheap save remap if you know the true canon name.
Confirm "Helper" or name the canon class.

**Resolution note (2026-07-07 archive pass): still genuinely open** —
carried forward live in `HANDOFF.md`'s M-RELEASE section ("Standing
queue: ... [Helper] canon name ...").

TOOLING (2026-07-04): godot-ai MCP connector SANCTIONED by user for
editor-visual/level-design work (headless dev hit visual-quality ceiling).
Addon committed in-tree (addons/godot_ai + _mcp_game_helper autoload, MIT);
its presence is NO LONGER the incident flagged at A2. Headless CLI remains
the default for all verification. Policy: wi-running-the-machine +
wi-adding-a-scene + wi-verifying-changes skills.

**Archive note (2026-07-07): the godot-ai addon was removed** per the
GOAL-CHAIN "CLEANUP" milestone (chain step 2, closed 2026-07-06) — this
tooling note is historical.

## MORNING DECISIONS — RESOLVED (user, 2026-07-04)

1. **Journal retrospective hints** → SAVED FOR THE M7 BRAINSTORM (user call).
   On the M7 brainstorm agenda below. No build now; toasts cover the beat.
2. **chieftains_raid difficulty (0.61→0.75 post-warrior-rename)** → user
   delegated to F1's authority. **F1 verdict: ACCEPT 0.75 as the baseline.**
   Rationale: (a) humans play materially below the autoplay proxy — the
   tutorial fight at 0.84 proxy cost the user multiple real attempts, so 0.75
   proxy ≈ a fight that already bites in practice; (b) the mage-kit incentive
   is intact (+0.18: 0.75 melee → 0.93 with kit) — the "wants the mage kit"
   design intent survives; (c) the only chieftains_raid-only levers
   (chieftain/spider stats) would re-harden a fight no human has yet called
   too easy — premature; (d) REVISIT on the first playtest that reaches that
   fight; if it falls first-try repeatedly, nudge chieftain data toward ~0.65
   proxy. No data change shipped.

## M-RELEASE SEEDED (2026-07-05, user direction): post-Three-Pillars
milestone = packaging/deploy/open-source/community. Seed spec with the
user's input + recommendations + ⚑ user calls:
specs/2026-07-05-release-community-seed.md. KEY EARLY ITEM: the asset
audit/history-scrub question (non-redistributable extracts are in git
history — gates any public push; can run as a background task before
the milestone). Brainstorm queued for a user session.

## M-BEAUTY CLOSED (2026-07-05 — Fable): SHIP
Atmosphere systems + art direction + LABEL REMOVAL all shipped
(2f133dd..583fa1b, opus final SHIP, fix wave closed all three Minors
incl. wiring phase thresholds live). The game now has: sleep-driven
day/dusk/night grades per map, warm light anchors (campfire/hearth/
torches/grates), fireflies/glints/motes/embers, sway/shimmer/vignette,
per-arena cave darkness, a tagless world where interactables carry
their own state (dirty->clean table, lit lantern, opened chest), and
the first-pickup I-hint. 27 fresh windowed baselines at
.superpowers/sdd/beauty-baselines/. Playtest: dusk/night feel, the
tagless world, night-combat readability (checklist above).

## PLAYTEST DIRECTIVE (2026-07-05, queued): FIELD HELD-KEY MOVEMENT
Per-press movement feels stilted on big exploration maps (Floodplains,
Liscor district); combat keeps per-press (steps cost there). Ship
held-arrow continuous movement on FIELD maps only. Implementation
seam: world.gd input — on move-tween completion, poll
Input.is_action_pressed and queue the next step; injected QA presses
stay single-step (scripts untouched — verify). Slotted as a small
standalone task AFTER M-BEAUTY RF, BEFORE Onboarding O1 (the
cold-start playtest should feel right). Windowed feel check is
human-only (pacing invisible to QA — M4 T10 precedent).

**Resolution note (2026-07-07 archive pass): SHIPPED** — confirmed live
in `wandering_inn_game/src/world/world.gd` (held-arrow polling via
`Input.is_action_pressed` on move-tween completion, ~line 1221-1249).

## M7 PLAYTEST (2026-07-05): systems confirmed working; explanation gap
→ Onboarding-rev spec §9 addendum (Relc teaches equipping; every system
gets its explaining beat; INTERIM first-pickup "Press I" toast rides
M-BEAUTY R3). Progression semantics VERIFIED as-designed on request:
melee_hit = any-weapon melee (Warrior levels), weapon-tagged skill uses
= evolution fork only, spells never advance Warrior. NEXT MILESTONE
QUEUED (user go): Onboarding rev plan+execute after M-BEAUTY RF closes.

## M7 WEAPONS+EQUIPMENT CLOSED (2026-07-05 night — Fable): SHIP

All six tasks + opus final review in one night, zero fix-first
findings. Range a3a7baf..close: items/events (E1), equipment sim +
injection + save v5 + Beauty phase fold (E2), isolated-RNG loot +
containers + Relc's spear gift (E3), inventory UI on I (E4),
inventory_loop canonical QA (E5), harness loadout axis — zero tuning
(E6). Gate 45/45. MORNING_SUMMARY.md has the playtest focus (the
spear identity fork) + queued escalations (charm-as-armor lore;
standing: goblin_parley gate, [Helper] name). NEXT: M-BEAUTY
floodplains-dusk pilot (live MCP look-dev, user judging) — phase sim
already landed, pilot is pure presentation.

## NIGHT RUN QUEUED (2026-07-04, prep complete — Fable)

**Start state `7b519bb`** — fully green, playtest-relaunchable. UI wave
SHIPPED (dash Enter-confirm, journal skills-by-class panel with
first-use reveal + used_skills save field, the self-colliding
_bb_escape bug fixed in all three copies with a QA regression tooth,
M6.5 F2/F3 cleanup). ALL post-D4 playtest items closed; 29 canonical
scripts. **Night mission: M7 weapons E1→F per `NIGHT-GOAL.md`** (plan
`docs/superpowers/plans/2026-07-04-m7-weapons-equipment.md` — its
plan-time corrections override stale spec text, esp. save v5 and loot
RNG isolation). Morning: `MORNING_SUMMARY.md`. User queue unchanged:
goblin_parley warrior-gate reconfirm; [Helper] canon name.

## M6.5 CLOSED (2026-07-04 late — Fable): presentation decomposition SHIPPED

Opus final review SHIP, zero Critical/Important. combat_screen.gd
2062 → 681 lines; six focused components (shared tile builder, read
facade, board renderer, T10 playback queue, HUD, targeting) with the
command surface pinned to the composition root. Zero behavior change
proven per task (events.jsonl oracles + full sweeps); 42-item gate
green at close (`928592e`). Hotfix waves A/A2 (playtest items 1-3,
6-9, 17-interim, 18) shipped interleaved, separately reviewed.
**Safe playtest relaunch: any commit from `928592e` onward.**
IN FLIGHT NEXT: UI wave (Dash Enter-confirm, journal layout +
skills-by-class panel w/ first-use reveal, F2/F3 cleanup) → M7 weapons
plan+execute per the locked runway.

## PLAYTEST RESULTS (2026-07-04 late — M-FP + slice build) — TRIAGE

**Hotfix wave A (data/dialogue/UX feedback — dispatches the moment M6.5 D2
lands; files are D2-free but QA runs share the worktree):**
- (2/18 blocker) Stew pot reads as DEAD: `skill_unknown` on a
  requires_skill prop is INVISIBLE — no toast (violates the M6
  "every explicit action needs visible feedback" rule). Fix: feedback
  toast on the locked-prop path ("You don't know how to work this yet."
  class), opacity-safe. This also masked ALL Helper visibility (18).
- (17-lite) Dark Cellar pre-[Light]: interact → "Too dark to see
  anything." toast (data). Class-gained toast: verify it lists granted
  skills ([Light], [Frost Bolt]) — if not, include grants in the toast
  copy. Full darkness version waits for the overworld hotbar (spec'd).
- (1) Lyonette repeats her Guild pitch post-advice — missing
  post-state text_variant (same class as the Krshia variant bug;
  last-match-wins ordering).
- (3) Hungry Patron: male pronouns on a female sprite — text fix.
- (6) Relc = blue rectangle in combat — wire the relc combatant record
  to the a_hunter sprite (already VISUAL-LOG'd).
- (8+9) BALANCE TUNE, one wave, harness-validated: weaken goblin_ambush
  goblin attacks (naive dash-forward player must survive; "not
  trivially easy, requires Relc's skill advice" is the bar) AND buff
  Relc's combatant stats — a high-level [Spearmaster] must not die to
  two goblins (canon). Re-verify canonical seeds (combat data change =
  seed check per skill).

**Post-D4 UI wave (files owned by the refactor until then):**
- (15) Dash fires on selection — must require Enter confirm like other
  slots.
- (11) Journal layout issues — VISUAL-LOG + fix.
- (7) PC death while Relc lives ≠ defeat — design call CONFIRMED by
  user: PC death = immediate defeat. Sim change (defeat condition),
  small, with QA (defeat_reload variant w/ ally alive).
- **(19, user directive 2026-07-04) Journal SKILLS-BY-CLASS panel:** the
  journal lists every known [Skill] grouped by class (innate skills
  under their own heading). Canon-fashion reveal: pre-first-use a skill
  shows NAME ONLY (+ flavor line at most); the full mechanical
  description unlocks after the skill is USED once. Plan-time
  decisions: (a) first-use tracking = a `used_skills` set on WIGame
  (fires from both the exploration skill_used path AND combat
  use_skill; note trivial fights suppress TALLIES but this is a set,
  not a counter — must record even in the spar); (b) persists in saves
  — additive state field, decide additive-default vs version bump at
  plan time (v4 precedent: additive with tolerant apply is fine);
  (c) opacity intact — descriptions are static text, no numbers-toward.
  Rides WITH the journal layout fix (11), one journal window.

**Milestone-scoped — "Onboarding rev" (spec amendment being drafted):**
- (5) PC starts CLASSLESS; Relc gives the weapon; Attack-only during
  tutorial; first Warrior level at post-tutorial sleep; Goblin Ambush
  becomes tutorial part 2 (Relc explains Skills incl. [Power Strike]/
  [Piercing Strikes]).
- (4) Tutorial rev: attack prompt beat; dummies deal ZERO damage and
  don't act (no block mechanics = no reason they move); skill-explain
  beats.
- (13) Mage from a Pisces tutorial encounter, not the Dusty Scroll
  (reaffirms the 2026-07-03 standing directive; adds magic-explainer
  beat).
- (18) Helper L1 grant invisible (lesser_stamina is a passive no-op) —
  rework so L1 grants something visible/usable.
- (17-full) Pitch-black cellar + overworld-hotbar [Light] (Three
  Pillars milestone, already spec'd).

**Answers / no action:**
- (10) Goblin ambush persisting after victory is INTENTIONAL —
  `respawns: true` is the leveling volume valve (dormant until sleep,
  then re-arms). Cosmetic "dormant" visual state queued in VISUAL-LOG.
- (12) Chieftain difficulty CONFIRMED right with Warrior+Mage — closes
  the F1 "revisit at first playtest" note. No data change.
- (14) Party building — added to the standing brainstorm agenda
  (needs you; ties to ally roster machinery ally_requires started).
- (16) Liscor visuals (freestanding cellar door, roof misalignment) —
  VISUAL-LOG'd for the next art pass.

## PLAYTEST-CONTENT SLICE (2026-07-04, executing — T1/T2/T3 shipped, T4 closing)

T1 `3fa7468` ([Helper]/Barmaid/Server + service skills), T2 `7b3126d`
(inn work-loop: patron serve, laden tray, gated stew pot + work_loop QA),
T3 `a75e83d` (The Missing Crate — fight/talk/[Light] paths + 3 QA
scripts). All per-task reviews SPEC✅. T4 in flight (full gate + opus
review).

**Pillar audit (spec §5 metric — repeatable counter sources):**
- Combat: Relc spar loop (persistent), 2 respawning road encounters,
  chieftains_raid, crate fight — HEALTHY.
- Social: patron serve loop (repeatable), Krshia/sergeant talk paths,
  Erin/Lyonette/Selys graphs — HEALTHY (serve is the repeatable anchor).
- Exploration/Puzzles: cellar [Light] study, scroll, lantern, cleaning —
  THINNEST pillar: only cleaning repeats; studied_*/lantern are one-shot
  counters. ACCEPTED for the slice (Tactician milestone owns the fix);
  flagged so the Three Pillars execution weights exploration loops.

**SLICE PLAYTEST CHECKLIST (the acceptance bar, spec §4 — one session):**
1. Level warrior via the Relc spar loop AND Helper via inn chores — does
   opaque-until-sleep feel right with TWO class lines moving? (This is
   the opacity verdict we're still missing.)
2. Split penalty: with warrior+helper both leveling, does combat feel
   ~20-25% weaker than a pure run? Fair or punishing?
3. The Missing Crate three ways (three runs or saves): fight / persuade
   the sergeant / [Light] cellar study. Does each feel like a REAL
   solution, not a menu pick? Is the hidden guile option's appearance
   (after studying) a delight or confusing?
4. Work-loop feel: is chore-grinding fun-adjacent or pure gym? (Honest
   answer shapes the Three Pillars milestone.)
5. Cosmetics logged, don't re-report: stew pot blends into hearth;
   street scatter discs read as sewer grates; sergeant wears citizen
   clothes not Watch armor.

## SECOND USER SESSION (2026-07-04 evening) — content + fidelity directives

- **Three Pillars SPEC APPROVED** (interactive brainstorm):
  `docs/superpowers/specs/2026-07-04-three-pillars-world-skills-design.md`.
  User awaiting-skim; executes after M7 weapons.
- **Playtest-content slice** approved, rides immediately after M-FP F
  (content gates leveling playtests — user directive). Slice = inn
  work-loop + Relc spar leg + one 3-path gate-district quest + [Helper]
  class data. Spec §4 has the acceptance bar.
- **Runway updated:** M-FP → slice → M6.5 → M7 weapons → Three Pillars.
- **Fidelity directives standing:** `docs/VISUAL-LOG.md` (drain each
  milestone F; spell-cast-plays-sword-swing logged as the first entry);
  max-fidelity sprites always; standardized UI components; common-sense
  checks in every visual read. Skills updated (Fable).

## M7 BRAINSTORM — RESOLVED (user, 2026-07-04 morning session)
1. **Autonomous runway CONFIRMED:** M-FP (Q1/Q2/F) → M6.5 presentation
   decomposition → M7 weapons plan (from the approved spec) + execution.
   No sync points required. **Three Pillars brainstorm WAITS for the user**
   (next present-session agenda item, alongside {content arc, economy}
   sequencing).
2. **Journal "Path" section: DROPPED permanently** (user call). Journal
   stays quest-only; toasts carry the class beats.
3. **Opaque-until-sleep hint tuning: PARKED** — the M6 playtest didn't
   reach leveling, no verdict. Re-ask after the next playtest that does.
4. **M4.1 dialogue-gate policy audit: rides the Q1/Q2 window** (audit every
   dialogue gate against the in-conversation-actions rule; fix violations
   in the same wave).

Next-playtest additions: fullscreen fill verdict, music seams (street esp.),
hotbar feel w/ number keys, movement-first arrows in combat, UI chrome
readability, environment feel vs the showcase bar.
M6 playtest additions (action classes): focused-vs-split feel (does specializing
FEEL rewarded, ~20-25% friction fair?), opaque-until-sleep reactions VERBATIM
(the one user-accepted design risk — a hint-tuning pass is pre-approved as an M7
candidate if it frustrates), the evolution moment (warrior→swordsman) delight,
consolidation prompt clarity (is "A Path Converges" legible + the choice clear
without a level number?).

## M4 playtest results (2026-07-02 evening) — PRIMARY M5 INPUT

User played post-M4. Verdicts + triage:

**M4.1 hotfix wave (quick, before M5 execution):**
- **(4) Erin repeats the initial quest pitch after completion** — hub node text is
  static. Needs small engine feature (conditional node text variants gated like
  options) + content. REAL BUG.
- **(5) Dash → auto-enter Move mode** (selecting Move again after Dash is clunky). Trivial UI fix. *(Superseded by M5 H2: Move mode is deleted entirely — arrows move directly, Dash just refills the pool.)*
- **(3) Lyonette's Fighter-2 gate feels arbitrary** — user policy: dialogue gates
  should key off actions IN conversation, not class/question-progression. Rework that
  option's gating (e.g. unlock via a prior conversational choice); audit other gates
  against this policy.

**M5 core scope (design-level, playtest-driven):**
- **(1) Game must FILL the window** — upper-left parking with UI parked beside/below
  is wrong; UI should overlay the world view.
- **(2) 16px-native rendering recalibration** — Pixel Crawler is a 16×16 aesthetic;
  current 64px-cell scaling makes movement jumpy. Low-res viewport + integer scale +
  smooth tweened movement.
- **(6) Main menu + quit-to-menu** — save/load STILL undiscoverable without it;
  needed to actually test save/autosave. (Shell lane, now with hard requirement.)
- **(7, user suggestion) Combat hotbar** — icon-based skill/ability selector along
  the bottom of the screen instead of the text menu.

**Next human playtest checklist (feel gate — after M5):**
1. **Paced AI turns** (QA cannot verify pacing — zero-delay by design): units move
   cell-by-cell per beat (no teleport), HP/MP bars tick per beat, ~0.5s cadence feels
   right, confirm/cancel skips playback instantly.
2. **Save/load discoverability retest** (carried from last playtest): footer hint +
   first-autosave toast — can you find save/load unprompted now? Then actually exercise
   save→load (still human-untested).
3. **Dialogue**: hubs ("Actually - one more thing."), progress-gated options invisible
   (no grey "requires more progress" rows), decided options gone, [Basic Cleaning] via
   the Dirty Table prop then reporting back to Erin.
4. **Art**: inn/street/cave tiles, NPC tints (Erin plain / Lyonette magenta / Selys
   green — distinct enough?), PC sprite field+combat (NOTE: PC is the unclothed Body_A
   base — outfit layer queued for M5), props (bed/table/door/tome), enemy chips w/
   outlined labels, cast flashes (frost blue / flame orange / shield blue).
5. **Defeat**: lose the chieftain fight on purpose — banner → reload at last autosave.
6. Chieftain difficulty gut-check still right post-art (no combat data changed in M4).
7. **Movement-first combat input (M5 H2)**: on your turn, arrows move the unit
   DIRECTLY (no Move slot/mode); number keys activate slots (1 Attack, 2 Dash,
   3+ skills), E ends turn; Dash only refills steps (keep walking right after).
   Feel questions: does direct movement + number keys read naturally mid-fight?
   Is the sprite bump + readout hint enough feedback when you're out of steps?

## Human playtest results (2026-07-02) — PRIMARY M4 INPUT (all items below now addressed in M4 except where noted)

User played both queued playtests. Difficulty verdict: **Goblin Chieftain fight is the right hard** (failed first attempt, won second) — keep the 0.61 balance cell. Findings, triaged:

**Fixed immediately (hotfix `a9b4dc2`):**
1. **Defeat wiped the run to a fresh game instead of restoring the sleep autosave** (`_close_banner` called `Game.reset()` unconditionally). Now loads the `auto` slot, resets only if none exists. No QA script exercises defeat yet — **M4: add a `defeat_reload` QA script** (needs a forced-loss setup; autoplay always plays winning seeds).

**Real bugs / design changes for M4 (user directives, not suggestions):**
2. **[Basic Cleaning] auto-completes** — Erin's dialogue option grants `cleaned_the_inn` inline and jumps straight to the congratulation node (`data/dialogue/erin_errand.json`, hub option 2); the Dirty Table prop is never involved. Fix: option should only direct the player; the accomplishment must come from interacting with the prop (same pattern as the Dusty Scroll).
3. **Gating-visibility policy (user decision):** quest/accomplishment-gated dialogue options must be HIDDEN until requirements are met — greyed "(requires progress)" rows are debug UI, not player UI. Skill/class/level-gated options MAY stay visible-locked (the tease is good). `WIDialogue.visible_options` needs to split `requires` handling by requirement type.
4. **Decision-invalidated options must disappear, not grey out** (e.g. Erin's two quest responses after you've committed) — extend the `hide_when` pattern over the M2 graphs.
5. **AI turns resolve invisibly** — combat jumps from end of player turn to start of next player turn; enemy/ally actions happen with no visible pacing. M4: paced turn playback (step/animate AI actions so the player sees what happened). Biggest combat-presentation item.
6. **Combat menu rows should grey when unaffordable** — Dash and skills already grey; Attack (2 AP) and Move (empty pool + no AP) don't.
7. **Text overlap everywhere** (user has been ignoring it pre-polish; includes the known enemy-label/menu overlap) — M4 UI/layout pass.
8. **Save/load discoverability**: user couldn't find it (Esc pause menu is unexplained) — surface it (hint/menu). **Save/load remains human-untested** — carry to next playtest after discoverability fix.
9. **Dialogue backtracking hubs missing** (user expected from M2): no "I have more questions" loop-back pattern — conversations are one-shot trees. `WIDialogue` supports `goto` loops already, so this is mostly graph authoring + one engine caveat: `ctx` is snapshotted at `start_dialogue`, so requirement gating inside a hub loop won't refresh mid-conversation (documented staleness — M4 must decide: refresh ctx per node, or author hubs to avoid mid-loop gating).

**Explained, deprioritized by user:**
10. "Shot through Relc" with no friendly fire — that was [Frost Bolt] (single-target `spell_damage`): combatants don't block LoS by design, only walls do. [Flame Jet] (`line_damage`) is the friendly-fire skill. Not a bug; the line preview already greys allies. Consider a one-line doc/tutorial hint eventually; user says low priority.


## Autonomy directive, 2026-07-02 (was HANDOFF.md lines 1135-1140)

## Autonomy directive (user, 2026-07-02 evening)
User most likely UNAVAILABLE for a post-M5 playtest — after M5's final review closes,
move DIRECTLY into M6 execution autonomously (spec/plan/approvals all in place). All
M5 playtest items queue in a single combined checklist for whenever the user returns.
Immersion mandate: environments/UI must feel immersive, not functional — design doc
2026-07-02-environment-ui-immersion-design.md governs R4/H briefs.
