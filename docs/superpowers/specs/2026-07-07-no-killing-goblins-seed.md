# "No Killing Goblins" — sign, narrative weave, goblin-ally runway (seed)

User directive 2026-07-07: the inn needs its iconic sign out front; the
tutorial being a goblin fight must be reconciled IN THE NARRATIVE (most
adventurers — and Erin herself — have killed goblins; the rule is about
her roof, and about who goblins could be); this opens the runway to
goblin allies (Rags) later.

## Canon (wiki-verified 2026-07-07)
- Sign wording: **"The Wandering Inn — No Killing Goblins"** (ch. 1.18:
  Erin "makes a sign for her inn"), posted "on a sign right in front of
  the inn, by the door, as well as on a dozen posters all around the inn."
- The exact-wording LOOPHOLE is canon (ch. 4.33: an adventurer reasons
  the sign "says nothing about Hobs") — the sign being argued-with is
  part of its character.
- Rags promoted the inn to goblins: "Her name is Erin Solstice. And she
  is good... And she likes Goblins."
- Companion rule exists: "No Killing Antinium."

## Part 1 — the sign (content micro-wave, NIGHT objective 7c; small)
- **Prop**: `inn_sign` beside the floodplains-side inn entrance (near
  `floodplains_inn_door` (7,5) — "right in front of the inn, by the
  door"). Sprite: check docs/asset-index.md for a wooden sign; sprites.json
  entry (SEQUENCE AFTER lane 7b releases sprites.json). Windowed-read
  mandatory (region + anchor gotchas).
- **Interact toast** (reads the sign): the sign TEXT is canon-fixed:
  "THE WANDERING INN — NO KILLING GOBLINS." Frame line staged below.
- **Observe line** (via the appraise Skill): staged below.
- Optional interior poster (decor reuse, same art smaller) — implementer
  judgment, cheap.
- QA: extend a canonical that already walks the door approach
  (tutorial_flow or title_flow's floodplains beat — trace which framing
  shot covers the door; per FIXTURE-FIRST, an extension beats a new
  script here since the route already exists) — assert the toast +
  ui confirmation; windowed shot of the sign in frame.

## Part 2 — the narrative weave (rides Part 1's dialogue touches)
The reconciliation, told in-world, never as a lecture:
- **The road is not her roof.** The tutorial fights happen ON THE ROAD,
  Watch-sanctioned, self-defense (Relc's framing already carries this).
  One Relc line at/after the spar or ambush wrap acknowledges the sign
  exists and that Erin's rule ends at her door — staged below.
- **Erin's own line** (her graph or a text_variant once the player has
  won_combat ≥ 1 — she KNOWS you've fought on the road): staged below.
  Erin is no hypocrite about it in canon; she's killed goblins and the
  rule is aspirational-forward, about what goblins could be if someone
  stopped first. Keep her line warm-stubborn, not preachy.
- Both lines voice-linted; ⚑ USER-TASTE on both (this is THE thematic
  rule of the source material — user reads before it ships? NO — per
  the night policy ship-with-⚑-open, morning pass reviews).

## Part 3 — the goblin-ally runway (design seed only, NOT tonight)
- **Counter seam**: `goblins_spared` — banked by any nonviolent
  resolution of a goblin encounter (today: the `goblin_parley` "Stand
  aside" bypass where still reachable; future: post-fight spare options).
  Pure additive accomplishment counter, zero UI until content consumes it.
- **Future spare-option design question** (escalate at implementation):
  goblin fights currently END in kills under autoplay; a "spare the last
  one" beat (combat end-state choice, or a parley trigger at low enemy
  HP) is REAL combat-flow design — its own task with harness/QA
  implications, not a rider.
- **Rags arc** (expansion-class, GOAL-CHAIN 8-adjacent): gated on
  `goblins_spared` + story position; Rags as the first goblin ally
  follows canon (she scouted/promoted the inn). Cast entry for the
  profiles-staging doc when the arc is specced. The companion "No
  Killing Antinium" rule pairs naturally with the existing Antinium
  cast plans (Ksmvr, dungeon arc).

## Staged copy (voice-linted; ⚑ USER-TASTE all four)
1. Sign interact toast:
   "A hand-painted board, letters gone bold where they were traced twice:
   THE WANDERING INN — NO KILLING GOBLINS."
2. Sign observe line:
   "The paint is newer than the post it hangs on. Somebody meant it, and
   means it still."
3. Relc line (post-spar wrap or ambush-adjacent, his register):
   "See the sign? Her inn, her rule. The road's the road — teeth are
   teeth out here. But under her roof? Don't."
4. Erin text_variant (requires won_combat ≥ 1):
   "I know what the road is like. I'm not asking you to un-fight
   anything. I'm asking you to knock first at the idea that they're all
   the same. Sign stays up."

## Sequencing
7c runs AFTER lane 7b releases data/sprites.json. Parts 1+2 together are
one small content task (prop + toasts + 2 dialogue touches + pins +
windowed). Part 3 is a seed — goblins_spared lands whenever the next
sim-touching wave is open (K4 or later), the Rags arc goes to the
GOAL-CHAIN 8 expansion queue.
