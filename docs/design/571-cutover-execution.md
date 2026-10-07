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
   nonblocking. `qa/noise_scan.sh` owns the single exemption; anything else
   still fails.
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
| B: depleted harness + reruns | not started |
| C: martial vault → ending | not started |
| D: worker wall → ending | not started |
| E: caster journey | not started |
| F: imperfect variant + fee list | not started |
| G: Rogue per-fight pins | not started |
