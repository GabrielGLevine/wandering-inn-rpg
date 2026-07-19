# b1 Rags — goblin-conduct audit (2026-07-19, Fable; step 1 of #199)

Factual audit backing the #199 gates. Design + implementation follow.

## Gate (b) — goblin conduct: what banks TODAY

- `goblins_spared` has EXACTLY ONE producer: goblin_parley.json's
  warrior-gated "Stand aside." option (contract comment in that file:
  every future nonviolent goblin route must also bank it). Consumers:
  erin_errand (requires 1), garden_sanctuary gate, shipped_ids (frozen).
- **"(Back away slowly.)" banks NOTHING** — the brief's predicted gap,
  confirmed. A player who avoids every goblin fight non-violently but
  lacks Warrior 1 can have zero mercy signal.
- Parley reachable from TWO maps: floodplains + street encounters
  (conversation-bearing goblin encounters).
- Kill side is FREE since #211: `fought_goblin_encounter_1/2`,
  `fought_goblin_night_patrol`, `fought_chieftains_raid` (integer,
  per-encounter, flag-on) — plus on_victory ids (`sign_defended`,
  `street_cleared`). No new kill counters needed.

Consequence for the design: add 1-2 mercy banks — minimum: the back-away
option banks a new `goblin_left_in_peace` (and per the parley contract
comment, evaluate whether it should ALSO bank `goblins_spared`; the
garden gate treats absence as zero, so widening the producer set changes
garden earn pacing — adjudicate + CHOICE-LOG). Conduct read =
mercy counters vs `fought_goblin_*` sums; threshold data-tuned.

## Gate (a) — Erin relationship: available counters

- erin_errand produces: door_chain_started, has_package,
  reported_cleaning, reward_acknowledged.
- Social system: `chatted_with_erin` (talk-pool counter), meal-beat
  counters, `befriended_moments`. Threshold pick pends the design pass
  (brief: "no new grind" — derive from existing chain).

## Spoiler bar (standing)

Rags early-volume-safe: small Goblin chieftain, Flooded Waters tribe,
wary of Humans, chess with Erin fair game. Never the Vol-9 door name.

## Next steps (design pass)

1. Adjudicate the goblins_spared widening vs a parallel counter.
2. Pick gate thresholds from real playthrough traces (pace harness can
   measure conduct-counter accumulation on the archetype traces).
3. Encounter shape: floodplains south, present_when on both gates;
   parley-first structure (b3's talk-down pattern); quest with
   non-combat resolution path + #211 resolution_grant records for BOTH
   paths (social line for the peaceful close).
4. Rags sprite rides c3 (PixelLab 8-dir walk); encounter ships
   sprite-gated or with a placeholder per wi-art-and-sprites rules.
