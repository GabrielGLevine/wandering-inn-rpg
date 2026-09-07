# QA DSL reference

## Script and fixture shape

Top level: optional `fixture_save` (one fixture or `{fixture,slot}` rows),
optional `starts_at_title`, and ordered `steps`. Fixture structure and version
come from `WISave`; include map/cell/facing, classes, accomplishments, skills,
removed/dormant entities, quests, deterministic RNG state, and any optional
current save fields needed by the route.

`player_facing` uses the save schema’s vector form. When facing matters for an
interaction, a blocked bump toward the target establishes it through gameplay.
For behavior that must occur before the first frame/autoload readiness,
`legacy_seed` installs its fixture before launch; inspect `run_qa.sh` and the
surface deriver for its current contract.

## Core actions

Movement/input: `move`, `press`, `wait_frames`. Observation:
`wait_for_event`, `assert_event_logged`, `assert_event_absent`,
`assert_event_count`, `assert_state`, `assert_dialogue_displayed`,
`screenshot`. Setup/control: `teleport`, `install_fixture`, `reload_data`,
`toggle_overlay`, `load_all_resources`. Combat: `combat_autoplay`. Save/settings
and audio have dedicated assertions. Before using any action, inspect its match
arm in `qa/test_driver.gd` for exact fields and indexing.

Use `dump_state` for a passing event-log probe and `dump_checkpoint` or the
runner’s checkpoint option to preserve a quiet-state save when supported. The
driver/runner’s fail-fast mode stops at the first divergence. `qa/oracle.gd`
can derive current visible options, paths, state, field bar, skills, portals,
and inventory; prefer it to guessing cursor counts or routes.

Touch actions include screen/cell/title row/dialogue option/field chip/settings
row/purchase row. Rows/options are generally one-based where declared by the
driver. Use `ui_*_armed` or rendered-rect events before tapping a newly shown
surface; this is the double-tap/timing proof. The web runner is
`qa/web/run_web_qa.sh`; inspect its current flags and CI invocation rather than
copying a stale command.

## Event/state traps

- `wait_for_event` searches after its cursor unless `from_start` is set.
- Logged/absent/count assertions are whole-run queries.
- `payload_contains` on an array-valued key compares the whole array, including
  order.
- Qualify toast text; autosave and feature toasts may occur together.
- `assert_state` roots at `Game.sim.snapshot()`; `combat.` roots at the active
  combat snapshot. `contains` expects an array.
- A screenshot action is inert headless. Windowed evidence must be captured and
  read before another run replaces the output directory.
- Teleport establishes state but does not prove doors, reachability, input, or
  onboarding routes.
- A fresh-waking talk-pool interaction may emit only the ambient line before a
  later interaction opens the graph. Wait for the actual line/panel teardown
  before sending the next press; input during teardown can be swallowed.
- Challenge weighting may make `won_combat` fractional or capped. Pin the
  domain counter/event that represents the acceptance claim rather than
  assuming one victory always deposits one whole accomplishment.
