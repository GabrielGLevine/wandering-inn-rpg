# Design Vision — Action-Driven Classes (user, 2026-07-02, for a future milestone)

> Status: **captured, not scheduled.** User-authored vision for the game's core identity
> system; supersedes placeholder leveling rules when implemented. The eventual milestone
> gets a full brainstorm → spec cycle against this document.

## The vision (user's words, structured)

The core of the Wandering Inn is its unique leveling system. Progression is determined by
**what you do**, never by explicit choice:

1. **Action-driven leveling.** No "I want to advance a level in [Mage]" (BG3-style).
   Having gained [Mage], you level it by doing [Mage] things — casting spells in combat.
   Primarily making melee attacks levels your [Fighter]/[Warrior] class instead.
2. **Specialization through behavioral focus.** Focusing on ice spells evolves
   [Mage] → [Cryomancer] (new ice spells + strengthens all ice spells). Fire focus →
   [Pyromancer]. Balanced casting keeps you a pure [Mage] with more powerful generalist
   Skills. Warriors: equipping/using Sword vs Spear leads
   [Warrior] → [Swordsman] → [Blademaster] vs the corresponding [Spearmaster] path.
3. **Non-linear class power scaling.** A Level 5 [Warrior]/Level 5 [Mage] multiclass is
   WEAKER than a pure Level 10 of either — focus is mechanically rewarded.
4. **Class consolidation.** Sufficiently leveled separate classes may consolidate into
   one more powerful class (e.g. [Warrior] 9 + [Mage] 12 → [Spellblade] 14).
5. **Canon-sourced.** Classes and Skills based as much as possible on real Wandering Inn
   classes/Skills (wiki as source of truth).

## Architectural runway (what already points here)

- **Accomplishment counters** (M2) are the exact substrate: action-driven leveling =
  per-action counters (`cast_spell`, `cast_ice_spell`, `melee_attack_landed`,
  `sword_attack`, …) recorded from sim events, driving `classes.json` thresholds.
- **`gained_by` machinery** (M3 T5) generalizes to evolution: an evolved class is a class
  whose `gained_by` requires held-class levels + behavioral counters (e.g. Cryomancer:
  `{class: {mage: 5}, accomplishment: {cast_ice_spell: 30}}`) and which *replaces* its
  parent — replacement semantics are new.
- **Sleep-beat resolution** (canon, shipped) is where leveling/evolution/consolidation
  naturally resolve.
- **The balance harness** is how non-linear scaling gets tuned without a human grinding
  builds: batch matrix over playstyle-scripted AI profiles.

## New machinery the milestone must design (not yet built)

- Combat-action → counter taxonomy (which actions feed which classes; weapon tags on
  attacks; element tags on spells).
- Class evolution (replacement + skill migration + what happens to the level number).
- Non-linear scaling model (per-level stat/skill weight curve).
- Consolidation rules (trigger, level math, canon target classes, player consent beat?).
- Level-by-doing thresholds that respect WI fiction (leveling slows with level; early
  levels fast).
- Interim-rule migration: M3's placeholder mage leveling (`won_combat >= 3` for Mage 2)
  is explicitly superseded by this vision.

## RESOLVED by user (2026-07-02, M4 close — M6 may now be specced/executed autonomously)

1. **Visibility: opaque until sleep.** Sleep beat reveals gains; journal MAY carry
   qualitative, numberless hints ("your sword arm feels surer") — no meters.
2. **Consolidation: offered at sleep.** Once-per-consolidation confirm beat;
   refusable and re-offered at later sleeps.
3. **Multiclass friction: moderate (~20–25%)** behind a pure build at equal total
   levels; consolidation later effectively refunds the penalty (the payoff arc).
   Harness tunes to this target.
4. **Class taxonomy: tight tree (~8–12 playable).** Warrior/Fighter base + 2 weapon
   evolutions, Mage + 2 element evolutions, 1–2 consolidations ([Spellblade]),
   possibly one utility/[Innkeeper]-flavor line. All harness-tunable.

## Original open design questions (retained for context)

- Visibility: does the player see progress-toward-next-level/evolution, or is it
  opaque-until-sleep (more canon, less legible)?
- Consolidation consent: automatic vs offered-at-sleep (canon has characters surprised by
  consolidations; a game may want a confirm).
- Multiclass friction: exactly how much weaker is split leveling (the non-linearity
  curve) — needs harness experiments.
- Canon class list curation: which wiki classes are in the playable taxonomy vs
  NPC-flavor-only.
