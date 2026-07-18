# Hedault enchanting (#142) — spec

**Authority:** user placement ruling ("Hedault as merchant NPC is
Invrisil", 2026-07-15) + #92's shipped gear-ability seam (accessory
`abilities` fold) + the CHOICE-LOG payout-anchor doctrine. v0.11.0 tail;
implement AFTER #163 merges (shared-data discipline).

## Canon frame (Book-17 bar)
Hedault: Invrisil's premier appraiser/enchanter (Vol 6-7, Ryoka arcs) —
exacting, humorless, hates being touched, fair to a fault. ATTESTED
canon-native. His services are priced formally; no haggling.

## The mechanic (one seam, data-first)
"Enchanting" = paying Hedault to add ONE ability to an accessory the
player carries — the #92 fold does the rest. No new engine for the
effect; ONE small seam for the transaction:
- Dialogue-effect `enchant_item: {item_id, ability_id}` (mirrors
  remove_item/gold effects; ~15 lines in the dialogue-effects resolver):
  validates the item is HELD, appends the ability to the player's COPY…
  → items are static catalog records, per-player item mutation does NOT
  exist. RULING: enchanting SWAPS the held item for a pre-authored
  enchanted VARIANT record (`copper_luck_band` → `hedaults_luck_band`),
  via the SHIPPED remove_item+item dialogue effects — ZERO engine. The
  "seam" is pure data.
- Three enchant offers v1 (one per flat-accessory family the #92 pass
  left unabilitied or shallow): priced 30-60g per the anchor doctrine
  (≥ 2× the accessory's base worth; validator arm extends the #92
  economy check to enchant pairs: variant price > base price + fee/2).
- Gates: each offer requires holding the base item (requires.item —
  verify the dialogue gate supports item-holding requires; if not, the
  option's effect chain refuses via the shipped requires_item toast
  path — survey first, STOP if neither fits).

## NPC + placement
`hedault` npc on invrisil mercantile_alleys (his shop = the apothecary
corner's neighbor); talk_pool (3 barks: appraisal snobbery, no-touching,
one Ryoka-adjacent dry remark — no Vol 8+ content); conversation
`hedault_enchanting`: appraise-then-offer register, formal prices, a
refusal line for absent base items. Sprite: human base + tint
placeholder, VISUAL-LOG flag.

## Verification
Registration matrix; economy validator arm (can-fail); QA
`hedault_enchant_loop` (fixture holding copper_luck_band + gold: enchant
→ swap + gold delta + fold visible in a fight's pc.skills; can-fail);
sim: measured cell with the enchanted variant equipped; dialogue-gate
grep; windowed read of the shop.
