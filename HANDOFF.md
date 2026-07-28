# Wandering Inn RPG Handoff

Live current-state doc. Per-issue narrative lives in merged PR bodies
(`gh pr list --state merged`); adjudications in CHOICE-LOG; build
history in git. Read order for a fresh session: wi-start-here.

## Current state (2026-07-27)

**THE MAIN QUEST WAVE IS MERGED TO MAIN — v0.14, UNTAGGED.** Nine phases,
seven PRs, all `[ci-full]` green: #291 acts I–V reframed off "post-game"
(Act IV opens on the seal), #297 "The Dig" (the Horns door-retrieval quest
backported to day one + the Liscor link), #293 FotI PR2a (Olesm+Pisces),
#294 PR2b (Relc+Zevara), #295 the roster to ten (Klbkch, Rags, Wilovan,
Grimalkin — quest-gated), #299 the Riverfarm→Invrisil→Pallass pilgrimage
spine + Act V's three-path conclusion + the finale sequence (epilogue
retired), #300 the difficulty ladder (each stop one band above the last).
The line plays start→finale; the whole-line machine playtest is drained
into docs/VISUAL-LOG.md. Board bookkeeping still owed: **#269 and #270 are
open issues whose work merged** — close #269, and either close #270 or
re-scope it to its unshipped Pallass-return B-side (`pallass_return_carved`
was never authored). Plan + freeze list:
docs/superpowers/plans/2026-07-26-main-quest-foti-wave.md (Status: DONE).

**Release-freeze step-0 (do this BEFORE the v0.14 tag):** bump `RELEASE` in
`wandering_inn_game/scripts/generate_shipped_ids.py`, regen, commit ahead of
the tag. 21 of the wave's new counters derive from data automatically; the
ONE exception is **`finale_played`** (bare `record_accomplishment` literal in
`src/ui/sleep_veil.gd`), which must be hand-added to `STRUCTURAL_LITERALS` in
BOTH lists — `generate_shipped_ids.py:92` and `tests/test_shipped_ids.gd:6`.
Tag-cut commits carry `[ci-full]`; bundle-latest check before tagging.

## Current release

**v0.13.0 SHIPPED 2026-07-20, all three targets green** (Release run
29716161272: full QA on real assets, itch html5 deploy, Win/Linux
desktop exports; Pages deploy green on the tag trigger). Contents: the Depth +
Polish wave — #209 journal tabs, #247 Friends of the Inn (Selys+Krshia
servable guests), #225 interior floors, **#111 project rename
("Wandering Inn RPG") + first-boot save carry-over**, #123 honest
canonicals, and the full art wave (#198 scroll split + sweep, #222
stalls/benches/statue, #224 batch B, #210 bespoke Erin, #223 rigs:
Rags/Ceria+cast/Ruin Warden) + pantry-door consolidation + the
scroll's earned decipher (PRs #260-268). 647 ids frozen at 0.13.0
(28 new). Prior: v0.12.1 (2026-07-19), v0.12.0 (2026-07-18), v0.11.x,
v0.10.0, v0.9.0, v0.8.0.

## 🎯 NEXT ACTIONS

**USER-GATED, decide before the next content wave (2026-07-27):**
1. ~~**Guest-row arc windows**~~ — **RULED IN + SHIPPED** (v0.15 ruling 1,
   Phase 3): `GUEST_POOL_GATES` takes an ANY-of Array; zevara and pisces
   carry arc windows, relc audited and deliberately not gated, and
   `test_content._validate_guest_gate_windows` now derives the window from
   pool gate AND rows so the two can never disagree. Residual: zevara's
   window opens at `heard_the_deep_tremor`, not at the earlier
   `watch_runner_pointed` — cost of the wider edge logged in
   docs/CHOICE-LOG.md; a Playtest-State ask if the user wants it.
