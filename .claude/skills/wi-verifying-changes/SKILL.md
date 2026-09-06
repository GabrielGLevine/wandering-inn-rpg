---
name: wi-verifying-changes
description: Select and evaluate QA evidence before claiming a Wandering Inn RPG change works.
---

# Verify the current tree

Evidence is valid only for the settled tree and environment that produced it.
Capture the tree SHA, command, fixture/manifest seed, engine/runtime, overlay
state, exit code, required success marker, complete noise scan, and artifact
path. Any subsequent relevant edit invalidates it.

Start with existing entry points; do not replace their contract with a new
wrapper. `scripts/preflight.sh` is the project preflight and `qa/run_qa.sh` /
`qa/ci_sweep.sh` own QA execution. Until the runner itself enforces all three,
verify each authoritative suite has: zero exit, expected `PASS`, and no
`SCRIPT ERROR|Parse Error|ERROR:|WARNING`. A QA run also needs a present
`result.json` with `passed: true`. Keep complete logs; never infer a verdict
from piped or truncated output.

Route checks by changed surface:

- Any JSON: `python3 wandering_inn_game/scripts/data_lint.py` first.
- Any GDScript: import when the script/image/class-name set changed, then
  `load_gate`, smoke, affected units and QA.
- `src/core/**`: `scripts/preflight.sh --full` and full canonical sweep.
- Combat/class/skill/arena: balance batch, affected combat scripts at manifest
  seeds, and full sweep.
- Map: `ci_sweep.sh --touching <path>` minimum; shared code/catalog/quest
  effects require explicit or full coverage.
- Sprite/icon/visual state: sprite registry unit plus real-overlay windowed
  before/after read.
- Player-visible UI/text/audio: domain + rendered assertions and windowed read.
- QA driver/script/fixture: load gate, edited canonical, one unaffected
  canonical, and derived-artifact checks.

Run units and sweeps sequentially in one tree. Finish edits before launching a
sweep. Preserve windowed evidence immediately because reruns and full sweeps
replace `qa_output`. Compare screenshot diffs in RGB and inspect the images;
pixel difference alone cannot judge readability or meaning.

Player-visible evidence must start from the production trigger. Direct mutator
tests, source greps, teleports, zero-delay test paths, or emitted payloads alone
cannot prove that a player can trigger, see, touch, or time the feature. Mouse
evidence does not prove touch. Native scripted touch proves only its declared
emulation; web `page.touchscreen.tap` proves the web touch path, while physical
device acceptance remains open until observed on the device.

Read [references/evidence-recipes.md](references/evidence-recipes.md) when
validating refactor equivalence, visual changes, combat seed changes, or a
claimed pre-existing failure. If a human report contradicts green QA, use
`wi-debugging-playtest-reports`.
