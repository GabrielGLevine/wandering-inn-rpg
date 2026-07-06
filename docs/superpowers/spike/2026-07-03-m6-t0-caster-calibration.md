# M6 T0 — Caster calibration spike

**Date:** 2026-07-03 · **Author:** controller (Opus) · **Type:** calibration spike (no data/sim tuning shipped)

## Question

The balance harness (`tests/sim_combat_batch.gd`) fields the PC with the **melee**
AI profile in every cell. Per the documented autoplay gotcha, the melee profile
never inspects spell skills, so `combat_autoplay` **never casts** — a mage build's
entire measured win-rate edge is its *passive* contribution ([Mana Shield] MP absorb,
extra max-HP/MP from the multiclass), not its *active* spellcasting. Spec §2.4 names
this the **dual-kit confound**: we cannot tell how strong the mage kit actually is
until something in the harness casts the way a player would.

## Method

1. Added a `"caster"` AI profile to `WICombatAI` (`combat_ai.gd`): lead with
   `_act_ranged` (spell/line selection, LoS-filtered, affordability-gated); when no
   spell is castable/approachable this action (mana-dry or no LoS), **fall through to
   `_act_melee`** — close and stab. This mirrors how a human plays the mage kit with a
   melee weapon: cast while you have mana, keep fighting when you don't. It is the
   minimum change that makes an AI-only run exercise active casts.
2. Added a **recorded-only** harness axis: a third build
   `fighter2_mage2_caster` (`ai:"caster"`, `gated:false`). Ungated cells print
   `(measured)` and are **not** subject to the 0.55–0.95 / median-3–12 bounds — this is
   a measurement, not a contract. The PC `ai` field is now threaded from the build
   (`build.get("ai","melee")`), leaving the two gated cells on the melee profile exactly
   as before.

## Result (100 seeds/cell)

| composition      | fighter2 | fighter2_mage2 (melee autoplay) | fighter2_mage2 (**caster**) |
|------------------|:--------:|:-------------------------------:|:---------------------------:|
| goblin_ambush    | 0.82     | 0.91                            | **0.97** (median 3, was 4)  |
| chieftains_raid  | 0.61     | 0.87                            | **0.99** (median 3, was 4)  |

Gated cells reproduced the baseline **byte-identical** (0.82 / 0.91 / 0.61 / 0.87) —
threading `pc["ai"]` did not perturb the melee runs.

## Findings

1. **The confound is real and large.** On `chieftains_raid`, the melee-profile mage
   already reads +26 pts over the pure fighter (0.61→0.87) — almost all of that is
   **passive** ([Mana Shield] soaking hits the fighter eats raw). Active casting adds a
   further +12 pts and drops median rounds 4→3 (0.87→0.99). A player who actually casts
   is far stronger than the melee-autoplay harness ever reported.
2. **The mage kit as tuned would blow the win-rate ceiling if measured actively**
   (0.97 / 0.99 vs the 0.95 gate). This is exactly the calibration signal T0 exists to
   surface. It is a **CONTENT/F-task decision** (raise spell MP/AP costs, soften effects,
   or scale the caster-facing encounters), NOT a sim edit — same disposition as T2's
   absolute-threshold tuning (T6 concern #2). Nothing is tuned in this spike.
3. The caster profile is **dead code under the two gated cells and all shipping QA**
   (nothing fields `ai:"caster"` outside this harness axis), so it cannot regress the
   melee-autoplay contract. It is a measurement instrument.

## Deferred / not done here

- **power_k sweep {1.0, 1.35, 1.7}** — out of this harness's reach. The harness grants
  skills at fixed class levels (`fighter:2, mage:2`) via `granted_skills`; `power_k`
  governs `effective_power = (ΣL_i^k)^(1/k)` which feeds **level-up pacing** (counter
  thresholds), not per-fight win rate. A k-sweep needs a progression-pace harness that
  varies levels, not this combat-outcome matrix. Recorded as a follow-up for the T4
  L^k-scaling task rather than fabricated here.

## Handoff

- Caster profile + measured axis land as a single commit on `main`.
- The active-cast overshoot (0.97/0.99) is the input to the **F-task rebalance** and to
  **M7**'s loadout axis (weapon gate changes which tagged spells are even in the kit) —
  when M7's harness axis lands, re-run the caster measurement per loadout.
