# Class & Skill Expansion — Implementation Spec (Waves A+B)

**Authority chain:** this spec implements
`docs/design/class-skill-expansion-proposal.md` as ruled 2026-07-15:
scope = Waves A+B (C parked with #92); witch = no gender gate, canon-liberty
flag; [Flash Step] = Necromancer L7 **and** Mage L11 (same Pisces teaching
beat); Necromancer evolution = PARKED, aspiration-only. [Eagle Eyes]
AMBIGUOUS-lean-PASS flag: ACCEPT logged as a CHOICES entry, **user ACK
requested pre-branch** (spec-verify canon finding: it is one of two names
riding a drift flag; the other, [Enhanced Movement], was downgraded to
ORIGINAL ⚑ instead). Execution briefs may correct stale text here —
briefs win.

**Issue structure (dependency-forced):** props reference skill ids;
`gained_by` counters need producers in the same tree for
`test_content.gd`. Therefore:
- **Issue WA — "Class expansion Wave A (data)":** one branch, one PR.
  Sub-lanes with disjoint file ownership (§8).
- **Issue WB — "Class expansion Wave B (overworld verbs)":** blink, ward,
  companion. One branch, one PR, engine files single-implementer.

Wave C (parked, do NOT implement): [Courier's Word] +1g, [Generous
Portions], [Sure Delivery] (fragile machinery lives in `bounties.gd:135`,
unverified semantics), witch hat sprite, [Tea Witch] fork, economy retune
(#92 owns pricing). **Controller delta vs the proposal's Wave-C list:**
`signature_dish` (Wave A) and `greater_hearthward` (WB) are pulled
forward — the proposal's own class tables already grant both at class
levels (§4.4/§4.2), they are pure data, and only their PRICING defers to
#92; the pull-forward resolves that internal inconsistency in favor of
the tables.

---

## 1. New counters (all banked via existing seams)

| Counter | Producer | Seam |
|---|---|---|
| `completed_delivery` | every delivery completion | 1 line in `_check_delivery_arrival` next to `wi_game.gd:327`'s `delivered_%s` bank |
| `witch_lessons` | Eloise teaching node (riverfarm_witch.json) | dialogue `effects: [{"accomplishment": ...}]` |
| `witch_craft_used` | every witch craft prop/verb (brew cauldrons now; ward casts in WB) | prop `on_skill_use.accomplishment`; WB ward branch banks it too |
| `studied_necromancy` | Pisces study node (pisces_magic.json) | dialogue effect |
| `death_cast` | automatic | `element: "death"` on bone_dart/deathbolt — `wi_combat.gd:740-742` banks `<element>_cast`, zero code |
| `blinked_past_danger` (WB) | blink crossing an armed `trigger_radius` | new blink branch, sneak-parity dedup (`danger:<id>` key pattern) |
| `warded_danger` (WB) | ward cast suppressing an ambush | ward branch |

`cooked_meal`, `delivered_item`, `sneaked_past_danger`, `ranged_hit`,
`won_combat`, `spell_cast` already ship with producers.

## 2. classes.json additions (Wave A lane L-DATA)

Threshold discipline: **no new pacing formulas** — every curve below is a
shipped curve reused verbatim, named in each record's `_comment`.
Curves: ROGUE = 2/4/7/10/14/18/23/29/36 (L2–L10); TRADER = 8/12/17/23/30/
38/47/57/68 (L2–L10, gained_by 5); MAGE = won_combat 3 at L2, then
4/8/13/18/24/30/37/45/54/64 (L3–L12); HELPER-delivered = 3/6/10/15/21/28/
36/45/55 (L2–L10).

### [Runner] → [Courier]
```json
{
  "_comment": "Curves: completed_delivery = rogue's sneaked_past_danger curve verbatim; delivered_item = helper's delivered_item column verbatim (requires_any, helper precedent). Counter-sharing with helper sanctioned (melee_hit feeds warrior AND spellsword). Evolution: SINGLE-AXIS on completed_delivery (tactician/trader precedent); min_uses 12 clears trivially (L10 threshold 36 >> 12). Street/City Runner are guild RANKS in canon, not classes -- rank text lives in Runner's Guild board copy only.",
  "id": "runner",
  "display_name": "Runner",
  "stat_growth": { "dex": 1 },
  "gained_by": { "accomplishment": { "completed_delivery": 2 } },
  "aspiration": { "display_name": "Courier", "text": "Run enough roads, fast enough, long enough, and the Guilds stop calling you a [Runner]. Couriers cross continents." },
  "evolution": {
    "at_level": 10, "dominance_share": 0.6, "min_uses": 12,
    "targets": { "completed_delivery": "courier" }
  },
  "levels": [
    { "level": 1, "requires": {}, "grants": ["quick_movement", "runners_legs"] },
    { "level": 2, "requires_any": { "completed_delivery": 2, "delivered_item": 3 }, "grants": [] },
    { "level": 3, "requires_any": { "completed_delivery": 4, "delivered_item": 6 }, "grants": ["efficient_run"] },
    { "level": 4, "requires_any": { "completed_delivery": 7, "delivered_item": 10 }, "grants": [] },
    { "level": 5, "requires_any": { "completed_delivery": 10, "delivered_item": 15 }, "grants": [] },
    { "level": 6, "requires_any": { "completed_delivery": 14, "delivered_item": 21 }, "grants": [] },
    { "level": 7, "requires_any": { "completed_delivery": 18, "delivered_item": 28 }, "grants": [] },
    { "level": 8, "requires_any": { "completed_delivery": 23, "delivered_item": 36 }, "grants": [] },
    { "level": 9, "requires_any": { "completed_delivery": 29, "delivered_item": 45 }, "grants": [] },
    { "level": 10, "requires_any": { "completed_delivery": 36, "delivered_item": 55 }, "grants": [] }
  ]
}
```
Runner L5 grants stay `[]` in WA; WB adds `"double_step"` there.
```json
{
  "_comment": "SPARSE TABLE (GH#54): [Courier] is Replacement-only -- floor = runner's evolution.at_level (10). completed_delivery continuation +8/+9 (rogue-delta continuation, the sharpshooter-past-floor pattern). CANON: [Courier] attested as class (4.24, 4.44 M).",
  "id": "courier",
  "display_name": "Courier",
  "stat_growth": { "dex": 1, "con": 1 },
  "inherits": "runner",
  "levels": [
    { "level": 10, "requires_any": { "completed_delivery": 36, "delivered_item": 55 }, "grants": ["enhanced_movement"] },
    { "level": 11, "requires_any": { "completed_delivery": 44 }, "grants": [] },
    { "level": 12, "requires_any": { "completed_delivery": 53 }, "grants": [] }
  ]
}
```

### [Hedge Witch] → [Witch]
```json
{
  "_comment": "CANON: [Hedge Witch] attested 6.41 E ('self-taught mage'); progression to full [Witch] = craft proven, the arc's own rule ('a hedge witch WITH a craft beats a trained witch without one'). NO GENDER GATE -- canon witches are female-coded through Vol 7; PC is unspecified; canon-liberty flag, user-ratified 2026-07-15. Curve: witch_craft_used = rogue's sneaked curve verbatim. Single-axis evolution on the UMBRELLA counter witch_craft_used (every craft prop banks it) -- avoids the 2-keys-1-target dominance trap (see trader's _comment).",
  "id": "hedge_witch",
  "display_name": "Hedge Witch",
  "stat_growth": { "int": 1 },
  "gained_by": { "accomplishment": { "witch_lessons": 1 } },
  "aspiration": { "display_name": "Witch", "text": "A [Witch] is her craft. Find yours, and the hat will follow." },
  "evolution": {
    "at_level": 10, "dominance_share": 0.6, "min_uses": 12,
    "targets": { "witch_craft_used": "witch" }
  },
  "levels": [
    { "level": 1, "requires": {}, "grants": ["hedge_remedy"] },
    { "level": 2, "requires": { "witch_craft_used": 2 }, "grants": [] },
    { "level": 3, "requires": { "witch_craft_used": 4 }, "grants": ["witchs_warding"] },
    { "level": 4, "requires": { "witch_craft_used": 7 }, "grants": [] },
    { "level": 5, "requires": { "witch_craft_used": 10 }, "grants": [] },
    { "level": 6, "requires": { "witch_craft_used": 14 }, "grants": [] },
    { "level": 7, "requires": { "witch_craft_used": 18 }, "grants": ["evil_eye"] },
    { "level": 8, "requires": { "witch_craft_used": 23 }, "grants": [] },
    { "level": 9, "requires": { "witch_craft_used": 29 }, "grants": [] },
    { "level": 10, "requires": { "witch_craft_used": 36 }, "grants": [] }
  ]
}
```
Hedge witch L5 stays `[]` in WA; WB adds `"hearthward_charm"`.
```json
{
  "_comment": "SPARSE TABLE (GH#54): [Witch] is Replacement-only -- floor = hedge_witch's evolution.at_level (10). Continuation +8/+9 (rogue-delta). CANON: [Witch] class requirements cited 6.41 E (defining passion, a hat, a personal craft) -- the evolution sleep-beat IS the moment; hat visual parked Wave C.",
  "id": "witch",
  "display_name": "Witch",
  "stat_growth": { "int": 1, "cha": 1 },
  "inherits": "hedge_witch",
  "levels": [
    { "level": 10, "requires": { "witch_craft_used": 36 }, "grants": [] },
    { "level": 11, "requires": { "witch_craft_used": 44 }, "grants": [] },
    { "level": 12, "requires": { "witch_craft_used": 53 }, "grants": [] }
  ]
}
```
Witch L10 gets `"greater_hearthward"` in WB.

### [Necromancer]
```json
{
  "_comment": "CANON: Pisces holds [Necromancer] from pre-story (1.06 R) and dual-classes [Mage] Lv 20 (6.67) -- separate base class held BESIDE mage is canon-exact, and leaves mage's shipped evolution block untouched. Curve: mage's own shape verbatim (won_combat 3 at L2, spell_cast curve on death_cast L3+; death_cast banks automatically off element:'death', wi_combat.gd:740-742). EVOLUTION PARKED (user-ratified 2026-07-15): no attested <=Vol-7 necromancer evolution exists; aspiration carries the fantasy; revisit on canon find. This is the roster's one deliberate no-evolution exception. ASPIRATION CANON-VERDICT: display_name 'Master of the Old Art' = ORIGINAL, canon-plausible flag; the text's shapes-no-grave phrasing is covered by Bone Horrors 4.37 O (PASS, pre-Book-17).",
  "id": "necromancer",
  "display_name": "Necromancer",
  "stat_growth": { "int": 1 },
  "gained_by": { "accomplishment": { "studied_necromancy": 1 } },
  "aspiration": { "display_name": "Master of the Old Art", "text": "At the height of the art, the dead answer in shapes no grave ever held." },
  "levels": [
    { "level": 1, "requires": {}, "grants": ["bone_dart", "detect_magic"] },
    { "level": 2, "requires": { "won_combat": 3 }, "grants": [] },
    { "level": 3, "requires": { "death_cast": 4 }, "grants": ["deathbolt"] },
    { "level": 4, "requires": { "death_cast": 8 }, "grants": [] },
    { "level": 5, "requires": { "death_cast": 13 }, "grants": [] },
    { "level": 6, "requires": { "death_cast": 18 }, "grants": [] },
    { "level": 7, "requires": { "death_cast": 24 }, "grants": [] },
    { "level": 8, "requires": { "death_cast": 30 }, "grants": [] },
    { "level": 9, "requires": { "death_cast": 37 }, "grants": [] },
    { "level": 10, "requires": { "death_cast": 45 }, "grants": [] },
    { "level": 11, "requires": { "death_cast": 54 }, "grants": [] },
    { "level": 12, "requires": { "death_cast": 64 }, "grants": [] }
  ]
}
```
Aspiration display_name is ORIGINAL ⚑ (flag in `_comment` if reviewer
prefers it inline). WB adds `"animate_dead"` at L5, `"flash_step"` at L7.

### [Cook] → [Chef]
```json
{
  "_comment": "CANON: [Cook] attested 3.16 (Garry); [Chef] 6.10 (Lasica, Pallass). Producers ship today (inn hearth props bank cooked_meal). Curve: trader's deliberate_commerce curve VERBATIM (same gained_by-5 start). Single-axis evolution, min_uses trivially cleared (68 >> 12).",
  "id": "cook",
  "display_name": "Cook",
  "stat_growth": { "con": 1 },
  "gained_by": { "accomplishment": { "cooked_meal": 5 } },
  "evolution": {
    "at_level": 10, "dominance_share": 0.6, "min_uses": 12,
    "targets": { "cooked_meal": "chef" }
  },
  "levels": [
    { "level": 1, "requires": {}, "grants": ["advanced_cooking"] },
    { "level": 2, "requires": { "cooked_meal": 8 }, "grants": [] },
    { "level": 3, "requires": { "cooked_meal": 12 }, "grants": [] },
    { "level": 4, "requires": { "cooked_meal": 17 }, "grants": [] },
    { "level": 5, "requires": { "cooked_meal": 23 }, "grants": ["perfect_recall"] },
    { "level": 6, "requires": { "cooked_meal": 30 }, "grants": [] },
    { "level": 7, "requires": { "cooked_meal": 38 }, "grants": [] },
    { "level": 8, "requires": { "cooked_meal": 47 }, "grants": [] },
    { "level": 9, "requires": { "cooked_meal": 57 }, "grants": [] },
    { "level": 10, "requires": { "cooked_meal": 68 }, "grants": [] }
  ]
}
```
```json
{
  "_comment": "SPARSE TABLE (GH#54): [Chef] is Replacement-only -- floor = cook's evolution.at_level (10). Trader-delta continuation +12/+13.",
  "id": "chef",
  "display_name": "Chef",
  "stat_growth": { "con": 1, "dex": 1 },
  "inherits": "cook",
  "levels": [
    { "level": 10, "requires": { "cooked_meal": 68 }, "grants": ["signature_dish"] },
    { "level": 11, "requires": { "cooked_meal": 80 }, "grants": [] },
    { "level": 12, "requires": { "cooked_meal": 93 }, "grants": [] }
  ]
}
```

### [Scout] consolidation
Consolidations array entry (pinned gate shape — same `_comment`
convention as innkeeper/ranger):
```json
{
  "_comment": "SAME gate shape as [Spellsword]/[Innkeeper]/[Ranger] (min_parent_level 10, min_combined_level 21). CANON: [Scout] attested 3.02 H (Halrac); [Veteran Scout] is his class through Vols 3-7.",
  "id": "scout",
  "target": "scout",
  "parent_lines": [
    ["rogue", "infiltrator"],
    ["archer", "sharpshooter"]
  ],
  "min_parent_level": 10,
  "min_combined_level": 21
}
```
```json
{
  "_comment": "Floor = 14 (derived: min_parent_level 10 + min_combined_level 21 -> merged max(ceil(2*(10+11)/3), 11) = 14, the spellsword walk; test_content re-derives). Thresholds: sneaked_past_danger = rogue-delta continuation past 36 (+8/+8/+9 -> 44/52/61 at 14/15/16 is NOT used; see below); ranged_hit reuses the ranger precedent (sharpshooter's late values 80/95/110). requires_any of the two parent verbs, spellsword shape. sneaked continuation: 36(+8)=44 @14, 52 @15, 61 @16.",
  "id": "scout",
  "display_name": "Scout",
  "stat_growth": { "dex": 1, "int": 1 },
  "inherits": ["rogue", "archer"],
  "aspiration": { "display_name": "Veteran Scout", "text": "The wood, the wall, and the enemy camp: a [Veteran Scout] has already been there, and left no sign." },
  "levels": [
    { "level": 14, "requires_any": { "sneaked_past_danger": 44, "ranged_hit": 80 }, "grants": ["eagle_eyes"] },
    { "level": 15, "requires_any": { "sneaked_past_danger": 52, "ranged_hit": 95 }, "grants": [] },
    { "level": 16, "requires_any": { "sneaked_past_danger": 61, "ranged_hit": 110 }, "grants": ["marked_quarry"] }
  ]
}
```

### [Mage] edit
L7 (`spell_cast: 24`) grants `[]` → `["detect_magic"]`. L11
(`spell_cast: 54`) stays `[]` in WA; WB adds `"flash_step"`.
Mandatory checks (both waves): grep `data/dialogue/** data/maps/**` for
`"skill": "detect_magic"` / `"flash_step"` (new ids — expect zero gates);
grep `qa/scripts` for `ui_hotbar_rendered` against fixtures holding mage
≥L7 (near_evolution/near_generalist fixtures) and update asserted slot
counts.

## 3. skills.json additions

**Wave A (14 records).** Canon verdicts inline; ⚑ = ORIGINAL,
canon-plausible flag in `_comment` (established convention). Icon ids
follow `icon_<skill_id>`; icon REQUIRED for any hotbar-castable skill
(field or AP-costed combat active); pure passives ship without.

| id | display_name | contexts | mechanics (reuse only) | canon `_comment` |
|---|---|---|---|---|
| `runners_legs` | [Runner's Legs] | exploration | pure passive identity (bargain/lesser_stamina shape — no ap/effect/field) | ⚑ ORIGINAL. "The road is long. Your legs have stopped caring." |
| `efficient_run` | [Efficient Run] | exploration | pure passive identity | ATTESTED — Fals, 7.00 (inside Book 17) |
| `enhanced_movement` | [Enhanced Movement] | combat | `ap_cost 0, effect move_pool_bonus 1` (battlefield_awareness twin) | ⚑ ORIGINAL, canon-plausible — adjudicated at spec-verify: the wiki lists the name with a Vol-1-era cite that no longer resolves (renumbering drift); per spoiler rule 5 the drifted cite cannot carry an ATTESTED verdict, so it ships under the ORIGINAL flag with the wiki note in the `_comment` |
| `hedge_remedy` | [Hedge Remedy] | exploration | `field: true`, `field_ambient` (idle line: stirring an absent pot), casts at cauldron props (`requires_skill` seam), icon | ⚑ ORIGINAL — renamed from [Brew Remedy] at spec-verify (ruling 9: bare imperative fails; [Hedge Remedy] is the clean noun phrase, echoes [Hedge Witch]) |
| `witchs_warding` | [Witch's Warding] | combat | `ap_cost 0, effect hp_bonus 8` — NOT mana_shield (witch kit is deliberately AP-only; mana_shield without an MP pool is dead weight) | ⚑ ORIGINAL |
| `evil_eye` | [Evil Eye] | combat | `ap_cost 2, effect spell_damage range 3, applies weakened duration_rounds 1` — calming_touch's exact no-mp shape, longer range, weaken not slow. NO `element` (witch craft ≠ death magic; must not bank an element counter) | ⚑ ORIGINAL — wiki-check at implementation; icon |
| `bone_dart` | [Bone Dart] | combat | `ap_cost 1, mp_cost 2, element "death", spell_damage range 4` — frost_bolt's costs, no rider | ATTESTED — Pisces' spell list; icon |
| `deathbolt` | [Deathbolt] | combat | `ap_cost 2, mp_cost 4, element "death", spell_damage range 4, applies weakened duration_rounds 1` | ATTESTED — Pisces; icon |
| `detect_magic` | [Detect Magic] | exploration | `field: true`, `field_ambient`, casts at warded/magical props; icon | ATTESTED — spell, Pisces & Ceria, 2.15 |
| `advanced_cooking` | [Advanced Cooking] | exploration | `field: true`, `field_ambient`, casts at chef-station props → fine_meal item; icon (distinct from icon_basic_cooking) | ATTESTED — Erin 2.17 |
| `perfect_recall` | [Perfect Recall] | exploration | pure passive identity (recipes/arts scope in description) | ATTESTED — Erin 2.17 |
| `signature_dish` | [Signature Dish] | exploration | `field: true`, chef-station props → signature_meal item; icon | ⚑ ORIGINAL |
| `eagle_eyes` | [Eagle Eyes] | exploration, combat | `field: true` (vantage props), `ap_cost 0, effect hit_bonus 8` in combat; icon | ATTESTED w/ flag — AMBIGUOUS-lean-PASS (renumbering drift), ACCEPTED 2026-07-15 |
| `marked_quarry` | [Marked Quarry] | combat | `ap_cost 2, weapon "bow", once_per_fight: true, effect damage_mult 1.8` — sudden_strike's pre-balanced numbers | ⚑ ORIGINAL (noun phrase) |

(13 named + signature_dish = 14; table folds them.)

**Wave B (5 records)** — exact field-verb flags fixed by the WB engine
design (§7):
| id | display_name | contexts | mechanics | canon |
|---|---|---|---|---|
| `double_step` | [Double Step] | exploration, combat | field `blinks: true, blink_range: 2`; combat `ap_cost 1, move_pool_bonus 2`; icon | ATTESTED — Valceif 2.15 |
| `flash_step` | [Flash Step] | exploration, combat | field `blinks: true, blink_range: 4`, `mp_cost 3`; combat `ap_cost 2, mp_cost 3, move_pool_bonus 3` (in-combat true-teleport = future resolver, documented compromise); icon | ATTESTED — Pisces' Tier-3 spell (mainline ~3.26) |
| `animate_dead` | [Animate Dead] | exploration | field `animates: true` at bone-pile props, `mp_cost 4` → skeleton companion until fall/sleep; icon | ATTESTED — Pisces |
| `hearthward_charm` | [Hearthward Charm] | exploration | field `wards: true` → suppress one armed ambush until next sleep; banks `warded_danger` + `witch_craft_used`; icon | ⚑ ORIGINAL |
| `greater_hearthward` | [Greater Hearthward] | exploration | `wards: true, ward_sleeps: 2` (persists an extra sleep) — new id, never a re-semanticized hearthward_charm; icon | ⚑ ORIGINAL |

## 4. items.json additions (Wave A)

- `remedy_draught` — consumable heal, witch-brewed; numbers mirror the
  shipped heal consumable band; honest use-at-full-HP behavior follows
  the #92 taste-queue precedent (consumes, "Healed 0 HP").
- `fine_meal` — `kind: "meal"`, pending_meal payload one clear step above
  `hot_meal` (implementer reads hot_meal's payload and adds +1 to one mod,
  not a new axis).
- `signature_meal` — `kind: "meal"`, chef-tier: hot_meal's payload +2
  spread across two mods. Conservative pricing, `_comment` deferring to
  #92.

## 5. Dialogue (Wave A lane L-DIALOGUE)

- **`riverfarm_witch.json` — Eloise teaching chain.** New post-quest
  branch gated `requires {"blight_lifted": 1}` + `hide_when
  {"drove_off_collectors": 1}` — i.e. any PEACEFUL resolution qualifies
  (brokered or paid, matching the ratified OR-path; the hide_when idiom
  is shipped precedent, invrisil_wilovan.json hub). Violent-path players
  are excluded, deliberate. **Documented delta:** the proposal's extra
  warmth gate (befriended_moments tier) is DROPPED — the peaceful quest
  resolution already is the respect beat; a second gate double-charges
  it. Two-beat: ask about the craft → she sets a small task of
  words (reuse existing node machinery, no new verbs) → effects bank
  `witch_lessons`. Voice per Eloise profile (warm, tea-first, terms
  precise). NO progress language, NO stat words.
- **`pisces_magic.json` — necromancy study chain.** New branch gated on
  holding [Mage] (class gate, same dict dialogue already reads) +
  `learned_magic_from_pisces: 1`. Beat: the PC asks about the OTHER art;
  Pisces deflects once (first visit), teaches on the second ask
  (`bank_first_use` dedup or a two-node chain — implementer picks the
  existing idiom); effects bank `studied_necromancy`. Include the
  footwork-lesson flavor line (WB's [Flash Step] teaching beat callback:
  he demonstrates, "a fencer's trick first, a spell second"). Stigma
  stays diegetic.
- **Watch cold lines.** One variant line each for Zevara and Dresk gated
  `{"studied_necromancy": 1}` — cold, professional, no mechanics
  (CHOICES #26 shape: profiles carry friction, no new NPCs).

## 6. Map props (Wave A lane L-MAPS)

All zero-engine (`requires_skill` + `on_skill_use` + `skill_hint_toast` +
`locked_toast`, the inn stove pattern at `inn.json:632-640`). Every prop
banks its counter EVERY use (grind = the leveling model; hot_meal
precedent). Blocked-cell props follow #116 biome-aware conventions;
sprites from existing pack stock per wi-art-and-sprites (no new pack
browsing).

| Map | Prop | requires_skill | on_skill_use |
|---|---|---|---|
| witch_hollow | Eloise's cauldron (distinct from the existing basic_cooking pot) | `hedge_remedy` | `witch_craft_used` + item `remedy_draught` |
| inn | hearth-side kettle alcove | `hedge_remedy` | `witch_craft_used` + item `remedy_draught` |
| inn | chef's counter (kitchen, beside existing stew pot) | `advanced_cooking` | `cooked_meal` + item `fine_meal`; variant array: `signature_dish` known → item `signature_meal` (latest-satisfied-wins, street.json:1526 precedent) — NOTE: variant keys on a counter, so bank `knows_signature_dish` via... NO: variant `when` reads counters only. Simplest: a SECOND prop entry gated `requires_skill: signature_dish` on the adjacent cell ("the good copper pan"). |
| pallass_market | food stall burner | `advanced_cooking` | `cooked_meal` + item `fine_meal` |
| trapped_halls | warded seam by the illusory floor | `detect_magic` | `observed_things`-style bank: `detected_wardwork` + toast revealing the trap-tell (hint layer only — existing observe/disarm routes stay the mechanical bypass) |
| inn | cellar door wardwork | `detect_magic` | `detected_wardwork` + lore toast (door_that_goes_elsewhere callback) |
| witch_hollow | leyline stone | `detect_magic` | `detected_wardwork` + toast; `visual_states.when` tint at counts (existing seam in this map) |
| ruin_surface | anchor-stone socket | `detect_magic` | `detected_wardwork` + lore toast |
| pallass_market | Grand Lift overlook rail | `eagle_eyes` | `scouted_vantage` + toast + small gold find (1g, band-consistent) |
| floodplains | hilltop cairn | `eagle_eyes` | `scouted_vantage` + toast |
| invrisil_boulevard | rooftop line from the parlor steps | `eagle_eyes` | `scouted_vantage` + toast |
| trapped_halls, deep_tunnels, ruin_surface | bone piles (one each) | none in WA (decor, `blocked: true`) | WB wires `animates` targeting |

New orphan counters (`detected_wardwork`, `scouted_vantage`) are legal
(producers without consumers pass test_content) and become future gate
currency.

## 7. Wave B engine design (Issue WB — single implementer on src)

Three seams, all in `field_skills.gd` dispatch + `wi_game.gd`, PURE sim
(no Node refs), each with its own QA script + windowed pass:

1. **Blink** (`blinks: true`, `blink_range: N`): new dispatch branch —
   target cell = farthest walkable, unoccupied cell along `player_facing`
   within N with clear line (reuse the LoS/walkable helpers combat uses);
   refusal toast when blocked at range 1. Set `player_cell`, emit a
   `PLAYER_TELEPORTED` event (world renders afterimage streak; reduced-
   motion honored). **Trigger-crossing rule:** for each armed
   `trigger_radius` encounter, if the START or any crossed cell is inside
   its radius and the END is outside, bank `blinked_past_danger`
   (dedup `danger:<id>`, sneak parity at `wi_game.gd:279-301`) and do NOT
   fire; landing INSIDE a radius fires it normally (blinking into an
   ambush is on you). MP check for flash_step's `mp_cost` uses the same
   field-mp seam invisibility already exercises.
2. **Ward** (`wards: true`): cast at a faced armed encounter entity
   within the faced direction... NO — cast on the faced CELL; the nearest
   armed `trigger_radius` encounter whose radius contains that cell
   becomes `warded_until_sleep` (stored on game state, save-persisted);
   `_check_trigger_radius` skips warded entities; banks `warded_danger` +
   `witch_craft_used` once per entity (dedup). Sleep clears wards
   (`ward_sleeps: 2` decrements instead). Refusal toast when no ambush in
   reach. Visual: a placed charm sprite on the cell + faint ring.
3. **Companion** (`animates: true`): cast at a faced bone-pile prop →
   consumes prop (remove_entity + scorched-terrain-style swap), sets
   `companion: "skeleton_ally"` on game state (save-persisted); a
   follower sprite trails the player (world layer); `start_combat`
   (`wi_game.gd:1281-1293`) appends the companion to allies (after
   `ally_requires` filtering, before `ally_hp_penalty`); companion death
   in combat clears the state ("the bones do not get up again"); sleep
   clears it (the working fades). `skeleton_ally` = new combatants.json
   record cloned from the vault skeleton at tuned-down HP (sim lane owns
   numbers).

WB also: add `double_step` to runner L5, `flash_step` to necromancer L7 +
mage L11, `animate_dead` to necromancer L5, `hearthward_charm` to
hedge_witch L5, `greater_hearthward` to witch L10; re-run the mage/necro
QA hotbar audits.

## 8. Lanes, ownership, gates

**Issue WA branch `issue/<n>-class-expansion-wave-a`, one shared
worktree, controller stages per lane (implementers do NOT commit):**
- **L-DATA:** `data/classes.json`, `data/skills.json`, `data/items.json`,
  `data/sprites.json` + icon assets via `tools/sync_assets.py`
  placeholder shapes (icon drain note → VISUAL-LOG for PixelLab pass).
- **L-DIALOGUE:** `data/dialogue/riverfarm_witch.json`,
  `pisces_magic.json`, `zevara_intro.json`, `dresk_recruit.json`.
- **L-MAPS:** the six map files in §6.
- **L-SRC:** `src/core/wi_game.gd` (ONE line: `completed_delivery` bank)
  + `tests/` additions (progression fixtures for the five new
  classes/consolidation, sim BUILDS rows: necromancer solo).
- **L-QA:** `qa/scripts/` + `qa/fixtures/`: `cook_chef_loop.json`,
  `runner_courier_loop.json`, `hedge_witch_loop.json`,
  `necromancer_loop.json`, `scout_consolidation_loop.json` (model:
  class_evolution_loop + near_evolution-style hand-authored fixtures per
  wi-writing-qa-scripts; each asserts the domain event AND, for combat
  classes, pc.skills contains the grant).

**Gates (per wi-verifying-changes):** headless smoke (zero warnings);
`test_progression`; `test_content`; `test_shipped_ids` (all new ids
pre-freeze); `sim_combat_batch` (necromancer rows in 0.55–0.95);
`qa/ci_sweep.sh --tier smoke` + the five new loops + crossing canonicals
(`--touching` for data lanes; L-SRC uses smoke minimum, never
--touching alone); composed-tree re-run after lane staging; per-lane
reviewer dispatch, fix wave, whole-branch review before PR;
wi-machine-playtest windowed pass (new props/toasts are player-visible
surface). PR body per issue-close template.

**Issue WB branch:** L-SRC-VERBS (field_skills.gd, wi_game.gd, world.gd
visuals, save.gd persistence — single implementer), L-DATA-B (skills/
classes/combatants deltas), L-QA-B (blink/ward/companion loops + a
floodplains road-ambush bypass script proving all three mobility answers
coexist). Same gates + sim with-skeleton rows + windowed screenshots of
blink streak, ward charm, follower.

## 9. Product-lock checklist (every lane brief carries it)

Opaque-until-sleep (no "N/12", no progress bars, results only); stat
grammar default (HP/MP/AP/damage OK; STR/DEX etc. out of player copy);
canon voice descriptions (prose, never stat readouts); noun-phrase Skill
names (ruling 9); spoiler two-tier (nothing past Book 17 in new copy;
Vol 8-9 names hard-banned: Pelt's class, Wilovan's class, [Crow Witch],
[Mass Teleportation], witch-hat power phrasing stays loose); ids are
permanent once shipped — get them right now (`snake_case`, no rename
after the next freeze cut).
