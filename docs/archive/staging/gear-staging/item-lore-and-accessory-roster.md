# M-GEAR Task G2 staging — item lore + accessory roster

**STAGING DOCUMENT ONLY.** Nothing under `wandering_inn_game/` is touched by
this doc. G2's implementer assembles from here into `data/items.json`,
`data/dialogue/krshia_crate.json`, `data/skeleton_scene.json` (loot/quest
sources), and the tests named in §D. Not committed by the staging lane.

Sources read: spec `docs/superpowers/specs/2026-07-06-systems-depth-priorities.md`
§1; plan `docs/superpowers/plans/2026-07-06-m-gear.md` (G2 + Global
Constraints); `wandering_inn_game/data/items.json`; voice contract
`.claude/skills/wi-adding-dialogue-and-quests/SKILL.md` (voice lint) +
`docs/design/character-profiles.md` + the positive exemplars in
`.superpowers/sdd/fp-handoff/voice-preaudit-report.md`.

**Flag legend.**
- `[CANON-CHECK: …]` — a canon-adjacent claim the controller must verify
  against the Wandering Inn Wiki before assembly. Names already shipped in
  game data (Liscor, the Watch, Relc, Krshia, Silverfang, Zevara, Erin,
  Pisces, Olesm, Selys, the Floodplains) are treated as previously verified
  and not re-flagged.
- `⚑ USER-TASTE` — wording/design the user picks or ratifies.

**Terminology.** The spec's ratified game-facing term is **resonance**
(card line "Resonance N", panel "Resonance 2/3"). The *sensory* fiction I
use around it — enchanted items **hum**, and over-capacity interference
reads as the hums turning to **static/argument** — extends the spec's own
example line. ⚑ USER-TASTE on that hum/static diction as the house
interference language (it recurs in the Traveler's Charm lore and every
refusal candidate below). [CANON-VERDICT 2026-07-06: CONFIRMED — canon
names this **"Magical Dissonance"** (wiki Artifacts page): "Dissonance will
occur with enough active artifacts in close proximity, e.g. on a person";
standard safe limit ~4 artifacts; "certain Skills enable wearing up to 8"
(grounds our opaque capacity-GROWTH beat exactly); the canonical warning
sign is the artifacts starting to SHAKE/vibrate. Note for the ⚑ refusal-copy
pick: a shaking/vibration-flavored line would be the most canon-true of the
candidates — the hum/static diction is adjacent but invented.]

---

## A) Lore lines for every existing item

Rules applied: 1–2 sentences; provenance / maker / what it implies about
the world; **no mechanics, no prices** (effect lines and shop options carry
those); resident diction, voice-linted. `lore` is a NEW field — nothing
below changes any existing `id`/`name`/`description`/`price`/mod.

Proposed `resonance` for existing items: **0 for all**, except
**`traveler_charm` = 1** (the plan names it as the entry enchanted item).

