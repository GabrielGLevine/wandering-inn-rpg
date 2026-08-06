# Cluster: riverfarm-shepherd+bark — T1 rural + exploration bark

Read `docs/dialogue-voice-bible.md` first. Supersedes
`riverfarm-hunter+bark.md` (same cluster, same frozen file ids; the character
became **A Shepherd** in #396). T1 stats carried unchanged: avg ≤8
words/sentence, max 14, no subordinate clauses, coordination only, no `;` `:`
`(` `)`.

**Antithesis (ban 1): one lifetime grant, and it is spent.** The pin is
`riverfarm_hunter.json` → `thicket_reported_rerouted`: "Fences before deer."
That node is LEGACY (`what_the_thicket_keeps` is retired for new saves), and
the grant stays pinned THERE — byte-exact, never re-sited to a live node.
Every shepherd-era string gets **zero**, including the soft form
("X moved. Mine didn't."), and including his `talk_pool` lines in
`riverfarm_village.json` (map talk is corpus text since GH#388).

**Two cohort-disjoint peaks, no third (ban 2).** The graph now holds two
unreachable-from-each-other arms:

| Cohort | Reachable arm | Its one button |
|---|---|---|
| Legacy saves (`heard_thicket_keeps`) | `thicket_*` nodes | `thicket_reported_rerouted` — "Fences before deer." + the father line (frozen) |
| Every new save | `winter_*` nodes | `winter_reported_traced` — "Wolves and me both, working round something neither of us can see." |

Nothing else in the file gets a button. Hub text, hub `text_variants`, the
map `talk_pool` and every `talk_pool_stages` line are variant/bark nodes:
ban 2 forbids a closer there outright, whatever the budget says.

## riverfarm_hunter.json

**BANNED:** Ban 7 (prose triad), `winter_brief`: "Three ways I see it." plus
three balanced route sentences — he may not announce or list the quest's
shape. The corpus's one enumeration precedent is `rags_meeting.json`'s
miscount ("Two ways… No, three."), and that is the sanctioned move: name
two, lose the third, hand it back at `winter_topic`. Ban 2, `winter_reported_watch`:
"One night bought is one night. I'll take it." — arithmetic-tautology button,
the exact shape banned at `thicket_reported_cleared` in the predecessor card;
flatten. Ban 2, `winter_reported_fold`: "He'd have said nothing and checked it
twice." — a second father-button, repeating the legacy peak's own move; the
father *fact* stays, the button dies. Ban 3, hub tv[2]: "The fires stay lit
anyway." after "Didn't figure we'd both still be standing" — sentiment-then-deflect,
and both corpus slots are spent (`rags_inn`, `zevara_intro`); the warm beat
must land and stay landed.

**Watch-list, KEEP:** "Wolves don't move ground for nothing." — field
knowledge, same class as the kept "Deer don't hold a line unless something
taught them to."; it is the traced route's hook, not a moral. "Bring your own
bandages. I've got enough of my own to worry about." — carried from the legacy
`agreed` node; respect in work terms, exactly the register. "Fires stay lit till
thaw anyway." (hub tv[3]) is the **one** carrier of the watch-fire register in
this cluster — do not multiply it into a template across nodes and barks.

**FORCED:** Avg ≤8 words/sentence. At least 1 self-repeat. At least 1 dropped
agreement ("That's the two I've got.", "Sheep is my trade"). Sentences trail
into work talk — hurdles, gate, margin, count — instead of resolving. Deleted
buttons are replaced by move 2 (hands keep working), never by truncation.

**CANON-VOICE:** Riverfarm shepherd, flock loss on his mind before mystery.
He counts sheep the way clerks count coin, and distrusts anything he cannot
walk out and look at. Respect is offered in work terms — a place at his fire,
a night stood, hurdles cut — never in speeches.

**CANON, do not re-number:** the bark pool's two thorn-killed lambs are
*inside* the hub's "Three lambs gone since spring". Three is the season's
total, two of them the thicket's. Neither figure moves.

**SAMPLE:** node `winter_brief` —
> Before: `Three ways I see it. Stand the watch with me and thin them. Rebuild the fold so they stop mattering. Or walk the sign and learn why they came. Wolves don't move ground for nothing.`
> After: `Stand the watch with me and we thin them. Or the hurdles are cut for a new fold. That's the two I've got. Wolves don't move ground for nothing.`

The announced triad dies; he counts two, and the sign he forgot comes back at
`winter_topic` ("And the sign. I near forgot the sign."). Zero facts lost —
the journal beat still enumerates all three routes, which is where the bible
says a triad belongs.

## riverfarm_thicket_patch.json

Unchanged from the predecessor card: bark-class narrator, **detail-interrupted**
shape, 2–4 sentences, no verdict closer, Eloise's-craft attribution kept
(quest-critical). The briar fight is now solo (#396 removed the ally) — the
bark still describes a hedgerow going wrong, never a companion.

## riverfarm_village.json (his map surface)

**BANNED:** Ban 1, `talk_banks.riverfarm_hunter_shared`: "The pack's ground
moved. Mine didn't." — soft antithesis on a speaker whose grant is pinned in
the legacy node. Ban 2, `talk_pool_stages` `riverfarm_shepherd_winter_answered[0]`:
"Cheap, next to lambs." — wit closer on a bark, and its "watch fires stay lit
till thaw" half was a near-verbatim twin of hub tv[3].

**FORCED:** His three post-quest bark lines each carry a different register:
habit (lambs in before dark), inference (fed elsewhere or thinner), and the
self-repeat ("First snow came and the count held. The count held.") — that
repeat is the T1 keep, do not smooth it.

**Art contract:** `wolf_sign_trail` draws `gnaw_pile` (a heap of cracked
bones). Its observe describes bone-sign, not hoof prints — the copy follows
the sprite, and any future re-sprite moves the copy with it.

**Deferred to the riverfarm region prose lane (NOT this card's scope):**
`wolf_sign_trail.toast`'s "They didn't choose these fields. They were pushed."
(narrator soft antithesis, and the displacement payload the quest needs),
`makings_tend_lamb.toast`'s "past the point that's useful and into the point
that counts", and the region's one remaining `...` ambient line. Riverfarm
prop prose has not had its #397-class pass; these three are its first three
rows.
