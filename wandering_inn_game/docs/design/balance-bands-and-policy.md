# Balance program: per-act level bands (draft) + competent-policy spec

Fable-authored 2026-08-11 for the balance program (#437 → #441 → #439 →
#440 → steel-thread Act V reauthor). Bands are a DRAFT to unblock #441
enumeration and #437 table columns; #439 finalizes them against the
side-content XP budget sim. Doctrine context: CHOICE-LOG 2026-08-11
("combat chokepoints are leveling gates", "QA proves completability;
sims prove balance").

## Per-act target bands (draft)

"Band" = combined class levels a player who did that act's side content
arrives with at the act's CLIMAX. Anchors: the designer-era fixtures
(`deep_descent_start` warrior 5, `winter_teeth_night_start` warrior 10,
`near_riverfarm` w5/m5, `pallass_standards_fight_start` /
`seal_open_start` spellsword 14) — these encode the intended power
curve the stitched-era content was authored against.

| Act | Climax | Band (combined levels) | Anchor evidence |
|---|---|---|---|
| I — Arrival | gate-road ambush | 1–2 | tutorial era; classless spar + first class |
| II — Make a Place | cisterns nest / crate | 4–6 | two classes formed; second class + 2-3 levels of quest counters |
| III — What Stirs Beneath | awakened boss | 8–10 | `deep_descent_start` w5 at the DELVE START; boss authored for mid-single-digits + Relc |
| IV — What the Door Opened | vault construct, forge exam era | 12–14, consolidation available by act end | `winter_teeth` w10 mid-act; `pallass_standards` ss14 late-act |
| V — What the Seal Was Feeding | Seal Warden | 14–16 (consolidated: spellsword-shape or equivalent) | `seal_open_start` ss14; warden 142 HP / 28-30 per hit is plausibly fair HERE |

Measured today (steel thread, `ceefd357`): Act III climax fought at
**2**; Act V reached at **w12/m2/d7/t2 unconsolidated, 56 HP**. The gap
between that row and this table is #439's work order.

Falsifiable check for #439: the warden's current stats vs a
consolidated 14-16 build under the competent policy should land in the
challenging-but-winnable range. If it does, #440 is mostly the bypass
rework, not a stat change — validate before touching warden numbers.

## Consolidation note

Spellsword floor is 14 (both parents 10+). The Act IV band therefore
implies REAL mage investment during Acts II–IV for a caster-leaning
player, or an equivalent second consolidation line. The side-content
XP budget sim (#439) must prove at least two viable spines reach the
Act V band: martial-primary and caster-primary. If only one reaches
it, the band or the content is wrong — surface, don't fudge.

## Competent-policy spec (#437 lane implements)

Purpose: the TUNING REFERENCE — approximates a player who uses their
resources, without optimal play. Sim-only; drives turns through the
real combat engine (sim_combat_batch harness). NOT shipped AI.

Home: `qa/combat_policies.gd` (class with static `take_turn(combat,
actor_id) -> void` driving the same engine calls the driver's autoplay
path uses). Two policies exported: `dumb` (今日's behavior, extracted,
byte-compatible outcomes) and `competent`.

Competent turn framework, in priority order:
1. SURVIVE: if HP < 35% max: use [Second Wind] if in kit+AP; else use
   the best carried heal draught (combat_use_item); else if
   [Invisibility]/escape-shaped skill in kit and MP suffices, cast it.
2. NUKE: if an elemental attack skill is castable (MP ≥ cost, target
   in range, AP ≥ cost) and its expected damage ≥ basic attack, cast
   the highest-expected-damage one.
3. ATTACK: melee/ranged basic on lowest-HP reachable enemy.
4. POSITION: ranged kit keeps max range (step away if adjacent);
   melee dashes only when it buys an attack this turn.
5. END turn when no AP-positive action remains.

Rules of construction:
- Deterministic given (state, rng) — table rows must reproduce.
- No lookahead beyond the current turn; no target-selection beyond
  lowest-HP-reachable. The point is "uses resources", not "optimal".
- Reaction skills, passives, mana model, challenge weighting: engine
  handles; policy never reimplements game math (read kit/costs from
  the same data the engine uses).

Table contract (#437 output, one row per spine fight):
`fight | build | floor(dumb): result/rounds/HP-margin |
reference(competent): result/rounds/HP-margin | authored bypasses`
Calibration acceptance (ground truth from the shipped steel thread):
- warden vs w12/m2/d7 56HP: floor LOSS ~round 5; competent LOSS
  (2.5× gap exceeds resource use).
- gallery_vermin_nest vs same: floor LOSS, competent WIN.
- Act III scouts/boss vs w2+Relc: floor WIN (3-4 rounds).
