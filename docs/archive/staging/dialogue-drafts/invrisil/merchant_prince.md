# merchant_prince.json — companion notes

**Narrative purpose:** the quest's true villain and its moral fork. Tone
target: a man who has never once raised his voice because money does it
for him. The spec's key line ("Do you know what reputation costs in this
city?") opens the accusation node, extended in his diction (pricing
errors, appreciation, retainers).

## THE FORK (flagged for user taste, per spec)
Both endings written, both opaque-safe (no stat/counter leaks):
- **EXPOSE** (`exposed_merchant_prince`): the player burns a fortune for a
  stranger. Coyle's ending grants him one flash of self-awareness ("he'd
  be right") — dignity in defeat, which makes the player's choice feel
  witnessed rather than just rewarded. No gold.
- **EXTORT** (`extorted_merchant_prince`): +40 gold and Coyle stays
  standing — richer city texture (his post-fork hub variant + the
  lieutenant's "mind he stays bought"). Morally paid for in flavor, never
  punished mechanically (opaque-safe).
- **OPEN — the 40 gold:** deliberately huge against the economy (charm 5,
  jerkin 24, work-day ~4). It should FEEL like a fortune; if it breaks
  the M-GEAR price curve, cut the number but keep the "removal-man's
  rate" symmetry (it's the same 40 gold his ledger shows — the extortion
  literally re-prices his own crime at cost, which is the joke).
- **OPEN — fork permanence:** both endings assume no later redemption/
  revenge content v1. The extort ending's "mind he stays bought" is a
  stage-2 hook, not a promise.

## Canon cites
- No canon names claimed. Invrisil as the City of Adventurers where
  reputation is currency is canon register; Magnolia Reinhart deliberately
  absent (spec non-goal).

## Invented / OPEN
- **"Master Coyle"** — ORIGINAL+flag (and "Coyle and Sons," "the sons are
  decorative" per the lieutenant's graph).
- "Master Hellam" (the rival) — ORIGINAL, shared with fixer.json.

## Wiring notes
- `merchant_blades` — the warehouse fight (spec: 3-roster hired blades,
  first all-human combatant family; lieutenant fields as context ally).
  start_combat sits on an `end:true` option per the rules; **on_victory
  banks `forced_confession`** (encounter lane). Re-talk then routes
  hub → cornered via the post-fight option, with the cornered
  text_variant carrying the beaten register.
- `lifted_true_ledger` — the counting-house [Observe]/hidden-safe beat
  (stealth path, map lane). `secured_testimony` — fixer.json.
- The fork's `merchant_fate_decided` is what the lieutenant's report
  requires — the quest cannot complete without visiting Coyle, on any
  path. Intentional: the villain scene is the quest's payoff.
- cornered node has NO exit option by design — you don't get to un-corner
  a man like Coyle. Rule check: both options are ungated (no hidden/
  vanishing options in the node), so the softlock guard is satisfied
  without an ungated-exit addition. If the validator objects anyway, add
  a "Let me think." goto hub option — but fight to keep the trap shut.

## Softlock audit
hub: hidden options + ungated "Just looking." ✓. accusation: hidden
options + TWO ungated ends (fight + walk away) ✓. cornered: all options
visible/ungated ✓. start_combat on end:true only ✓.
