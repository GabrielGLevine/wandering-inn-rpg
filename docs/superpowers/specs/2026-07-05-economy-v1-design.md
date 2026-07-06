# Economy v1 — Gold, Wages, Krshia's Shop (DESIGN)

Status: user-ratified 2026-07-05 (3 calls: work+quests+loot earn; Krshia
dialogue-shop sink; inventory-panel + toast display). Night track D per
`NIGHT-GOAL.md`. M7 shipped items/equipment/loot with ZERO currency — the
work loop pays nothing material; this makes all three pillars EARN.

## 1. Currency + display

- `gold: int` on the sim (save: additive tolerant-default 0, no version
  bump). Money is DIEGETIC, not a hidden stat: earn/spend toasts ("Earned
  2 gold.", "Paid 12 gold.") and a coin line in the inventory panel (I).
  NO always-on HUD counter (label-removal direction). Opaque-until-sleep
  does NOT apply to gold — coins are countable objects in-world, per user
  call; class/level opacity rules unchanged.

## 2. Earning (all three pillars)

- **Work:** completed chore/serve interactions pay small coin immediately
  (data field on the prop/conversation effect, e.g. `gold: 1-2`) with the
  earn toast riding the existing toast surface.
- **Quests:** reward beats gain gold options (data; the errand's
  keep-or-return precedent can price honesty: return = coin reward).
- **Loot:** encounters may drop coin via the ISOLATED loot RNG
  (hash(run_seed, encounter_id) — the M7 mechanism, so no canonical-seed
  shifts from the roll itself; the loot table gains `gold` entries).

## 3. Spending: Krshia's shop (dialogue-based)

- Krshia's existing conversation grows priced buy options using the
  SHIPPED affordability-greying mechanism (M4): 3–5 items from
  `items.json` with new `price` fields (healing potion [new item, existing
  consumable machinery if any — else a held item for M-later and ship
  gear only], leather_jerkin, a lantern/tool). Buying: deduct gold, grant
  item, toast. No new UI panel — the dialogue IS the shop, canon-flavored
  (Krshia's Liscor shop, wiki-checked copy).
- `requires`-style gating: options grey when unaffordable (existing), hide
  never (window-shopping is content).

## 4. Sim seam (small)

`wi_game.gd`: `gold` field + `earn_gold(n, source)`/`spend_gold(n, sink)`
(events `gold_changed {delta, total, source}` + toast); dialogue/interact
effect vocab gains `gold: +/-n` handled beside `item`/`accomplishment`
effects; loot table `gold` entries. Save round-trip. Affordability check
feeds the existing greying ctx.

## 5. QA + risks

- New canonical `economy_loop` (earn via chore → buy from Krshia →
  affordability negative [grey when broke] → loot gold from a fight →
  inventory panel shows the coin line).
- Expected-red risk: work_loop/crate scripts interact with paying
  props/NPCs — earn toasts enter their streams (FIFO queue discipline;
  qualified waits). Disclose + close in-task (small window, O5 idiom).
- Balance: prices vs earn rates are DATA; v1 aims "a day's honest work
  buys a potion; the jerkin takes several" — tune by feel at playtest,
  never mid-night.

## 6. Non-goals (v1)

Selling TO shops, haggling ([Haggling] canon skill — future Diplomat/
Merchant tie-in), multiple shops, stock rotation, theft.
