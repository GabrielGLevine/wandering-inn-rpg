---
name: wi-writing-qa-scripts
description: Add or edit declarative QA scripts, fixtures, driver actions, and manifest registration.
---

# Author QA through the player path

Scripts live in `qa/scripts/*.json`; `qa/test_driver.gd` executes them. Read
`qa/manifest.json` for current seeds, fixtures, tiers, arguments, and notes.
Use a fixture-first start for a new feature canonical unless navigation itself
is under test. Load every authored fixture to prove `WISave.apply` accepts it;
derive its schema/version from `src/core/save.gd`, never copied prose.

Build a steel thread: input action → actual production trigger → domain event →
rendered event → state/result. For player-facing behavior assert both the
specific domain event and `ui_*_rendered`, with exact `payload_contains` where
several events can occur. A cumulative `assert_event_logged` scans the whole
run; use ordered `wait_for_event` or event counts to prove a later repeated
action emitted something new.

The wait cursor advances after each matched event. Respect production order,
especially dialogue: `dialogue_started` → `dialogue_node` →
`ui_dialogue_shown`. Dialogue moves address the currently visible option list,
and the cursor wraps, so assert the selected destination/effect as well as the
number of moves. Priced purchases require the confirmation route; read the
dialogue skill before writing one.

For a new driver action, search `qa/test_driver.gd` first and extend an
existing match arm rather than shadowing it. Add any new autoload dependency to
the driver-stubbed unit test. Normalize JSON coordinate numbers before strict
GDScript array comparisons. `combat_autoplay` uses the PC’s default AI profile;
assert kit state rather than expecting behavior that profile cannot produce.

Register a canonical once in `qa/manifest.json`. Run
`wandering_inn_game/scripts/derive_qa_surfaces.py`, then
`scripts/render_qa_notes.py --write`. Verify the edited script and one
unaffected canonical. A fixture `rng_state` overrides the CLI seed after load;
combat scripts still carry a manifest seed.

Touch assertions must identify their evidence tier. Native touch actions are
emulated clicks. The web runner with `--touch` services the requested window
coordinate using browser touchscreen input. Neither is a physical device
observation. Do not substitute keyboard/mouse or zero-delay TestDriver paths
for acceptance that names touch, animation, or timing.

Read [references/qa-dsl.md](references/qa-dsl.md) before adding an action,
fixture, touch route, dialogue route, or save import/export route. The driver
source remains authoritative if this reference and code differ.
