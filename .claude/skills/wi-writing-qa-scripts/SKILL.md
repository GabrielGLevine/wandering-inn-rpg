---
name: wi-writing-qa-scripts
description: Use when writing a new declarative QA playtest script, extending an existing script to cover a new player-visible feature, hand-authoring a save fixture, or a QA run hangs/fails and the script itself (not the feature) is suspect.
---

# Writing QA Scripts

Scripts are JSON in `qa/scripts/<name>.json`, run by `qa/test_driver.gd`
(`_execute`) via `qa/run_qa.sh <name> headless --seed=N`. Seeds, fixtures,
tiers, and notes come from `qa/manifest.json`; the generated human index is
`docs/QA-SCRIPT-NOTES.md`.

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
| `assert_field_skill_absent` | `skill` | #398: negative of `press_field_skill`, reads `field_hotbar_loadout()` directly — proves a weapon-gated skill is OFF the bar (falsifiable: equip the weapon family and it reds) |
| `assert_event_count` | `type`, `count`, `payload_contains` | exact whole-run count — the once-semantics proof (`== 1` after a repeat press) |
| `assert_dialogue_displayed` | (see driver) | pins the rendered dialogue panel |
| `touch_screen`/`touch_cell`/`touch_title_row`/`touch_dialogue_option`/`touch_field_chip`/`touch_purchase_row` | `pos:[x,y]` / `cell:[x,y]` / `row` (1-based) / `option` (1-based) / `chip` / `row` ("buy"/"cancel") | #503 REAL-TOUCH TIER: natively an emulated click labelled `qa_touch {real:false}`; on the web runner with `--touch` the driver publishes the WINDOW pixel and Playwright performs a genuine `page.touchscreen.tap` (`qa_touch {real:true}`); an unserviced request FAILS the step -- no keyboard/mouse fallback. Canonical: `mobile_touch_smoke` (native = emulated; `run_web_qa.sh mobile_touch_smoke 9 --skip-export --touch --device=iphone --portrait-entry` = the real-tap run, still EMULATED hardware) |
| `assert_state` | `path`, `equals` or `contains` | see below |
| `assert_save_exists` | `slot` | checks `user://saves/<slot>.json` |
| `assert_settings_file_exists` | — | checks `user://settings.cfg` |
| `assert_audio_bus_send` | `bus`, … | probes an AudioServer bus send |
| `screenshot` | `name` | no-op in headless |
| `combat_autoplay` | `max_turns` (200) | drives AI turns to `combat.finished` |
| `teleport` | `map`, `cell:[x,y]` | debug-only, bypasses doors |
| `install_fixture` | `fixture`, `slot` ("auto") | mid-run version of `fixture_save` |
| `reload_data` | `expect` (true) | GH#278: rebuilds sim from disk JSON via the save round-trip; refuses (toast) in combat/dialogue/consolidation — `expect: false` pins the refusal leg. Canonical: `reload_loop` |
| `toggle_overlay` | — | GH#279: toggles the dev debug overlay (debug builds only); emits `ui_debug_overlay_rendered`/`_hidden`. HIDDEN BY DEFAULT is a pinned contract — never leave it on across FEEL screenshots. Canonical: `overlay_loop` |
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
confirm`. The cursor WRAPS: a mis-sized hub silently selects a WRONG row
instead of timing out, so every hub selection must also assert its
DESTINATION (node text or banked counter), never an index alone (#396).

## Dialogue event order (cost two reds, 2026-08-06)
The order is `dialogue_started` → `dialogue_node` → `ui_dialogue_shown`.
Waiting on `ui_dialogue_shown` FIRST advances the since-cursor past the
hub's own `dialogue_node`, so a later `dialogue_node` pin can never match.
Pin the node first, or use `from_start`.

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
a seed-search task. Register a new canonical once in
`wandering_inn_game/qa/manifest.json` (THE single source of truth parsed by
`ci_sweep.sh`), then run `derive_qa_surfaces.py` and
`scripts/render_qa_notes.py --write`. Per-script routing index:
`wandering_inn_game/docs/QA-SCRIPT-NOTES.md`.
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
- Adding a script without a complete `qa/manifest.json` row or without
  regenerating surfaces and QA notes.
- Authoring a fixture without ever loading it in a run.
- Comparing JSON-parsed coordinate Arrays directly with int cell Arrays.
- Using a cumulative event assertion to prove a repeated post-action emission.
- **A new AUTOLOAD reference inside test_driver.gd breaks a unit test,
  not the driver** — `test_combat_visuals.gd` compiles an
  autoload-STUBBED copy of the driver source (its stub list injects
  `var Game/ObservableBus/... = null`); an arm referencing a new
  autoload (WIDebugOverlay, GH#279) fails THAT compile in CI's unit
  job while every QA run stays green. Add the autoload to the stub
  list in the same commit as the arm.
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

## Boot-time user-dir behavior: the `legacy_seed` hook (#111, 2026-07-19)
A script proving something that must happen BEFORE the first frame
(autoload _ready ordering — e.g. the rename save-migration) cannot use
driver steps to set it up. `"legacy_seed": "<fixture>"` in the script
root makes run_qa.sh seed a PRE-launch legacy user dir (the
"Wandering Inn RPG v4" app_userdata sibling inside the run's isolated
HOME) with that fixture + a settings.cfg, so Game._ready's migration
runs against real state and the title's Continue proves it. The seeded
path derivation mirrors Godot's own (Darwin vs XDG branch in
run_qa.sh). derive_qa_surfaces treats legacy_seed as a fixture
dependency. Canonical: save_rename_migration.

## v0.15 wave lessons (2026-07-28)

- **Never pin toast ORDER across `combat_started`** — toast holds are
  wall-clock while driver steps are frame-paced, so pre-combat queue
  depth (and therefore post-combat delivery order) varies with host
  frame rate. Pin delivery ("rendered by the time the board closes",
  `from_start` + generous timeout), never sequence. The sewers CI
  flake (v0.15 P1) is the reference failure.
- **Fresh worktrees need `godot --headless --import` before any QA**
  — a warm `.godot` copied from another branch is NOT sufficient;
  `class_name` registration fails silently otherwise.
- **A numeric acceptance gate must state its measurement RULE at the
  table and name a subject it currently fails.** The v0.15 figure-
  height bar shipped green while its own subject failed it, because
  an unstated rule drifted toward whatever passed (FIGURE_ROWS,
  test_combat_visuals — see the P5 fix round). Rule-at-the-table +
  a known-failing control is the antidote.

## Leads rows re-pin lead_lines canonicals (v0.16 close)
Adding `data/leads.json` rows changes the journal's rendered strip in
every fixture state whose counters satisfy the new rows —
`spine_reach` exact-pins `lead_lines` at two opens and went red on the
seven v0.16 rows. Before landing leads rows, grep `qa/scripts` for
`lead_lines` and re-derive each pin from a real run (the growth is the
feature; the payloads double as gating proof for the new rows).

## #398 wave lessons (2026-08-07)

- **New map entities APPEND LAST in the map's arrays** — #397's prose
  pins are POSITIONAL over entity iteration order; inserting a pocket
  door/prop mid-array shifts every later entity's narrator line and
  reds pin files that never mention the new entity. Append-only, and
  re-run the touching prose canonicals when a map gains entities.
- **Toasts COALESCE under queue pressure** — repeated same-key toasts
  merge into one render with an updated count/text, so
  `assert_event_count ui_toast_rendered == N` over a grind loop
  undercounts. Pin the DOMAIN event count; pin toast text only on the
  final coalesced form (reference: #398 gate-refusal loops).
- **Negative reachability legs WALK** — `teleport` bypasses door/gate
  blocking entirely; a "can't get in without the skill" leg must
  bump-move the route and assert `player_blocked`, never teleport +
  assert-absent (proves nothing).

## Rendered-event ≠ seen (GH#324, RESOLVED v0.17 — do not hand-pad)
The "dead render" was never a render bug: windowed capture holds were
eaten by live-tween drain (music crossfade at world_ready), so early
shots caught the line after expiry. Fixed at the driver —
`TestDriver.capture_hold_ceiling_msec()` DERIVES the hold from the
script's own waits, and the crossfade tween is excluded from capture
gating. Consequences for authors: never hand-pad waits "for settle"
(the old ~90-frame workaround is obsolete and hides real timing bugs);
`line_display_ab` is the canonical regression proof (interact at
world_ready+0 must render); `ui_dialogue_rendered` alone is still not
display proof — pair it with a windowed shot or a hold assertion.

## Deletion re-indexes everything after it (2026-08-09, broke a holdout pin)
The append-LAST rule for new entities has a mirror: DELETING an entity
shifts every later index down one, silently breaking every positional
pin ($.entities[N] paths in holdout/keeps/QA payloads) past it. The r4
cottage merge deleted witch_hut_door and a holdout pin two slots later
dangled for two waves until verify-untouched ran again. When an entity
must die: grep the repo for the map's `entities[` paths at HIGHER
indices, migrate each with a recorded path-migration (text asserted
byte-identical), and run verify-untouched IN THE SAME COMMIT.

## Negative legs pin CREATED state; new items pin their tables (2026-08-10)
- A pocket/gate negative leg asserting `player_blocked` on a cell that
  was ALREADY blocked on main is INERT — it passes with the whole
  feature deleted. Pin state the diff CREATED (a new blocked cell, an
  exact rendered blocked-count with a can-fail comment, a perimeter
  walk of new geometry). Prove it: the pocket-deletion mutation must
  red the leg.
- Every new items.json row needs its `test_effect_text.gd`
  EXPECTED_ITEMS pin IN THE SAME CHANGE — the table is exhaustive both
  ways and reds CI, not just local runs. Generalize: grep tests/ for
  every data surface you append to before running gates.

## Continuous steel-thread lessons (2026-08-11 rebuild)
- **New-waking pool line:** the FIRST interact with a pool-carrying NPC
  after any sleep emits only `dialogue_line`. Idiom: interact → wait
  `dialogue_line {speaker}` → interact → wait `dialogue_started`.
  `social_talked` clears ONLY in `sleep()` — same-waking revisits open
  the graph on the first interact across any number of map hops. NPCs
  carrying `dialogue` (not `talk_pool`), e.g. `pisces_seal_escort`, are
  exempt: the graph opens on the first interact even on a fresh waking.
- **Panel-teardown input window:** a press within a closing panel's
  teardown frames (pool-line panel, dialogue end) is silently eaten —
  wait_frames ~30 before the next press. Two reds bought this.
- **`_visible_options` DROPS accomplishment-gated rows** (not "locked");
  only skill/item/gold gates render locked. Count cursor moves against
  the graph JSON evaluated under CURRENT accomplishments.
- **Routing hub rows carry no effects** — banks live on the destination
  node's rows. Pin the destination `dialogue_node` text, then confirm.
  `quest_beat_completed` payloads are 1-indexed, complete in order, and
  only the LAST completed index is emitted; beat events fire
  synchronously BETWEEN an option's own effects.
- **`door_when` short-circuits `on_interact_accomplishment`** — pin the
  open_toast/map_changed, never the accomplishment, on gated travel
  props. Transitions bypass blocking: arrival can land ON a prop's cell;
  step off before re-approaching.
- **`on_victory` story counters bank on the combat DISMISS** (before
  `ui_combat_hidden`); an `end:true` option tears the panel down
  (`dialogue_ended` → `ui_dialogue_hidden`) BEFORE its effects resolve.
- **Worn-accessory abilities are known while worn** (ruling 2026-08-11):
  equips can change the field bar (`ITEM_EQUIPPED` re-render), prop
  skill gates, and dialogue skill gates. Sneak survives door transitions
  only; any non-door interact breaks it.
- **Patch hygiene:** edit scripts with one build-load-append-dump pass,
  `json.dump(..., indent=1)`; RE-READ the file and assert the steps
  landed at the intended indices before running; never print success
  outside the match loop (five phantom "patches" in a row shipped
  no-ops and burned four runs before the miss was caught).
- **The driver continues past failures** — steps after a red run against
  whatever state the failure left (even a defeat-reload), so a short
  failures[] list can flatter a broken run; read the FIRST divergence
  and events.jsonl, not the count. Deliberately-failing `assert_state`
  probes are a cheap state-dump idiom (many unknowns per run).

## Instruments and traps from the balance-program wave (2026-08-12)
- **New driver actions:** `dump_state {label}` (emits `qa_state_dump` to
  events.jsonl in a PASSING run — the sanctioned probe idiom) and
  `dump_checkpoint {slot}` (WISave → user saves + copy-out to
  qa_output/<script>/; refuses in combat/dialogue/consolidation).
  `run_qa.sh --checkpoint-at=N[,N…]` checkpoints an existing script
  WITHOUT editing it (defers past combat/dialogue to the next quiet
  step). `fixture_save` accepts a PATH, so scratch scripts load
  checkpoints straight from qa_output/. Fail-fast: `--fail-fast` flag /
  `QA_FAIL_FAST=1` / `"fail_fast": true` — stops at first failure;
  every failure line now carries a state dump (map/cell/gold/dialogue
  options+cursor/combat roster).
- **The oracle answers before you run:** `qa/oracle.gd` (see
  qa/STEEL-THREAD.md) — `visible_options` (with cursor_index AND
  authored_index + why dropped rows dropped), `path` (BFS → driver-shape
  move steps + bump approach), `state`, `field_bar`, `known_skills`,
  `portal_rows`, `inventory`. Derive dialogue cursors and walk routes
  from it, not from red runs.
- **Worktree trap:** `cd /Users/gabriel/wandering-inn-rpg && godot
  --path wandering_inn_game` silently runs the MAIN repo from inside a
  worktree — verify `git rev-parse --show-toplevel` before any
  godot/qa command in a lane. A fresh worktree/merge also needs
  `godot --headless --import` or new class_names parse-error.
- **`--script` runs:** autoloads exist at `_initialize()`, not
  `_init()`; a failed `assert()` does NOT stop the run and a trailing
  PASS line still prints — only the SCRIPT ERROR grep catches it.
- **Falsifiable dialogue-gate pins:** most hub gates pair a `requires`
  with a `hide_when` on the SAME counter (one row appears, one
  disappears — net row count unchanged). Pin a gate WITHOUT a paired
  hide_when, or pin text, never row counts.
- **`sim_spine_viability` writes its table doc ONLY under
  `WI_SPINE_WRITE=1`** — without it you diff the stale doc against
  itself (cost one phantom ablation). The run's stdout always carries
  the fresh rows; parse the log, or set the env var.
- **Balance doctrine (CHOICE-LOG 2026-08-12):** QA proves
  completability, sims prove balance. Never tune an encounter to green
  an autoplay pin; re-fixture the canonical at/over band instead.
  Tuning target = competent policy at band ∈ [0.55, 0.85]
  (`qa/combat_policies.gd`, `tests/sim_spine_viability.gd`,
  `docs/design/balance-bands-and-policy.md`).


## Suite-authoring lessons (wave >=434, 2026-08-13)
- **`quit(1)` BEFORE `assert(false, ...)`, always.** A failed GDScript
  assert aborts the enclosing function, so an assert-then-quit failure
  path never reaches the quit and hangs to the watchdog (rc 142, 60s)
  instead of failing in 3s. Four suites carried this shape; grep for
  `assert(false` when touching any suite.
- **`godot --headless --script` exits 0 on failed assertions.** Never
  trust rc alone for --script runs — grep `SCRIPT ERROR|FAIL` tokens (the
  sweep's grep is the real red signal).
- **`steel_thread` runs take `--seed` EXPLICITLY, every time.** An
  unseeded verify run fail-fasts mid-run on a combat loss and the cascade
  reads like a late-run desync — a controller burned a full false
  diagnosis on this.
- **VISUAL-LOG appends: check the tail newline first, resolve append
  conflicts keep-both.** Two tail-append collisions in one wave; a missing
  trailing newline glued rows into one line.