2. **Grimalkin sprite re-measure** — his figure renders ~98px, about 2.3×
   Relc's documented 43.4px catalog convention. A `sprites.json`
   `render_scale` re-measure frees the inn seat (14,5) and the
   door-approach trade it forced. Ledgered in docs/VISUAL-LOG.md (P3).
3. **The v0.14 tag cut** — release-freeze step-0 above, `[ci-full]` on
   the cut commits, bundle-latest check before tagging.

**FOLLOW-UP BATCH (agent-actionable, from the wave's final whole-branch
review, 2026-07-27)** — dead fixture keys, the `interactions.gd` variant
guard and the `hedault_enchanting.json` fragment arm all SHIPPED in v0.15
Phase 3 (hygiene batch), alongside the Pallass arrival cell, the em-dash
sweep, the golem name split and the `{addr}`/variant/arrival lint arms.
Still open from that batch:
- `test_copy_fit` blind spots: the `sleep_veil.gd` line tables and dialogue
  `text_variants` are still unmeasured (VEIL-COPY/UNMEASURED, P4). Phase 3
  closed the `skill_uses` toast blind spot only.
- COMBAT/FEED-FOLD (P2, docs/VISUAL-LOG.md): the combat feed's viewport
  admits three rows and a sliced fourth — a shared message-panel budget
  fix touching every panel class, so it needs its own verification pass.

**Dev-arch wave #275-280 (2026-07-26) — residue only:** all seven PRs
merged (#282 wi_data_lib, #284 data_lint, #285 live reload, #286
ship-asset gate + pending audio slots, #288 4-way parallel CI sweeps,
#289 data_diff, #290 debug overlay). Still live: **#283** (the shipped
vacuously-true `invrisil_anchor_stone` portal_menu_when — lint allowlists
it; closing it = wrap the gate + drop the allowlist entry, needs a
canonical re-check) and **#280 DEFERRED** (revival criteria in
docs/design/2026-07-26-dev-arch-eval-275-280.md).

**Door-chain polish pair (filed 2026-07-20, small)**: #271
`dungeon_attuned` banks silently in `sleep_beat.gd` — no toast, no
quest beat; add one bank-site toast (nudge idiom, GH#167). #272 Selys
`pallass_sponsored_reaction` copy says "give it a day or so" while the
sponsor node says "same-day" and no wait exists — copy-only fix ruled
in the issue (sleep-gate alternative rejected: re-pins
pallass_walkthrough). Both are clean Codex-sized dispatches. Came out
of a progression-map audit; cost-curve concern folded into the
existing #65 economy-ledger taste item, not a new issue.

## 🧑‍⚖️ TASTE QUEUE (user-held, in rough value order)

- **v0.14 wave asks** (detail in USER-GATED above): the tag cut; the
  guest-row arc-window design call; Grimalkin's sprite re-measure. The
  whole-line playtest's remaining visual items (Act IV pending-itinerary
  render policy, journal half-row, briar camouflage, Pallass forge floor,
  warden rig scale) are ledgered open in docs/VISUAL-LOG.md.
- **#195 Ove Melaa audio listen** (~30 files) → wiring pass after.
- **#211 challenge-weighted leveling FEEL** (shipped flag-on; all
  knobs data).
- **3 Rags reads** (b1 content: meeting/mercy/betrayal voice).
- Standing visual asks: windup overlay visibility in the vault fight
  (brightened ~2.5x without an in-fight windowed read — your eyes);
  rock-crab relc_downed band sits at 0.62 vs the infeasible ~0.5
  target (frontier documented in the combatant _comment).
- Economy ledger pass someday: the cumulative ~82g three-city travel
  spend (each fee individually sanctioned; flagged at #65).
- Lore-gated: #134 Wave-D classes (Alchemist/Druid/Priest), #141
  [Acolyte]→[Priest].
- User-deferred: #253 itch/mobile Import Save picker bug. Pre-existing
  flake: #140 Metal windowed screenshot corruption. On hold: #19 Steam.

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
