# #513 Pallass income and Pallass themes (design)

Design only; no code or data changed here. Base: main `6a5df080`.
#514 has landed. Implementation re-reads the shipped dialogue and map files
at build time.

## Rulings this design answers

- **#513 (2026-10-07, revised 2026-10-08):**
  - add a **Gnoll–Drake social quest** in Pallass paying about **12g plus a
    sellable trade bale**;
  - it must be startable on arrival with little gold and reachable before the
    lift pass;
  - the Runners' Post follows later (#600).

  Rejected: another grinding job, and the bonded-room paperwork quest
  ("Held in Bond"), because it repeated Pallass's paperwork theme.
- **Pallass themes (2026-10-08).** Besides bureaucracy, Pallass is:
  - the City of Inventions;
  - famous for its alchemists and smiths;
  - home to Grimalkin's fitness culture;
  - home to other races, Garuda and Dullahans among them.

  Re-theme the existing quests so only `papers_for_pallass` stays
  paperwork-focused. Quest, accomplishment and item ids, fees and rewards
  all stay. "Grand Lift" stays.
- **Voice and prose rules:**
  - `docs/dialogue-voice-bible.md` and the voice cards (`forge-smith`,
    `grimalkin`, `lift+klbkch`, `den-keeper+witch`, `market-pallass`,
    `market-local`, `yvlon+xif`);
  - the dialogue skill's canon-and-voice reference;
  - zero-inference scenery;
  - discovery over instruction.

Every line quoted below is a **draft for the prose pass**, not final copy.

## 1. Summary

**New quest, "Room on the Row".** A Gnoll wool trader has come up through the
Door with plains wool and her grandmother's brass weights. The Drake stall
row will not rent her the free counter: years ago a trader with a hollow
weight cheated the row, and the stallkeeper still tells the story.
- **Talk route:** win the row over with [Charming Smile], or Skill-free by
  weighing her brass against the city's chained test weights at the public
  scales, in front of everyone.
- **Help route:** carry her bales to the Drake den-shop keeper, who sells
  them from her own shelf.
- **No fight route.** None is natural to a civil quarrel on a tier the Watch
  patrols.
- **Reward:** 12g plus a bale of plains wool (price 16, sells for 8g on the
  same tier).
- **Pacing:** startable on arrival with 0g, and it covers the 18g in-Pallass
  fee chain in the arrival waking.

**Re-themes.** Only `papers_for_pallass` keeps the paperwork texture:

| Quest | New theme |
|---|---|
| `forge_tier_permit` | **Grimalkin's fitness.** A booked exam floor, a Sinew Magus read, a lift token cut to your measured load class |
| `tempered_standards` | **Smiths and alchemists.** A Dullahan examiner's bend test, a fast alchemical quench, a smith who taught "harder" |
| `ledger_eats_first` | **City of Inventions.** A rune-set oven regulator the mana-stone cage refuses, with a Garuda runner in passing. Its talk route moves from the two clerks to Xif and the smith |

All are copy, prop and beat-texture changes. The one mechanics change is
that relocation of two hidden options.

## 2. Canon check (bar: ebook Book 17, about web 7.28)

The research pulled wiki wikitext through the API and checked each claim
against chapter text up to 7.28. Chapter URLs follow
`wanderinginn.com/YYYY/MM/DD/slug/`: for example 5.01 is
`/2018/07/14/5-01/`, 6.09 is `/2019/04/20/6-09/` and 7.02 is
`/2020/01/26/7-02/`.

