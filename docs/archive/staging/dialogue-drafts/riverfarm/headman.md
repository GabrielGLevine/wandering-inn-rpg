# headman.json — companion notes

**Narrative purpose:** quest giver + the village's emotional barometer.
His arc (suspicion → shame → half-swallowed apology) is the quest's B-plot;
the spec's key line ("We don't truck with witches. …We didn't USE to.")
opens the give node.

## Canon cites
- **Riverfarm's canon headman-figure is Prost** (Mister Prost, later
  Laken's [Steward]). Deliberately NOT used: Prost is welded to the Laken
  arc, which the spec rules out of v1 scope, and putting him here without
  Laken would contradict canon staging. **Speaker "Aldern" = ORIGINAL+flag.**
  If the user prefers the canon anchor anyway, a rename is one field —
  but re-check Prost's wiki page first (voice is gruff-loyal, close to
  this register).
- "Everyone's something these days" + the whistling-[Class] joke leans on
  canon's everyone-has-a-class world rule — resident diction, no
  travel-brochure framing.
- Arrival framing "through the door-magic, from the Drake city" matches
  the spec's Door-attunement arrival (8a seam).

## Invented / OPEN
- **Reward: 8 gold** village purse — economy-sized guess (two work-days).
  OPEN.
- The two-failed-envoys gag (tea / engaged-to-be-married) — original;
  establishes the witch as charming, not sinister, before the player
  climbs the hill. The engagement is a dangling thread ON PURPOSE (future
  pool line fodder). Flag if unwanted.
- "He declines the name" in the suspicion node is a deliberate design
  choice: it keeps the charmed-villager reveal as the PLAYER's discovery
  (charmed_villager.json), and it characterizes him (a headman managing
  his own temper). If the quest lane wants the headman to point at Tam
  instead, that node needs a rewrite — flag.

## Wiring notes
- The give option banks `heard_of_the_blight` + starts
  `the_price_of_a_favor` — the witch's spec-key hub variant gates on it.
- `reported_blight_lifted` is the quest's suggested terminal beat.
- Positive-gold effect caveat: same as hermit_antler_order.md — verify
  `{"gold": 8}` grant semantics at wiring.

## Softlock audit
Hub: hidden options + ungated exit ✓. give node has no hidden/vanishing
options (both options ungated) ✓. No start_combat ✓.
