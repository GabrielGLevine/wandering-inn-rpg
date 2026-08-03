# Wandering Inn RPG Handoff

Live current-state doc. Per-issue narrative lives in merged PR bodies
(`gh pr list --state merged`); adjudications in CHOICE-LOG; build
history in git. Read order for a fresh session: wi-start-here.

## Current state (2026-08-02, session close)
**v0.16.2 TAGGED at 300a478 — the friend-playtest wave, one session
end-to-end.** 28 notes triaged (11 investigators) -> 18 CHOICE-LOG
rulings -> seam PR #340 (dialogue toast arm) -> lane fleet
(impl->adversarial-review->fix x2) -> #341 sim + #342 content (incl.
controller items: Raskghar tempo swap [profile refuted the HydroGene
wire], Erin meal duration) -> #344 art (five hero sprites via the NEW
Codex->PixelLab-pro pipeline, all five controller-read SHIP) -> id
freeze (zero removals; GH#330's stray ids captured) -> tag. Release/
Pages runs were in progress at close — CONFIRM GREEN first thing.
Board: #334 closed; deferred work lives in #335-#339 + #343; #283
closed stale. v0.17 is RATIFIED as six parallel lanes (ROADMAP) and
its dispatch prompt is below — FRESH SESSION ONLY (user directive).

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

0. **v0.17 WAVE IS RUNNING (dispatched 2026-08-02, fresh session per
   directive; ultracode on).** Pre-flight confirmed: #334 CLOSED,
   v0.16.2 tagged, Release run 30770686326 + Pages 30770686332 both
   GREEN, guard OK (43%/9%). Workflow `wf_fcf9addc-7e4`: seven
   concurrent worktree lanes at /Users/gabriel/wi-lanes/v017-l{1..7}
   (branches issue/336-l1-journal-ui, issue/337-l2-combat-cooldowns,
   issue/324-l3-presentation, lane/v017-l4-art,
   issue/323-l5-content-riders, lane/v017-l6-causality,
   lane/v017-l7-fable-design; base 5569c5c; overlay 185 files copied
   into L1-L5). Each code lane: impl → TWO adversarial review lenses
   (correctness-trace + QA-evidence-repro) → fix. Briefs (file:line
   evidence + method hints) in session scratchpad briefs/; slotting:
   #343+#339(1-3)→L5, #339(4)→L6. RUNNING — controller owns PRs +
   anchored train next (L3 lint vs siblings pre-merge; L2 sole balance
   authority; L4 palette LAST; checks table its own step; composed
   census + full 30-suite). **NEW mid-wave user directive → #350
   (player buys an inn room): controller-dispatched rider AFTER L5's
   train slot lands, before tag; price default 20g pending CHOICE-LOG
   adjudication at close.**
   UPDATE (session continues, 2026-08-03): train COMPLETE — 8 PRs
   merged (#351-#358 incl. controller seam PR; L2's difficulty-wire
   prescription reversed for core purity, landed as field+scene-push).
   Riders wf_c0579423 running (R1 #350 room @ rider/350-inn-room, R2
   moods re-tune @ rider/moods-retune). close/v017 branch carries:
   lead_camp_winter cure, 2 skill folds, fought_<id> freeze-generator
   parity. **v0.18 WAVE-1 RATIFIED (user, pre-sleep): W1 #348-slice-1 /
   W2 #347-prototype-BEHIND-FLAG / W3 #318 / W4 debt-drain(+Pisces
   re-window) / W5 Wave-D Alchemist+Druid (Priest PARKED) + rung-4 —
   W5 = sole balance writer. Pre-grants: rung-4, Pisces re-window,
   companion respawning prop, #350 20g FIRM. Overnight: close v0.17 →
   tag → dispatch W1-W5 → train → HANDOFF; eye/ear verdicts queue with
   prepared states.**

### v0.17 dispatch prompt (paste into the fresh session)

> Dispatch v0.17 per docs/ROADMAP.md's ratified seven-lane plan. First:
> wi-start-here read order, confirm wave-2/#334 is CLOSED and tagged
> (if residuals exist, fold them into the matching lane's brief), run
> wi-usage-guard. Then dispatch ALL SIX LANES CONCURRENTLY as worktree
> lanes with the exact file ownership printed in the roadmap — no
> cross-lane waits; intra-lane order as written (L1 #336→#338→#345→#346;
> L3 #324→#335→grading+motion; L4 drain+tint-audit→palette). Design
> authorities: docs/design/2026-08-02-{skill-panel,quest-clarity,
> skill-cooldown,visual-next-level}-spec docs + issues #335-#338 and
> #345-#349 (L1 also carries #345 difficulty + #346 creation prompts;
> L2 carries the #349 arena leg; L5 carries #349 narrative + #323/#332;
> L7 is the Fable design lane for #347/#348; #339 singles ride any
> lane). Each lane runs
> impl → traced adversarial review → fix per wi-running-the-machine;
> briefs carry file:line evidence from the specs + method hints.
> Controller owns PRs + the anchored merge train per the roadmap's
> train notes (L3 lint vs siblings pre-merge; L2 sole balance
> authority; L4 palette lands LAST; checks table read as its own
> step; composed census + full 30-suite bar). Close: windowed
> machine-playtest, VISUAL-LOG verification, id-freeze regen step-0,
> HANDOFF/CHOICE-LOG/ledger updates, tag v0.17.0. Wave autonomy
> applies: decide + log, surface at close. Art lane uses the banked
> candidates in potential_assets/codex_pixellab_2026-08-02/ (README
> maps candidate→target) + the wi-art-and-sprites hero-art pipeline
> for anything missing; tint is NOT disambiguation.


1. ~~CONFIRM the v0.16.2 Release/Pages runs green~~ — DONE 2026-08-02,
   both green (see item 0).
2. Everything else scheduled lives on the board (#335-#339, #343,
   #324/#323/#332 inside the v0.17 lanes) or in the taste queue below.
   Deferred minors from the v0.16 lane ledgers + economy carried items
   (gossip-ladder ask, pace-harness blindness, #65) are unchanged.

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
