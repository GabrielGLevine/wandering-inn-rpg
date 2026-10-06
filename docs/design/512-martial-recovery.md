# Martial walked recovery (#512)

The fresh seed37 martial route now walks to the existing free Inn bed after
six wins and returns to defeat the Awakened boss. It stops at the next actual
combat wall: a fully rested vault party loses in round7. This is bounded core
recovery evidence, not a full journey pass or an ending claim.

## Source and scope

Branch `issue/512-martial-recovery`, base `f71d8e8c`; source checkpoints
`cd426005` (walked detour), `fe7922dc` (exact receipts and fresh greeting).
The original2582 operations/assertions remain in order, with116 inserted steps
(total2698) and one stale comment corrected. No production/data/gear/food/seed/
funds/enemy changes, injected state, checkpoint loads or tactical search.

The detour starts after original661, Deep Tunnels(8,3), following the scout
victory. It reuses deep_descent46–64,76–94,104–142: exit through sewers/street,
walk the floodplains to the Inn, use Your Bed upstairs, then return to(8,3).
Its fixture-only road ambush is omitted because this fresh martial history
already permanently removed that encounter. The route asserts this retirement.

| Trigger | Observed state/result |
|---|---|
| Six wins, before retreat |4/49HP,0/13MP;12gold;four sleeps;Warrior9/Mage4|
| Actual free bed interaction |Fifth sleep;49/49HP,13/13MP;levels/gold/stock unchanged|
| Rendered recovery receipt |`Rested: HP 49/49 (+45), MP 13/13 (+13).`|
| Walked return/boss entry |49/49HP,13/13MP;no intervening combat or purchase|
| Awakened boss |Victory round4;26/49HP,0/13MP;seventh victory|
| Zevara after recovery sleep |Fresh-waking ambient cistern line, actual teardown, second interaction opens report graph|
| Existing sixth sleep |Full42/42HP,14/14MP|
| `vault_boss_slot` |Entry42/42HP,14/14MP;party loses round7;construct46/220HP;17gold|

The inserted sleep resets Zevara's talk pool. Original731 expected the graph
on the first interaction because its comment assumed the same waking as the
summons. The scoped correction hears the observed line and interacts again;
it preserves the existing report choices. Exact numeric domain, settled,
rendered recovery, return-state and boss-entry/outcome pins cover the detour.

## Validation and limits

Official Godot4.7.stable.official.5b4e0cb0f, headless, isolated fresh user dir,
seed37. All185 private overlay payloads came only from manifest paths in the
integration tree; source existence, destination ignore status and SHA256
identity were checked before/after copying. No imported cache was copied and
no asset is tracked. Import and data lint pass; derived surfaces/notes unchanged
and their checks pass. `git diff --check` passes.

Evidence root: `/private/tmp/wi-512-martial-evidence/`.

- `first-rested` with `.log`/`.exit`: cd426005 fresh run fails new828 at the
  fresh Zevara greeting. Rest and boss victory are already observed. Exit1,
  failed result, zero engine errors/warnings. `source-first.json` records source.
- `pinned-rested` with `.log`/`.exit`: fe7922dc fresh run passes the corrected
  greeting and stops at new1009/original893, the vault victory expectation.
  Exit1, failed result, zero engine errors/warnings;1689 later steps unrun.
  `source-pinned.json` records source, command and limits. This is the current
  acceptance boundary, not a clean full-route PASS.
- `load_gate` (2steps) and `combat_abandon` (54steps,seed9): exit0/PASS,
  valid passing results and zero engine errors/warnings. Logs use hyphenated
  names `load-gate.log` and `combat-abandon.log`; `.exit` files match folders.
- `overlay.json`, `import.log`, `lint-initial.log`, `lint-pinned.log` preserve
  environment and structural checks.

The fresh route dumps `checkpoint_martial_rested_return.json` and
`checkpoint_martial_rested_warren_victory.json` for inspection only; it never
loads them. No native window was launched because root retained that lane;
focused windowed proof of these receipts remains pending. No mobile work.

Tree released after this checkpoint. Next owner should review the measured
fully rested vault loss before choosing further core work. No additional rest,
equipment, tactics, balance or whole-endgame adaptation was attempted.
