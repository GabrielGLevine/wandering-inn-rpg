# Erin Solstice — stage copy companion

Profile contract (character-profiles.md): warm, chatty, runaway-optimist,
chess-sharp under the babble. Wiki: Erin_Solstice.

## Voice-lint pass (every line, read aloud in register)

Stage-2 pool:
- "burn soup / Kidding. Mostly." — self-interruption + concrete object. PASS.
- "basically furniture now. Nice furniture." — the doubled-back joke is her
  exact existing register ("I'm still workshopping the rest of it"). PASS.
- "one truthful compliment about my pasta" — specific humor, not "jokes". PASS.

Stage-3 pool:
- "testing a recipe on you. That came out wrong. WITH you." — the
  caught-mid-sentence correction is the warmest Erin tell in canon. PASS.
- "Lyonette hums when she scrubs now" — warming shown through a CONCRETE
  observed detail, not a named emotion; also stitches her stage to
  Lyonette's shipped thaw (same quest, two windows on it). PASS.
- "less a lot" — wrong-size words on purpose, hers. PASS. No triads, no
  em-dash chains, no over-named emotions anywhere in the set.

## Warming audit (earned, not sudden)

Stage 1 (deferred S2 pool) is friendly-to-strangers — she's Erin. Stage 2
adds FAMILIARITY (furniture, Selys gossip, standing invitations); stage 3
adds NEED ("less a lot" — she lets you see the inn weighs on her). Same
person at every step; the delta is how much she stops performing.

## Canon anchors + flags

- **Chess (stage 2): SAFE.** Core Volume 1 canon; "Olesm's been practicing
  and I still win" is literally the wiki record.
- ⚑ **Home (stage 3): otherworlder-adjacent.** Kept strictly oblique —
  "can't get there by walking, I did the math on walking" — no Earth, no
  other-world claim. The game's own GDI opener already establishes the
  Human PC as an otherworlder, so an oblique nod is consistent rather than
  a new reveal; still user-gated because it's the game's biggest secret
  surface. The "no more feelings before lunch, house rule" exit keeps her
  deflection canonical.

## Dependencies

- Stage 1 pool is the S2 deferred copy — **must land before any Erin stage
  can advance** (`chatted_with_erin` accrues only via the pool path). The
  S2 report measured Erin's pool at ~12 canonical-script reds; that
  re-path wave is the price of admission for this whole column.
- `errand_decided` (selys_delivery.json) and `resolved_wrong_order`
  (krshia_crate/lyonette_tip) both exist today.

## Softlock guard note (execution lane)

Both new hub options are accomplishment-`requires` (hidden until met);
`erin_errand.json`'s hub already carries the fully ungated "Just passing
through." exit — the guard holds. New nodes loop back via
"Back up a moment." → hub, house pattern.
