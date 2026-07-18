# Second Wind wave (#165) — pure-line tables to L16 (spec)

**Authority:** #160 measured funnel finding + user ruling (option 1,
2026-07-17); autonomy directive 2026-07-18 (choices logged, not gated).
Canon research: 16-line workflow sweep 2026-07-18, every skill verified by
an independent adversarial pass against wiki.wanderinginn.com / the serial
text (fandom mirror is fetch-blocked; official wiki is the source of
truth). 16/16 upheld, 0 contested.

## The mechanics (uniform across all 16 lines)

- Every terminal pure-line class extends its sparse table to L16 by
  delta-continuation (GH#54 comment conventions; derive each line's deltas
  from its own last two rows — never guess).
- ONE new grant per line at **L14** (empty rows elsewhere). L15/L16 rows
  are empty — the levels themselves carry stat_growth, which is the funnel
  fix; a second grant tier waits for real content demand.
- Generalist forks: mage's High-Mage (balanced_grants) gains the SAME
  L14-16 table extension on the base mage record so the generalist path
  doesn't fall behind its Replacement siblings; helper likewise.
- Consolidation records untouched (floors, requires_any, tables).

## The grants (canon verdicts in parentheses; citations in the research
journal, wf_e7d76c5f-e6e)

| class | L14 grant | shape | notes |
|---|---|---|---|
| swordsman | [Crescent Cut] (ATTESTED 6.56, Yvlon) | combat: line_damage, sword-gated, ap 3 | the line's first non-mult active |
| spearmaster | [Pierce Thrust] (ATTESTED Vol 7 Gecko interlude, Relc) | combat: line_damage, spear-gated, ap 3 | canon: through-the-target thrust |
| ice_mage | [Ice Wall] (ATTESTED 4.27 H, Ceria/Illphres) | combat: mana_shield (large pool), mp-heavy | the specialist's heavy shield |
| fire_mage | [Flashfire Spellcraft] (ATTESTED, Vol ≤7) | combat: quick_cast | incantation-free flame |
| sharpshooter | [Blinding Arrow] (ATTESTED) | combat: damage_mult ~1.2 bow-gated + applies weakened 1rd | |
| infiltrator | [Shadowstep] (ATTESTED) | combat: move_pool_bonus +2 | blink-flavored repositioning |
| strategist | [Instantaneous Barrage (Phantom Arrows)] (ATTESTED) | combat: line_damage, ap 3, weaponless | ship id `phantom_barrage`, display "[Instantaneous Barrage]" |
| emissary | [Trusted Voice] (ATTESTED) | field/social passive | opens the deepest persuade gates; grep dialogue skill-gates before wiring (GH#64 trap) |
| barmaid | [Server's Prescience] (ATTESTED 5.59, Drassi — gained on barmaid-line inn work) | passive: dangersense | ADJUDICATED: barmaid keeps the attested name |
| server | [Swift Service] (⚑ ORIGINAL — collision adjudication) | combat: move_pool_bonus +1 | Server's Prescience already taken by its sibling; hustle voice |
| merchant | [Evaluation of Wealth] (ATTESTED) | field: value-read ambient (dangersense-key reuse, prose = appraisal) | |
| courier | [Double Step] (ATTESTED) | passive: move_pool_bonus | NOTE: shipped icon_double_step exists (Wave B flash-step family) — check id collision; ship id `couriers_double_step` if `double_step` is taken |
| witch | [Tea Omens] (ATTESTED) | passive: dangersense | omen-read prose |
| chef | [Supplies: Flarepepper Powder] (ATTESTED) | field: at sleep, restock one `flarepepper_powder` consumable (new item, meal-buff shape) | the only new item this wave |
| alchemist | [Perfect Reduction] (ATTESTED 6.39, Xif) | field bench-cast: consumes crude_draught → yields tonic_of_the_clear_eye, banks synthesized_draught | ADJUDICATED: the D-1 "Xif skills are dialogue color only" fence is RELAXED for earned late grants — sharing named skills across holders is canon-normal; the fence protected Wave-D-1 scope, not exclusivity. Economy validator holds (16 > 4). |
| beast_master | [Sworn Fang: Ride Together] (⚑ ORIGINAL — collision adjudication) | passive: +hit while the companion is fielded (PC-side boon injected at roster build, the GH#156 pattern inverted) | research's top pick [Lesser Bond] IS ATTESTED for the line (6.08) but the id is shipped as the tamer's L3 tame verb — renaming shipped ids is forbidden; the researcher's own Redfang-voiced fallback ships instead |

## Audit flag carried from research
[Extended Sweep]/[Spear Flurry] (shipped spearmaster grants) are
wiki-attested only at 8.34 R — past the bar. Shipped ids are frozen API
and STAY; logged here so nobody cites them as bar-clean precedent.

## Verification
Registration matrix (wi-adding-a-class-or-skill) IN FULL — effect_text
pins for every skill AND the new item, combat_data ap/effect, icons ×16
placeholder (PixelLab drain note), sprite-registry pins, seed tables.
Sim: new GATED cells for the six combat-active lines at L14 solo
(band 0.55-0.95); measured cells for passives. `sim_class_paths` re-run:
expect the equal-playtime spellsword margin to compress; the CI funnel
gates must hold. Dialogue-gate grep for emissary/merchant before wiring.
One QA loop (`second_wind_loop`): fixture at L13 near-threshold on one
combat line + one civil line, level to 14 organically, assert grants in
kit; can-fail proven. Whole-wave review before PR.
