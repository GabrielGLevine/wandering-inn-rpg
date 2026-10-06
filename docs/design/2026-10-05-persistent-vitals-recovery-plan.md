# Persistent HP/MP and recovery implementation plan

User-directed roadmap change, 2026-10-05. Planning only: this document and its issues do not claim implemented or playtested gameplay. GitHub #502 and milestones own scheduling. Baseline main: `e1d2edee`; the active #564 art program uses its own branch and remains owned there.

## Approved outcomes and starting recommendations

HP and MP carry across battles. Actual sleep refills them. Inn meals, food made with a relevant held Skill, and inventory food/potions restore resources. Potions work during combat at an AP cost. Excess MP potions cause mana poisoning and HP loss. Exploration shows HP/MP so the player can decide to recover or prepare a buff. Separately, increase resonance capacity to allow more enchanted gear.

The following values and boundaries are implementation recommendations to measure, not additional user rulings:

| Question | Initial recommendation | Reason / alternative |
|---|---|---|
| Combat potion cost | 1 AP | Matches shipped HP-potion cost; a higher new cost would need independent balance evidence. |
| MP potion allowance | Three safe doses per waking; fourth onward restores MP and deals 4 HP immediately | A sleep-bounded saved count prevents starting a new fight from bypassing overuse. Per-battle allowance is the user-selectable alternative. Immediate per-dose damage avoids adding a world-time or turn-time status engine. |
| Poison warning | Preview dose, MP gain and HP cost; explicitly confirm first harmful dose | Informed resource choice; cancel is atomic and free. |
| Lethal ingestion | Normal defeat in combat; refuse a lethal out-of-combat dose in this first slice | World death has no existing resource-death flow; avoid silently designing one. Revisit if requested. |
| Resonance capacity | 4 at creation, 5 after existing once-only growth beat | Permits 2+1+1 then 3+1+1 loadouts under current costs. Measure useful combinations and no-auto-win limits. |
| Physical gear positions | Keep three accessory positions | The requested resonance increase can ship independently of physical-slot/schema expansion. User can select additional positions separately. |

