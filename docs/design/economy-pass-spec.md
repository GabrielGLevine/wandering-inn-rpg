# Economy pass (#92) — delta-first spec DRAFT (v0.10.0)

**Frame:** the economy exists (gold, shops, wages, bounties); #92 closes the
LOOP GAPS, not a rework. Five deltas, smallest-first, each independently
shippable. Balance numbers are proposals — controller adjudicates before
merge (balance philosophy = strongest reasoner + user taste).

## D1 — price the unpriced consumables
`crude_draught`, `tonic_of_the_clear_eye` (D-1 outputs), meal tiers,
`remedies` — every purchasable/craftable consumable gets a `price` and a
sell margin consistent with the crude→mid tier line (crude ~6g, mid ~18g;
alchemist crafting undercuts stall price by the component cost, never
free). Xif's stall + Krshia + inn kitchen rows updated. Validator: every
consumable in any shop inventory has a price; crafted-output price >
summed component prices (no infinite-gold crafting loop) — test_content
addition.

## D2 — use_item combat verb
Combat hotbar slot for carried consumables (drink the draught mid-fight):
`use_item` action, ap_cost 1, consumes the item, applies its existing
effect shape (heal/meal-buff reuse). Data: `combat_usable: true` flag on
the 3-4 potion items ONLY (no food mid-fight). Engine: one verb in
wi_combat + hotbar wiring; sim: with-potion cells GATED. This is the
biggest slice — if it threatens the release window, it ships behind D3-D5
and can defer to v0.11.0 (flag in PR).

## D3 — repeatable sinks
Two standing gold sinks: inn room upgrade tiers (bed quality → +1 max HP in
COMBAT per held tier, cumulative, cap +3 — a persistent `hp_mod` contribution,
not a sleep-restored pool; 3 tiers, 25/60/120g) and Watch supply donations
(reputation flavor + a barracks thread relay line). Both data-first
(props/dialogue gold_cost), no new engine.

## D4 — boss/elite drops
`on_victory` gold purses exist; add ITEM drops to the 4 boss-tier
encounters (raskghar_awakened, ruin_guardian, vault_construct,
kingslayer_spider): one guaranteed mid-tier consumable + one gear-ability
accessory each (reuse shipped accessory ability shapes). No random tables
— deterministic drops, sim-neutral (drops resolve post-victory).

## D5 — gear abilities pass
The accessory `abilities` seam is shipped but sparsely used. Give the 3
flattest accessories one ability each (ability = existing skill id folded
via fold_abilities — zero new engine). Sim: loadout cells re-measured.

## Explicitly OUT
Resonance growth curves (parked — needs its own design), Hedault
enchanting (#142 rides this shape NEXT release), haggling minigame, any
currency besides gold.

## Gates
Full wi-verifying-changes rotation; economy validator additions can-fail
proven; `--touching` sweeps per data file; one QA loop per shipped delta
(potion_combat_loop for D2; room_upgrade_loop for D3); #154 reachability
green; freeze-list note: new item/skill ids land BEFORE the v0.10.0 cut.
