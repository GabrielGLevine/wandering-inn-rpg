# Active Godot project guidance

Model-neutral guidance for `wandering_inn_game/`, the only active game project.
Read the repository-root `AGENTS.md` first for workflow, branch, PR, asset, and
shipping rules. Run every shell command below from the repository root.

## Operating contract

- **QA-first:** every feature must be machine-verifiable. Every player-visible
  behavior emits a domain event, renders through presentation, emits a matching
  `ui_*_rendered` confirmation, and has a declarative QA assertion. **Humans gate FEEL**
  through windowed reads and milestone playtests; automated QA does not
  replace taste or interaction judgment.
- **Pure simulation:** `src/core/**` never references autoloads, `Node`, or the
  scene tree. Inject configuration, event sinks, and seeds.
- **Thin presentation:** UI and world nodes forward input to `Game.sim` and
  render state/events. Never `print()` anything a player should see.
- **Visible stat grammar:** HP/MP/AP, damage, gold, levels, classes, race, gear,
  and `[Skills]` are player-facing. Raw STR/DEX/CON/INT/WIS/CHA stay out by
  default; clarity exceptions update `test_effect_text` in the same change.
- **Opaque until sleep:** never show progress-toward counts, percentages, or
  merged-level arithmetic. Show results only after the sleep resolution.
- **Canon:** names, races, classes, skills, and locations come from the
  Wandering Inn Wiki, not invented lore.
- **Balance:** tune data, not sim rules, and treat the combat harness as the
  numerical authority. Human feel can identify a problem; it does not replace
  measurement.
- **Zero-noise baseline:** any `SCRIPT ERROR`, `Parse Error`, `ERROR: FAIL`, or
  `WARNING` in a run is a regression even if a final line says `PASS`.

## Sources of truth

| Concern | Authority |
|---|---|
| Work queue, branches, PR close flow | repository-root `AGENTS.md` + GitHub issue/PR |
| Live cross-session state | `HANDOFF.md` |
| Current architecture boundaries | this file; structural map in `wandering_inn_game/docs/ARCHITECTURE.md`; rationale/history in `wandering_inn_game/docs/ARCHITECTURE-HISTORY.md` |
| QA script names, seeds, fixtures, tiers, notes | `wandering_inn_game/qa/manifest.json` |
| Human QA inventory | generated `wandering_inn_game/docs/QA-SCRIPT-NOTES.md` |
| Exact QA routes and assertions | `wandering_inn_game/qa/scripts/<name>.json` |
| Unit-suite inventory | discovered from `wandering_inn_game/tests/test_*.gd` by `scripts/preflight.sh --full` |
| Save format version | `WISave.VERSION` in `wandering_inn_game/src/core/save.gd` |
| Comment-weight limits | constants in `scripts/comment_census.py` |
| Verification selection and evidence rules | `wi-verifying-changes` |

Do not copy volatile counts, seeds, save versions, or lint ceilings into prose.
Read them from their authority. Generated documents are outputs, never a second
hand-edited source.

## Architecture boundaries

- **Simulation:** `WIGame` and its pure modules own combat, progression,
  dialogue, quests, economy, inventory, field skills, interactions, portals,
  saves, and deterministic RNG.
- **Autoloads:** `Game` owns the `WIGame` instance and file I/O.
  `ObservableBus` is the single domain-event pipe and JSONL event log.
- **Presentation:** `src/world/**`, `src/ui/**`, and `src/audio/**` consume sim
  state and bus events. `src/world/main.tscn` is the authored root scene.
- **Content:** gameplay content is JSON under `data/`; maps live at
  `data/maps/<region>/<map>.json` and are composed by `WISceneCatalog`.
- **Tests:** `tests/test_*.gd` are SceneTree unit/contract suites. Anything that
  needs real autoload/UI/gameplay wiring belongs in declarative QA.
- **QA:** `qa/test_driver.gd` executes JSON scripts with real input, event waits,
  state assertions, combat autoplay, and screenshots. It is inert without a QA
  script argument.

The machine-oriented structural map (module registry, data catalog, seams,
extension recipes) is `wandering_inn_game/docs/ARCHITECTURE.md` — read it when
designing or executing a feature. Rollout rationale and historical traps belong
in `wandering_inn_game/docs/ARCHITECTURE-HISTORY.md`, not in this bootstrap file.

## Commands

```bash
# Fast documentation/data/tooling gate + sprite-registry unit
scripts/preflight.sh

# The discovered complete unit suite, with exit/PASS/error discipline
scripts/preflight.sh --full

# Import after branch switches that change .gd files, or after new .gd/images
/usr/local/bin/godot --headless --path wandering_inn_game --import

# Parse/smoke
wandering_inn_game/qa/run_qa.sh load_gate headless
/usr/local/bin/godot --headless --path wandering_inn_game --quit

# One canonical QA script; read its seed from qa/manifest.json
wandering_inn_game/qa/run_qa.sh <script> headless --seed=<seed>
wandering_inn_game/qa/run_qa.sh <script> windowed --seed=<seed>

# Canonical QA selections
wandering_inn_game/qa/ci_sweep.sh --tier smoke
wandering_inn_game/qa/ci_sweep.sh --touching <path>[,<path>]
wandering_inn_game/qa/ci_sweep.sh

# QA-derived artifacts after manifest/script/fixture changes
python3 wandering_inn_game/scripts/derive_qa_surfaces.py
python3 scripts/render_qa_notes.py --write

# Combat balance authority
/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/sim_combat_batch.gd

# Run the game
/usr/local/bin/godot --path wandering_inn_game
```

