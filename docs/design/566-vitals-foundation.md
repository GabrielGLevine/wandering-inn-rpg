# #566 staged resource foundation

The resource foundation runs in `/private/tmp/wi-566-foundation`, branch
`issue/566-persistent-vitals-foundation`, base `b1c4b02b`. It stages persistent resources on the composed integration branch; player-route
acceptance remains incomplete.

## Delivered seams

- `WIVitals` owns saved world HP/MP and MP-potion exposure. World HP is positive;
  MP and exposure can be zero. Finite integer validation accepts JSON integer-valued
  floats, rejects fractions/booleans/strings/negative/out-of-range values, and
  clamps restored HP/MP to maxima derived from current data. Counts cap at
  2,147,483,647; this is a serialization bound, not a poisoning threshold.
- `WICombatBuild.resource_maxima` is the only HP/passive/MP-kit formula used by
  both battle construction and the world projection. Existing numerical fights
  remain fully rested unless the PC configuration explicitly supplies
  `initial_hp` / `initial_mp`. These fields never deplete enemies or companions.
- The player-build preview uses the actual class kit, weapon gate, accessory
  abilities, armor, waking food and room bonuses without consuming preparation.
  Armed `pending_meal` remains a next-fight bonus and does not increase world HP.
- New characters initialize full. Gear changes preserve absolute current values,
  clamp before/after swaps, and never refill on a larger maximum. Sleep refills
  only after waking-buff expiry and class progression/evolution, clearing exposure;
  ordinary clock wrap and travel do neither.
- `snapshot().vitals` / `player_resources()` project live battle HP/MP while a
  fight exists. `WISave` writes the separate world handoff, without active combat
  or derived maxima. Version 10 requires all resource fields; older saves missing
  them initialize full after the restored kit/equipment is applied. Reserializing
  a migrated depleted save preserves depletion. Resource validation runs before
  any mutation; malformed save versions cannot select the legacy-refill path.

## Choices and staging

The resumed composed branch activates carried resources for integration testing.
PR #572 stays draft/unmerged until practical HUD/recovery paths and #571 software
acceptance are complete. No runtime switch, player option or deployment is added.
Pure per-game state and the existing versioned JSON save pipeline remain authority.

`COMBAT_PREPARING` fires after arena validation and before preparation consumption.
An earlier dialogue-choice checkpoint wins over this general entry checkpoint.
Victory commits current PC resources and clamps one-fight maximum expiry before
banking; `COMBAT_RESOLVED` listeners still have the finished combat. Reentrant
resolution cannot bank twice. `COMBAT_SETTLED` fires after combat is cleared.
Defeat never commits zero-HP state; the existing loader restores pre-combat state
and encounter exit grace. Abandon retains its distinct `auto` rollback checkpoint.

Autosaves defer while combat or sleep settlement is active. Sleep retains its early
phase event for the veil, then resolves progression and kit changes before refill,
exposure reset, and `SLEEP_SETTLED`. Intermediate class/phase events cannot save
partially settled state. In-combat day-phase changes cannot overwrite rollback.

`RESOURCES_CHANGED` carries frozen `before`, `after`, `reason`, `source` and
`preparation` dictionaries. Resource projections contain current/max HP/MP and
`mp_potion_doses`; preparation has `armed`, `active`, `well_fed`, and `room_hp`.
Combat actions emit only changed pools; preparation/equipment receipts can emit
with equal pools. HUD rendering and actual player-route proof remain #567 work.

## Remaining integration work

1. Run full current-tree units, canonical QA and the shared balance batch; update
   only deliberate semantic assumptions, never weaken numerical windows.
2. Add actual player-trigger carry/reload/sleep/retry routes with rendered
   confirmations and windowed reads after #567 composition.
3. Compose #568/#569 recovery/count and #570 capacity delivery in migration order;
   complete #571 cutover evidence before merging an activated player build.

## Verification

The new pure contracts cover explicit depleted construction, enemy/companion
rest, shared maxima/passives, equipment cycling, sleep after kit gain/evolution/
leveling, actual phase wrap, current/legacy saves, corrupt resources and versions,
and live-versus-world projection. Existing defaults require full preflight,
canonical QA and the shared numerical balance batch. These prove foundation
compatibility; they do not prove player-facing carried-resource delivery.


## Historical foundation evidence (6d3a0a88)

Implementation source: `6d3a0a883372313a35285e2b6733e9374a73e855`, tree
`d8d77929ec791593e73084d312909c07dd4d4795`; engine
`4.7.stable.official.5b4e0cb0f`. The public checkout was tested without the
licensed overlay. Logs/verdicts live at `/private/tmp/wi-566-evidence`.

| Gate | Observed result |
|---|---|
| `scripts/preflight.sh --full` | 47 Godot unit suites: exit 0, nonempty PASS, zero noise each. Overall exit 1 due to the two Python cases below; 265 Python cases and 43 subtests pass. |
| Final `test_vitals.gd` / `test_vitals_initialization.gd` contracts through preflight's unit-command seam | Exit 0, nonempty PASS, zero noise after adding the sparse-config and literal passive/tactic cases. |
| `wandering_inn_game/qa/ci_sweep.sh` | Exit 0; all 266 manifest routes have passing result.json, nonempty PASS and zero noise, verified individually in canonical-evidence.json. |
| `sim_combat_batch.gd`, default policy | Exit 0, clean PASS across 147 cells × 100 seeds. |
| `WI_POLICY=competent sim_combat_batch.gd` | Exit 0, clean required 4-rung order PASS across 147 cells × 100 seeds. Cell-band FAIL lines are the existing report-only competent-policy output, not an all-bands acceptance claim. |
| Comment census, leak check, diff whitespace | Pass. |
| Independent source review | Approved for this bounded draft at 6d3a0a88; external record `/private/tmp/wi-566-independent-review.md`. No merge/full-issue approval. |

That historical foundation preflight was red on the then-oversized CHOICE-LOG
and four moved source-grant pins. Art composition and the resumed source-pin
updates resolved those blockers. It described no newly activated resource UI;
that statement does not apply to the current carry/sleep/HUD composition.

## Current checkpoint evidence

`03da9ec4` passed `scripts/preflight.sh --full` (exit 0, `PREFLIGHT: ALL GREEN`)
and both 147 × 100 seeded balance policies (exit 0, PASS and zero noise).
Complete logs and per-suite verdicts: `/private/tmp/wi-566-resumed-evidence`.
The competent-policy cell bands remain report-only; the required ladder passed.

Review found that explicit full-rest fields in the shared batch builder froze
pools before downstream spine probes appended their food HP bonus. The builder
now deliberately omits initial pools so `WICombat` derives/rests the final config.
The calibration regression fails on the old builder and passes after the fix,
asserting current HP/MP equal final maxima after the actual post-builder bonus.
The unchanged calibration windows also pass. Evidence: `rested-red` and
`rested-green` under the same evidence root.

The current composed source includes the HUD and visible sleep copy. Actual
carry/heal/reload/sleep route proof and windowed reads are still pending; old
foundation compatibility runs do not establish these new player behaviors.
Composed full gates remain required before #571 activation.
