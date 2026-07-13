# Region tiers (issue #66)

Content-author-facing copy of the tier table that lives in
`tests/sim_combat_batch.gd`'s own header comment — THAT copy is the
authority (the harness enforces it; this page explains it for anyone
adding a new region/encounter). Keep both in sync.

## The model: fixed tiers, no scaling-to-player

Region rosters are tuned to the build a player is **expected to hold at
first arrival**, never re-tuned to whatever level the player actually is
when they show up. This is canon-hostile with any "scale to player level"
mechanism on purpose — the Wandering Inn's world does not level with you.
A consolidated [Spellsword] wandering back into Liscor and flattening
goblins is progression *feeling real*, not a balance bug.

**Over-tier trivial is INTENDED.** If a build well above a region's tier
steamrolls its rosters, that is the design working, not a gap to close.
The only thing this table exists to fix is the inverse failure: a NEW
region opened at the player's actual frontier failing to press that
frontier build (finding 28 — Riverfarm/Invrisil read trivial at
[Spellsword] 11 because their rosters were tuned against a much weaker
~L10-split build, not because the encounters were ever meant to be easy).

## The table

| Tier | Regions | Expected build | Notes |
|---|---|---|---|
| T1 | Inn / Liscor / floodplains (tutorial + the 3 starter quests) | warrior 1-4 | Existing `goblin_ambush`/`chieftains_raid` cells already band here. |
| T2 | Sewers, the descent, the door chain | 4-7 (first consolidation possible at the tail) | Existing `ENCOUNTER_CELLS`/`BOSS_CELLS`/`RUIN_CELLS` bands roughly hold — reverified by this task, left untouched. |
| T3 | Riverfarm + Invrisil (post-door unlocks) | 8-10, MONO — consolidation no longer reachable here | RE-RETUNED (class-foundation pass R3, issue #96, 2026-07-12) — the earlier "spellsword ~9" reference (issue #66) is now structurally unreachable: [Spellsword]'s consolidation floor moved to level 14 (`min_parent_level` 6→10, `min_combined_level` 13→21, data/classes.json), closing the reachability gap #96 diagnosed (consolidation used to arrive well before either parent's own evolution could resolve). New GATING reference: `BUILDS.t3_warrior10` (warrior 10, the SAME T3 gear basis `t3_warrior9`/`t3_spellsword9` already established) — `briar_collectors_t3_warrior10_hunter`/`briar_collectors_deep_t3_warrior10_hunter`/`hired_blades_t3_warrior10_wilovan` re-derived GATED at this build, landing cleanly inside their EXISTING bands (0.93/0.73/0.75 respectively) with ZERO roster retuning needed. `t3_spellsword9`/`t3_warrior9`-referencing cells are NOT deleted — see "Off-tier baselines" below. |
| T4 | The dungeon (8d) | 10-12 + the Horns party | Bands are derived WITH allies from day one (the 4-ally math) — `BUILDS.t4_spellsword11_party` + `PARTY_CELLS` (`sim_combat_batch.gd`) are the first 4-ally harness cells. 8d C3 (issue #82) landed the windup mechanism + the boss's final tuning: `vault_construct_t4_party` is now GATED (0.55-0.95 win rate, 3-12 median rounds — measured 0.86 / 6); `raskghar_awakened_t4_party` stays the over-tier calibration cross-check, MEASURED-only (a T2 boss vs. a T4 party reads near-1.0, as expected). R3 NOTE: spellsword 11 is ALSO now below the new consolidation floor (14) — same unreachability T3's build faced — but the shipped GATED vault cell stays PINNED to `t4_spellsword11_party` per this pass's own ruling (a working, tuned boss fight isn't re-tuned over a reachability-only floor change). `BUILDS.t4_spellsword14_party` (the genuinely-reachable floor) was added as a MEASURED-only companion (`vault_construct_t4_spellsword14_party`, reads 0.91/5 — the gate still holds comfortably at the real floor too, just not re-gated to it). |
| T5 | Pallass (8e) | 12-14 | Authored to this table at build time — not retuned by this task. |

## What "geared to the tier" means

A tier's "expected build" is a level distribution **plus** the gear a
player can plausibly own by the time they first arrive there — a level-9
PC with an empty inventory is not the same fight as a level-9 PC who
spent gold along the way. `BUILDS.t3_spellsword9`/`t3_warrior9`/`t3_warrior10`
(the last is R3's current GATING reference; the first two are measured
historical baselines) all carry the SAME gear basis:
`gnollish_hunting_knife` (sword-family, so `[Power Strike]` stays
weapon-gated in — a spear would silently swap it for `[Piercing
Strikes]`, which the melee AI profile never calls by name) +
`leather_jerkin` (the mundane-armor-tier ceiling; `watch_issue_gambeson`'s
flat damage-reduction is an equal-tier alternative, not extra headroom) +
`hedge_ward_charm` + `hunters_fang_talisman` (resonance 1+1 = the shipped
capacity-2 ceiling exactly — the same "actual best-case early loadout"
combo `LOADOUT_CELLS`' own `warrior2_max_legal_kit` already established).
Trace a new tier's gear ceiling the same way: read the vendor stock a
player passes on the way to that region (`data/dialogue/*.json`'s shop
nodes), not just the class/level table.

## Gated vs. measured-only

Every gated encounter's win-rate/round band is evaluated **at its own
tier's reference build**. A build below or above an encounter's tier
stays measured-only (recorded, not a contract) — that is what "over-tier
trivial is intended" looks like as a harness rule, not just a vibe:
`sim_combat_batch.gd`'s own `goblin_ambush`/`chieftains_raid` matrix
against `pure_warrior10`/`t3_spellsword9`/`t4_spellsword11_party` reads
near-1.0 on purpose and is never gated.

Not every encounter needs the full gate treatment, though — the T3 retune
pass (issue #66) made three different calls, worth carrying forward as
precedent:

- **The real quest-completion fight** (`briar_collectors`,
  `briar_collectors_deep`, `hired_blades`) gets the full tier gate: retune
  the roster's data (stat_growth-scale numbers, never code) until the
  tier's reference build lands 0.55-0.95 win rate / 3-12 median rounds
  (or an explicit tighter band, same convention `BOSS_CELLS`/`RUIN_CELLS`
  already use for "beatable-but-threatening" fights).
- **A deliberately-dangerous ambush** (`river_wolf_pack`, a NIGHT ambush
  by design, issue #56) stays measured-only even at its own tier's build
  — gating it to a comfortable win-rate band would misrepresent what the
  encounter is FOR. Report the numbers honestly; don't force a band onto
  content whose whole point is a bad-luck spike.
- **A low-lethality safety-net fight** (`alley_footpads`, the "must not
  wall a failed [Stealth] check" contract) keeps its EXISTING low-tier
  gate as the load-bearing one — the promise is to an under-leveled
  player, not to the region's average arrival build — and gets a NEW
  measured-only cell at the tier's reference build simply to confirm the
  over-tier trivial read is exactly what's expected, with no roster
  change at all.

## Off-tier baselines

When a retune moves an encounter's GATING AUTHORITY from an old
pre-tier build (e.g. `warrior5_mage5`, the harness's long-standing
"~L8-12 kit" stand-in) onto a new tier-reference build, the old cell
is not deleted — it loses its `win_lo`/`win_hi` and becomes a measured
historical baseline (labeled `(measured)` in the harness log), so the
before/after delta from a retune stays visible in the same file instead
of being lost to git blame.

## Canonical QA seeds

A roster retune under this table can turn a canonical QA script's
FIXTURE-pinned build (fixtures predate tiers — they field ~L5-10 kits,
not a tier's real reference build) into a loss at its pinned seed. That
is expected, not a regression: re-derive the seed (or the fixture's own
`rng_state`) honestly rather than walking the retune back, UNLESS the
fixture's build cannot win at any reasonable seed — that is a real stop
signal (the roster is stronger than the fixture context allows for) and
should be reported, not silently forced.
