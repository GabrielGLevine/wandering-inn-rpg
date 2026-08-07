# ISSUE #398 PHASE 0 — engine deltas for skill-gated areas (Codex brief)

Work THIS checkout (/tmp/wi-398, branch issue/398-skill-gated-areas).
Do NOT run any git commands — the controller commits.

Read FIRST: wandering_inn_game/AGENTS.md;
docs/superpowers/specs/2026-08-05-skill-gated-areas-design.md (§3, §5
deltas D1/D3/D4/D5, §10 kill criteria K1/K2/K4);
docs/superpowers/plans/2026-08-06-skill-gated-areas-398.md (Lane 0 +
standing constraints).

NUMBERED ACCEPTANCE CRITERIA — meet each, cite its evidence; at the end
LIST EVERY CRITERION YOU DID NOT MEET:

1. skills.json: [Power Strike] and [Piercing Strikes] gain `cuts: true`
   plus whatever field-context tag the shipped `burns`/`freezes` skills
   carry (mirror [Firefly]/[Snap Freeze]'s exact field shape).
   [Flame Jet] gains `burns: true`. No other skill rows change.
2. interactions.json: `cuts × cuttable` rows APPENDED at the tail (row
   ORDER is load-bearing — tests/test_interactions_table.gd pins it;
   prove untouched rows' order unchanged). Outcome reuses the shipped
   remove_scorch shape with row-parameterized toast/counter; add a
   sibling verb ONLY if toast/counter semantics genuinely diverge — if
   you believe they do, STOP that criterion and report the divergence
   instead of building (K2).
3. data_lint.py: `skill_gates` registry validation — spec §3 arms:
   (a) ≥2 modes with distinct mechanisms or distinct skill properties
   [HARD]; (b) class-disjointness derived from skills.json/classes.json,
   blink modes counted by blink-skill granters [HARD; K4: NO allowlist
   parameter may exist]; (c) mode carriers resolve: real cells,
   resolvable prop ids, min_range ≤ max shipped blink range [HARD];
   (d) rewards resolve to same-map entities [HARD]; (e) freezable-
   adjacent-island / burnable-blocking-line map with no skill_gates
   entry → ADVISORY. Each arm SELF-TESTED per the file's own convention
   with a prove-it-can-fail probe: synthetic bad registry → arm reds →
   revert. A lint arm that cannot fail is the audited failure mode —
   probes are not optional.
4. D3 blink-over-water: a headless QA proof (throwaway script + fixture
   under qa/, clearly marked THROWAWAY) showing a Double Step (range 2)
   cast crossing a 2-cell water gap onto a walkable landing on any
   existing map's water. If line-of-sight or any engine path refuses,
   STOP — write the finding (file:line of the refusing check) and do
   NOT edit engine code.
5. D4 M-ENDURE (`endure_damage: N` on trap props: interact offers
   push-through costing N HP, refused at HP ≤ N): implement ONLY if it
   lands as a one-arm diff in the existing interact dispatch path;
   otherwise skip and report why. If implemented: a can-fail unit or QA
   leg proving refusal at low HP AND the HP cost on success.
6. K1 byte-identity: run the shipped traversal canonicals touching
   freeze/burn/blink (find them in qa/manifest.json) at pinned seeds
   BEFORE your edits (record event streams) and AFTER — untouched
   scripts byte-identical. Any drift = stop and report.
7. Full verification: python3 wandering_inn_game/scripts/data_lint.py
   rc 0; ALL unit suites (tests/test_*.gd) rc 0 with zero
   SCRIPT ERROR|Parse Error|WARNING; criterion-6 canonicals green.
   macOS: no `timeout` — use `perl -e 'alarm N; exec @ARGV'`;
   alarm-wrap godot directly.
8. Comment economy: data ≤15.0% ceiling is TIGHT — pay for any
   `_comment` by trimming provenance prose nearby; run
   python3 scripts/comment_census.py --check and read ITS OWN exit code.

Final output: per-criterion evidence table + the not-met list + every
command run with its rc.
