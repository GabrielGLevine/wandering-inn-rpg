# Social Pillar v1 — Rotating Talk + [Diplomat] (DESIGN)

Status: user-ratified 2026-07-05 (4-call brainstorm: both night tracks A→B;
rotating pools + sleep re-arm; [Diplomat]; art authority full-gen+integrate).
Answers Three Pillars P5's audit flag: **social is the thinnest repeatable
pillar — dialogue banks are one-shot.** Executes as night track A per
`NIGHT-GOAL.md`.

## 1. Problem

Combat repeats (encounters re-arm at sleep), exploration repeats ([Observe]
everywhere, field skills), but every social interaction is a one-shot
accomplishment bank. A social build has nothing to DO on day 2.

## 2. Core loop: rotating talk pools, re-armed by sleep

- Selected NPCs gain a `talk_pool`: 2–4 short, canon-voiced topic lines
  (data, `skeleton_scene.json` per-entity or the dialogue file — implementer
  reads where conversation content lives and picks the cheaper seam;
  the POOL is not a full conversation graph, it's one-line flavor + effects).
- **Once per waking, per NPC:** the first talk interaction plays the NPC's
  next pool topic (rotation index = `chatted_with_<npc>` counter % pool
  size — deterministic, zero rng, zero new save-critical state for
  rotation) and banks `chatted_with_<npc>` +1 and `heard_gossip` +1.
  Subsequent talks that waking fall through to the NPC's normal
  conversation graph exactly as today (no double-banking, no pool spam).
- **Sleep re-arms the pools** (mirrors encounter re-arm): a
  `social_talked: {npc_id: true}` sim dict cleared in `sleep()`.
  Save: additive tolerant-default field (used_skills precedent, NO version
  bump).
- NPCs WITHOUT a `talk_pool` are completely untouched — zero behavior
  change for them (QA-compat lever: ship pools ONLY on NPCs whose
  canonical-script interactions are start-of-conversation asserted, or
  re-path in the same task — the plan discloses exactly which).
- Opacity: pool lines are flavor; counters are invisible; NO "2/3 topics"
  or progress text anywhere.

## 3. [Diplomat] — the talk-flavored earned class

- `gained_by`: persuasion — `persuaded_someone ≥ 1` (a NEW unifying counter
  banked by the existing persuade/parley dialogue effects: goblin_parley
  "Stand aside", watch_sergeant crate persuade, + any future persuade
  option adds it as data). If `gained_by` machinery supports multi-key
  thresholds, add `heard_gossip ≥ 3` as the volume gate; if not
  (single-key precedent), persuaded_someone alone gates and gossip feeds
  LEVELS only — implementer traces `check_class_gains`/`_meets` and
  documents which shipped.
- **CANON-CHECK at content time** (wiki.wanderinginn.com): [Diplomat]
  existence/flavor; kit names. Misses escalate with closest-canon fallback
  flagged, never silent invention.
- Kit v1 (2 skills, both reusing EXISTING machinery):
  - **[Friendly Face]** (name canon-checked): field-tagged; on a faced NPC →
    a warmer per-NPC reaction line (data string, observe-seam mechanism —
    P3's `observe` field precedent, separate `friendly_line` field) and
    banks `befriended_moments` +1 (feeds levels; same first-per-entity
    dedup QUESTION as [Observe]'s logged minor — v1 SHIPS the dedup for
    BOTH: bank only first-use-per-entity-per-waking, resolving the TP
    review's M1 for observe at the same seam).
  - **[Calming Words]** (canon-checked): combat, costs AP, applies the
    existing `slowed`-class status machinery re-flavored as hesitation
    (data-defined status, NO new sim effect types).
- Levels 2–6 via chatted/gossip/befriended thresholds (modest, opaque).

## 4. The [Observe]/social dedup seam (folds in TP review M1)

One shared mechanism: per-waking first-use-per-entity banking for
"pointed-at-entity" counter skills ([Observe]'s `observed_things`,
[Friendly Face]'s `befriended_moments`). Cleared at sleep alongside
`social_talked`. Kills the mash-to-level degenerate case for both pillars
with one dict.

## 5. QA

- New canonical `social_loop` (33rd): boot → talk Erin (pool line + toast?
  pool lines render via the existing dialogue_line/toast surface —
  implementer picks the shipped idiom) → talk again same waking (normal
  graph, no double bank) → sleep → talk re-armed (next rotation index) →
  persuade route (sergeant fixture or parley) banks persuaded_someone →
  sleep → class_gained{diplomat} grants toast → [Friendly Face] on a faced
  NPC → line + used_skills reveal. Fixture allowed (post_tutorial_street
  precedent).
- Expected-red window: pools on canonical-asserted NPCs may shift
  dialogue-adjacent event streams — the plan's S2 DISCLOSES the exact set;
  S4 closes it (O5 discipline, expected small).
- Harness: diplomat cell measured-only if [Calming Words] is fieldable by
  the AI (likely not — melee-profile AI; document like piercing_strikes).

## 6. Non-goals (v1)

Relationship tiers/UI, tavern-rush time pressure, romance/reputation
systems, NPC schedules, per-topic branching. All future-milestone
candidates pending playtest.
