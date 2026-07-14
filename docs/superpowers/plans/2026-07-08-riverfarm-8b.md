# Riverfarm (issues #10 + #11, milestone 8b) — Implementation Plan

> Status: **DONE** — executed; retained as a design record.

> **For agentic workers:** dispatch-grade tasks per repo convention;
> wi-running-the-machine governs. Comment style per CLAUDE.md conventions
> (function/constraints/traps — no provenance).

**Goal:** the first Door expansion — Riverfarm's two maps, three profiled
NPCs, and "The Price of a Favor" 3-path quest, arriving via the FIRST real
use of `data/portals.json`'s anchor-stone-per-region contract.

**Design authority:** `docs/superpowers/specs/2026-07-06-riverfarm-design.md`
(all §) + `docs/archive/design/riverfarm-art/{direction,picks,handoff}.md` (art) +
`docs/design/character-profiles-staging.md` "Riverfarm (8b)" (profiles) +
issues #10/#11 (briefs; their danger lists bind).

## Locked design shapes (controller decisions — do not re-litigate)
1. **Arrival**: a Guild-board rumor beat (a posting-class surface at the
   REQUEST BOARD seeding the expansion, per the spec) banks
   `riverfarm_attuned`; a new `data/portals.json` row
   `{id:"riverfarm", display_name:"Riverfarm", map:"riverfarm_village",
   cell:<R1 picks>, requires_accomplishment:"riverfarm_attuned",
   arrival_toast:<R1 drafts>}` — ZERO portal code (the #8 contract; if any
   code change is needed the contract is broken — STOP and report).
2. **The night-gated encounter** (first phase-conditional spawn): a new
   `encounter_when: {"phase": ["night"]}` gate on the encounter ENTITY,
   evaluated at the same sites `door_when`-class gates already run
   (interact + trigger checks), reading `phase()`. door_when-family
   extension with its own validator arm — NOT a new spawn system; no
   timers, no respawn logic beyond what `respawns` already does.
3. **The charmed-villager tell**: the villager's talk_pool carries ONE
   entry shaped `{"echo_of": "riverfarm_witch"}`; WISocial resolves it at
   line-pick time to the witch's CURRENT pool line verbatim (both derive
   from the same times_slept rotation, so the echo can never drift).
   Sanctioned WISocial extension + validator arm + unit proof. The tell is
   killed (entry retired via the existing pool-stage machinery) when the
   quest resolves.
4. **The Witch's two-form read**: `visual_states` keyed on PHASE (elder at
   day, young at dusk/night) — the visual_states `when` family gains a
   `phase` shape alongside counters (shared with locked shape 2's gate
   family; ONE implementation, two consumers).
5. **Licensed art discipline (the bundle-v3 lesson, BINDING ORDER):** any
   licensed pick R1 needs ships manifest entry + ignore regen + extract +
   bundle-v4 + fetch BEFORE the data commit referencing it. Owned
   PixelLab village assets (the art cache) commit directly per SHIP-OK.

## Lane map
- **Lane α: R1 → R3 → RF** (share skeleton_scene + dialogue files).
- **Lane β (parallel with R1): R2 combat data** — owns combatants.json,
  arenas.json, harness cells ONLY. Interface: encounter ids
  `briar_collectors` / `briar_collectors_deep` / `river_wolf_pack`,
  arena ids `witch_hollow` / `village_edge_night`, on_victory
  `drove_off_collectors` / `survived_wolf_night`.
- Registry appends in lane α only.

### Task R1 — the two maps, the cast, the arrival
**Files:** skeleton_scene.json (maps `riverfarm_village` ~24x16 +
`witch_hollow` ~12x14 from the art handoff's staged fragments; the
earthworks NORTH-EDGE DRESSING only — Laken out of scope; dormant
encounter placements per lane-β ids incl. the `encounter_when` night gate
on `river_wolf_pack`), biomes/sprites (owned village set from
potential_assets/pixellab_2026-07-07_riverfarm/ + any licensed picks via
the locked shape-5 order), moods.json ("harvest light" / "green shade"
cards per the direction card), the 3 NPC entities + talk_pools + observe
lines (profiles-staging is the voice contract; the Witch's phase
visual_states = locked shape 4; the villager echo = locked shape 3),
data/portals.json row + the Guild-board rumor beat (locked shape 1),
sim: the `encounter_when`/phase-visual_states shared gate + the
`echo_of` WISocial resolution (+ validator arms + unit teeth for all
three), fixture `near_riverfarm` + canonical `riverfarm_walkthrough`
(door arrival → village walk → all 3 NPC pools → the hollow round-trip →
the witch's two-form read across a phase crossing → the night wolf gate
NEGATIVE at day) + registry three-way.
**Danger:** the wolf entity must be UNREACHABLE at day (the negative is
canonical-pinned); the Witch phase-swap must not fight atmosphere.gd's
phase clock (#10's danger list — trace, then prove at a crossing);
blast-radius on the street/guild if the rumor beat touches the board.

### Task R2 — combat data (lane β)
**Files:** combatants.json (briar collectors ×2 variants, plant-class,
canon-checked; the wolf pack — mundane canon fauna), arenas.json
(`witch_hollow` bent-tree arena + `village_edge_night` — mind the
dark-arena brightness floor), harness cells (gated bands justified per
cell; wolf pack tuned for a NIGHT ambush read — measured-only acceptable
with rationale). Existing cells byte-identical A/B. No skeleton edits.

### Task R3 — "The Price of a Favor" (after R1 merges)
**Files:** quests.json (3-path parity → ONE `blight_lifted`), the
headman/witch/villager dialogue graphs (§4 voice keys verbatim as
starting points; the TALK renegotiation; the SKILL gauntlet =
basic_cooking + [Light] + [Observe] in sequence via existing field-skill
seams), the FIGHT path wiring to lane-β's encounters, the village
visual_states BRIGHTEN on `blight_lifted` (the map as reward readout),
the witch-cottage VENDOR unlock (herb-craft consumables — M-GEAR band
items, prices inside existing economy discipline), the villager echo
RETIRES on resolution, per-path canonicals `riverfarm_fight/talk/skill`
(the C3 precedent) + a phase-crossing leg proving the wolf gate POSITIVE
at night + registry.
**Danger:** 3-path parity is identity-rule binding; vendor prices are
balance-adjacent (stay in the shipped consumable band; flag anything
outside it); voice-lint everything.

### Task RF — close
Whole-8b review (composed, cross-lane: the echo sync, the phase gates ×
atmosphere, the portal contract's first exercise, vendor economy) +
machine-playtest rotation (both direction cards day/dusk contrast — THE
storytelling device; the two-form witch; the brighten payoff) +
VISUAL-LOG drain + HANDOFF playtest checklist + `Closes #10` /
`Closes #11` + milestone close.
