# Pantry-door prop consolidation — spec (user FEEL verdict 2026-07-19)

USER DIRECTIVE: the 3-prop cluster at the pantry (pantry_door 14,6 +
pantry_door_runes 14,5 + cellar_wardwork 13,5) is confusing. Replace it
with ONE door that visually BECOMES the runed door at the story beat;
deliver the information through different SKILL interactions on the
door, not through adjacent props.

## Target design
1. **One entity**: `pantry_door` keeps its cell/door/portal roles.
   `visual_states` swaps its sprite `door` -> `pantry_door_runes` when
   `door_chain_started` banks (the garden_door at:0/at:1 precedent —
   order-sensitive later-satisfied-wins; render-only, structural keys
   untouched).
2. **Multi-skill arms on one entity** (the sim extension): today an
   entity carries ONE `requires_skill` + `on_skill_use`. Add a
   `skill_uses` map — `{"observe": {...}, "detect_magic": {...}}` —
   resolved in the same code path (wi_game use_skill / interactions),
   with `on_skill_use` kept as the single-skill sugar. test_content
   validates every key is a real skill + every accomplishment produced.
3. **Fold both props into the door**:
   - observe arm = the runes read (banks `read_the_door_runes`, the
     door-chain SKILL leg) — text from pantry_door_runes verbatim.
   - detect_magic arm = the wardwork read (banks `detected_wardwork`) —
     text from cellar_wardwork verbatim.
   - [Open Doors] door_flavor (#214) + interact toast variants stay.
   - The locked/hint toasts merge into the door's observe variants.
4. **Remove** `pantry_door_runes` + `cellar_wardwork` entities. Their
   counters live on (shipped ids; now banked via the door's arms).

## Blast radius (why this executes on FRESH runway, not marathon-tail)
- Sim: `skill_uses` resolution + validator arms (small, but core).
- inn sprite-count pins drop 16->14: inn_walkthrough, work_loop,
  upstairs_walkthrough, horns_residence (19->17) + any other
  ui_entities_rendered pin on the inn.
- door_chain_scout (and siblings) target the RUNES entity's cell for
  the observe leg -> retarget to the door cell + re-pin toasts.
- #214's door_flavor + detect-hint copy cites cellar_wardwork — the
  hint text needs a re-cite pass (dialogue/toast greps both dash forms).
- Full bar + windowed before/after of the pantry corner.

## Sprite note
`pantry_door_runes` (the runed-jamb sprite) becomes the door's at:1
STATE sprite — check it reads as a DOOR at the door cell (it was
generated as a jamb post; if it reads wrong in the windowed shot, regen
"runed wooden door" ~$0.09, alt already banked).

Est: one focused block (sim arm + 2 removals + ~6 canonical re-pins).
