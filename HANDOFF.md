# Wandering Inn RPG Handoff

Live current-state doc. Per-issue narrative lives in merged PR bodies
(`gh pr list --state merged`); adjudications in CHOICE-LOG; build
history in git. Read order for a fresh session: wi-start-here.

## PAUSED (2026-08-04): v0.19 playtest feedback — 14 findings, 1 BLOCKER class, handed off

**State:** PR #394 open (branch `v0.19-wave-2`, 61 commits), **CI 7/7 green**.
`v0.19.0` tagged LOCALLY ONLY — deliberately not pushed, so Release/Pages do
not fire. Working tree clean. DO NOT MERGE #394 until the blocker below is
resolved.

### PROCESS FAILURE, mine, read this first
I ran a windowed capture in a detached worktree at `180ebbce` WITHOUT the
private asset overlay. That violates the iron rule in wi-machine-playtest
("windowed verification ALWAYS runs on the real asset overlay"). The specific
conclusion I drew from it survives — I compared TEXT ROW GEOMETRY (option
positions, exit-row y), which is UI and unaffected by world art, and the rows
matched to the pixel — but **do not trust that frame for any FEEL judgment**,
and re-run it properly with the overlay before relying on it.

### THE BLOCKER (user finding 11 + 13): shop dialogue traps the player
Krshia (`krshia_crate`) and the street Peddler (`peddler_stall`) — the game's
only `requires: {gold:}` shop hubs. User reports a huge panel with no way out;
had to quit the program.

**Verified by me:**
- The shop panel is UNBOUNDED and does not scroll. On the charms sub-menu (8
  options with effect sub-lines) the EXIT row "Back to the regular stall" lands
  at y=662 of a 720px viewport, already clipped by the input-hint bar. One more
  option or effect line and the only exit is off-screen.
- **This PREDATES v0.19.** Reproduced identically at `180ebbce`. My autowrap
  change is NOT the cause — removing it does not fix it.
- I could NOT reproduce a fully EMPTY panel. Mine renders text. The user's
  "empty" needs their state or a screenshot — that may be a second, distinct
  defect. ASK BEFORE ASSUMING it is the same bug.
- I did not finish checking whether `cancel`/Esc has ANY path out of a dialogue
  hub (`dialogue_panel.gd:444` handles cancel only for the PICKER). If Esc
  cannot close a conversation, that is the actual trap and the real fix.

**Why every gate missed it — three independent holes:**
1. `d2_shop_shot`, the ONE script whose whole purpose is the shop panel
   screenshot, is **NOT in `ci_sweep`'s canonical list** (grep count 0). It has
   been failing since at least `180ebbce` and nothing reported it.
2. The scripts that DO cover `krshia_crate` assert EVENT payloads — option
   text, locked, requirement — all of which are correct. Event-level QA is
   structurally blind to "the panel is taller than the screen".
3. My machine-playtest rotation did not include a shop. The protocol says
   rotate the subset; I picked combat/inn/street/martial/panels and no vendor.

### The other 13, triaged (NOT yet investigated unless noted)
- **(3) Martial skills have no hotbar icons — user calls it non-shippable.** Highest
  priority after the blocker. Likely missing `icon` ids on the five new skills.
