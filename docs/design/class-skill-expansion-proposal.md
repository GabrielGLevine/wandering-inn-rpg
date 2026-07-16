# Class & Skill Expansion — Design Proposal (Fable, 2026-07-15)

**Status: PROPOSAL — user-gated.** Nothing here is implemented. Every canon
verdict below was wiki-verified this session (MediaWiki API pulls of
character pages, Leveling Histories, List of Classes, Skills Effect and
Spells indexes) against the two-tier spoiler rule (`spoiler-cutoff.md`):
Book 17 bar for new content, Volume 7 advertised. Every engine claim was
verified against `src/core/` this session (file:line cites in the
machinery appendix).

## 1. Goals

- Widen the class board past [Mage]/[Warrior]-shaped play: movement,
  witchcraft, necromancy, cooking, scouting — each with evolution and/or
  consolidation options per the existing `WIProgression` contracts.
- Give exploration Skills real overworld verbs with visual effects (the
  [Light]/[Stealth]/[Snap Freeze] family), and make sure **every new verb
  has at least two existing map/quest touchpoints** plus room for a new
  content slice.
- Balance through the existing game: reuse shipped effect types and
  threshold curves; anything touching combat kits re-runs
  `sim_combat_batch.gd` (0.55–0.95 band).

## 2. Design principles applied

1. **Accomplishment-driven, never chosen** — every class gains via
   `gained_by.accomplishment` with a producer that exists (test_content
   enforces this).
2. **Explicit Skill use** (user directive 2026-07-10) — all field verbs are
   hotbar casts, never auto-fired by interact; tiresome actives become
   passives.
3. **Machinery-reuse ladder** — Wave A is data-only (the
   `requires_skill`+`on_skill_use` prop seam costs zero engine code);
   Wave B is three bounded engine seams; nothing speculative.
4. **Canon names with verdict flags** — attested names cited; ORIGINAL
   names carry the established `CANON-VERDICT` `_comment` flag; ruling 9
   (no bare action-verb names) honored.
5. **Three pillars** — two of the four new base classes are primarily
   non-combat (Runner, Cook), one is mixed (Witch), one combat
   (Necromancer); the consolidation (Scout) feeds the puzzle pillar.

## 3. Roster overview

