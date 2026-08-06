# Blind-read rubric — GH#397 Phase 0

**Status:** the measurement instrument for acceptance criteria 2, 6 and 9.
**Applies to:** `sample-dialogue-blind.txt`, `sample-maps-blind.txt` (Phase 0
baseline) and the same views regenerated over revised prose, plus
`sample-holdout-blind.txt` — the untouched `holdout.json` rendered in the same
blind format (Phase 5 exit read).

> **Comparability of the sample and the holdout.** The holdout is drawn from
> the **same eligibility pool as the blind samples**: strings of ≥6 words, with
> protected keeps and the hand-named work list reserved out. The two views are
> therefore one population read twice — revised strings on one side, untouched
> strings on the other — and the §2/§6 procedure applies identically to both.
> The §2 sampling caveat below applies to both equally, which is the point: a
> holdout drawn from *everything* would be half-full of "Nothing there." and
> would score lower than the sample for reasons that have nothing to do with
> the rewrites. Read the holdout with the same instrument, in the same session,
> and report its numbers separately.
>
> Before trusting a Phase 5 read, confirm the holdout is actually untouched:
> `python3 qa/scripts/extract_prose.py verify-untouched --dir docs/prose-naturalization`
> exits 1 if any holdout or protected-keep string moved a byte.

---

## 1. What you are being asked

Estimate **how AI-authored this text reads to a context-free reader**, and say
**why** in terms of a fixed set of rhetorical tells.

Three things this rubric is deliberately *not*:

- **Not a provenance test.** A blind read cannot establish how any string was
  produced, and the issue forbids claiming otherwise. You are scoring
  *perceived* machine-authorship. A human writer can score 90; a generated
  line can score 10.
- **Not a quality score.** Good prose can read AI-like (fluent, balanced,
  perfectly closed). Bad prose can read human (clumsy, unfinished, flat). Do
  not let "I like this line" pull the number down.
- **Not a plainness reward.** The failure mode this project is most likely to
  create is a flat "plain fact + physical action" monoculture. Uniform
  plainness is itself a machine signature. If the revised corpus reads plain
  *and identical*, say so loudly — that is a Phase 5 red, not a pass.

## 2. Procedure

1. Read `sample-*-blind.txt` **cold, top to bottom, once.** Do not open the
   repo, `sample-key.json`, the inventory, or this rubric's tell list first.
   Context is the thing being controlled for.
2. Record a first-pass gut number per row on the first read.
3. Second pass: assign tell-family flags and adjust the number if a flag
   changes your reading. Adjustments are expected; large ones are a signal the
   gut read was responding to something the families do not name — write that
   down in §7, it is the most valuable output you can produce.
4. Only then compute corpus statistics (§6) and open the key.

The two corpora are scored **separately** and the exit target compares them:
map prose must end up no higher than dialogue.

**Sampling caveat.** Rows are drawn with `random.Random(397)` from strings of
≥6 words, so very short functional strings ("Nothing there.", "Your own bed.")
are under-represented by construction. The sample is a *judgment* instrument,
not a distribution estimate. Corpus-wide distribution questions belong to the
advisory metrics (Phase 4), not to this read.

## 3. Per-string scoring sheet

One row per numbered string:

| field | values |
|---|---|
| `row` | the number from the blind view |
| `ai_likeness` | **0–100** (see §6). Never a binary label. |
| `confidence` | `low` / `med` / `high` — how sure you are of *that number* |
| `families` | any of `NEG` `BUTTON` `OBJECT` `MOTIF` `UNIFORM` `OVERAUTH` (§5) |
| `ending_shape` | `fact` `motion` `interruption` `unresolved` `instruction` `silence` `epigram` `reversal` `verdict` `joke` |
| `keep` | `yes` if this is a peak worth protecting even at high AI-likeness |
| `note` | one clause, only when the number needs defending |

`ending_shape` is scored on **every** row, not just flagged ones. Ending-shape
*variety across the sample* is a first-class acceptance criterion (9), and it
cannot be recovered afterwards from the numbers alone.

`keep` exists because criterion 6 requires documenting intentional keeps.
A row can be `ai_likeness: 85, keep: yes` — a deliberate, earned peak. That
combination is the single most useful thing this sheet records.

## 4. The button smoke score (tooling, advisory only)

`extract_prose.py` computes a 0–5 `closer_score` per string and
`dialogue-graph-heatmap.md` ranks graphs by it. It adds points for a copular
generalisation in the final sentence, for `which from X is Y` /
`the X is the X` / `the way X does` shapes, for a negation-correction, for an
abstract closer noun, and for a short punch after a long setup.

**Do not consult it while reading, and do not treat it as ground truth.** It
exists to *rank work* — to tell Phase 2/3 which region or graph to open first —
and it is wrong in both directions constantly: it misses buttons built from
concrete nouns, and it flags plain sentences that merely contain "is the".
The issue is explicit that most of this problem is perceptual and that
optimising for detector scores is a failure mode. Where the score and your
read disagree, **your read wins** and the disagreement goes in §7.

## 5. The six tell families

Flag a family when the string exhibits it. Families are not weighted equally
and do not sum to the score — they explain it.

