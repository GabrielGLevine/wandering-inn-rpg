# 397 Phase 2/3 orchestration design (controller, 2026-08-05)

QA-script coupling is star-shaped (inn/liscor/floodplains core; mood_sheet_*
spans 8 regions) → region lanes CANNOT own qa/scripts. Adopt the dialogue-pass
shape instead:

**Wave A — rewrite lanes (map files only, perfectly disjoint):**
1. pallass (149 strings, 16 demotion candidates, 0 landmark)
2. invrisil (125)
3. liscor (97)
4. inn (89)
5. floodplains + garden (89+12)
6. dungeon + sewers + ruin (61+48+43 — the "empty regions" lane; anon-agent
   focus, ≤15% target)
Riverfarm (134) EXCLUDED — runs after #396 merges (CHOICE-LOG ruling 3).
Each lane owns data/maps/<region>/*.json ONLY. No qa/scripts edits, no
baseline regen, no _shared_talk.json (talk banks are #388 territory, out of
scope). Deliverable per lane: rewrites + pin-delta report
(file/field/entity-id, old string → new string) + gates: data_lint,
load_gate, --touching sweep with EXPECTED pin failures enumerated and
verified pin-only (speaker/text payload, nothing structural).

**Phase 3 — dialogue lane(s), concurrent with Wave A (disjoint files):**
Top graphs by heatmap minus riverfarm_*: krshia_crate, pisces_seal,
forge_temper_golem, rags_inn, ceria_dig_camp, ksmvr_plates, pisces_magic,
krshia_inn, selys_delivery + issue-named hedault_enchanting, olesm_intro.
Whole-graph judgment per issue Phase 3 rules. Same pin-delta contract.
No dialogue baseline regen in-lane.

**Wave B — single pin-sync integrator (after all Wave A + Phase 3 merge):**
One agent owns qa/scripts/* + tests with prose pins (grep tests/ first);
applies all pin deltas; full unit bar + full sweep green.

**Controller at close:** regenerate voice-gate baselines (dialogue + maps)
on the composed tree; Phase 4 metrics lane extends dialogue_voice_gate.py
(advisory only, CAPS two-class split, sentence-length stdev report-only);
Phase 5 blind read (revised sample vs holdout, exit ≤40%).

Worktrees: each lane branches off issue/397-prose-naturalization post-bible
commit; lane branches 397/<lane>; controller merges (disjoint = trivial).
