# witch.json — companion notes

**Narrative purpose:** the heart of "The Price of a Favor" — the meet that
reframes the villain, the debt truth, the TALK resolution, and the vendor
payoff. Tone target: transactional warmth; every kindness is priced and the
pricing IS the kindness.

## Canon cites
- **Witch-craft as debt/price/collection** is core canon (the witches arc,
  Vol. 6 Riverfarm chapters): witchcraft runs on prices paid and owed;
  favors have costs; a witch collecting what she's owed is lawful-craft,
  not malice. The whole quest premise rides on this canon frame.
- **Tea-first manners**: canon witches keep hospitality forms (Eloise the
  tea-witch most of all). The spec's "the craft has MANNERS" key line is
  the register anchor.
- **Riverfarm** = Laken's emerging village-town (canon); Laken content is
  out of scope per spec — this graph never references him.

## Invented / OPEN
- **Speaker unnamed ("The Witch").** The staging profile says name
  canon-checked else ORIGINAL+flag. Canon-nearest fit is **Eloise** (the
  tea-witch — tea-first manners match almost exactly), but she's bound to
  the traveling coven arc and a bigger canon footprint than a v1 side arc
  wants. Recommendation: keep her UNNAMED v1 ("Names are prices too" is
  now load-bearing in the collateral node — the mystery is in-register);
  if the user wants a name, mint an original one, don't spend Eloise.
  **Flagged for user taste.**
- **Vendor sells for coin vs profile's "prices in favors, never coin":**
  reconciled in-text ("Coin is the one favor the whole world agrees on. I
  take it under protest") + the hub variant. This is a deliberate
  post-quest character beat, not a profile violation — the profile line
  governs the QUEST (debt can't be coin-paid: `coin_refused` node dramatizes
  exactly that); the vendor is her ceding one round to the world.
- **Vendor items** `witch_bitterroot_draught` / `witch_hearthwax_candle` /
  `witch_clearveil_salve` (6/4/9 gold) — M-GEAR placeholder ids + prices,
  ALL OPEN. Spec only says "herb-craft consumables."
- "Second-spring honey," "fire debt with a fish" — original flavor, no
  canon claims.

## Wiring notes
- `heard_of_the_blight` — banked by the headman's give (headman.json).
- `drove_off_collectors` — on_victory of the briar-collectors encounter
  (hollow arena, spec §5).
- `paid_price_yourself` — terminal of the field-skill gauntlet (spec §3
  SKILL): `cooked_the_offering` [basic_cooking] + `lit_threshold_candles`
  [[Light]] + `observed_true_knot` [[Observe]] → the final prop banks it.
  Prop wiring owned by the map/quest lane.
- `blight_lifted` — THE shared resolution accomplishment all three paths
  bank; village visual_states brighten off it (spec) and
  charmed_villager.json's freed state gates on it.
- Path-flavor accomplishments (`witch_debt_renegotiated` / `_beaten` /
  `_paid_for`) exist for text_variants and future callbacks only.
- Quest beats suggestion: hear (`heard_of_the_blight`) → learn
  (`learned_debt_truth`) → lift (`blight_lifted`) → report
  (`reported_blight_lifted`, headman side).

## Softlock audit
Hub: hidden options + ungated "Another time." ✓. renegotiate/coin_refused
keep ungated outs ✓. Shop is Krshia-shaped (gold-gated buys grey visible,
"Nothing today" ungated) ✓. No start_combat ✓.
