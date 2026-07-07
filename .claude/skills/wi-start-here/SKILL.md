---
name: wi-start-here
description: Use when starting any session on the Wandering Inn RPG repo, when unsure which project skill applies, or when onboarding to the codebase for the first time.
---

# Wandering Inn RPG — Start Here

## Read order (every fresh session)
1. `HANDOFF.md` — live state, playtest results, open decisions. **Trust its
   "next step" over your own guess.**
2. `wandering_inn_game/CLAUDE.md` — architecture, commands, the canonical
   QA seed table, gotchas. The active project is `wandering_inn_game/` only.
3. `.superpowers/sdd/progress.md` (ledger, gitignored) — tail = exact position.
4. **GitHub Issues/Milestones = the plan** (transitioned 2026-07-07):
   `gh issue list -R GabrielGLevine/wandering-inn-rpg --milestone <name>`
   — each issue body is a dispatch-grade brief (goal/sources/scope/danger
   list/verification/exit). `docs/ROADMAP.md` is a pointer + history. `docs/HANDOVER-FABLE-TO-OPUS.md` §1/§8
   — operating model + hard-won lessons.

## Project identity (non-negotiable)
- **QA-first:** every player-visible feature ships with a bus event, a
  `ui_*_rendered` confirmation, and a QA-script assertion. Humans gate FEEL.
- **Stats hidden:** raw STR/DEX/CON/INT/WIS/CHA never appear in any
  player-facing text. HP/MP/AP/damage numbers are allowed.
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
| Drive the editor/live game via godot-ai MCP | wi-godot-mcp |

## Library governance (user-mandated 2026-07-04)
**Only Fable modifies `.claude/skills/` — never Opus or another model.** If a
session finds a skill gap or error, write the proposed change into HANDOFF.md
(a "SKILL PROPOSALS" note) with the evidence, and leave the library untouched.

## Escalate to the user (never guess)
Design/taste/canon-ambiguity calls, balance-bound changes, anything
irreversible or outward-facing (publishing, licenses, purchases), and any
playtest-feel verdict. Queue in HANDOFF with options + a recommendation.