| Theme | Verdict | Evidence |
|---|---|---|
| City of Inventions | **Within** | "This is Pallass, the City of Invention!" (5.01), recurring in 6.09, 6.32, 7.01 and 7.19. Hand-crank lifts and magic lifts (5.01). Mana-stone elevators (6.09). [Engineers] built the goods elevators (7.01). Stipends for [Engineer], [Alchemist] and [Inventor] (7.19). <https://wiki.wanderinginn.com/Pallass>. **Past:** the Engineer's Guild (Vol 10, and *Innovation and Invention*) and the eight named "Grand Lifts" (the shipped name stays by ruling) |
| Smiths and alchemists | **Within** | The 9th floor's alchemists' section and forges (6.09). Pallass for steel and potions: "Pallassian steel? Our potions?" (5.01); "Pallass for steel and potions" (6.11); "a good portion of Izril's steel" (6.31). Xif (6.09; <https://wiki.wanderinginn.com/Xif>). Maughin, a Dullahan [Armorer] (6.09; <https://wiki.wanderinginn.com/Maughin_Dulamet>, whose surname is not used). Lorent, a Dullahan [Sharpener] (6.09). **Past:** Pelt's move to Esthelm (7.31) and the Alchemium Scholaris (7.49). **Uncertain:** steel "second only to Deríthal-Vel" |
| Grimalkin's fitness and Sinew Magic | **Within** | "Physical magic. His personal school." (6.09). [Sinew Magus] in the text from 6.31. His gym (7.02): weights beside essay desks, anatomy diagrams, "Willpower!". He takes any species. Students include Ferkr (Gnoll), Giren (Dullahan) and Ekil (Garuda). His weights were forged by Maughin (6.31), and he knows which muscle each lift works (6.38). <https://wiki.wanderinginn.com/Grimalkin_Duveig>. **Past:** the surname Duveig (8.42) and the Magic-Captain rank. Neither is used |
| Garuda living in Pallass | **Within** | A young male Garuda Street Runner at a Watch House (7.02). "More common here than Humans" (6.31). Garuda fly in Pallass (7.03). A Garuda waiter (7.11). A Garuda apprentice [Alchemist] (7.17 S). **Past:** the citizenship panel (Vol 10) and Esor (8.29) |
| Dullahans living in Pallass | **Within** | Maughin, Lorent (6.09), Giren (7.02). "Two seats out of hundreds", "a growing minority" (6.31) |
| Gnolls and Drakes in Pallass | **Within** | "City Gnoll" is canon (5.06 M, 5.44; *Interlude – Krshia*: "used sometimes with pity or disdain"). Xif's "I am a City Gnoll" (6.09). Rufelt (Gnoll) and Lasica (Drake), married, run Tails and Scales (6.09). A Plains Gnoll guide looks down on City Gnolls (7.01). Drakes hold most posts in Izril (*Interlude – Krshia*); Gnolls rarely reach high rank in Drake armies (4.16). Tribes are "accused of thievery" (7.10 K). <https://wiki.wanderinginn.com/Gnolls> |

**Past the bar, so never used:**
- the Meeting of Tribes and anything there (8.02+);
- Plain's Eye's scheme and Ferkr's speech (8.42);
- white Gnolls in Salazsar and Doombearer magic (7.33 I) and the Doombearer
  truth (8.79);
- the Gnoll Magic War and the civil war;
- Hectval's slurs and "second-class" City Gnolls (7.53);
- Gnoll army generals (7.53, 10.37).

The white-fur superstition (5.42, 6.32) is within the bar but is left alone.

**Uncertain, so not used:**
- Lizardfolk residents in Pallass;
- the open statement of Saliss's other identity.

**Original, not canon, so the user should acknowledge:**
- the wool trader and the stall row's grievance;
- load classes on the exam floor;
- the Dullahan bend-test examiner, which is consistent with Lorent and
  Maughin;
- the oven regulator and the Garuda runner on the shaft, which is
  consistent with 7.02 and 7.03.

No named canon character past the bar appears. Named canon mentions within
the bar are Xif, Grimalkin and Maughin (the forge of Grimalkin's bar).

## 3. New quest: "Room on the Row" (`room_on_the_row`)

### 3.1 Premise and fit

Pallass's market tier is Drake by default, and it checks weights in public:
the shipped `market_public_scales` observe line already reads "Any
stallkeeper's measure can be checked here against the city's, in front of
everyone." A **Plains Gnoll** trader who arrived by the Door is turned away by the
stall row's suspicion of "Gnoll weights". This is grounded in canon
within the bar:
- tribes "accused of thievery" (7.10 K);
- Drakes holding most posts (*Interlude – Krshia*);
- Pallass's own City Gnolls and Gnoll–Drake households (Xif, Rufelt and
  Lasica, 6.09);
- the Plains–City divide (6.09, 7.01).

The stakes are personal and social: her week's trade, and the row's
memory of being cheated. The fix is trust shown in public, which is a
civic act and not paperwork.

It stays clear of every post-bar Gnoll–Drake event (§2). The quarrel is
everyday market prejudice, with an invented and specific grievance (a
hollow weight, eight years ago), no politics and no named canon figures.

### 3.2 People and places (market tier and den shop; all reachable before the lift)

- **New NPC `wool_trader`** ("Gnoll Wool Trader"), an unnamed role near the
  arrival plinth. The candidate cells are (2,4) and (3,3), final after the
  census in §6.
  - Conversation: new `data/dialogue/pallass_wool_trader.json`.
  - First-waking `talk_pool` bark: "Plains wool, yes? Washed twice. Nobody
    on the row will rent me a counter to sell it from."
  - Rig: reuse the unnamed-role `gnoll_traveler` rig, or commission one
    (VISUAL-LOG). No named character's rig is shared.
- **New prop `wool_bale_stack`** ("Six Wool Bales") beside her. Its
  observe: "Six bales of plains wool, tied with twine, a set of brass
  weights in a cloth on top."
- **Drake side:** the shipped `market_stallkeeper` (`pallass_market_local`),
  who already reacts to the player's race. She gets one hidden option,
  appended last.
- **Help partner:** the shipped `den_shop_keeper` (`pallass_den_keeper`), a
  Drake who already carries eleven households on credit (her house slate).
  She gets one hidden option, appended last. A new prop, `den_shop_wool_shelf`
  ("A Cleared Shelf"), is added in the den shop.
- **Talk alternative:** a quest-gated `variants` row appended to the shipped
  `market_public_scales`. Ungated players see the pinned toast unchanged.

### 3.3 Loop (counters are new ids, frozen once shipped)

| Beat | Where | Gate → effect |
|---|---|---|
| Start | Trader: "I'll talk to the row." | None, so 0g and no stamp → quest `room_on_the_row`, `wool_trade_started` |
| Talk, [Charming Smile] | Stallkeeper: hidden "About the Gnoll with the wool." → node `row_wool` → visible-locked skill row | Skill → `row_opened`, `trader_placed` |
| Talk, Skill-free | `row_wool` "Then check her weights at the public scales, in front of everyone." → `heard_row_grievance`. Interact the scales (variant) → `weights_proved`. Then the stallkeeper's hidden "[Her weights matched the city's.]" | `row_opened`, `trader_placed` |
| Help | Trader's "Where else could you sell it?" names the den shop. Interact `wool_bale_stack` (leg 1), then `den_shop_wool_shelf` (leg 2), each banking `wool_bales_carried` once the quest has started. Then the den keeper's hidden "[Two bales are on your shelf.]" | `wool_consigned`, `trader_placed` |
| Report | Trader: "[Tell her where she is selling.]". Hidden until `trader_placed`; `hide_when: wool_trade_settled` | `wool_trade_settled`; +12g; item `plains_wool_bale` |

