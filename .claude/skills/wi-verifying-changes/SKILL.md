---
name: wi-verifying-changes
description: Use before claiming any Wandering Inn RPG change works, when choosing which QA gates to run, when a QA run hangs or shows warnings, or when deciding if a change needs windowed screenshots.
---

# Verifying Changes (the QA gates)

## Core principle
**Evidence before claims.** A change "works" only after the gates below pass
with ZERO warnings — any `SCRIPT ERROR`, `Parse Error`, or `WARNING` in any
run is a regression (the project has no known-harmless warnings).

## Which gates for which change
| You changed… | Run (all from repo root) |
|---|---|
| Any `.gd` / any code | `load_gate` + smoke + the QA scripts touching that surface |
| `src/core/**` (sim) | ALL unit suites (16 as of M-GEAR close -- count `tests/test_*.gd`, never trust a hardcoded number) + FULL canonical QA sweep |
| `data/combatants.json` / `skills.json` / `classes.json` / arenas | balance harness + full sweep + **seed check** (below) |
| `data/skeleton_scene.json` (maps) | full sweep + re-derive any path-walking scripts you broke |
| `data/sprites.json` / new sprite assets / icon gen | **`test_sprite_registry` MINIMUM** (it pins per-animation frame counts — new entries need expected-count rows) + windowed read. `ci_sweep.sh` runs QA scripts, NOT units — a sprites.json add can leave this suite silently red for days (PF-wave incident 2026-07-06, caught by the public repo's first CI run, not locally) |
| Anything player-visible (UI, sprites, text) | the above + **windowed screenshot you READ yourself** |
| QA scripts / fixtures / test_driver | `load_gate` + the edited scripts + one untouched script (harness regression) |

## Commands
```bash
# Parse/compile gate + smoke (always cheap, always first)
wandering_inn_game/qa/run_qa.sh load_gate headless
/usr/local/bin/godot --headless --path wandering_inn_game --quit   # grep WARNING

# One QA script (seed table: wandering_inn_game/CLAUDE.md — seeds are PER SCRIPT)
wandering_inn_game/qa/run_qa.sh <script> headless --seed=<seed>
wandering_inn_game/qa/run_qa.sh <script> windowed --seed=<seed>   # + screenshots

# Unit suite (run individually; see CLAUDE.md list)
/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_sim_core.gd

# Balance harness (data-tuning authority; gated cells 0.55–0.95 win, medians 3–12)
/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/sim_combat_batch.gd
```
Read `qa_output/<script>/result.json` for pass/failures; `events.jsonl` for
the event log; `*.png` (windowed) for what a player sees.

## Iron rules
- **Seed check after combat-data changes:** fights are deterministic per seed;
  changing combat data can flip canonical outcomes. Re-run every combat script
  at its pinned seed (table in CLAUDE.md). A failed script may need a seed
  re-derivation — that's a real task, not a one-value edit.
- **A failed `assert` HANGS the run** (SceneTree scripts idle forever). Wrap
  runs: `perl -e 'alarm 45; exec @ARGV' /usr/local/bin/godot ...`. macOS has
  no `timeout`. Kill >2min runs, read partial output.
- **A unit suite can print `PASS` and still contain a SCRIPT ERROR** (an error
  thrown then swallowed mid-run — a T9 save-migration bug shipped this way).
  Grep unit-run output for `SCRIPT ERROR|Parse Error|WARNING`, never for
  `^PASS` alone. Zero-warning applies to unit runs too.
- **Windowed screenshots must be READ, not just captured.** QA asserts logical
  state; sprite size, label placement, text clipping, and "could a stranger
  find this?" are only visible to eyes. Every sprite/tile region or scale pick
  gets a screenshot read before the change is called done.
- **Screenshot pixel-diffs: compare in RGB, never RGBA-default.** Pillow
  ≥8.3's `ImageChops.difference(...).getbbox()` on RGBA defaults to
  `alpha_only=True` → returns None ("identical") for ANY same-alpha pair —
  a false negative that once "proved" day==dusk. Convert to RGB (or pass
  `alpha_only=False`). Expect background noise from NPC idle-animation
  frame jitter between independently launched windowed runs — crop to the
  region under test.
- **`qa_output/<script>/` is CLOBBERED by every re-run of that script** —
  a headless re-run (yours or a reviewer's) deletes the windowed PNGs.
  Read windowed shots IMMEDIATELY after capture, or copy them out
  (scratchpad / fp-handoff) if any later run could touch that script.
  This has cost redundant windowed re-runs twice (Q2, slice T2).
- **Common-sense pass rides every visual read** (user directive 2026-07-04):
  does the animation/icon/sfx MATCH the action semantically (a spell cast must
  not swing a sword), does text wrap/fit, is anything placeholder-grade? Any
  hit → fix now or log in `docs/VISUAL-LOG.md`; never silently ship it.
- **QA passing ≠ playable.** If a human report contradicts a green run,
  believe the human → wi-debugging-playtest-reports.
- **Verification runs are headless CLI.** (The godot-ai MCP was removed
  2026-07-06 — barely used; the windowed-QA loop covers visual work. The
  zero-warning grep now has NO exempt lines.)
- New `.gd` files: run `--headless --import` once, commit the `*.uid` sidecar.

## Full-gate one-liner (before any commit claiming "all green")
Run: load_gate → all canonical scripts at pinned seeds (ci_sweep.sh) → every tests/test_*.gd suite → smoke.
Report results per script, not "everything passed".

## OS-level screen capture (available since 2026-07-08)
macOS Screen Recording permission is granted: `screencapture -x <png>`
and `ffmpeg -f avfoundation -i "Capture screen 0"` (at
/opt/homebrew/bin/ffmpeg) work. Reach for them when the QA screenshot
can't answer the question: motion/feel evidence (frame-diff a real
windowed walk — the #41 jitter methodology), post-viewport-scaling
artifacts (in-engine dumps show pre-scale pixels only), and trailer
capture. QA screenshots stay the default for content/legibility reads.