Failed GDScript assertions can leave a headless SceneTree idle forever. Wrap a
potentially hanging direct Godot run with
`perl -e 'alarm 300; exec @ARGV' /usr/local/bin/godot ...`; macOS has no
`timeout`. Always inspect the exit code, require a `PASS` line when applicable,
and grep the complete output for every zero-noise marker above.

## QA registration workflow

1. Add or edit the script/fixture.
2. Register script, seed, fixture, tiers, args, and note once in
   `wandering_inn_game/qa/manifest.json`.
3. Run `derive_qa_surfaces.py`; it writes derived manifest surfaces and fails
   on contradictory fixture declarations.
4. Run `render_qa_notes.py --write`; never edit the generated notes directly.
5. Run the edited canonical plus one unaffected canonical to prove the harness.
6. For player-visible work, run windowed, immediately read the screenshots,
   and preserve evidence before any later run clobbers that script's output.

Fixture saves carry their own `rng_state`, which overrides a command-line seed
after load. Combat scripts still have a manifest-pinned seed. A combat-data
change that flips an outcome requires re-derivation and evidence, not a casual
seed replacement.

`qa_output/<script>/` contains `result.json`, `events.jsonl`, logs, and windowed
screenshots. Every rerun of that script replaces the directory; a full sweep
flushes prior artifacts.

## Verification routing

Use `wi-verifying-changes` for the complete evidence contract. Minimum routing:

| Changed surface | Minimum before broader gates |
|---|---|
| Any `data/*.json` | `python3 wandering_inn_game/scripts/data_lint.py` |
| Any `.gd` | import when needed, `load_gate`, smoke, affected units/QA |
| `src/core/**` | `scripts/preflight.sh --full` + full canonical QA sweep |
| Combat/class/skill/arena data | balance harness + affected combat canonicals + full sweep |
| Map content | `ci_sweep.sh --touching <path>`; use explicit/full scripts when engine or quest surfaces are involved |
| Sprites, icons, visual states | sprite-registry unit + windowed before/after read |
| Player-visible UI/text/audio | logical QA + windowed evidence; humans decide FEEL |
| QA driver/script/fixture | load gate + edited script + one untouched script + derived-artifact checks |

`--touching` is a content-path selector, not a universal dependency engine.
Changes under `src/**` and some shared catalogs require explicit scripts or the
smoke/full sweep.

## Working conventions

- Follow the root issue-branch/PR workflow. Non-issue guidance housekeeping may
  land directly on `main`; issue-closing work uses `issue/<n>-<slug>` and a PR.
- Content belongs in data, behavior in pure sim, and rendering in presentation.
- Add player-visible work to a QA script with both domain and rendered-event
  assertions. A direct call to a state mutator is not gameplay-wiring proof.
- Comment function, constraint, payload shape, or non-obvious trap. Do not add
  provenance or review narrative. Let `scripts/comment_census.py --check`
  enforce the current limits.
- Edit shipped JSON surgically. Prefer `wandering_inn_game/scripts/splice_json.py`
  for appends; do not reserialize a mixed-format shipped file.
- New `.gd` files need their generated `.uid` sidecars and an import pass.
- Before implementing a Godot system, invoke the matching
  `godot-prompter:*` skill. Common matches: `gdscript-patterns`,
  `scene-organization`, `resource-pattern`, `event-bus`, `godot-ui`, and
  `godot-testing`.

## Durable Godot and QA gotchas

- `@tool` is not inherited by GDScript subclasses; editor-aware subclasses
  need their own annotation.
- `ResourceLoader.load()` can return a non-null but uncompilable script.
  Compile/load gates must also check `Script.can_instantiate()`.
- Bare `--script` runs do not instantiate project autoloads. Keep pure tests
  and core modules free of bare autoload identifiers.
- Declaring an `ext_resource` does not wire it. Confirm an actual property or
  node references the resource.
- A unit test calling a mutation method proves the method, not that gameplay
  triggers it. Contract-test the real call path or cover it through QA.
- Logical success does not prove visibility. Player-facing changes need the
  rendered confirmation plus an on-screen read.
- `CanvasLayer` has no `modulate`; tint or fade child canvas items.
- Transparent padding changes sprite feet anchoring. Measure the alpha bounds,
  set `data/sprites.json` anchors from the feet plane, and verify adjacency in
  a windowed screenshot.
- JSON coordinates may parse as floats while code-authored cells use ints.
  Normalize through `int()` or `Vector2i` before strict array comparisons.
- Long-lived lambdas captured by `RefCounted` modules can leak ObjectDB
  instances. Use bound methods for long-lived injected callables.
- An absent `result.json` is a failed QA run even when the process exits zero.
- Screenshot diffs must compare RGB; RGBA alpha-only behavior can report
  same-alpha images as identical.

## Pointers

- `wi-start-here` — session bootstrap and skill routing.
- `wi-running-the-machine` — issue execution, review, PR, and merge discipline.
- `wi-verifying-changes` — authoritative gate selection and evidence handling.
- `wi-writing-qa-scripts` — QA DSL, fixtures, event ordering, and registration.
- `wandering_inn_game/docs/QA-SCRIPT-NOTES.md` — generated searchable QA index.
- `wandering_inn_game/docs/ARCHITECTURE.md` — machine-oriented structural map: modules, data catalog, seams, extension recipes.
- `wandering_inn_game/docs/ARCHITECTURE-HISTORY.md` — mechanism rationale and history.
- `docs/DOC-MAP.md` — repository-wide document authority map.
