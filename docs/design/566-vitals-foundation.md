# #566 staged resource foundation

This slice runs beside #564 in `/private/tmp/wi-566-foundation`, branch
`issue/566-persistent-vitals-foundation`, base `b1c4b02b`. It does not activate
persistent damage in player fights or satisfy all #566 acceptance.

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

Keep resource authority in the pure simulation and the existing JSON save
pipeline. Node-based Saveable components or a second formula would violate the
current ownership/shared-math contract. A focused RefCounted state object is
per-game, never a shared mutable Resource. HP modifiers stay in the build data;
food restoration will be explicit in #568/#569.

Battle construction defaults to full rest. `start_combat` deliberately does not
supply the saved resource values in this slice, and `resolve_combat` does not
commit terminal resources. This is the integration-branch staging approach from
the approved recovery plan; do not merge/deploy a persistence-only player build.
No HUD, new events, canon, potion thresholds, physical slots or capacity tuning
are introduced here.

## Remaining #566 work after the art checkpoint

1. Wire carried PC initialization and exactly-once terminal commit. Cover damage,
   real mana spends, shields, healing then victory, and all practice/story entries.
2. Preserve an armed-versus-active preparation boundary. The current build still
   clears pending_meal before COMBAT_STARTED. Move pre-combat autosave before
   that consumption, preserving the earlier dialogue-choice checkpoint.
3. Serialize world/combat/event/autosave ownership with #564. Add honest domain
   events, rendered confirmation and actual QA routes without weakening pins.
4. Ensure sleep autosave occurs after the final refill/progression. Current
   PHASE_CHANGED and intermediate CLASS_* autosaves precede that final state;
   this slice does not claim completed autosave ordering.
5. Prove defeat/abandon rollback with the real Game checkpoint loader and exit
   grace. Never carry dead-player state into the world or refill on retry.
6. Compose count/capacity migration with #568/#570 using version 10 as this
   foundation; subsequent schemas need ordered migration, not parallel versions.
7. Add earned two-fight, depletion/reload, sleep, max-buff expiry and retry routes,
   windowed/browser-touch evidence, then full composed acceptance through #571.

## Verification

The new pure contracts cover explicit depleted construction, enemy/companion
rest, shared maxima/passives, equipment cycling, sleep after kit gain/evolution/
leveling, actual phase wrap, current/legacy saves, corrupt resources and versions,
and live-versus-world projection. Existing defaults require full preflight,
canonical QA and the shared numerical balance batch. These prove foundation
compatibility; they do not prove player-facing carried-resource delivery.


## Recorded foundation evidence

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

Full preflight is not green. `test_choice_log_stays_a_decision_index` finds
the untouched base CHOICE-LOG at 31,122 bytes (limit 30,000). The base HANDOFF
also exceeded its 12,000-byte cap; this lane's current handoff is trimmed.
`test_head_tree_findings_are_the_known_set` reports four line-number drifts:
`sworn_fang_boon`, `basic_command_boon`, `pack_bond_boon`, and
`flarepepper_powder`. Repin the actual granting lines after composing the tree.
The shared data-lint validator and CHOICE-LOG are owned by the art lane; this
lane leaves them untouched and records those fixes for serialized integration.
No behavior/fixture/golden/balance assertion was weakened.

There is no new player-visible surface to inspect in this staged slice.
Existing native routes establish compatibility only. Carried-resource gameplay,
new rendered receipts, browser touch, physical devices and human understanding
remain unproven until the follow-up wiring/recovery work lands.
