# Lyonette du Marquin — the retrofit note (reference implementation)

Her thaw is ALREADY the system: `skeleton_scene.json`'s inn entity
carries `talk_pool` (wounded pride) + `talk_pool_post`
(`requires_accomplishment: {resolved_wrong_order: 1}` → open warmth).
The retrofit is expressing that shipped seam as a stage row, zero copy
changes:

```json
{
	"npc": "lyonette",
	"talk_pool_stages": [
		{
			"id": "lyonette_thawed",
			"requires_accomplishment": { "resolved_wrong_order": 1 },
			"lines": "== the shipped talk_pool_post.lines, verbatim =="
		}
	]
}
```

Execution shape: when the stage seam (`talk_pool_stages`, ordered,
last-met-wins) lands, her `talk_pool_post` migrates to a one-entry
`talk_pool_stages` and `_talk_pool_line`'s C4 read generalizes from "one
post dict" to "walk the ordered list". C4's unit
`test_talk_pool_post_grows_pool_after_gate` becomes the stage-derivation
unit's first case (drive the REAL entity, base pool before the gate,
stage pool after) — the spec's `stages_loop` canonical then drives one
OTHER NPC base→final so both the retrofit AND the generalization are
proven.

## Optional additions (both ⚑, both default OUT)

- **Stage-2 topic, home (princess-adjacent):** her thaw shipped without
  a deeper-topic unlock. A conservative draft if the user wants one —
  hub option "You weren't always a barmaid, were you?" (requires
  `resolved_wrong_order`, hide_when a new `heard_lyonette_home` bank) →
  "No. And you may keep noticing that quietly, the way you have been.
  ...Somewhere very far east of here there is a house with too many
  rules. I set a perfect table for years before anyone taught me to
  carry one. That is all the biography on offer." — Calanfer never
  named, princess never said; the fallen-diction slip ("set a perfect
  table") does the work. HARD RAIL: the [Princess] reveal is not ours to
  spend in a talk pool; anything sharper belongs to a future arc beat.
- **Stage-2 perk:** her post-pool already offers "the good chair by the
  fire" in fiction. If the user wants it backed: a once-per-waking short
  rest at the inn (small HP restore, `entity_first_use` dedup) — the
  same seam Erin's daily meal needs, so build once, use twice. Ships
  perk-less today; adding one is a taste call, not a gap.

## Voice check (existing copy, re-read against the profile)

Shipped post-pool holds the contract (haughty→humbling, formal diction
slipping into sincerity): "I'm allowed to insist, it's practically my
inn too" — the possessive pride re-aimed at belonging. No lint findings;
nothing to fix in flight.
