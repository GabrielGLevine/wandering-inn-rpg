---
name: wi-writing-qa-scripts
description: Use when writing a new declarative QA playtest script, extending an existing script to cover a new player-visible feature, hand-authoring a save fixture, or a QA run hangs/fails and the script itself (not the feature) is suspect.
---

# Writing QA Scripts

Scripts are JSON in `qa/scripts/<name>.json`, run by `qa/test_driver.gd`
(`_execute`) via `qa/run_qa.sh <name> headless --seed=N` (seed table:
`wandering_inn_game_v4/CLAUDE.md`).

## Top-level fields
| Field | Shape | Meaning |
|---|---|---|
| `fixture_save` | String \| Array | String → copies `qa/fixtures/<name>.json` into `user://saves/manual.json`. Array of `{fixture, slot}` → seeds multiple slots (`save_migration` uses this for `auto`). |
| `starts_at_title` | bool (default false) | false → driver auto-skips the title screen before step 1; true → your steps drive it (`ui_title_gate_rendered`/`ui_title_rendered`). |
| `steps` | Array | executed in order. |

## Step actions (complete set)
| action | fields | notes |
|---|---|---|
| `move` | `direction`, `steps` (default 1) | injects `move_<direction>` N times |
| `press` | `name` | `ACTION_KEYS`: move_up/down/left/right, interact, confirm, cancel, cycle, journal, hotbar_1/2/3, end_turn |
| `wait_for_event` | `type`, `timeout_sec` (5), `payload_contains` ({}), `from_start` (false) | since-marker below |
| `assert_event_logged`/`_absent` | `type`, `payload_contains` | cumulative whole-run, not windowed |
| `assert_state` | `path`, `equals` or `contains` | see below |
| `assert_save_exists` | `slot` | checks `user://saves/<slot>.json` |
| `screenshot` | `name` | no-op in headless |
| `combat_autoplay` | `max_turns` (200) | drives AI turns to `combat.finished` |
| `teleport` | `map`, `cell:[x,y]` | debug-only, bypasses doors |
| `install_fixture` | `fixture`, `slot` ("auto") | mid-run version of `fixture_save` |
| `wait_frames` | `frames` (1) | |
| `assert_world_to_screen_camera_aware` | — | probes `Main.world_to_screen` |
| `assert_world_labels_in_view` | `context` ("field") | probes `WorldLabels.panel_projections` |
| `load_all_resources` | — | the `load_gate` payload |

## `assert_state` paths
Root is `Game.sim.snapshot()`; prefix `combat.` reads `combat.snapshot()`
(fails if no active combat). Dots index Dictionary keys or Array indices.
`equals` is loose numeric equality; `contains` requires an Array result and
checks (loose) membership — e.g. `combat.combatants.pc.skills` `contains`
`"frost_bolt"` proves a granted spell is fielded without seeing it cast.

## The since-marker
A successful `wait_for_event` advances a cursor past the matched event; the
next `wait_for_event` only scans after it, so it can't match a stale event
that already satisfied an earlier one. `assert_event_logged`/`_absent` ignore
this cursor — they scan the WHOLE run, so be specific with `payload_contains`
after any phase change (combat → sleep). `{"from_start": true}` opts one wait
out.

## Props have TWO interaction shapes
`on_interact_accomplishment` (plain interact) — OR `requires_skill` +
`on_skill_use` (lantern-style): interact routes through `use_skill`, emitting
`skill_unknown` (and nothing else) unless the skill is in `known_skills()`
(innate `player_skills` ∪ class grants). Testing a gated prop means
bootstrapping the class first (scroll → sleep → [Mage] grants `light` at
level 1 — no `skill_unlocked` event fires for level-1 grants). Model:
`lantern_check.json` / `mage_unlock_loop.json`.

## The unqualified-toast trap
Never treat a bare `wait_for_event ui_toast_rendered` as proof of WHICH toast
rendered — one beat can fire several (e.g. `class_gained` autosaves FIRST, so
the next toast is "Autosaved...", not "[Mage] class gained!"). Always
`payload_contains` the exact text, or `assert_event_logged` it.

## Dialogue moves are option-cursor moves
Once `ui_dialogue_shown` fires, `move` steps the visible OPTION cursor, not
the body (body stays put). Options are the VISIBLE list only — a hidden
(`hide_when`/gated) option shifts later indices down. Idiom
(`dialogue_walkthrough.json`): `ui_dialogue_shown` → `move down 1` → `press
confirm`.

## Fixtures
`qa/fixtures/*.json`, authored against `WISave` (`src/core/save.gd`):
`{"version": 3, "state": {current_map, player_cell, player_facing, classes,
accomplishments, player_skills, removed_entities, dormant_encounters,
started_quests, rng_state, generalist_classes?, pending_consolidation?}}`
(`rng_state` is a String; last two keys additive-optional). Validate by
actually loading it — a bad/missing required key makes `WISave.apply` reject
it as a silent no-op.

## Seeds and registering
Combat is deterministic per seed; every script reaching combat needs a
pinned, PER-SCRIPT seed row (`level_up_loop` needs 11, not 9, because its
fight composition differs). A failing first-picked seed is a seed-search
task. Register in `wandering_inn_game_v4/CLAUDE.md` in BOTH places: the
canonical seed table AND the Commands script-list block (two lists exist;
keep them consistent) so `wi-verifying-changes`'s full sweep picks it up.
Assert both the domain event AND its `ui_*_rendered` confirmation for any
player-visible feature.

## Example
```json
{"action": "wait_for_event", "type": "class_evolved",
 "payload_contains": {"from": "warrior", "to": "swordsman"}},
{"action": "wait_for_event", "type": "ui_toast_rendered"},
{"action": "assert_state", "path": "classes", "equals": {"swordsman": 10}}
```
(`class_evolution_loop.json` — event, UI confirmation, state check.)

## Common mistakes
- Treating `assert_event_logged`/`_absent` as scoped to "since the last wait"
  — they see the whole run.
- Computing dialogue `move` steps against the full option list instead of
  the visible one.
- Expecting `combat_autoplay` to show a PC spell cast — see
  `wi-adding-an-encounter`'s autoplay gotcha.
- Asserting only the domain event, skipping the `ui_*_rendered` half.
- Adding a script without a seed-table row in `CLAUDE.md`.
- Authoring a fixture without ever loading it in a run.

Verify per `wi-verifying-changes` before claiming a script is good.