**Rules.**
- One gate type per `requires`.
- Every node with hidden options keeps an ungated exit.
- The resolution ladder runs weakest first, last match wins:
  `wool_consigned` < `row_opened`. A shelf in someone else's shop is a
  workaround; a counter on the row changes the row.
- Grants mirror the shipped Pallass magnitudes:
  - talk: `persuaded_someone` 3, `heard_gossip` 2;
  - help: `befriended_moments` 2, `observed_things` 2.

**Why there is no fight route.** The quarrel is civil and on a Watch-patrolled
tier. The nearby watch-golem pair is a separate respawning cull. Forcing a
brawl would contradict both the premise and the Pallass verb. Two
legitimate non-combat routes carry the Pillars, as the ruling allows.

### 3.4 Voice drafts (prose pass decides)

**Trader** (T2, Gnoll texture: one ", yes?" per node at most, "Hrr." at
most once in the file, standalone):
- hub: "Plains wool, washed twice and baled tight. I came up through the Door
  with six bales and my grandmother's weights. The row has a counter free.
  The row says my weights are Gnoll weights."
- `weights`: "Brass, cast in Liscor, the same as theirs. Somebody here was
  cheated once by a trader with a hollow weight. She tells it to everyone
  who stops at her stall."
- payoff: "Twelve now, from what I sell before the bell. And take a bale. It
  fetches more in Liscor, and you go there anyway."

**Stallkeeper** (T2 market-local, impatient, concrete):
- `row_wool`: "The counter's free. I'm not renting it to weights I haven't
  seen checked. Eight years back somebody sold half this row short with a
  hollow weight. We all paid for that one."
- After the scales: "Counter three, posted rent, settled at week's end like
  everyone. She brings the weights every morning. I'll be looking."

