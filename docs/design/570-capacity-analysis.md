# #570: capacity analysis before implementation

Analysis date: 2026-10-05. Source snapshot:
`b1c4b02bee71ba0b0926bf1c466ad7eab65a80e6`.
Scope: the approved capacity direction in [#570](https://github.com/GabrielGLevine/wandering-inn-rpg/issues/570)
and the [recovery plan](2026-10-05-persistent-vitals-recovery-plan.md).

**Regenerated 2026-10-08 for #514** ([514-gear-rules.md](514-gear-rules.md)).
The generated block below reads current data: Hedault's trueing lowered his
products' resonance, and the wands carry spell power in place of a weapon
damage point. That block adds a flat spell power column, so `--check`
passes. The prose that follows the block was written against the 10-05
snapshot. It still holds except where a bracketed #514 note says otherwise.

Recommend **4 at creation, 5 after the existing once-only sleep growth** for
the implementation candidate. Actual catalog combinations show a useful
additional enchanted item at each boundary while retaining three accessory
positions and a capacity refusal above five. The catalog analysis and the
bounded diagnostic below are not combat balance acceptance. No game values, item
costs, save rules, physical positions, UI or balance windows change here.
The recommendation is ready for combat measurement; it does not establish
that the larger capacity avoids auto-wins.

## Reproducible catalog measurements

From the repository root:

```sh
python3 scripts/analysis/capacity_570.py
python3 scripts/analysis/capacity_570.py --check
```

The script reads shipped item, Skill and dialogue JSON. It sums accessory
modifiers and resonance and enumerates distinct item sets; it does not call
`equip()`, build combatants or run fights. Flat columns exclude weapon,
armor, class growth and Skill effects. In particular, the HP column does
not include [Tough Body]. Item-granted Skills are unique IDs, not promises
of additional effects when the class already holds that Skill. The shared
authority for interpreting those fields remains
[`WICombatBuild`](../../wandering_inn_game/src/core/combat_build.gd).

**Budget fit alone is insufficient: row J requires four accessory positions
and is always physically refused, even when its resonance fits.** All other
rows use at most three positions. The examples assume resonance-zero weapon
and armor; production capacity counts every equipped position.

<!-- capacity-570:begin -->
| Loadout | Resonance | Accessory positions | Flat HP | Flat damage | Flat spell power | Flat reduction | Item-granted Skills | Budget fits 2 / 3 / 4 / 5 |
|---|---:|---:|---:|---:|---:|---:|---|---|
| A: current shop pair | 2 | 2 | 2 | 1 | 0 | 0 | — | yes / yes / yes / yes |
| B: current pair + Stonescale | 4 | 3 | 2 | 1 | 0 | 1 | [Tough Body] | no / no / yes / yes |
| C: current grown trio | 3 | 3 | 5 | 1 | 0 | 0 | — | no / yes / yes / yes |
| D: shield + two Hedault pieces | 1 | 3 | 5 | 1 | 0 | 0 | [Dangersense], [Eagle Eyes], [Mana Shield] | yes / yes / yes / yes |
| E: earned Lichbone alone | 3 | 1 | 3 | 0 | 2 | 1 | — | no / yes / yes / yes |
| F: earned Lichbone + Fang | 4 | 2 | 3 | 1 | 2 | 1 | — | no / no / yes / yes |
| G: earned Lichbone + pair | 5 | 3 | 5 | 1 | 2 | 1 | — | no / no / no / yes |
| H: earned Anchor + pair | 5 | 3 | 6 | 1 | 0 | 1 | — | no / no / no / yes |
| I: two costly pieces | 6 | 2 | 7 | 0 | 2 | 2 | — | no / no / no / no |
| J: four pieces, budget fits | 3 | 4 | 6 | 1 | 0 | 0 | [Dangersense] | no / yes / yes / yes |

Catalog scope: 24 positive-resonance accessories with a nonzero flat modifier or an ability.

| Capacity | Single items | Two-item sets | Three-item sets |
|---:|---:|---:|---:|
| 2 | 22 | 136 | 0 |
| 3 | 24 | 221 | 680 |
| 4 | 24 | 265 | 1360 |
| 5 | 24 | 275 | 1802 |

Actual dialogue gold debits (excluding travel and prerequisites):

- A: 23g; B: 58g; C: 43g.
- True-Set Wardstone: 56g = 16g bead + 40g fee; Keen-Set Hunters Fang: 49g = 14g fang + 35g fee.
- D: 105g plus the Traveler's Charm acquisition cost plus its 20g upgrade fee.
- G/H: an earned unpriced item plus 23g for the purchased pair.
<!-- capacity-570:end -->

The set counts cover positive-resonance accessories with at least one
nonzero flat modifier or an ability. They exclude zero-resonance pieces and
purely cosmetic positive-cost pieces. Each set contains distinct item IDs
and ignores ordering. These are catalog possibilities, not counts of
simultaneously obtainable, class-useful or balance-approved builds; no
quest, route or mutual-exclusion filter is applied. In particular, duplicate
Skills can make a counted item less useful for a given class.

The table's item IDs are fixed in the script. Names in its row labels mean:
Fang = `hunters_fang_talisman`; Ward/pair = `hedge_ward_charm` plus Fang;
Stonescale = `stonescale_talisman`; Lichbone = `lichbone_wand`;
Anchor = `anchor_sliver`. Row C adds `phosphor_pendant`; D uses
`hedaults_wardstone`, `hedaults_hunters_fang`, `hedaults_traveler_charm`;
J adds `copper_luck_band` to C.

## What changes, and what remains a choice

At current starting capacity 2, row A fits and its third accessory position
cannot accept Stonescale's cost 2. Starting capacity 4 admits row B: one
additional enchanted accessory and +1 flat damage reduction. [Tough Body]
adds 10 max HP only when absent from the class kit; Warrior already grants
it at level 1, so this is not an additional 10 HP for Warrior builds.
This is the strongest simple purchasing witness: all three pieces are sold
by Krshia, with actual debits totaling 58 gold.

At current grown capacity 3, Lichbone alone fits (E) but cannot retain the
Fang or Ward. At proposed starting 4 it can retain Fang (F). The earned
growth to 5 admits Ward too (G), adding 2 flat HP to F. Thus sleep still
buys something tangible. Anchor offers a parallel 3+1+1 witness (H), trading
G's two spell power for one flat HP [#514; the 10-05 snapshot traded one flat
damage modifier]. Existing 3-cost
items become wearable before resonance growth if acquired; this is a real
progression change to measure, not just more room for small items.

