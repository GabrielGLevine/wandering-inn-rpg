---
name: wi-start-here
description: Route a Wandering Inn RPG task to the smallest relevant guidance set.
---

# Start here

The current user task is authority. Do not inspect the queue or start unrelated
work when the user supplied a bounded task. For “continue project work,” read
the live section of `HANDOFF.md`, then the relevant GitHub issue/PR. Read
`.superpowers/sdd/progress.md` only when it records an active resumable task.

Read `wandering_inn_game/AGENTS.md` for any game change, then select the one
domain skill that owns the task. Use `wi-running-the-machine` for issue
execution and `wi-verifying-changes` before completion claims.

| Task | Skill |
|---|---|
| QA route or evidence | `wi-verifying-changes` |
| QA DSL/fixture | `wi-writing-qa-scripts` |
| Human report contradicts QA | `wi-debugging-playtest-reports` |
| Map/room/door/prop | `wi-adding-a-scene` |
| Enemy/arena/encounter | `wi-adding-an-encounter` |
| Class/skill/progression | `wi-adding-a-class-or-skill` |
| Dialogue/quest/copy | `wi-adding-dialogue-and-quests` |
| Sprite/icon/tile/assets | `wi-art-and-sprites` |
| Windowed player read | `wi-machine-playtest` |
| External PR | `wi-handling-prs` |
| Release/private bundle | `wi-shipping` |
| Delegation | `wi-delegating-to-codex` |
| Usage notification | `wi-usage-guard` |

Existing issue acceptance or an approved design authorizes reversible work in
scope. Ask for a new material taste/canon choice, unresolved scope that changes
the product, or a consequential action outside prior authorization. Record unresolved taste gates
in `HANDOFF.md`; do not guess. Use optional external workflow or Godot skills
only when installed and directly useful.