**Den keeper** (T2, her hatchlings, shelves and bread texture):
- "Plains wool. I said yes to the shelf if it gets here. My cut is on the
  slate like everyone's."
- After: "Two bales, counted onto the shelf. The small ones have been told
  not to sit on them."

**Scales variant toast** (map register, zero inference): "Her brass goes in
one pan and the city's chained weights in the other. The beam settles
level. Two stallkeepers watching from the row go back to their own
counters."

### 3.5 Reward and pacing

**Reward:** 12g, plus `plains_wool_bale`: a new mundane `tool`, price 16,
every combat modifier 0, resonance 0, sellable. It sells for 8g at the
market-tier stallkeeper (`sell_price` is half the worth times (1 + trade
bonus)). That is 20g of value, under every Invrisil one-shot (25, 25 and
30).

**Arriving with 0g after the stone**, all in the arrival waking with 0 extra
sleeps:

| Step | Purse |
|---|---|
| Quest reward | 12 |
| Entry stamp (−2) | 10 |
| Exam-floor booking (−5) | 5 |
| Exam row | Locked: "needs 3 more gold" |
| Sell the bale (+8) | 13 |
| Grimalkin's read (−8) | 5 |
| Lift token (−3) | **2** |

Today the same arrival takes about 2.5 wakings (imperfect ledger, T16–T18).

Other arrival purses:
- the worker (12g) ends at 6g plus the bale;
- the martial (18g) ends at 12g plus the bale;
- the Rogue and caster (66–78g) gain an optional +20g of value.

### 3.6 Files

| File | Change |
|---|---|
| `data/maps/pallass/pallass_market.json` | Append `wool_trader` and `wool_bale_stack`; append a `variants` row on `market_public_scales` (splice) |
| `data/maps/pallass/pallass_den_shop.json` | Append `den_shop_wool_shelf` |
| `data/dialogue/pallass_wool_trader.json` | New graph |
| `pallass_market_local.json`, `pallass_den_keeper.json` | One hidden option each, appended last, plus the nodes they lead to |
| `data/quests.json` | `room_on_the_row`: resolve `complete_when_any` over `row_opened`/`wool_consigned`; report on `wool_trade_settled`; `resolution_paths` |
| `data/items.json` | `plains_wool_bale` |
| `data/leads.json` | `lead_room_on_the_row`, requires `pallass_attuned`, hides on `wool_trade_started`. Draft text: "A Gnoll trader stands by the plinth with six bales of wool and nowhere to sell them." |
| Docs | `docs/design/character-profiles.md` (Wool Trader role); a voice card |
| Art | Sprites as needed (`wi-art-and-sprites`) |

### 3.7 QA plan

1. **Static checks:**
   - data_lint;
   - `test_content` (lead mirrors its gate; ungated exits; quest beats;
     variants);
   - `test_dialogue`;
   - `test_copy_fit`;
   - the shipped-IDs test;
   - reachability.
2. **Fixture:** `journey_imperfect`'s L5 checkpoint (0g after the stone),
   walked through the Door with real input. This is the
   `poor_retired_producer_recovery` idiom.
3. **`pallass_row_talk`:**
   - a [Charming Smile] leg, from a fixture holding the Skill;
   - a scales leg: assert the visible-locked row without the Skill, the
     grievance, the scales toast and `weights_proved`, then the row line;
   - report: +12g, the bale;
   - pay the stamp and booking; assert "needs 3 more gold" on Grimalkin's
     row;
   - sell the bale (+8) through the stallkeeper's picker;
   - pay the read and the token; take the lift;
   - assert `times_slept` is unchanged.
4. **`pallass_row_help`:** stack, shelf, den keeper, report. Same payoff.
5. **Negatives:**
   - the report row is absent before `trader_placed`;
   - no second payout;
   - an ungated player's scales toast and the stallkeeper and den-keeper
     option lists are unchanged.
6. **Windowed reads:**
   - the trader and stack by the plinth;
   - the scales toast;
   - the den-shop shelf;
   - the journal lead;
   - page budgets.
7. **Pins:** re-derive `pallass_peek`'s market sprite count (27 to 29). The
   census keeps the new cells off journey walk and use cells.

### 3.8 The five journeys

None takes the quest. Gold, fights and sleeps are unchanged.

What they do see:
- the lead line in their Act V journal screenshots;
- two new entities on the market tier, which must be off their cells.

The appended hidden options and the scales variant are invisible to them.

