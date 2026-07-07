# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo Layout

- **`wandering_inn_game/`** — **the active project; all current work happens here.** A fresh Godot 4.7 build designed QA-first for agent-driven development: pure sim core, ObservableBus event log, declarative QA playtest scripts (`qa/run_qa.sh`). Has its own `CLAUDE.md` — read it when working here.
- **Predecessors are out of the working tree** (v1 and v2 both removed 2026-07-02, user-approved scope-down; recover either from git history if needed — v2 was the GDQuest-based frozen reference, Godot 4.6.2-only via `/Applications/Godot4.6.app`, handoff history in `docs/archive/HANDOFF-v2-v3-archive.md`; `godot-open-rpg/` is v2's gitignored upstream clone, a separate repo, never commit into it).
- **`docs/superpowers/specs/`** and **`docs/superpowers/plans/`** — design specs and implementation plans per milestone, written via the `superpowers:brainstorming` → `superpowers:writing-plans` → `superpowers:subagent-driven-development` skill chain. Read the relevant spec/plan before significant changes.
- **`HANDOFF.md`** — the living cross-session state doc: current state, playtest checklists, next steps. **Keep it updated as work progresses** (not just at session end) — it's the primary handoff between sessions/agents (including Codex). Milestone execution detail lives in the ledger `.superpowers/sdd/progress.md` (gitignored).
- **`potential_assets/`** — user-sourced asset packs, gitignored (licenses forbid redistribution — never commit). Asset plan: `docs/superpowers/specs/2026-07-02-wandering-inn-asset-design.md`.

## Working Conventions (apply repo-wide)

- `main` is the integration branch and there are no long-lived feature branches. **Worktree lanes ARE allowed** (user directive 2026-07-06, supersedes the old main-only rule; see `GOAL-CHAIN.md` and the `wi-running-the-machine` skill's hardened merge rules): parallel execution lanes may run in isolated worktrees (`Agent isolation:"worktree"`) when their surfaces are disjoint, and the controller merges + re-gates on `main`. Content milestones sharing `skeleton_scene.json` still effectively serialize (merge conflicts); only genuinely disjoint-file systems work should pair via worktrees.
- Lore/canon reference (character names, races, skills, locations) comes from the Wandering Inn Wiki — treat it as source of truth when adding new content, not invented flavor.
- **Stats (STR/DEX/CON/etc.) are never shown to the player anywhere in the UI** — this applies across all projects in this repo. Player-facing text/UI shows race, class, level, skills, HP/MP, and gear only. This constraint has been violated by mistake before during review — double-check any new UI or toast text against it.
- When implementing Godot systems, check for a matching `godot-prompter:*` skill before writing code (dialogue-system, resource-pattern, scene-organization, godot-ui, godot-testing, ability-system, etc.) — this repo uses GodotPrompter alongside Superpowers; the workflow skill (brainstorming/planning/subagent-driven-development) governs *process*, GodotPrompter skills govern Godot-specific implementation patterns.

## Commands

Each Godot project is run independently — there is no repo-wide build step or package manager. The installed engine is **Godot 4.7** (`/usr/local/bin/godot`).

```bash
# Run the active game (from repo root)
/usr/local/bin/godot --path wandering_inn_game

# PRIMARY verification tool — declarative agent playtests
# (per-script canonical seeds + full script table: wandering_inn_game/CLAUDE.md)
wandering_inn_game/qa/run_qa.sh load_gate headless
wandering_inn_game/qa/run_qa.sh combat_walkthrough headless --seed=9   # or `windowed` for screenshots

# Headless parse/smoke check
/usr/local/bin/godot --headless --path wandering_inn_game --quit

```

See `wandering_inn_game/CLAUDE.md` for the QA-loop conventions.

## Cross-Cutting Gotchas (apply across projects in this repo)

- **`@tool` does not inherit to GDScript subclasses.** Every subclass of an editor-time-aware base class (`Interaction`, `InteractionTemplateConversation`, etc. in v2) needs its own `@tool` annotation, even if the parent has one. Missing this has caused real bugs more than once.
- **A resource/scene ext_resource id being declared does not mean it's wired to anything.** When cleaning up or reviewing `.tscn` files, grep for actual usage (`animation_scene = ExtResource(...)`, `script = ExtResource(...)`), not just the declaration line — orphaned declarations from removed content accumulate.
- **A unit test calling a state-mutation method directly does not prove the real gameplay trigger calls it.** E.g. a test calling `WIPlayerState.record_accomplishment(...)` directly can pass while the actual combat-victory/interaction code path that's supposed to call it is missing entirely. Scene-contract tests should assert the *wiring* (does the relevant node's script reference the code that performs the real call), not just that the underlying method works in isolation.
- **Passing tests and headless clean-parse do not prove a feature is visible/usable to a player.** Toast text, dialogue triggers, and hint text can be logically correct but never rendered (e.g. a stray `print()` instead of an on-screen UI call) or visually indistinguishable from other content (e.g. reusing another character's exact sprite for a new prop). When adding anything player-facing, check what a first-time player would actually see, not just that the code executes.
