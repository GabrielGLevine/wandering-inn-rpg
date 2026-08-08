# #397 round 2 — controller train notes (live doc)

Rulings and owed train-time fixes accumulated while the six writing
lanes run. Folded into CHOICE-LOG at the round-2 PR; this file is the
working ledger.

## Rulings

1. **Brief criterion 8's "zero round-2 ADVISORY hits on the files you
   touched" is adjudicated as: the lane's OWN strings contribute zero
   hits.** l2 proved the literal clause unreachable inside the fence —
   protected keeps and holdout strings carry button closers that alone
   exceed the per-file ceiling, and lanes may not touch them. Applies
   to all six lanes; a lane reporting this "miss" with a
   string-by-string proof of own-string zero is CLEAN. Residual hits
   on unlisted/untouchable strings are train-time inventory, not lane
   findings.

2. **l4's Relc petition ACCEPTED (controller, wave autonomy).**
   `floodplains $.entities[12].observe` stays as written: it is
   character-bearing (not the scenic register round 2 targets), bible
   §3 defends the exact ending as a MODEL, and the census matcher's
   documented 0.74 precision makes this a legible false positive.
   Removing defended peaks is the flattening danger the issue names.
   The lane's drop-in fallback (`round2-l4.json`
   `_petition.candidate_if_denied`) stays unused. §7's zero-target for
   `the way X does` records this row as its one adjudicated exception.
3. **l4's frozen-cache trade ACCEPTED**: `[5].observe` losing the
   "water can be made to bear weight" affordance line is safe — the
   hint ships verbatim in `[32].toast` and the freeze route is data
   (`freezable`); amendment 4 wins where it and the fact rule pull
   against each other AND the fact survives elsewhere in the same map.

