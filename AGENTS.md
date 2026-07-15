# AGENTS.md

This file provides model-neutral guidance to development agents working in this repository.

## Session bootstrap ("Continue project work")

**This PUBLIC repo is the one working repo** (unified 2026-07-07 —
every commit is public on push; there is no private working copy).
A fresh session positions itself in this order:
1. This file, then `wandering_inn_game/AGENTS.md` (architecture,
   commands, canonical QA seed table, gotchas).
2. **The GitHub board is the work queue**: `gh issue list -R
   GabrielGLevine/wandering-inn-rpg` (milestones = the roadmap ladder;
   every issue body is a dispatch-grade brief; the Projects board is
   the kanban view). Route execution through the `wi-*` skills in
   `.agents/skills/` — start with `wi-start-here`.
3. `HANDOFF.md` — the living cross-session state doc (tracked): open
   flags, playtest checklists, taste-queue for the user. **Keep it
   updated as work progresses**, not just at session end. **It is
   current-state, NOT a changelog — trim the tail regularly** (drop
   dated session-close/milestone/wave entries once they're shipped and
   in git; keep only genuinely-live sections + the Commands/env footer).
   Left unpruned it accreted to 1296 lines / 78KB loaded every session
   (pruned 2026-07-12); git history is the archive, so delete freely.
   Never leave inline-code file paths wrapped across lines.
4. `.superpowers/sdd/progress.md` (gitignored ledger) — exact
   mid-milestone position, if present.
Then: pick up the highest-priority unblocked issue (respect
taste-gate/USER-SESSION labels — those wait for the user) and run the
wi-running-the-machine cycle.

## Repo Layout

- **`wandering_inn_game/`** — **the active project; all current work happens here.** A fresh Godot 4.7 build designed QA-first for agent-driven development: pure sim core, ObservableBus event log, declarative QA playtest scripts (`qa/run_qa.sh`). Has its own `AGENTS.md` — read it when working here.
- **`docs/superpowers/specs/`** and **`docs/superpowers/plans/`** — design specs and implementation plans per milestone, written via the `superpowers:brainstorming` → `superpowers:writing-plans` → `superpowers:subagent-driven-development` skill chain. Read the relevant spec/plan before significant changes.
- **`potential_assets/`** — user-sourced asset packs, gitignored (licenses forbid redistribution — NEVER track; parked as `potential-assets-vN` on the private assets repo; restore via `scripts/fetch_potential_assets.sh`).
- **Predecessor history**: the pre-transition private repo (`GabrielGLevine/wandering_inn_rpg`, underscores) is the frozen archive — full history incl. licensed assets; never make it public. v1/v2 game predecessors live in ITS history only.

## Licensed assets & secrets (the unified-repo discipline)

- 160 licensed asset paths (see `wandering_inn_game/assets_manifest.json`)
  are NOT in this repo — local dev overlays them via
  `scripts/fetch_private_assets.sh` (game boots on committed
  placeholder fallbacks without them). They're covered by a GENERATED
  `.gitignore` block; `scripts/leak_check.sh` runs first in CI and
  fails the build if any is ever tracked. New licensed asset =
  manifest entry + ignore-block regen + bundle release FIRST (see
  wi-shipping skill).
- API keys: `docs/*_api_key.txt`, gitignored, local-only —
  `docs/SECRETS-SETUP.md` documents provisioning. Actions secrets live
  only in release.yml.

## Working Conventions (apply repo-wide)