### `NEG` — negation/correction as a shared engine
Meaning framed as "not X; Y", "it is not X, it is Y", "X is not the same as Y",
"not a P. A Q."

Diagnostic: *does the sentence need the negated term at all?* If deleting
"not X" loses nothing but rhythm, the shape is decoration.
Corpus note: individual uses work — the problem is recurrence, so this family
is scored at the **sample** level as well as per string (§6).

### `BUTTON` — the polished closer
The passage refuses to stop on a fact and resolves into an aphorism, ominous
reversal, joke, or emotional verdict.

Diagnostic: **would it fit on a poster?** Also: does the final sentence
*re-describe* what the earlier sentences already showed, at a higher level of
abstraction? That is the button's tell, and truncating it does not fix it —
a truncated epigram is still an epigram.

### `OBJECT` — over-interpreted objects
Worn furniture, chalk marks, pegs, rope, ledgers and ash disclose a miniature
history, a personality, or the moral thesis of the location. Carried heavily
by `someone`, `somebody`, `something`, `whoever`, `whatever`.

Diagnostic: **does the visible physical evidence support the inference?**
Banked ash genuinely implies someone meant to wake the fire — that inference
is earned. A shelf does not imply that its owner "meant it to last".
Ask also: *how confident is the narrator about invisible motives?* Constant
certainty about what absent people intended is what makes a world feel
authored rather than observed.

### `MOTIF` — motif saturation
The speaker's assigned semantic field (chess/counting, scholarship/adequacy,
appraisal/price, inventory/market, hats/manners, files/shifts,
standards/forms) is demonstrated *again*.

Diagnostic: could this line have been spoken about something else, badly or
plainly? Characters differentiated at the noun level but sharing one
underlying eloquence is the flattening this family catches.

### `UNIFORM` — uniform intelligence and emotional legibility
The speaker coins a metaphor, arranges a reversal, or lands at exactly the
right emotional point regardless of who they are. Rural fragments and formal
subordination arriving at the same polished thematic resolution.

Diagnostic: is anyone in this sample allowed to be **inarticulate, wrong, or
boring**? Register-marked-but-equally-eloquent is the trap: locally distinct,
globally identical.

### `OVERAUTH` — over-authored functional prose
A hint, refusal, gate message, skill outcome or no-op carries the literary
pressure of a major discovery. Every trap, kettle, rope, crate and shelf gets
a bespoke flourish.

Diagnostic: **is this string's job to inform?** If the player needs it to know
what to do next, ornament competes with the instruction — and it spends the
contrast that real narrative moments need.

## 6. Calibrating 0–100

Anchor on these, not on an internal sense of "AI":

| band | what it means |
|---:|---|
| 0–15 | Reads specifically human. Idiosyncratic, unbalanced, or unfinished in a way that serves it. Would be hard to produce on request. |
| 16–35 | Human-reading. Plain or rough, no rhetorical architecture, no closer pressure. |
| 36–55 | Ambiguous. Competent and clean; nothing distinctively either way. |
| 56–75 | Reads machine-shaped: fluent, well-balanced, lands its ending, one or two families flagged. |
| 76–90 | Strongly machine-shaped. Multiple families, visible rhetorical geometry, closes on cue. |
| 91–100 | Template-visible. You could state the recipe that produced it. |

**Corpus-level numbers to report, per corpus:**

- midpoint estimate + plausible range (the issue's Phase 0 figures were
  dialogue 78% [65–88], map prose 94% [88–98], combined ≈85% [75–92]);
- per-family incidence (share of rows flagged);
- **ending-shape histogram** — the anti-monoculture check. A sample where one
  shape exceeds ~35% of rows fails criterion 9 regardless of the midpoint;
- share of rows scoring ≥76 and share scoring ≤35 (the tails matter more than
  the mean: the goal is *fewer jewels with more air around them*, which shows
  up as a fatter low tail, not a shifted average).

Exit target: combined ≈40% or lower, map prose no higher than dialogue, with
reviewers naming preserved high-style lines as **intentional peaks** rather
than the default register.

## 7. Disagreements and intentional keeps (required output)

Criterion 6 requires these to be documented, not resolved away.

- **Rows where your number and the smoke score disagree**, with which you
  trust and why.
- **Rows flagged `keep: yes`.** Cross-check against `protected-keeps.json`
  after unblinding: a keep you independently identified that is *not* in that
  file is a candidate addition; a protected keep you scored as flat is a
  candidate removal. Both are findings, and neither should be silently fixed.
- **Anything the six families fail to name.** The families come from a prior
  audit; they are not guaranteed complete. A tell you can describe but not
  file is the most valuable thing in this document.
- **Suspected register mismatches** — a string that reads like scenery doing
  landmark work, or a hint doing scenery work. These feed
  `inventory-classified/<region>.json`'s `demotion_candidate` queue.

## 8. Unblinding

Only after §3 and §6 are recorded: open `sample-key.json`, join row numbers to
inventory ids, and pull `file` / `field` / `speaker` / `register` from
`inventory.jsonl`. Report per-region and per-register breakdowns then — those
are the Phase 2/3 work-order inputs, and they are worthless if the read that
produced them was not blind.
