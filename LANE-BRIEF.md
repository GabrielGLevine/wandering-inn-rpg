# GH#397 round 2 — map-register re-authorship lane

You are one of six writing lanes. Your worktree is this checkout; your
rows are `lane-rows.jsonl` at the repo root (one JSON row per string:
id, file, field_path, register, families, sources, text_sha1).

## Read order (before touching anything)
1. `docs/prose-naturalization/narrator-bible.md` — the **Round 2
   amendments** section at the top, then §2 (SCENIC) and §5 (budgets).
   The amendments OVERRIDE what they name.
2. `docs/prose-naturalization/phase5/phase5-reconciliation.md` — why
   round 2 exists (know the enemy: button closers, descriptor triad,
   affordance formula, over-interpreted objects, trim scars).
3. `wandering_inn_game/AGENTS.md` — commands + seed table.

## The job
For every row in lane-rows.jsonl: open the map file, locate the string
at `field_path`, and RE-AUTHOR it under the amended doctrine.

Numbered acceptance criteria — list every one you did NOT meet in your
final report:
1. **Fresh authorship.** Read the old string ONCE to learn its facts,
   then write from the field's job. Never trim, never lightly edit —
   a changed word count with the same skeleton is trimming.
2. **Zero inference by default** (amendment 2). Physical fact only.
   If a file on your list earns its ONE inference allowance, DECLARE
   it in your report BEFORE the rewrite appears ("file X, row Y,
   because Z") — an undeclared inference is a criterion miss.
3. **Named bans** (amendments 3–6): no descriptor triad, no affordance
   formula, ≤1 button-family closer per FILE (count your own), no
   one-word deflation codas, no inserted self-corrections.
4. **Fact payload preserved** (quest-prop rule, §2): counts, names,
   directions, prices, item/skill/quest names stay, findable in the
   same field. Spoiler bar: Book 17; write "Magical Door", never the
   Vol-9 name.
5. **Untouchables:** never edit a string whose id is in
   `docs/prose-naturalization/protected-keeps.json`,
   `protected-keeps-extra.json`, or `holdout.json` — your rows are
   pre-filtered, but if an edit would TOUCH one anyway (shared file,
   adjacent field), stop and report. Run
   `python3 wandering_inn_game/qa/scripts/extract_prose.py verify-untouched`
   BEFORE starting and AFTER finishing; both must exit 0. A nonzero
   exit = STOP and report; exclusions are controller-only.
6. **No structural edits.** Strings edited in place; no array
   reordering, no new entities, no key renames.
7. **Pin-sync.** After rewriting, grep `wandering_inn_game/qa/scripts/`
   for any OLD verbatim fragment of every string you changed
   (payload_contains pins). Re-derive each affected pin from a REAL
   run (`wandering_inn_game/qa/run_qa.sh <script> headless --seed=<N>`
   per the AGENTS.md seed table), never by hand-guessing text. Write
   the delta list to `docs/prose-naturalization/pin-deltas/round2-l4.json`
   (old→new per script).
8. **Gates green in YOUR worktree before reporting:**
   `python3 wandering_inn_game/scripts/data_lint.py` rc=0 AND zero
   round-2 ADVISORY hits (`--advisories | grep amendment`) on the
   files you touched; verify-untouched rc=0; every QA script you
   re-pinned green; the FULL unit suite green
   (run each test under wandering_inn_game/tests/ per AGENTS.md —
   grep output for "ERROR: FAIL", do not trust rc alone).
   Run verification FOREGROUND, sequentially. Never background a
   sweep and wait for a notification — it will not come.
9. **Report** (final message): rows done/skipped + why, inference
   allowances declared, per-file button counts, pin-delta summary,
   gate evidence (actual command outputs, not claims), and criteria
   not met. Do NOT commit — the controller commits.

## Traps that have bitten before
- Editing a fixture or QA script to make a pin pass is pin-gaming and
  will be caught by fixture-diff review. Re-derive from runs.
- `assert_event_logged` sees the whole run; qualify toasts by exact
  payload text.
- macOS: no `timeout` (use `perl -e 'alarm N; exec @ARGV'`).
- Read rc from the command itself, not after a pipe (`tail` eats it).
