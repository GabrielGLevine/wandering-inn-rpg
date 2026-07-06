# M7 — Weapons & Equipment Design

**Status:** user-approved brainstorm (2026-07-03). Approach A confirmed; "basic but
extensible" amendment applied (§1 tier/abilities). Economy (coins/shops/buy-sell) is
explicitly **M8** — nothing here prices anything.

**Why now (user, roadmap restructure 2026-07-03):** weapon-driven evolution is core
class identity ([Warrior] → [Blademaster] vs [Spearmaster] follows the wielded
weapon), and equipment is a complex base component to build while Fable leads.
M6's skill weapon-tags (T1) are the seam: the wielded weapon gates which tagged
skills you can field → which counters accrue → which evolution you qualify for.
**M6 needs zero amendment** — this milestone plugs into it.

## 0. Decisions (locked)

| Decision | Call |
|---|---|
| Weapon model | **Gate + modest stats**: weapon gates its skill family AND carries a small damage mod; skills stay the power source |
| Slots | **Weapon + armor**, two slots; armor = flat damage reduction and/or small max-HP bonus; shields/accessories later |
| Acquisition (pre-economy) | **All three**: combat loot drops (per-encounter tables), placed/found gear (containers, quest reward), Relc's starter spear at the Floodplains meeting |
| UI | **Inventory screen on I** — parchment panel, journal interaction grammar |
| Extensibility (user amendment) | `tier` field (default `"mundane"`) + reserved `abilities: []`, both inert this milestone — Gold-Rank gear and Relics later add data, not schema |
| Start state | PC starts with **Rusty Sword equipped** — existing fights keep their shape; Relc's spear creates the first identity fork |

## 1. Data — `data/items.json` (new)

```jsonc
{
  "items": [
    {
      "id": "rusty_sword",
      "name": "Rusty Sword",
      "kind": "weapon",                // weapon | armor
      "weapon_family": "sword",        // sword | spear | none (armor)
      "damage_mod": 0,                 // added to melee attack damage
      "hp_mod": 0,                     // armor: added to max_hp
      "damage_reduction": 0,           // armor: flat incoming-damage reduction (min 1 dmg rule stands)
      "tier": "mundane",               // reserved: mundane | gold_rank | relic (only mundane ships)
      "abilities": [],                 // reserved, INERT in M7 (Gold-Rank/Relic hook)
      "description": "Seen better decades. Still swings."
    }
  ]
}
```

Starter set (~8, canon-flavored, all `mundane`): `rusty_sword` (PC start, equipped),
`relcs_spare_spear` (Relc intro gift; damage_mod +1), `crude_blade` / `chipped_spear`
(goblin drops), `leather_jerkin` (+4 hp), `watch_issue_gambeson` (dr 1, quest reward
candidate), `traveler_charm` (armor-slot trinket, +2 hp, placed at ruin-stones POI),
`solid_oak_spear` (chest/container find). Exact numbers are provisional — the
harness settles them (§5).

Encounters (`skeleton_scene.json` entities / arenas) gain optional
`"loot": [{"item": id, "chance": 0.0-1.0}]` rolled once per item on victory with the
encounter's seeded RNG (deterministic per seed). Container props gain
`"contains": [item_ids]` (chest prop becomes real; emptied containers persist via
save state).

## 2. Sim (Approach A — equipment as pure sim state)

- `WIGame.inventory: Array[String]` (item ids, unordered, no stacking — YAGNI) and
  `WIGame.equipped: Dictionary {"weapon": id|"", "armor": id|""}`.
- API: `pickup(item_id, source_id)` (adds to inventory, emits `ITEM_GAINED`),
  `equip(item_id)` / `unequip(slot)` (validates kind/possession, emits
  `ITEM_EQUIPPED`/`ITEM_UNEQUIPPED`). Field-only actions — no mid-combat swaps
  (Approach B's seam stays open; the combat build reads equipment ONCE at start).
- **Combat build injection** (in the existing `start_combat` build step): PC skill
  list = class kit ∩ (equipped weapon_family's tagged skills + untagged skills);
  weapon `damage_mod` added to the combatant's attack damage; armor `hp_mod` to
  max_hp, `damage_reduction` applied in `_deduct_hp` before mana_shield (floor:
  a landed hit always deals ≥1). Unarmed (deliberate unequip only): basic attack
  + untagged skills.
- **Counters follow automatically:** T1 tallies tagged skills at the single spend
  site; the weapon gate decides which tagged skills exist in the kit. No M6 change.
- Save v3: `inventory`, `equipped`, and emptied-container/claimed-loot state join
  the payload (single bump; rejects v2 per the M5 precedent).
- WIEvents additions: `ITEM_GAINED`, `ITEM_EQUIPPED`, `ITEM_UNEQUIPPED`,
  `UI_INVENTORY_SHOWN`, `UI_INVENTORY_HIDDEN`, `LOOT_DROPPED`.

## 3. UI

- `I` toggles the inventory panel: UIChrome parchment, journal grammar (arrows
  navigate, Enter equips/unequips, I/Esc closes). Two slot rows pinned top
  ("Weapon: Rusty Sword", "Armor: —"), carried list below. Emits
  `ui_inventory_shown {items: N}` / `ui_inventory_hidden`.
- Pickups toast via the existing parchment toast ("Got: Relc's Spare Spear").
  Victory loot surfaces as pickup toasts after the banner closes.
- Hotbar re-renders on equip (kit changes with the weapon) — existing
  `ui_hotbar_rendered` contract carries it.
- **No raw stats rule** stands: item lines read as prose + the already-player-visible
  HP/damage numbers ("Leather Jerkin — boiled leather, +4 HP"). Never STR/DEX/INT.
- Footer hint gains "I — inventory" (discoverability lesson from M2 save/load).

## 4. Content integration

- Relc's Floodplains introduction (Floodplains design §6) gifts `relcs_spare_spear`
  via the conversation's effects path — the player's first sword-vs-spear moment.
  (Lands with the Floodplains door-graph integration; M7 ships the mechanism +
  a placed fallback copy so the system is testable before that map is reachable.)
- Inn chest `contains` a starter armor piece; ruin-stones POI holds the trinket
  (data ready, reachable when Floodplains wires in).
- Goblin encounters get drop tables (crude_blade / chipped_spear, low chance).

## 5. Balance + QA

- Harness gains a **loadout axis**: sword build vs spear build vs unarmored/armored
  across the existing composition matrix; win-rate gate 0.55–0.95 and median 3–12
  still govern; item numbers are DATA tuned by the harness, never sim edits.
- Canonical seeds WILL move (damage mods shift trajectories) — re-derivation is the
  milestone's F-task, M5-style.
- New QA: `inventory_loop` (pickup → open inventory → equip spear → fight →
  assert spear counters accrued & sword counters didn't → victory loot → assert
  ITEM_GAINED + toast rendered). Existing walkthroughs gain container/pickup beats
  where cheap. Unit tests: items data validation (ids unique, kinds/families legal,
  kit-intersection math, damage_reduction floor, save v3 round-trip incl. emptied
  containers, v2 rejection).

## 6. Out of scope (M8+)

Economy (coins, shops, buy/sell at the Liscor market row), item stacking,
consumables, durability, mid-combat weapon swap, shields/accessory slots,
Gold-Rank/Relic mechanics (schema hook only), enemy equipment visibility,
PC sprite weapon rendering.
