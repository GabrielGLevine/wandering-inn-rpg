# Wandering Inn RPG Handoff

Live current-state doc. Per-issue narrative lives in merged PR bodies
(`gh pr list --state merged`); adjudications in CHOICE-LOG; build
history in git. Read order for a fresh session: wi-start-here.

## Current state (2026-08-02)
**FRIEND-PLAYTEST WAVE 2 IN FLIGHT.** A friend's 28-note list (NEW list,
zero overlap with the owner's 26) triaged by an 11-investigator fleet —
all verdicts file:line-cited; 3 surprises beyond the notes: pending_meal
whole-value replacement silently eats armed buffs, an uncured free-cook-
then-sell twin of the #6 economy exploit (pallass_stall_burner), and a
latent hard softlock (dungeon_attuned without horns_delve_started =
zero exits, probe-proven). Rulings: CHOICE-LOG 2026-08-02 block (18).
SHIPPED ALREADY: seam PR #340 (dialogue-effect `toast` arm — talk-route
resolutions can finally speak; merged f8481c5, 7/7 green); #283 closed
as already-fixed; specs committed (skill cooldowns v0.17+ milestone
#337, Skills-tab redesign #336, quest clarity #338) + deferral issues
#335 (feedback layer) / #339 (tripwires+inerts). RUNNING: fix-wave
fleet wf_ad27edcc — sim lane (/private/tmp/wi334-sim, issue/334-sim)
+ content lane (/private/tmp/wi334-content, issue/334-content), each
impl→adversarial-review→fix; briefs in session scratchpad; #334 is the
umbrella. Controller owns PRs + anchored train (sim first). THEN: art
pass (ruins/rune-door/hut via the NEW Codex→image-to-pixelart-pro
pipeline — proven 2026-08-02, folded into wi-art-and-sprites; ship-
grade candidates in session scratchpad codex-art/) + audio leg (wire
the profiled HydroGene combat winner for the Raskghar fight, ear-gate
state) + composed gates + close.

**Codex image gen = REAL and wired into the art doctrine.** Codex CLI
has native image generation (feature stable+on, ChatGPT auth). Hero-art
pipeline: painterly concept → PixelLab /image-to-pixelart-pro (~180px
clean pixel art, full fidelity). Visual next-level strategy at
docs/design/2026-08-02-visual-next-level.md (Atmosphere Milestone =
v0.17 candidate: palette unification + time-of-day grading + motion
layer). gpt-image licensing: bundle-tier until redistribution verified.

UNTAGGED on main: #331 (board pair) + #333 + #340 + wave-2 docs —
v0.16.2 cut rides the wave-2 close.


**v0.16.1 "the playtest wave" TAGGED at 0fe611d** (Release/Pages runs
verifying at close — confirm green). ALL 26 findings from the user's
full sitting addressed in three PRs, same session as receipt: #327
(sim/UX/audio — one toast spec incl. GH#325, [Light] toggle, field
readout, combat-beat audio clock, defeat music, biome voice, MP hint,
both music swaps), #328 (content/maps — economy exploit closed with
yarrow-gated brewing + the hidden counter exploit, Hunter ruling,
mill ramp, alley mouth, fence resolution toast, Cups gating, mothbear
re-home, blade banding, pot tints, sign entity, warehouse-door split),
#329 (art — bespoke Lady/Hedault/Coyle rigs + 2 shared civilians +
sign for $0.26, pc_* sprite ban with a mutation-proven registry gate,
16 entities re-cast). Process notes ledgered: composed-census red on
#328's first head (both lanes trimmed to their own trees) caught at
the verdict read and trimmed; sim reviewer caught the toast fix
regressing GH#325's own repro (one-shot cap) pre-merge.

**v0.16.0 shipped earlier the same day** (see git history of this
block): the Region Depth wave, 778 frozen ids, one-session end-to-end.

## 🎯 NEXT ACTIONS

0. **v0.17 DISPATCH IS RESERVED FOR A FRESH SESSION (user directive
   2026-08-02).** This session finishes wave-2 ONLY (train → close →
   tag decision) and STOPS. The fresh session's dispatch prompt is
   recorded below; art candidates parked durably at
   potential_assets/codex_pixellab_2026-08-02/ (gitignored, README
   inside maps candidate→target).

### v0.17 dispatch prompt (paste into the fresh session)

> Dispatch v0.17 per docs/ROADMAP.md's ratified six-lane plan. First:
> wi-start-here read order, confirm wave-2/#334 is CLOSED and tagged
> (if residuals exist, fold them into the matching lane's brief), run
> wi-usage-guard. Then dispatch ALL SIX LANES CONCURRENTLY as worktree
> lanes with the exact file ownership printed in the roadmap — no
> cross-lane waits; intra-lane order as written (L1 #336→#338;
> L3 #324→#335→grading+motion; L4 drain+tint-audit→palette). Design
> authorities: docs/design/2026-08-02-{skill-panel,quest-clarity,
> skill-cooldown,visual-next-level}-spec/.md + issues #335-#338
> (#323/#332 ride L5, #339 singles ride any lane). Each lane runs
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


1. ~~Tag v0.16.0~~ — DONE (runs 30398347500/30398347409 green).
2. ~~#325~~ — SHIPPED in v0.16.1 (#327's toast spec; issue closable).
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

- **⭐ WAVE-2 EAR/EYE GATES (land with the wave close)**: (1) Raskghar
  fight music swap — profiled HydroGene winner wired, ear-gate state
  ships; THIRD strike if it reads wrong, say the word and the runner-up
  wires (#200 history). (2) Pisces canon deviation ACKNOWLEDGED in
  CHOICE-LOG ruling 6: this game's Horns are a three-person party,
  Pisces staged as YOUR consultant (the Act IV/V thread requires it) —
  copy now says so consistently; veto reopens it as the L-sized
  four-member reading. (3) Hero-art candidates (ruins/hut via the new
  pipeline) get windowed reads at integration — eye-gate the style fit
  vs PC16 neighbors.

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
