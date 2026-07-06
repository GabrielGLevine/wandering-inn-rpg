# Relc Grasstongue — stage copy companion

Profile contract: loud, cocky, friendly-menacing; bored by paperwork;
genuinely kind under it. Wiki: Relc_Grasstongue (made-up skill names —
"[Relc Punch]" — are canonical humor).

## Voice-lint pass

Stage-2 pool:
- "favorite punching bag. Kidding — the dummies are my favorite." —
  friendly-menace with the insult downgraded mid-joke, his exact shipped
  register ("You gonna eat that? ...No? Shame."). PASS.
- "[Teacher] ... dock my pay for moonlighting" — the made-up-title gag is
  wiki-attested Relc humor; specific (pay, Watch), not generic. PASS.
- "you'll hear me laughing before you hear the bell" — cocky+protective in
  one concrete image. PASS.

Stage-3 pool:
- "went DOWN the creepy hole ... file a report about the hole. From
  upstairs." — respect expressed as a paperwork insult; kindness under the
  bluster, per contract. PASS.
- "Zevara smiled this week. Actual smile." — warming via observed concrete
  detail, and it cross-lights Zevara's own stage table. PASS.
- "That's new for me. Don't make it weird." — he catches himself being
  sincere and slams the door on it; earned-warmth without a named emotion.
  PASS. No triads, single em-dashes only, no banned tells.

## Warming audit

Stage 1 (deferred pool) is all swagger at a stranger. Stage 2: you're a
project he's proud of (the [Teacher] bit). Stage 3: he admits, sideways,
that trusting someone is new. Same volume the whole way — what warms is
what he's willing to let slip between the jokes ("stand still while it
lands").

## Canon anchors + flags

- **Army past (stage 2): SAFE.** Relc as ex-Liscor-army is early canon;
  Liscor's army being permanently abroad ("it just never comes home") is
  Volume 1 city-fact. Kind-under-it beat ("people I liked going into
  them") anticipates nothing later than his established war weariness.
- ⚑ **HARD FINDING — the daughter is OUT.** Wiki/Embria: first appearance
  Volume 5 (Ch 5.12), Wing Commander of the 4th Company. At our early-arc
  timeline the reveal does not exist, and canon gives no sign Liscor at
  large knows. The staged `relc_after` copy names NO family — "I left
  people in it. Some I'd still take a spear for" is true of comrades AND,
  silently, of her, so it retroactively holds up if a later milestone ever
  earns the real reveal. **Default-OUT variant** (user may swap in, ⚑):
  after "sober", add: "...And there's a family thing in it too. Not a
  sad one. Just not a today one." — warmer, still nameless; I recommend
  against even this until an arc actually uses her.

## Conditions

- `sparred_with_relc` (relc_spar on_victory) and `cleared_the_warren`
  (awakened_boss on_victory) both exist. `chatted_with_relc` is the named
  Erin/Relc pool-landing dependency (S2 measured Relc at ~22 reds — the
  widest blast radius of any NPC; his pool landing should be planned as
  its own re-path wave, not an add-on).
- ⚑ Stage-3 condition uses the neutral `cleared_the_warren` on purpose:
  `relc_joined_descent` is the warmer beat (he was THERE) but permanently
  locks stage 3 for `went_alone` players, and the gate machinery is
  AND-only (no OR row). User call, table row flagged.

## Softlock guard note

`relc_intro.json`'s meet hub keeps the ungated "Keep walking." exit; both
new options are accomplishment-hidden. New nodes loop "Back a step." →
meet, matching the file's existing warns-node pattern.
