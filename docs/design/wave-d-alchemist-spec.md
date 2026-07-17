# Wave D-1: [Mixer] → [Alchemist] + the Pallass alchemists (spec)

**Authority:** #134 rulings (2026-07-16/17) + the canon research posted
there. All names below carry their verdicts from that research; Book-17
bar enforced. In the v0.10.0 set per user (2026-07-17).

## Class ladder (canon-exact)

- **[Mixer]** — base class (List of Classes: the canon base "Alchemist =
  advanced [Mixer]"). `gained_by {synthesized_draught: 1}`.
  stat_growth {int: 1}. Curve: TRADER shape verbatim on
  `synthesized_draught` (gained-by-low, grind-priced). Kit:
  L1 [Low-Grade Synthesis] (ATTESTED 6.39, Octavia) — field skill, casts
  at alchemy-bench props (the zero-engine `requires_skill`+`on_skill_use`
  seam): consumes nothing v1 (basic-cooking precedent), yields a
  low-tier consumable + banks `synthesized_draught`. L3 [Cleansing Heat]
  (ATTESTED 6.39) — pure passive identity (actives-become-passives
  directive; description: botched mixtures burn off clean). L5
  [Magic-Water Solvent] (ATTESTED 6.39) — field, bench-cast, yields
  `solvent_phial` (component item). L7 [Mineral Distillation] (ATTESTED
  6.39) — field, bench-cast, yields `mineral_salts`.
- **[Alchemist]** — Replacement evolution at 10, single-axis
  `{synthesized_draught: "alchemist"}` (tactician precedent; min_uses
  clears trivially). SPARSE floor 10 (GH#54 comment conventions).
  stat_growth {int: 2}. L10 grant [True Synthesis] (⚑ ORIGINAL,
  canon-plausible — [Master Alchemist]/guild names are Vol-9 FAIL):
  bench-cast consuming `solvent_phial` + `mineral_salts` → a mid-tier
  consumable (first component-consuming recipe; `requires_item` +
  `remove_item` on the prop payload — shipped seam). L12 [].
  Aspiration: { display_name: "Guild Alchemist" ⚑ ORIGINAL, text: "The
  guilds certify what the cauldron already knows. Keep mixing." }

## NPCs (pallass_market)

- **Xif** (CANON-NATIVE, 6.09): "Cunning Crafts" stall — new vendor NPC.
  Voice: friendly, distractible, cost-minded, "I am a City Gnoll, if
  anyone asks." Shop: potions/components (haggle: false — Pallass civic
  doctrine). His [Perfect Reduction]/[Poison Immunity] are DIALOGUE
  COLOR only (never player grants). Saliss = one banter name-drop max
  ("the only alchemist in this city better than me is a naked lunatic")
  — NEVER near Onieva/identity. Sprite: gnoll base + tint placeholder,
  VISUAL-LOG flag (shaggy tan, stained many colors, singed twice).
- **Octavia** (RELOCATION-FLAGGED): day-trade stall beside Xif's
  (consignment via their 6.39 working contact — the one canon hook;
  frame as door-day-trips, NOT residency; the papers system treats her
  as a non-citizen trader). Voice: fast-talking sales pitch, low-20s-
  at-most level nerves, stink-potion gag (2.44) referenced once. SHE
  teaches: her chain banks the first `synthesized_draught` walkthrough
  (gated on buying anything from her + a warmth beat) — the player's
  entry to [Mixer]. "Apprentice of Saliss" NEVER appears
  (fail-until-proven).

## Props / items

- Alchemy benches (requires_skill low_grade_synthesis / solvent /
  distillation / true_synthesis variants via the latest-satisfied-wins
  variant arrays): Xif's stall bench (pallass_market) + an apothecary
  corner bench (invrisil mercantile_alleys — new prop, gives the class
  a second region). Every cast banks `synthesized_draught`.
- Items: `solvent_phial`, `mineral_salts` (components), `tonic_of_the
  _clear_eye` (⚑ mid-tier output — effect reuses an existing consumable
  shape, pricing defers to #92-in-this-release).

## Verification

wi-adding-a-class-or-skill gates (progression/content/shipped_ids/sim
untouched — no combat skills in this class v1); mixer_alchemist_loop QA
script (near_mixer fixture; bench casts → evolution → True Synthesis
component consume) with can-fail; #154 validator green (new gates need
producers by construction); copy-fit; icons ×5 via placeholder shapes
(PixelLab budget is user-gated — placeholders fine for v0.10.0, drain
note); windowed pass of the two stalls; Octavia/Xif dialogue voice
review; prepared Playtest State at the Xif stall.
