# COMMON RULES (every #398 pocket lane)

Work THIS checkout only. NO git commands (controller commits). Read
FIRST: wandering_inn_game/AGENTS.md; the spec §3/§4/§6/§7 (docs/
superpowers/specs/2026-08-05-skill-gated-areas-design.md); the plan's
Phase-1 section + standing constraints (docs/superpowers/plans/
2026-08-06-skill-gated-areas-398.md). Phase 0 is IN this tree: cuts is
weapon-gated at the field seam; skill_gates registry + lint arms live;
modes with no skill granter need an explicit "gate" field
(dialogue|item|endure).

BINDING:
- Your map gets a `skill_gates` entry (spec §3 shape) naming every mode
  + rewards; data_lint must pass it (the arms are strict — class
  disjointness, real carriers, same-map rewards).
- Every mode banks a DISTINCT counter where flavor allows; register new
  counters in generate_shipped_ids.py STRUCTURAL_LITERALS + regenerate
  (the generator is a proven no-op baseline — your diff must add only
  your ids).
- Rewards: unique loot item (data/items.json, NAMED anchor row under a
  lane comment), encounter +2-4 above region band with sim_combat_batch
  cells gated per wi-adding-an-encounter, one quest hook (observe or
  journal line — no new quests.json rows this wave).
- QA: mode-A leg, mode-B leg (DIFFERENT build fixture), negative leg
  (refusal/hint toast asserted + reward unreachable + reward entity
  absent/un-interactable). New canonicals: fixture-first (near_*
  precedent), derived seeds, manifest rows APPENDED LAST under your
  lane marker. Destination asserts on any dialogue selection (cursor
  wraps). No ui_entities_rendered sprite-count pins.
- FIXTURES ARE A REVIEW TRIPWIRE: never edit an existing fixture to
  suppress a derivation change; if any shipped canonical breaks in a
  way you believe needs a fixture or design change, STOP that item and
  report it for controller adjudication.
- Prose: functional register (plain, ≤2 sentences, zero closers) for
  every toast/hint; teaching copy names BOTH modes (K5 discovery).
- Census: data ceiling 15.0% — pay for every _comment with a nearby
  provenance trim; read comment_census.py's own rc.
- Verify: data_lint 0; census 0; affected units zero-warning; your new
  scripts green at derived seeds; `ci_sweep.sh --touching <your map>`
  green; the FULL 33-unit bar; alarm-wrap godot directly (no timeout
  on macOS; never wrap run_qa.sh).
- Final output: per-criterion evidence + NOT-DONE list + command ledger
  with rcs.

# P5 — THE BRIAR-CHOKED ARCH (ruin/ruin_surface.json ONLY)
Build the spec §4 P5 pocket: a briar wall line (blocking props, the
briar_wall sprite SHIPPED in this tree) across a collapsed arch. Modes:
M-PROP burns (Firefly or Flame Jet — both carry burns now) and M-PROP
cuts (Phase 0's property: power_strike/piercing_strikes, WEAPON-GATED —
your mode-B fixture must equip a matching weapon). You ship the FIRST
cuttable carriers: props carry cuttable:true + burnable:true + authored
cut_toast AND burn_toast (functional register), and you MUST remove the
`staged_target_properties` declaration from data_lint's registry data —
the lint LAPSES it once a shipped carrier exists (it will red until you
do; that is the designed handoff). Reward gating answers BOTH counters
(cut_through_growth / the burn counter — requires-any or shared idiom,
disclose). Reward: ~+3 band encounter + loot + a hook toward the
dungeon thread. CAUTION: ruin_surface carries #397 keeps/holdout + a
RESTAGE landmark — new entities only, zero existing-prose edits.
