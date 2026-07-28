# Wandering Inn RPG Handoff

Live current-state doc. Per-issue narrative lives in merged PR bodies
(`gh pr list --state merged`); adjudications in CHOICE-LOG; build
history in git. Read order for a fresh session: wi-start-here.

## Current state (2026-07-28, session close)

**v0.16.0 "REGION DEPTH" SHIPPED — tag at 1c1756b, Release run
30398347500 + Pages run 30398347409 green (full QA on real assets, itch
html5, Win/Linux desktops).** Third tag cut this day (v0.14.0, v0.15.0,
v0.16.0). One session end-to-end: recon → 4 per-region plans →
adversarial verify (42 findings, 4 BLOCK, all fixed pre-dispatch) →
4-lane worktree fleet (20 agents) → anchored merge-train (#319 Riverfarm,
#320 Invrisil, #321 Pallass, #322 Floodplains) → close PR #326 (freeze
step-0 with the skill_uses generator gap patched; 778 ids, zero
removals; 7 leads rows) → tag. Issues #305-#308 closed.

Content: 7 quests with three-pillar parity, 7 walk-in interiors, the
first goblin-ally fight (betrayal branch got its first live QA
coverage), the nobility layer (user directive; #318 = v0.17 Magnolia
thread), 4 bespoke PixelLab camp sprites, forge-hall board-fight debt
closed. Close evidence: 22-run windowed machine playtest (all pass);
economy axes ratified (CHOICE-LOG close block). Per-issue narrative:
the five PR bodies. INCIDENT (ledgered + skill-folded): the close PR
was merged past a red Unit suites via owner-auth bypass — main red ~5
min, fixed forward (test_sim_core active_leads pins re-derived), full
30-suite bar green before the tag.

**Session infra (user directives):** CI doc-drift → advisory
non-required job (09ebdbe); tracked pre-commit hooks, path-scoped,
worktree-scoped install (68fa336). Wave-lesson skill folds: producer-
schema parity (wi-shipping), leads re-pin + rendered-vs-seen
(wi-writing-qa-scripts, wi-machine-playtest), anchored merge trains +
owner-auth merge-bypass discipline (wi-running-the-machine).

## 🎯 NEXT ACTIONS

1. ~~Tag v0.16.0~~ — DONE (runs 30398347500/30398347409 green).
2. **#325 payoff-toast-behind-Autosaved** — v0.16.1 HOTFIX CANDIDATE: all
   seven new quests' payoff prose currently dies unread behind the
   housekeeping toast if the player moves. Small presentation fix +
   re-derive first-toast-after-beat canonicals.
3. **#324 world_ready ~1.5s dead-render window** (global, PRE-EXISTING;
   corrects the v0.15 "readout overdraw" diagnosis): ambient lines render
   nothing while ui_dialogue_rendered fires. Needs systematic-debugging in
   message_layer timing; on fix, fold the "rendered-event ≠ seen"
   verification boundary into wi-writing-qa-scripts.
4. **VISUAL-LOG open rows from the close pass**: readout-eats-interior-
   bottom-rows (P3, all 8-9-row interiors), OLD-HUT-HAS-NO-HUT (P3 — the
   enterable frame has no hut art; the cottage arch is decoy),
   line_stalker two-headed overlap (still open), scavenger-vs-scavenger
   sameness, stationer mood phase-flat + south-half emptiness, ward-scrap
   lore toast slicing the field readout lines. Art/map/UI pass candidates.
5. **Deferred minors** from the four lane ledgers (preserved at the
   session scratchpad + summarized in the PR bodies): armed-plate pocket
   cell (I2), fence power_level re-derivation, gate-closed-toast coverage
   legs, QUIET-arm canonical, post-terminal offer hide, quest-starts-from-
   offer canonical, den-keeper reactive stages.
6. **Economy carried items**: gossip-ladder scaling ask (taste queue ⭐),
   sim_progression_pace still blind to both axes (structural), #65 travel
   ledger someday.
7. Board: #283 (vacuous gate), #280 (deferred), #271/#272 (Codex-sized),
   #323 (dead inn_settled lines, v0.17), #318 (nobility thread, v0.17).

## 🧑‍⚖️ TASTE QUEUE (user-held, in rough value order)

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
