---
name: wi-writing-qa-scripts
description: Use when writing a new declarative QA playtest script, extending an existing script to cover a new player-visible feature, hand-authoring a save fixture, or a QA run hangs/fails and the script itself (not the feature) is suspect.
---

# Writing QA Scripts

Scripts are JSON in `qa/scripts/<name>.json`, run by `qa/test_driver.gd`
(`_execute`) via `qa/run_qa.sh <name> headless --seed=N` (seed table:
`wandering_inn_game/AGENTS.md`).

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

For a repeated event with the same payload, a cumulative
`assert_event_logged` is not proof that a later action emitted it. Use ordered
`wait_for_event` steps or compare the event count before and after the action.

## Coordinate arrays cross a JSON type boundary
JSON coordinates parse as Arrays of floats, while code-authored map cells are
often Arrays of ints. GDScript Array equality is element-type strict, so
`[5.0, 8.0] == [5, 8]` is false even though the cells are numerically the
same. Normalize coordinates through `int()`/`Vector2i` before equality,
membership, route, or blocker checks. `assert_state.equals` already provides
loose numeric comparison; this trap applies to GDScript tests/helpers that
read QA JSON directly.

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
**FIXTURE-FIRST POLICY (consultant review, ratified 2026-07-07):** a NEW
canonical script defaults to a FIXTURE start (`near_*` precedent) — long
organic routes are reserved for scripts whose ROUTE is the subject
(walkthroughs, onboarding proofs). Rationale: the pinned-seed suite's
blast radius — every combat-data edit risks invalidating hand-derived
organic routes (O5 re-pathed 19 scripts in one wave); fixture starts cut
the re-derivation surface to the fight under test. When extending an OLD
organic script, consider whether the extension belongs in a new
fixture-based script instead.

`qa/fixtures/*.json`, authored against `WISave` (`src/core/save.gd`):
`{"version": 3, "state": {current_map, player_cell, player_facing, classes,
accomplishments, player_skills, removed_entities, dormant_encounters,
started_quests, rng_state, generalist_classes?, pending_consolidation?}}`
(`rng_state` is a String; last two keys additive-optional). Validate by
actually loading it — a bad/missing required key makes `WISave.apply` reject
it as a silent no-op.

## Seeds and registering
Combat is deterministic per seed; every script reaching combat needs a
pinned, PER-SCRIPT seed row (fixture-based scripts: the fixture rng_state
governs instead — see FIXTURE-FIRST above; e.g. `level_up_loop` is a
fixture loop whose rng 9 overrides --seed). A failing first-picked seed is
a seed-search task. Register a new canonical in `wandering_inn_game/qa/manifest.json` (THE
single source of truth — ci_sweep.sh parses it and hard-fails at startup
if AGENTS.md's compact seed table drifts from it) AND add the matching
row to AGENTS.md's compact table (the drift check enforces the pair).
Per-script routing history: `wandering_inn_game/docs/QA-SCRIPT-NOTES.md`.
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
- Adding a script without a seed-table row in `AGENTS.md`.
- Authoring a fixture without ever loading it in a run.
- Comparing JSON-parsed coordinate Arrays directly with int cell Arrays.
- Using a cumulative event assertion to prove a repeated post-action emission.
- **Adding a driver action without grepping for the name first** — the
  driver's match takes the FIRST matching arm, so a duplicate arm SHADOWS
  the original silently (no parse error). A shadow with different
  semantics (0- vs 1-based `click_dialogue_option`, 2026-07-18) off-by-oned
  every consumer and cost 7 sweep reds. `grep '"<action>"' qa/test_driver.gd`
  before authoring; extend the existing arm, never re-declare it.
- **Pinning an option LIST and assuming contains-semantics** — `payload_contains`
  matches per-KEY, and an `options` key compares the WHOLE list (exact
  members, exact order): adding one option to a pinned dialogue node reds
  every script pinning that node's list (the #172 retirement-node wave hit
  4 scripts). The driver's timeout failure prints the subset + cursor —
  read it before seed-shopping.

## Challenge-weighting pin traps (GH#211, 2026-07-19 — flag ships ON)
- A gray-band fight (weak enemies vs a leveled build) emits NO
  `won_combat` accomplishment event — the deposit is fractional and only
  a whole-unit bank fires ACCOMPLISHMENT_RECORDED. Pin `victories`
  instead when the script needs "a win happened": it banks integer under
  BOTH flag states. Cost: boulevard_night_footpads_loop hang.
- A low-power player beating a real fight banks `won_combat` at the
  adversity CAP (2 per win on the classless tutorial arc) — pin actuals,
  don't "fix" the double.
- Milestone fixtures (evolution/level thresholds) must arrive
  PRE-QUALIFIED: a below-band grind fight cannot push a L10+ axis
  counter over its threshold anymore — that is the design, not a bug.
- `ci_sweep.sh --touching` maps `data/quests.json` to ZERO scripts (the
  quest surface joins the src/** false-safe class) — run the quest
  canonicals explicitly on quest-data edits.
- `click_dialogue_option` takes `"option"` (1-based), NOT `"index"` — a
  wrong key silently no-ops the click (zero events; cost one hang).
  Graph dialogues pin `dialogue_node` `{speaker, text}` subsets
  (`ui_dialogue_rendered` is the plain line-panel path only);
  `item_gained` payloads key `"item"`; `assert_state` on a MISSING
  path ERRORS — use `assert_event_absent` for never-banked counters.
- Comment keys must NEVER go inside `payload_contains` — the subset
  match treats them as required payload keys (cost one hang).

Verify per `wi-verifying-changes` before claiming a script is good.
- Fixture `player_facing` is a 2-VECTOR (`[0, -1]` = up), never a
  string — `WISave.apply` type-rejects the whole save and the TITLE
  shows the misleading "Save is from an older version" notice (the
  version is fine; `_load_slot_or_notice` shows one notice for every
  apply failure). A fixture that "won't load" gets its state checked
  against apply()'s type guards FIRST, not its version. Robust facing
  for an interact: don't trust the field — bump-move into the target's
  cell (blocked move sets facing without moving), the walkthroughs'
  own idiom.
