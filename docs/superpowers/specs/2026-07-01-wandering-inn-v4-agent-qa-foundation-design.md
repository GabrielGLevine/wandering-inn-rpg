# Wandering Inn RPG v4 — Agent-QA-Native Foundation (M0 Spike) Design

## Context and Decision Record

Playtest round 2 of the v3 slice (2026-07-01) found the entire post-Shield-Spider quest chain
dead from a single load-time parse error (`level_up_toast.gd` extends `CanvasLayer`, which has no
`modulate`) — the **third** instance of a feature passing every automated check while being broken
or invisible in real play. The prior two: a victory trigger that never recorded its accomplishment
(dead quest chain), and a tutorial hint delivered via `print()` (console-only, invisible to the
player).

**North star (user, 2026-07-01): "Baldur's Gate 3, but set in the world of The Wandering Inn,
scaled for a development team of 1" — and [Skills] must be usable outside combat, not just in
it.** Read realistically for a team of 1: a systems-first 2D CRPG — tactical turn-based combat,
skill-based problem solving in and out of combat, choice/reactivity in dialogue and world — not
BG3's cinematic presentation. Depth comes from simulation and data-driven content, not content
volume or art spectacle.

Decisions made with the user (all on 2026-07-01):

1. **Do not patch v2 further.** `wandering_inn_game_v2/` is frozen as a reference implementation.
2. **Rebuild on a vision-scale architecture designed natively for agent-driven QA and
   development** — the QA harness is milestone 0, and the game grows on top of it, so every
   future feature lands already-verifiable by agents without a human in the loop.
3. **Stack: fresh Godot project, engine 4.7.stable** (no GDQuest base; upgraded from 4.6.2 with user approval on 2026-07-01 — the 4.6 pin existed only for godot-open-rpg compatibility, and a greenfield project should start on the latest stable; 4.6.2 kept at `/Applications/Godot4.6.app` for running the frozen v2 reference). Chosen over a TypeScript/Phaser web
   stack: keeps engine features (tilemaps, animation, audio, pathfinding), GDScript knowledge,
   godot-prompter tooling, and the easiest mining of v1/v2 assets — while the agent-QA gap is
   closed via the project's own HTML5 export driven by Playwright in a headless browser.
