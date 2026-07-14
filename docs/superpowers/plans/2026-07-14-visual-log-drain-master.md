# VISUAL-LOG Drain Master Implementation Plan

> **Work item:** GitHub #113
> **Design:** `docs/superpowers/specs/2026-07-14-visual-log-drain-design.md`
> **Execution skill:** Use `wi-running-the-machine` for every wave and `wi-verifying-changes` before every completion claim.
> **Status:** READY after user selects an execution mode.

**Goal:** Resolve all twenty unchecked `docs/VISUAL-LOG.md` entries with
windowed evidence, bounded fixes, or one of the three approved promoted issues,
then leave the log with zero unchecked entries.

**Architecture:** Execute four ordered, independently committed plans. Wave 0
freezes current evidence and may close stale findings. Wave 1 integrates the
art set through the sprite registry. Wave 2 changes data-driven scene staging
and one narrow field-rendering seam. Wave 3 changes bounded copy/QA, files the
three broad follow-ups, and performs composed closure. A later wave may consume
art from an earlier wave, but no earlier wave depends on later code.

**Technology:** Godot 4.7, GDScript, JSON scene/catalog data, declarative QA,
PixelLab v1/v2, shell verification scripts, GitHub CLI.

## Ordered plans

1. [Wave 0 — evidence audit](2026-07-14-visual-log-evidence-audit.md)
2. [Wave 1 — generated art](2026-07-14-visual-log-generated-art.md)
3. [Wave 2 — scene staging](2026-07-14-visual-log-scene-staging.md)
4. [Wave 3 — presentation and closeout](2026-07-14-visual-log-presentation-closeout.md)

## Twenty-item coverage map

| Original open entry | Owning plan/task |
|---|---|
| Skill icons | Wave 1, Tasks 1–2 |
| Rock crab | Wave 1, Task 4 |
| Dart slit and illusory-floor tells | Wave 1, Task 3 |
| Riverfarm witch/cottage overlap | Wave 2, Task 2 |
| Relc descent-veto cameo | Wave 2, Task 3 |
| Board/delivery picker | Wave 0 audit; Wave 3, Task 4a promotion |
| Upstairs room zoning | Wave 2, Task 4 |
| Sewer arena bat-like decor | Wave 0 combat audit; Wave 2, Task 6 |
| Delivery board | Wave 1, Task 3 |
| Small-prop player occlusion | Wave 2, Task 5 |
| Guild notice wall | Wave 1, Task 3 |
| Sparse combat arenas | Wave 0 combat audit; Wave 2, Task 6 |
| Field readout collapse/expand | Wave 0 audit; Wave 3, Task 4b promotion |
| Deep-tunnel threshold props | Wave 1, Task 3 |
| Sewer nest ledge | Wave 1, Task 3 |
| Shield Spider | Wave 1, Task 5 |
| Field blocked-cell rendering | Wave 0 audit; Wave 3, Task 4c promotion |
| Garden diagonal QA leg | Wave 3, Task 3 |
| Terrain slow-expiry text | Wave 3, Tasks 1–2 |
| Ruin route readability | Wave 2, Task 7 |

## Locked execution rules

- [ ] Work on `main`; confirm a clean tree before each wave and preserve
  unrelated user changes if the tree becomes dirty.
- [ ] Keep each wave in its own focused commit referencing `#113`.
- [ ] Before any QA rerun, copy keeper screenshots out of that script's
  clobber-prone `qa_output/SCRIPT_NAME/` directory into the matching
  `qa_output/visual_log_2026-07-14/before/SCRIPT_NAME/` or
  `qa_output/visual_log_2026-07-14/after/SCRIPT_NAME/` directory.
- [ ] Judge every changed player-facing surface in a real `windowed` run at
  full resolution. A passing JSON result is not visual acceptance.
- [ ] Stop an arm if it expands into a fourth broad mechanism. Record evidence
  and propose issue promotion instead of silently expanding scope.
- [ ] Use the fidelity-best asset available. PixelLab is the primary bespoke
  generator, not an automatic winner over a better in-hand licensed asset.
- [ ] Keep generated/redistributable winners public. If a redistribution-
  limited asset wins, follow `wi-shipping`: manifest + generated ignore block
  + private bundle release before public consumer wiring.
- [ ] Never track `potential_assets/`, API keys, raw candidate zips, or local
  generation drivers.
- [ ] Run `scripts/leak_check.sh` before every art-bearing commit.
- [ ] Keep `HANDOFF.md` current during execution, then prune shipped #113 state
  at close; it is current state, not a changelog.

## Cross-wave verification

After each wave:

```bash
git diff --check
/usr/local/bin/godot --headless --path wandering_inn_game --quit
wandering_inn_game/qa/run_qa.sh load_gate headless
```

Expected: exit 0; no parse errors, `SCRIPT ERROR`, or warnings; `load_gate`
reports PASS.

After Wave 3, run from `wandering_inn_game/`:

```bash
qa/run_qa.sh load_gate headless
qa/ci_sweep.sh
for t in tests/test_*.gd; do
  /usr/local/bin/godot --headless --path . --script "$t" || exit 1
done
/usr/local/bin/godot --headless --path . --quit
../scripts/leak_check.sh
../scripts/comment_census.py --check
```

Then run the final affected scripts windowed as listed in Wave 3. Expected:
all suites and canonicals PASS, zero in-run warnings, zero leak/comment failures,
and every final frame clears the design's clipping, occlusion, palette,
silhouette, animation, and placeholder-grade rejection bars.

Run the long `qa/ci_sweep.sh` in a persistent command session and poll it; do
not place a foreground wait longer than the collaboration update interval.

## Completion checklist

- [ ] All four linked plans are executed and committed in order.
- [ ] `docs/VISUAL-LOG.md` contains no `- [ ]` rows.
- [ ] Every original entry names its evidence, fix commit, already-fixed
  finding, or promoted issue.
- [ ] Exactly three broad follow-up issues exist: board/delivery picker,
  field-readout collapse/expand, and field blocked-cell rendering.
- [ ] Issue #113 is closed only after final composed verification.
- [ ] Final `git status --short --branch` is clean except the intentional
  ahead-of-origin commits pending user-approved push.
