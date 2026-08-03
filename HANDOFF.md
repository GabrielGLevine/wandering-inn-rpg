# Wandering Inn RPG Handoff

Live current-state doc. Per-issue narrative lives in merged PR bodies
(`gh pr list --state merged`); adjudications in CHOICE-LOG; build
history in git. Read order for a fresh session: wi-start-here.

## RUNNING (2026-08-03 evening): dialogue voice pass, branch `voice-pass`
De-AI rewrite of all 71 dialogue files per external critique
(docs/dialogue-voice/critique-2026-08-03.md). Spec + plan in
docs/superpowers/{specs,plans}/2026-08-03-dialogue-voice-pass*.
DONE: Tasks 1-5 — gate script (qa/scripts/dialogue_voice_gate.py,
self-testing; snapshot baseline committed), 36-cluster manifest,
Fable bible + 36 cards (docs/dialogue-voice-bible.md, -cards/),
W2 rewrite (36 sibling-blind agents, 288 nodes, 68 files changed),
W3 final gate CLEAN (anti=6/30). NEXT: Task 6 W4 cold-reader
detection (71 per-file adversarial readers + 1 budget aggregator,
prompts verbatim in plan) — HELD at usage CAUTION (burn-rate spike
post-W2); background watcher polls 5m, dispatch on OK. Then W5
failure loop, W6 Fable adjudication + wi-verifying-changes sweep +
wi-machine-playtest. CHOICE-LOG "Voice pass" block has 4 rulings.
Unrelated: filed #370 (Relc front-on first meeting), #371 (inn
one-party-at-a-time canonical groups), #372 (Floodplains
tutorializing defeat text) from user playtest notes.

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
