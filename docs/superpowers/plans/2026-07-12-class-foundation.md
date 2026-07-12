# Class foundation pass (#93 + #95 + #98) — one design pass (2026-07-12)

User framing (binding): the rest of the game balances around Class +
Skill progression. Inputs: docs/design/evolution-reachability.md (#96's
table + pinned retune), the gap-2 judgment (#93), the user directives
(#95 trap kit, #98 Trader line). Product locks bind throughout: stats
hidden, opaque-until-sleep, wiki canon (Book-17 bar), visible-currency
cards via WIEffectText, every grant = a visible skill card (never an
invisible stat bump).

## Controller design rulings

### R1 — The stagnant trio's ladders (grants pinned; wiki pass in-lane
for every NAME; if a name fails the wiki check, the lane substitutes the
nearest attested name and discloses — mechanics stay as pinned)
- **Tactician** (1: observe, battlefield_awareness): L3 `dangersense`
  (reads danger — canon-fit, already shipped); L5 NEW `directed_strike`
  [Directed Strike] (combat active, damage_mult ~1.6, 2 AP — the
  tactician lands the opening he read); L7 NEW `flanking_step`
  [Flanking Step] (move_pool_bonus +1 passive). Evolution at 10 →
  **[Strategist]** (Olesm's attested arc): L10 grants NEW
  `read_the_field` (field+combat observe upgrade — reuse the observe
  effect shape at wider radius if expressible, else a second dangersense
  -family passive; disclose the pick).
- **Diplomat** (1: charming_smile, calming_touch): L3 NEW
  `measured_words` [Measured Words] (field skill, no combat effect —
  the social-pillar rung; its USE surface = the persuade-fork gates,
  i.e. new dialogue options may gate on it in future content); L5 NEW
  `soothing_presence` [Soothing Presence] (combat: heal effect, ally
  target, 2 AP/3 MP — the pacifist's combat contribution); L7
  `charming_smile` STAYS the gate skill — L7 grants NEW `open_doors`
  [Open Doors] (field passive: flavor + future vendor-perk hook).
  Evolution at 10 → **[Emissary]** (wiki-check; fallback candidates
  the lane may substitute with disclosure).
- **Rogue** (1: sneak): L3 NEW `find_trap` [Find Trap] (field: reveals
  trap tells in radius 2 — the observe-reveal seam, one cast); L5 NEW
  `disarm_trap` [Disarm Trap] (the requires_skill disarm verb the
  dart_slit already consumes — GENERALIZED: every trap-class prop's
  disarm re-points to this id; observe-based disarms stay as the
  no-Rogue fallback where currently authored); L7 NEW `sudden_strike`
  [Sudden Strike] (combat active, damage_mult ~1.8, 2 AP, ONCE per
  fight — expressible? if once-per-fight needs new sim state, plain
  damage_mult at higher AP cost instead; disclose). Evolution at 10 →
  wiki-check ([Infiltrator] candidate).
- **Sharpshooter** (10+): L10 NEW `called_shot` [Called Shot]
  (damage_mult ~2.2, 3 AP); L12 NEW `piercing_volley` [Piercing Volley]
  (line_damage, bow-family). Zero→two grants.

### R2 — Fire's earn surface (from #96)
Mage L2 adds NEW `flame_dart` [Flame Dart] (spell_damage single-target,
fire-tagged, 2 AP/3 MP — frost_bolt's fire twin, slightly weaker die).
flame_jet stays. The fire axis gains a practical early active; the
1/28 landing-rate gap closes structurally. Harness: the mage cells
re-verified byte-stable (AI never casts player-granted spells — the
harness BUILDS matter, check which builds carry mage kits).

### R3 — The consolidation retune + the T3 reference rework (from #96,
the deep coupling — this is why the retune waited for this pass)
- consolidation: min_parent_level 6→10, min_combined_level 13→21,
  merged-level floor 14 (the pinned values). [Spellsword] now arrives
  AFTER both parents' evolutions can resolve — the race inverts to a
  real choice.
- THE COUPLED REWORK: the ratified T3 reference build "spellsword ~9"
  becomes unreachable. New T3 reference: **warrior 10 + T3 gear**
  (re-derive `briar_collectors_*` + `hired_blades_*` cells GATED at the
  new reference; the sim_combat_batch tier table + region-tiers doc
  update together). T4 stays spellsword-based but at the new floor
  (spellsword 14 — re-verify vault cells at a spellsword14 build ALSO,
  as a measured companion cell; the shipped gated vault cells stay
  pinned to their current builds unless they break).
- near_consolidation fixture re-based to the new gate (mage 10 +
  warrior 11 shape); consolidation_flow/reload re-derived honestly.

### R4 — Two new consolidations (wiki pass in-lane)
- **[Innkeeper]** (helper + diplomat) — the game's own heart; grants at
  consolidation: the parents' field kits + NEW `perfect_hospitality`
  [Perfect Hospitality] (field passive; hooks the inn's serve/cook
  economy — a wage/effect bump expressible via existing once_per_waking
  wage props reading the skill? disclose the smallest wiring).
- **[Ranger]** (warrior + archer) — wilderness canon; grants
  `dangersense` if unowned + NEW `steady_draw` [Steady Draw] (bow
  damage_mult passive ~1.15).
- Same gate shape as spellsword (requires_any parent counters, the new
  R3 thresholds).

### R5 — The Trader line (#98)
- **[Trader]** earned class: `gained_by` accomplishment = NEW counter
  `deliberate_commerce` — banked by: selling (the new verb), a
  completed delivery turn-in, a gold-gated shop purchase >= 5g.
  Threshold 5 (deliberate, not incidental).
- **THE ONE SANCTIONED SIM ADDITION: the `sell` verb.** Sellable items
  (a `sell_price` field on items.json rows; unsellable-by-design items
  simply lack it) sold at a vendor conversation's sell node (a
  dialogue-effect arm `{sell_menu: true}`? NO — smallest shape: a
  code-built graph like the boards, WIBounties.build_picker_graph
  precedent, listing sellable inventory; disclose if a cheaper shape
  exists). Sell surface v1: Krshia + the witch + the Pallass market
  clerk-adjacent stallkeeper.
- **[Bargain]** (Trader L1): shop prices read lower — implemented at
  the ONE gold-gate evaluation point (`_meets`'s gold arm? NO — prices
  are authored in requires{gold}+effects{gold} pairs; the honest shape:
  a `price_mod` resolution applied to BOTH the gate and the effect at
  dialogue-option resolution when the buyer holds the skill, ~10 lines,
  ONE site, validator-checked that gate and effect stay consistent).
  Display: the rendered option text shows the REAL (discounted) price —
  visible currency, no hidden math. Pallass REFUSES haggling
  diegetically: its shop nodes carry `no_haggle: true` (price_mod
  skipped + a clerk line when a Trader tries — the posted-prices
  register reinforced).
- **[Trader] L5**: NEW `appraise_goods` [Appraise Goods] (field read:
  an item's provenance/value flavor line — WIEffectText-formatted).
- Evolution at 10 → **[Merchant]** (Krshia canon): L10 `bulk_terms`
  [Bulk Terms] (sell prices improve).
- Economy guard: every discount/sell price through the balance lens —
  the #92 sinks land AFTER this, so v1 numbers stay conservative
  (Bargain ~10%, sells at ~40% of buy price).

### R6 — Trap placements (#95's second half; parallel lane)
6-10 placements on the shipped trap-class machinery: sewers (2, vermin
nests), mercantile_alleys (2, the footpad era's leftovers),
warren approach (1-2), witch_hollow (1, briar-snare), trapped_halls
keeps its 4. Every placement: observe-reveal tell + the no-Rogue
counterplay (avoidable path) + disarm banks `trap_disarmed` (feeds
Rogue's axis) + a small salvage (the real-cost doctrine inverted:
disarming PAYS — 1-2g scrap or a consumable-tier item). Placements off
canonical walk paths (the absolute-cell-count trap); dynamism
non-negative per map.

## Lane split + order
- **Lane A (sim+data, serialized owner of classes/skills/items/
  sim files):** R1+R2+R3+R4+R5 — big; commits in R-order so review can
  bisect. The balanced_grants/levels[].grants id validation (#96's
  hardening) lands FIRST as its own tooth.
- **Lane B (skeleton+dialogue, parallel):** R6 placements + the sell
  nodes' vendor wiring (forward-references find_trap/disarm_trap/sell
  ids AS PINNED HERE — the reconciliation-rehearsal review checks the
  seams before merge, the 8e lesson).
- Controller: wiki adjudication on the names the lanes flag, the voice
  pass on any new NPC-facing lines, the reconciliation merge.
- QA: every new grant = a card pin (test_effect_text) + the earn
  canonicals (trader_earn_loop, a rogue trap loop, consolidation
  re-derives); harness cells per R3's table.

## Exit criteria
No class dead-ends before its evolution/consolidation point; the
consolidation race inverted (table re-run proves evolution-first under
mono play, consolidation available for mixed at 14+); fire ≈ ice earn
rates (table re-run); [Trader] earnable + [Bargain]/sell live in 3
vendors + Pallass refuses; traps reward the Rogue and stay fair
without one; all locks intact; full gates.