## 4. Re-themes of the existing Pallass quests

Ids, gates, fees and rewards are frozen. Beats keep their counters and
order. Speaker names stay (all five journeys pin `"Forge-Tier Clerk"` and
`"Grimalkin"`).

### 4.1 `forge_tier_permit` → Grimalkin's fitness

**Before.** "Clearance for the Forge Tier": file a permit at a window (5g),
Grimalkin's fitness read (8g), collect a stamped pass (3g). The texture is
windows, files and stamps, and the clerk says "I only handle paper".

**After.** "Fit for the Forge Tier":
1. Book a slot on Grimalkin's exam floor (5g, same window).
2. The read itself (8g): Sinew Magic laid on your forearm, then grip and the
   stair at pace.
3. A lift token cut to the load class he writes (3g).

The forge tier carries loads all day, and the lift (an invention) is rated
by class. The clerk keeps the T3 procedural register, but his subject is the
floor, chalk and classes.

**Changes** (drafts; speaker names unchanged):

| Where | Before (abridged) | After (draft) |
|---|---|---|
| `pallass_forge_clerk` `hub` | "State your business and your sponsor, or stand aside…" | "Exam-floor bookings, lift tokens, floor kit. State which, or stand aside for the next in line." |
| `hub` option | "I need clearance for the forge tier." | Unchanged |
| `permit_intro` | "Five gold, filed same-day… I only handle paper." | "Five gold books a slot on the exam floor, same day, posted price. Grimalkin reads you at the far end of this office. The forge tier carries loads from first bell to last, and he writes down whether you can." |
| option | "File it. (5 gold)" | "Book the slot. (5 gold)" |
| `permit_filed_reaction` | "Filed. Grimalkin is at the exam floor…" | "Booked. Chalk your hands at the bucket before you go to him. He notices." |
| `permit_status` | "Filed and pending…" | "Booked and waiting on his read. This window cuts your token after he writes your class." |
| `hub` option | "The exam's done. About that stamp." | "Grimalkin wrote my class. About the token." |
| `collect_stamp` | "Grimalkin's mark is on the file. Three gold for the stamp…" | "His class is on the slate. Three gold for the lift token, posted price, cut to the class he wrote." |
| option | "Collect the stamped pass. (3 gold)" | "Take the token. (3 gold)" |
| `stamp_reaction` | "Stamped. The lift answers to it now…" | "Cut and stamped with your class. The lift answers to it now. Lose it and you sit his read again." |
| `pallass_grimalkin` `exam` | "Grip, cleared. Wind, cleared…" | "Grip on the bar Maughin forged me, cleared. Four short of my Dullahan student's number. The stair at pace, twice, cleared, barely. You did not quit before I did. Class four. The forge tier carries class four. Ask around this office what I usually write." (Canon: Maughin forged his weights, 6.31; he has Dullahan and Garuda students, 7.02. The comparison is a count, in his register, not a balanced pair.) |
| Grimalkin hub option | "I'm here for the forge-tier fitness read. (8 gold)" | Unchanged (already fitness) |
| `permit_office_counter` | "Permit Office Window"; "…waiting on a stamp…" | "Exam-Floor Window"; observe: "The ledge is chalk-white where a thousand hands have rested on it. A slate beside the glass lists load classes one to six, and the posted fees." |
| `quests.json` title | "Clearance for the Forge Tier" | "Fit for the Forge Tier" |
| beats `apply`, `examined`, `stamped` | file a permit; pass the exam; collect the stamped pass | "Book a slot on Grimalkin's exam floor at the window by the Grand Lift." / "Pass Grimalkin's read at the far end of the office." / "Collect your lift token, cut to the class he wrote, at the same window." |
| resolution text | "You passed Grimalkin's examination on your own legs…" | "Grimalkin read you, wrote your class, and the lift answers to the token." |

The forge clerk's shop rows (oil, pike, apron) and their nodes are
unchanged. The `acts.json` Act IV lines ("opens for paperwork, not heroics"
and "papers stamped and the lift unlocked") point at `papers_for_pallass`'s
chain and stay.

**Pins** (`grep qa/scripts`):
- **All five journeys** (`journey_rogue`, `journey_worker`,
  `journey_caster`, `journey_imperfect`, `steel_thread`) quote `permit_intro`,
  `collect_stamp` and Grimalkin's `exam`. Several also quote the options
  "File it. (5 gold)", "The exam's done. About that stamp." and "Collect the
  stamped pass. (3 gold)".
