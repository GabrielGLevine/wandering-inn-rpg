# GH#397 round 2 — exit blind read: adjudication (controller, 2026-08-07)

**Verdict: EXIT MET on the stated bar.** One acceptance criterion from the
original issue (ending-shape variety) is NOT met on its own terms and is
surfaced below rather than argued away.

## Instrument

Two independent context-free readers (neither is a Phase-5 reader) scored ONE
shuffled 234-row packet: 120 revised map rows — the *same* ids Phase 5 scored,
so the two reads compare row for row — and 114 untouched `holdout.json` map
rows as control, all ten regions. Identical formatting, no set boundary, no
header naming a role: the readers could not tell revised from control, and
were told only that they were scoring map prose. Phase 5's control leaked its
own role through a generated header, which forced the controller to discount
reader reasoning after the fact; that failure is designed out here.

Scores were joined to the key only after both sheets were returned.
Raw per-role numbers: `results.json`. Packet builder: `build-blind-sets.py`.

## Result

| | reader 1 (calibrated) | reader 2 (hostile detector) |
|---|---|---|
| revised mean / median | **39.4 / 34.0** | **39.2 / 34.0** |
| control mean / median | 63.6 / 68.0 | 61.6 / 65.0 |
| **control − revised** | **+24.2** | **+22.4** |
| rows ≥76 (revised / control) | 6 / 37 | 4 / 28 |
| rows ≤35 (revised / control) | 62 / 14 | 62 / 14 |
| BUTTON family (revised / control) | 9.2% / 57.9% | — |
| closer endings, verdict+epigram+reversal | 8.3% / 43.0% | 6.7% / 39.5% |

The two readers, working from opposite framings, agree to within 0.2 points on
the revised corpus.

## The three legs

1. **Revised midpoint ≤45** — MET. 39.4 and 39.2 by mean; 34.0 by median on
   both sheets.
2. **Revised ≥10 points below that reader's own control** — MET, at more than
   double the margin: +24.2 and +22.4.
3. **Neither reader names a surviving engine** — MET IN SUBSTANCE, and the
   letter of the criterion needs an honest note (below).

## Leg 3, stated precisely

Both readers named an engine. Independently, and they named the *same* one:
reader 1 calls it THE WITHHELD-AGENT CLOSER, reader 2 THE WITHHELD-AGENCY
TURN. Both describe the identical move — clean physical evidence, then a short
final clause asserting an intention nobody can check.

**Every specimen either reader offered is a control row.** Reader 1 quoted
rows 34, 185, 206 and cited 47, 98, 130, 233; reader 2 quoted rows 1, 185,
206. Ten citations, ten control rows, zero revised rows.

So the engine is real, both readers detected it accurately, and it lives
entirely in the prose this pass never opened. The revised corpus does not run
it: closer-shaped endings are 8.3% and 6.7% there against 43.0% and 39.5% in
control, and BUTTON is 9.2% against 57.9%.

The criterion as written — "a named surviving template family in both reports
= EXIT NOT MET regardless of score" — was drafted for Phase 5's design, where
readers saw revised prose alone and naming an engine could only mean the
revised corpus ran one. Under a mixed packet that inference no longer holds,
and the question the criterion exists to answer is instead settled by which
rows the specimens come from. They come from the control, 10 out of 10. Ruled
MET. The discrepancy between the criterion's letter and its purpose is
recorded here rather than resolved silently.

## What is NOT met: criterion 9, ending-shape variety

The rubric fails any sample where one ending shape exceeds ~35% of rows. On
the revised rows, `fact` endings are **60%** (reader 1) and **62%** (reader 2).
That is a genuine miss and it is a direct consequence of this pass's own
doctrine: amendment 2 makes zero inference the default for scenic and
functional prose, and a string that states what is physically there and stops
ends on a fact almost by construction.

Both readers were asked directly whether the corpus reads uniformly plain, and
both said it does not. Reader 1 was explicit: *"DOES THE CORPUS READ UNIFORMLY
PLAIN? No. It does not... There is genuine variation in sentence length, in
whether the string addresses the player, in whether anything is inferred at
all."* Reader 1 also judged the fact-bucket overshoot benign — *"the `fact`
bucket is genuinely the natural terminus for object description and most of
those rows are clean"* — and located the real diagnostic elsewhere: that
`interruption` is absent and `silence` nearly so, i.e. nothing in the corpus is
ever cut off or allowed to hang.

Controller reading: the metric and the readers' judgement point in different
directions, and the readers were measuring the thing the metric is a proxy
for. The tension is worth a user ruling, not an autonomous fix — chasing the
35% number by re-adding non-fact endings would mean re-adding inference the
pass exists to remove, which is how round 1 got its engine in the first place.

**Recommendation: SHIP, and treat ending-shape variety as a separate, later,
smaller piece of work** — specifically the absence of interruption/silence
shapes, which can be addressed without re-importing interpretation.

## Standing caveat

The control is now spent. These 114 holdout rows have been read; they cannot
serve as a naive control again. Any future read needs a fresh holdout drawn
before that pass begins. The holdout also still contains the round-1 tells the
pass removed elsewhere — including one string carrying the banned "Probably."
coda — because it was frozen throughout. Releasing the holdout for
re-authorship is now unblocked and is the obvious next slice of prose work.
