# Active Godot project contract

Run commands from the repository root. The root `AGENTS.md` owns user intent,
branches, PR closure, worktree ownership, public-asset safety, and canon.

## Architecture

`src/core/**` is pure simulation. It must not reference autoloads, `Node`, the
scene tree, or file I/O; inject configuration, event sinks, and deterministic
seeds. `Game` owns the `WIGame` instance and saves. `ObservableBus` is the
single domain-event/log pipe. `src/world/**`, `src/ui/**`, and `src/audio/**`
forward input to `Game.sim` and render state/events. Anything a player should
see belongs on screen, never in `print()`.

Gameplay content lives in JSON under `data/`; maps live at
`data/maps/<region>/<map>.json` and compose through `WISceneCatalog`. Tune
balance data rather than sim rules. The combat batch harness is numerical
authority; human playtests judge feel. `tests/test_*.gd` cover pure/contract
behavior. Declarative QA covers real autoload, input, presentation, and
gameplay wiring.

The structural source map and extension seams are in `docs/ARCHITECTURE.md`.
Read the relevant section for a feature; historical rationale belongs in
`docs/ARCHITECTURE-HISTORY.md`.

## Evidence contract

Every player-visible behavior emits a domain event, renders through
presentation, emits a matching `ui_*_rendered` confirmation, and has a QA
assertion driven through the actual gameplay trigger. A unit that calls a
mutator directly does not prove the production trigger is wired. Logical QA
does not prove visibility, placement, touch targeting, animation timing, or
feel; run the relevant script windowed and inspect the screenshots. Physical
touch acceptance requires the real web touch route or a device observation as
specified by the issue.

For any authoritative run, preserve the exit code, require its expected
success marker, reject `SCRIPT ERROR`, `Parse Error`, `ERROR:`, and
`WARNING`, and require a valid passing `result.json` for QA. A final `PASS`
cannot override a nonzero exit or noise. Do not pipe a gate into `head` or
`tail` to decide its status. Settle the tree before a sweep; any edit during a
run invalidates it. Run one Godot process class per tree at a time.

## Commands and sources of truth

```bash
scripts/preflight.sh
scripts/preflight.sh --full
python3 wandering_inn_game/scripts/data_lint.py
/usr/local/bin/godot --headless --path wandering_inn_game --import
wandering_inn_game/qa/run_qa.sh load_gate headless
wandering_inn_game/qa/run_qa.sh <script> headless --seed=<manifest-seed>
wandering_inn_game/qa/run_qa.sh <script> windowed --seed=<manifest-seed>
wandering_inn_game/qa/ci_sweep.sh --touching <path>[,<path>]
wandering_inn_game/qa/ci_sweep.sh
/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/sim_combat_batch.gd
```

`qa/manifest.json` owns script names, seeds, fixtures, tiers, arguments, and
notes; `docs/QA-SCRIPT-NOTES.md` is its generated readable index. `qa/scripts/*.json` owns routes/assertions. `scripts/preflight.sh --full` discovers unit suites. `WISave.VERSION` owns the save version;
`scripts/comment_census.py` owns comment ceilings. Do not copy volatile counts
or seeds into prose.

After a QA manifest/script/fixture change, run
`wandering_inn_game/scripts/derive_qa_surfaces.py`, then
`scripts/render_qa_notes.py --write`; do not hand-edit generated notes. A
fixture `rng_state` overrides the command-line seed after load. A rerun replaces
`qa_output/<script>/`, and a full sweep flushes evidence, so preserve and read
windowed screenshots before later runs.

Use `wi-verifying-changes` to route gates and `wi-writing-qa-scripts` for the
DSL. Any JSON edit starts with `data_lint`. Core changes require full units and
the full canonical sweep. Combat/class/skill/arena changes also require the
balance harness and affected pinned-seed scripts. Map changes start with
`--touching`; shared engine/catalog changes need explicit or full coverage.
Visual/UI/text/audio work requires logical QA plus a windowed read.

## Durable traps

- `@tool` is not inherited; each editor-aware subclass needs it.
- A declared `ext_resource` is not wired until a node/property references it.
- `ResourceLoader.load()` may return an uncompilable script; check
  `Script.can_instantiate()`.
- Bare `--script` runs do not instantiate autoloads.
- New `.gd` or image files and branch switches that change class-name scripts
  need an import pass; commit generated `.uid` sidecars.
- Edit shipped mixed-format JSON surgically; use `scripts/splice_json.py` for
  structured appends rather than reserializing the file.
- JSON coordinates may be floats; normalize to integers before strict array
  comparisons.
- Sprite transparent padding changes the visual feet plane; measure the alpha
  bounds and verify adjacency windowed.
- Screenshot diffs compare RGB, because same-alpha RGBA images can falsely
  appear identical.