| New class | Kind | Gained by | Evolution | Consolidation | Aspiration |
|---|---|---|---|---|---|
| [Runner] | base, movement/economy | delivery-board contracts | → [Courier] (attested class, 4.24) | future: ×[Trader] line (name unverified — parked) | — (evolution IS the ladder) |
| [Hedge Witch] | base, craft/social | Eloise teaching chain | → [Witch] (craft proven) | future: [Tea Witch] fork (Eloise's line, 6.40) | "A [Witch] is her craft. Find yours, and the hat will follow." |
| [Necromancer] | base, combat/utility | Pisces study chain | PARKED (no attested ≤Vol-7 evolution; aspiration carries it) | — (Pisces dual-class precedent: holds beside [Mage]) | "At the height of the art, the dead answer in shapes no grave ever held." (Bone Horrors, 4.37 O) |
| [Cook] | base, economy/support | cooked meals (counter ships today) | → [Chef] (attested, Lasica of Pallass 6.10) | future: ×[Helper] line | — |
| [Scout] | **consolidation** [Rogue]×[Archer] | lines at 10/10, combined 21 (the pinned gate shape) | — | is one | [Veteran Scout] (Halrac, Vols 3–7) |

Canon verdicts (wiki, chapter cites): [Runner] PASS (3.16; **Street/City
Runner are guild RANKS, not classes** — usable as diegetic Runner's Guild
rank text, not as class ids); [Courier] PASS as class (4.24, 4.44 M);
[Witch]/[Hedge Witch] PASS (6.41 E); [Tea Witch] PASS (6.40 E, Eloise);
[Necromancer] PASS (Pisces, 1.06 R); [Cook]/[Chef] PASS (3.16 / 6.10);
[Scout]/[Veteran Scout] PASS (3.02 H / Halrac through Vol 7).
**Excluded by the Book-17 bar:** [Crow Witch] (7.55), Pelt's true class
(8.09), Wilovan's true class (9.27), [Mass Teleportation] (7.36), the
Vol 8-9 witch titles, the literal "power stored in hats" phrasing (Vol 9
cite — the Vol 6 arc gives us hats + emotion-gathering, phrase loosely).

## 4. Class specs

### 4.1 [Runner] → [Courier]

The delivery board (13 contracts, cross-region + standing routes) is a
complete leveling substrate already shipped. CHOICES #24 deferred an
aggregate delivery counter "until it ships for its own reasons" — this
class is that reason, and it retroactively enables the Papers-for-Pallass
completed-postings record path.

- **New counter:** `completed_delivery`, banked in the delivery-completion
  code path next to the per-contract `delivered_<id>` ids (~2 lines).
- **gained_by:** `{ "completed_delivery": 2 }` — two board runs.
- **stat_growth:** `{ "dex": 1 }`; [Courier] `{ "dex": 1, "con": 1 }`.
- **Kit:** L1 [Quick Movement] (exists; attested for Valceif 2.18 — reuse,
  two-class-grant precedent exists) + [Runner's Legs] (ORIGINAL ⚑,
  passive identity, lesser_stamina shape). L3 [Efficient Run] (attested,
  Fals 7.00 — inside Book 17) — passive. L5 **[Double Step]** (attested,
  Valceif 2.15 "every step covers twice the distance") — the Wave-B hop
  verb, combat half = `move_pool_bonus 2, ap 1`. L8 [Sure Delivery]
  (ORIGINAL ⚑, passive: fragile parcels never break — reads the existing
  `fragile` contract flag).
- **Levels:** `requires_any { completed_delivery, delivered_item }` —
  helper's own curve shape, thresholds tuned to measured board cadence
  (implementer derives from bounty-rotation pacing; no new formula).
  Sharing `delivered_item` with [Helper] is sanctioned counter-sharing
  (melee_hit already feeds warrior AND spellsword).
- **Evolution:** at_level 10, single-axis `{ "completed_delivery":
  "courier" }` (tactician/trader precedent, min_uses 12 clears trivially —
  document in `_comment`). [Courier] sparse table floor 10, L10 grant
  [Courier's Word] (ORIGINAL ⚑, passive: standing contracts pay +1g —
  small read at delivery payout, or ships flavor-only v1).
- **Diegetic rank text:** Runner's Guild board copy can promote Street
  Runner → City Runner as *rank*, canon-clean, zero mechanics.

### 4.2 [Hedge Witch] → [Witch]

Canon arc, literally: "a hedge witch WITH a craft beats a trained witch
without one" (6.41 E). Eloise ([Tea Witch], canonically resident at
Riverfarm — CHOICES #63) is the teacher; witch_hollow and
price_of_a_favor already ship.

- **gained_by:** `{ "witch_lessons": 1 }` — new Eloise dialogue chain,
  gated on a non-violent price_of_a_favor resolution (`mediated_the_debt`
  or the paid-it-yourself path) + a warmth gate (befriended_moments tier).
  Producer: the new dialogue node.
- **stat_growth:** `{ "int": 1 }`; [Witch] `{ "int": 1, "cha": 1 }`.
- **Kit:** L1 **[Brew Remedy]** (ORIGINAL ⚑ — field skill; casts at
  cauldron/hearth props via the zero-cost `requires_skill`+`on_skill_use`
  seam; witch_hollow's cauldron already gates on basic_cooking at
  :430, so the prop pattern is proven; yields a remedy consumable and
  banks `witch_craft_used`). L3 [Witch's Warding] (ORIGINAL ⚑, combat:
  `mana_shield` reuse — a charm, not a spell, no mp grant… **note:**
  mp_cost presence is what grants max_mp; keep the witch kit AP-only so
  witches don't silently become mana casters). L5 **[Hearthward Charm]**
  (ORIGINAL ⚑ — the Wave-B ward verb: suppress one nearby armed ambush
  until next sleep, banks `warded_danger`). L7 [Evil Eye] (combat:
  `spell_damage` low + `weakened` rider — CANON-CHECK at implementation;
  if unattested, ORIGINAL ⚑ under a noun-phrase name).
- **Levels:** requires on `witch_craft_used` (umbrella counter banked by
  every craft prop/verb — single-axis by construction, avoiding the
  2-keys-1-target dominance trap the trader `_comment` documents).
- **Evolution:** at_level 10, single-axis `{ "witch_craft_used": "witch" }`.
  [Witch] sparse floor 10; L10 grant strengthens the ward (data retune,
  same id? NO — new id [Greater Hearthward] ⚑; ids never re-semanticized).
  Hat appears on evolution — cast-frame/sprite variant (PixelLab,
  wi-art-and-sprites pipeline). [Tea Witch] fork parked until a second
  craft's content exists.
- **FLAGGED DECISION:** canon witches are female-coded through Vol 7. The
  PC is unspecified. Default here: **no gender gate** (canon-liberty flag
  in the class `_comment`), user may overrule.
- Flavor cite for multiclass blessing: Alevica, the "Witch Runner" (6.35)
  — a [Witch] who is a City Runner. Witch×Runner on one PC is canon-shaped.

### 4.3 [Necromancer]

Closes CHOICES #8's deferred "Pisces perk needs real design." Pisces
dual-classes [Mage] Lv 20 + [Necromancer] (6.67) — canon precedent for a
separate base class held alongside [Mage], which leaves mage's shipped
evolution block untouched.

- **gained_by:** `{ "studied_necromancy": 1 }` — new Pisces dialogue
  chain: gated on holding [Mage] (dialogue reads the classes dict) + his
  existing warmth surface (the ticking-parcel delivery / pisces_magic
  thread). Necromancy stigma stays diegetic: Watch NPCs get cold variant
  lines, no mechanics.
- **stat_growth:** `{ "int": 1 }`.
- **Kit** (all attested — Pisces' own list): L1 **[Bone Dart]**
  (`spell_damage`, range 4, `element: "death"` — the element key makes
  `death_cast` bank automatically, zero engine code) + **[Detect Magic]**
  (2.15, Pisces & Ceria — field skill on the zero-cost prop seam: reveals
  wardwork, illusory floors, leyline signs). L3 [Deathbolt]
  (`spell_damage`, range 4, higher mp — his attested heavy bolt). L5
  **[Animate Dead]** (Wave B — raise a skeleton at bone-pile props; it
  joins subsequent fights through the existing ally roster seam until it
  falls or you sleep). L7 **[Flash Step]** (Wave B — see §5; canon home
  is exactly here: it is Pisces' Tier-3 spell, not a Runner Skill).
- **Levels:** `requires { death_cast: … }`, mage's spell_cast curve shape.
- **Evolution: PARKED** — no attested ≤Vol-7 necromancer evolution to
  target; the aspiration line carries the fantasy (Bone Horrors at Lv 30,
  4.37 O, PASS). Revisit on canon find. (Every other base class has an
  evolution; this is the one deliberate exception, documented.)
- **Balance:** this is a real combat class — new `sim_combat_batch`
  BUILDS rows solo and with-skeleton; skeleton reuses an existing vault
  skeleton combatant record at tuned HP.

### 4.4 [Cook] → [Chef]

The machinery already ships end-to-end: `cooked_meal` banks at inn hearth
props today; `pending_meal` feeds damage_mod/hp_mod/damage_reduction into
the next fight (`wi_game.gd:1327-1331`); items.json has `kind: "meal"`;
`well_fed` is a live dialogue effect. Pure data class.

- **gained_by:** `{ "cooked_meal": 5 }` (producers: inn hearth props,
  stretched_the_order path).
- **stat_growth:** `{ "con": 1 }`; [Chef] `{ "con": 1, "dex": 1 }`.
- **Kit:** L1 **[Advanced Cooking]** (attested, Erin 2.17 — field skill
  at hearth/stove props: produces meal items carrying `pending_meal`
  payloads; distinct id from basic_cooking, distinct icon). L5
  [Perfect Recall] (attested, Erin 2.17 — arts/recipes-scoped; passive
  identity + journal recipe flavor). L8 [Generous Portions] (ORIGINAL ⚑,
  passive: meals also cover allies entering the fight — data flag read
  where pending_meal applies, small).
- **Levels:** `requires { cooked_meal: … }` — helper's cooked_meal
  requires_any column, verbatim shape.
- **Evolution:** at_level 10, single-axis `{ "cooked_meal": "chef" }`.
  [Chef] L10 grant [Signature Dish] (ORIGINAL ⚑ — a strictly better meal
  recipe; new item, no new machinery).
- **Economy coupling:** meal/remedy item pricing lands inside the #92
  economy pass — this class ships its items priced by that ledger, not ad
  hoc.

### 4.5 [Scout] — consolidation, [Rogue]×[Archer]

Fills the consolidation gap for the two lines that have none, and feeds
the puzzle pillar (vantage/reveal play). Same pinned gate shape as
spellsword/innkeeper/ranger: `min_parent_level 10, min_combined_level 21`;
parent_lines `[["rogue","infiltrator"],["archer","sharpshooter"]]`;
sparse floor **derived** = 14 (ceil(2*(10+11)/3) — same walk as
spellsword's `_comment`; test_content re-derives it).

- **stat_growth:** `{ "dex": 1, "int": 1 }`.
- **L14:** **[Eagle Eyes]** (wiki-listed, Vol-2-era cite with renumbering
  drift — AMBIGUOUS-lean-PASS ⚑, flag in `_comment`): combat
  `hit_bonus 8`; field: long-range reveal via `requires_skill` vantage
  props (no engine code). **L16 capstone:** [Marked Quarry] (ORIGINAL ⚑,
  noun-phrase per ruling 9): `weapon: bow, ap 2, once_per_fight,
  damage_mult 1.8` — sudden_strike's exact pre-balanced numbers.
- **Aspiration:** [Veteran Scout] — "The wood, the wall, and the enemy
  camp: a [Veteran Scout] has already been there, and left no sign."

### 4.6 Existing-class enrichment (small, separate lane)

- **[Mage] L7 (currently empty): grant [Detect Magic]** — mage and
  necromancer both carry it (Ceria AND Pisces attest it, 2.15). Fills a
  dead level with an overworld verb. Checks required: no dialogue gates
  exist on `detect_magic` yet (new id — GH#64 audit trivially clean);
  QA scripts with L7+ mage fixtures re-assert hotbar slot counts
  (`mage_unlock_loop` asserts at L1 kit — unaffected; audit
  class_evolution_loop's near_evolution fixture).
- **Rogue second evolution fork ([Thief], attested 1.00 C): PARKED** —
  needs stealing machinery that doesn't exist; noted so the Gentlemen
  Callers surface (brothers_parlor) has a future mechanical home.

## 5. New overworld verbs and their world leverage

Engine facts (survey, this session): the `requires_skill`+`on_skill_use`
prop seam costs **zero engine code** and already ships in 9+ maps; sneak
is proximity-trigger suppression banking `sneaked_past_danger` per armed
`trigger_radius` entity; ambush zones with trigger_radius ship in
sewers (1), invrisil_boulevard (2), mercantile_alleys (2),
riverfarm_village (3), floodplains (3).

| Verb | Skill(s) | Engine cost | Existing touchpoints | New slice |
|---|---|---|---|---|
| Reveal (prop seam) | [Detect Magic], [Eagle Eyes] | **zero** — data props | trapped_halls illusory_floor + dart slits (props exist, VISUAL-LOG names them); door_that_goes_elsewhere wardwork (a fourth read-the-runes route); witch_hollow `visual_states` signs; ruin anchor stone | leyline traces at the Riverfarm standing stones |
| Brew/craft (prop seam) | [Brew Remedy], [Advanced Cooking] | **zero** — data props + items | witch_hollow cauldron (skill-gated prop already there); inn hearth ×2; pallass_market food stalls | Eloise's tea table at the inn |
| **Blink** | **[Flash Step]** (necromancer L7), [Double Step] (runner L5, short-hop tuning) | **new dispatch branch** — the one verb with no precedent (nothing mutates `player_cell` today): teleport N cells along facing with LoS/walkable checks, afterimage visual, `TELEPORTED` event; **banks `blinked_past_danger`** when the jump crosses an armed trigger_radius (else it would bypass silently and bank nothing — sneak-parity, dedup key per entity) | floodplains "Raiders in the Dark" respawning road ambush (the exact alternative-to-sneaking case); trapped_halls pressure plates (a fourth route beside fight/disarm/guide-Ksmvr); sewers channel gaps (crosses without [Snap Freeze] — deliberate overlap, two classes solve one obstacle differently); mercantile_alleys ambush pair | Pisces' footwork lesson on the floodplains (teaching beat for the grant) |
| **Ward** | [Hearthward Charm] (witch L5) | **new branch + suppression check** in `_check_trigger_radius` + sleep-expiry + placed-ward visual | the goblin road ambushes on the inn hamper route ("The road has goblins" — slip copy, literally); riverfarm_village's three ambush zones during the hunter arc; witch_hollow approach | warding Riverfarm's fields as a price_of_a_favor epilogue |
| **Companion** | [Animate Dead] (necromancer L5) | **injection at `start_combat`** ally-roster build (allies/ally_requires seam exists; roster is fixed at fight start — no mid-fight spawn needed) + follower sprite on the field | dungeon gallery skeletons (skeleton scene shipped in 8dC3); kingslayer_den bones; ruin_surface graves | a bone-pile prop family, biome-aware like #116's blocked-cell props |

Mobility design rule that falls out: **each line answers "danger ahead"
differently** — [Rogue] sneaks past it, [Witch] wards it off, [Necromancer]
flash-steps over it, [Runner] outruns it (double-step hops), [Warrior]
fights it. Same obstacle, five class-flavored answers: that is the
three-pillars doctrine on the overworld.

Hotbar note: no hard slot cap (bar grows; 9 number keys practical), and
`loadout_toggle` already ships — more field skills than keys is a solved
problem via the player-editable loadout.

## 6. Balance plan

- **Combat kits reuse shipped effect types only** (spell_damage,
  damage_mult, mana_shield, hit_bonus, move_pool_bonus, heal, riders
  burning/slowed/weakened/guarded) — no new resolver work in Wave A.
  Numbers copy pre-balanced precedents (marked_quarry = sudden_strike's
  1.8/once_per_fight; bone_dart ≈ frost_bolt band).
- **sim_combat_batch:** new BUILDS rows for necromancer (solo,
  with-skeleton) and any existing-class kit change (mage L7 is field-only
  — no sim impact). Win-rate band 0.55–0.95, rounds 3–12. Meal buffs get
  one harness arm (canonical seeds with/without pending_meal) since they
  shift every build's cells.
- **Threshold curves copied, never invented:** warrior's melee_hit shape,
  helper's requires_any shape, mage's spell_cast shape — per the
  no-new-pacing-formula convention.
- **Economy:** remedy/meal pricing + [Courier's Word] +1g ride the #92
  economy ledger pass; runner income itself uses the shipped 1–4g
  delivery bands. The 82g travel-sink flag (CHOICES #25) is partially
  answered by Runner/Courier income being travel-shaped.
- **Product locks:** opaque-until-sleep (no progress readouts anywhere in
  the new copy); stat grammar default (HP/MP/AP/damage fine, STR/DEX out
  of player text); all mp-costed skills grant max_mp — deliberate
  decision per class (witch kit is AP-only for exactly this reason).

## 7. Rollout waves (parallel-lane shaped, file ownership disjoint)

- **Wave A — data-only (no engine code):** [Cook]→[Chef]; [Scout]
  consolidation; [Runner]→[Courier] core (the 2-line counter bank is the
  only src touch); [Necromancer] combat core (bone_dart/deathbolt/
  detect_magic + Pisces chain); [Mage] L7 detect_magic; all reveal/brew
  props. Lanes split cleanly: classes.json+skills.json vs dialogue vs
  maps vs items.
- **Wave B — three bounded engine seams, one lane each:** blink verb
  (+blinked_past_danger); ward verb (+suppression+expiry); companion
  injection (+follower visual). Each ships with its skill(s), its QA
  loop script, and its windowed screenshot pass (wi-machine-playtest).
- **Wave C — taste/economy:** witch evolution content ([Greater
  Hearthward], hat sprite), [Signature Dish], [Courier's Word]
  mechanics, consolidation candidates pending canon checks ([Trader]×
  [Runner] line; [Bard] — Numbtongue attests it Vol 5, the moods/audio
  system is ready for song Skills; [Alchemist] once crafting exists;
  [Beast Tamer] once companion machinery generalizes from Animate Dead).

**Per-wave verification (wi-verifying-changes gates):**
`test_progression` (math pins), `test_content` (every gained_by
accomplishment produced somewhere — the new dialogue/prop producers
close this), `test_shipped_ids` (all new ids are pre-freeze and free
until the next cut), sim harness on combat deltas, one QA loop script
per new tree (model: class_evolution_loop + near_evolution-style
fixtures; assert the domain event AND the fight's pc.skills contains
the grant), dialogue-gate grep before moving ANY existing grant level
(we only add, so clean), icon drain into VISUAL-LOG (~10 new 16×16
icons: detect_magic, bone_dart, deathbolt, animate_dead, flash_step,
double_step, brew_remedy, hearthward_charm, advanced_cooking,
eagle_eyes — PixelLab pipeline, user-owned outputs).

## 8. Flagged decisions for user ruling

1. **Witch gender gate** — canon female-coded through Vol 7; proposal
   defaults to no gate + canon-liberty flag. Overrule?
2. **[Flash Step] home** — proposal puts it on [Necromancer] L7 (canon:
   it is Pisces' spell). Alternative: also/instead a high [Mage] grant via
   the same Pisces teaching beat. Combat half ships as a move burst
   (reuses move_pool_bonus); true in-combat teleport is a future resolver.
3. **Necromancer evolution parked** — accept aspiration-only, or
   commission an ORIGINAL-flagged evolution name now?
4. **Roster size** — 4 base + 1 consolidation + 1 mage grant in one
   arc is a big bite; natural cut line is Wave A alone (ships 3 classes,
   zero engine risk) with Wave B as its own milestone.
5. **[Eagle Eyes]** ships under an AMBIGUOUS-lean-PASS flag (wiki
   renumbering drift) — accept, or swap to an ORIGINAL name?

## Appendix — engine facts relied on (verified this session)

- Field dispatch: `src/core/field_skills.gd:33-100` ordered verb chain;
  `use_skill_field` faces one adjacent cell (`wi_game.gd:505-514`).
- Zero-cost seam: `requires_skill`+`on_skill_use` props route through
  `wi_game.gd:473-502` (same seam as interact; payload supports
  accomplishment/toast/gold/item/remove_item/requires_item + variant
  arrays); `visual_states.when.counter` drives counter-conditional
  visuals.
- Sneak/ambush: `_check_trigger_radius` (`wi_game.gd:279-301`) —
  suppression + `sneaked_past_danger` bank, dedup `danger:<id>`.
- Counters: `record_accomplishment` (`wi_game.gd:572-574`); combat
  tallies banked post-victory (`wi_game.gd:1509-1544`); `<element>_cast`
  and `<weapon>_skill_used` bank automatically off skill fields
  (`wi_combat.gd:739-742`) — `element: "death"` needs no code.
- Allies: fixed roster at `start_combat` (`wi_game.gd:1281-1293`),
  `allies`/`ally_requires`/`ally_hp_penalty`; no mid-fight spawn.
- Meals: `pending_meal` → damage/hp/damage_reduction mods
  (`wi_game.gd:1327-1331`); `well_fed` +2 hp_mod; `kind:"meal"` items.
- Hotbar: no sim cap; loadout via `loadout_toggle` (`wi_game.gd:688-696`).
- Travel: accomplishment-gated portals only, no skill hooks
  (`src/core/portals.gd`) — [Flash Step] deliberately does NOT touch
  inter-map travel.