- `pallass_walkthrough` quotes the same set plus the quest title.
- `pallass_depth_gates_check` quotes the clerk `hub` line.

Option order is unchanged, so cursor routes hold. Only text pins move.

### 4.2 `tempered_standards` → smiths and alchemists (a Dullahan examiner)

**Before.** An examiner fails the apprentice nine times. The talk route reads
the examiner's printed notice ("it measures recovery") and "gets it in
writing". The texture is a notice, a file and an inquest.

**After.** The examiner is a **Dullahan** blade-tester. He tests on a **bend
jig**: a notch for how far a blade bends, a notch for where it springs back.
The apprentice's blades fail because the smith taught "harder" and had **Xif
blend a fast quench**, which leaves steel brittle.

The routes keep their counters:
- **talk** (`read_the_examination_standard` → `standards_brokered`): read the
  jig's notches to the smith;
- **skill** (`temper_run`, [Appraise Goods]): run the temper on the slow oil;
- **fight** (`golem_recalibrated`): bring the drifting calibration rig back
  into tolerance. The rig is the tier's bend-tester, an invention.

Craft and alchemy replace the paper.

| Where | Before (abridged) | After (draft) |
|---|---|---|
| `pallass_forge_smith` `commission` | "…The examiner has failed her nine times running…" | "You counted them. Good. My apprentice has the steadiest hand on this tier, and the examiner has bent nine of her blades back into that bin. He's a Dullahan. He holds his head out level with the edge and sights down it. I taught those hands myself. Go and find out which of us the bend agrees with." |
| `commission_brief` | "…read the examiner's own notice on my wall…" | "Hall's through the door past the second bench. Run the temper yourself if you have the eye for it, or look at his bend jig on the hall wall and tell me what it measures. Watch the calibration rig either way. It has been drifting." |
| `standard` | "The city sets the spec… an inquest with my name in the file." | "The examiner bends every blade on his jig and lets go. Where it comes back to is the mark. I've held this bench to his marks for six years." |
| `broker` | "Recovery. It is printed on his own notice…" | "Recovery. Two notches on his jig, one for the bend and one for the spring. She kept bringing him harder steel because harder is what I taught her, and I had Xif blend her a fast quench to get it. Nine fails. Read me the notches again." |
| report option | "[The standard measures recovery. It's printed on his own notice.]" | "[The jig's second notch is where it springs back.]" |
| `commission_settled` tv[2] | "…It is in the file now…" | "Six years we argued and the jig had both our marks on it. She'll quench slow in the morning." (this file's PEAK stays here) |
| smith stage `smith_standards_tempered` | "The examiner sent the file up himself…" | "The examiner climbed the stair himself to watch her bend one. Head under his arm the whole way up." |
| `forge_hall_standard_notice` | "The Examination Standard"; notice text | "The Examiner's Bend Jig"; observe: "A steel jig bolted to the wall, two notches filed into its arm. A Dullahan's maker's mark is stamped on the base." toast: "The jig bends a blade to the first notch and lets go. The mark that counts is the second notch, where the blade comes back to." |
| `forge_hall_temper_bench` skill toast | "…hold the count two beats longer…" | "[Appraise Goods] — You read the grain off the colour, set the fast oil aside for the slow barrel, and quench. The billet springs back to the second notch." |
| `forge_reject_bin` toast | "…all failed on the same measure…" | "Nine blades in the bin, all from one hand, all bent past the same notch and left there." |
| `quests.json` | report "…and let her file it."; resolutions "…got it in writing." | "Bring the smith the answer at her anvil." "You read the examiner's jig to the smith, and she changed the quench." "You ran the temper yourself, on the slow oil, and the billet came back." (rig text unchanged) |

Title, lead and the rig encounter are unchanged. Grimalkin's hub tv[2] (the
"same measure as a squat" line) already ties fitness to smithing, so it
stays.

**Pins:**
- `pallass_standards_talk` quotes the notice toast and the Grimalkin tv;
- `pallass_standards_skill` quotes the bench skill toast;
- `pallass_standards_fight` quotes the rig, which is unchanged;
- `pallass_depth_gates_check` quotes the bench locked toast, which is
  unchanged;
- `pallass_walkthrough` quotes the smith's `hub` and `spec`, which are
  unchanged.

No journey quotes this quest.

