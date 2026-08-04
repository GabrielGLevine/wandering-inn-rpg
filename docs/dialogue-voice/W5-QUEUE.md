# W5 queue — written at WINDDOWN 2026-08-03, resume when usage OK

State: Tasks 1–6 committed on `voice-pass`. W4 verdicts + audit in
`report-w4.json` (52/71 FAIL). Reconciliation NOT yet done.

## Step 1 — Fable reconciliation (dispatch first, synchronous, model "fable")

Prompt (fill nothing, paste as-is):

> Adjudication task: reconcile the W4 cold-reader findings for the Wandering Inn dialogue voice pass and issue the W5 fix directive. Working directory: /Users/gabriel/wandering-inn-rpg.
>
> Read: `docs/dialogue-voice/critique-2026-08-03.md`, `docs/dialogue-voice-bible.md` (you wrote it — §5 allocations are binding), `docs/dialogue-voice/report-w4.json` (52 FAIL verdicts + budget audit).
>
> Known reconciliation facts: the auditor does not know §5 allocations. rags_inn `served` and zevara_intro `zevara_oath_two` are the two SANCTIONED sentiment-deflect keeps; riverfarm_tallyman and pisces_seal are the two SANCTIONED reveals. pisces_inn/pisces_magic sentiment-deflects and pallass_forge_smith's deflect + reveal-shape residue are UNSANCTIONED. Tell-2 pattern: rewrite agents put their one allowed button on hub nodes (banned placement) and cold readers flag wit-density beyond the one-per-graph budget. Bark template survives in crab_nest/kingslayer_den/gallery_vermin_nest per the auditor (crab_nest passed individually).
>
> Rule, per FAIL file in report-w4.json: (a) REAL — violation stands, fix required; (b) SANCTIONED — bible §5 keep, overrule the detector; (c) OVERREACH — detector counted competent prose as a tell, overrule with one line of reasoning. Then write `docs/dialogue-voice/w5-directive.md`: per REAL file, the exact nodes to touch and the fix (which button dies, which moves off a hub to the peak node, which line goes flat), grouped by cluster id from `docs/dialogue-voice/clusters.json` so one agent per cluster can execute. Global rulings up front: where the button bar actually sits (placement + density), whether wit-density alone fails a file, and the two bark files of the three that must change shape. Do not edit dialogue files. Return the directive path and a REAL/SANCTIONED/OVERREACH count.

## Step 2 — W5 rewrite wave

One agent per cluster that owns ≥1 REAL file (Workflow, default model,
sibling-blind as W2). Agent prompt = W2 template (plan Task 4 Step 2)
PLUS: "A cold reader failed your file(s). The adjudicated fix directive
is docs/dialogue-voice/w5-directive.md — your cluster's section is
binding. Fix exactly what it names; change nothing that passed."
Then: full gate (`check --baseline docs/dialogue-voice/baseline --final
--report docs/dialogue-voice/report-w5-gate.json`) must stay CLEAN.

## Step 3 — re-detect (sample, not all 71)

Cold readers (W4 prompt, plan Task 6 Step 1) on: every REAL file that
was touched, cap 25; if more, prioritize worst-lines-table files +
one per tier. Auditor re-run for budget tells. PASS bar per plan.

## Step 4 — Task 8 (W6) close per plan

Fable sample adjudication (includes any still-FAIL docket) →
wi-verifying-changes sweep → wi-machine-playtest → CHOICE-LOG/HANDOFF
→ close commit.
