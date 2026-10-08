# #571 cutover execution

Controller plan and live status for closing #571 (recovery cutover). Branch
`issue/571-recovery-cutover` from main `79177b01`. Governing design:
`2026-10-05-persistent-vitals-recovery-plan.md`. This file replaces a HANDOFF
entry while HANDOFF is at its size cap; update the status table in place.

## Starting facts (2026-10-07)

- Carried HP/MP is already live on main through #578; no rollout switch exists.
  `WIVitals` refills only on new game, actual sleep and legacy-save import;
  combat seeds the PC from `vitals` (`wi_game.gd` `_build_player_combatant`).
  Criterion 7 therefore reduces to proving no legacy full-refill path remains.
- Journeys: Rogue reaches the ending (`journey_rogue`, partial ledger).
  Worker loses six times to `awakened_boss` (`deep_tunnels.json`).
  Martial `steel_thread` (unregistered) loses `vault_boss_slot` once at
  step ~1008 with the construct at 46/220. No caster or imperfect variant.
- Harness: rested-only; `WICombat` already accepts `initial_hp/initial_mp`.

## User rulings (2026-10-07)

1. **#586 deferral:** the exact macOS headless shutdown line
   `ERROR: N RID allocations of type '…DummyShaderE' were leaked at exit.` is
   nonblocking. A later ruling the same day added the two windowed (Metal/RD)
   shutdown variants: `ERROR: N shaders of type ParticlesShaderRD were never
   freed` and the `N10RendererRD15MaterialStorage6ShaderE` RID leak.
   `qa/noise_scan.sh` owns these exemptions; anything else still fails.
2. **Journey walls:** a continuous journey may retry after a defeat (normal
   rollback, as a player would) and take optional side content that already
   exists before the wall. Every retry and detour is logged in the ledger. No
   enemy tuning, no new content, no repeating one fight only for XP.
3. **Caster journey:** author it now inside #571; no transfer to #438.

Standing rules still apply: no balance/seed changes, no fixture top-ups or
teleports in claimed continuous evidence, no relaxed assertions, mobile
evidence reuse per #585, Web parity waivable as a merge bottleneck.

## Lanes

At most two implementation lanes at once, each in its own worktree with the
private asset overlay copied from main and a Godot import before running.

| Lane | Issue | Owns | Output |
|---|---|---|---|
| A tooling | #586/#515 | `qa/noise_scan.sh`, `qa/ci_sweep.sh`, journey tier/budget/report, registration guard | Controller |
| B harness | #453 | `tests/sim_*` depleted-entry report; reruns on main; vault and worker build analysis | Report doc + harness |
| C martial | #512 | `qa/scripts/steel_thread.json` (+ goldens residue) | Ending, per-fight ledger |
| D worker | #512/#513 | `qa/scripts/journey_worker.json` | Ending, ledger, criterion-5 pins |
| E caster | #512 | new `qa/scripts/journey_caster.json` | Ending, casts, MP potions in combat |
| F imperfect | #512/#513 | new imperfect variant script, fee list | Variant + ledgers |
| G rogue pins | #571 | `qa/scripts/journey_rogue.json` | Per-fight pins, low-resource reload |

`qa/manifest.json`, generated notes and goldens are shared: lanes hand back
manifest rows; the controller registers them serially.

## Evidence per journey

Per fight: entry/exit HP/MP, potions used and exposure. Per route: sleeps and
locations, food/rest detours, gear changes, gold in/out, branches, retries and
side-content detours. Fresh new game, real input, no teleport/fixture install.
Windowed read of each journey's key captures at production timing.

## Status

