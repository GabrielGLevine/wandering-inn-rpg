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

## Lane status

- ALL SIX LANDED: l1 0775c365 (34), l2 faf2e7b6 (28), l3 b32a40d0
  (26), l4 d610d430 (23+petition), l5 7335fae3 (37), l6 0808cf3a (39)
  = 187/188 rows (1 accepted petition). Reviews: l2 DONE (1 Critical
  self-contradiction + 6 trims + 1 semantic inference — fix wave
  RUNNING; mechanics/pins/facts all verified clean). l1/l3/l4/l5/l6
  reviewers running.
