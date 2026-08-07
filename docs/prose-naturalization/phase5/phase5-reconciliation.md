# Phase 5 — independent blind read: reconciliation (controller, 2026-08-06)

Two independent context-free readers (no repo access; sets renamed A/B/C;
C's generated header leaked its holdout role to both — discount C-role
reasoning, not C-content scores). Set A = the frozen 120-row dialogue
sample re-rendered over revised text; Set B = the frozen 120-row maps
sample, revised text; Set C = the 227-row holdout control (untouched).
Reader 1: calibrated per the rubric. Reader 2: hostile-detector framing.
Reader 1's full 467-row score sheet: `reader1-scores.py` (re-runnable).

## Headline numbers

| set | reader 1 midpoint [range] | reader 2 midpoint |
|---|---|---|
| A (dialogue, revised) | 45 [33–57] | ≈46 |
| B (maps, revised) | 52 [42–62] | ≈58 |
| C (holdout, untouched) | 53 [40–65] | C-dlg 47.9 / C-map 62.3 |
| combined A+B | ≈47 | ≈52 [45–60] |

Original Phase-0 audit, same corpora, different auditor: dialogue 78
[65–88], maps 94 [88–98], combined 85 [75–92].

## Adjudication: EXIT NOT MET

The issue's criterion 6 asks for combined ≤40 with maps ≤ dialogue.

- Raw: combined 47–52 > 40; maps runs +7 to +12 over dialogue.
- Calibration-corrected (these readers score the UNTOUCHED corpus at
  ~50–53 where the original auditor scored it 85, so their
  40-equivalent is ≈25): the revised sets sit only 2–4 points below
  their like-for-like control subsets — far above a corrected target.
- Both readers independently reached the same structural verdict: the
  regex-visible tells are gone, but ONE RHETORICAL ENGINE survives —
  BUTTON-family closers on 36–58% of rows, the descriptor triad
  (2 concrete details + 1 interpretive clause, 16 instances), the
  affordance formula (7 instances), simile-by-type (10+), and the
  narrator's certainty about absent intent. Reader 2: "the register
  masks are convincing locally and globally identical."

## What the pass DID achieve (calibrated by the same read)

- Set A is structurally healthier than the control: 41% of rows ≤35,
  nine ending shapes, the only genuine disfluency in 467 rows, keeps
  reading as deliberate peaks (35-point gap over the default register)
  — acceptance criterion 9's shape largely holds for dialogue.
- Both readers ranked B > C > A for uniformity — i.e. revised dialogue
  reads LESS machine-uniform than untouched prose.
- Every mechanical family fell to near-zero on the touchable corpus
  (Phase 4 report), facts/QA/structure fully preserved (sweep 207/207
  at integration; every owner script green after the riverfarm pass).

## Why not another trim round now

Both readers flagged the pass's OWN fix-templates as already visible:
the one-word deflation coda (12+ instances), the inserted
self-correction (5), the stripped-twin deletion scars, B's floor of
16-with-nothing-below ("uniform plainness is itself a machine
signature"). A further trim by the same method deepens the editing
signature. The residual is precisely named — ~130 closer-template rows,
~90 over-interpreted objects, the map register doing landmark-grade
prose on kettles/pegs/shelves — and removing it means RE-AUTHORING
those rows under tightened doctrine (scenery zero-inference by default;
descriptor-triad and affordance-formula as named bans; per-file button
ceilings), which is a round-2 decision with a real taste dimension
(the issue's own danger list warns against flattening everything).

## Round-2 decision — USER'S CALL (surfaced at session close)

Option A: run round 2 under tightened doctrine (re-author the named
~220 rows; ~6 lanes + pin-sync + fresh two-reader blind read).
Option B: accept the current state as the shipped bar and re-scope the
issue's exit (criterion 6 was written against one auditor's scale; the
corpus now reads BELOW its own untouched control on every measure).
Recommendation: A, but scoped to the MAP register only (Set A is close
to done; B carries the gap), with the §2 zero-inference-default
amendment and fresh authorship rather than trimming.

## Bugs found by the read (fixed in cc59f61a)

- Pier observe carried a literal wiki citation in player-visible prose
  (both readers, independently). Fixed; 3rd holdout exclusion.
- One curly apostrophe (relc_intro). Normalized.
- Recorded, not fixed (pre-existing corpus duplication the talk-only
  dupe gate cannot see): "Low fence rail, bordering the tilled rows."
  ×3; "The bones rise and fall into step behind you." ×2 (two fields,
  identical text). Round-2 work list.