Capacity 5 still rejects Lichbone plus Anchor (I: 6, with a third position
free). Three accessory positions also still reject J at capacity 3, 4 or 5.
Increasing capacity cannot retain Stonescale, Fang, Ward **and** Copper
Luck-Band. Dropping the ring can cost [Dangersense] to a class that lacks it.
Likewise Hollow Herb Sachet costs zero resonance, occupies a position and
grants [Witch's Warding] (+8 max HP when not already held). A three-piece
enchanted loadout is not automatically the best use of three positions.

`WIGame.equip()` checks accessory-position availability before resonance;
new refusal QA must leave a physical position free when it intends to prove
the capacity refusal. The function also subtracts displaced weapon/armor
resonance when replacing those pieces. Preserve both rules.

## Real acquisition and price evidence

These are authored routes, not completed playthrough observations. Source
nodes and item grants can be inspected in the linked files. Gold below is
the acquisition debit, without assigning a gold value to travel or combat.

| Item(s) | Existing source and prerequisites | Actual gold debit |
|---|---|---:|
| Fang / Hedge-Ward / Stonescale | [Krshia dialogue](../../wandering_inn_game/data/dialogue/krshia_crate.json), `charms` options 4 / 3 / 5, respectively; sufficient gold | 14 / 9 / 35 |
| Phosphor Pendant | [Wilovan dialogue](../../wandering_inn_game/data/dialogue/invrisil_wilovan.json), `fence` option 0; one purchase via `bought_phosphor_pendant` | 20 |
| Witch's Wardstone Bead → True-Set Wardstone | [Riverfarm witch](../../wandering_inn_game/data/dialogue/riverfarm_witch.json), `shop` option 3, then [Hedault](../../wandering_inn_game/data/dialogue/hedault_enchanting.json), `hub` option 2; consumes the bead | 16 + 40 = 56 |
| Fang → Keen-Set Hunters Fang | Krshia purchase, then Hedault `hub` option 1; consumes the original Fang | 14 + 35 = 49 |
| Traveler's Charm → Warded Traveler Charm | Krshia `shop` option 0 at 5g, or option 6 at 4g after her friendship gates; Hedault `hub` option 0 consumes it | 25 standard / 24 friend |
| Lichbone Wand | [Ruin surface](../../wandering_inn_game/data/maps/ruin/ruin_surface.json), non-respawning `crypt_lich_mouth` victory, chance 1.0 loot; reach the dig and win the optional Lich fight | No purchase; earned, unpriced |
| Anchor Sliver | Same map, cracked plinth container; `pedestal_unsealed`, `rune_sequence_done`, `horns_dig_joined`; granted alongside `anchor_stone` | No purchase; earned, unpriced |
| Graveflame Wand, alternative 2-cost accessory | Wilovan `fence` option 2, requires `brothers_job_done`; one purchase via `bought_graveflame_wand` | 30 |

Row D therefore costs **130g standard / 129g friend** if all base items are
purchased. The resulting catalog price fields (50/45/18) are not these
payments. A found Traveler's Charm reduces the incremental gold needed;
that is not evidence the whole acquisition route is free. Phosphor also
appears as chance-0.3 loot from the sewer Shield Spider Nest; the guaranteed
purchase is used for the reproducible cost comparison. No earned unique's
missing price is converted to a hypothetical shop price.

## Affected class spines and consequences to measure

Skill grants and inheritance below come from
[`classes.json`](../../wandering_inn_game/data/classes.json), with effects in
[`skills.json`](../../wandering_inn_game/data/skills.json). Combat abilities
are folded without duplicate IDs. These are exposure priorities, not
measured win-rate changes or new class requirements.

| Spine family | Why extra capacity matters | Comparison priority |
|---|---|---|
| Warrior → Blademaster / Spearmaster; Spellsword / Spellspear / Deathknight | Stonescale's flat reduction helps while its [Tough Body] duplicates the inherited kit. Extra Fang/Lichbone flat damage can affect repeated weapon hits. | A→B, E→F→G with the spine's actual weapon and allies |
| Mage → Ice Mage / Fire Mage; Druid / Wild Sage | Pure caster paths can gain [Tough Body] from B. Mage level 2 already grants [Mana Shield], inherited by these Mage descendants, so D does not grant a second shield. | B versus cheaper HP/ward combinations; D with the actual held kit and MP |
| Necromancer → Deathknight | Graveflame and Lichbone are accessories in this engine. Capacity admits their defensive modifiers and, since #514, their spell power beside other pieces. | Graveflame+pair (4) versus Lichbone+pair (5), solo and companion routes |
| Archer → Sharpshooter / Scout / Ranger / Skirmisher; Rogue → Infiltrator | D grants [Eagle Eyes] (+8 hit bonus) if missing. Scout grants it at 14; duplicates give no extra bonus. Rogue grants [Dangersense] at 4, Warrior-derived hybrids inherit it. | D versus B/C with ranged/Skill use; do not infer bow behavior from melee autoplay |
| Beast Tamer → Beast Master | More personal defense can change survival while the companion deals damage; caster consolidations also inherit Mage's shield. | B/C with the real companion and earned equipment timing |
| Helper / service / Innkeeper; Trader / Merchant; Runner / Courier; Cook / Chef; Mixer / Alchemist; Diplomat / Emissary; Tactician / Strategist; Hedge Witch / Witch | Equipment can supply combat abilities absent from the class kit. Tactician gets [Dangersense] at 3; Hedge Witch gets [Witch's Warding] at 3. Added equipment must not be assumed to repair progression-route gaps. | Purchased B/D versus zero-resonance ring/sachet choices on the actual spine; include constrained gold and low resources |

[Mana Shield] consumes existing MP one-for-one to absorb damage; depleted MP
buys no absorption. [Eagle Eyes]'s +8 is a hit-bonus input, not a measured
eight-point win-rate increase. Flat damage is an input to the combat damage
path, not a claim that every spell scales with every item. No semantic
ruling for #494/#495, Hedault price rewrite or item-resonance retuning follows
from this report.

## Implementation and acceptance handoff

The baseline has `WISave.VERSION = 9`, starting capacity hard-coded as 2,
load fallback 2 and growth +1. Implement a data-owned base/growth accessor
used by creation, save migration and equip checks. Preserve the live sleep
gate: after `door_awakened`, the second `catalyst_attunement_sleeps` earns
`resonance_grown` once. A day-phase change alone is not sleep. Preserve
partial attunement progress and the grown marker; increasing the baseline
must not replay the growth beat.

Coordinate the composed save version with #566/#568 before coding migration;
this document reserves no version number. Apply the baseline delta +2
exactly once to legacy numeric capacity: 2→4, 3→5, custom 7→9. Preserve
equipped IDs, inventory and growth/attunement history; never clamp valid
custom values to five. Define the missing-field legacy default explicitly
from legacy rules, including fixtures with existing growth history. Modern
saves must round-trip capacity and depletion unchanged. Verify sequential
migrations from each supported predecessor and a second load of the migrated
save. Do not treat every save older than some unrelated recovery migration
as eligible to receive the capacity delta again.

No accessory here has an MP modifier, but HP modifiers and granted
`hp_bonus` Skills affect resource maxima. When composed with #566, test
depleted HP/MP through equip, unequip, replacement, reload and entering or
leaving combat. Changing maxima must follow the shared persistent-resource
policy and must not replenish spent resources by cycling equipment. Include
Stonescale with and without class-owned [Tough Body] and a depleted
[Mana Shield] wearer. Report the selected max-change policy from #566 rather
than inventing a competing one in this slice.

Remaining gates before #570 can close:

1. Implement configuration, accessor, migration, actual sleep growth and UI
   values; prove old/new saves, repeat migration, growth idempotence and the
   two independent refusal cases. No such implementation is in this slice.
2. Use `tests/sim_combat_batch.gd` and `tests/sim_spine_viability.gd` through
   their existing shared combat build/policies. Compare A→B, C→D and E→F→G
   against affected spine encounters at actual acquisition levels, with
   identical seeds/party/difficulty/policy on each comparison. Preserve both
   floor and competent results, HP/MP consequences, win rate and rounds;
   add zero-resonance defensive alternatives where relevant. Submit findings
   to #453/#513; unchanged old cells do not measure the newly admitted sets.
   Retain existing balance windows and report any auto-win as unresolved.
3. Earn or purchase the chosen example items through real gameplay, equip
   through inventory, read used/capacity and attack/Skill consequences,
   exercise capacity refusal with a free position and physical refusal with
   spare capacity, unequip/re-equip, then actual sleep and reload. Capture
   trigger → domain event → rendered confirmation → QA assertion, windowed
   screenshots and the required browser-touch route. Named physical devices
   still require their observations.
4. Run the implementation's prescribed data lint, full units, shared combat
   batch, full canonical sweep and independent review after composition.
   Keep zero-exit, success-marker, noise-scan and QA `result.json` evidence.

## Calibrated combat diagnostic

[#514 note, 2026-10-08: the D/E/F/G win rates below were measured with the
pre-#514 wand and Hedault stats (wand +1 weapon damage, untrued resonance).
They are historical diagnostics, not current values.]

The new
[`sim_capacity_570.gd`](../../wandering_inn_game/tests/sim_capacity_570.gd)
completed **34 cells × 100 seeds = 3,400 fights** on Godot
`4.7.stable.official.5b4e0cb0f`. It preloads the authoritative batch script
without instantiating its SceneTree and calls the existing static `_build_pc`.
Resolution uses `WICombat`; both default (`dumb`) and `competent` policies
come from `WICombatPolicies`. No combat formula or alternative builder is
introduced. The experiment was refreshed on composed art head
`a5b6dee5b1dc91e085d30da7247aa404a5240781`, tree
`86f1881bc6f74918665b507c6d50110598f6abe2`, on 2026-10-06. Art composition
changed catalog bytes; all 3,400 seed outcomes and PC Skill-event counts
nevertheless match the initial run at `7e834e58` exactly.

Four existing batch cells are read directly from its constants:

| Global batch index | Cell / build | Fixed gear and party |
|---:|---|---|
| 115 | `counting_room_guard_t3_warrior10_solo` / `t3_warrior10` | Warrior 10; hunting knife, leather jerkin; solo |
| 86 | `briar_arch_wards_mage11_solo` / `p5_mage11_caster` | Mage 11, caster AI; hunting knife, leather jerkin; solo |
| 125 | `side_vault_construct_t5_infiltrator14_solo` / `infiltrator14` | Infiltrator 14; hunting knife, no armor; solo |
| 67 | `mage3_necromancer3_goblin_ambush_with_skeleton` / `mage3_necromancer3_caster` | Mage 3 / Necromancer 3, caster AI; no weapon/armor; Skeleton ally |

Within each source cell, enemy records, arena, classes, weapon/armor and
party stay fixed. Seeds are 1–100, difficulty multiplier 1.0, no consumables
or preparation. Entry HP/MP is full under the current engine. Only accessory
selection changes. The unarmed companion build receives an explicit empty
weapon ID for variants to enable the existing builder's accessory fold;
its control retains the exact source build. These are counterfactual loadouts,
not proof that the classes can earn and afford those items at these fights.

Each result is **wins out of 100 / upper-median rounds / upper-median PC
end HP / upper-median PC end MP** across all runs, including losses. Control
means the unchanged source build; row letters refer to the earlier catalog
table. The JSON also preserves each seed's outcome and PC `skill_resolved`
event counts, aggregate Skill counts, source/effective builds, source hashes,
rounds histogram and ally downs. Event counts describe exercised policy actions.

| Source index | Accessories | Default policy | Competent policy |
|---:|---|---|---|
| 115 | control | 38 / 4 / 0 / 0 | 53 / 4 / 2 / 0 |
| 115 | A | 38 / 4 / 0 / 0 | 53 / 4 / 2 / 0 |
| 115 | B | 65 / 4 / 4 / 0 | 69 / 4 / 9 / 0 |
| 115 | E | 68 / 4 / 5 / 0 | 70 / 4 / 9 / 0 |
| 115 | F | 76 / 4 / 8 / 0 | 77 / 4 / 15 / 0 |
| 115 | G | 80 / 4 / 10 / 0 | 82 / 4 / 17 / 0 |
| 86 | control | 38 / 4 / 0 / 0 | 9 / 5 / 0 / 0 |
| 86 | A | 38 / 4 / 0 / 0 | 9 / 5 / 0 / 0 |
| 86 | B | 66 / 4 / 10 / 0 | 60 / 5 / 7 / 0 |
| 86 | C | 49 / 4 / 0 / 0 | 40 / 5 / 0 / 0 |
| 86 | D | 61 / 4 / 4 / 0 | 47 / 5 / 0 / 0 |
| 125 | control | 61 / 3 / 5 / 0 | 73 / 3 / 12 / 0 |
| 125 | C | 76 / 3 / 15 / 0 | 86 / 3 / 17 / 0 |
| 125 | D | 89 / 3 / 19 / 0 | 96 / 3 / 21 / 0 |
| 67 | control | 62 / 4 / 19 / 0 | 46 / 4 / 0 / 0 |
| 67 | A | 67 / 4 / 20 / 0 | 54 / 4 / 5 / 0 |
| 67 | B | 86 / 4 / 33 / 0 | 73 / 5 / 21 / 0 |

No sampled cell won all 100 seeds. That does not establish a no-auto-win
guarantee. Infiltrator D's 96/100 competent result is a balance risk for
follow-up, not permission to widen a band. Mage policy outcomes differ:
caster default AI also casts spells, so “default” must not be described as
universally basic-attacks-only. Capacity does not repair every policy/build
weakness; the Mage D result is still 47/100 under competent policy.

Additional comparisons for #453/#513: counting-room default-policy variants
F (76/100) and G (80/100) exceed the existing source row's 71/100 upper bound;
side-vault C (76/100) and D (89/100) exceed its 70/100 upper bound. These are
changed-gear diagnostics, not replacements for the pinned source builds or
permission to widen their windows. C already fits the old grown capacity of
three, so its excess is existing gear sensitivity, not solely an effect of
new capacity. Competent rows here are report-only; the control's 46/100 and
A's 54/100 do not establish a newly introduced competent-gate regression.
Retain these risks when choosing reachable loadouts and interpreting continuous
resource/economy measurements; the proposed curve is not final balance closure.

The composed import and diagnostic completed with zero exit and no
`SCRIPT ERROR|Parse Error|ERROR:|WARNING`; the diagnostic emitted its expected
PASS marker. All four source controls were run under both policies through
the unchanged authoritative batch. **All eight match win rate,
median/min/max rounds and the complete rounds histogram exactly.** Default
batch runs emitted their PASS marker; competent report-only runs emitted
`[policy-sweep] policy=competent complete`. A first composed import with an
existing companion test's missing-UID warning was rejected and rerun cleanly
after Godot recreated that local UID. This is a public-checkout numerical
run, not a private-overlay or visual run.

The smoke tier passed all 15 canonicals, including `load_gate`, with zero
exit, the suite's all-green marker, no error/warning matches and valid
passing `result.json` files. The affected `test_combat_policies.gd` suite
also passed with zero exit, its expected PASS marker and no error/warning
noise. These gates ran at `0cd72ddb9406d6e5dfeceff0868d312e0bf5acea`, tree
`f6bfbe8e7be1f5a6b82dc0826b48de127fa8435a`; only documentation changed after
calibration. Independent review remains before publication acceptance.
No thresholds or pins were changed.
Actual acquisition, runtime equip/refusal, persistent
resource interaction, migration, sleep rendering and touch remain unproven.

Reproducer (choose an evidence directory outside the project):

```sh
godot --headless --path wandering_inn_game --script res://tests/sim_capacity_570.gd -- --report=/tmp/capacity_570.json
WI_CELL_RANGE=115:115 WI_POLICY=dumb godot --headless --path wandering_inn_game --script res://tests/sim_combat_batch.gd
WI_CELL_RANGE=115:115 WI_POLICY=competent godot --headless --path wandering_inn_game --script res://tests/sim_combat_batch.gd
```


## Staged implementation checkpoint

The staged implementation uses four initial Resonance and adds one at the
existing second attunement sleep. `data/progression.json` owns those values;
the simulation, inventory readout and equip gate share the same capacity
accessor. Item costs, prices, three accessory positions and benchmark windows
are unchanged.

Save version 11 adds the historical baseline increase of two exactly once to
valid pre-v11 capacity. Missing legacy capacity uses two, or three when the
existing growth accomplishment is present. Custom capacities are increased,
not clamped downward within the supported range. Capacity is limited to
`2^53 - 1` (9,007,199,254,740,991), the largest universally exact JSON integer.
Legacy values whose +2 increase would exceed this bound are rejected. Modern
saves must carry an explicit nonnegative, finite integral capacity within the
same bound. Invalid initial/growth configuration uses the safe default; growth
stops at the bound. An actual serialize/reparse regression proves the largest
accepted capacity survives migration and subsequent saves without rounding. Rejection precedes
game mutation. Existing earlier schema migrations retain their prior behavior.
The v11 step preserves equipped items, inventory, lore and accomplishments,
as well as present depleted HP, zero MP and potion exposure.

`test_capacity_570.gd` exercises actual simulation equip/refusal verbs, both
physical-full and capacity-full cases, the existing sleep trigger and reload,
legacy migration through versions 2–10, malformed-capacity atomic rejection,
and Stonescale with/without a Warrior's existing Tough Body. Depleted-MP Mage
combat confirms that equipping does not refill resources or fuel Mana Shield.
The focused test and Godot 4.7 import pass with zero exit and no error/warning
noise. Three rejected test-fixture runs are retained separately: one omitted
Stonescale's authored damage reduction, one used an innate skill instead of a
class combat grant, and one supplied modern lore to pre-lore save schemas.
None prompted a combat or earlier-schema migration change.

The existing save test now pins v11 and migrates missing capacity from v10 to
four. The core test pins four initially and explicitly retains capacity two
for its synthetic swap/refusal boundary. The affected save/core suites pass
cleanly on implementation commit `36787975` (tree `058a1993`). Full composed
integration, actual 58-gold acquisition, UI/domain/rendered evidence and
windowed/touch checks remain separate gates; this checkpoint does not close
them. Earlier counterfactual combat measurements remain diagnostics, not proof
of earned gear or sustained resource balance.


The staged QA routes now use actual catalog costs to keep refusal meaningful
under four capacity: Moon Bone (2) plus Stonescale (2) fits; Hedge (1) refuses
with the third position free. A separate three-position-full check uses only
two capacity points and expects the physical-position refusal instead. The
awakening fixture wears Moon Bone (2), then attempts Anchor Sliver (3) both
before and after the existing growth sleep. A further real sleep must retain
five and the single growth event. These fixtures preserve their historical
schema and prove no earned acquisition. Targeted headless checks pass with
seed 9 and production message timing: gear (124 steps), awakening (94), the
shared-fixture journal hints (43), and untouched fresh-start vitals (122).
The final load gate and fixture-coherence suite (209/209) also pass. Each
runtime gate has zero exit, its PASS marker and no error/warning noise; each
canonical has a passing result JSON. Gear ran at `7fa79946`; the remaining
settled checks ran at `f79e4a37`. Only the independent awakening route changed
between those heads. Root-owned windowed/browser verification remains open.

The production toast queue pauses while inventory is open and can replay an
interrupted message. QA captures the panel refusal first, closes inventory,
and then requires the exact rendered toast. It lets earlier equipment/tool
messages drain before the separate physical-full leg. Rejected authoring runs
retain the initial modal-wait and short-queue-timeout failures; no production
holds were shortened to obtain these passes.

For actual acquisition, append the 58-gold purchase leg to a continuous #512
journey with recorded ordinary quest/job receipts and all intervening spending.
Do not infer purse balance from gross catalog payouts or seed the needed gold.
Keep imperfect reward/forced-crate histories; if that declared route cannot
afford the set, record the blocker rather than insert undisclosed wage loops.
Then prove purchase confirmation, depleted-resource equip behavior, a declared
combat consequence, actual sleep/save/reload, and the browser path separately.
