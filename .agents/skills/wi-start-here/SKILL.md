---
name: wi-start-here
description: Use when starting any session on the Wandering Inn RPG repo, when unsure which project skill applies, or when onboarding to the codebase for the first time.
---

# Wandering Inn RPG — Start Here

## Repo identity (UNIFIED 2026-07-07)
This public repo IS the working repo — every commit is public on push;
there is no sync step. Licensed assets overlay locally via
`scripts/fetch_private_assets.sh`; `scripts/leak_check.sh` is CI job 1.
Details: wi-shipping. The pre-transition private repo (underscored
name) is a frozen read-only archive.

## Read order (every fresh session)
1. `HANDOFF.md` — live state, playtest results, open decisions. **Trust its
   "next step" over your own guess.**
2. `wandering_inn_game/AGENTS.md` — architecture, commands, the canonical
   QA seed table, gotchas. The active project is `wandering_inn_game/` only.
3. `.superpowers/sdd/progress.md` (ledger, gitignored) — tail = exact position.
4. **GitHub Issues/Milestones = the plan** (transitioned 2026-07-07):
   `gh issue list -R GabrielGLevine/wandering-inn-rpg --milestone <name>`
   — each issue body is a dispatch-grade brief (goal/sources/scope/danger
   list/verification/exit). `docs/ROADMAP.md` is a pointer + history.
   `docs/DOC-MAP.md` maps current authority versus archived design records.
5. Run `scripts/usage_status.sh`; it queries and caches the active provider's
   own capacity (Claude CLI or Codex app-server), failing soft when unavailable.
   All providers keep the shared lane and integration discipline.

## Project identity (non-negotiable)
- **QA-first:** every player-visible feature ships with a bus event, a
  `ui_*_rendered` confirmation, and a QA-script assertion. Humans gate FEEL.
- **Stat grammar (default, not a hard ban — softened 2026-07-13):** raw
  STR/DEX/CON/INT/WIS/CHA stay out of player-facing text by default;
  HP/MP/AP/damage numbers are the visible currency. Enforced by
  test_effect_text's tripwires — don't restate it in briefs; clarity
  exceptions allowed (update the tripwire in the same commit).
- **Opaque-until-sleep:** never render progress-toward text (no "3/12 uses",
  no percentages, no merged-level numbers in prompts). Results only.
- **Canon from the wiki** (`wiki.wanderinginn.com` mirror), never invented.
- **Tune data, never sim.** The balance harness is the numbers authority.
- **All work on `main`.** Commit verified units with clear messages.

## Which skill do I need?
| Task | Skill |
|---|---|
| Verify a change / run the gates | wi-verifying-changes |
| Execute a task end-to-end (implement→review→commit) | wi-running-the-machine |
| A human reports a bug QA doesn't catch | wi-debugging-playtest-reports |
| Write or fix a QA playtest script | wi-writing-qa-scripts |
| New map / room / doors / furniture | wi-adding-a-scene |
| New enemy / encounter / fight balance | wi-adding-an-encounter |
| New class, class skill, evolution, consolidation | wi-adding-a-class-or-skill |
| New NPC dialogue / quest / choice gating | wi-adding-dialogue-and-quests |
| Sprites, icons, tiles, asset packs | wi-art-and-sprites |
| An external PR arrives (triage/review/test/merge) | wi-handling-prs |
| Drive the editor/live game via godot-ai MCP | wi-godot-mcp |

## Library governance
`.agents/skills/` is the tracked, model-neutral source. Edit it only with
issue-scoped evidence, then regenerate provider mirrors with
`python3 scripts/sync_agent_guidance.py --write`; CI rejects drift.

## Escalate to the user (never guess)
Design/taste/canon-ambiguity calls, balance-bound changes, anything
irreversible or outward-facing (publishing, licenses, purchases), and any
playtest-feel verdict. Queue in HANDOFF with options + a recommendation.