- **(1)/(5) [Ice Floor] and [Snap Freeze] refuse at the pond/channel** ("no
  standing water" / "nothing here to grip") — the wave's marquee feature not
  working in play. Suspect the faced-cell freezable lookup vs where the player
  actually stands. THIS IS THE THESIS FEATURE; treat as near-blocker.
- **(6) Enemy health numbers show through the pause menu.** I looked at
  `01_pause_over_combat.png` and judged it acceptable; the user disagrees on
  their screen. The scrim alpha 0.55 was my invented value — raise it, or the
  combat HUD needs to hide under pause rather than be dimmed.
- **(2) Corusdeer healthy/injured/dead differ only by TINT** — direct violation
  of the tint-is-not-disambiguation directive. Needs distinct art per state.
- **(14) `martial_field_armed` has no cooking skills** — my prepared playtest
  state is wrong for the #391 read. Fixture fix.
- **(12) Pisces idle reads as walking in place** — my v3 "breathing idle"
  generation drifts the legs. Regenerate with a stiller prompt.
- **(10) "Octavia is black?"** — check the generated rig's palette against the
  Stitch-girl profile; may be a bad generation or a tint left on the row.
- **(4) "What is the scree chute? The cairn on a hill?"** — the [Even Footing]
  placement does not read as a crossable slope. Dressing problem.
- **(7) Flame Jet destroys the sodden timber but the point is unclear** — the
  yield/consequence is not legible.
- **(9) Yellow menu text on light toast background is hard to read** — contrast.
- **(8) Sleep prompt copy lacks flavor.**
- **(13) "Who is the male vendor supposed to be?"** — `peddler`, sprite
  `hired_blade`; it is a shared/undistinguished rig and the name says nothing.

### Suggested order for whoever picks this up
1. Reproduce finding 11 WITH the overlay and get the user's exact state.
2. Answer: can Esc leave a dialogue? If not, that is the fix and it is small.
3. Cap the dialogue panel height + scroll or paginate options so the exit row
   is ALWAYS reachable. Add `d2_shop_shot` to `ci_sweep` and repair its stale
   pins so this can never rot again.
4. Then finding 3 (icons), then 1/5 (the freeze verbs).

## DONE (2026-08-04): v0.19 (wave-2) — "the world answers the hand" — SHIPPED

**Tagged v0.19.0.** 19 of 20 issues closed; #348 stays open by design (its
close condition is the K5 discovery playtest, below). #390 filed for the
#385 Tier 2/3 art carry. v0.20 milestone now holds #371, #388, #390.

