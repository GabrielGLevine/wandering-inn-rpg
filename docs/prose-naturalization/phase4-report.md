# Phase 4 — advisory distribution metrics — GH#397

**GENERATED** by `qa/scripts/extract_prose.py report --outdir docs/prose-naturalization` — seed 397, python 3.12.3, deterministic (a re-run on the same tree is byte-identical). Do not hand-edit.

> ## ADVISORY. NO METRIC HERE IS A GATE.
>
> The issue's Phase 4 is *"report-only metrics **before** considering any new hard gate"* and *"avoid turning advisory counts into a synonym-replacement game"*. Nothing in this file is wired into `ci_sweep.sh`, and the controller ruled sentence-length stdev **report-only with no published target**. Every regex here is a smoke detector; the cold read in Phase 5 is the gate.

**Honest denominators.** Every count below is split `touchable / protected / holdout`. Protected keeps and holdout strings CANNOT be edited (`verify-untouched` fails on a byte of drift), so folding them into a corpus rate would quietly move a target a later pass has no way to hit. Pins read from the frozen artifacts: **29 protected keeps, 229 holdout strings**.

---

## 1. Headline — the paper baseline for Phase 5

Touchable **narrator** strings only, because narrator-only is the ruled basis for the §6.4 anon target (inn lane's adopted reframing). Spoken strings get their own read in §4 and §6.

| region | touchable narrator n | anon 4-word | closer ≥2 | negation instances | worst file ending-shape | sentence-length stdev |
|---|--:|--:|--:|--:|---|--:|
| dialogue | 7 | 1 (14.3%) | 0 | 0 | — | 5.92 |
| dungeon | 44 | 1 (2.3%) | 3 | 2 | fact 86% (`dungeon_approach.json`) | 6.37 |
| floodplains | 71 | 2 (2.8%) | 0 | 0 | fact 53% (`floodplains.json`) | 6.41 |
| garden | 7 | 0 (0.0%) | 0 | 0 | motion 43% (`garden_sanctuary.json`) | 6.46 |
| inn | 56 | 2 (3.6%) | 0 | 0 | fact 54% (`inn_player_room.json`) | 5.68 |
| invrisil | 100 | 5 (5.0%) | 0 | 1 | fact 68% (`mercantile_alleys.json`) | 7.02 |
| liscor | 63 | 2 (3.2%) | 0 | 0 | fact 75% (`barracks.json`) | 5.89 |
| pallass | 116 | 1 (0.9%) | 1 | 1 | fact 55% (`pallass_forge.json`) | 6.20 |
| riverfarm | 116 | 5 (4.3%) | 0 | 1 | fact 55% (`witch_hollow.json`) | 4.94 |
| ruin | 34 | 0 (0.0%) | 0 | 0 | fact 64% (`ruin_surface.json`) | 5.67 |
| sewers | 40 | 0 (0.0%) | 1 | 1 | fact 67% (`deep_tunnels.json`) | 5.16 |
| **maps (all)** | 647 | 18 (2.8%) | 5 | 6 | fact 86% (`dungeon_approach.json`) | 6.13 |
| **dialogue (all)** | 7 | 1 (14.3%) | 0 | 0 | — | 5.92 |
| **corpus (all)** | 654 | 19 (2.9%) | 5 | 6 | fact 86% (`dungeon_approach.json`) | 6.13 |


`anon 4-word` = strings containing `someone` / `somebody` / `whoever` / `whatever` (bible §6's motive words). `closer ≥2` = button smoke score ≥2/5. `negation instances` counts SHAPES, not strings, so one string stacking three shapes counts three. `worst file ending-shape` is the region's most concentrated file on the §9.2 measure. Stdev is pooled over the region's touchable narrator sentences and has **no target**.

---

## 2. Narrator vs spoken — how the split is derived

SPOKEN = the words are a character's own (node line, player option, option-bank line, map ambient `dialogue[].text`, `friendly_line`). NARRATOR = everything else, including option-effect toasts and `copy` documents. Transport is irrelevant: `friendly_line` ships as a toast and is still the NPC talking.

| corpus | voice | renderer | strings |
|---|---|---|--:|
| dialogue | narrator | `effect-toast` | 7 |
| dialogue | spoken | `bank-line` | 22 |
| dialogue | spoken | `node-line` | 566 |
| dialogue | spoken | `player-option` | 878 |
| maps | narrator | `diegetic-document` | 5 |
| maps | narrator | `narration` | 768 |
| maps | spoken | `ambient-speech` | 63 |
| maps | spoken | `npc-friendly-line` | 19 |

`copy` is the one honest wobble: a board notice is written matter rather than anybody's speech, and it reaches the player inside a code-built graph whose speaker is the prop's display_name (`wi_game.gd:1539-1563`). It is counted narrator-side and is broken out as `diegetic-document` above so a reader can subtract it.

---

## 3. Negation/correction and closer density

Bible §7: corpus ceiling **8** negation instances in map prose (from 29 pre-pass), at most one per file, zero in functional register. §2/§5: closers are the scarce register.

| region | narrator n (touch) | neg instances (touch) | neg strings | stacked ≥2 | closer ≥2 | closer ≥3 | neg in protected+holdout |
|---|--:|--:|--:|--:|--:|--:|--:|
| dialogue | 7 | 0 | 0 | 0 | 0 | 0 | 0 |
| dungeon | 44 | 2 | 2 | 0 | 3 | 1 | 1 |
| floodplains | 71 | 0 | 0 | 0 | 0 | 0 | 0 |
| garden | 7 | 0 | 0 | 0 | 0 | 0 | 1 |
| inn | 56 | 0 | 0 | 0 | 0 | 0 | 0 |
| invrisil | 100 | 1 | 1 | 0 | 0 | 0 | 0 |
| liscor | 63 | 0 | 0 | 0 | 0 | 0 | 3 |
| pallass | 116 | 1 | 1 | 0 | 1 | 0 | 0 |
| riverfarm | 116 | 1 | 1 | 0 | 0 | 0 | 1 |
| ruin | 34 | 0 | 0 | 0 | 0 | 0 | 1 |
| sewers | 40 | 1 | 1 | 0 | 1 | 0 | 0 |
| **maps (all)** | 647 | 6 | 6 | 0 | 5 | 1 | 7 |
| **dialogue (all)** | 7 | 0 | 0 | 0 | 0 | 0 | 0 |
| **corpus (all)** | 654 | 6 | 6 | 0 | 5 | 1 | 7 |

The last column is the pre-explained residue: negation inside a protected keep or a holdout string is ruled or frozen, and a later pass cannot touch it. §10 lists each one.

---

## 4. Anonymous-agent inference — reported four ways

empty-regions item 5, ADOPTED: the four-word figure is the §6.4 metric; report both. The narrator/spoken split is the inn lane's adopted reframing: narrator-only is the target basis, so a region is never churned chasing its patrons' speech.

- **motive set (4)**: someone, somebody, whoever, whatever — the words that invent an absent agent; this is the §6.4 metric.
- **present indefinites (3)**: something, nobody, anyone — they invent nobody, which is the point of the split.
- bible §6 rule 4, ADVISORY: corpus ≤12%, unpeopled regions (garden/dungeon/ruin/sewers) ≤15%, populated ≤10%. Measured on TOUCHABLE NARRATOR strings.

| region | NARRATOR touch n | 4-word | 7-word | SPOKEN touch n | 4-word | 7-word | untouchable 4-word (N/S) |
|---|--:|--:|--:|--:|--:|--:|--:|
| dialogue | 7 | 1 (14%) | 1 (14%) | 1347 | 77 (6%) | 161 (12%) | 0/16 |
| dungeon | 44 | 1 (2%) | 5 (11%) | 1 | 0 (0%) | 0 (0%) | 4/0 |
| floodplains | 71 | 2 (3%) | 5 (7%) | 2 | 1 (50%) | 1 (50%) | 4/0 |
| garden | 7 | 0 (0%) | 0 (0%) | 0 | 0 (—) | 0 (—) | 3/0 |
| inn | 56 | 2 (4%) | 5 (9%) | 21 | 0 (0%) | 5 (24%) | 3/0 |
| invrisil | 100 | 5 (5%) | 10 (10%) | 10 | 0 (0%) | 0 (0%) | 2/0 |
| liscor | 63 | 2 (3%) | 7 (11%) | 18 | 0 (0%) | 1 (6%) | 1/0 |
| pallass | 116 | 1 (1%) | 12 (10%) | 8 | 1 (12%) | 1 (12%) | 2/0 |
| riverfarm | 116 | 5 (4%) | 15 (13%) | 4 | 0 (0%) | 0 (0%) | 2/0 |
| ruin | 34 | 0 (0%) | 1 (3%) | 3 | 0 (0%) | 0 (0%) | 2/0 |
| sewers | 40 | 0 (0%) | 7 (18%) | 2 | 0 (0%) | 0 (0%) | 1/0 |
| **maps (all)** | 647 | 18 (3%) | 67 (10%) | 69 | 2 (3%) | 8 (12%) | 24/0 |
| **dialogue (all)** | 7 | 1 (14%) | 1 (14%) | 1347 | 77 (6%) | 161 (12%) | 0/16 |
| **corpus (all)** | 654 | 19 (3%) | 68 (10%) | 1416 | 79 (6%) | 169 (12%) | 24/16 |

---

## 5. `which from X is Y` / `the way X does` / `the X is the X`

bible §7 'other shared shapes': target ZERO (12 instances in map prose pre-pass, 1 in dialogue).

**Gap fix.** RE_WHICH_FROM now allows a 1-3 word noun phrase between the preposition and the copula. 'which from a razorbeak is an invitation' was invisible to the one-word pattern.

**Counted: 4.**

| id | region | voice | status | shapes | string |
|---|---|---|---|---|---|
| `pallass_den_keeper.json:$.nodes.hub.text` | dialogue | spoken | touchable | noun_repeat×1 | Come in, mind the small ones. If you're buying, the shelf is the shelf. If you're official, the counter's there, and it  |
| `floodplains/floodplains.json:$.entities[26].skill_hint_toast` | floodplains | narrator | holdout | which_from×1 | It goes still when you crouch, which from a razorbeak is an invitation. Make the offer properly. |
| `invrisil/adventurers_rest.json:$.entities[1].observe` | invrisil | narrator | touchable | which_from×1 | He keeps the ledger of who is owed a table rather than who is owed money, which in this house is the more delicate book. |
| `liscor/street.json:$.entities[3].observe` | liscor | narrator | holdout | the_way_x×1 | An Antinium of Liscor's Watch — dark chitin, four arms, antennae, twin swords worn at the hips like a closed argument. H |

**Near misses — NOT counted: 2.** NOT counted in the metric: a longer noun phrase (4-6 words) or a non-copular verb (means / reads / amounts / makes / becomes / signifies). Listed so a widened regex is a controller decision rather than a silent one.

| id | status | match | string |
|---|---|---|---|
| `invrisil_seal_broker.json:$.nodes.table.text_variants[0].text` | touchable | `which in this city means` | The block is gone off my table and the cloth is sitting there with nothing on it, which in this city means nob |
| `pisces_magic.json:$.nodes.lesson_light.text` | touchable | `which for a man of my reputation is` | [Light]. Always [Light]. It is cheap and it is obedient. When it fails, it merely goes out — no fire, no inque |

---

## 6. Per-speaker motif-word concentration (dialogue)

Per speaker, over that speaker's NODE lines only. Player option rows are excluded (an option row's `speaker` is the NPC whose node offers it, so counting them would file the player's lines under whoever they are talking to), and the 22 `text_bank` rows are excluded with them (the gate's speaker_for() returns its file-level 'narrator' fallback for a bank path). `top` is the single most frequent CONTENT word and its share of the speaker's content words. `issue_anchor` is that speaker's problem-4 anchor list from the issue, expanded to inflections only.

The issue states the Pallass anchor about the CITY ('Pallass generally: standards, forms, measurements, queues'), so it is scoped to speakers appearing in a `pallass*` graph rather than to a person.

| speaker | node lines | content words | top content word | 2nd | 3rd | issue anchor share | pallass anchor share |
|---|--:|--:|---|---|---|--:|--:|
| Pisces | 61 | 1099 | `read` 0.9% | `city` 0.8% | `cut` 0.8% | 6/61 (10%) | — |
| Olesm | 41 | 701 | `board` 1.3% | `door` 1.0% | `thank` 1.0% | 20/41 (49%) | — |
| Krshia | 28 | 327 | `stall` 2.4% | `ask` 1.5% | `crate` 1.5% | — | — |
| Wilovan | 27 | 471 | `man` 3.4% | `hat` 2.1% | `door` 1.3% | 12/27 (44%) | — |
| Zevara | 26 | 389 | `watch` 2.1% | `desk` 1.3% | `file` 1.3% | 12/26 (46%) | — |
| Erin | 24 | 275 | `selys` 1.8% | `cellar` 1.5% | `guild` 1.5% | — | — |
| Rags | 23 | 106 | `ate` 2.8% | `camp` 2.8% | `doors` 2.8% | — | — |
| Eloise | 20 | 251 | `craft` 2.4% | `sit` 2.4% | `kettle` 2.0% | — | — |
| A Shepherd | 19 | 214 | `line` 3.7% | `deer` 1.4% | `every` 1.4% | — | — |
| Lyonette | 19 | 250 | `line` 3.6% | `lyonette` 2.4% | `room` 2.4% | — | — |
| Relc | 19 | 275 | `spear` 2.9% | `version` 1.8% | `gate` 1.5% | — | — |
| Selys | 17 | 208 | `fee` 2.4% | `desk` 1.9% | `anything` 1.4% | — | — |
| A Lady with a Ring Box | 16 | 265 | `hand` 2.3% | `people` 1.9% | `stone` 1.9% | — | — |
| Cups | 15 | 273 | `cup` 2.2% | `coyle` 1.8% | `hat` 1.8% | — | — |
| Forge-Tier Smith | 15 | 178 | `slab` 2.8% | `bench` 2.2% | `read` 2.2% | — | 3/15 (20%) |
| Former Headman | 15 | 207 | `count` 2.9% | `hollow` 2.4% | `village` 2.4% | — | — |
| Lift Attendant | 13 | 203 | `bell` 3.9% | `quarter` 3.9% | `cage` 2.5% | — | 3/13 (23%) |
| Grimalkin | 12 | 192 | `file` 2.1% | `measure` 2.1% | `numbers` 2.1% | — | 4/12 (33%) |
| A Man with a Rented Table | 10 | 143 | `block` 3.5% | `nobody` 2.8% | `nothing` 2.8% | — | — |
| Ceria | 10 | 153 | `camp` 2.0% | `floodplains` 2.0% | `four` 2.0% | — | — |
| Forge-Tier Clerk | 10 | 130 | `office` 4.6% | `posted` 3.8% | `filed` 3.1% | — | 0/10 (0%) |
| Hedault | 10 | 214 | `set` 2.3% | `ward` 2.3% | `cloth` 1.9% | 4/10 (40%) | — |
| Tier Clerk | 10 | 99 | `business` 6.1% | `state` 6.1% | `entry` 4.0% | — | 1/10 (10%) |
| Master Coyle | 9 | 160 | `consultant` 1.9% | `paid` 1.9% | `price` 1.9% | 2/9 (22%) | — |
| A Scribe by the Hour | 8 | 97 | `hour` 4.1% | `blotter` 3.1% | `man` 3.1% | — | — |
| Sergeant Ashgrave | 8 | 99 | `next` 4.0% | `counted` 3.0% | `pell` 3.0% | — | — |

Speakers with fewer than 8 node lines are omitted from the table (they are in the JSON) unless the issue anchors them: a top-word share over a handful of lines is noise.

---

## 7. Fraction of map objects carrying inferred history or thematic interpretation

An OBJECT is one `$.entities[i]` in one map file, counted when it carries at least one narrator prose string. It 'carries inference' when any of its narrator strings has a four-word anonymous agent (inferred history) or a button smoke score >=2 (thematic interpretation). 22 narrator strings hang off the MAP rather than an entity (`interior_flavor`, `arrival_toasts[].text`) and are excluded from the denominator.

| region | objects | carry inference | of which trigger is touchable | by 4-word anon | by closer ≥2 |
|---|--:|--:|--:|--:|--:|
| dungeon | 22 | 9 (41%) | 4 (18%) | 4 | 5 |
| floodplains | 32 | 5 (16%) | 2 (6%) | 4 | 2 |
| garden | 6 | 3 (50%) | 0 (0%) | 3 | 0 |
| inn | 26 | 5 (19%) | 2 (8%) | 5 | 0 |
| invrisil | 78 | 6 (8%) | 3 (4%) | 4 | 2 |
| liscor | 33 | 3 (9%) | 2 (6%) | 2 | 1 |
| pallass | 57 | 7 (12%) | 2 (4%) | 3 | 4 |
| riverfarm | 73 | 8 (11%) | 5 (7%) | 7 | 1 |
| ruin | 16 | 3 (19%) | 0 (0%) | 2 | 1 |
| sewers | 19 | 2 (10%) | 1 (5%) | 1 | 1 |
| **maps (all)** | 362 | 51 (14%) | 21 (6%) | 35 | 17 |

---

## 8. Ending shapes, adjacency, and sentence-length spread

**Taxonomy:** `fact`, `motion`, `interruption`, `unresolved`, `instruction`, `absence`.

Ordered proxy over the LAST sentence: interruption (terminal dash / ellipsis / '!') > unresolved (terminal '?') > instruction (imperative first word, or the 'down you go' idiom) > absence (an absence token: nobody/nothing/none/never/empty/gone/missing/silence/silent/unanswered/without/not/no) > motion (a motion verb not preceded by a copula) > fact (DEFAULT, therefore a catch-all).

> **Known divergence from §9's hand labels.** §9's own table labels 'Nobody came back to make the ninety-third.' a FACT ending; this proxy calls it ABSENCE because `nobody` is an absence token — and §5 itself describes mercantile_alleys' 'nobody left standing beside it' as ending on an absence. The bible's labels are hand judgements; the proxy is consistent, which is what a concentration measure needs. It is a smoke detector, not a verdict.

### 8.1 Per-file distribution (§9.2: 40% advisory, loosen to 50%)

§9.2 scopes the per-file cap to SCENIC + FUNCTIONAL strings, so that is the scope here; narrator only.

| file | touchable n | top shape | top % | distribution | stdev (touchable) |
|---|--:|---|--:|---|--:|
| `dungeon/dungeon_approach.json` | 7 | fact | 86% ⚠ | absence 1 · fact 6 | 3.97 |
| `dungeon/seal_vault.json` | 3 | fact | 67% ⚠ | absence 1 · fact 2 | 4.65 |
| `dungeon/trapped_halls.json` | 29 | fact | 48% | absence 9 · fact 14 · instruction 1 · motion 5 | 5.79 |
| `floodplains/floodplains.json` | 55 | fact | 53% ⚠ | absence 10 · fact 29 · instruction 2 · motion 14 | 6.07 |
| `floodplains/rags_camp.json` | 12 | fact | 42% | absence 4 · fact 5 · motion 3 | 6.79 |
| `garden/garden_sanctuary.json` | 7 | motion | 43% | absence 2 · fact 2 · motion 3 | 6.46 |
| `inn/inn.json` | 30 | fact | 43% | absence 9 · fact 13 · motion 8 | 5.52 |
| `inn/inn_player_room.json` | 11 | fact | 54% ⚠ | absence 1 · fact 6 · instruction 1 · motion 3 | 5.88 |
| `inn/inn_upstairs.json` | 9 | absence | 33% | absence 3 · fact 3 · motion 3 | 4.01 |
| `invrisil/adventurers_rest.json` | 11 | absence | 46% | absence 5 · fact 4 · motion 2 | 6.45 |
| `invrisil/brothers_parlor.json` | 16 | fact | 56% ⚠ | absence 3 · fact 9 · instruction 1 · motion 3 | 6.61 |
| `invrisil/invrisil_boulevard.json` | 17 | motion | 47% | absence 2 · fact 6 · instruction 1 · motion 8 | 7.90 |
| `invrisil/mercantile_alleys.json` | 22 | fact | 68% ⚠ | absence 5 · fact 15 · instruction 1 · motion 1 | 6.51 |
| `invrisil/stationer.json` | 8 | absence | 38% | absence 3 · fact 3 · instruction 1 · motion 1 | 5.58 |
| `liscor/barracks.json` | 12 | fact | 75% ⚠ | absence 2 · fact 9 · motion 1 | 4.64 |
| `liscor/guild.json` | 12 | fact | 67% ⚠ | absence 1 · fact 8 · instruction 1 · motion 2 | 7.15 |
| `liscor/runners_guild.json` | 15 | fact | 53% ⚠ | absence 2 · fact 8 · motion 5 | 5.29 |
| `liscor/street.json` | 15 | fact | 47% | absence 4 · fact 7 · motion 4 | 5.40 |
| `pallass/pallass_den_shop.json` | 12 | absence | 42% | absence 5 · fact 5 · motion 2 | 7.17 |
| `pallass/pallass_forge.json` | 31 | fact | 55% ⚠ | absence 7 · fact 17 · instruction 1 · motion 6 | 5.57 |
| `pallass/pallass_forge_hall.json` | 16 | fact | 44% | absence 5 · fact 7 · motion 4 | 6.46 |
| `pallass/pallass_market.json` | 52 | fact | 54% ⚠ | absence 12 · fact 28 · motion 12 | 6.11 |
| `riverfarm/riverfarm_longhouse.json` | 4 | absence | 50% | absence 2 · fact 1 · motion 1 | 2.81 |
| `riverfarm/riverfarm_mill.json` | 10 | fact | 50% | absence 1 · fact 5 · motion 4 | 6.11 |
| `riverfarm/riverfarm_village.json` | 46 | fact | 52% ⚠ | absence 9 · fact 24 · instruction 1 · motion 12 | 4.64 |
| `riverfarm/witch_hollow.json` | 40 | fact | 55% ⚠ | absence 9 · fact 22 · instruction 4 · motion 5 | 4.49 |
| `riverfarm/witch_hut.json` | 11 | fact | 46% | absence 4 · fact 5 · motion 2 | 3.31 |
| `ruin/ruin_surface.json` | 28 | fact | 64% ⚠ | absence 8 · fact 18 · motion 2 | 5.44 |
| `sewers/deep_tunnels.json` | 15 | fact | 67% ⚠ | absence 3 · fact 10 · motion 2 | 4.37 |
| `sewers/sewers.json` | 25 | fact | 52% ⚠ | absence 5 · fact 13 · motion 7 | 5.56 |

**28 of 30** scored files exceed 40%; **16** exceed the loosened 50%. §9.2 anticipated exactly this and ruled the number advisory, to be loosened rather than churned against — and the reason is visible in the distributions: `fact` is the proxy's DEFAULT arm, so a large `fact` share means "declarative, and not one of the other five", which is what a de-buttoned corpus is supposed to look like. Read the ⚠ rows as *look here in the cold read*, never as *rewrite to hit a number*.

### 8.2 Adjacent-entity ending-shape collisions

§9 rule 4, RULED: 'adjacent' means ENTITY-LIST ORDER. One shape per entity: its `observe` if it has one, else its first narrator string in document order. Grid proximity stays a cold-read lens and is deliberately not computed.

| file | entities scored | collisions | % of pairs | string-level pairs | string-level collisions |
|---|--:|--:|--:|--:|--:|
| `dungeon/dungeon_approach.json` | 4 | 1 | 33% | 9 | 4 |
| `dungeon/seal_vault.json` | 3 | 0 | 0% | 4 | 0 |
| `dungeon/trapped_halls.json` | 15 | 7 | 50% | 44 | 16 |
| `floodplains/floodplains.json` | 24 | 8 | 35% | 69 | 19 |
| `floodplains/rags_camp.json` | 8 | 1 | 14% | 16 | 8 |
| `garden/garden_sanctuary.json` | 6 | 0 | 0% | 11 | 3 |
| `inn/inn.json` | 16 | 6 | 40% | 39 | 13 |
| `inn/inn_player_room.json` | 6 | 2 | 40% | 13 | 4 |
| `inn/inn_upstairs.json` | 4 | 1 | 33% | 10 | 3 |
| `invrisil/adventurers_rest.json` | 12 | 1 | 9% | 15 | 4 |
| `invrisil/brothers_parlor.json` | 20 | 10 | 53% | 23 | 11 |
| `invrisil/invrisil_boulevard.json` | 22 | 4 | 19% | 28 | 4 |
| `invrisil/mercantile_alleys.json` | 14 | 7 | 54% | 31 | 16 |
| `invrisil/stationer.json` | 10 | 2 | 22% | 9 | 2 |
| `liscor/barracks.json` | 7 | 5 | 83% | 13 | 8 |
| `liscor/guild.json` | 4 | 2 | 67% | 13 | 5 |
| `liscor/runners_guild.json` | 6 | 0 | 0% | 16 | 5 |
| `liscor/street.json` | 16 | 8 | 53% | 29 | 10 |
| `pallass/pallass_den_shop.json` | 7 | 2 | 33% | 17 | 8 |
| `pallass/pallass_forge.json` | 19 | 5 | 28% | 39 | 10 |
| `pallass/pallass_forge_hall.json` | 8 | 4 | 57% | 17 | 4 |
| `pallass/pallass_market.json` | 23 | 10 | 46% | 62 | 24 |
| `riverfarm/riverfarm_longhouse.json` | 2 | 0 | 0% | 3 | 1 |
| `riverfarm/riverfarm_mill.json` | 6 | 3 | 60% | 12 | 6 |
| `riverfarm/riverfarm_village.json` | 35 | 24 | 71% | 62 | 24 |
| `riverfarm/witch_hollow.json` | 25 | 14 | 58% | 45 | 25 |
| `riverfarm/witch_hut.json` | 5 | 2 | 50% | 11 | 2 |
| `ruin/ruin_surface.json` | 16 | 7 | 47% | 39 | 19 |
| `sewers/deep_tunnels.json` | 7 | 3 | 50% | 16 | 4 |
| `sewers/sewers.json` | 12 | 3 | 27% | 28 | 8 |

### 8.3 Six shapes per region (§9.3: at least 4)

| region | shapes present | n | meets ≥4 |
|---|---|--:|---|
| dialogue | absence, fact, instruction, motion | 4 | yes |
| dungeon | absence, fact, instruction, motion | 4 | yes |
| floodplains | absence, fact, instruction, motion | 4 | yes |
| garden | absence, fact, motion | 3 | NO |
| inn | absence, fact, instruction, motion | 4 | yes |
| invrisil | absence, fact, instruction, motion | 4 | yes |
| liscor | absence, fact, instruction, motion | 4 | yes |
| pallass | absence, fact, instruction, motion | 4 | yes |
| riverfarm | absence, fact, instruction, motion | 4 | yes |
| ruin | absence, fact, motion | 3 | NO |
| sewers | absence, fact, motion | 3 | NO |

---

## 9. CAPS — lettering context vs bare

§8 RULED: diegetic lettering PERMITTED, CAPS-as-emphasis 0, with a mechanical proxy and judgement as the arbiter. The bare list is the work queue.

The 'in a … hand' form is new this phase (pallass petition item 4): lettering attributed by the handwriting that made it. `chalked`, `stamped` and `stencilled` were already covered. The cue that fired is printed for every row so a wrong cue is auditable.

**15 lettering / 1 bare.**

| class | cue | id | status | string |
|---|---|---|---|---|
| BARE | `—` | `dungeon/trapped_halls.json:$.entities[8].skill_uses.detect_magic.variants[0].toast` | holdout | [Detect Magic] — The ward opens under your sight and does not stop opening. It is not holding anything shut. I |
| lettering | `painted` | `floodplains/floodplains.json:$.entities[3].toast` | touchable | A hand-painted board, letters gone bold where they were traced twice: THE WANDERING INN — NO KILLING GOBLINS. |
| lettering | `sign` | `invrisil/invrisil_boulevard.json:$.entities[12].toast` | touchable | You circle the block twice before it clicks. The modest COYLE AND SONS sign faces the boulevard; the two wagon |
| lettering | `board` | `invrisil/invrisil_boulevard.json:$.entities[19].observe` | touchable | A modest hanging board, burgundy and brass, lettered COYLE AND SONS in a hand that cost more than the paint. T |
| lettering | `lettered` | `invrisil/mercantile_alleys.json:$.entities[11].observe` | touchable | Shelves of labelled jars, a rented burner, and a hand-lettered card: WORKING SPACE, BY THE HOUR, NO CREDIT. |
| lettering | `field:copy` | `liscor/guild.json:$.entities[2].board_rumors[0].copy` | touchable | TRAVELER'S NOTE, pinned crooked. Village called Riverfarm, downriver a fair walk, farming folk, growing fast u |
| lettering | `field:copy` | `liscor/guild.json:$.entities[2].board_rumors[1].copy` | protected | A LETTER, sealed in wax gone slightly soft from handling, addressed to no one by name. Inside: impeccable hand |
| lettering | `field:copy` | `liscor/guild.json:$.entities[2].board_rumors[2].copy` | touchable | A WATCH NOTICE, freshly pinned. The reopened gallery under the old seal is to be surveyed properly before the  |
| lettering | `field:copy` | `liscor/guild.json:$.entities[2].board_rumors[3].copy` | touchable | WATCH NOTICE, pinned by a hand in a hurry. Recruit Pell missed second muster running. Ashgrave has it logged a |
| lettering | `field:copy` | `liscor/guild.json:$.entities[2].board_rumors[4].copy` | touchable | A SCRAP OF PARCHMENT, tacked low, easy to miss. 'LOST: one backup warhammer, plain steel, no love lost between |
| lettering | `board` | `liscor/runners_guild.json:$.entities[2].second_visit_toast` | touchable | THE DELIVERY BOARD. Your slip's still logged at the counter. |
| lettering | `board` | `liscor/runners_guild.json:$.entities[2].toast` | touchable | THE DELIVERY BOARD. Legs and ledgers. Gold by distance, paid on the mark, same-waking terms. Slips at the coun |
| lettering | `chalked` | `pallass/pallass_forge.json:$.entities[17].toast` | touchable | One crate of tin, den shop, market tier. Logged three cycles running and carried none of them. Beside it, chal |
| lettering | `stencilled` | `pallass/pallass_forge.json:$.entities[4].locked_toast` | touchable | The brass gate is locked. A stencilled plate: PERMIT AND STAMP REQUIRED. The clerk's window is open. |
| lettering | `writing` | `pallass/pallass_forge_hall.json:$.entities[5].toast` | protected | Forty-one attempts. Under the last one, in smaller writing than the rest: TRY THE OTHER WAY ROUND. |
| lettering | `stencilled` | `pallass/pallass_market.json:$.entities[12].locked_toast` | touchable | The brass gate is locked. A stencilled plate: PERMIT AND STAMP REQUIRED. The clerk's window is open. |

---

## 10. Granted-exception register — read this before acting on any count above

Printed INLINE so a counter that fires on a granted keep is pre-explained: a keep OUTRANKS the rule it trips (bible guard §10.2) and CONSUMES the relevant budget. A count in this report is never an instruction to edit one of these.

### 10.1 Protected keeps that FIRE a counter (18 of 29)

| id | region | pinned to | counters fired | why (head) |
|---|---|---|---|---|
| `relc_descent.json:$.nodes.join.text` | dialogue | baseline | anon_indef 1 | issue-counterevidence: Relc's deep-tunnel joke, voice-distinctive |
| `riverfarm_villager.json:$.nodes.hub.text` | dialogue | baseline | neg_correction 1 | 'The hens are laying again. No. That weren't your question.' A speaker losing and recovering his own thread. Ending shape = interruption. The corpus needs more of this and the rubr |
| `riverfarm_villager.json:$.nodes.remember.text` | dialogue | baseline | neg_correction 1, closer 2 | 'I should be angry. I keep meaning to be angry.' Smoke score 2 (short punch after long setup) but the repeat is a man failing to finish a feeling -- the T1 register working exactly |
| `dungeon/trapped_halls.json:$.entities[8].skill_uses.detect_magic.toast` | dungeon | post-pass | anon_indef 1 | The simile is the diagnostic. 'It does not flare and settle the way a bound ward should. It holds one low steady note, like a breath nobody has to let out' is how the player learns |
| `dungeon/trapped_halls.json:$.entities[8].skill_uses.detect_magic.variants[1].toast` | dungeon | baseline | anon_indef 1, 5 sentences (§1.4 ceiling 2) | GRANTED as a §1.4 exception at 5 sentences (ceiling 2). Two independent grounds. (a) The prop's byte-frozen holdout sibling at $.entities[8].skill_uses.detect_magic.variants[0].toa |
| `dungeon/trapped_halls.json:$.entities[8].skill_uses.observe.variants[0].toast` | dungeon | post-pass | 4 sentences (§1.4 ceiling 2) | GRANTED at 4 sentences (ceiling 2). The interval-and-wear comparison is the reveal's proof -- same hand, same fixed interval as the pantry frame, worn deeper therefore older -- and |
| `floodplains/floodplains.json:$.entities[24].locked_toast` | floodplains | baseline | 3 sentences (§1.4 ceiling 2) | Three sentences against the functional ceiling of two (§1.4, which loosens only by petition with the string in hand -- this is that petition). The middle sentence is TWO WORDS: "Fa |
| `floodplains/rags_camp.json:$.entities[4].variants[0].toast` | floodplains | baseline | anon_indef 2 | The terminal beat of the camp's repeatable-work chain, and the only string in either map file where the goblins register the player as one of theirs. The inference is present behav |
| `garden/garden_sanctuary.json:$.entities[2].observe` | garden | baseline | neg_correction 1, anon_motive 1 | 'a sky that isn't real. It's made up with clean linen anyway, like that settles the argument.' Earned: the absurdity is physically present in the scene, and the closer is dry rathe |
| `garden/garden_sanctuary.json:$.entities[4].visual_states[0].observe` | garden | baseline | 3 sentences (§1.4 ceiling 2) | the war-memorial plinth: 'Liscor sealed the dark for good, once the warren was cleared -- masonry over memory, and no one asked for thanks. This is as close as the hill gets to giv |
| `liscor/guild.json:$.entities[2].board_rumors[1].copy` | liscor | baseline | 5 sentences (§1.4 ceiling 2) | GRANTED PETITION (lane-raised, controller-granted) -- DIEGETIC-DOCUMENT EXCEPTION. A board_rumors 'copy' string is not authorial narration; it is a physical document the player is  |
| `liscor/runners_guild.json:$.entities[3].observe` | liscor | baseline | 3 sentences (§1.4 ceiling 2) | GRANTED PETITION (lane-raised, controller-granted). Character-bearing register (bible section 3): a present, visible person, observed. 'Not asleep. Not far from it.' is keep-criter |
| `liscor/street.json:$.entities[11].observe` | liscor | post-pass | neg_correction 1 | SECTION 7 NEGATION KEEP + SECTION 7.3 FILE-CEILING EXCEPTION, CONTROLLER-GRANTED. The negation is MID-SENTENCE ('watches hands, not faces'), which section 7.4 rules is 'far less vi |
| `liscor/street.json:$.entities[12].observe` | liscor | post-pass | neg_correction 2 | SECTION 7 NEGATION KEEP -- keep-criterion-as-function, ratified verbatim in bible section 7. A barred grate in a city street actively invites the assumption that it is locked, and  |
| `pallass/pallass_den_shop.json:$.entities[5].toast` | pallass | baseline | anon_indef 1, closer 2 | 'resumes an argument you cannot follow about whose turn it is.' Smoke score 2 and an anonymous agent, so the tooling flags it -- and the tooling is wrong here. The inference is abo |
| `pallass/pallass_forge.json:$.entities[14].variants[0].toast` | pallass | baseline | 3 sentences (§1.4 ceiling 2) | The payoff of the region's repeatable-work chain, gated at pallass_fetches_run 5 — the player earned it by running the errand five times. "She wouldn't." is a two-word closer, and  |
| `pallass/pallass_market.json:$.interior_flavor[1]` | pallass | baseline | anon_indef 1 | An empty-cell flavour line that characterises the whole city in one observed action, with a real present person doing it — the §6 rule-1 ideal (an action the evidence shows, no mot |
| `ruin/ruin_surface.json:$.entities[16].observe` | ruin | baseline | anon_indef 1 | The work is the survey discipline (driven at intervals, string, chalk numbers on every stake) and then the line stopping dead at the court mouth -- information the player acts on,  |

### 10.2 Lane petitions ruled by the controller

| source | kind | file · field | sections | ground (head) |
|---|---|---|---|---|
| `empty-regions.json` | PEAK | `ruin/ruin_surface.json` · `$.entities[11].observe` | §6 | Present-behaviour characterisation of a person who is actually on stage. The armour stacked in the order it goes back on and the plank tested every single pass are observed repeat  |
| `empty-regions.json` | PEAK | `ruin/ruin_surface.json` · `$.entities[16].observe` | §6 | The work is the survey discipline (driven at intervals, string, chalk numbers on every stake) and then the line stopping dead at the court mouth -- information the player acts on,  |
| `empty-regions.json` | PEAK | `dungeon/trapped_halls.json` · `$.entities[14].observe` | — | The bible citation is binding here, not decorative: 'Dropped stone comes back as a sound and not much of one' IS the depth measurement -- zero inference, zero agent, and it is the  |
| `empty-regions.json` | PEAK | `dungeon/trapped_halls.json` · `$.entities[8].skill_uses.detect_magic.toast` | — | The simile is the diagnostic. 'It does not flare and settle the way a bound ward should. It holds one low steady note, like a breath nobody has to let out' is how the player learns |
| `empty-regions.json` | LENGTH-EXCEPTION §1.4 | `dungeon/trapped_halls.json` · `$.entities[8].skill_uses.detect_magic.variants[1].toast` | §1.4 | GRANTED as a §1.4 exception at 5 sentences (ceiling 2). Two independent grounds. (a) The prop's byte-frozen holdout sibling at $.entities[8].skill_uses.detect_magic.variants[0].toa |
| `empty-regions.json` | LENGTH-EXCEPTION §1.4 | `dungeon/trapped_halls.json` · `$.entities[8].skill_uses.observe.variants[0].toast` | — | GRANTED at 4 sentences (ceiling 2). The interval-and-wear comparison is the reveal's proof -- same hand, same fixed interval as the pantry frame, worn deeper therefore older -- and |
| `floodplains-garden.json` | PEAK | `floodplains/rags_camp.json` · `$.entities[4].variants[0].toast` | §6 | The terminal beat of the camp's repeatable-work chain, and the only string in either map file where the goblins register the player as one of theirs. The inference is present behav |
| `floodplains-garden.json` | LENGTH-EXCEPTION §1.4 | `floodplains/floodplains.json` · `$.entities[24].locked_toast` | §1.4 | Three sentences against the functional ceiling of two (§1.4, which loosens only by petition with the string in hand -- this is that petition). The middle sentence is TWO WORDS: "Fa |
| `floodplains-garden.json` | RECORDED -- NOT FIXED | `floodplains/floodplains.json` · `$.entities[26].skill_hint_toast` | — | "which from X is Y" is a corpus-wide narrator template. This is the fg lane's only instance, it sits in the holdout, and it is therefore a hard floor: the lane's which-from count c |
| `liscor.json` | RULED KEEP | `liscor/street.json` · `$.entities[12].observe` | §7 | SECTION 7 NEGATION KEEP -- keep-criterion-as-function, ratified verbatim in bible section 7. A barred grate in a city street actively invites the assumption that it is locked, and  |
| `liscor.json` | RULED KEEP -- file-ceiling exception, controller-granted | `liscor/street.json` · `$.entities[11].observe` | §7, §7.3 | SECTION 7 NEGATION KEEP + SECTION 7.3 FILE-CEILING EXCEPTION, CONTROLLER-GRANTED. The negation is MID-SENTENCE ('watches hands, not faces'), which section 7.4 rules is 'far less vi |
| `liscor.json` | GRANTED | `liscor/runners_guild.json` · `$.entities[3].observe` | §7, §7.3 | GRANTED PETITION (lane-raised, controller-granted). Character-bearing register (bible section 3): a present, visible person, observed. 'Not asleep. Not far from it.' is keep-criter |
| `liscor.json` | GRANTED -- section 3.3 tension noted for Phase 5 | `liscor/street.json` · `$.entities[17].observe` | §3.3, §8 | GRANTED PETITION (lane-raised, controller-granted), WITH A RECORDED SECTION 3.3 TENSION FOR PHASE 5. Grounds for the keep: one sentence, zero anonymous agents, zero negation, and e |
| `liscor.json` | GRANTED -- diegetic-document exception | `liscor/guild.json` · `$.entities[2].board_rumors[1].copy` | §1.4, §8 | GRANTED PETITION (lane-raised, controller-granted) -- DIEGETIC-DOCUMENT EXCEPTION. A board_rumors 'copy' string is not authorial narration; it is a physical document the player is  |
| `pallass.json` | deferred_to_close | `pallass/pallass_market.json` · `$.entities[22].variants[0].toast` | — | The reviewer flagged this as a possible landmark rather than a demotion: the reversal is earned by a gate the player passed, the civic text is quoted rather than paraphrased, and t |
| `pallass.json` | granted | `pallass/pallass_forge_hall.json` · `$.entities[5].toast` | §8 | The region's one earned peak on the apprentice chain. A counted fact (forty-one) plus diegetic lettering that is attributed to the physical surface in the same string ("in smaller  |
| `pallass.json` | granted | `pallass/pallass_market.json` · `$.interior_flavor[1]` | §6 | An empty-cell flavour line that characterises the whole city in one observed action, with a real present person doing it — the §6 rule-1 ideal (an action the evidence shows, no mot |
| `pallass.json` | granted | `pallass/pallass_forge.json` · `$.entities[14].variants[0].toast` | — | The payoff of the region's repeatable-work chain, gated at pallass_fetches_run 5 — the player earned it by running the errand five times. "She wouldn't." is a two-word closer, and  |
| `pallass.json` | granted | `pallass/pallass_den_shop.json` · `$.entities[1].observe` | — | Two concrete wear-marks, and the inference is about years of one woman's own labour rather than an absent agent — the exact counter-case to the region's civic-schedule template. "B |
| `riverfarm.json` | petitions | `riverfarm/riverfarm_mill.json` · `$.entities[5].toast` | §6 | §6 rule 1 PERMITTED-CLASS KEEP — and the strongest possible ground: this exact string is the bible's OWN worked exemplar for §6 rule 1, quoted verbatim in narrator-bible.md ('Permi |
| `riverfarm.json` | petitions | `riverfarm/riverfarm_longhouse.json` · `$.entities[1].observe` | §6 | §6.2 CONSEQUENCE-ANON, the class RULED permitted at the pallass petition and amended into §6 at #397 integration. 'for whoever needs it' points FORWARD at a hypothetical future gue |
| `riverfarm.json` | petitions | `riverfarm/riverfarm_village.json` · `$.entities[31].locked_toast` | §6 | §6.2 CONSEQUENCE-ANON, second instance. 'This is a job for somebody built for it' names whoever COULD do the lift, not somebody who did anything — a Skill gate stated as a person-s |
| `riverfarm.json` | petitions | `riverfarm/witch_hut.json` · `$.entities[1].on_skill_use.toast` | §1.4 | LENGTH EXCEPTION §1.4: three sentences in functional/skill-outcome, where the ceiling is two. Petitioned on the precedent already GRANTED twice in this pass for the same shape — du |
| `riverfarm.json` | petitions | `riverfarm/witch_hut.json` · `$.entities[1].skill_hint_toast` | §7 | §7 NEGATION KEEP IN FUNCTIONAL REGISTER — a counter-invisible one, disclosed rather than quietly kept. 'and not the way dust hums' is a correction geometry that NEITHER regex fires |
| `riverfarm.json` | petitions | `riverfarm/witch_hut.json` · `$.entities[5].toast` | — | PEAK, and the answer to the §10 worry about this exact file. narrator-bible.md §10 names witch_hut as THE anti-template case study and quotes a 'lazy fix' draft that flattens all f |
| `riverfarm.json` | recorded_not_fixed | `riverfarm/riverfarm_longhouse.json` · `$.entities[1].sleep_toast` | — |  |
| `riverfarm.json` | recorded_not_fixed | `riverfarm/riverfarm_mill.json` · `$.entities[2].locked_toast` | — |  |
| `riverfarm.json` | recorded_not_fixed | `riverfarm/riverfarm_village.json` · `$.entities[31].observe` | — |  |
| `riverfarm.json` | recorded_not_fixed | `riverfarm/witch_hollow.json` · `$.entities[0].observe` | — |  |

### 10.3 §9.2 ending-shape exceptions already ruled

Source: docs/superpowers/2026-08-05-wave2-rulings-and-fix-specs.md — '## Empty-regions lane' item 4 and '## Inn lane'

| file | lane-recorded share | this report's top shape | ruling |
|---|--:|---|---|
| `sewers/sewers.json` | 46% | fact 52% | empty-regions lane invoked §9.2's loosen-to-50; ACCEPTED — the file was at or above this share before the pass |
| `sewers/deep_tunnels.json` | 47% | fact 67% | empty-regions lane, same ruling |
| `dungeon/seal_vault.json` | 50% | fact 67% | empty-regions lane, same ruling |
| `inn/inn_upstairs.json` | 55.6% | absence 33% | inn lane §9.2 exception (baseline 66.7%); ACCEPTED as an improvement on a 9-string file |

The two shares are computed by different shape proxies and are not expected to agree. Both are advisory.

### 10.4 Landmark beats granted out of the §5 reserve

bible §5 RULED the ceiling at 12 beats (8 spent by the ruled landmark strings, 4 in reserve). 1 grant(s) have since been allocated out of that reserve, so **3 remain**. Reserve is allocated by the controller on petition only (§5 counting rule 3); a lane never self-grants.

| id | disposition | beat | granted |
|---|---|---|---|
| `pallass/pallass_market.json:$.entities[22].variants[0].toast` | KEEP-AS-IS | Ordinance 44 / the stamped tier pass (pallass civic chain) | controller grant 2026-08-06 from the 4-beat reserve (elevator_pass_stamped-gated, chain-earned) |

A grant does not touch the string and does not change the register heuristic: `landmark-registry.json` records it as a `controller-grant` row with its own reserve arithmetic, so the allocation stays visible to every later reader.

### 10.5 Holdout, by region (frozen for Phase 5)

| region | holdout strings |
|---|--:|
| dialogue | 113 |
| dungeon | 12 |
| floodplains | 14 |
| garden | 3 |
| inn | 12 |
| invrisil | 15 |
| liscor | 11 |
| pallass | 18 |
| riverfarm | 21 |
| ruin | 4 |
| sewers | 6 |

---

## 11. Reproducing this

```sh
python3 qa/scripts/extract_prose.py report --outdir docs/prose-naturalization
python3 qa/scripts/extract_prose.py self-test          # includes report legs
python3 qa/scripts/extract_prose.py verify-untouched   # the untouchability gate
```

The report reads the live tree plus the FROZEN `protected-keeps.json` / `holdout.json`. It never rebuilds `inventory.jsonl` (verify-untouched's baseline) and never rebuilds the blind sets. Two runs on one tree are byte-identical; self-test proves it.

