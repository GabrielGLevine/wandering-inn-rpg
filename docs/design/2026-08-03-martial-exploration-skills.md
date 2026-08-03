# Martial & Mundane Exploration [Skills] — CANDIDATE DOC

**Status: CONTROLLER-CURATED (Fable, 2026-08-03) — READY FOR USER PICKS. Nothing
ships until the user chooses.** Curation notes: canon citations spot-checked on
the wiki mirror ([Even Footing]/Toren, [Bar Fighting]/Erin — both confirmed);
the data census (§1) independently matches the shipped skills.json. I ADOPT the
doc's two cut recommendations ([Blur Leap] duplicates double_step; [Basic
Crafting] is the Alchemist bench without a granted distinction) and the
[Flawless Attempt] enumerated-whitelist caveat. Top-10 table is the pick list;
#1/#4/#5 pair directly with the user's Ice-Floor/Flame-Jet examples as the
martial mirror. W1 (#348 slice 1) ships the substrate these hook into. Research pass 2026-08-03. Author: research subagent.

Brief: the user's complaint — *"Mages get all the interesting exploration
options."* This doc drafts 24 candidate field/exploration [Skills] for MARTIAL
and non-mage classes, ranked, each with a canon citation or an explicit
INVENTED mark, a field verb, a named hook into shipped seams or the property
layer, a cost estimate, and a spoiler note.

---

## 0. Summary table (top 10 by fun × canon-fit × inverse-cost)

| # | Skill | Canon? | Holder / class fit | FIELD verb | Hook | Cost | Spoiler |
|---|---|---|---|---|---|---|---|
| 1 | **[Even Footing]** | ATTESTED 2.24 T | Toren; Warrior/Runner/Scout | MOVEMENT — cross ice/scree/mud yourself, no terrain change | `_is_freezable` cell class + `is_cell_blocked` (wi_game.gd:264-275); passive read, [Wild Affinity] precedent (:625-645) | M | Vol 2 ✅ |
| 2 | **[Rope Work]** | ⚑ INVENTED (canon [Rope Arrow] is spoiler-blocked) | Scout/Archer/Ranger/Laborer | MOVEMENT — anchor a line, gap becomes permanently crossable | `state_set` (spec §4.1) + `present_when` entity gate (AGENTS.md:351) | S-M | n/a ✅ |
| 3 | **[Greater Strength]** (field-tag an attested Skill) | ATTESTED 1.10 R | Garia Strongheart; Warrior/Laborer | INTERACTION/MOVEMENT — force a barred door, shift a boulder | `requires_skill` arm + `_door_openable` (wi_game.gd:544-551) + `removed_entities` | S | Vol 1 ✅ |
| 4 | **[Basic Repair]** | ATTESTED 2.14 G | Rags; Crafter/Laborer/Warrior | INTERACTION→MOVEMENT — mend the ladder/bridge/cart, permanently | property row `repairs × broken` → `state_set` (spec §4.1) | M | Vol 2 ✅ |
| 5 | **[Broader Shoulders]** | ATTESTED 1.11 | unnamed Gnoll [Hunter]; Laborer/Hunter | ECONOMY — haul what you can't carry; heavy prop → item + cleared cell | authored arm + `item` yield + `remove_entity` (wi_game.gd:430-532) | S | Vol 1 ✅ |
| 6 | **[Durable Picks]** | ATTESTED 6.02 | Numbtongue (Pyrite line); Miner/Laborer | INTERACTION — break a rubble wall without spending the pick | `requires_item` gate WITHOUT `remove_item` (wi_game.gd:465-472) | S | Vol 6 ✅ |
| 7 | **[Long Ear]** | ATTESTED 5.11 E | Zevara Sunderscale; Scout/Rogue/Watch | PERCEPTION — hear through a closed door: count the ambush, catch the talk | `skill_uses` per-entity map (field_skills.gd:62-72) or `listens × door` row | S-M | Vol 5 ✅ |
| 8 | **[Prey Sense]** | ATTESTED 6.61 L | Bird; Hunter/Beast Tamer/Ranger | PERCEPTION — sense beast-kind nearby, direction + count | reads the SHIPPED `beast: true` flag (7 map carriers) + :625-645 | S-M | Vol 6 ✅ |
| 9 | **[Campfire Chef]** | ATTESTED 5.37 G | Cook/Chef/Ranger/Scout | ECONOMY — cook with no hearth; the Skill *is* the station | `pickup` + waking-key cap; frees cooking from station props | S | Vol 5 ✅ |
| 10 | **[Bar Fighting]** | ATTESTED 1.28 | Erin Solstice; Innkeeper/Helper/Warrior | INTERACTION/ECONOMY — any inn prop becomes a one-fight weapon | items.json `use_effect.next_fight` one-shot (AGENTS.md:184) | S | Vol 1 ✅ |

Full ranked list of 24 in §4. Cut list with reasons in §6. Spoiler-blocked
canon in §7.

---

## 1. The complaint, stated as data

This is not a vibe. I ran the census against `data/skills.json` +
`data/classes.json`.

**All 12 skill-side "world-changing" property-flag carriers, with their
granting class:**

| flag | skill | granted by |
|---|---|---|
| `burns` | kindle [Firefly] | (ungranted; mage-line kit) |
| `freezes` | frost_touch [Snap Freeze] | (ungranted; mage-line kit) |
| `toggles_light` | light [Light] | **mage L1** |
| `animates` | animate_dead | **necromancer L5** |
| `wards` | hearthward_charm / greater_hearthward | **hedge_witch L5 / witch L10** |
| `blinks` | flash_step | **mage L11 / necromancer L7** |
| `blinks` | double_step | **runner L5** ← the ONE martial carrier |
| `sneaks` | invisibility | **mage L5** |
| `sneaks` | sneak [Stealth] | **rogue L1** |
| `tames` | lesser_bond | **beast_tamer L3** |
| `door_flavor` | open_doors | **diplomat L7** (cosmetic — toast only) |

Every verb that **changes the world** — burn, freeze, animate, ward, light —
belongs to mage / necromancer / witch. The martial line's total holdings are
one blink (Runner), one stealth toggle (Rogue), and a joke line on doors.

**And the field roster by class is worse than that.** Of 38 `field: true`
skills, these classes grant **ZERO**: `warrior`, `swordsman`, `spearmaster`,
`ranger`, `sharpshooter`, `infiltrator`, `strategist`. `archer` grants exactly
one (`keen_eye`, read-only). `scout` grants one, at **L14**. `tactician` grants
one (`observe`). Meanwhile `mage` grants four and `mixer`/`alchemist` grant
five.

A player who takes [Warrior] and walks outside has an **empty field hotbar**.
That is the bug the user is naming.

**Second finding, worth the controller's attention:** the martial field skills
that *do* ship are almost all **read-only** — observe, keen_eye, eagle_eyes,
find_trap, appraise_goods, measured_words. They tell you about the world; they
never move it. `disarm_trap` is the sole martial exception that removes an
entity. So the gap is not just *count*, it's *grammar*: mages get verbs,
martials get nouns.

---

## 2. Design principles — what makes a martial exploration Skill feel martial

The user's two mage-side benchmarks (as stated in the task):

- **[Ice Floor] → walkable water.** A mage *rewrites the terrain*. The world
  is different afterward, for everyone, and it persists (`frozen_cells`,
  until-sleep, save-round-tripped).
- **[Flame Jet] → cooked corpse.** A mage *transforms matter*. An input
  becomes a categorically different output.

Both are **transmutation**: the caster asserts a new fact about reality. A
martial Skill that tries to compete by transmuting reads as a spell with a
sword sticker on it. The martial answer has to be a different *shape* of power,
and there are five that work:

**P1 — The body is the tool, not the world.** A mage freezes the river; a
[Scout] with [Even Footing] just *walks across the scree the mage had to
freeze*. Same outcome, opposite mechanism: the mage changes the ground, the
martial changes what the ground can do **to them**. Mechanically this means:
prefer **player-only, non-persistent, no-TERRAIN_CHANGED** effects. That is
also cheap — no new save state (spec §4.4).

**P2 — Craft leaves a thing behind.** The mage's flame is gone when it's gone.
The [Laborer] who repairs the bridge leaves **a bridge**. Permanent,
counter-backed, one-way — which is exactly what the property layer's
`state_set` substrate can already express and *cannot* reverse (spec §4.1, "No
reversal in v1"). Repair, rope, barricade, snare: the martial verbs are the
ones the monotone counter store was born to hold. **This is the single best
mechanical argument in the doc:** the spec's biggest limitation (no undo) is a
*feature* for craft verbs and a *bug* for magic verbs.

**P3 — Grit is a passive, not a button.** Per the explicit-Skill-use doctrine
and "tiresome actives become passives": [Eyes In The Back] must never be a
hotbar slot you mash before every corner. It is a known-skill read inside
`_check_trigger_radius`, the way `_wild_affinity_reduction` (wi_game.gd:625-645)
already silently shrinks beast ambushes for a [Beast Tamer]. The martial kit
should be **roughly half passive** — that is what "veteran" feels like, and it
costs zero hotbar slots in a bar that is already 5 wide.

**P4 — Perception is martial when it costs you something.** A mage's
[Detect Magic] is free information. A [Scout]'s [Long Ear] means *standing
still with your ear on a door* — it should break sneak, or cost the action
tick, or work only on the faced cell. Information that has a posture is
martial. Information that arrives is magic.

**P5 — Economy verbs are first-class.** [Broader Shoulders] carrying a
corusdeer corpse home to sell is not a lesser fantasy than [Flame Jet] cooking
it. It is the *other half of the same scene*, and it feeds the three-pillars
mandate's non-combat majority (spec §7 acceptance rule) far more cheaply than
another combat active.

**Anti-pattern to police:** anything phrased "you emit / you project / you
conjure". If the sentence needs a noun that leaves the body, it's a spell. The
one canon candidate in this doc that fails this test is flagged as such
(§4, #24 [Deft Hand] — explicitly "minor telekinesis").

---

## 3. Reading of the seams these hook into

Quick map, so every candidate below can cite rather than re-explain.

- **Authored arm (zero engine):** entity `requires_skill` + `on_skill_use` →
  `WIGame.use_skill` (wi_game.gd:430-532). Yields: `accomplishment`, `toast`,
  `gold`, `item`, `remove_item`, `lore`. Gates: `requires_item` (String|Array,
  all-or-nothing, :465-472), `once_per_waking` (:498-505),
  `gold_once_per_waking` (:508-518). Variants via `when` on counters. **43
  such arms ship.** Cost of a new one: S.
- **`skill_uses` per-entity map** (field_skills.gd:62-72) — one entity answers
  several Skills differently. The pantry-door precedent.
- **Property table (proposed, spec §4.1):** `skill_property × target_property →
  outcome ∈ {remove_scorch, freeze_cell, thaw_cell, state_set, bank_toast,
  refuse}`. New properties are additive registered booleans; `state_set` is
  ONE-WAY, counter-backed (world.gd:767-800).
- **Cell-class walkability:** `freezable` per-map dict → `_is_freezable`
  (wi_game.gd:275); `frozen_cells` flips `is_cell_blocked` via `_is_frozen`
  (:264-272); until-sleep, save-round-tripped.
- **Permanent removal:** `removed_entities` (wi_game.gd:2344) + `TERRAIN_CHANGED`
  — the burn shape.
- **Blink loop:** `_blink_field` (wi_game.gd:589-622) walks `player_facing`,
  `continue`s over freezable cells, breaks on blocked, banks
  `blinked_past_danger` via `_blink_bypassed_encounters`.
- **Ward/pacify:** `_ward_field` (wi_game.gd:682-723) → `dormant_encounters`,
  until-sleep, entity-keyed; `_check_trigger_radius` skips warded entities.
- **Passive skill read inside sim:** `_wild_affinity_reduction`
  (wi_game.gd:625-645) — the sanctioned pattern for a passive that changes
  world behavior without a cast.
- **One-shot next-fight buff:** items.json `use_effect.next_fight` →
  `pending_meal` (AGENTS.md:184).
- **Structural presence gate:** `entity_present` / `present_when`
  (AGENTS.md:351) — an entity that exists only once a counter banks.

---

## 4. The 24 candidates, ranked

Ranking = fun × canon-fit × inverse-implementation-cost. **Tier A** = best
ratio, ship first. Cost: **S** = data-only, zero engine. **M** = one registered
property/dispatch arm over already-serialized state. **L** = new save state →
`WISave.VERSION` bump → K3 territory (spec §10).

### TIER A — highest ratio

---

**1. [Even Footing]** — MOVEMENT
- **Canon:** ATTESTED. Wiki *Skills Effect/E*, cites **ch 2.24 T**; holder
  **Toren** (per Toren/Leveling History). Effect verbatim: *"Helps the User
  traverse through treacherous terrain, like slick patches of ice or divots in
  the ground, as if they were walking on a smooth, hard surface."*
- **Classes:** Warrior, Runner, Scout, Ranger.
- **Field verb:** You personally cross hazard cells — ice, scree, mud, rubble
  — that everyone else must freeze, burn or go around. **No `TERRAIN_CHANGED`,
  no persistence, no help for anyone else.**
- **Hook:** the `freezable` cell-class dict is already a per-map registry of
  "treacherous cell" (wi_game.gd:275), and `is_cell_blocked` already has an
  escape hatch keyed on player state (`_is_frozen`, :262-272). Add a
  known-skill read alongside it — the `_wild_affinity_reduction` passive
  pattern (:625-645), NOT a hotbar cast.
- **Cost: M.** No new save state (spec §4.4 clean). The real cost is
  byte-identity risk: `is_cell_blocked` is the hottest sim predicate and every
  traversal canonical crosses it. Mitigation: gate on a NEW cell class
  (`treacherous`) with zero existing carriers, so slice-1 is provably inert
  (spec §10-K1 discipline).
- **Spoiler: Vol 2 — safe, well inside the bar.**
- **Why it leads:** it is the exact structural rival to [Ice Floor]→walkable
  water, arrived at by the opposite route, and the contrast *teaches the
  system*: the mage's ice is visible, shared, and melts; your footing is
  invisible, selfish, and permanent. Best fun-per-line-of-code in the doc.

---

**2. [Rope Work]** — MOVEMENT — ⚑ **INVENTED, canon-style**
- **Canon:** ⚑ INVENTED. The obvious canon name, **[Rope Arrow]**, is held by
  Halrac Everam and Nailren Fletchsing, but its only wiki citation is
  *Interlude – Adventurers (Pt. 2)* (published 2022-11-13, Vol 8/9 era) →
  **spoiler-blocked under spoiler-cutoff.md rule 5** (ambiguous timing ⇒ treat
  as past cutoff). [Rope Work] is a canon-shaped noun phrase per ruling 9;
  adjacent attested craft Skills ([Basic Crafting] 1.07, [Enhanced Thread]
  1.01 D) establish the register.
- **Classes:** Scout, Archer, Ranger, Laborer, Rogue.
- **Field verb:** Cast at a faced anchor point across a gap/ledge → a line goes
  up and **the gap becomes permanently crossable**, and stays visible.
- **Hook:** two shipped halves, no new state. (a) `state_set` outcome banks a
  counter (spec §4.1, monotone, permanent); (b) a pre-authored "rope bridge"
  entity carries `present_when` on that counter (`entity_present`,
  AGENTS.md:351) so it *appears* and the cell it occupies becomes traversable
  scenery. Walkability follows the shipped entity-presence rules — no
  `frozen_cells`-style store needed.
- **Cost: S-M.** Both halves ship; the work is authoring anchors + one table
  row + the canonical leg.
- **Spoiler:** n/a (invented). Flag to user: if they want the canon name,
  [Rope Arrow] is available but costs a spoiler exception.
- **Note:** this is the martial answer to [Flash Step] that is *better* than
  [Flash Step], because it leaves the crossing behind for the return trip.
  Principle P2 in its purest form.

---

**3. [Greater Strength]** (give the shipped-attested Skill a FIELD verb) —
INTERACTION / MOVEMENT
- **Canon:** ATTESTED. Wiki *Skills Effect/G*, cites **ch 1.10 R**; upgrade of
  [Enhanced Strength] (same cite); canon holder **Garia Strongheart**
  ([Runner], per her page: *"[Greater Strength] — upgraded from [Enhanced
  Strength]"*).
- **Classes:** Warrior, Laborer, Runner, Ranger.
- **Field verb:** Force what won't open. A barred door, a jammed portcullis, a
  boulder in the tunnel — the martial answer to a locked way that is neither
  lockpicking nor a spell.
- **Hook:** 100% shipped. `requires_skill` on the door/boulder entity;
  `_door_openable` already distinguishes real doors from sealed
  `door_when` gates (wi_game.gd:544-551) so a story-locked seam correctly
  refuses; boulders resolve via `remove_entity` + `TERRAIN_CHANGED` (the burn
  shape). **Zero engine work.**
- **Cost: S.** Data + map arms only.
- **Spoiler: Vol 1 — safest possible.**
- **No-duplicate check:** `lesser_strength` ships as an exploration **passive
  with no `field` flag** and no verb. This is a strict upgrade record, not a
  rename — clean under the ids-are-permanent rule.

---

**4. [Basic Repair]** — INTERACTION → MOVEMENT
- **Canon:** ATTESTED. Wiki *Skills Effect/B*, cites **ch 2.14 G**; holder
  **Rags** (per Rags/Leveling History). Effect verbatim: *"Assists basic
  repairs to nonmagical items **or structures**."*
- **Classes:** Crafter, Laborer, Goblin-line, Warrior, Innkeeper.
- **Field verb:** Mend the broken thing — a ladder, a plank bridge, a cart
  wheel, a collapsed stair — and the way opens **permanently**.
- **Hook:** **the single cleanest property-layer fit in this doc.** A new
  registered skill flag `repairs` × a new target flag `broken` → the shipped
  `state_set` outcome (spec §4.1): counter-backed visual_states swap
  (world.gd:767-800) for the visual, `remove_entity` for the blocker. The
  spec's hard constraint — **`state_set` is one-way, there is no un-set** — is
  *correct* here: nobody un-repairs a bridge. Contrast the spec's own worked
  example of the constraint biting (dousing a lit hearth, §4.1), which is a
  magic verb.
- **Cost: M.** One flag pair, 2-3 rows, carriers, one canonical. Rides existing
  outcome verbs → "SMALL per property" by spec §8's own rule.
- **Spoiler: Vol 2 — safe.**
- **Combo:** pairs with #19 [Detect Flaw] (find the cracked masonry → repair
  it), which is the kind of two-Skill chain the property table exists to make
  predictable.

---

**5. [Broader Shoulders]** — ECONOMY
- **Canon:** ATTESTED. Wiki *Skills Effect/B*, cites **ch 1.11**. Effect
  verbatim: *"Expands shoulder width to aid in carrying larger loads (Used by
  a Gnoll hunter to carry a Corusdeer corpse)."* Holder is the unnamed Gnoll
  **[Hunter]** of 1.11 — no named-character attribution on the wiki.
- **Classes:** Laborer, Hunter, Porter, Warrior.
- **Field verb:** Haul what you otherwise cannot. Heavy props — a carcass, a
  crate, a millstone, a strongbox — become liftable: they yield an item AND
  their cell clears.
- **Hook:** pure authored arm (`requires_skill` + `on_skill_use` with `item`
  yield) + `remove_entity` for the cleared cell. Zero engine. Sells into the
  shipped fence/economy seams (`data/fence_stock.json`).
- **Cost: S.**
- **Spoiler: Vol 1 — safest possible.**
- **Why it matters:** this is the *direct* rival to the user's [Flame Jet] →
  cooked-corpse example. The mage cooks the corusdeer where it fell. The
  [Hunter] **carries it home whole and sells it.** Same scene, martial verb,
  better payout — that framing is the pitch.

---

**6. [Durable Picks]** — INTERACTION
- **Canon:** ATTESTED. Wiki *Skills Effect/D*, cites **ch 6.02**; holder
  **Numbtongue** (his page lists it — inherited via the [Pyrite] memory, the
  Goblin [Miner] line). Effect verbatim: *"Pickaxes are more endurable."*
- **Classes:** Miner, Laborer.
- **Field verb:** With a pick in the pack, break through rubble/ore seams
  **without spending the tool.**
- **Hook:** an elegant inversion of a shipped gate. The `requires_item` /
  `remove_item` pair (wi_game.gd:465-472, 529-531) currently powers the
  `trap_kit` consume on the delve disarm route (`delve_skill` canonical). Here:
  gate on the pick, **omit `remove_item`** — the Skill *is* the non-consumption.
  Plus `remove_entity` on the rubble → permanent path.
- **Cost: S.** One item, arms on rubble props, no engine.
- **Spoiler: Vol 6 — safe. Cite the Skill only; the Pyrite-memory arc runs
  into Vol 7-8.**
- **Note:** cheapest way to give a non-combat class a *tool-gated* verb that
  reads as expertise rather than magic.

---

**7. [Long Ear]** — PERCEPTION
- **Canon:** ATTESTED. Wiki *Skills Effect/L*, cites **ch 5.11 E**. Effect
  verbatim: *"Gives the User long range hearing."* Holders per wiki insource
  search include **Zevara Sunderscale** ([Watch Captain] — already a shipped
  NPC), Falene Skystrall, and Beastkin generally.
- **Classes:** Scout, Rogue, Watch/Guard, Ranger.
- **Field verb:** Ear to the faced door/wall: how many are on the other side,
  what they're saying, whether the room ahead is empty.
- **Hook:** two options, controller picks. (a) **S:** pure `skill_uses`
  authored arms on specific doors — the pantry-door precedent (field_skills.gd:
  62-72) where one entity answers observe *and* detect_magic differently; this
  one adds a third ear. (b) **M:** a generic `listens × door` property row →
  `bank_toast` (spec §4.1) so it works on *every* door, which is the
  universality beat the spec §3 says is the deliverable core.
- **Cost: S (authored) / M (generic).** Recommend (b) — three-plus interesting
  rows exist (doors, the sewer grates, the trapped_halls seams), clearing the
  spec §8 budget rule.
- **Spoiler: Vol 5 — safe.**
- **P4 check:** must break sneak and cost the action tick. Standing with your
  ear on a door is a posture, not a passive.

---

### TIER B — strong, mid-cost or narrower

---

**8. [Prey Sense]** — PERCEPTION
- **Canon:** ATTESTED. Wiki *Skills Effect/P*, cites **ch 6.61 L**; holder
  **Bird** (Antinium [Hunter]; listed on his page). Effect verbatim: *"Allows
  the User to sense any creatures it considers prey in their vicinity."*
- **Classes:** Hunter, Beast Tamer, Ranger, Scout.
- **Field verb:** Toast naming direction + count of beast-kind nearby.
- **Hook:** **the target property already ships with carriers.** `beast: true`
  has 7 carriers across `data/maps/`, and `_wild_affinity_reduction`
  (wi_game.gd:625-645) already reads it as a first-class category. So spec
  §5's carrier-cross-ref arm passes on day one — no map authoring needed for
  row 1.
- **Cost: S-M.** One dispatch arm or one `senses_prey × beast` row →
  `bank_toast`. No state.
- **Spoiler: Vol 6 — safe.**
- **Design note:** deliberately *not* [Foefinder's Scan] (#9). Prey ≠ foe: this
  finds the hunt, not the ambush. Keeping them distinct is what makes [Hunter]
  and [Scout] read differently.

---

**9. [Foefinder's Scan]** — PERCEPTION
- **Canon:** ATTESTED. Wiki *Skills Effect/F*, cites **ch 6.62 L**. Effect
  verbatim: *"The User can look for nearby enemies and identify their number
  and approximate size."* No named holder found on the wiki.
- **Classes:** Scout, Tactician, Ranger, Strategist.
- **Field verb:** Reveal armed ambushes in a radius — count and rough size —
  without triggering them.
- **Hook:** reads exactly the set `_ward_field` (wi_game.gd:682-723) and
  `_check_trigger_radius` already walk: armed encounters with a
  `trigger_radius`. Emits `TOAST` only, banks `scouted_danger`. **Zero new
  state, zero persistence.**
- **Cost: M** (new dispatch arm, small).
- **Spoiler: Vol 6 — safe.**
- **Systemic value:** this becomes the **fourth answer to an ambush**, joining
  the three that already ship — sneak past it (rogue), blink past it (runner/
  mage), ward it (witch). "Know it's there and choose" is the *tactician's*
  answer, and it's the missing one. The floodplains road-ambush QA script
  (class-expansion §8, L-QA-B) already proves the other three coexist; this
  extends the same canonical.

---

**10. [Campfire Chef]** — ECONOMY / INTERACTION
- **Canon:** ATTESTED. Wiki *Skills Effect/C* and the *Cooking (skill)* page,
  cites **ch 5.37 G**. No effect text on the wiki (name + citation only) — the
  reading "cook without a kitchen" is inference from the name; **flag as
  ATTESTED-NAME / INFERRED-EFFECT** for the canon reviewer.
- **Classes:** Cook, Chef, Ranger, Scout, Hunter.
- **Field verb:** Cook **anywhere**, no hearth. Once per waking, outdoors →
  `hot_meal`.
- **Hook:** today **every** cooking verb is a `requires_skill` arm on a station
  prop (stove, stew pot, chef's counter — class-expansion §6). This inverts it:
  the Skill *is* the station. Implementation is the `field_ambient`-position
  arm + `pickup` + a waking-scoped key (the `serve:<id>` idiom, wi_game.gd:498,
  re-keyed to the skill rather than an entity).
- **Cost: S.**
- **Spoiler: Vol 5 — safe.**
- **Why:** the [Cook]/[Chef] line currently only matters *inside buildings*.
  This makes a non-combat class matter **on the road**, which is where the
  exploration complaint actually lives.

---

**11. [Bar Fighting]** — INTERACTION / ECONOMY
- **Canon:** ATTESTED. Wiki *Skills Effect/B*, cites **ch 1.28**; holder
  **Erin Solstice** (her leveling history). Effect verbatim: *"Grants increased
  aptitude with weapons made from things that can be found in a bar."*
  Sibling: **[Tavern Brawling]**, cite ch 1.16, *"Innate sense for fighting in
  an inn or tavern."*
- **Classes:** Innkeeper, Helper, Barmaid, Warrior.
- **Field verb:** Inside an inn/tavern map, cast at a chair/bottle/pan → yields
  a one-fight improvised weapon.
- **Hook:** the one-shot `next_fight` buff dict already ships end-to-end —
  items.json `use_effect.next_fight` → `pending_meal`, folded into
  `_build_player_combatant` at the next `start_combat` then cleared
  (AGENTS.md:184). A "bottle" item with a `next_fight` payload is data.
- **Cost: S.**
- **Spoiler: Vol 1 — safe.**
- **Charm:** makes the inn map *mechanically* special rather than just
  narratively special, and it is the most Erin thing in the list.

---

**12. [Night Eyes]** — PERCEPTION / MOVEMENT — ⚑ **INVENTED name, ATTESTED
effect**
- **Canon:** ⚑ **split verdict, read carefully.** The EFFECT is attested at
  **ch 5.05**: Halrac Everam's wiki page lists an unnamed Skill — *"??? —
  Enhance the User's eye vision to be superior to an owl's in pitch
  blackness"* — with a 5.05 reference. The canon *name* for this shape,
  **[Owl's Vision]** (Bird), cites only **ch 9.48** → spoiler-blocked. So:
  invented name over a Vol-5-attested effect on a Vol-1-established [Veteran
  Scout].
- **Classes:** Scout, Rogue, Hunter, Ranger.
- **Field verb:** See in dark cells **without lighting them.**
- **Hook:** the spec's own proposed `dark cell*` target property (§7 matrix
  row for `light`), read passively against a known-skill check. The shipped
  `light_active` flag (cleared by `sleep()`, wi_game.gd:2365) is the contrast
  state.
- **Cost: M.**
- **Spoiler:** ⚑ name invented *because* the canon name is blocked — call this
  out to the user explicitly; they may prefer to take the exception.
- **Best trade design in the doc:** the mage's [Light] illuminates the room —
  which means **everyone sees you**, and it breaks nothing but your own
  concealment budget. The scout's eyes cost nothing and reveal nothing. Same
  information, opposite silhouette. That is P1 stated as a player choice.

---

**13. [Detect Poison]** — PERCEPTION
- **Canon:** ATTESTED. Wiki *Skills Effect/D*, cites **ch 5.24 L**; wiki
  insource search also surfaces **ch 5.26 L** and attributes the holder as
  **Lyonette du Marquin** (her levelling history lists it). Effect verbatim:
  *"The User can detect if poison is in something they plan to eat or drink,
  by seeing something poisoned as **uncleaned or dirty**."*
- **Classes:** Barmaid, Server, Innkeeper, Rogue, Cook.
- **Field verb:** Cast at a meal/cask/well → clean or foul.
- **Hook:** **canon hands you the property vocabulary for free.** The effect
  text literally describes poison as reading `dirty` — which is the exact
  target property the spec proposes in §7's matrix (the `dirty*` column,
  basic_cleaning's row). A `detects_poison × dirty` row → `bank_toast`, plus a
  `refuse` row on a trapped consumable, is coherent from the two vocabularies
  alone — the spec's own "authored-feeling test" (§7, ★ cells).
- **Cost: S-M.**
- **Spoiler: Vol 5 — safe.**

---

**14. [Lightning Sprint]** — MOVEMENT
- **Canon:** ATTESTED. Wiki *Skills Effect/L*, cites **ch 4.30**; holder
  **Relc Grasstongue** ([Spearmaster], shipped NPC — his page lists it).
  Effect verbatim: *"Gives the user an immense burst of speed."*
- **Classes:** Warrior, Spearmaster, Runner, Guard.
- **Field verb:** Cross N cells along facing in one action — but **the whole
  path must be walkable**. You out-run the ambush; you never skip over a gap.
- **Hook:** `_blink_field` (wi_game.gd:589-622) with **the `_is_freezable`
  `continue` removed** (:597-599) and the bypass credit kept
  (`_blink_bypassed_encounters`, :648+). Same store-free shape, distinct
  dispatch arm.
- **Cost: M.**
- **Spoiler: Vol 4 — safe.**
- **Differentiation, load-bearing:** [Double Step]/[Flash Step] are
  **teleports** — they cross water, walls-permitting, and are magic-shaped.
  This is **running** — it costs a clear road, which means the mage's blink and
  the warrior's sprint solve *different* maps. Without that constraint this is
  a reskin and should be cut.

---

**15. [Basic Crafting] → [Advanced Crafting]** — ECONOMY / INTERACTION
- **Canon:** ATTESTED. [Basic Crafting] — wiki *Skills Effect/B*, cites **ch
  1.07**; holders Erin Solstice, Lyonette, **Toren**. Effect verbatim:
  *"Assists with creating basic items and tools. Minor repairs become much
  easier."* [Advanced Crafting] — cites **ch 2.30** (wiki table also lists
  2.17); holder **Ksmvr** (his page lists it). Effect: *"Assists with
  assembling more complex items with greater ease."*
- **Classes:** Crafter, Laborer, Cook, Adventurer-generalist.
- **Field verb:** Junk in the pack → a tool. Scrap + cloth → torch; sinew +
  haft → pick; plank + nail → a repair kit that feeds #4.
- **Hook:** the **alchemist bench recipe seam verbatim** — `requires_item`
  (Array, all-or-nothing) + `remove_item` + `item` yield (wi_game.gd:465-472,
  529-531), which is exactly the shipped [True Synthesis] `solvent_phial +
  mineral_salts` shape. **Data-only.**
- **Cost: S.**
- **Spoiler: Vol 1 / Vol 2 — safe.**
- **Duplicate risk — REAL, and the differentiator is the point:** mechanically
  this *is* the Alchemist bench. It must differ on **station-dependence**:
  Alchemist needs a bench prop; [Basic Crafting] does not. That is the whole
  fantasy (a crafter improvises; an alchemist needs glassware) and it is one
  boolean's worth of authoring. If the controller won't grant the
  no-bench distinction, **cut this** — otherwise it's a reskin.

---

**16. [Eyes In The Back]** — PERCEPTION (PASSIVE)
- **Canon:** ATTESTED. Wiki *Skills Effect/E*, cites **ch 7.28**; holder
  **Relc Grasstongue** (his page lists it). Effect verbatim: *"The User has a
  vague sense of what was behind them. The User can't see details, but could
  easily spot anyone running in a hurry."*
- **Classes:** Guard, Warrior, Rogue, Scout.
- **Field verb:** Ambushes that arm from **behind** your facing announce
  themselves instead of firing.
- **Hook:** **passive**, per P3 and the tiresome-actives doctrine. A known-skill
  read inside `_check_trigger_radius`, structurally identical to
  `_wild_affinity_reduction` (wi_game.gd:625-645) which already silently
  changes ambush behavior for a [Beast Tamer] with no cast and no hotbar slot.
- **Cost: S-M.**
- **Spoiler: ch 7.28 — late Vol 7, but INSIDE the Book-17/Vol-7 bar. Note for
  the reviewer: this is the latest citation in Tier A/B; if the controller
  wants extra margin, drop it.**
- **Why include a passive at all:** the field hotbar is 5 slots and already
  contested. A martial kit that is *all* actives will crowd out the cooking
  and cleaning verbs. Half-passive is the shape.

---

### TIER C — good ideas, higher cost / narrower / needs a ruling

---

**17. [Eye of Need]** — ECONOMY / LEGIBILITY
- **Canon:** ATTESTED. Wiki *Skills Effect/E*, cites **ch 4.20 E**; holder
  **Prost Surehand** ([Farmer]/[Steward]). Effect verbatim: *"The User can tell
  what they're low on and what issues are most critical and require
  attention."*
- **Classes:** Steward, Innkeeper, Helper, Trader, Tactician.
- **Field verb:** Names the one thing you're short of and points at the nearest
  unfinished thread.
- **Hook:** a read-only derivation over shipped state — `inventory` plus the
  quest beat re-derivation `_check_quests` already runs every tick
  (wi_game.gd:1518-1534). No new state.
- **Cost: M** (the derivation + careful copy).
- **Spoiler: Vol 4 — safe.**
- **Cross-ref:** overlaps
  `docs/design/2026-08-02-quest-clarity-spec.md` — the controller should check
  whether that spec already owns this surface before funding it as a Skill.
  Turning a legibility feature into a *class privilege* is a real design
  question, not a free win.

---

**18. [Detect Guilt]** — PERCEPTION (SOCIAL)
- **Canon:** ATTESTED. Wiki *Skills Effect/D*, cites **ch 1.10**; holder
  **Relc Grasstongue** (his page lists it). Effect verbatim: *"The User can
  detect if someone has committed a crime. Appears as dark splotches on the
  Target."*
- **Classes:** Guard, Watch, Rogue, Diplomat.
- **Field verb:** Cast at an NPC → the splotches, or their absence.
- **Hook:** the `charming_smile` generic-NPC arm shape verbatim
  (field_skills.gd:82-90): a per-entity `guilt_line` key, a first-use dedup
  bank (`_bank_first_use`), a counter.
- **Cost: S.**
- **Spoiler: Vol 1 — safe.**
- **Design warning:** must be a **hint layer, never a bypass** — the shipped
  precedent is `detect_magic`'s wardwork arms, which reveal the trap-tell while
  the observe/disarm routes stay the mechanical bypass (class-expansion §6).
  Without that discipline this Skill solves every mystery in the game on sight.

---

**19. [Detect Flaw]** — ECONOMY / PERCEPTION
- **Canon:** ATTESTED. Wiki *Skills Effect/D*, cites **ch 4.35 E**. Effect
  verbatim: *"The User can detect flaws in objects, like gemstones."* Holder
  attribution on the wiki is thin (insource surfaces Tessia, Zedalien) —
  **flag: attested Skill, weak holder attribution.**
- **Classes:** Trader, Merchant, Crafter, Miner.
- **Field verb:** Spot the flaw — in a gem (price), in a wall (a `broken`
  carrier for #4), in a lock.
- **Hook:** `appraise_goods` / `evaluation_of_wealth` both ship as
  `field: true` read verbs; this is a third in that family, plus it **produces
  the target tag** #4 consumes.
- **Cost: S.**
- **Spoiler: Vol 4 — safe.**
- **Duplicate risk:** high against [Appraise Goods]. Differentiate hard:
  Appraise = *what it's worth*; Detect Flaw = *where it will break*. Only fund
  if #4 [Basic Repair] is also funded — alone it's a third appraise verb.

---

**20. [Set Snare]** — INTERACTION — ⚑ **INVENTED, canon-style**
- **Canon:** ⚑ INVENTED. Canon-adjacent: snares are established world furniture
  (a Raskghar snare prop already ships in
  `data/maps/sewers/deep_tunnels.json` with a `disarm_trap` arm), and
  [Deploy Trap: Bear Trap] exists on the wiki but carries no early citation.
  Noun-phrase form per ruling 9.
- **Classes:** Hunter, Rogue, Ranger, Beast Tamer.
- **Field verb:** The **inverse of the shipped [Disarm Trap]** — arm a snare on
  a faced cell; the next ambush that would fire there is pacified instead.
- **Hook:** `dormant_encounters` — the shipped, until-sleep, entity-keyed
  pacification store that `_ward_field` (wi_game.gd:682-723) already writes and
  `_check_trigger_radius` already honours. **Note the spec's own boundary:**
  §4.1 rules out repurposing `dormant_encounters` as a generic *prop*-state
  store; this is not a prop, it is encounter pacification — the sanctioned use.
- **Cost: M.**
- **Spoiler:** n/a (invented).
- **Symmetry value:** [Disarm Trap] ships at rogue L5 and only ever *removes*.
  Giving the same class family the constructive half is cheap and reads as
  mastery.

---

**21. [Ingredients Sense (Minor)]** — PERCEPTION / ECONOMY
- **Canon:** ATTESTED. Wiki *Skills Effect/I*, cites **ch 7.05 P**. Effect
  verbatim: *"Allowed the User to instantly know what edible things are around
  them. Although it has a range of about 5 feet, it still picks up everything
  edible in the area."*
- **Classes:** Cook, Chef, Hunter, Druid, Ranger.
- **Field verb:** Reveal + gather forageables in a small radius.
- **Hook:** the spec's own proposed `growth*` target property (§7 matrix,
  hedge_remedy × growth cell, marked ★) → `bank_toast` + `item` yield.
- **Cost: S-M.**
- **Spoiler: ch 7.05 — early Vol 7, inside the bar. Safe.**
- **Dependency:** worth little until `growth` carriers exist; bundle with the
  spec's slice-2 tag pass rather than funding standalone.

---

**22. [Alcohol Brewer]** — ECONOMY
- **Canon:** ATTESTED. Wiki *Skills Effect/A*, cites **ch 1.22**; holder
  **Erin Solstice**. Effect verbatim: *"Provides general knowledge of brewing
  alcoholic beverages such as necessary ingredients or fermentation time."*
- **Classes:** Innkeeper, Cook, Helper, Trader.
- **Field verb:** Cask prop → a sellable/consumable brew.
- **Hook:** 100% shipped machinery — `requires_skill` arm, `item` yield,
  `gold_once_per_waking` payout cap (wi_game.gd:508-518).
- **Cost: S.**
- **Spoiler: Vol 1 — safe.**
- **Honest assessment:** lowest fun ceiling in the doc — it is a third bench
  verb next to cooking and alchemy. Included because it is nearly free and it
  gives [Innkeeper] a road-independent income sink. Cut without regret if the
  slate is tight.

---

**23. [Battlefield Eye]** — PERCEPTION
- **Canon:** ATTESTED. Wiki *Skills Effect/B*, cites **ch 4.05 K**; holder
  **Belgrade** (Antinium [Tactician] — his leveling history lists it). Effect
  verbatim: *"Creates a mental image of the battlefield from any angle based on
  line of sight and reports received."*
- **Classes:** Tactician, Strategist.
- **Field verb:** Read the room — exits, hazards, how many things here answer a
  Skill.
- **Hook:** the honest cheap version is `bank_toast` naming exits +
  interactable count, derived from map data already in hand. **The expensive
  version (real fog-of-war reveal) has no substrate — no fog system ships** —
  and is presentation-shaped, which spec §9 slice 3 explicitly fences to
  issue #335.
- **Cost: M (toast version) / L (any real reveal — do not fund here).**
- **Spoiler: Vol 4 — safe.**
- **Note:** [Tactician] currently grants exactly one field skill (`observe`).
  This is the natural second, and it is the only candidate that speaks to the
  Tactician/Strategist line at all.

---

**24. [Flawless Attempt]** — META (INTERACTION)
- **Canon:** ATTESTED. Wiki *Skills Effect/F*, cites **ch 5.26 L**; holder
  **Lyonette du Marquin** (her levelling history). Effect verbatim: *"Allows
  the User to do a single task to the best of their physical/magical ability.
  There is presumably a limit for the maximum length of the tasks, which so far
  have lasted less than 10 minutes."*
- **Classes:** any non-mage (canon presents it as broadly available).
- **Field verb:** The martial [Quick Cast] — the next field Skill you use this
  waking **cannot refuse**; a `refuse` row resolves as its success row instead.
- **Hook:** a one-shot boolean consumed at the top of `WIFieldSkills.dispatch`,
  modelled on the shipped `pending_meal` one-shot (AGENTS.md:184).
- **Cost: M.**
- **Spoiler: Vol 5 — safe.**
- **Risk, stated plainly:** it can produce resolutions nobody authored, which
  is precisely what spec §4.1 forbids ("a rule engine produces resolutions
  nobody authored — which is what QA-first forbids"). **Only fund with a
  whitelist**: [Flawless Attempt] promotes a specific, enumerated set of
  refusal rows, each with its own authored success copy. With that constraint
  it is a lovely "second chance" verb that makes the property table's refusal
  cells feel like locked doors rather than walls. Without it, cut.

---

## 5. Coverage check against the classes that have nothing

| Class | field skills today | candidates above that fix it |
|---|---|---|
| warrior / swordsman / spearmaster | **0** | #1 Even Footing, #3 Greater Strength, #4 Basic Repair, #14 Lightning Sprint, #16 Eyes In The Back |
| archer / sharpshooter | 1 (keen_eye, read-only) | #2 Rope Work, #8 Prey Sense, #9 Foefinder's Scan |
| ranger | **0** | #1, #2, #8, #10 Campfire Chef, #21 Ingredients Sense |
| infiltrator | **0** (inherits rogue's 3) | #7 Long Ear, #12 Night Eyes, #20 Set Snare |
| scout | 1, at **L14** | #1, #2, #7, #9, #12 — this line is the biggest winner |
| tactician / strategist | 1 (observe) | #9 Foefinder's Scan, #23 Battlefield Eye, #17 Eye of Need |
| trader / merchant | 2, one at L14 | #5 Broader Shoulders, #19 Detect Flaw |
| cook / chef | 2 (both station-bound) | #10 Campfire Chef, #13 Detect Poison, #21 Ingredients Sense |
| (new) laborer / miner / crafter | n/a | #3, #4, #5, #6 Durable Picks, #15 Basic Crafting |

**Three-pillars gate (spec §7 acceptance rule — non-combat majority):** of the
24, **17 are social/puzzle/economy-pillar verbs** and 7 are combat-adjacent
(movement + ambush perception). Passes with margin.

**Explicit-Skill-use doctrine:** every active above fires only from
`use_skill_field` (wi_game.gd:573-588) at a faced cell. **`interact()` consults
none of them.** The four passives (#1 Even Footing, #12 Night Eyes, #16 Eyes In
The Back, and the passive half of #8) take **no hotbar slot** — deliberate,
because the field bar is 5 wide and already contested by cooking/cleaning.

---

## 6. Considered and cut (with reasons — curation input, not candidates)

- **[Blur Leap]** (ATTESTED 5.58, Seborn Sailwinds) — *"Accelerates jump
  motion. Also can turn in midair."* Cut: `double_step` already ships at
  runner L5 with `blinks: true, blink_range: 2`. This is the same slot at the
  same range. Only revive it with a hard differentiator (diagonal leaps, or
  landing *on* a hazard cell).
- **[Loud Voice]** (ATTESTED 1.00 C, Erin/Menrise) — hail across a gap, draw a
  guard, scare a beast. Genuinely charming and it self-balances (it must break
  sneak by definition). Cut only for cost: opening a dialogue graph at range is
  a new targeting mode. **Cheap revival: make it a `wards`-shaped noise that
  scatters one beast ambush.** Worth a second look.
- **[Deft Hand]** (ATTESTED 4.48, Magnolia Reinhart / Seraphel / Eloise) — cut
  on **principle P1**: the wiki calls it *"minor telekinesis"* outright. It is
  the one canon martial-adjacent option that is unambiguously spell-shaped, and
  its holders are nobles, not fighters.
- **[Twofold Rest]** (ATTESTED, *Interlude – The Hangover After*, Erin) — sleep
  economy. Cut on blast radius: `times_slept` drives bounty rotation and the
  inn-guest seating window, so anything that perturbs it re-derives pinned
  canonicals. A safer reading (until-sleep effects survive one extra sleep —
  the `ward_sleeps: 2` precedent generalized) is fundable if the user wants it.
- **[Basic Fortification Construction]** (ATTESTED 4.42 L, Belgrade) — placing
  a *new* blocking entity is new save state → K3 (spec §10). An authored-socket
  version is fine but is really just #4 [Basic Repair] wearing a helmet.
- **[Weathersense]** (ATTESTED 6.34 E) — no weather system exists; the Skill
  would be pure flavor text. Revisit if weather ever ships.
- **[Natural Concealment]** (ATTESTED 3.27 M) — duplicates `sneak`/
  `invisibility` (`sneaks` flag, 2 carriers already).
- **[Keen Eyes]** (5.41), **[Evaluation of Wealth]** (6.17 S),
  **[Eagle Eyes]** (2.11) — already shipped. Listed so the controller can see
  they were checked for duplicates.

---

## 7. Spoiler-blocked canon (do NOT use these names)

Every one of these is a canon Skill that would fit beautifully, and every one
fails **spoiler-cutoff.md** — either a post-Vol-7 citation or (rule 5)
ambiguous timing, which defaults to blocked.

| Blocked name | Only wiki citation | Would have been | Safe substitute in this doc |
|---|---|---|---|
| **[Rope Arrow]** | *Interlude – Adventurers (Pt. 2)*, 2022-11-13 (Vol 8/9 era). Holders Halrac, Nailren | the perfect traversal verb | **#2 [Rope Work]** ⚑ |
| **[Owl's Vision]** | 9.48 (Bird) | night vision | **#12 [Night Eyes]** ⚑ (effect attested 5.05 via Halrac) |
| **[Sure Footing]** / **[Surefoot]** | 9.19; Ksmvr | footing | **#1 [Even Footing]** (2.24 T — better anyway) |
| **[Directionsense]** | 9.69 H (Pt.2); Ksmvr | navigation | none proposed |
| **[Advanced Tracking]** | 10.63 RY | tracking | none proposed |
| **[Climber's Hold]** | 9.49 | climbing | partially **#2** |
| **[Advanced Butchery]** | 9.43 L | field-dress a kill | partially **#5** |
| **[Softfoot]**, **[Depth Dive]**, **[Estimate Wealth]** | Halfseekers interludes, 2025 (Seborn) | stealth / swim / appraise | shipped equivalents exist |
| **[Bird's Eye View]** | *Interlude – The Spitoon*, 2023 (Olesm) | map reveal | **#23 [Battlefield Eye]** (4.05 K) |
| **[Locate Shelter]**, **[Forager's Senses]**, **[Highlight Forageables]**, **[Hound's Nose]**, **[Increased Carry Weight]**, **[Enhanced Grip]** | Vol 9-10 | various | **#21**, **#5** |

**Method note for the canon reviewer:** every citation in §4 was pulled from
`wiki.wanderinginn.com` via `index.php?action=raw` on the `Skills Effect/<L>`
transclusion pages (the master alphabetical tables: name / effect / reference
chapter), cross-checked against character pages
(`Halrac_Everam`, `Relc_Grasstongue`, `Bird`, `Ksmvr`, `Seborn_Sailwinds`,
`Numbtongue`, `Garia_Strongheart`, `Olesm_Swifttail`, `Krshia_Silverfang`,
`Jelaqua_Ivirith`) and `api.php` insource searches for holder attribution.
**Effect quotes are the wiki's wording, not the serial's** — a canon reviewer
should spot-check the chapter itself before any of these ships, per the
established ATTESTED-vs-⚑ discipline. Skills where the wiki gives a name and
chapter but **no effect text** are flagged inline (#10 [Campfire Chef] is the
one such case in the funded tiers).

---

## 8. Suggested slate if the user wants a single wave

Not a plan — a shape, for the controller to price.

- **The headline pair (prove the thesis):** #1 [Even Footing] + #2 [Rope Work].
  One is "the world can't stop me", the other is "I left a way through". Between
  them they answer [Ice Floor]→walkable-water twice, from two different
  directions, and neither is a spell.
- **The free wins (all cost S, all data-only, zero engine):** #3 [Greater
  Strength], #5 [Broader Shoulders], #6 [Durable Picks], #11 [Bar Fighting].
  Four martial verbs for the price of map authoring.
- **The property-layer showcase:** #4 [Basic Repair]. If the emergent-
  interactions spec ever ships slice 2, this is the row that justifies it —
  a one-way `state_set` on a `broken` carrier is the verb that substrate was
  built for.
- **Defer:** everything in Tier C until #335's feedback layer lands (spec §9
  slice 3 dependency — an emergent resolution nobody notices is wasted
  content), and all of §6 pending user taste.

---

*End of candidate doc. 24 candidates, 21 canon-attested + 3 explicitly
invented. No repo files were modified in producing this.*
