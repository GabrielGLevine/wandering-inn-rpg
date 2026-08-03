# Invrisil nobility thread — spec (#318, v0.18 lane W3)

Fable-authored 2026-08-03, in-lane, SPEC-FIRST per the W3 brief. This
document is the contract the implementation in the same branch was
written from. Read it before touching any file it names.

## 1. Narrative purpose

Issue #318's directive: *nobility is an important component of the world
we haven't represented.* v0.16 shipped the copy-level layer — the
stationer's client elevated to a Lady with a house behind her, one
oblique acknowledgment that "this city is run from a house you cannot
see from any street in it," and a single ambient bark at the
Adventurer's Rest about the Reinhart carriage. That layer is texture.
It has no verb.

This thread gives the layer a verb, in Invrisil's own dialect. The city
bible's line is binding: **Invrisil asks you to DEAL**, the quest
register is *schemes*, and *nothing is a neighbour problem; everything
is leverage.* So the nobility content is not a ball, a duel, or an
investiture. It is a **forgery** — somebody has been renting a fallen
house's name by the hour, and the house that notices everything has
noticed. The player is hired to find the hand before the card is
answered.

Emotional tone target: quiet dread with no monster in it. The threat in
this thread is *attention*. Nobody is stabbed for the name; the Lady is
frightened because a woman she has never met now knows she exists.

## 2. Magnolia-ADJACENT: the felt/seen rule

**Magnolia Reinhart never appears, is never spoken to, and is never
named by any character in this thread.** She is felt three ways, all
oblique, all at the Vol-7 advertised surface:

1. **The card.** A cream card, no crest, one line, from a hand the Lady
   has seen twice in her life. The card is the whole of the house's
   agency on screen.
2. **The carriage.** A boulevard prop the player can find once the card
   exists: the street has stopped pretending not to look, and the pink
   carriage is already three streets on. The event is the WAKE, never
   the vehicle — literally felt, never seen.
3. **The steward.** A woman who came in a carriage waits at the
   Adventurer's Rest to take the answer. She is an ORIGINAL UNNAMED
   ARCHETYPE (issue #318's own convention for minor nobles and house
   staff), not Ressa and not Reynold. She never names her mistress; her
   register is the method, not the person.

Ressa and Reynold stay off-screen entirely. Their wiki profiles are
canon-safe by date (see §3) but their portrayal bar is the highest in
the game, and #318 gates them on a canon pass this lane did not run.
Recorded as DEFERRED.

## 3. Canon pass (wiki, 2026-08-03)

Verified against https://wiki.wanderinginn.com, with the spoiler-cutoff
rule's mandatory *when-does-it-enter* leg applied to every fact:

