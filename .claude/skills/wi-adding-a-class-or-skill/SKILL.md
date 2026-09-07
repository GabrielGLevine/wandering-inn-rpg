---
name: wi-adding-a-class-or-skill
description: Add, rename, evolve, consolidate, or rebalance classes and skills.
---

# Add a class or skill

Progression is accomplishment-driven and resolves only at sleep. Keep its logic
in pure `WIProgression`; do not duplicate leveling math or expose progress
counts, percentages, or merged-level arithmetic to players. Every action that
produces a leveling counter must also serve an in-world purpose such as feeding,
paying, unlocking, resolving, or surviving; no action exists solely as a level
treadmill.

Before editing, trace the current class, skill, evolution, consolidation, and
dialogue-gate references. Frozen IDs in `data/shipped_ids.json` are permanent
save API. Retire/remap them through `WISave.DEPRECATED_IDS`; do not rename or
change their meaning in place.

Implement content in `data/classes.json` and `data/skills.json`. Cumulative
`requires` values are lifetime thresholds. Evolution-only or consolidation-only
classes start their contiguous level table at the level mathematically reachable
from their source rule; preserve any grant removed with lower rows. Evolution
and consolidation inheritance must deliver grants through the real combat kit,
not just a display list.

For consolidation, enumerate every reachable parent-line pair after evolution
closure. Each pair needs one authored target or a narrowly reasoned exemption.
Ordering is semantic because the first matching row wins; narrow rules precede
broad ones and tests pin both directions. New targets also update derived spine
loadouts. Use `scripts/scaffold_consolidation.py` when applicable, then review
its proposal rather than copying records manually.

When rebalancing a grant, search dialogue/maps for skill gates, display-name
pins, player copy, exhaustive test tables, and hotbar counts in addition to ID
references. Field weapon gating uses the field-specific key; combat `weapon`
changes the combat kit and can strip passives. Any stat/kit/skill change is a
balance change and requires the combat harness plus pinned combat canonicals.

Verify the actual sleep trigger, progression domain event, rendered result, and
the granted skill present in a real combat snapshot. Run data lint, progression/
content/effect-text/fixture/sprite registry coverage as affected, preflight full,
balance batch, affected QA, full sweep, and windowed evidence. Read
[references/progression-schema.md](references/progression-schema.md) before
editing class/skill records or consolidation/evolution rules.
