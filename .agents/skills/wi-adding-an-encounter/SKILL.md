---
name: wi-adding-an-encounter
description: Add or rebalance a combatant, arena, encounter entity, roster, or fight.
---

# Add an encounter

Combatants and arenas are data; encounter entities live on maps. Read the
current record and parser before copying a sibling. Decide whether victory
removes the encounter permanently or leaves it dormant until sleep, and whether
parley, allies, or multiple victory accomplishments apply.

Keep tactical readability aligned with mechanics: spawn cells must be valid,
blocked cells must match visible cover, decorations must not obscure the playable
grid, and large field sprites may need combat-only scale. Use distinct art for
functional identities; tint alone does not make two combatants readable.

The batch combat harness is the numerical authority. Run it after any roster,
stat, skill, AI, arena, or combat-rule change and evaluate the current gated and
observational cells from the harness itself. Do not copy historical cell counts
or bounds into task prose. Pay special attention to the actual first-fight
profile even when it is observational rather than gated.

Autoplay uses each combatant’s AI profile. The player record’s empty/default
profile behaves as melee, so autoplay cannot prove a player spell casts. Prove
spell/kit availability through combat snapshot state, and use the batch’s
appropriate build profile for measured caster behavior.

Add or extend a canonical QA route that reaches the encounter through real
gameplay and asserts combat start/finish plus shown/hidden rendering and victory
effects. Read seeds and fixtures from `qa/manifest.json`. After combat data
changes, rerun every combat-touching canonical; investigate changed outcomes and
derive a justified seed/fixture rather than editing one value to get green.

Run data lint, affected content/combat units, balance batch, affected canonicals,
full preflight/sweep, and a windowed readability/playability pass. Read
[references/encounter-schema.md](references/encounter-schema.md) before adding
new record fields or changing AI/respawn semantics.