### 4.3 `ledger_eats_first` → City of Inventions (Garuda in passing)

**Before.** "The Ledger Eats First". A crate of tin is held in an office
queue. Routes:
- walk the offices (market clerk endorses, forge clerk countersigns, den
  keeper signs);
- find the exemption in the forms ([Appraise Goods]);
- carry it down yourself in three legs.

This is the corpus's main paperwork loop.

**After.** "The Crate the Cage Refuses". The den shop ordered a **rune-set
oven regulator** from a forge-tier workshop. The mana-stone cage's
feather-fall runes flicker whenever it is loaded, so the attendant will not
send it. Routes, with the same counters:
- **talk** (`queue_notice_endorsed` → `queue_notice_countersigned` →
  `loop_walked`):
  - Xif identifies the rune-ink as his own batch, which sings near
    mana-stone unless lead sits between them;
  - the forge smith folds a lead wrap from her apron offcuts;
  - the den keeper takes delivery.
- **skill** (`exemption_found`, [Appraise Goods] on the den shop's
  drawings): the drawings show a shipping catch the packers never set.
- **help** (`shipment_carried`): carry it down by the service stair in the
  same three legs.

A Garuda runner appears in the attendant's traffic line.

**The one mechanics change.** The two talk-route options move:
- from `pallass_market_clerk` (`queue_entry` option and nodes) to `xif.json`;
- from `pallass_forge_clerk` (`queue_release` option and nodes) to
  `pallass_forge_smith`.

Gates and effects are unchanged. They are hidden options, appended last
where added, so no visible option list moves for anyone outside the quest:
- the caster journey's 11 Xif pins stay valid, because it never starts the
  quest;
- the clerks lose only hidden rows.

**Changes:**