| id | resonance | lore |
|---|---|---|
| `rusty_sword` | 0 | "Watch surplus goes by the crate when the armory clears its racks, and half the cellars in Liscor hold one of these. Somebody drilled with it every morning for a year, once, and then stopped." |
| `relcs_spare_spear` | 0 | "The Watch quartermaster budgets for Relc the way innkeepers budget for breakage. This one survived him, which means the haft is good and the week was quiet." |
| `crude_blade` | 0 | "Goblin forges run on scavenge — plow edges, cartwheel rims. Whoever hammered this understood one thing about swords, and it was the edge." |
| `chipped_spear` | 0 | "The cord on the haft has been rewrapped by three different hands. Goblin gear outlives goblins; it gets passed forward, not down." |
| `solid_oak_spear` | 0 | "Turned out by the dozen for the yard behind the Watch barracks, where recruits learn which end matters. The oak usually outlasts the recruit's pride." |
| `leather_jerkin` | 0 | "A tannery south of the market cures these forty at a time, and the smell reaches the gate when the wind turns. New ones go to adventurers; secondhand ones come back from the Floodplains with the stitching checked." |
| `watch_issue_gambeson` | 0 | "Signed out against a deposit, and Watch Captain Zevara knows exactly how many never came back. The padding is older than some of the guards inside it; the budget for replacements has died in council three years running." [CANON-VERDICT 2026-07-06: CONFIRMED — "originally ruled by a civilian council made up of the 8 foremost important Drakes"; Watch Captains rank alongside Council members] |
| `traveler_charm` | **1** | "The old stones outside the city give up trinkets like this after a hard rain, and nobody living remembers who strung them. Hold it to your ear and it hums, faintly — most owners decide not to ask a second question." [CANON-VERDICT 2026-07-06: CONFIRMED — ancient city fell a millennium ago (became the dungeon); Skinner's ruins found ten miles southwest. "Old stones outside the city" is safe] |
| `gnollish_hunting_knife` | 0 | "Silverfang steel comes south with the tribe's caravans and gets worked plains-side, the old way, before it ever sees a city stall. Krshia could sell three times what her kin send her — she says so to anyone who buys one." [CANON-VERDICT 2026-07-06: CONFIRMED — Great Plains tribe; part immigrated to Liscor "to facilitate trade"; known as great [Traders], silver mining + merchant work; Krshia leads the Liscor Silverfangs with kin ties] |
| `wool_lined_cloak` | 0 | "Plains wool, city loom — Gnoll caravans sell the fleece and Drake weavers argue the price, and the cloak comes out warmer than the bargaining. The Floodplains rain finds every cheaper seam." |

Voice-lint self-check run on all ten: no banned tells, no cadence-stacked
triads (the `crude_blade` list is two items; terse concrete lists match the
"Sewers, scavengers, paperwork" exemplar register), one em-dash max per
line, no whole-word STR/DEX/CON/INT/WIS/CHA tokens, no `%`.

---

## B) New item roster (9: 7 accessories, 2 tools)

Schema assumptions for the implementer (see §D for test fallout): new
`kind` values `"accessory"` and `"tool"`; `weapon_family: "none"`;
`abilities: []`; mods restricted to `hp_mod`/`damage_mod`/
`damage_reduction` (numbers modest — G4's harness measures). Resonance ≥ 1
items presumably need `tier: "enchanted"` (or the tier field's semantics
yield to `resonance`) — G1/G2 decision, flagged in §D.

Price band coherence: day's inn work ~4 gold; entry charm 5; jerkin 24.
New shop prices: 4 / 4 / 5 / 9 / 14 / 35. **The cheapest new item is
deliberately 4, not 3** — `economy_loop` asserts EVERY buy greys at its
3-gold shop visit (§D).

### 1. `copper_luck_band` — "Copper Luck-Band" (accessory: ring)
- **Description:** "A thin copper ring, polished bright by worried thumbs. Drakes swear copper turns bad luck aside; copper-sellers agree loudly."
- **Lore:** "Every stall in the gate market moves a tray of these. The luck is arguable; the copper is real, and that is the Silverfang position on the matter."
- **Resonance:** 0 (mundane — good copper, not magic)
- **Mods:** `hp_mod: 1`
- **Price:** 4 (one day's honest work — the teaching purchase)
- **Source:** Krshia stall. *Reasoning: the first accessory a fresh player can afford; teaches the new slot without touching capacity at all.*

### 2. `hedge_ward_charm` — "Hedge-Ward Charm" (accessory: charm)
- **Description:** "Dried herbs and a knot of red thread sealed in a wax bead, warm to the touch. Roadside work, from up north."
- **Lore:** "Hedge-charmers work the wagon stops between Celum and Liscor, selling wards to travelers who want the odds nudged. Most beads are wax and hope; this one was made by somebody with a real Skill, and it knows it." [CANON-VERDICT 2026-07-06: CONFIRMED — Celum is 88 miles north of Liscor, Human town, trade route]
- **Resonance:** 1
- **Mods:** `hp_mod: 2`
- **Price:** 9 (~two days' work)
- **Source:** Krshia stall. *Reasoning: the second resonance-1 item in the shop; charm (1) + ward (1) exactly fills base capacity 2 — the cheapest honest route to the refusal moment.*

### 3. `hunters_fang_talisman` — "Hunter's Fang Talisman" (accessory: talisman)
- **Description:** "A beast's fang on a braided cord, capped in silver. The point still looks like it has opinions."
- **Lore:** "The silver fang is the Silverfang mark, and the stall caps a good trophy in it for a hunter who asks. Krshia will tell you whose kill this was if you ask, and the story runs longer than the cord." [CANON-VERDICT 2026-07-06: no first-kill fang-capping CUSTOM is wiki-documented — REWRITTEN to hang on the tribe's silver-fang SIGIL (confirmed: "their sigil is a silver fang", silver jewelry motifs confirmed) as stall practice, not a claimed tribal custom]
- **Resonance:** 1
- **Mods:** `damage_mod: 1`
- **Price:** 14 (knife-adjacent tier — sits beside the 15-gold hunting knife)
- **Source:** Krshia stall. *Reasoning: the offense-flavored resonance-1 option, so capacity choices are real trade-offs (ward vs fang), not strictly-better stacking.*

### 4. `phosphor_pendant` — "Phosphor Pendant" (accessory: charm)
- **Description:** "A glass bead of sewer phosphor that never quite goes out. Brighter than it has any right to be, and it smells faintly of where it came from."
- **Lore:** "Somebody down in the drains learned to seal the glowing moss in glass, and somebody else paid them for it. Neither name made it back up to the street."
- **Resonance:** 1
- **Mods:** `hp_mod: 3`
- **Price:** none (not sold)
- **Source:** loot — `shield_spiders` (the cisterns nest). *Reasoning: a sewers-themed drop rides the existing phosphor_moss prop fiction; shield_spiders is the safest loot table to touch (no script pins its loot absence — §D hazards).*

### 5. `stonescale_talisman` — "Stonescale Talisman" (accessory: talisman)
- **Description:** "A grey Drake scale, shed and gone stone-hard, set in an iron clasp. Heavier on the mind than on the neck."
- **Lore:** "Shed scales with stone in them turn up in the southern hills, and enchanters pay well for the rare one that takes a binding. Drakes find wearing another Drake's scale distasteful — the stall keeps this one under the counter." [CANON-VERDICT 2026-07-06: no wiki doc either way on a scale-wearing taboo — treat as ORIGINAL stall behavior (framed as taste, not doctrine); enchanted-goods trade is generic-safe. KEEP with the ORIGINAL flag]
- **Resonance:** 2
- **Mods:** `damage_reduction: 1`
- **Price:** 35 (above the jerkin's 24 — the first enchanted-premium purchase)
- **Source:** Krshia stall (her "good stock where a browsing hand drifts"). *Reasoning: the notable-tier shop item; at base capacity 2 it monopolizes the budget alone, making "one big hum vs two small ones" a real decision.*

### 6. `moon_bone_amulet` — "Moon-Bone Amulet" (accessory: amulet)
- **Description:** "Carved bone on a sinew cord, worn smooth wherever a thumb would rest. Under moonlight the carving is a moon; under anything else it is just circles."
- **Lore:** "Raskghar work, cut in the deep warrens by hands that are only clever some nights. Whatever the amulet waits for, it waits patiently." [CANON-VERDICT 2026-07-06: lucidity CONFIRMED ("only during the full moon would they regain any measure of sanity"; "frightfully intelligent"); moon-RITES are NOT documented — the line as written hangs only on lucidity ("hands that are only clever some nights"), which passes. Do not add rite/worship claims]
- **Resonance:** **3** ⚑ USER-TASTE — at the default capacity 2 this trophy CANNOT be worn until a capacity-growth event lands; that "you carried it home and it won't sing for you yet" beat is deliberate motivation for the opaque growth milestone. Drop to 2 if the user wants it wearable day-one.
- **Mods:** `hp_mod: 3`, `damage_mod: 1`
- **Price:** none (never sold)
- **Source:** quest reward — the Act III warren arc (attach to the seal beat's Zevara dialogue, or `awakened_boss` loot; recommend the SEAL dialogue so the reward lands in the surface epilogue, not mid-dungeon). ⚑ USER-TASTE on which. *Reasoning: the arc's capstone deserves the roster's ceiling item; stream disclosure required either way (§D).*

### 7. `watch_token` — "Watch Token" (accessory: token)
- **Description:** "A brass token stamped with Liscor's gate, the kind the Watch hands to runners and irregulars. It opens no doors by itself, but it slows down the questions."
- **Lore:** "Zevara signs maybe ten of these a year, and she remembers every one. Losing it is a worse conversation than never having earned it."
- **Resonance:** 0
- **Mods:** none (0/0/0 — a wearable story, not a stat stick)
- **Price:** none (never sold)
- **Source:** quest reward — the cisterns TALK path (Zevara's `watch_swept_cisterns` resolution) fits best: she rewards the one player who got the Watch to do its job by argument. *Reasoning: proves accessories can be pure environmental storytelling; also the diegetic seed for any future Watch-reputation content.*

### 8. `field_whetstone` — "Field Whetstone" (tool)
- **Description:** "A palm-sized whetstone in a leather sleeve, dished from use. Steel forgets its edge; this reminds it."
- **Lore:** "Watch-issue kit includes one, and half the Watch loses theirs by spring. The tanner who sews the sleeves has stopped putting names on them."
- **Resonance:** 0
- **Mods:** none
- **Price:** 5
- **Source:** Krshia stall. *Reasoning: mundane kit grounds the stall as a real shop, not a magic boutique; a natural hook for the spec §4 [Repair]/upkeep Skills wave later.*

### 9. `fishers_handline` — "Fisher's Handline" (tool)
- **Description:** "Waxed line and bone hooks wound on a stick, with a cork float. The Floodplains pond is deeper than it looks."
- **Lore:** "Drakes fish the pond in fair weather and swear off it every winter, when the water starts moving wrong. The line-sellers do their best business in spring, replacing gear that was 'lost.'"
- **Resonance:** 0
- **Mods:** none
- **Price:** 4
- **Source:** Krshia stall. *Reasoning: second tool; points at the one body of water the game already renders (pond + shimmer + glints) and leaves a fishing-content hook without promising mechanics.*

**Capacity story sanity check** (base capacity 2 per the plan): charm(1)+ward(1)
fills it; fang(1) forces a swap; stonescale(2) monopolizes it; moon-bone(3)
waits for growth. Every rung of the refusal/choice ladder is purchasable or
earnable in the shipped content graph.

---

## C) Refusal copy — capacity-refusal toast candidates

The spec's own line ("The charm's hum turns to static against the sword's.")
is the register baseline. Candidates below are **item-agnostic** (they can't
assume a charm or a sword is involved) unless G3 decides the toast templates
item names. All ⚑ USER-TASTE — user picks one (or one + the spec's for
variety).

1. ⚑ "The new hum meets the ones you're wearing and sours. Your teeth ache until something comes off."
2. ⚑ "It wakes, feels what you already carry, and goes sullen and silent."
3. ⚑ "Two hums become an argument, and you're the room they're arguing in."
4. ⚑ "It buzzes once against the others, like a wasp against glass, and will not settle."

(Diegetic, no numbers, no "capacity" vocabulary in the player-facing line —
the card's visible "Resonance 2/3" carries the arithmetic.)

---

## D) Assembly notes for G2

### QA-pin audit (done in this staging pass — grep evidence)
- Scripts/tests that mention existing item **ids or names**:
  `qa/scripts/{inventory_loop, work_loop, relc_tutorial, tutorial_flow,
  economy_loop, level_up_loop, combat_move_input, wrong_order_fight,
  d2_shop_shot, d3_inventory_shot}.json` and `tests/{test_save,
  test_effect_text, test_sim_core, test_dialogue, sim_combat_batch}.gd`.
  Every hit is an **id reference or a "Got: <Name>" toast pin** — grepping
  each existing item's `description` phrasing across `qa/scripts/` and
  `tests/` finds **zero pins on description text** (the only description
  pin anywhere is a *skill* description in `field_skills_loop.json`).
- **Conclusion: `lore` + `resonance` are additive fields; every existing
  pin is unaffected** so long as existing `id`/`name`/`description`/
  `price`/mod values stay byte-identical — this doc changes none of them.
- One formatter caveat: once G1/G3 makes the "Resonance N" line join
  `WIEffectText.item_effect_lines()`, `tests/test_effect_text.gd`'s exact
  item-line pins must be extended in the same task — the new FIELD alone
  (unread by the formatter) breaks nothing.

### Stream-touching hazards (disclose per the plan's Global Constraints)
- **`economy_loop` shop-greying pin:** at its 3-gold visit it asserts EVERY
  buy option greys. Cheapest new shop item is priced **4** on purpose.
  Also: append new buy options **after** the existing four in
  `krshia_crate.json`'s `shop` node (gold-gates grey visible, never hide,
  so appended options never shift the earlier indices the script drives);
  add nothing to the `hub` node's option list (its index-2 note in the
  seed table is load-bearing). Re-run `economy_loop` regardless.
- **Loot tables:** do NOT touch `goblin_encounter_1` (inventory_loop pins
  `assert_event_absent loot_dropped` at seed 9) nor
  `crate_scavengers`/`goblin_encounter_1` gold outcomes (economy_loop pins
  gold 2 @ seed 9 on both). The loot RNG is `hash(run_seed, encounter_id)`-
  derived and rolls per entry, so even APPENDING an entry to a pinned
  table can shift the gold draw. `phosphor_pendant` therefore goes on
  `shield_spiders` (no script pins its loot); re-run `cisterns_fight` and
  check no mid-run `loot_dropped`/toast desyncs a wait.
- **Quest-reward `{item: …}` effects** (watch_token on Zevara's sweep
  resolution; moon_bone_amulet on the seal beat) fire `item_gained` + a
  "Got: <Name>" toast mid-conversation — the known toast-queue-race class.
  Re-run `cisterns_talk`, `climax_seal`, `arc_flow` (and `social_loop` if
  Zevara's graph indices move — add reward effects to EXISTING options,
  never new options, to keep visible indices stable); qualify any new
  toast waits (`payload_contains` exact text), the repo pattern.

### Test/validation work the plan expects (`test_items` / `test_content`)
- `tests/test_items.gd` must extend in lockstep with the data:
  - `VALID_KINDS` gains `"accessory"` and `"tool"` (accessories/tools:
    `weapon_family: "none"`, same rule as armor).
  - The `tier == "mundane"` hard-fail must move: either resonance-≥1 items
    ship `tier: "enchanted"` and the check allows it, or `tier` is retired
    in favor of `resonance` — G1/G2 call, but the test and data change in
    the SAME task or the suite reds. ⚑ USER-TASTE adjacent (which field is
    the card's rarity vocabulary).
  - New checks per the plan: `lore` present + non-empty string on EVERY
    item; `resonance` present, int, `0 <= r <= 3`; `abilities` stays empty.
- `tests/test_content.gd` needs **no edit** for the copy itself: its
  recursive player-string vocab sweep covers new string fields
  automatically. All §A/§B/§C copy above was scanned against
  `\b(str|dex|con|int|wis|cha)\b` and `%` — clean.
- **Lore-vs-effect separation** (GF opus hint): `lore` renders as its own
  card field and must NEVER route through `WIEffectText` (and no
  `item_effect_lines()` output ever leaks into `lore`).
- **G4 reminder:** every stat-bearing new item above (`copper_luck_band`,
  `hedge_ward_charm`, `hunters_fang_talisman`, `phosphor_pendant`,
  `stonescale_talisman`, `moon_bone_amulet`) needs an E6 loadout cell.

### Open questions for G1/G2 (flagged, not decided here)
- ⚑ USER-TASTE / G1: `traveler_charm` is currently `kind: "armor"` (it
  competes with the jerkin for the armor slot). As THE resonance-1 entry
  charm it reads as an accessory — re-kinding it frees the armor slot and
  makes the fiction honest, but touches old-save equipped-shape tolerance
  and `economy_loop`'s buy (pack-only, no equip — likely safe). Decide in
  G1's save/slot work, not as a silent data edit.
- ⚑ USER-TASTE: refusal-line pick (§C) and the hum/static house diction.
- ⚑ USER-TASTE: `moon_bone_amulet` resonance 3-vs-2 and reward surface
  (seal dialogue vs boss loot).

---

## Flag tally
- **[CANON-CHECK]: 8** (interference framing citation; Liscor Council;
  Floodplains old stones/ruins; Silverfang caravans/kin trade; Celum trade
  road; Silverfang fang-capping custom; enchanted-goods trade + Drake
  scale-wearing taboo; Raskghar moon-rites/bone carving).
- **⚑ USER-TASTE: 8** (hum/static interference diction; 4 refusal
  candidates; moon-bone resonance value + reward surface; tier-vs-resonance
  vocabulary; traveler_charm re-kind).
- **Items:** 10 existing lore lines + 9 new items (7 accessories, 2 tools).