Restoration amounts, service prices and MP-potion price/availability are measured data choices owned by the food/potion and economy issues. Do not present the proposed numeric rules as canon. The [Wiki Mana page](https://wiki.wanderinginn.com/Mana) identifies potion-overuse poisoning; the game-specific safe dose and damage numbers are our tuning proposal. Detailed canon verification at implementation must respect the spoiler cutoff; this plan adds no late-book potion-growth mechanics or named Skills.

## Current implementation and architectural choice

`WICombat._make_combatant` initializes full HP/MP at every construction. `WIGame._build_player_combatant` consumes `pending_meal` into a fight-only HP/damage build, and `resolve_combat` banks outcomes then drops the fight. `WISave` currently saves gear, well_fed and armed meal modifiers but no current HP/MP or potion exposure. `WIItems` accepts healing only in combat for 1 AP; exploration use arms next-fight modifiers. Inventory uses unique item IDs and rejects duplicate pickup, so multiple consumable doses require quantity support.

Use saved pure-simulation resource state owned by `WIGame`, with derived maxima factored into the same shared combat-build math used by runtime and the balance harness. The encounter owns its turn/AP/status state while active; commit the player's terminal resource values before discarding it. Snapshot/view/event adapters expose that state to UI. Reject retaining full-refill encounter state as the permanent player authority: it cannot carry depletion through travel and reload. Do not move resource authority into HUD/autoload nodes or fork the shared formulas.

AP stays encounter-local. Enemy/ally/companion resources stay encounter-local in this scope. Existing field-Skill MP costs and passive regeneration are not broadened silently. A standalone numerical fight can explicitly start fully rested; it is not continuous attrition evidence.

## Resource lifecycle and compatibility

| Trigger | Required behavior |
|---|---|
| New game | Full derived HP/MP, zero potion exposure. |
| Battle entry | Seed PC with carried resources; do not refill. Autosave records resources and armed buffs before combat build consumes preparation. |
| Battle action | Damage, MP spends, existing heals and potion effects use the authoritative live combat resources and event pipe. |
| Victory/finish | Commit terminal PC values once, bank outcomes and return to world with matching HUD. |
| Defeat/abandon | Preserve current checkpoint rollback/exit grace; restore exact saved resources, exposure and inventory. No automatic full heal or new death penalty. |
| Transition/dialogue/day-phase wrap | Preserve resources/exposure; day wrap does not count as sleep. |
| Actual sleep | Expire waking effects, resolve class/Skill/max changes, then refill to resulting maxima and clear potion exposure; notify/render and save coherent state. |
| Equip/max change | Preserve absolute current values; clamp on reduced maxima and do not raise current values on increased maxima. Gear swapping alone never heals. |
| Eat/use potion | Apply explicit advertised restoration, clamped to max; preparation is a distinct effect with a visible duration. |
| Meal buff activation/expiry | Retain existing strongest-per-key caps and one-fight scope; consume and expire at the correct boundary, reconcile/clamp maxima, and show an honest receipt. |
| Legacy save import | Initialize absent resource fields full once; legacy held consumables have quantity one; migrate capacity delta once. Modern depleted saves round-trip depletion/exposure. |

Save validation covers finite integer/range/count fields, corruption transactionality and versioned composition. Keep combat unserialized and inventory/quest/equipment identity stable. Explicit stackable-consumable counts need all pickup/shop/dialogue/loot/cook/use/sell/handover paths reconciled; do not rewrite the entire equipment inventory.

Existing #432 meal caps prevent modifier stacking, not repeated recovery from a freely usable kitchen. Preserve approved repeatable station access, no resale spigot and capped restoration; measure its new recovery role before proposing ingredients/cooldowns. Preserve existing [Basic Cooking], [Advanced Cooking] and [Signature Dish] gates. Ordinary non-cook Inn/rest access must be reachable before low resources can trap the player. At least one food/service route restores HP and one restores MP, without promising that every ordinary dish restores both.

## Issues and ordering

| Issue | Deliverable | Prerequisites |
|---|---|---|
| #565 | Program tracker and complete acceptance map | All children, including cutover; never dispatched as a duplicate implementation |
| #566 | Resource state, maxima, combat handoff, sleep and save migration | Ready for staged implementation |
| #567 | Exploration vitals, buffs, receipts and poisoning preview | #566 |
| #568 | Consumable quantities, inventory/combat recovery, AP and exposure | #566; presentation coordinated with #567 |
| #569 | Real Inn service and held-Skill cooking → food → eat | #566, #568; receipts via #567 |
| #570 | Larger capacity and loss-proof legacy migration | Independent capacity slice; compose max-resource checks before final routes |
| #571 | One composed tree, continuous attrition evidence and activation | All deliveries plus #512/#513/#453/#515; no dependency on human #516 |

Core/save/inventory files overlap: one mutating owner per worktree, or separate worktrees with exclusive non-overlapping ownership and serialized integration. The active #564 UI/icon/art paths are not available to a second writer. Future Godot implementation must load the matching domain skill; planning does not implement a Godot system.

Use a composed issue integration branch, or one temporary internal rollout switch defaulting to legacy behavior until all practical recovery/HUD paths are ready. Keep it out of player product choices. Remove it at cutover after the settled composed software evidence passes; no permanent dual rules and no persistence-only published build.

## Roadmap accommodation

This is a substantial M2 scope addition. It displaces generic pacing/gear/journey final acceptance until the recovery foundation exists, rather than adding work to M4 after old full-refill balance has already been accepted. Existing M1 physical/human observations stay attached to their original candidate; new changed-build parity evidence is collected in M2/M5. Finish an owned #564 safe checkpoint before conflicting mutations. Independent preparation can continue while M1 devices or #494/#495 rulings are unavailable.

| Existing owner | Change |
|---|---|
| #512 continuous journeys / #438 caster route | Add carried HP/MP, real casts, food/potion acquisition, dose/exposure and rest ledgers. Final results consume the new delivery children. Compiler completion is still not an invented route-authoring dependency. |
| #513 economy / #453 numerical balance | Count food/potion/rest costs and reachable poor-player recovery. Keep full-rest tactical baselines separate from continuous depletion. Retain current windows and no-auto-win rules; surface exceptions before unauthorized tuning. |
| #515 routine regression | Register bounded carried-resource and recovery journeys using #512, not a second itinerary/compiler. |
| #494/#495/#514 gear semantics | Capacity expansion is authorized separately. Existing semantic decisions remain unresolved; #514 consumes the larger curve and the shared max-resource contract when implementing selected rules. |
| #516 M2 gate | Add composed cutover plus human understanding of low resources, food, AP and poisoning on desktop and both named phone targets. |
| #517/#518/#520 M3 homecoming | Move mechanical Inn recovery into M2; leave character/relationship/homecoming stories in M3 and reuse the service seams. |
| #521/#522/#523/#526 M4 tactics | Design and validate depletion, potion AP and poison counterplay on the new baseline; final presentation/integration follows cutover. No universal full-rest encounter assumption. |
| #525 extraction | Preserve resource/recovery contracts during later architecture work; do not extract overlapping inventory/core code mid-cutover. |
| #530 M5 release | Add resource/count/exposure migration, mobile save transfer and complete changed-build route regression to existing release acceptance. |

No new milestone, dates, release tag, deployment, region, hunger system, potion-resistance progression, or wholesale engine rewrite is committed. #347 and paid-distribution gates remain deferred. #494/#495 do not block independent recovery/capacity preparation.

## Proof and cutover gate

Pure/save tests cover carry, caps, max changes, migration, stock/AP/exposure atomicity, threshold boundaries and rollback. Actual earned QA covers two successive fights without sleep; low HP/MP reload; sleep after progression; a poor non-cook at the Inn; held Skill → station → acquired food → inventory eating; repeated owned MP potions in and out of combat; warning/cancel/refusal; equip-toggle and repeat-kitchen negatives.

Run full required units, canonical sweep, shared batch and affected pinned-seed routes after composition. Update affected goldens deliberately, retaining event/checkpoint/tail guarantees; logical tests and runtime comparator claims stay distinct. Report input resources, gear, kit, actual potions and policy for numerical rows. No fixture top-ups, ideal-spend steering or unreported farming in continuous evidence.

Every player-facing behavior needs the actual trigger, domain event, rendered confirmation, asserted resource result and a windowed read. Use production timing, exported browser touch and explicit source/export/browser/host identity. Physical iPhone Safari/Android Chrome and unfamiliar-player verdicts remain #516/#530 human gates; no unchanged M1 baseline or mouse-only proof substitutes for them.

This planning task completes when issue bodies, dependencies, readiness labels, milestone outcomes, #502 and local pointers agree. Implementation and gameplay acceptance remain open in the new delivery issues.