4. **l3's four round-1 petition collisions RULED (controller).** The
   riverfarm keeps-petitions file was UNRULED round-1 leftover; the
   frozen worklist correctly included its rows. (a) mill `[5].toast`
   rewrite ACCEPTED — declared-allowance inference keeps the
   flood-record fact, anon agent + button dropped; bible §6 citation
   now dangling (owed item 1 class). (b) village `[31].locked_toast`
   rewrite ACCEPTED, petition DENIED — its ground is the affordance
   formula verbatim, superseded by amendment 4. (c) witch_hut
   `[1].on_skill_use.toast` ACCEPTED, petition MOOT after compression.
   (d) witch_hut `[5].toast` rewrite ACCEPTED, PEAK petition DENIED —
   the old close ("You decide not to work that through any further
   today") is the narrator-declining-out-loud deflection template the
   Phase-5 readers named; the rewrite keeps the beat as evidence
   ("Dust lies along the sill, unbroken."). Mark the riverfarm
   petition file RULED with these outcomes at train time.

## Owed at train time (controller)

1. **Bible §6.2 CONSEQUENCE-ANON exemplar is stale** — its quoted
   string (forge_hall `$.entities[1].locked_toast`, "Guessing here
   costs somebody a week") was on the frozen worklist (BUTTON+TRIAD)
   and l2 re-authored it. Replace the §6.2 citation or annotate it as
   historical at train time.
2. **Steam-vent twin pair half-broken** — round-1 ruling
   (`pin-deltas/pallass.json` `_accepted_as_deliberate` item 6)
   accepted forge `$.entities[3]` and market `$.entities[8]` as
   byte-identical DELIBERATELY. Only forge `[3].observe` was on the
   worklist; the observes now differ, the toasts are still twins.
   Train fix: re-author market `[8].observe`, `[8].toast`, and forge
   `[3].toast` distinctly (finish the divergence — round-2 doctrine
   outranks the round-1 acceptance), and mark ruling item 6 superseded
   in the pin-delta file's note.
3. **Affordance-family unlisted residue** (l2 report): 9 hits across
   pallass outside the frozen worklist, 4 genuine ("built to run
   hot"-class), 5 detector false-positives on measures ("tall enough
   to swallow a wagon"). Genuine ones are candidate rows for the
   drain, NOT round-2 scope creep — decide at train whether they ride
   a small controller fix commit or file as follow-up.
4. **Lane-local files must not ride to main:** every lane branch
   carries LANE-BRIEF.md + lane-rows.jsonl at its root (committed with
   the lane's work). Strip both from the train before the PR.

## Additional owed items (from reviews)

5. **§6 exemplar quote is cited in TWO places** (l2 review finding 5):
   narrator-bible §6 rule 2 AND keeps-petitions/riverfarm.json:24
   argue from the now-rewritten forge_hall locked_toast. Re-point both
   at a surviving CONSEQUENCE-ANON string when marking the riverfarm
   petitions RULED.
6. **extract_prose self-test rc=1 pre-existing** (l6): corpus 915 vs
   825 ±5% tolerance; three heuristic landmarks lack registry rows
   (mercantile_alleys [19].victory_toast + [20].open_toast,
   ruin_surface [32].open_toast — all #398-era strings). Controller:
   rule dispositions, regenerate registry, refresh the tolerance.
   Independent of round 2 but gate it before the round-2 PR (self-test
   red on main is not shippable).
7. **Deep_tunnels holdout survivor still carries "Probably." coda**
   (l6) — holdout is frozen until the blind-read control is spent;
   note for the POST-read holdout release: that string is a worklist
   row for the next pass, not this one.

8. **Corpus inflation watch (l1 review M11):** l1's 34 rows grew
   +29.6% in words (~+6.5/string). Check composed inflation across all
   188 rows at train time; if the corpus balloons, a tightening pass
   is a taste decision to surface, not an auto-fix.
9. **Mop-up candidates growing:** unlisted residue (pallass 9,
   invrisil 8, floodplains 1, riverfarm 3, liscor/inn ~7, dungeon 4)
   + boulevard `$.entities[7].dialogue[0].text` (ambient line carrying
   the exact interpretation its observe was cleaned of — the advisory
   arm skips `text` by design). Decide mop-up lane scope at train.
10. **l4 freeze-teach ruling REVISED:** the earlier acceptance was
   based on a false "nothing stranded" claim — [32].toast is
   companion-gated. Fix wave restores an ungated physical-fact freeze
   cue in [5].observe itself.

11. **Amendment-2 Skill-receipt carve-out RULED + committed** (l3
   review I4): on_skill_use/skill_uses toasts report what the Skill
   reads, no allowance spent, canon guard bounds. Resolves the
   promotion-time rule collision; retro-covers l5/l6's
   over-declarations.
12. **Matcher recall gaps recorded** (l1 I6, l3 M5): the persistence
   coda variant "and the <NP with modifiers> keeps ..." and bare
   "wants" as affordance both evade the arms. Note at promotion
   decision; the arms stay smoke, not verdicts.
13. **Sentence-shape convergence is a cross-lane risk** (l3 I3: 62%
   two-sentence → 81%; l2 review: 68%): fix waves instructed to
   rebalance. At train, measure the composed two-sentence share over
   all re-authored rows vs the 65% corpus baseline — if the pass
   TIGHTENED the distribution, that is a new mechanical tell and a
   surface for the blind read.
14. **Process note:** merged main into lane worktrees while fix waves
   were live (docs-only, read-not-write surfaces — no collision, but
   the never-edit-while-delegated rule says don't repeat it).

15. **l5 rulings folded into its fix wave:** "four stalls" leveled to
   must-fix (invented number, canon guard); Olesm "No pressure. A
   little pressure." RESTORED from baseline (pre-pass authored voice,
   census FP on character-bearing — Relc-precedent class); quoted
   in-world documents are facts (board_rumors content restored);
   net-word-reduction ordered (l5 ran +38.7%).
16. **Brief discipline correction (l5 reviewer):** test_sim_core-class
   suites signal failure via `SCRIPT ERROR|Parse Error|WARNING` grep +
   `^PASS` presence, NOT "ERROR: FAIL" (rc stays 0 AND PASS still
   prints on a broken assert). Fold into wi-verifying-changes at
   close: grep BOTH families.

17. **INCIDENT (controller, 2026-08-07 late): street.json fix-wave
   wipe + recovery.** Controller edited the Olesm string via a python
   json.dump round-trip (typography ruling: re-dash the baseline
   restore's ellipses), which reformatted the whole file; the revert
   (`git checkout --`) then discarded the l5 FIX WAVE's uncommitted
   street.json hunks — the exact shared-file wipe class
   wi-running-the-machine documents (2026-07-18). Recovery: fixer
   agent resumed to re-apply its four street edits byte-identical
   (one recorded in the pin-delta ledger, one from baseline, two from
   its context) + the em-dash ruling. Lessons re-armed: (a) NEVER
   json-reserialize a shipped map file — targeted string edit only;
   (b) `git diff <file>` and name every hunk before ANY revert of a
   file that could hold another agent's uncommitted work.

## Lane status

- ALL SIX LANDED: l1 0775c365 (34), l2 faf2e7b6 (28), l3 b32a40d0
  (26), l4 d610d430 (23+petition), l5 7335fae3 (37), l6 0808cf3a (39)
  = 187/188 rows (1 accepted petition).
- Reviews DONE: l2 (1 Critical), l4 (no Critical, stranded-teach),
  l1 (no Critical, actionability class), l3 (no Critical, skeleton
  reuse + rule collision → carve-out), l5 (1 Critical arrow
  contradiction + invented number). l6 reviewer running.
- Fix waves: l4 DONE + committed 165ec244 (train-ready).
  l1/l2/l3/l5/l6 fix waves running.
- l6 review DONE (no Critical; 4 Important: Rope-Work misdirection,
  invented "ninth turn" in the one field no arm checks, introduced
  marrow-twin phrasing, falsifiable wall-angle claim). Plate-order
  fact PROVEN true by construction; west/east _comment proven
  backwards. New mop-up candidate: wi_game.gd:951 hardcodes the
  retired "bones rise and fall" line as taken_toast's ENGINE default
  — outside the corpus, unguarded by any prose gate.

## 18. CONTROLLER RULING (train, 2026-08-07): CADENCE REBALANCE BEFORE THE BLIND READ

Composed measurement, 188 worklist rows, base a33e2cf6 vs train:

| | base | train |
|---|---|---|
| words | 4202 | 5227 (**+24.4%**) |
| 1-sentence rows | 43 | 26 |
| 2-sentence rows | 113 | **138** |
| 2-sentence share | 60.1% | **73.4%** |

The pass killed the button-closer engine and grew a NEW one: a
two-sentence fact-stop cadence on three of every four re-authored
rows. Both Phase-5 readers named "uniform plainness is itself a
machine signature" as a detectable tell, and round 1's whole lesson is
that a corpus-wide rhythm reads as authored no matter how clean each
sentence is. Shipping this to the blind read would spend the decisive
instrument on a corpus with a known defect.

RULED: a cadence rebalance wave runs BEFORE Task 4. Targets:
- 2-sentence share **≤55%** over the 188 rows (below base's 60.1%,
  because base was already mode-heavy and the pass must not merely
  restore the old shape).
- Net words **DOWN** vs the train (rebalance by CUTTING — merge or
  drop a sentence — never by padding; that fixes cadence and
  inflation with one move).
- No row may re-acquire a banned shape (button/triad/affordance/
  one-word coda) to hit the number; the advisory arms stay at zero
  attributable hits.
- Facts, pins, and untouchables are governed exactly as in the
  writing wave; ruled rows (Relc, Olesm) stay frozen.

## 19. Cadence wave attempt 1 died on the session limit; relaunched lean

Six parallel Opus rebalancers burned ~622k subagent tokens and hit the
session cap with 0 of 6 landing. c3 had partial uncommitted edits
(stashed on its branch, recoverable, unverified — DO NOT trust or
merge them without a fresh gate). Relaunch (`wwyyk82e0`) is leaner by
design: the per-lane verify agent is dropped and lanes no longer run
the full unit bar or the 230-script sweep — the controller runs those
ONCE on the composed train, which is the real gate anyway (a lane's
green attaches to its own tree). Per-lane share targets are weighted
so the worst offenders do the most work (c1 82%→45, c5 84%→45,
c4 79%→45, c6 69%→50, c3 65%→50, c2 57%→50).

Lesson worth keeping: fanning six writing agents that each run a full
verification bar is the expensive shape. Lanes should verify what only
they can (their own strings, their own pins); everything composed
belongs to the controller.

## 20. Task-4 instrument built ahead of the corpus being final

`docs/prose-naturalization/round2-read/build-blind-sets.py`. Two fixes
over Phase 5: one shuffled packet (no set boundary, so the control's
role cannot leak the way C's header did), and the revised rows are the
SAME 120 map ids Phase 5 scored, making the reads comparable row for
row. Control = 114 untouched holdout map rows, all ten regions, the
three exclusions honoured. Generated outputs are NOT committed — the
sample must be built from the final corpus at read time.
