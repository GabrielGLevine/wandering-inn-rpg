# Wandering Inn RPG Handoff

Live current-state doc. Per-issue narrative lives in merged PR bodies
(`gh pr list --state merged`); adjudications in CHOICE-LOG; build
history in git. Read order for a fresh session: wi-start-here.

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

1. **USER: the 2-minute web rename check** (#111 rehearsal b): open
   the itch page in the browser you've played in before — Continue
   should light up with your old web save; load it. Same on Pages.
   Fail = report; rollback = revert the rename PR + re-tag (browser
   data is untouched either way; copy-only design). The NATIVE
   rehearsal already passed on this machine with real data
   (5 saves + settings migrated byte-true, marker set, v4 dir intact).
2. Then the board is fully user-gated (see taste queue). Next
   milestone planning is open — docs/ROADMAP.md; Three Pillars
   (spec approved) is the standing next big rock.

## 🧑‍⚖️ TASTE QUEUE (user-held, in rough value order)

- **Web rename check** (above — gates calling #111 fully done).
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
