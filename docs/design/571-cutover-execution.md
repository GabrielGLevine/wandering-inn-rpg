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
| G: Rogue per-fight pins | done: exact entry pins for all 11 fights and exit pins for the 8 wins (19 counts; the 3 defeats enter at full HP, so defeat rollback is proven by `steel_thread`, not here) and an earned pause Save→Load at 10/44 HP, 0/14 MP in `deep_tunnels`; 3509/3509, noise clean. Windowed read pending integration. Rogue never fights twice without sleep, so criterion 5 item 1 comes from lanes C/E. |