| Where | After (draft) |
|---|---|
| `pallass_lift_attendant` hub option | "Your manifest says one crate, refused three cycles." |
| `ledger_pitch` | "Four cycles, and it will be five. Every time it goes in the cage, the feather-fall runes under the floor flicker. I don't send a cage down flickering." |
| pitch option | "Somebody should get it down." |
| `ledger_brief` | "There's a regulator in that crate, rune-set on this tier, for a bread oven. Its runes and my cage's runes don't get on. Find out what quiets it, {addr}. Or carry it down the service stair, which is nine flights and not how it's done. The consignee is the den shop on the market tier." |
| `ledger_brief_two` | "Xif on the market tier sold the workshop its ink. The smith by the second bench cast the case. The den shop takes delivery last. Down at the quarter bell." |
| `traffic` | "…one crate my cage won't take. This morning it was charcoal, a coop of live hens for the ninth tier, and a Garuda runner who wouldn't wait for the cage and went down the shaft on his own wings…" |
| `seal` and hub tv | "tin" becomes "the den shop's crate" or "charcoal". The "two hundred miles" line stays |
| `ledger_report` options | "[Xif's ink, the smith's lead. It rides the cage now.]"; "[The regulator has a shipping catch. Nobody set it.]"; carried option unchanged |
| `ledger_settled` tvs | Talk: "You got an alchemist and a smith to agree about my cage…". Skill: "A catch. Three cycles, and it was one brass catch. Don't speak to me until the half bell." Carried: unchanged; it is the file's peak |
| `xif.json` (new hidden option, appended last) | "That crate on the forge landing. The regulator." → "My ink, yes? I sold that workshop a jar. It sings near mana-stone if nothing is between them. Lead is between them. Tell the smith two fingers of lead. Prices are posted. This advice is not on the board, so it is free." → `queue_notice_endorsed` |
| `pallass_forge_smith` (new hidden option, appended last) | "Xif says two fingers of lead around the regulator." → "Two fingers. I've offcuts from the aprons. Hold the case still while I fold it. There. Tell the cage it can stop flickering." → `queue_notice_countersigned` |
| `pallass_den_keeper` | Hub option: "I'm here about your oven regulator." `month`: "A regulator for my oven, four cycles late, on a landing two tiers up. The cage won't carry it. I have hatchlings upstairs chewing yesterday's bread and an oven that burns the bottom of every loaf." `consignee` option: "[It rides the cage in a lead wrap now.]". `released`: "A lead coat for it. I'll have it fitted before the evening bake." hub tv: "The regulator came down. The loaves come out even now. Sit down, {addr}. You are eating something." `carried` is unchanged (its peak) |
| Props | `lift_manifest_slate` toast: "One crate, den shop, market tier, logged three cycles running. Beside it in a tidier hand: refused, cage runes."; `den_shop_consignment_file` becomes "The Maker's Drawings" (observe, locked and skill toasts rewritten around sheet nine's shipping catch); `market_dray_rank` and `lift_cargo_pallet` toasts name the service stair and ramp; the dock is unchanged |
| `quests.json` | Title "The Crate the Cage Refuses". Unstick beat: "Get the refused crate to the den shop on the market tier. Quiet its runes, find why they sing, or carry it down yourself." Resolutions: "Xif named the ink, the smith folded the lead, and the cage took the crate." / "You found the shipping catch on the drawings and set it." Carried text unchanged |
| `leads.json` `lead_ledger_eats_first` | "One crate has sat on the forge-tier landing three cycles, and the cage will not take it." |

**Voice-bible note.** The lift attendant's budgeted recursive-bureaucracy
gag goes away with the queue. The budget is a ceiling, not a quota. The den
keeper's `month_two` loses its system line in favour of oven and bread
detail.

**Pins:**
- `pallass_ledger_offices` (re-authored for the new talk route);
- `pallass_ledger_skill`;
- `pallass_ledger_carry` (title only, and the attendant option);
- `pallass_depth_gates_check` (the drawings' locked toast);
- `invrisil_disagreement_talk`, `invrisil_walkthrough` and
  `stage3_perks_loop`: they quote the attendant's `cycle` node, which is
  unchanged. Verify only.

No journey quotes this quest. The caster journey's Xif option arrays are
unchanged (hidden append).

### 4.4 `papers_for_pallass` (unchanged)

It stays the one paperwork quest: Selys's sponsorship, Krshia's stone and
the Tier Clerk's entry stamp.

## 5. Spread check

| Quest | Theme | Verb in play |
|---|---|---|
| `papers_for_pallass` | Bureaucracy | File, stamp |
| `forge_tier_permit` | Grimalkin's fitness | Be measured |
| `tempered_standards` | Smiths and alchemists, Dullahan examiner | Read the craft |
| `ledger_eats_first` | Inventions, Garuda runner | Fix the machine |
| `room_on_the_row` | Gnoll and Drake neighbours | Win trust in public |

No two quests share a premise, a place or a route texture.

## 6. Journeys, census and gates

All five continuous journeys pass through Pallass and pay the fee chain.

| Change | Effect on the journeys |
|---|---|
| `forge_tier_permit` re-theme | Changes their pinned text (§4.1). Re-pin from observed runs; inputs and gold are unchanged |
| The other two re-themes and the new quest | No journey quotes them |
| New entities on the market tier and in the den shop | Must lie off every journey's walked and use cells. Derive the census from each journey's `events.jsonl` |
| The lead | Renders in Act V journal screenshots; payload pins assert `act_id` only. Re-read the screenshots |

**Gates:**
- data_lint and the content and dialogue suites;
- `ci_sweep --touching data/maps/pallass`;
- the full sweep;
- `qa/journey_gate.py` on all five journeys;
- windowed reads of every changed node and toast (page budgets);
- `derive_qa_surfaces.py` and `render_qa_notes.py --write` after the QA
  edits.

**Docs to sync:**
- `docs/design/story-causality-map.md` (quest titles);
- `docs/design/character-profiles.md`;
- the voice cards `forge-smith`, `lift+klbkch`, `den-keeper+witch` and
  `yvlon+xif`.

## 7. Decisions for the user

1. **Speaker names stay** (for example "Forge-Tier Clerk"), to spare 4–5
   speaker pins per journey. Renaming him "Exam-Floor Clerk" is possible at
   that cost.
2. **On-screen Dullahan or Garuda NPCs.** Both stay off-screen or in passing
   (a jig's maker's mark, an attendant's line), because no shipped rig
   exists. Putting either on screen needs commissioned art.
3. **The trader's rig:** reuse `gnoll_traveler` (an unnamed-role rig already
   used by three unnamed NPCs), or commission one.

## 8. Next: "The Runners' Post" (#600)

A Pallass Runner's Guild office. It needs:
- per-board delivery pools, keeping Liscor's rotation byte-identical;
- user clearance for a Pallass branch (canon shows Runners and a Runners'
  lane in Pallass but no named branch by Book 17);
- a ruling on whether a second board counts as a grinding job.