- `main` is the integration branch and there are no long-lived feature branches. **Worktree lanes ARE allowed** (user directive 2026-07-06; see the `wi-running-the-machine` skill's hardened merge rules): parallel execution lanes may run in isolated worktrees (`Agent isolation:"worktree"`) when their surfaces are disjoint, and the controller merges + re-gates on `main`. Maps live in `data/maps/<region>/<map>.json` (issue #100 split) — content lanes touching different region dirs are genuinely disjoint; only same-region map edits still serialize.
- **Issue closes go through a PR** (user directive 2026-07-15): work an issue on branch `issue/<n>-<slug>`, open the PR with `.github/PULL_REQUEST_TEMPLATE/issue-close.md` filled (choices made, validation evidence, player-visible proof, new agent context, deferrals), squash-merge after CI + review. The PR body is the durable per-issue record — HANDOFF.md stays current-state only (RUNNING/QUEUE/flags), and future sessions read `gh pr list/view` instead of raw commit history. Non-issue housekeeping (HANDOFF edits, VISUAL-LOG drains, ledger, typo-class fixes) may still commit direct to main. Lanes merge into the issue branch; only the PR merges to main.
- **Comment economy:** keep compressed traps, contracts, constraints, ordering dependencies, and payload shapes. Delete provenance, review stories, code restatement, and duplicated rationale. `scripts/comment_census.py --check` enforces GDScript ≤20% comment lines and game-data `_comment` text ≤15% of JSON characters.
- Lore/canon reference (character names, races, skills, locations) comes from the Wandering Inn Wiki — treat it as source of truth when adding new content, not invented flavor.
- **Stat grammar (softened 2026-07-13, user directive):** the game's visible currency is race, class, level, [Skills], HP/MP/AP, damage numbers, and gear; raw attribute scores (STR/DEX/etc.) stay out of player-facing text *by default*. The convention is baked into the core (`test_effect_text`'s visible-currency tier + forbidden-vocab tripwires enforce it), so it does NOT need restating in briefs, issue templates, or reviews — and sensible exceptions for item/description clarity are allowed when diegetic phrasing would genuinely be worse (update the tripwire in the same commit). Spirit stands; the hard ban does not.
- When implementing Godot systems, check for a matching `godot-prompter:*` skill before writing code (dialogue-system, resource-pattern, scene-organization, godot-ui, godot-testing, ability-system, etc.) — this repo uses GodotPrompter alongside Superpowers; the workflow skill (brainstorming/planning/subagent-driven-development) governs *process*, GodotPrompter skills govern Godot-specific implementation patterns.

## Commands

Each Godot project is run independently — there is no repo-wide build step or package manager. The installed engine is **Godot 4.7** (`/usr/local/bin/godot`).

```bash
# Run the active game (from repo root)
/usr/local/bin/godot --path wandering_inn_game

# PRIMARY verification tool — declarative agent playtests
# (per-script canonical seeds + full script table: wandering_inn_game/AGENTS.md)
wandering_inn_game/qa/run_qa.sh load_gate headless
wandering_inn_game/qa/run_qa.sh combat_walkthrough headless --seed=9   # or `windowed` for screenshots

# Headless parse/smoke check
/usr/local/bin/godot --headless --path wandering_inn_game --quit

```

See `wandering_inn_game/AGENTS.md` for the QA-loop conventions.

## Provider and handoff contract

- Roles, not model names, govern work: controller, implementer, reviewer, and
  Git/windowed-QA operator. One person or agent may hold several roles.
- Every in-progress handoff records issue, branch and base SHA, owned files,
  verification already run, conflicts/dirty state, operator needs, and the
  exact next action.
- Discover capabilities per session. Never assume an agent can write `.git`,
  access the network, or open a window solely from its provider/model name.
- Usage telemetry is provider-scoped: Claude uses its CLI/cache; Codex queries
  `account/rateLimits/read` through the local app server. Either fails soft
  without borrowing the other provider's limits. All providers still obey the
  shared no-overlapping-writers and integration-gate rules.
- Codex (gpt-5.6-sol) delegation: Codex implements, the controller verifies/
  merges — Codex never self-attests verification. Guardrails + audited failure
  modes live in the `wi-delegating-to-codex` skill; briefs carry numbered
  acceptance criteria and closes are gated against the issue-close PR template.
- The tracked `.codex/hooks.json` is Git-root-safe and requires one-time review
  via `/hooks`; trust its exact definition only after inspecting it.
- `.agents/skills/` is canonical. `.claude/skills/` is generated by
  `scripts/sync_agent_guidance.py`; CI rejects drift.

## Cross-Cutting Gotchas (apply across projects in this repo)

- **`@tool` does not inherit to GDScript subclasses.** Every subclass of an editor-time-aware base class (`Interaction`, `InteractionTemplateConversation`, etc. in v2) needs its own `@tool` annotation, even if the parent has one. Missing this has caused real bugs more than once.
- **A resource/scene ext_resource id being declared does not mean it's wired to anything.** When cleaning up or reviewing `.tscn` files, grep for actual usage (`animation_scene = ExtResource(...)`, `script = ExtResource(...)`), not just the declaration line — orphaned declarations from removed content accumulate.
- **A unit test calling a state-mutation method directly does not prove the real gameplay trigger calls it.** E.g. a test calling `WIPlayerState.record_accomplishment(...)` directly can pass while the actual combat-victory/interaction code path that's supposed to call it is missing entirely. Scene-contract tests should assert the *wiring* (does the relevant node's script reference the code that performs the real call), not just that the underlying method works in isolation.
- **Passing tests and headless clean-parse do not prove a feature is visible/usable to a player.** Toast text, dialogue triggers, and hint text can be logically correct but never rendered (e.g. a stray `print()` instead of an on-screen UI call) or visually indistinguishable from other content (e.g. reusing another character's exact sprite for a new prop). When adding anything player-facing, check what a first-time player would actually see, not just that the code executes.