| Item | State |
|---|---|
| A: #586 noise deferral | done `35b0f988` (`qa/noise_scan.sh`, ci_sweep) |
| A: journey tier/budget/report/guard | done: `qa/journeys.json`, `qa/journey_gate.py`, `journey` tier ⊂ `full`, nightly CI job. Measured locally under two concurrent lanes: Rogue 17.8 s (budget 90), Worker 10.4 s (budget 60). Real negative run: wrong checkpoint and registry drop both FAIL. Register martial/caster/imperfect as lanes land. |
| B: depleted harness + reruns | done: report-only `WI_ENTRY_FRACTION` leg, `scripts/harness_entry_report.py`, `571-attrition-measurements.md` (rested PASS; vault 0.85–0.90 → 0.20–0.24 at 75% entry). Surfaced to #453; no tuning. |
| C: martial vault → ending | merged `dec3b309`: `steel_thread` 3134/3134 to `martial_full_ending`, registered (`journey` tier, gate 16.7 s/90 s). Vault: identical retry replays the same seed (rollback restores RNG), so the route wears carried gear and rests at the Inn bed before winning; guardian retried after rest. No-sleep footpad pair + depleted Save/Load pinned. Ledger `571-ledger-martial.md`. Reviewed (early review HOLDS). Windowed log clean under the extended #586 deferral. |
| D: worker wall → ending | merged: `journey_worker` 3998/3998 to `worker_full_ending` (gate 21.9 s/90 s). Awakened wall cleared after one optional Chieftain's Raid (Warrior 2 at sleep); seal warden after optional ruin guardian loot, a cooked meal, owned gear and rest. All 82g mandatory fees paid; Pallass shortfall worked off with Inn chores. Pins: every meal, meal bonus armed/active/expired with clamp, no-heal equip toggle, pause-menu Abandon with exact rollback (no combat-usable item held, so inventory unchanged by design). |
| E: caster journey | merged `b68cda65`: `journey_caster` 3782/3782 to `caster_full_ending`, registered (gate 18.7 s/120 s). Fresh Pisces→[Mage]→[Ice Mage] 14, every fight player-driven (no autoplay), 8/8 wins; road + sewer bats in one waking at 0 MP; 4 bought Mana Potions: 2 in combat at 1 AP, dose 3 safe, dose 4 warning→Cancel→accept −4 HP; pause Save/Load at 21/38, 12/19, 4 doses. Windowed log clean under the extended #586 deferral. Found combat LoS asymmetry (filed separately). |
| F: imperfect variant + fee list | done: fee audit (`571-fee-audit.md`) and `journey_imperfect` 4115/4115 to `imperfect_full_ending` (gate 16.9 s/90 s). Declared imperfect choices: unused knife + handline leave 0g after the catalyst, Coyle exposed, 80g Invrisil one-shots skipped; every later fee earned back from repeatable producers over 4 extra wakings, locked fee rows pinned at 7/13/2g. #513 notes: delivery slips rotate out of the Pallass stretch; delivery gold toast missing; locked fee rows don't show the shortfall. |
| G: Rogue per-fight pins | done: exact entry pins for all 11 fights and exit pins for the 8 wins (19 counts; the 3 defeats enter at full HP, so defeat rollback is proven by `steel_thread`, not here) and an earned pause Save→Load at 10/44 HP, 0/14 MP in `deep_tunnels`; 3509/3509, noise clean. Windowed read done: after the Load the HUD shows `HP 10/44 MP 0/14`. Rogue never fights twice without sleep, so criterion 5 item 1 comes from lanes C/E. |

## Criterion 7: no rollout switch, no legacy refill path

This branch changes no `src/`. Carried HP/MP shipped with #578 without a
switch. `WIVitals.refill` has exactly three call sites:

- new game: `wi_game.gd:228`;
- actual sleep, after the sleep beat resolves maxima: `wi_game.gd:3316`;
- a legacy save that has no `vitals` block: `save.gd:415`.

Combat seeds the PC from carried values (`wi_game.gd:2627–2628`
`initial_hp/initial_mp`). Victory, defeat rollback, transitions and day wraps
do not refill. The journey ledgers show the depleted carries this proves:
- martial footpad pair: entered at 40/49 HP, 0/16 MP;
- caster sewer bats: entered at 0 MP;
- worker meals: eaten at 3/44 HP after a fight;
- every reload pin returns the saved depleted values.

## Criterion map (for the closing PR)

1. Composed tree: `issue/571-recovery-cutover` head; CI's Web export is the
   export identity.
2. Journeys: `571-ledger-{rogue,worker,martial,caster,imperfect}.md`, with
   per-fight entry/exit, sleeps, recovery, gear, gold, reloads and act
   boundaries.
3. `571-attrition-measurements.md` (#453, rested vs depleted, surfaced not
   tuned); `571-fee-audit.md` plus `journey_imperfect` (#513 low gold);
   `poor_retired_producer_recovery` (exhausted producer).
4. Journey gate and `journey` tier (#515). Martial goldens residue is recorded
   in `scripts/itinerary/README.md`; runtime proof is kept separate.
5. Earned items:
   - two fights without sleep: martial footpads, caster road + bats;
   - low-resource reload: Rogue, martial, caster;
   - sleep after progression: caster, all routes;
   - non-cook Inn recovery: free Inn beds on every route are the earned
     recovery; the paid Inn meal service for a non-cook is proven only by
     `meal_service_loop`, which uses real input from a disclosed fixture start;
   - held-Skill cooking then eating: worker;
   - consecutive MP doses across the threshold with save/load: caster;
   - AP cost and Cancel: caster (earned). Refusal comes from fixture scripts
     with real input: full-health no-benefit refusal in `item_use_loop`,
     lethal-dose refusal and settlement in `consumable_poison_defeat`;
   - defeat rollback: Rogue, martial, worker, imperfect;
   - Abandon rollback: worker;
   - buff expiry: worker;
   - no-heal equip toggle: worker.
   Fixture-based negatives remain in `vitals_lifecycle_negatives`,
   `item_use_loop` and `consumable_poison_defeat`.
6. Windowed reads at production timing: each journey's key captures were read
   (listed in each ledger; Rogue's depleted reload shows `HP 10/44 MP 0/14`). Exported browser touch: CI Web registry on the PR head;
   physical devices #516/#585.
7. Above.
8. Linked in the closing comments on #565, #516, #526 and #530.