Thesis: every verb the player aims at the world lands on something real and
visibly resolves. Built forward (property layer #387, martial verbs
#380-#383, feedback tells #335) and repaired backward (the eight blind-
playtest findings #372-#379, each the same defect stated differently).

Planning: two Fable passes (spec audit of all 22 issues + holistic shape),
reconciled in `docs/superpowers/plans/2026-08-04-v019-wave2-plan.md`. Each
issue carries its audit as a GitHub comment; **where audit and issue body
disagree, the audit wins.** 14 rulings in the CHOICE-LOG close block.

**Structure that worked: phase 0 landed EVERY `src/core` edit first**, in two
disjoint worktrees, so phase 1 could fan six lanes wide over pure
data/copy/UI/art. Eight lane merges, ZERO conflicts. Repeat this shape.

**Structure that leaked: cross-lane handoffs.** Three defects were each a
handoff where both lanes did their own half correctly and nobody closed the
seam — the ice tile shipped dead (L4 made it, L5 owned the wiring), the
kitchen tint survived (L3 held it for L4's sprites, which landed), and
`journal_categories` went unpinned when L2's data changed a script L5 owned.
The train caught all three, by luck as much as design. **Next wave: name the
counterpart lane in each brief and make handoff-closure an explicit train
step.**

**Dual adversarial review is load-bearing, not ceremony.** Lanes reported
fully green (33/33 units, 205/205 canonicals) and reviewers still found: a
`state_set` that was not actually permanent (its one-way guard read
`entity_first_use`, which `sleep()` clears, so an already-set carrier replayed
first-time copy and re-banked a SAVE-PERSISTED counter once per sleep,
unbounded); a `thaw_cell` leaving ice painted over open water; a ward grace
that overwrote a player's paid-for [Hearthward] charm; consolidation going
mouse-dead at 5+ field slots; and the Serve `source_hint` clipping at both
accessibility text scales. **Every BLOCK came from a different lens** — single-
lens review would have missed one.

**Open for you:**
1. **[Rope Work]** — the invented name is the one item still wanting an ACK.
   Pinned by id, so a rename is a one-string diff.
2. **PixelLab top-up** — $1.53 and 0 subscription generations. Six bespoke rig
   rows are carried unfunded (#390). Money is yours to decide.
3. **K5 discovery playtest** — the post-tag event that closes #348 and decides
   slice 3. A stranger plays; the question is whether they FIND the property
   layer without being told.
4. Standing: [Perfect Reduction] fence-vs-grant, Raskghar ear-gate, #253.

## DONE (2026-08-04): dialogue voice pass — SHIPPED via `voice-pass` branch PR
All 71 dialogue files de-AI'd per the 2026-08-03 critique. Six waves
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
User directive: get the martial work on the board so it isn't lost.
Found: the martial exploration [Skills] doc was tracked in NO issue —
design doc + CHOICE-LOG rulings + morning-queue item only, invisible to
`gh issue list`, and the largest unscheduled body of work on the project.
Picks MADE under wave-autonomy (all revocable, rationale in CHOICE-LOG
"2026-08-04 — board hygiene"): **#380** wave-1 = [Even Footing],
[Greater Strength], [Broader Shoulders], [Durable Picks], [Bar Fighting]
+ the [Ice Floor] grant (four data-only; Even Footing is one passive
cell-class read; pairs with Ice Floor deliberately — mage makes the ice,
martial crosses it). Split on distinct blockers: **#381** [Basic Repair]
(needs #348 slice 2), **#382** [Rope Work] (INVENTED name, only item
still wanting a user ACK), **#383** [Flame Jet]→corpse (four-part
package; yield can't be a table row per spec §6). Tier C stays behind
#335, unchanged. Closes v018-close rulings #8 and #9.
**#384** files three v0.18-close items that were deferred "to the board"
and never actually filed: #360 extreme-flip triage, ai_kit-stratified
parity envelope (until it exists there is NO class-balance gate, only
monotonicity), W3 acts.json row.
Morning-queue item 1 struck through — it no longer blocks.
TRAP for anyone reading the martial doc: cite skills by NAME. Its `#N`
row numbers drift between its own sections AND read as GitHub issue refs
without being them (doc "#19 [Detect Flaw]" is not GH#19). Only #348 and
#335 in that doc are real issue numbers.
PROCESS: "deferred to the board" is not a filing. Two waves produced six
such items and zero issues. A close isn't done until every DEFERRED/board
line in its adjudication block has an issue number beside it.

### Blind machine-playtest triage (2026-08-03) — #373-#379 filed, user takes next wave
Four blind browser-agent reports (v0.16.1, 2026-08-02 + three legs
2026-08-03). Every claim re-verified against HEAD before filing; the
already-fixed and the agent-artifact halves were dropped, not filed.
**#373 (blocker, S, successor-ready)** — combat's empty-target mode is
sticky: `_input_target` (combat_screen.gd:1017-1032) swallows movement
actions and `targeting_controller.enter()` never auto-cancels on an empty
candidate list, so Attack-with-no-target parks the player in a modal state
that eats every key but Esc. ONE bug behind both reported symptoms
("movement fails silently" + "no target in reach"); ~8 repros across three
sessions; the agent's zone-of-control theory is wrong.
**#374 (bug, S, successor-ready — REWRITTEN 2026-08-03 on user ruling)** —
the ambush gating Liscor is INTENDED; the original gate-geometry framing
was wrong and is withdrawn. Real defect: Continue-after-Defeat restores
the `auto_pre_combat` slot written at COMBAT_STARTED (game.gd:82-86 →
combat_screen.gd:946), which is BY CONSTRUCTION a cell inside the
encounter's trigger radius — so the next step re-fires the fight you just
lost. Also explains the "respawn moves between deaths" report (the slot is
rewritten per fight; deterministic, but unnamed). Fix seam:
`warded_encounters` (wi_game.gd:72, checked :368) gains an exit-clearing
entry on defeat load — wake where you fell, encounter stays live, walking
away works first try. Lands WITH #372 (copy half of the same beat).
**#375 (S)** —
`inn_sign` at [6,6] blocks a third of the GH#185-widened facade; move to
[5,6]. Carries a stale-comment one-liner (world.gd:148 claims
clamped-follow is unexercised; floodplains 40x26 exercises it).
**#376 (art)** — `your_bed` and `inn_chest` read as each other; BOTH
playtests made the identical inversion, and v0.17's relc_spar toast now
points at "bed" explicitly. Directive case: tint-is-not-disambiguation.
**#377 (S)** — pause_menu builds no scrim; combat HP text bleeds through
"Abandon to Last Save". **#378 (M)** — seven Serve options gate on
`hot_meal`, whose only producer needs `basic_cooking`; same issue carries
the three-cauldrons-one-silhouette tint debt the entity comment admits.
**#379 (S, copy)** — Resonance is shipped/save-persisted/sleep-grown and
explained nowhere; open question in all four reports.
Already fixed, do NOT re-open: save-less Continue (greyed), sleep-is-the-verb
signposting (relc_spar toast), journal scroll (#216 slice 2), unlabelled
creation cards (deliberate, hotfix #3), single-tile inn door (GH#185).
Agent artifacts, discounted with evidence: missable toasts (`_toast_seconds`
scales; 0.4s cap is QA-mode only), "attack only works orthogonally"
(`is_adjacent` is Chebyshev, diagonals included), walked-off-screen past the
map edge (camera clamp is correct; the agent admits it could not identify
its own sprite).

## Current state (2026-08-03, overnight session close — v0.17.0 SHIPPED, v0.18.0 closing)
**v0.17.0 TAGGED + Release/Pages GREEN. v0.18 wave-1 train COMPLETE
(#364-#368, five lanes, 20 agents, dual adversarial lenses), close in
flight (freeze 12 adds/0 removals, CHOICE-LOG 12-ruling block, focused
playtest running, tag v0.18.0 per ruling #12).**
v0.18 wave-1 content: #348 slice-1 substrate (proven byte-identical
inert; ice-floor works as pure data; Flame-Jet corpse deferred to the
skill-picks package), #347 prototype behind flag (demo state for the
naming read), #318 nobility thread (Magnolia felt-never-seen,
spec-first, "Five Families" REFUSED on spoiler grounds), the whole
playtest hotfix head + #359 looping clock (first waking byte-identical),
Wave-D Alchemist+Druid (Priest parked) + rung-4 restored (4-step ladder
0.92>0.84>0.69>0.61) + #360 harnesses (difficulty tiers monotone clean
0/141; parity measured, envelope deliberately unratified on the ai_kit
confound).
**MORNING QUEUE: wandering_inn_game/qa/playtest_saves/2026-08-03-v018-morning/README.md
— one doc, six items, load lines included** (martial picks, [Perfect
Reduction] fence-vs-grant, bestowal naming/rarity, moods eye-items,
new classes in play, lease gate). Wave-2 shape follows the picks.
Incidents this session (all gate-caught, all logged): core-purity seam
reversal, hook-BLOCK-swallowed recurrence, import-rule x3 (now covers
image assets + train pulls).

Process lessons this session (fold candidates for wi-running-the-machine
/ wi-verifying-changes / wi-machine-playtest):
1. Pre-commit hook BLOCK swallowed by `tail -1` — three commits
   silently never happened; branch pushed a stale head. Read commit
   success from rc + `git log`, never hook chatter.
2. Composed census ceiling bit AGAIN (15.0% exact, ~70 chars over
   after merge): comment-trim is the cure; census slack belongs in the
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
1. **MORNING QUEUE — the six-item README above.** Wave-2 dispatches
   after the picks (skill package: martial picks + ice_floor + the
   Flame-Jet corpse arm + [Perfect Reduction] ruling + bestowal
   direction + remaining W4 debt incl. Pisces re-window).
2. Board: #348 open (slice 2+), #347 open (migration behind rulings),
   #360 open (flip-gate triage + stratified envelope), #359/#134/#318
   close via the train PRs.


## 🧑‍⚖️ TASTE QUEUE (user-held, in rough value order)

- **⭐ WAVE-2 EAR/EYE GATES (land with the wave close)**: (1) Raskghar
  fight music swap — profiled HydroGene winner wired, ear-gate state
  ships; THIRD strike if it reads wrong, say the word and the runner-up
  wires (#200 history). (2) RESOLVED 2026-08-02: user reversed —
  Pisces IS a Horn (#349, v0.17); he still starts in Liscor
  independent. (3) Hero-art
  shipped in #344 with controller reads — eye-gate only if something
  reads wrong in play.

- **⭐ THE FULL SITTING — 14 states + 1 paper read, ~1hr** (v0.16 bundle +
  v0.15 carryover + organic Riverfarm run, ALL in
  qa/playtest_saves/2026-07-28-v016-bundle/README.md — one doc, load
  lines included). Supersedes the separate v0.15 bundle entry below.
  Original v0.16 detail: (states
  named in docs/VISUAL-LOG.md close section): (1) the goblin-ally fight —
  the wave's marquee moment; does fighting BESIDE Rags land? (2) the
  witch-hut door post-fix at dusk — readable enough, or does the hut want
  bespoke art (it is currently a freestanding frame)? (3) the Lady's
  three-node arc — does the nobility register read as intended? (4) den
  shop warmth vs the tier's stone (the region's counterweight room). (5)
  line_stalker pair overlap — creature or two-headed bug? (6) GOSSIP
  LADDERS (adjudication ask, balance-bound): heard_gossip ceiling 39→48
  while [Diplomat]/[Innkeeper] rungs stand still — recommend scaling
  gossip rungs with the talkable census (or scoping the pace claim);
  numbers in CHOICE-LOG close block. (7) quest payoff toasts (#325) —
  ship the hotfix now or bundle to v0.17?

- **⭐ THE v0.15 PLAYTEST-STATE BUNDLE — six asks, one sitting.** Top of
  docs/VISUAL-LOG.md's Open list, each with a prepared-state name and a
  load/do/judge line: (1) camouflage tints; (2) Ruin Warden at 3.51 cells;
  (3) toast over an open journal; (4) `pallass_market`/`pallass_forge`
  lights by day; (5) Grimalkin in the inn (measurement refuted the scale
  claim — lever is seat or art); (6) the finale's paced lines (the one ask
  no agent can answer).
- **#195 Ove Melaa audio listen** (~30 files) → wiring pass after.
- **#211 challenge-weighted leveling FEEL** (shipped flag-on; knobs data).
- **3 Rags reads** (b1 content: meeting/mercy/betrayal voice).
- Standing visual asks: vault-fight windup overlay (brightened ~2.5x, no
  in-fight windowed read); rock-crab relc_downed band 0.62 vs infeasible
  ~0.5 (frontier in the combatant _comment).
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
  `/Applications/Godot4.6.app` for the frozen v2 only.
- PixelLab via the `pixellab` MCP server (pipeline + traps in
  wi-art-and-sprites); ~$2.7 overage credits as of 2026-07-20.
- Web QA deps installed (export templates 4.7, Playwright chromium,
  qa/web/node_modules). `potential_assets/` is gitignored — never
  commit it.
- **Windowed-exit flake**: ~1/3 windowed runs print an ObjectDB leak
  notice AFTER `QA_RESULT: PASS` (audio teardown race, pre-existing,
  never headless, results unaffected) — do not re-diagnose. Godot 4.7
  also rarely SIGABRTs at shutdown (cosmetic; if phantom FAILs appear
  with clean QA_RESULT lines, suspect exit-134 first).
- macOS: no `timeout` (use `perl -e 'alarm N; exec @ARGV'`); bash 3.2
  (no mapfile; `${ARR[@]+"${ARR[@]}"}` for empty arrays under set -u);
  zsh does not word-split unquoted vars.

*(Older narrative — closed milestones, the 2026-07 wave logs, and the
numbered adjudication ledger through v0.13.0 — lives in this file's git
history and the merged PR bodies; pre-2026-07-05 material in the frozen
archive repo at docs/archive/HANDOFF-archive-2026-07.md.)*
