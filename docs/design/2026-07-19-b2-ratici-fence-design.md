# b2 Ratici's rotating fence — design (2026-07-19, Fable; wave SEED 1)

The user's own example package. Profile: character-profiles.md#ratici
(SHIP APPROVED #133; Drake, [Gentleman Thief] name-ceiling, careful
browns, floppy cap, hats-off tell shared with Wilovan). Wilovan voice
notes apply to the register: courtesy over menace, "recover" never
"steal", one dash per line.

## 1. Shape (all machinery precedented)

- **Carrier**: `parlor_stash_chest` (brothers_parlor [12,7]) converts
  from a plain observe/eyed prop into the FENCE register — its OWN
  conversation (`ratici_fence`), never Ratici's pinned talk-pool (the
  purchase-options-never-ride-pinned-hubs rule). Ratici the npc is
  untouched.
- **Gate**: first interact keeps banking `eyed_the_stash` (the shipped
  dangling counter becomes the fence's own doorbell). The fence
  CONVERSATION opens via the chest's `door_when`-style gate:
  `eyed_the_stash >= 1` AND `brothers_job_done`-class trust counter
  (check what #133 banked at the job close — use the shipped Brothers
  arc completion counter; the fence is a TRUST reward, not a walk-up
  shop). Below trust: the chest stays the flavor prop (observe line
  carries the tease).
- **Rotation**: `WIBounties.active_slate(pool, times_slept)` idiom over
  a new `data/fence_stock.json` pool (6-8 records: `{id, item,
  price, patter}`) — 2 visible per waking, zero rng. Code-built graph
  via a `WIPortals.build_portal_graph`-style static builder
  (`build_fence_graph(slate, gold)`) — the board-picker precedent, so
  the dialogue-panel UI and QA idioms need nothing new.
- **Pricing**: fence premium — stock items price at ~1.4× catalog
  (Ratici's cut; the #92 band logic); one slot per waking may be a
  UNIQUE flavor accessory (the fence's draw — start with 2 uniques in
  the pool, resonance-1, effect-text-pinned).
- **Patter**: each stock record carries ONE Ratici line (voice: Drake
  understatement, item never named directly — "A thing that fell off a
  cart. The cart disagrees.").

## 2. Economy guards

- Buy-only v1 (no sell-to-fence — the #92 sell seam stays Krshia's;
  CHOICE-LOG if flipped). No buyback: a fence purchase is final
  (sell_price on fence uniques stays the standard 50% via the normal
  sell flow — no infinite loop: price 1.4× catalog, sell 0.5× catalog).
- `deliberate_commerce` banks naturally via the -gold effect (≥5g
  purchases) — Trader fuel intended, bounded by the rotation (2
  slots/waking).

## 3. QA plan

- `ratici_fence_loop` canonical (fixture: trust met, gold, day N):
  rotation determinism (same times_slept → same slate pin), buy leg
  (gold delta + item_gained + patter render), slate EXACT-list pin =
  rotation can-fail; second fixture day → different slate pin proves
  rotation.
- Gate leg rides the same script's pre-trust fixture sibling OR a
  gates-check twin (b1/b3 pattern): below trust the chest interacts as
  the plain prop (eyed banks, no fence conversation).
- Registration all-three + fixture coherence + full bar.

## 4. Execution order

1. `fence_stock.json` pool + builder (`WIFence.build_fence_graph`,
   static, WIBounties file or its own src/core/fence.gd — keep static
   pure; NO new WIGame state beyond reading times_slept/gold).
2. Chest gate rewire + the fence-open interact arm (the
   `portal_menu`-style flag: `fence_menu: true` + `fence_menu_when` —
   ONE new interact-routing arm in WIInteractions (post-#194a home) +
   wi_game glue callable.
3. Stock authoring (6-8 records, 2 uniques) + patter voice pass.
4. Canonicals + fixtures; sweep; review; PR closes the b2 issue
   (find its number: gh issue list "Ratici").

## 5. Adjudications (CHOICE-LOG at implementation)

- Trust gate counter choice (whatever #133's close banked) — flag the
  exact id chosen.
- 1.4× fence premium + buy-only v1.
- Unique count (2) and their effects (flavor-tier resonance 1).
