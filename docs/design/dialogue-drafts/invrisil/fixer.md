# fixer.json — companion notes

**Narrative purpose:** the informant surface (spec §2) — five one-gold
rumors that make Invrisil feel inhabited, three of which double as
quest-path hints; plus the TALK path's testimony chain. Tone target:
someone who'd do this job for free and has decided never to admit it.

## The rumor menu (what each cup buys)
| Rumor | Texture | Mechanical tease |
|---|---|---|
| footpads | alley life | STEALTH path: patrol habit/blind spot (K2 sneak hint) |
| counting_house | Coyle's operation | STEALTH path: the propped side door (infiltration hint) |
| hellam | merchant politics | TALK path: names the rival witness |
| hats | the Brothers | pure canon texture (hat on/off arithmetic) |
| door | the magic door | meta-seed for the 8a Door arrival; her "menace to my trade" objection is the joke |

All five: `requires {gold:1}` (greys visible when broke — D1 numeric gate)
+ `hide_when heard_rumor_*` (each sells once). Prices are diegetic
numerals, allowed per the D2 precedent (coin is countable, not a stat).

## Canon cites
- The hats rumor is built directly on the verified Wilovan-page line
  ("perfect gentlemen. Until the hats come off") and the canon honor code
  (take only what's owed). Street-level phrasing keeps it resident
  diction, not brochure.
- The door rumor references Erin's magic door (canon: the inn's door
  eventually links Invrisil among cities) filtered through the game's 8a
  Door-attunement seam. Kept hearsay-shaped ("if true") so it can't
  contradict either canon or our own door timing.

## Invented / OPEN
- **"Cups"** — ORIGINAL street-name+flag (earned name, matches her
  trade). Real name never given; in-register for a fixer.
- **"Master Hellam"** — ORIGINAL, shared with merchant_prince.json.
  **OPEN:** Hellam stays OFFSTAGE in this draft (Cups arranges him in one
  beat). If the quest lane wants the rival merchant as a walk-on with his
  own mini-graph, split `secured_testimony` out of `arranged` and give
  Hellam the bank — this file's chain was built so that's a two-line
  change.
- The 10-gold grease option (spec: "gold grease optional — economy sink")
  vs the free (Persuade) — note the persuade is NOT class-gated: the spec
  calls the whole path a [Diplomat] chain, but the gating policy prefers
  in-conversation logic; the persuasion here banks `persuaded_someone`
  (feeding [Diplomat] identity) rather than requiring it. **OPEN if the
  user wants a harder gate** — add `requires {class:{diplomat:1}}` to the
  persuade option (visible-locked) and the 10-gold cup becomes the
  classless route.

## Wiring notes
- `secured_testimony` is what merchant_prince.json's testimony
  confrontation requires; `fixer_will_testify` is the chain's midpoint.
- Her `friendly_line`/`observe` entity fields (spec: "observe/friendly-
  rich") are NOT in this file — pool drafts in pools/talk_pools.json;
  observe/friendly lines are an entity-data task (suggested observe:
  "A tea-tray harness worn shiny at the left shoulder — she pours
  right-handed and listens left-eared. The cups are chipped. The ears
  are not.").

## Softlock audit
Hub: many hidden/gold-locked options + ungated "Just the tea today."
(goto → ungated end) ✓. balk keeps an ungated back-out ✓. No
start_combat ✓.