4. **Combat direction: tactical, positional, turn-based (BG3-inspired; grid-based for
   team-of-1 tractability).** This *supersedes* the earlier "stay on ATB" recommendation, which
   was explicitly conditioned on preserving v2's working ATB engine — a premise the rebuild
   removes. With a fresh build, the north star decides: v1's 25 positional skills and AP-economy
   design become directly usable material rather than a porting liability. Combat is designed
   and built at M1+, **headless-sim-first** (the sim/presentation split means combat rules, AI,
   and balance are developed and mass-tested as pure logic before any combat UI exists — the
   exact de-risking v1's from-scratch attempt lacked). M0 builds no combat, but nothing in M0
   may assume ATB.

## Goal of the M0 Spike

Prove the agent-QA loop end to end on a **walking skeleton** before any real game is built.

Success criterion, stated as a user story: *an agent, unattended, runs a scripted playtest of the
skeleton (move, talk to an NPC, interact with a prop, see a toast), captures screenshots it can
read, asserts on a machine-readable event log and state snapshot, and gets a pass/fail exit code.*

The skeleton's beats deliberately mirror the three historical failure classes, so the spike
demonstrates each would now be caught:

| Historical bug class | How the harness catches it |
|---|---|
| Script parse error surfacing only at runtime load | Script-load gate: a test `load()`s every `.gd` in the project |
| Player-visible message that never renders (`print()`) | ObservableBus contract: assertions read the bus event log, and `print()` is not on the bus |
| Gameplay trigger never calls the state mutation | Scripted playtest performs the *real* interaction and asserts the state snapshot afterward |

## Architecture Principles (the QA-native part — these outlive the spike)

1. **Sim/presentation split.** Game logic (state, quest flags, later combat/progression) lives in
   pure GDScript classes with no scene-tree dependencies → testable headless, mass-simulatable
   (e.g. thousands of seeded combat sims for balance work later).
2. **ObservableBus.** Every player-visible event (toast, dialogue line, level-up, quest beat)
   flows through a single autoload bus that (a) drives the UI and (b) appends to a
   machine-readable JSONL event log under `user://qa/`. Tests assert on the log. UI code never
   bypasses the bus.
3. **In-engine TestDriver.** An autoload, activated only via CLI arg (e.g.
   `-- --qa-script=res://qa/scripts/skeleton_walkthrough.json`), that executes a declarative
   playtest script: `move_to`, `interact`, `choose_dialogue`, `wait_for_event`, `screenshot`,
   `assert_state`, `assert_event`. Runs identically in a native windowed run and in the web
   export. Emits pass/fail via exit code + a JSON result file.
4. **Playwright rig.** Export HTML5 → headless Chromium via Playwright: keyboard injection as
   input fallback, `page.screenshot()` for agent-readable PNGs, and a `JavaScriptBridge`-exposed
   state/event-log snapshot for assertions. Fully headless — nothing pops up on the user's
   machine.
5. **Deterministic seeds.** RNG is injected and seedable from the QA script.
6. **Content is data + code, not editor-authored scenes.** Maps/NPCs/interactions are declared in
   data files instantiated by code, so agents author content in their native medium and the
   hand-edit-a-giant-`.tscn` bug source from v2 is gone.
7. **[Skills] are cross-context, first-class.** A Skill is one data definition with
   context-tagged effects (combat / exploration / dialogue), per the north star's
   skills-outside-combat requirement. "Skill used" is a single domain event on the
   ObservableBus regardless of context. The sim core's state model is built so that
   out-of-combat skill use is native from day one, never a retrofit (v1's data already marks
   `combat_only: false` and contains ~12 non-combat skills — cook, insight, illuminate,
   repair — that become first-class citizens under this principle).

## Spike Phases and Kill Criteria

- **Phase A — walking skeleton + in-engine TestDriver, native run.** One small map, player
  movement, one NPC with one dialogue line, one interactable prop, one toast. The prop
  interaction is framed as an **out-of-combat [Skill] use** (placeholder skill, e.g. the player
  "has" a single skill and using it on the prop records the accomplishment flag) — this
  exercises the cross-context skill pipe (principle 7) from day zero at near-zero extra cost.
  TestDriver walks it, saves screenshots + event log + result JSON. Runs
  windowed via Bash on the user's machine (a brief window popping up is acceptable). *Even Phase
  A alone is a categorical improvement over today's QA.*
- **Phase B — web export + Playwright.** Same script, fully headless. JS bridge for state.
- **Kill criterion:** if the web export can't render/drive reliably under headless Chromium
  within ~2 working sessions, Phase A's native-windowed rig becomes the standing QA loop and
  Phase B is shelved — the spike still succeeds on Phase A.

## Non-Goals (M0)

- No combat, no classes/skills beyond the single placeholder skill, no save/load, no real maps,
  no art, no dialogue system choice (one hardcoded line is fine — Dialogic vs. custom is an M1+
  decision, and the north star raises its stakes: BG3-style skill checks *inside* dialogue may
  favor a custom data-driven dialogue format over Dialogic). No porting of v1/v2 content yet.
- Not a general visual-regression system — screenshots are for agent eyeballs, not pixel-diff CI.

## Deliverables

1. `wandering_inn_game_v4/` — fresh Godot 4.7 project containing the skeleton + harness,
   with its own `CLAUDE.md` (architecture, QA-loop commands, conventions).
2. `qa/` tooling: TestDriver autoload, ObservableBus, script-load gate test, at least one
   passing declarative playtest script, Playwright runner (Phase B).
3. Updated `HANDOFF.md` and root `CLAUDE.md` (new active project, frozen-v2 note).
4. A recorded agent-run playtest: screenshots + event log + passing result, checked in or
   reproduced on demand.

## What Survives From v1/v2 (mined later, from M1 on)

v1's `data/*.json` (78 skills, classes, races, enemies, dialogue), v2's `.dtl` dialogue content
and WI-layer design (WIPlayerState/accomplishments model, PCBattlerBuilder concept, level-by-
sleeping), both prior specs, and the failure-class lessons in `HANDOFF.md`/both `CLAUDE.md`s.
The product constraints carry over unchanged: **no raw stat numbers ever shown to the player**;
lore canon from the Wandering Inn Wiki.