| Fact | Source | First appears | Verdict |
|---|---|---|---|
| Lady Magnolia Reinhart, House Reinhart | `Magnolia_Reinhart` | 1.19 R | SAFE, used obliquely (never named) |
| Her estate is **in Invrisil** | `Magnolia_Reinhart` | 1.19 R | SAFE — this is why the thread works at all |
| Magnolia holds informal power over Invrisil; day to day the city is guilds and nobles infighting | `Invrisil` | 2.09+ | SAFE, and it is the thread's premise |
| Invrisil = "City of Adventurers" | `Invrisil` | 2.09+ | SAFE (already shipped in the Rest's copy) |
| The pink carriage; fastest travel in Izril short of teleportation | `Magnolia_Reinhart` | 4.06 KM | SAFE — used for the boulevard sighting |
| Ressa, [Head Maid] | `Ressa` | 1.19 R / Interlude 3 | SAFE by date, DEFERRED by portrayal bar |
| Reynold Ferusdam | `Magnolia_Reinhart` | 3.09 | SAFE by date, DEFERRED by portrayal bar |
| **"the Five Families"** as a named set | `Five_Families` | cited **7.18 M** | **REFUSED.** Volume 7, and the wiki does not resolve it inside the Book-17 slice. Spoiler rule 5 says ambiguous timing = treat as past the cutoff. The phrase appears nowhere in this thread, and no house but Reinhart is named or alluded to. |

**New canon introduced: none.** Every original element (the Lady, her
house, the scribe, the broker, the steward) is an unnamed archetype. No
house name is invented; the Lady's own house is never named on screen,
which is also the point of her shipped line about its two assets.

## 4. Thread shape

### The quest

`the_name_and_the_habit` — **"The Name and the Habit"**, region Invrisil.
The title is lifted from the Lady's own shipped line: *"My house has
exactly two assets left: its name, and the habit people have of not
looking past it."* Somebody is spending the second one.

Three beats, order-gated, each with its own location and a state change
between:

| beat | where | complete_when |
|---|---|---|
| `trace` | the stationer's — the scribe who rents the blank seal | `forged_hand_named` |
| `answer` | the mercantile alleys — the broker's rented table | `seal_block_settled` |
| `report` | the Adventurer's Rest — the steward | `house_answer_given` |

### Three-pillar parity

Parity lands on `answer`, the middle beat, and the entry beat carries a
second, smaller parity of its own so no build is walled out of starting.

| pillar | beat 1 `trace` (the scribe) | beat 2 `answer` (the broker) |
|---|---|---|
| SOCIAL | `[Charming Smile]` two-node persuade | `[Charming Smile]` two-node persuade → `block_bought_back` |
| PUZZLE/SKILL | `[Appraise Foe]` reads the blotter | `[Stealth]` lifts the block off the table → `block_lifted` |
| COMBAT | — | the broker's two hired men → `block_taken` |
| REAL-COST ALTERNATE | 8 gold for "the hour he was not working" | 30 gold, name your price for the block → `block_bought_back` |

Every route pays: a Skill, coin, or a fight. The free option on the
scribe's counter (`"Who hired the blank seal?"`) is a **signposting
line, not a solution** — he refuses it, in character, and loops back.
That is the GH#50 rule applied deliberately: the entry is discoverable
for free, the answer never is.

ANTI-AUTO-WIN (GH#64) traced: no Skill arm resolves the quest. The
scribe's persuade lands on beat 1 of 3 and the broker still has to be
dealt with; the broker's persuade lands on beat 2 of 3 and the card is
still unanswered. Both persuades are two-node chains (pitch → close),
the shipped idiom for a gate that earns itself inside the conversation.

### Resolution paths (weakest claim first, LAST MATCH WINS)

Mirrors `the_hat_stays_on`'s own ladder, which is the right register for
this city: loud < talked < unseen.

1. `block_taken` — you took it with his men on the floor. The street saw.
2. `block_bought_back` — you bought it, and the transaction is a record.
3. `block_lifted` — nobody ever knew the block moved. The house's ideal.

### The Lady's arc

Her shipped graph (`invrisil_stationer_client.json`) gains, behind
`setting_commissioned` so no shipped canonical can see a new row:

- an entry option that starts the quest (`house_card_shown`),
- `the_card` → `the_hand` → `terms_card`, her three new nodes,
- a mid-thread reaction node gated on `forged_hand_named`,
- a coda node gated on `house_answer_given`,
- three new `text_variants` on the hub, gated on counters no shipped
  fixture holds.

Her arc across the two threads reads as one movement: in I1 she pays
somebody else to say a true thing for her; here she signs her own name
to a card, in her own hand, for the first time in eleven years.

## 5. New counters

`house_card_shown`, `forged_hand_named`, `block_bought_back`,
`block_lifted`, `block_taken`, `seal_block_settled`,
`house_answer_given`, `carriage_passed`.

All follow the shipped verb conventions and freeze at the next release
cut (wi-shipping step 0).

## 6. Surfaces touched

| file | change |
|---|---|
| `data/dialogue/invrisil_stationer_client.json` | extended, gated behind `setting_commissioned` |
| `data/dialogue/invrisil_hired_scribe.json` | NEW — the stationer's scribe, beat 1 |
| `data/dialogue/invrisil_seal_broker.json` | NEW — the alley broker, beat 2 |
| `data/dialogue/invrisil_house_steward.json` | NEW — the Rest's steward, beat 3 |
| `data/quests.json` | one row appended under `<!-- v018-W3 -->` |
| `data/maps/invrisil/stationer.json` | `conversation` added to the existing `stationer_clerk` (additive; his talk_pool bark still serves first) |
| `data/maps/invrisil/mercantile_alleys.json` | `alley_seal_broker` (npc) + `broker_hands` (encounter), both gated on `forged_hand_named` |
| `data/maps/invrisil/adventurers_rest.json` | `rest_house_steward` (npc), gated on `house_card_shown` |
| `data/maps/invrisil/invrisil_boulevard.json` | `boulevard_carriage_wake` (facade prop), gated on `house_card_shown` |

Every new map row is `present_when`/`encounter_when` gated on a counter
no shipped fixture holds, so all four maps are byte-unchanged in
behaviour for every canonical that already crosses them.

**Not touched, by ruling:** `data/combatants.json`, `data/arenas.json`,
`data/items.json`, `data/acts.json`, `data/leads.json`. The fight leg
composes an EXISTING arena (`mercantile_alley`) with the EXISTING
shipped roster (`footpad_lookout` + `footpad_bruiser`) — the exact
composition already measured as `alley_footpads_t3_warrior10_solo` in
`sim_combat_batch.gd`, so no new balance cell is owed and none is added.
No reward item is granted (items.json is out of lane); the steward pays
30 gold, priced against I1's 25 and I2's 25.

## 7. Verification plan

- `data_lint`, comment census, then the unit suite: `test_dialogue`,
  `test_content`, `test_quests`, `test_reachability`, `test_sim_core`,
  `test_effect_text`, `test_copy_fit`, `test_fixture_coherence`,
  `test_acts`, `test_shipped_ids`, `test_save`, plus a headless smoke.
- `ci_sweep.sh --touching` on every changed data path, to re-gate every
  crossing canonical at its pinned seed.
- Three NEW canonicals walking the thread end to end, one per pillar:
  `invrisil_house_name_talk`, `_skill`, `_fight`, each with its own
  fixture. Headless first, then windowed, SERIAL, LAST — including a
  windowed register read of the Lady's new nodes.

## 8. Deferred (recorded, not done)

- Ressa / Reynold on screen — needs the #318 canon pass on portrayal.
- Magnolia's estate as a visitable surface — a region-scale ask, not a
  thread-scale one.
- A `leads.json` row for the thread: `_validate_leads` requires every
  gate counter to be a SHIPPED id, and these counters do not freeze
  until the next release cut. The row belongs in the release after this
  one; `leads.json` is out of lane besides.
