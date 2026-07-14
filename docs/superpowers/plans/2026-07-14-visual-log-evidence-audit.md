# VISUAL-LOG Wave 0: Evidence Audit Implementation Plan

> **Required skills:** `wi-running-the-machine`, `wi-machine-playtest`,
> `wi-verifying-changes`; use `wi-writing-qa-scripts` only for the temporary
> probes described below.
> **Parent:** `2026-07-14-visual-log-drain-master.md`

**Goal:** Freeze current full-resolution evidence for every open surface,
classify every item as reproduced/already-fixed/non-reproducible, and make only
audit-documentation changes.

**Architecture:** Existing canonical scripts are the primary camera routes.
Temporary probes may expose a missing angle but never become manifest entries.
All before-images are copied to a non-clobbered evidence directory. The audit
edits only `docs/VISUAL-LOG.md`, `HANDOFF.md`, and an evidence index; gameplay
files remain untouched.

---

## Task 1: Establish the evidence ledger

**Files:**

- Create: `wandering_inn_game/qa_output/visual_log_2026-07-14/README.md`
- Modify: `HANDOFF.md`

- [ ] Confirm `git status --short --branch`, current SHA, Godot 4.7, and
  available private asset overlay.
- [ ] Create the evidence README with one row for each of the twenty design
  dispositions and columns: entry, canonical/probe, screenshot path, verdict,
  mechanism/file trace, next wave.
- [ ] Record issue #113, branch `main`, base SHA, owned files, and exact next
  action in `HANDOFF.md`.
- [ ] Do not put binary evidence under version control; `qa_output` remains an
  artifact area. The README may remain untracked if `qa_output` is ignored.

## Task 2: Capture field, interaction, and map evidence

Run these scripts windowed at their canonical seed, preserving each generated
directory before any rerun:

```bash
wandering_inn_game/qa/run_qa.sh delve_skill windowed --seed=9
wandering_inn_game/qa/run_qa.sh riverfarm_talk windowed --seed=9
wandering_inn_game/qa/run_qa.sh deep_descent windowed --seed=9
wandering_inn_game/qa/run_qa.sh upstairs_walkthrough windowed --seed=9
wandering_inn_game/qa/run_qa.sh delivery_loop windowed --seed=9
wandering_inn_game/qa/run_qa.sh barracks_walkthrough windowed --seed=9
wandering_inn_game/qa/run_qa.sh guild_interior_walkthrough windowed --seed=9
wandering_inn_game/qa/run_qa.sh garden_walkthrough windowed --seed=9
wandering_inn_game/qa/run_qa.sh ruin_walkthrough windowed --seed=9
```

For each script:

- [ ] Confirm PASS and zero in-run warning/script-error lines in `result.json`.
- [ ] Read every relevant PNG at original resolution.
- [ ] Copy keepers to
  `qa_output/visual_log_2026-07-14/before/SCRIPT_NAME/`.
- [ ] Record concrete scene judgment, not merely PASS: visual hierarchy,
  grounding, collision honesty, crop/occlusion, palette family, and route
  visibility.

The expected item coverage is:

| Script | Items |
|---|---|
| `delve_skill` | dungeon trap tells |
| `riverfarm_talk` | witch/cottage overlap |
| `deep_descent` | Relc cameo absence; fissure/hearth/gnaw/warren stand-ins |
| `upstairs_walkthrough` | room zoning; Lyonette-door occlusion |
| `delivery_loop` | delivery board; board picker evidence for promotion |
| `barracks_walkthrough` | bread-stall occlusion |
| `guild_interior_walkthrough` | notice wall; board-density read |
| `garden_walkthrough` | missing diagonal coverage |
| `ruin_walkthrough` | ruin route missing central architecture |

## Task 3: Capture combat and creature evidence

**Temporary files:**

- Create/delete: `wandering_inn_game/qa/scripts/visual_probe_crab.json`
- Modify temporarily then restore or create/delete:
  `wandering_inn_game/qa/scripts/visual_probe_arena_matrix.json`

- [ ] Recreate the already-proven crab probe only if the retained
  `qa_output/visual_probe_crab` artifacts are missing. Capture the live crab
  beside `boulder` and its encounter field token; delete the probe afterward.
- [ ] Run `cisterns_fight` windowed and add two temporary screenshots around
  `ui_combat_shown`: one before autoplay and one after the first visible spider
  action. Restore the canonical JSON byte-for-byte after copying evidence.
- [ ] Run `deep_descent`, `door_chain_fight`, `crab_cull_loop`, and one current
  sewer-bat encounter windowed to judge `deep_warren`, `ruin_court`, the crab
  arena, and `sewers_nest` at their canonical pinned seeds.
- [ ] Compare Sewer Bat silhouettes against `sewers_nest` off-grid decor and
  blocked-cover props. Record which exact prop/cell competes, or close the
  item as already fixed if no current prop reads as a bat.
- [ ] Score each audited arena as `adequate` or `sparse` using the same bar:
  the board must establish biome at a glance while the tactical grid and all
  combatants remain dominant. Record exact off-grid cells proposed only for
  arenas that fail.

Expected audit finding from the demonstrated crab probe: reproduce the crab
defect because the warm salmon-brown silhouette remains distinct from the
nearby neutral-grey boulder; dialogue layout passes.

## Task 4: Audit icons and the three broad redesigns

**Files:**

- Read: `wandering_inn_game/data/skills.json`
- Read: `wandering_inn_game/data/classes.json`
- Read: `wandering_inn_game/data/combatants.json`
- Read: `wandering_inn_game/tests/test_combat_data.gd`
- Read: relevant picker/readout/blocked-cell screenshots and source traces

- [ ] Produce the exact player-visible icon target set by intersecting
  `KNOWN_ICONLESS_SKILLS` with class grants and field/AP-visible skills.
  Expected generated targets are:
  `appraise_goods`, `called_shot`, `directed_strike`, `disarm_trap`,
  `find_trap`, `flame_dart`, `flame_pillar`, `measured_words`, `open_doors`,
  `perfect_hospitality`, `piercing_volley`, and `soothing_presence`.
- [ ] Confirm `guarding_ward`, `raskghar_maul`, and `slam` are enemy-only in
  current consumers and therefore have no player hotbar/journal icon surface.
  Keep them allowlisted unless the consumer predicate itself is deliberately
  narrowed in Wave 1.
- [ ] Preserve at least one full-resolution screenshot and source trace for
  each promoted redesign: picker, field readout, and blocked-cell rendering.
  Do not file the issues yet; Wave 3 combines the before evidence with final
  affected-code/canonical lists.

## Task 5: Record audit verdicts and commit

**Files:**

- Modify: `docs/VISUAL-LOG.md`
- Modify: `HANDOFF.md`

- [ ] Under each still-open row, add a compact `2026-07-14 audit:` line with
  `REPRODUCED`, `ALREADY FIXED`, or `NON-REPRODUCIBLE`, evidence path, and the
  exact next-wave owner. Do not check reproduced rows yet.
- [ ] Check an entry now only if current evidence proves it already fixed or
  non-reproducible; name the responsible mechanism or prior commit.
- [ ] Confirm all temporary QA files are deleted/restored and no manifest or
  shipped QA surface changed.
- [ ] Run:

```bash
git diff --check
wandering_inn_game/qa/run_qa.sh load_gate headless
git status --short
```

Expected: PASS; only `docs/VISUAL-LOG.md` and `HANDOFF.md` are tracked changes.

- [ ] Commit:

```bash
git add docs/VISUAL-LOG.md HANDOFF.md
git commit -m "Audit VISUAL-LOG surfaces (#113)"
```
