# Regional Kits Phase 0 — Lane C (wiring) Implementation Plan

> Status: **ACTIVE**
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the frame-count pins out of `tests/test_sprite_registry.gd` into a data fixture, and ship `tools/wire_asset.py` and `tools/fill_kit.py` so a pool candidate becomes a registered sprite (and a kit-pool member) with one command instead of ~7 hand edits — without changing any shipped map (issue #607).

**Architecture:** Three deliverables on branch `issue/607-lane-c`. (1) `qa/fixtures/sprite_frame_counts.json` is generated once by the test's own `_build_expected_counts` and the test then reads it. (2) `tools/wire_asset.py` builds an in-memory `WirePlan` (file copies + text edits with before/after), proves it, and either prints the diff (`--dry-run`) or applies it; every write is idempotent and `sprites.json` is spliced, never reserialized. (3) `tools/fill_kit.py` (Wave 2) queries `docs/asset-candidates.json`, filters, renders a contact sheet, wires picks through `wire_asset`, splices `data/kits.json`, and logs shortfalls. Both tools take `--repo-root` so pytest runs them against a synthetic game tree.

**Tech Stack:** Python 3.12 + Pillow 12 (tools and `scripts/tests` pytest 9), Godot 4.7 GDScript headless unit (`tests/test_sprite_registry.gd`), bash gates (`scripts/preflight.sh`, `scripts/leak_check.sh`).

**Spec:** `docs/superpowers/specs/2026-10-08-regional-kits-design.md` (§4.2 Lane C wiring, §4.3 generation list) and the plan index `docs/superpowers/plans/2026-10-08-regional-kits-phase0.md` (contracts C5, C7, C8, C9 — used verbatim below).

## Global Constraints

- Branch `issue/607-lane-c` from `issue/607-kits-foundation` (itself from `main` at `7155db91`), in its own worktree `/private/tmp/wi-607-c`. Copy the private overlay in before any Godot gate (HANDOFF "Commands and environment"). Run every command from the worktree root.
- **No player-visible change in Phase 0.** No map JSON gains a `@` reference; no real candidate is wired on this branch (real-tree runs are `--dry-run` only). `data/kits.json` is lane A's file; lane C only edits it through `fill_kit` in tests or in later phases.
- **Lane C owns:** `tools/wire_asset.py`, `tools/fill_kit.py`, `wandering_inn_game/tests/test_sprite_registry.gd`, `wandering_inn_game/qa/fixtures/sprite_frame_counts.json`, `docs/art-generation-list.md`, `docs/art-bundle-pending.md`, `scripts/tests/test_wire_asset.py`, `scripts/tests/test_fill_kit.py`, `scripts/tests/wi_fake_tree.py`. Two touches outside that list are unowned by A/B and necessary: one `SKIP` row in `wandering_inn_game/tests/test_fixture_coherence.gd` (it applies every `qa/fixtures/*.json` as a save) and one message string in `scripts/scaffold_consolidation.py:536`. Never touch lane A files (`src/core/scene_catalog.gd`, `scripts/data_lint.py`, `scripts/wi_kits_lib.py`, `src/world/world.gd`, `data/biomes.json`) or lane B files (`tools/slice_atlases.py`, `tools/asset_candidates.py`, `tools/asset_index.py`).
- **Paths:** `tools/` and `docs/` at repo root; `scripts/`, `qa/`, `data/`, `src/`, `tests/`, `assets/` under `wandering_inn_game/`; pytest suites at repo-root `scripts/tests/` (preflight runs `python3 -m pytest -q scripts/tests` in its fast tier, so new suites must run in seconds and need no `potential_assets/`).
- **Assets and licensing:** never track `potential_assets/` or any `assets_manifest.json` path; `scripts/leak_check.sh` is authoritative. Pack art is wired only as a `region` row on a pack sheet already present under `wandering_inn_game/assets/`; loose pack copies are never written into `assets/`. No private bundle release. Owned PixelLab output is user-owned and redistributable (provenance goes in `assets/LICENSES/v019-owned-art-provenance.txt`).
- **Shipped mixed-format JSON** (`data/sprites.json`, map JSON) is edited surgically (`wandering_inn_game/scripts/splice_json.py` primitives). `data/kits.json` likewise. The fixture `qa/fixtures/sprite_frame_counts.json` is lane C's generated file and is kept in canonical form `json.dumps(obj, indent=1, sort_keys=True) + "\n"`.
- **Hang trap:** a failed `assert` in a headless `--script` run hangs until `WITestWatchdog` quits with rc 1 after 60 s. Keep the test's existing `assert` pattern; never replace it with `push_error`/`quit` because the whole suite relies on the watchdog contract.
- **Evidence:** preserve exit codes and the `^PASS` marker; reject `WARNING|SCRIPT ERROR|Parse Error|ERROR:`; never pipe a gate into `head`/`tail`. Comment ceilings: `python3 scripts/comment_census.py --check` (GD 24%, JSON 18%).
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- C9 verbatim: `python3 tools/wire_asset.py <candidate_path>… --id <sprite_id> [--kind prop] [--fallback <owned_sprite_id>] [--dry-run]`; a pack slice resolves to the bundled game sheet by matching `sheet_sha256` against the files under `wandering_inn_game/assets/`; nothing matches → exit 3 and print `BUNDLE-PENDING <source_sheet>`. `python3 tools/fill_kit.py <region> <role> --need N [--kind <tag>] [--contact-sheet out.png] [--select id,id,…]`; shortfall → one row in `docs/art-generation-list.md`; bundle-pending → one row in `docs/art-bundle-pending.md`.
- C7 verbatim: fixture format `{"_comment": "...", "counts": {"<sprite_id>/<anim>": <int>, …}}`; the test reads it instead of `_build_expected_counts`; a missing key still fails the assert at `:23-24`.
- C8 verbatim (slice rows): `{"path": "potential_assets/…/_sliced/<stem>/<stem>__x{X}_y{Y}_w{W}_h{H}.png", "kind": "prop", "targets": [...], "verdict": "UNREVIEWED", "notes": "", "source_sheet": "potential_assets/…/<sheet>.png", "region": [X, Y, W, H], "sheet_sha256": "<hex>", "method": "...", "has_shadow": false, "size_class": "S|M|L|XL", "label_confidence": 0.0}` inside `{"assets": [...]}` at `_sliced/<sheet-stem>/SLICES.json`.
- C5 (lane A, Wave 2 import): `wandering_inn_game/scripts/wi_kits_lib.py` exposes `load_kits(game_root: Path) -> dict`, `map_region(map_path: Path) -> str`, `resolve_map(map: dict, map_id: str, region: str, kits: dict) -> dict`, `resolve_all(game_root: Path) -> dict[str, list[dict]]`. `fill_kit` codes against these names only.

## Review Focus

1. **A non-save JSON file in `qa/fixtures/` is applied as a save.** `tests/test_fixture_coherence.gd:216-224` lists every `qa/fixtures/*.json` and runs `WISave.apply` on it; `sprite_frame_counts.json` would fail "malformed save shape" and turn `preflight --full` red. Pinned in Task 2 (SKIP row + the unit run).
2. **Godot parses JSON numbers as floats.** `expected_counts.get(key, -1)` now yields `4.0`, and `actual == expected` must still compare as ints; a fixture row written as `4.0` or `"4"` by a careless tool must be refused. Pinned in Task 2 (the `int()` cast and the migrated unit passing) and Task 4 (`fixture_with` rejects non-integer counts).
3. **Re-running after a partial failure.** If the PNG copy landed but `sprites.json` did not, the second run must complete the wiring rather than refuse "sheet exists". Pinned in Task 4 (`test_resumes_after_partial_copy`).
4. **Pack directories carry spaces and dots** (`Pixel Crawler - Free Pack 2.1`), so slice paths, SLICES.json `path` matching and the bundle-pending markdown row must survive them. Pinned in Task 6 (the fake tree's slice lives under exactly such a name).
5. **`fill_kit --select` with a bad number must wire nothing.** A selection outside the numbered list (or a duplicate) must fail before the first `wire_asset` call, or the tree is half-wired with no kits.json row. Pinned in Task 11 (`test_select_validation_wires_nothing`).

---

## File map

| File | Responsibility |
|---|---|
| `wandering_inn_game/qa/fixtures/sprite_frame_counts.json` | C7 pin table, canonical JSON, generated once (Task 1), appended by `wire_asset` |
| `wandering_inn_game/tests/test_sprite_registry.gd` | reads the fixture (`:7`, `:23`), function body `:254-958` deleted (Task 2) |
| `wandering_inn_game/tests/test_fixture_coherence.gd:5-9` | `SKIP` row for the fixture (Task 2) |
| `scripts/scaffold_consolidation.py:536` | message string now points at the fixture (Task 2) |
| `docs/art-generation-list.md`, `docs/art-bundle-pending.md`, `docs/DOC-MAP.md` | §4.3 list, bundle-pending log, map row (Task 3) |
| `scripts/tests/wi_fake_tree.py` | synthetic repo tree for pytest (Task 4, extended in Task 9) |
| `tools/wire_asset.py` | C9 wiring CLI (Tasks 4–7) |
| `scripts/tests/test_wire_asset.py` | pytest for wire_asset (Tasks 4–7) |
| `tools/fill_kit.py` | C9 pool-first fill CLI, Wave 2 (Tasks 9–12) |
| `scripts/tests/test_fill_kit.py` | pytest for fill_kit (Tasks 9–12) |

Wave 1 = Tasks 1–8. Wave 2 (after lane A's `wi_kits_lib.py` and `data/kits.json` are merged into `issue/607-kits-foundation` and rebased into this branch) = Tasks 9–12. Task 13 gates close the lane.

---

### Task 1: Generate the frame-count fixture from `_build_expected_counts` (Wave 1)

**Files:**
- Modify: `wandering_inn_game/tests/test_sprite_registry.gd:4-7` (temporary dump branch; removed in Task 2)
- Create: `wandering_inn_game/qa/fixtures/sprite_frame_counts.json`

**Interfaces:**
- Produces: the fixture file in C7 format, canonical form `json.dumps(obj, indent=1, sort_keys=True) + "\n"`, every value an `int`, keys `"<sprite_id>/<anim>"`. Also the raw dump at `$SCRATCH/frame-counts-dump.json` kept for the Task 2 equivalence proof.

- [ ] **Step 1: Set up the worktree and scratch dir**

```bash
cd /Users/gabriel/wandering-inn-rpg
git fetch origin
git worktree add /private/tmp/wi-607-c -b issue/607-lane-c issue/607-kits-foundation
cd /private/tmp/wi-607-c
export SCRATCH=/private/tmp/claude-501/-Users-gabriel-wandering-inn-rpg/51756bad-a97d-4799-b968-ee7d2ae6c8c9/scratchpad/lane-c
mkdir -p "$SCRATCH"
# private overlay (HANDOFF "Commands and environment"); the bundled pack sheets must be present for the registry unit
rsync -a --ignore-existing /Users/gabriel/wandering-inn-rpg/wandering_inn_game/assets/ wandering_inn_game/assets/
/usr/local/bin/godot --headless --path wandering_inn_game --import > "$SCRATCH/import.log" 2>&1; echo "rc=$?"
grep -cE 'SCRIPT ERROR|Parse Error' "$SCRATCH/import.log"
```
Expected: `rc=0`, grep prints `0`.

- [ ] **Step 2: Add the one-shot dump branch to the test**

Edit `wandering_inn_game/tests/test_sprite_registry.gd` so `_init` begins:

```gdscript
func _init() -> void:
	WITestWatchdog.arm(self)
	## One-shot C7 fixture generator (removed in the next commit): dumps the
	## hand-written table so qa/fixtures/sprite_frame_counts.json is exact.
	var dump_to := OS.get_environment("WI_DUMP_FRAME_COUNTS")
	if dump_to != "":
		var out := FileAccess.open(dump_to, FileAccess.WRITE)
		assert(out != null, "cannot open dump path: " + dump_to)
		out.store_string(JSON.stringify({"_comment": "", "counts": _build_expected_counts()}, "\t", true) + "\n")
		out.close()
		print("PASS: dumped frame counts to " + dump_to)
		quit(0)
		return
	var catalog: Dictionary = _load_json("res://data/sprites.json")
	var expected_counts: Dictionary = _build_expected_counts()
```

- [ ] **Step 3: Run the dump**

```bash
WI_DUMP_FRAME_COUNTS="$SCRATCH/frame-counts-dump.json" perl -e 'alarm 120; exec @ARGV' /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_sprite_registry.gd > "$SCRATCH/dump.log" 2>&1; echo "rc=$?"
grep -c '^PASS: dumped' "$SCRATCH/dump.log"; grep -cE 'WARNING|SCRIPT ERROR|Parse Error|ERROR:' "$SCRATCH/dump.log"
```
Expected: `rc=0`, `1`, `0`.

- [ ] **Step 4: Canonicalize into the fixture**

```bash
python3 - <<'EOF'
import json, os, pathlib
raw = json.loads(pathlib.Path(os.environ["SCRATCH"], "frame-counts-dump.json").read_text())
counts = {}
for k, v in raw["counts"].items():
    assert float(v).is_integer() and "/" in k, (k, v)
    counts[k] = int(v)
fixture = {
    "_comment": ("Frame-count pins, '<sprite_id>/<anim>': frames. Generated once from "
                 "tests/test_sprite_registry.gd::_build_expected_counts (2026-10-08); "
                 "tools/wire_asset.py appends; the test fails on a missing key. "
                 "Canonical form: json.dumps(indent=1, sort_keys=True)."),
    "counts": dict(sorted(counts.items())),
}
out = pathlib.Path("wandering_inn_game/qa/fixtures/sprite_frame_counts.json")
out.write_text(json.dumps(fixture, indent=1, sort_keys=True) + "\n", encoding="utf-8")
print(len(counts), "pins")
EOF
```
Expected: `N pins` with N ≥ 635 (every `(sprite_id, anim)` pair in `data/sprites.json` has a key today, and there are 635 animation records; inert pins such as `wilovan/cast` make N larger).

- [ ] **Step 5: Prove the fixture equals the function's output (key AND value set)**

```bash
python3 - <<'EOF'
import json, os, pathlib
raw = json.loads(pathlib.Path(os.environ["SCRATCH"], "frame-counts-dump.json").read_text())["counts"]
fix = json.loads(pathlib.Path("wandering_inn_game/qa/fixtures/sprite_frame_counts.json").read_text())["counts"]
assert {k: int(v) for k, v in raw.items()} == fix, "fixture != _build_expected_counts()"
cat = json.loads(pathlib.Path("wandering_inn_game/data/sprites.json").read_text())
need = {f"{sid}/{anim}" for sid, e in cat.items() if isinstance(e, dict) for anim in e.get("animations", {})}
missing = sorted(need - set(fix))
print("EQUIVALENT", len(fix), "pins; catalog keys missing from fixture:", missing)
EOF
```
Expected: `EQUIVALENT <N> pins; catalog keys missing from fixture: []`.

- [ ] **Step 6: Commit (fixture + the generator branch, so the generation is reproducible at this SHA)**

```bash
git add wandering_inn_game/qa/fixtures/sprite_frame_counts.json wandering_inn_game/tests/test_sprite_registry.gd
git commit -m "test: generate qa/fixtures/sprite_frame_counts.json from _build_expected_counts (C7)

One-shot dump branch in test_sprite_registry.gd (WI_DUMP_FRAME_COUNTS) wrote
the table verbatim; canonicalized to json.dumps(indent=1, sort_keys=True).
Equivalence: dump == fixture, every sprites.json animation key present.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Switch `test_sprite_registry.gd` to the fixture and delete the table (Wave 1)

**Files:**
- Modify: `wandering_inn_game/tests/test_sprite_registry.gd:4-24` (read fixture, drop dump branch), delete `:254-958` (`_build_expected_counts`), keep `_facings`, `_assert_expected_region`, `_assert_biome_tiles_build` and every other assertion
- Modify: `wandering_inn_game/tests/test_fixture_coherence.gd:5-9` (`SKIP`)
- Modify: `scripts/scaffold_consolidation.py:536-538`

**Interfaces:**
- Consumes: fixture from Task 1.
- Produces: the missing-key contract — `assert(expected >= 0, "no expected frame count for <id>/<anim>")` at the same site, now reading the fixture.

- [ ] **Step 1: Replace the head of `_init` (drop the dump branch, read the fixture)**

```gdscript
func _init() -> void:
	WITestWatchdog.arm(self)
	var catalog: Dictionary = _load_json("res://data/sprites.json")
	## C7: frame-count pins live in data (tools/wire_asset.py appends them).
	## A sprite animation without a key here is a hard failure below.
	var fixture: Dictionary = _load_json("res://qa/fixtures/sprite_frame_counts.json")
	assert(fixture.get("counts") is Dictionary, "sprite_frame_counts.json needs a top-level counts dict")
	var expected_counts: Dictionary = fixture["counts"]
```

and at the former `:23` (JSON numbers parse as floats, so cast):

```gdscript
				var expected: int = int(expected_counts.get("%s/%s" % [resolved, anim_name], -1))
				assert(expected >= 0, "no expected frame count for %s/%s" % [resolved, anim_name])
```

- [ ] **Step 2: Delete the function body**

```bash
s=$(grep -n '^func _build_expected_counts' wandering_inn_game/tests/test_sprite_registry.gd | cut -d: -f1)
e=$(grep -n '^func _facings' wandering_inn_game/tests/test_sprite_registry.gd | cut -d: -f1)
echo "deleting lines $s..$((e-1))"
sed -i '' "${s},$((e-1))d" wandering_inn_game/tests/test_sprite_registry.gd
grep -c '_build_expected_counts' wandering_inn_game/tests/test_sprite_registry.gd
```
Expected: `deleting lines 265..971` (the original `:254-958` shifted by Task 1's 11 inserted lines plus the two blank lines before `func _facings`; verify `s` is the `func _build_expected_counts` line and `e-1` the blank line before `func _facings`), then `0`. The `v017-L4` comment block (`:614-639` originally) goes with the function; its three pins now live in the fixture as plain rows.

- [ ] **Step 3: Add the `SKIP` row in `test_fixture_coherence.gd`**

```gdscript
const SKIP := {
	"v1_format": "pre-v2 save format, deliberately REJECTED by WISave.apply (test_save.gd's own migration-rejection proof) -- not a loadable story position at all",
	"v2_format": "pre-v3 migration INPUT (consumed by _migrated(), never applied verbatim) -- not itself a playtest destination",
	"dp2_fixwave_absolute_start": "a deliberately MID-ANOMALY soft-lock repro (found_spider_silk banked before its posting was ever accepted), explicitly 'NOT registered in qa/manifest.json' per its own _comment -- its incoherence IS its subject",
	"sprite_frame_counts": "not a save: the C7 frame-count pin table tests/test_sprite_registry.gd reads (regional kits Phase 0); tools/wire_asset.py appends rows to it",
}
```

- [ ] **Step 4: Repoint the scaffold message**

In `scripts/scaffold_consolidation.py` replace the string at `:536-538`:

```python
		"qa/fixtures/sprite_frame_counts.json -- a frame-count pin per new sprites.json "
		"entry (tools/wire_asset.py appends it; tests/test_sprite_registry.gd fails on a "
		"missing key), and the icon PNG must exist (tools/sync_assets.py::_draw_placeholder "
		"needs a NEW shape, not a recolour).",
```

- [ ] **Step 5: Run the two units and the python suites**

```bash
perl -e 'alarm 300; exec @ARGV' /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_sprite_registry.gd > "$SCRATCH/unit-registry.log" 2>&1; echo "rc=$?"
grep -c '^PASS: sprite registry catalog builds SpriteFrames' "$SCRATCH/unit-registry.log"; grep -cE 'WARNING|SCRIPT ERROR|Parse Error|ERROR:' "$SCRATCH/unit-registry.log"
perl -e 'alarm 300; exec @ARGV' /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_fixture_coherence.gd > "$SCRATCH/unit-coherence.log" 2>&1; echo "rc=$?"
grep -c '^PASS' "$SCRATCH/unit-coherence.log"; grep -cE 'WARNING|SCRIPT ERROR|Parse Error|ERROR:' "$SCRATCH/unit-coherence.log"; grep -c 'sprite_frame_counts' "$SCRATCH/unit-coherence.log"
python3 -m pytest -q scripts/tests/test_scaffold_consolidation.py
```
Expected: registry `rc=0`, `1`, `0`; coherence `rc=0`, `1`, `0`, `0` (the fixture is skipped, never named as a failure); pytest green.

- [ ] **Step 6: Prove the missing-key contract still fails (hang trap: bounded by the watchdog)**

```bash
cp wandering_inn_game/qa/fixtures/sprite_frame_counts.json "$SCRATCH/fixture.bak"
python3 - <<'EOF'
import json, pathlib
p = pathlib.Path("wandering_inn_game/qa/fixtures/sprite_frame_counts.json")
d = json.loads(p.read_text()); del d["counts"]["door/idle"]
p.write_text(json.dumps(d, indent=1, sort_keys=True) + "\n")
EOF
perl -e 'alarm 120; exec @ARGV' /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_sprite_registry.gd > "$SCRATCH/missing-key.log" 2>&1; echo "rc=$?"
grep -c 'no expected frame count for door/idle' "$SCRATCH/missing-key.log"; grep -c '^WATCHDOG' "$SCRATCH/missing-key.log"; grep -c '^PASS' "$SCRATCH/missing-key.log"
cp "$SCRATCH/fixture.bak" wandering_inn_game/qa/fixtures/sprite_frame_counts.json
git status --porcelain wandering_inn_game/qa/fixtures/
```
Expected: `rc=1` after ~60 s, `1`, `1`, `0`; the final `git status` line is empty (fixture restored).

- [ ] **Step 7: Re-prove equivalence against the Task 1 dump and check comment ceilings**

```bash
python3 - <<'EOF'
import json, os, pathlib
raw = json.loads(pathlib.Path(os.environ["SCRATCH"], "frame-counts-dump.json").read_text())["counts"]
fix = json.loads(pathlib.Path("wandering_inn_game/qa/fixtures/sprite_frame_counts.json").read_text())["counts"]
assert {k: int(v) for k, v in raw.items()} == fix
print("EQUIVALENT", len(fix))
EOF
python3 scripts/comment_census.py --check; echo "rc=$?"
```
Expected: `EQUIVALENT <N>` (same N as Task 1), census `rc=0`.

- [ ] **Step 8: Commit**

```bash
git add wandering_inn_game/tests/test_sprite_registry.gd wandering_inn_game/tests/test_fixture_coherence.gd scripts/scaffold_consolidation.py
git commit -m "test: sprite registry reads qa/fixtures/sprite_frame_counts.json (C7)

_build_expected_counts deleted (705 lines); the missing-key assert at the
same site still fails (proved: door/idle removed -> assert + WATCHDOG rc=1).
test_fixture_coherence skips the non-save fixture.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Create `docs/art-generation-list.md` and `docs/art-bundle-pending.md` (Wave 1)

**Files:**
- Create: `docs/art-generation-list.md`
- Create: `docs/art-bundle-pending.md`
- Modify: `docs/DOC-MAP.md:23` (add one row after the asset-discovery row; keep `Last verified: **2026-08-11**` untouched — `scripts/check_doc_drift.py` greps it)

**Interfaces:**
- Produces: the exact header texts, which `tools/wire_asset.py` (`BUNDLE_PENDING_HEADER`) and `tools/fill_kit.py` (`GENERATION_LIST_HEADER`) embed verbatim so a missing file is recreated identically. Column rows: generation list `| region | role | have (ids) | need | what the pool lacked | base sprite | status |`; bundle pending `| date | source_sheet | candidate | sprite_id | region |`.

- [ ] **Step 1: Write `docs/art-generation-list.md`**

```markdown
# Art generation list (living)

Rows are PixelLab generation requests the asset pool could not fill. Nothing
here is generated until the user approves a batch (regional kits spec §4.3,
Phase 3). `tools/fill_kit.py` appends a row when a role's selection falls short
of `--need`; `what the pool lacked` is the `--lacked` text the selecting agent
wrote after the pool read.

Insertion: tail — append rows at the end; one open row per (region, role) is
updated in place; a row closes by setting status to `done <sprite ids>` in the
batch PR, never by deletion.

Columns: region · role · have (ids already in the pool) · need (target pool
size) · what the pool lacked · base sprite (existing sprite id to derive
PixelLab object-state variants from) · status (`open` | `done <ids>` | `dropped`).

| region | role | have (ids) | need | what the pool lacked | base sprite | status |
|---|---|---|---|---|---|---|
```

- [ ] **Step 2: Write `docs/art-bundle-pending.md`**

```markdown
# Art bundle pending (living)

Pack slices that `tools/wire_asset.py` refused to wire because their source
sheet is not under `wandering_inn_game/assets/` (exit 3, `BUNDLE-PENDING
<source_sheet>`). Pack art may only be wired as a `region` row on an
already-bundled sheet; a new sheet needs a manifest row and a private bundle
release (`wi-shipping`), which Phase 0 does not allow, so the request waits here.

Insertion: tail — append rows; delete a row in the commit that wires its
candidate. One row per candidate path.

Columns: date · source_sheet (pack path under `potential_assets/`) · candidate
(the slice PNG) · sprite_id (the id the wiring asked for) · region ([x, y, w, h]
on the source sheet).

| date | source_sheet | candidate | sprite_id | region |
|---|---|---|---|---|
```

- [ ] **Step 3: Add the DOC-MAP row** (after the `docs/asset-catalog.md` row):

```markdown
| `docs/art-generation-list.md`, `docs/art-bundle-pending.md` | Regional-kits supply ledgers: approved-batch generation requests, and pack slices waiting on a bundled sheet (`tools/fill_kit.py` / `tools/wire_asset.py` append) | Living; tail insertion; rows close in the wiring/batch PR |
```

- [ ] **Step 4: Verify and commit**

```bash
python3 scripts/check_doc_drift.py; echo "rc=$?"
git add docs/art-generation-list.md docs/art-bundle-pending.md docs/DOC-MAP.md
git commit -m "docs: art-generation-list and art-bundle-pending ledgers (kits §4.3)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
Expected: `rc=0`.

---

### Task 4: `tools/wire_asset.py` — owned static PNG path, with the fake tree (Wave 1)

**Files:**
- Create: `scripts/tests/wi_fake_tree.py`
- Create: `tools/wire_asset.py`
- Create: `scripts/tests/test_wire_asset.py`

**Interfaces:**
- Consumes: `wandering_inn_game/scripts/splice_json.py` (`scan_container_span(text, open_ch, close_ch, start) -> (open_idx, close_idx)`, `last_sibling_indent(text, open_idx, close_idx) -> str`, `reindent(record_json: str, indent: str) -> str`), `tools/asset_candidates.py` (`present(dir) -> set[str]`, `build(assets_root, repo_root) -> dict`, `dump_registry(reg) -> str`, `summary_md(reg) -> str`), `wandering_inn_game/scripts/sprite_alpha_probe.py`'s rule (feet plane = lowest row with alpha ≥ 8; anchor `[0.5, feet/frame_h]`).
- Produces (used by Tasks 5–12): module `wire_asset` with `EXIT_OK=0, EXIT_USAGE=2, EXIT_BUNDLE_PENDING=3, EXIT_REFUSED=4, EXIT_PROBE=5`; `FIXTURE_COMMENT: str`; `BUNDLE_PENDING_HEADER: str`; `DEFAULT_SCALE = {"owned": 0.4, "pack": 1.0}`; exceptions `Refused`, `ProbeError`, `BundlePending(source_sheet, region)` each with `.exit_code`; `Paths(repo_root)` with properties `game, sprites, fixture, provenance, manifest, assets, docs, bundle_pending, potential`; `sha256_file(Path) -> str`; `read_text(Path) -> str`; `probe(png: Path, frame_w: int | None = None) -> dict{w,h,bbox,feet,anchor}`; `frame_geometry(w, h, manifest_frame) -> (fw, fh, count)`; `manifest_row(candidate, paths) -> dict`; `load_catalog(paths) -> (text, dict)`; `bundle_paths(paths) -> set[str]`; `check_fallback(fallback, catalog, bundle) -> None`; `sibling(catalog, mode, like, sheet_res, frame_size) -> (id, entry) | None`; `is_slice(candidate) -> bool`; `fixture_with(text, key, frames) -> str`; `regenerate_candidates(paths) -> None`; `main(argv) -> int`.
- Sibling rule (documented in the module docstring): `--like <id>` wins; else pack mode → first catalog entry (file order) whose `animations.idle.sheet` is the same game sheet and has a `region`; owned mode → first non-directional entry whose idle sheet is under `res://assets/sprites/` with equal `frame_size`, skipping `pc_*`, `icon_*`, `owned_fallback_*`; none → `render_scale` from `DEFAULT_SCALE[mode]` and `shadow` true iff `--kind prop`. Only `render_scale` and `shadow` are copied.

- [ ] **Step 1: Write the fake tree helper `scripts/tests/wi_fake_tree.py`**

```python
#!/usr/bin/env python3
"""Synthetic repo tree for tools/wire_asset.py and tools/fill_kit.py tests.

Builds a throwaway copy of the parts those tools touch (sprites.json, the C7
fixture, assets_manifest.json, provenance, docs, one bundled pack sheet, one
owned batch with MANIFEST.json, two atlas slices with SLICES.json) so the tools
run with --repo-root and never see the real tree. PNGs are drawn with PIL.
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO_ROOT / "tools"))
import wire_asset as wa  # noqa: E402

PACK = "Pixel Crawler - Free Pack 2.1"       # spaces and a dot, like the real pack dir
UNBUNDLED_PACK = "Pixel Crawler - Hideout 1.0"
OWNED = "potential_assets/pixellab_test/L2_props/parcel_stack.png"
OWNED_DUP = "potential_assets/pixellab_test/L2_props/parcel_stack__alt1.png"
STRIP = "potential_assets/pixellab_test/L2_props/lantern_flicker.png"
BENCH = "potential_assets/pixellab_test/L2_props/wide_bench.png"
SLICE = f"potential_assets/{PACK}/_sliced/Furniture/Furniture__x16_y8_w16_h23.png"
PENDING_SLICE = f"potential_assets/{UNBUNDLED_PACK}/_sliced/Props/Props__x0_y0_w16_h16.png"
PIXELLAB_ID = "0a4384ab-702d-4998-8e26-8e15c4c97585"


def png_box(path: Path, w: int, h: int, box: tuple[int, int, int, int],
            color: tuple[int, int, int, int] = (150, 90, 40, 255)) -> Path:
    """Transparent canvas with one opaque box (inclusive corners, PIL semantics)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(img).rectangle(box, fill=color, outline=(20, 10, 5, 255))
    img.save(path)
    return path


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def snapshot(root: Path) -> dict[str, str]:
    """relpath -> sha256 for every file; tests diff two of these."""
    return {p.relative_to(root).as_posix(): sha(p) for p in sorted(root.rglob("*")) if p.is_file()}


def changed(before: dict[str, str], after: dict[str, str]) -> set[str]:
    return {p for p in set(before) | set(after) if before.get(p) != after.get(p)}


def make_tree(root: Path) -> Path:
    game = root / "wandering_inn_game"
    png_box(game / "assets" / "sprites" / "crate_owned" / "Idle-Sheet.png", 64, 64, (20, 30, 43, 59))
    sheet = png_box(game / "assets" / "props" / "free_pack" / "Furniture.png", 128, 64, (16, 8, 31, 30))
    sprites = {
        "pc_human_m": {"directional": True, "render_scale": 0.62, "animations": {"idle": {
            "sheet_down": "res://assets/sprites/pc_human_m/Idle_Down-Sheet.png",
            "sheet_side": "res://assets/sprites/pc_human_m/Idle_Side-Sheet.png",
            "sheet_up": "res://assets/sprites/pc_human_m/Idle_Up-Sheet.png",
            "frame_size": [104, 104], "fps": 6}}},
        "crate_owned": {"render_scale": 0.4, "anchor": [0.5, 0.9375], "shadow": True, "animations": {
            "idle": {"sheet": "res://assets/sprites/crate_owned/Idle-Sheet.png",
                     "frame_size": [64, 64], "fps": 1}}},
        "crate": {"fallback_sprite": "crate_owned", "render_scale": 1.0, "anchor": [0.5, 1.0], "animations": {
            "idle": {"sheet": "res://assets/props/free_pack/Furniture.png", "frame_size": [16, 23],
                     "region": [16, 8, 16, 23], "fps": 1}}},
    }
    (game / "data").mkdir(parents=True)
    (game / "data" / "sprites.json").write_text(json.dumps(sprites, indent=1) + "\n", encoding="utf-8")
    fixture = {"_comment": wa.FIXTURE_COMMENT,
               "counts": {"crate/idle": 1, "crate_owned/idle": 1, "pc_human_m/idle": 4}}
    (game / "qa" / "fixtures").mkdir(parents=True)
    (game / "qa" / "fixtures" / "sprite_frame_counts.json").write_text(
        json.dumps(fixture, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    manifest = {"_comment": "fake", "assets": [{"path": "assets/props/free_pack/Furniture.png",
                "source_pack": PACK, "verdict": "FORBIDDEN", "bundle": True, "fallback": "placeholder"}]}
    (game / "assets_manifest.json").write_text(json.dumps(manifest, indent=1) + "\n", encoding="utf-8")
    (game / "assets" / "LICENSES").mkdir(parents=True)
    (game / "assets" / "LICENSES" / "v019-owned-art-provenance.txt").write_text(
        "OWNED ART — fake tree\n=====================\n\nassets/sprites/crate_owned/Idle-Sheet.png\n"
        "    fake owned sibling.\n", encoding="utf-8")
    (root / "docs").mkdir()
    (root / "docs" / "art-bundle-pending.md").write_text(wa.BUNDLE_PENDING_HEADER, encoding="utf-8")
    # owned batch: a 64x64 static, its byte-identical duplicate, a 192x64 three-frame
    # strip, and a 96x32 strip whose MANIFEST row pins frame_size [48, 32]
    batch = root / "potential_assets" / "pixellab_test" / "L2_props"
    png_box(batch / "parcel_stack.png", 64, 64, (18, 24, 45, 59))
    (batch / "parcel_stack__alt1.png").write_bytes((batch / "parcel_stack.png").read_bytes())
    png_box(batch / "lantern_flicker.png", 192, 64, (24, 10, 40, 60))
    png_box(batch / "wide_bench.png", 96, 32, (4, 6, 90, 30))
    (batch / "MANIFEST.json").write_text(json.dumps({
        "schema": 1, "source": "pixellab", "tier": "owned-public", "family": "PIXELLAB-AI", "assets": [
            {"path": "parcel_stack.png", "kind": "prop", "targets": ["parcel_stack", "crate"],
             "verdict": "READY", "pixellab_id": PIXELLAB_ID, "prompt": "stacked parcels"},
            {"path": "parcel_stack__alt1.png", "kind": "prop", "targets": ["parcel_stack", "crate"],
             "verdict": "ALT", "pixellab_id": PIXELLAB_ID},
            {"path": "lantern_flicker.png", "kind": "prop", "targets": ["lamp"], "verdict": "READY",
             "pixellab_id": "11111111-2222-4333-8444-555555555555"},
            {"path": "wide_bench.png", "kind": "prop", "targets": ["seat", "crate"], "verdict": "REJECTED",
             "frame_size": [48, 32]},
        ]}, indent=1) + "\n", encoding="utf-8")
    # pack slices: one cut from the bundled sheet, one from a sheet absent under assets/
    sliced = root / "potential_assets" / PACK / "_sliced" / "Furniture"
    sliced.mkdir(parents=True)
    with Image.open(sheet) as im:
        im.crop((16, 8, 32, 31)).save(sliced / "Furniture__x16_y8_w16_h23.png")
    (sliced / "SLICES.json").write_text(json.dumps({"assets": [{
        "path": SLICE, "kind": "prop", "targets": ["crate"], "verdict": "UNREVIEWED", "notes": "",
        "source_sheet": f"potential_assets/{PACK}/Furniture.png", "region": [16, 8, 16, 23],
        "sheet_sha256": sha(sheet), "method": "grid16", "has_shadow": False, "size_class": "M",
        "label_confidence": 0.9}]}, indent=1) + "\n", encoding="utf-8")
    pending = root / "potential_assets" / UNBUNDLED_PACK / "_sliced" / "Props"
    png_box(pending / "Props__x0_y0_w16_h16.png", 16, 16, (1, 1, 14, 14))
    (pending / "SLICES.json").write_text(json.dumps({"assets": [{
        "path": PENDING_SLICE, "kind": "prop", "targets": ["crate"], "verdict": "UNREVIEWED", "notes": "",
        "source_sheet": f"potential_assets/{UNBUNDLED_PACK}/Props.png", "region": [0, 0, 16, 16],
        "sheet_sha256": "f" * 64, "method": "grid16", "has_shadow": False, "size_class": "M",
        "label_confidence": 0.5}]}, indent=1) + "\n", encoding="utf-8")
    return root
```

- [ ] **Step 2: Write the failing tests `scripts/tests/test_wire_asset.py`**

```python
#!/usr/bin/env python3
"""tools/wire_asset.py against the synthetic tree (scripts/tests/wi_fake_tree.py)."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

pytest.importorskip("PIL")   # Pillow is the dev dependency sprite_alpha_probe.py already needs
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent.parent / "tools"))
import wire_asset as wa  # noqa: E402
from wi_fake_tree import (BENCH, OWNED, PENDING_SLICE, PIXELLAB_ID, SLICE, STRIP,  # noqa: E402
                          UNBUNDLED_PACK, changed, make_tree, sha, snapshot)

SPRITES = "wandering_inn_game/data/sprites.json"
FIXTURE = "wandering_inn_game/qa/fixtures/sprite_frame_counts.json"
PROVENANCE = "wandering_inn_game/assets/LICENSES/v019-owned-art-provenance.txt"


@pytest.fixture
def tree(tmp_path: Path) -> Path:
    return make_tree(tmp_path / "repo")


def run(tree: Path, *argv: str) -> int:
    return wa.main([*argv, "--repo-root", str(tree)])


def sprites(tree: Path) -> dict:
    return json.loads((tree / SPRITES).read_text())


def fixture(tree: Path) -> dict:
    return json.loads((tree / FIXTURE).read_text())["counts"]


def provenance(tree: Path) -> str:
    return (tree / PROVENANCE).read_text()


def test_refuses_pc_id(tree, capsys):
    before = snapshot(tree)
    assert run(tree, OWNED, "--id", "pc_gnoll_x") == wa.EXIT_REFUSED
    assert snapshot(tree) == before
    assert "pc_" in capsys.readouterr().out


def test_id_count_must_match_candidates(tree):
    before = snapshot(tree)
    assert run(tree, OWNED, STRIP, "--id", "only_one") == wa.EXIT_USAGE
    assert snapshot(tree) == before


def test_owned_static_wires(tree):
    assert run(tree, OWNED, "--id", "parcel_stack") == 0
    dst = tree / "wandering_inn_game/assets/sprites/parcel_stack/Idle-Sheet.png"
    assert sha(dst) == sha(tree / OWNED)
    assert sprites(tree)["parcel_stack"] == {
        "render_scale": 0.4, "anchor": [0.5, 0.9375], "shadow": True,
        "animations": {"idle": {"sheet": "res://assets/sprites/parcel_stack/Idle-Sheet.png",
                                "frame_size": [64, 64], "fps": 1}}}
    assert fixture(tree)["parcel_stack/idle"] == 1
    lines = [l for l in provenance(tree).splitlines() if l.startswith("parcel_stack/Idle-Sheet.png:")]
    assert len(lines) == 1 and sha(dst) in lines[0] and PIXELLAB_ID in lines[0] and OWNED in lines[0]
    reg = json.loads((tree / "docs/asset-candidates.json").read_text())
    assert any(r.get("sprite_id") == "parcel_stack" for r in reg["assets"])


def test_rerun_is_noop(tree, capsys):
    assert run(tree, OWNED, "--id", "parcel_stack") == 0
    before = snapshot(tree)
    assert run(tree, OWNED, "--id", "parcel_stack") == 0
    assert snapshot(tree) == before
    assert "no change" in capsys.readouterr().out


def test_existing_id_with_different_content_is_refused(tree):
    assert run(tree, OWNED, "--id", "parcel_stack") == 0
    p = tree / SPRITES
    cat = json.loads(p.read_text())
    cat["parcel_stack"]["render_scale"] = 0.5
    p.write_text(json.dumps(cat, indent=1) + "\n")
    before = snapshot(tree)
    assert run(tree, OWNED, "--id", "parcel_stack") == wa.EXIT_REFUSED
    assert snapshot(tree) == before


def test_existing_sheet_with_different_bytes_is_refused(tree):
    dst = tree / "wandering_inn_game/assets/sprites/parcel_stack/Idle-Sheet.png"
    dst.parent.mkdir(parents=True)
    dst.write_bytes((tree / STRIP).read_bytes())
    before = snapshot(tree)
    assert run(tree, OWNED, "--id", "parcel_stack") == wa.EXIT_REFUSED
    assert snapshot(tree) == before


def test_resumes_after_partial_copy(tree):
    dst = tree / "wandering_inn_game/assets/sprites/parcel_stack/Idle-Sheet.png"
    dst.parent.mkdir(parents=True)
    dst.write_bytes((tree / OWNED).read_bytes())
    assert run(tree, OWNED, "--id", "parcel_stack") == 0
    assert "parcel_stack" in sprites(tree) and fixture(tree)["parcel_stack/idle"] == 1


def test_dry_run_prints_diff_and_writes_nothing(tree, capsys):
    before = snapshot(tree)
    assert run(tree, OWNED, "--id", "parcel_stack", "--dry-run") == 0
    out = capsys.readouterr().out
    assert snapshot(tree) == before
    assert ("COPY potential_assets/pixellab_test/L2_props/parcel_stack.png -> "
            "wandering_inn_game/assets/sprites/parcel_stack/Idle-Sheet.png") in out
    assert '+ "parcel_stack": {' in out
    assert '+  "parcel_stack/idle": 1' in out
    assert "+parcel_stack/Idle-Sheet.png:" in out


def test_sprites_json_edit_is_surgical(tree):
    before = (tree / SPRITES).read_text()
    assert run(tree, OWNED, "--id", "parcel_stack") == 0
    after = (tree / SPRITES).read_text()
    head = before.rstrip()[:-1].rstrip()   # every byte up to the final closing brace
    assert after.startswith(head + ",\n") and after.endswith("\n}\n")
    assert json.loads(after)["crate"] == json.loads(before)["crate"]


def test_fixture_rejects_non_integer_pins(tree):
    f = tree / FIXTURE
    d = json.loads(f.read_text())
    d["counts"]["crate/idle"] = 1.5
    f.write_text(json.dumps(d, indent=1, sort_keys=True) + "\n")
    before = snapshot(tree)
    assert run(tree, OWNED, "--id", "parcel_stack") == wa.EXIT_REFUSED
    assert snapshot(tree) == before
```

- [ ] **Step 3: Run to verify failure**

Run: `python3 -m pytest -q scripts/tests/test_wire_asset.py`
Expected: collection error `ModuleNotFoundError: No module named 'wire_asset'`.

- [ ] **Step 4: Write `tools/wire_asset.py`**

```python
#!/usr/bin/env python3
"""Wire one asset candidate into the game (regional kits spec §4.2, contract C9).

  python3 tools/wire_asset.py <candidate.png>… --id <sprite_id> [--id …] [--kind prop|setpiece]
        [--fallback <owned_sprite_id>] [--like <sprite_id>] [--fps N] [--dry-run]
        [--no-regen] [--repo-root DIR]

One --id per candidate, in order. Exit codes: 0 wired or no change; 2 usage;
3 bundle pending; 4 refused (pc_* id, id already wired with different content,
bad --fallback, non-canonical fixture); 5 probe failure (empty alpha, bad strip).

Owned PNG (potential_assets/pixellab_*/…, codex_*/…): copied unchanged to
assets/sprites/<id>/Idle-Sheet.png; a static sprites.json entry; a
'<id>/idle' pin in qa/fixtures/sprite_frame_counts.json; one provenance line in
assets/LICENSES/v019-owned-art-provenance.txt (source path, sha256, PixelLab
id from the batch MANIFEST.json when present). A sheet wider than tall is a
horizontal strip of height x height frames unless the MANIFEST row carries
"frame_size": [w, h].

Pack slice (…/_sliced/<stem>/<stem>__x_y_w_h.png beside SLICES.json): a
`region` entry on the ALREADY-BUNDLED game sheet, found by matching the row's
sheet_sha256 against every PNG under wandering_inn_game/assets/ (a row
"game_sheet" from the slicer short-circuits that). No file is copied, no
manifest row is added, provenance is the entry's own _comment (source sheet,
region, sheet sha). --fallback is required and must be a public, one-hop,
non-pc_ catalog entry. No bundled match: exit 3, print `BUNDLE-PENDING
<source_sheet>`, append one row to docs/art-bundle-pending.md.

Anchor: the alpha probe of the FIRST frame (scripts/sprite_alpha_probe.py's
rule): feet = lowest row with alpha >= 8, anchor [0.5, feet / frame_h].

Sibling rule for render_scale and shadow: --like <id> wins; else pack mode
takes the first catalog entry (file order) on the same game sheet that has a
region; owned mode takes the first non-directional entry under
res://assets/sprites/ with the same frame_size (pc_*, icon_*, owned_fallback_*
skipped); none -> DEFAULT_SCALE and shadow iff --kind prop.

Every write is planned in memory and proved first; --dry-run prints the exact
diff. Re-running a finished wiring prints "no change" and writes nothing.
sprites.json is spliced with scripts/splice_json.py's primitives, never
reserialized. docs/asset-candidates.* are regenerated through
tools/asset_candidates.py's build() (the same code `python3
tools/asset_candidates.py` runs) so --repo-root stays honoured.
"""
from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import re
import sys
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "tools"))
sys.path.insert(0, str(REPO_ROOT / "wandering_inn_game" / "scripts"))
import asset_candidates as ac  # noqa: E402
import splice_json  # noqa: E402

EXIT_OK, EXIT_USAGE, EXIT_BUNDLE_PENDING, EXIT_REFUSED, EXIT_PROBE = 0, 2, 3, 4, 5
ALPHA_FLOOR = 8
ID_RE = re.compile(r"^[a-z0-9_]+$")
DEFAULT_SCALE = {"owned": 0.4, "pack": 1.0}
FIXTURE_COMMENT = ("Frame-count pins, '<sprite_id>/<anim>': frames. Generated once from "
                   "tests/test_sprite_registry.gd::_build_expected_counts (2026-10-08); "
                   "tools/wire_asset.py appends; the test fails on a missing key. "
                   "Canonical form: json.dumps(indent=1, sort_keys=True).")
BUNDLE_PENDING_HEADER = """# Art bundle pending (living)

Pack slices that `tools/wire_asset.py` refused to wire because their source
sheet is not under `wandering_inn_game/assets/` (exit 3, `BUNDLE-PENDING
<source_sheet>`). Pack art may only be wired as a `region` row on an
already-bundled sheet; a new sheet needs a manifest row and a private bundle
release (`wi-shipping`), which Phase 0 does not allow, so the request waits here.

Insertion: tail — append rows; delete a row in the commit that wires its
candidate. One row per candidate path.

Columns: date · source_sheet (pack path under `potential_assets/`) · candidate
(the slice PNG) · sprite_id (the id the wiring asked for) · region ([x, y, w, h]
on the source sheet).

| date | source_sheet | candidate | sprite_id | region |
|---|---|---|---|---|
"""


class Refused(Exception):
    exit_code = EXIT_REFUSED


class ProbeError(Exception):
    exit_code = EXIT_PROBE


class BundlePending(Exception):
    exit_code = EXIT_BUNDLE_PENDING

    def __init__(self, source_sheet: str, region: list[int]):
        super().__init__(f"BUNDLE-PENDING {source_sheet}")
        self.source_sheet = source_sheet
        self.region = region


@dataclass
class Paths:
    repo_root: Path

    def __post_init__(self) -> None:
        self.repo_root = Path(self.repo_root).resolve()

    @property
    def game(self) -> Path:
        return self.repo_root / "wandering_inn_game"

    @property
    def sprites(self) -> Path:
        return self.game / "data" / "sprites.json"

    @property
    def fixture(self) -> Path:
        return self.game / "qa" / "fixtures" / "sprite_frame_counts.json"

    @property
    def provenance(self) -> Path:
        return self.game / "assets" / "LICENSES" / "v019-owned-art-provenance.txt"

    @property
    def manifest(self) -> Path:
        return self.game / "assets_manifest.json"

    @property
    def assets(self) -> Path:
        return self.game / "assets"

    @property
    def docs(self) -> Path:
        return self.repo_root / "docs"

    @property
    def bundle_pending(self) -> Path:
        return self.docs / "art-bundle-pending.md"

    @property
    def potential(self) -> Path:
        return self.repo_root / "potential_assets"


@dataclass
class TextEdit:
    path: Path
    before: str
    after: str


@dataclass
class Copy:
    src: Path
    dst: Path
    sha: str


@dataclass
class WirePlan:
    sprite_id: str
    entry: dict
    frames: int
    edits: list[TextEdit] = field(default_factory=list)
    copies: list[Copy] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)

    def is_noop(self) -> bool:
        return (all(e.before == e.after for e in self.edits)
                and all(c.dst.is_file() and sha256_file(c.dst) == c.sha for c in self.copies))


# ------------------------------------------------------------------ helpers

def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.is_file() else ""


def probe(png: Path, frame_w: int | None = None) -> dict:
    """Alpha probe of the FIRST frame: bbox, feet row and anchor."""
    with Image.open(png) as raw:
        img = raw.convert("RGBA")
    w, h = img.size
    first = img.crop((0, 0, frame_w or w, h))
    box = first.getchannel("A").point(lambda v: 255 if v >= ALPHA_FLOOR else 0).getbbox()
    if box is None:
        raise ProbeError(f"{png}: first frame is fully transparent")
    x0, y0, x1, y1 = box
    return {"w": w, "h": h, "bbox": [x0, y0, x1, y1], "feet": y1, "anchor": [0.5, round(y1 / h, 4)]}


def frame_geometry(w: int, h: int, manifest_frame: list | None) -> tuple[int, int, int]:
    """(frame_w, frame_h, count): square = one frame; wider = strip of h x h frames."""
    if manifest_frame:
        fw, fh = int(manifest_frame[0]), int(manifest_frame[1])
        if fh != h or fw <= 0 or w % fw:
            raise ProbeError(f"manifest frame_size {manifest_frame} does not tile a {w}x{h} sheet")
        return fw, fh, w // fw
    if w == h:
        return w, h, 1
    if w % h == 0:
        return h, h, w // h
    raise ProbeError(f"{w}x{h} is neither square nor a strip of {h}x{h} frames; "
                     f"add \"frame_size\": [w, h] to the MANIFEST.json row")


def manifest_row(candidate: Path, paths: Paths) -> dict:
    """The candidate's row in the nearest MANIFEST.json above it (asset_candidates schema)."""
    for d in (candidate.parent, *candidate.parent.parents):
        if paths.potential not in d.parents:
            break
        if "MANIFEST.json" in ac.present(d):
            rel = candidate.relative_to(d).as_posix()
            rows = json.loads((d / "MANIFEST.json").read_text(encoding="utf-8")).get("assets", [])
            return next((r for r in rows if r.get("path") == rel), {})
    return {}


def load_catalog(paths: Paths) -> tuple[str, dict]:
    text = paths.sprites.read_text(encoding="utf-8")
    return text, json.loads(text)


def bundle_paths(paths: Paths) -> set[str]:
    if not paths.manifest.is_file():
        return set()
    data = json.loads(paths.manifest.read_text(encoding="utf-8"))
    return {a["path"] for a in data.get("assets", []) if a.get("bundle")}


def sheets_of(entry: dict) -> list[str]:
    out = []
    for anim in (entry.get("animations") or {}).values():
        if isinstance(anim, dict):
            out += [str(v).replace("res://", "") for k, v in anim.items() if k.startswith("sheet")]
    return out


def check_fallback(fallback: str, catalog: dict, bundle: set[str]) -> None:
    target = catalog.get(fallback)
    if not isinstance(target, dict):
        raise Refused(f"--fallback {fallback}: not in sprites.json")
    if fallback.startswith("pc_"):
        raise Refused(f"--fallback {fallback}: pc_* rigs are player-only")
    if "fallback_sprite" in target:
        raise Refused(f"--fallback {fallback}: has its own fallback_sprite (targets are one hop)")
    private = [s for s in sheets_of(target) if s in bundle]
    if private:
        raise Refused(f"--fallback {fallback}: not public, bundle-only sheets {private}")


def sibling(catalog: dict, mode: str, like: str | None, sheet_res: str,
            frame_size: tuple[int, int]) -> tuple[str, dict] | None:
    if like:
        if not isinstance(catalog.get(like), dict):
            raise Refused(f"--like {like}: not in sprites.json")
        return like, catalog[like]
    for sid, entry in catalog.items():
        if not isinstance(entry, dict) or sid.startswith(("pc_", "icon_", "owned_fallback_", "_")):
            continue
        idle = (entry.get("animations") or {}).get("idle") or {}
        if mode == "pack":
            if idle.get("sheet") == sheet_res and "region" in idle:
                return sid, entry
        elif (not entry.get("directional")
              and str(idle.get("sheet", "")).startswith("res://assets/sprites/")
              and [int(v) for v in idle.get("frame_size", [0, 0])] == list(frame_size)):
            return sid, entry
    return None


def build_entry(mode: str, sheet_res: str, frame: tuple[int, int], region: list[int] | None,
                anchor: list[float], sib: tuple[str, dict] | None, kind: str,
                fallback: str | None, fps: int, comment: str) -> dict:
    entry: dict = {}
    if comment:
        entry["_comment"] = comment
    entry["render_scale"] = sib[1].get("render_scale", DEFAULT_SCALE[mode]) if sib else DEFAULT_SCALE[mode]
    entry["anchor"] = anchor
    shadow = sib[1].get("shadow", False) if sib else (kind == "prop")
    if shadow:
        entry["shadow"] = True
    anim: dict = {"sheet": sheet_res, "frame_size": [frame[0], frame[1]]}
    if region:
        anim["region"] = list(region)
    anim["fps"] = fps
    entry["animations"] = {"idle": anim}
    if fallback:
        entry["fallback_sprite"] = fallback
    return entry


def is_slice(candidate: Path) -> bool:
    return "_sliced" in candidate.parts and (candidate.parent / "SLICES.json").is_file()


# ------------------------------------------------------------ text edits

def splice_top_level(text: str, key: str, value: dict) -> str:
    """splice_json.py's dict-mode append, in memory, with the same proofs."""
    open_idx, close_idx = splice_json.scan_container_span(text, "{", "}", 0)
    indent = splice_json.last_sibling_indent(text, open_idx, close_idx)
    body = '"%s": %s' % (key, splice_json.reindent(json.dumps(value, ensure_ascii=False), indent))
    tail = close_idx
    while tail > 0 and text[tail - 1] in " \t\n":
        tail -= 1
    out = text[:tail] + ",\n" + indent + body + text[tail:]
    before, after = json.loads(text), json.loads(out)
    if key not in after or len(after) != len(before) + 1 or after[key] != value:
        raise Refused(f"sprites.json splice proof failed for {key}")
    if not (out.startswith(text[:tail]) and out.endswith(text[close_idx:])):
        raise Refused("sprites.json splice changed bytes outside the insertion")
    return out


def sprites_with(text: str, catalog: dict, sprite_id: str, entry: dict) -> str:
    existing = catalog.get(sprite_id)
    if existing is not None:
        if existing == entry:
            return text
        raise Refused(f"{sprite_id}: already in sprites.json with different content:\n"
                      f"  have {json.dumps(existing, sort_keys=True)}\n  want {json.dumps(entry, sort_keys=True)}")
    return splice_top_level(text, sprite_id, entry)


def fixture_with(text: str, key: str, frames: int) -> str:
    data = json.loads(text) if text else {"_comment": FIXTURE_COMMENT, "counts": {}}
    counts = data.get("counts")
    if not isinstance(counts, dict):
        raise Refused("sprite_frame_counts.json needs a top-level counts dict (C7)")
    for k, v in counts.items():
        if type(v) is not int:
            raise Refused(f"sprite_frame_counts.json: pin {k} = {v!r} is not an int")
    if text and json.dumps(data, indent=1, sort_keys=True) + "\n" != text:
        raise Refused("sprite_frame_counts.json is not canonical (json.dumps indent=1 sort_keys=True); "
                      "regenerate it before wiring")
    if key in counts and counts[key] != frames:
        raise Refused(f"fixture pin {key} = {counts[key]} already; candidate has {frames} frames")
    counts[key] = frames
    data["counts"] = dict(sorted(counts.items()))
    data.setdefault("_comment", FIXTURE_COMMENT)
    return json.dumps(data, indent=1, sort_keys=True) + "\n"


def provenance_line(sprite_id: str, candidate_rel: str, sha: str, row: dict, pr: dict,
                    frame: tuple[int, int], count: int) -> str:
    gen = f" owned PixelLab generation {row['pixellab_id']};" if row.get("pixellab_id") else ""
    return (f"{sprite_id}/Idle-Sheet.png:{gen} source {candidate_rel}; copied unchanged; "
            f"canvas {pr['w']}x{pr['h']}; frames {count} of {frame[0]}x{frame[1]}; "
            f"alpha {tuple(pr['bbox'])}; feet anchor [0.5, {pr['anchor'][1]}]; sha256 {sha}; "
            f"wired by tools/wire_asset.py.\n")


def provenance_with(text: str, line: str) -> str:
    if line in text:
        return text
    prefix = line.split(":", 1)[0] + ":"
    if any(l.startswith(prefix) for l in text.splitlines()):
        raise Refused(f"provenance already lists {prefix} with different content")
    return text.rstrip("\n") + "\n\n" + line


def bundle_pending_with(text: str, source_sheet: str, candidate_rel: str, sprite_id: str,
                        region: list[int]) -> str:
    if not text:
        text = BUNDLE_PENDING_HEADER
    if any(f"| `{candidate_rel}` |" in l for l in text.splitlines()):
        return text
    row = f"| {date.today().isoformat()} | `{source_sheet}` | `{candidate_rel}` | {sprite_id} | {region} |\n"
    return text.rstrip("\n") + "\n" + row


# ------------------------------------------------------------------ plans

def plan_owned(candidate: Path, sprite_id: str, args: argparse.Namespace, paths: Paths,
               text: str, catalog: dict) -> WirePlan:
    row = manifest_row(candidate, paths)
    with Image.open(candidate) as img:
        w, h = img.size
    fw, fh, count = frame_geometry(w, h, row.get("frame_size"))
    pr = probe(candidate, fw)
    sha = sha256_file(candidate)
    sheet_res = f"res://assets/sprites/{sprite_id}/Idle-Sheet.png"
    sib = sibling(catalog, "owned", args.like, sheet_res, (fw, fh))
    fps = args.fps or (1 if count == 1 else 6)
    entry = build_entry("owned", sheet_res, (fw, fh), None, pr["anchor"], sib, args.kind,
                        args.fallback, fps, "")
    plan = WirePlan(sprite_id, entry, count)
    plan.notes.append(f"owned: {count} frame(s) of {fw}x{fh}; sibling {sib[0] if sib else '(none; defaults)'}; "
                      f"probe bbox {pr['bbox']} feet {pr['feet']}/{fh} anchor {pr['anchor']}")
    plan.copies.append(Copy(candidate, paths.assets / "sprites" / sprite_id / "Idle-Sheet.png", sha))
    plan.edits.append(TextEdit(paths.sprites, text, sprites_with(text, catalog, sprite_id, entry)))
    ftext = read_text(paths.fixture)
    plan.edits.append(TextEdit(paths.fixture, ftext, fixture_with(ftext, f"{sprite_id}/idle", count)))
    ptext = read_text(paths.provenance)
    rel = candidate.relative_to(paths.repo_root).as_posix()
    line = provenance_line(sprite_id, rel, sha, row, pr, (fw, fh), count)
    plan.edits.append(TextEdit(paths.provenance, ptext, provenance_with(ptext, line)))
    return plan


def render_diff(plan: WirePlan, paths: Paths) -> str:
    lines: list[str] = []
    for c in plan.copies:
        state = "exists, identical" if c.dst.is_file() and sha256_file(c.dst) == c.sha else "new file"
        lines.append(f"COPY {c.src.relative_to(paths.repo_root).as_posix()} -> "
                     f"{c.dst.relative_to(paths.repo_root).as_posix()} sha256 {c.sha[:12]} ({state})\n")
    for e in plan.edits:
        if e.before == e.after:
            continue
        rel = e.path.relative_to(paths.repo_root).as_posix()
        for d in difflib.unified_diff(e.before.splitlines(True), e.after.splitlines(True),
                                      f"a/{rel}", f"b/{rel}"):
            lines.append(d if d.endswith("\n") else d + "\n")
    return "".join(lines)


def apply_plan(plan: WirePlan) -> None:
    for c in plan.copies:
        if not (c.dst.is_file() and sha256_file(c.dst) == c.sha):
            c.dst.parent.mkdir(parents=True, exist_ok=True)
            c.dst.write_bytes(c.src.read_bytes())
    for e in plan.edits:
        if e.before != e.after:
            e.path.parent.mkdir(parents=True, exist_ok=True)
            e.path.write_text(e.after, encoding="utf-8")


def regenerate_candidates(paths: Paths) -> None:
    reg = ac.build(paths.potential, paths.repo_root)
    paths.docs.mkdir(parents=True, exist_ok=True)
    (paths.docs / "asset-candidates.json").write_text(ac.dump_registry(reg), encoding="utf-8")
    (paths.docs / "asset-candidates.md").write_text(ac.summary_md(reg), encoding="utf-8")


# ------------------------------------------------------------------- main

def wire_one(candidate: Path, sprite_id: str, args: argparse.Namespace, paths: Paths) -> bool:
    """Returns True when files changed. Raises Refused/ProbeError/BundlePending."""
    candidate = (candidate if candidate.is_absolute() else paths.repo_root / candidate).resolve()
    if not ID_RE.match(sprite_id):
        raise Refused(f"{sprite_id}: ids are [a-z0-9_]+")
    if sprite_id.startswith("pc_"):
        raise Refused(f"{sprite_id}: pc_* ids are the player's own skin; give it an NPC/prop id")
    if not candidate.is_file():
        raise Refused(f"{candidate}: no such file")
    if paths.potential not in candidate.parents:
        raise Refused(f"{candidate}: candidates live under potential_assets/")
    text, catalog = load_catalog(paths)
    if args.fallback:
        check_fallback(args.fallback, catalog, bundle_paths(paths))
    plan = plan_owned(candidate, sprite_id, args, paths, text, catalog)
    for n in plan.notes:
        print(f"{sprite_id}: {n}")
    if plan.is_noop():
        print(f"{sprite_id}: no change (already wired identically)")
        return False
    for c in plan.copies:
        if c.dst.is_file() and sha256_file(c.dst) != c.sha:
            raise Refused(f"{c.dst.relative_to(paths.repo_root)} exists with different bytes")
    diff = render_diff(plan, paths)
    if args.dry_run:
        print(diff, end="")
        print(f"{sprite_id}: DRY-RUN, nothing written (docs/asset-candidates.* would be regenerated)")
        return False
    apply_plan(plan)
    print(f"{sprite_id}: wired, {plan.frames} frame(s). Next: /usr/local/bin/godot --headless --path "
          f"wandering_inn_game --import, then commit the .import sidecar")
    return True


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("candidates", nargs="+", type=Path)
    ap.add_argument("--id", action="append", default=[], help="sprite id; repeat once per candidate")
    ap.add_argument("--kind", choices=("prop", "setpiece"), default="prop")
    ap.add_argument("--fallback", help="owned public sprite id (required for pack slices)")
    ap.add_argument("--like", help="copy render_scale/shadow from this catalog entry")
    ap.add_argument("--fps", type=int, help="default 1 for one frame, 6 for strips")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--no-regen", action="store_true", help="skip docs/asset-candidates.* rebuild")
    ap.add_argument("--repo-root", type=Path, default=REPO_ROOT)
    args = ap.parse_args(argv)
    if len(args.id) != len(args.candidates):
        print(f"wire_asset: {len(args.candidates)} candidate(s) need exactly {len(args.candidates)} --id value(s)",
              file=sys.stderr)
        return EXIT_USAGE
    paths = Paths(args.repo_root)
    rc, any_change = EXIT_OK, False
    for candidate, sprite_id in zip(args.candidates, args.id):
        try:
            any_change = wire_one(candidate, sprite_id, args, paths) or any_change
        except (Refused, ProbeError, BundlePending) as exc:
            print(str(exc))
            rc = max(rc, exc.exit_code)
    if any_change and not args.no_regen:
        regenerate_candidates(paths)
        print("docs/asset-candidates.* regenerated")
    return rc


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 5: Run the tests**

Run: `python3 -m pytest -q scripts/tests/test_wire_asset.py`
Expected: `10 passed`.

- [ ] **Step 6: Commit**

```bash
git add tools/wire_asset.py scripts/tests/wi_fake_tree.py scripts/tests/test_wire_asset.py
git commit -m "tools: wire_asset.py wires an owned PNG (copy, sprites.json splice, fixture pin, provenance)

Planned in memory and proved; --dry-run prints the diff; re-run is a no-op;
pc_* and divergent existing ids are refused. Pytest runs it on a synthetic
tree via --repo-root (scripts/tests/wi_fake_tree.py).

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: `wire_asset.py` — horizontal strips and MANIFEST frame sizes (Wave 1)

**Files:**
- Modify: `tools/wire_asset.py` (no code change expected — `frame_geometry` and `manifest_row` already carry it; this task pins the behaviour)
- Modify: `scripts/tests/test_wire_asset.py` (append tests)

**Interfaces:**
- Consumes: `frame_geometry`, `manifest_row` from Task 4.
- Produces: pinned rules — strip frame = `h x h`, `count = w // h`, fps 6; MANIFEST `frame_size` overrides; conflicting existing pin refused; `--fps` honoured.

- [ ] **Step 1: Append the failing tests**

```python
def test_strip_frames_from_height(tree):
    assert run(tree, STRIP, "--id", "lantern_flicker") == 0
    idle = sprites(tree)["lantern_flicker"]["animations"]["idle"]
    assert idle["frame_size"] == [64, 64] and idle["fps"] == 6
    assert sprites(tree)["lantern_flicker"]["anchor"] == [0.5, 0.9531]
    assert fixture(tree)["lantern_flicker/idle"] == 3
    line = [l for l in provenance(tree).splitlines() if l.startswith("lantern_flicker/Idle-Sheet.png:")][0]
    assert "frames 3 of 64x64" in line and "11111111-2222-4333-8444-555555555555" in line


def test_manifest_frame_size_wins(tree):
    assert run(tree, BENCH, "--id", "wide_bench", "--fps", "4") == 0
    idle = sprites(tree)["wide_bench"]["animations"]["idle"]
    assert idle["frame_size"] == [48, 32] and idle["fps"] == 4
    assert fixture(tree)["wide_bench/idle"] == 2


def test_frame_pin_conflict_refused(tree):
    f = tree / FIXTURE
    d = json.loads(f.read_text())
    d["counts"]["lantern_flicker/idle"] = 4
    f.write_text(json.dumps(d, indent=1, sort_keys=True) + "\n")
    before = snapshot(tree)
    assert run(tree, STRIP, "--id", "lantern_flicker") == wa.EXIT_REFUSED
    assert snapshot(tree) == before


def test_odd_sheet_is_a_probe_error(tree):
    from wi_fake_tree import png_box
    odd = tree / "potential_assets/pixellab_test/L2_props/odd.png"
    png_box(odd, 100, 64, (2, 2, 60, 60))
    before = snapshot(tree)
    assert run(tree, str(odd), "--id", "odd_prop") == wa.EXIT_PROBE
    assert snapshot(tree) == before
```

- [ ] **Step 2: Run them**

Run: `python3 -m pytest -q scripts/tests/test_wire_asset.py -k "strip or manifest_frame or pin_conflict or odd_sheet"`
Expected: `4 passed` (if any fails, the fix belongs in `frame_geometry` or `fixture_with`; the first-frame bbox for the strip is `(24, 10, 41, 61)` → anchor `0.9531`).

- [ ] **Step 3: Commit**

```bash
git add scripts/tests/test_wire_asset.py tools/wire_asset.py
git commit -m "test: wire_asset strips, MANIFEST frame_size override, pin conflicts

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: `wire_asset.py` — pack slices on bundled sheets, BUNDLE-PENDING, fallback rules (Wave 1)

**Files:**
- Modify: `tools/wire_asset.py` (add `slice_row`, `bundled_sheet_for`, `plan_slice`; branch in `wire_one`)
- Modify: `scripts/tests/test_wire_asset.py` (append tests)

**Interfaces:**
- Consumes: C8 row fields `path`, `region`, `sheet_sha256`, `source_sheet`, optional `game_sheet`.
- Produces: `slice_row(candidate, paths) -> dict`, `bundled_sheet_for(sha, paths) -> str | None` (returns `"assets/..."` relative to the game root), `plan_slice(candidate, sprite_id, args, paths, text, catalog) -> WirePlan`; `wire_one` appends the bundle-pending row (not in `--dry-run`) and re-raises `BundlePending`.

- [ ] **Step 1: Append the failing tests**

```python
def test_pack_slice_becomes_region_row(tree):
    before = snapshot(tree)
    assert run(tree, SLICE, "--id", "crate_lidded", "--fallback", "crate_owned") == 0
    e = sprites(tree)["crate_lidded"]
    assert e["animations"]["idle"] == {"sheet": "res://assets/props/free_pack/Furniture.png",
                                       "frame_size": [16, 23], "region": [16, 8, 16, 23], "fps": 1}
    assert e["fallback_sprite"] == "crate_owned" and e["render_scale"] == 1.0
    assert e["anchor"] == [0.5, 1.0] and "shadow" not in e
    assert e["_comment"].startswith("slice of potential_assets/Pixel Crawler - Free Pack 2.1/Furniture.png "
                                    "region [16, 8, 16, 23]")
    assert fixture(tree)["crate_lidded/idle"] == 1
    after = snapshot(tree)
    assert not any(p.startswith("wandering_inn_game/assets/") for p in set(after) - set(before))
    for untouched in ("wandering_inn_game/assets_manifest.json", PROVENANCE):
        assert after[untouched] == before[untouched]


def test_pack_slice_rerun_is_noop(tree):
    assert run(tree, SLICE, "--id", "crate_lidded", "--fallback", "crate_owned") == 0
    before = snapshot(tree)
    assert run(tree, SLICE, "--id", "crate_lidded", "--fallback", "crate_owned") == 0
    assert snapshot(tree) == before


@pytest.mark.parametrize("fallback", [None, "crate", "pc_human_m", "nope"])
def test_pack_slice_requires_public_one_hop_fallback(tree, fallback):
    before = snapshot(tree)
    argv = [SLICE, "--id", "crate_lidded"] + (["--fallback", fallback] if fallback else [])
    assert run(tree, *argv) == wa.EXIT_REFUSED
    assert snapshot(tree) == before


def test_unbundled_sheet_exits_3_and_logs_pending(tree, capsys):
    before = snapshot(tree)
    assert run(tree, PENDING_SLICE, "--id", "hideout_crate", "--fallback", "crate_owned") == wa.EXIT_BUNDLE_PENDING
    assert f"BUNDLE-PENDING potential_assets/{UNBUNDLED_PACK}/Props.png" in capsys.readouterr().out
    assert changed(before, snapshot(tree)) == {"docs/art-bundle-pending.md"}
    doc = (tree / "docs/art-bundle-pending.md").read_text()
    assert doc.startswith(wa.BUNDLE_PENDING_HEADER)
    assert doc.count("Props__x0_y0_w16_h16.png") == 1 and "| hideout_crate | [0, 0, 16, 16] |" in doc
    assert run(tree, PENDING_SLICE, "--id", "hideout_crate", "--fallback", "crate_owned") == wa.EXIT_BUNDLE_PENDING
    assert (tree / "docs/art-bundle-pending.md").read_text() == doc


def test_unbundled_dry_run_logs_nothing(tree):
    before = snapshot(tree)
    assert run(tree, PENDING_SLICE, "--id", "hideout_crate", "--fallback", "crate_owned",
               "--dry-run") == wa.EXIT_BUNDLE_PENDING
    assert snapshot(tree) == before


def test_slicer_game_sheet_hint_short_circuits_hash(tree):
    sj = tree / f"potential_assets/{UNBUNDLED_PACK}/_sliced/Props/SLICES.json"
    d = json.loads(sj.read_text())
    d["assets"][0]["game_sheet"] = "assets/props/free_pack/Furniture.png"
    sj.write_text(json.dumps(d, indent=1) + "\n")
    assert run(tree, PENDING_SLICE, "--id", "hinted_crate", "--fallback", "crate_owned") == 0
    assert sprites(tree)["hinted_crate"]["animations"]["idle"]["sheet"] == "res://assets/props/free_pack/Furniture.png"
```

- [ ] **Step 2: Run to verify failure**

Run: `python3 -m pytest -q scripts/tests/test_wire_asset.py -k "pack or unbundled or hint"`
Expected: `test_pack_slice_becomes_region_row` fails (`KeyError: 'crate_lidded'` or a `Refused` on the fallback path), the unbundled tests fail on the exit code.

- [ ] **Step 3: Add the slice functions to `tools/wire_asset.py`** (after `is_slice`)

```python
def slice_row(candidate: Path, paths: Paths) -> dict:
    """The C8 row for this slice in its SLICES.json (path matched repo-relative)."""
    rel = candidate.relative_to(paths.repo_root).as_posix()
    rows = json.loads((candidate.parent / "SLICES.json").read_text(encoding="utf-8")).get("assets", [])
    row = next((r for r in rows if r.get("path") == rel), None)
    if row is None:
        raise Refused(f"{rel}: no row in {candidate.parent / 'SLICES.json'}")
    for key in ("region", "sheet_sha256", "source_sheet"):
        if key not in row:
            raise Refused(f"{rel}: SLICES.json row lacks {key}")
    return row


_SHEET_INDEX: dict[Path, dict[str, str]] = {}


def bundled_sheet_for(sha: str, paths: Paths) -> str | None:
    """'assets/…' path (game-root relative) of the PNG under assets/ hashing to sha, else None."""
    index = _SHEET_INDEX.get(paths.assets)
    if index is None:
        index = {}
        for p in sorted(paths.assets.rglob("*.png")):
            index.setdefault(sha256_file(p), p.relative_to(paths.game).as_posix())
        _SHEET_INDEX[paths.assets] = index
    return index.get(sha)


def plan_slice(candidate: Path, sprite_id: str, args: argparse.Namespace, paths: Paths,
               text: str, catalog: dict) -> WirePlan:
    row = slice_row(candidate, paths)
    x, y, w, h = (int(v) for v in row["region"])
    if not args.fallback:
        raise Refused(f"{sprite_id}: pack art needs --fallback <owned public sprite_id>")
    hint = row.get("game_sheet")
    rel_sheet = hint if hint and (paths.game / hint).is_file() else bundled_sheet_for(row["sheet_sha256"], paths)
    if rel_sheet is None:
        raise BundlePending(row["source_sheet"], [x, y, w, h])
    pr = probe(candidate)
    if (pr["w"], pr["h"]) != (w, h):
        raise ProbeError(f"{candidate.name}: slice PNG is {pr['w']}x{pr['h']} but region says {w}x{h}")
    sheet_res = f"res://{rel_sheet}"
    sib = sibling(catalog, "pack", args.like, sheet_res, (w, h))
    comment = (f"slice of {row['source_sheet']} region {[x, y, w, h]} sheet sha256 "
               f"{row['sheet_sha256'][:12]}; wired by tools/wire_asset.py")
    entry = build_entry("pack", sheet_res, (w, h), [x, y, w, h], pr["anchor"], sib, args.kind,
                        args.fallback, args.fps or 1, comment)
    plan = WirePlan(sprite_id, entry, 1)
    plan.notes.append(f"pack: bundled sheet {rel_sheet}; sibling {sib[0] if sib else '(none; defaults)'}; "
                      f"probe bbox {pr['bbox']} feet {pr['feet']}/{h} anchor {pr['anchor']}")
    plan.edits.append(TextEdit(paths.sprites, text, sprites_with(text, catalog, sprite_id, entry)))
    ftext = read_text(paths.fixture)
    plan.edits.append(TextEdit(paths.fixture, ftext, fixture_with(ftext, f"{sprite_id}/idle", 1)))
    return plan
```

In `wire_one`, replace the single `plan = plan_owned(...)` line with:

```python
    if is_slice(candidate):
        try:
            plan = plan_slice(candidate, sprite_id, args, paths, text, catalog)
        except BundlePending as exc:
            if not args.dry_run:
                rel = candidate.relative_to(paths.repo_root).as_posix()
                doc = read_text(paths.bundle_pending)
                new = bundle_pending_with(doc, exc.source_sheet, rel, sprite_id, exc.region)
                if new != doc:
                    paths.bundle_pending.parent.mkdir(parents=True, exist_ok=True)
                    paths.bundle_pending.write_text(new, encoding="utf-8")
            raise
    else:
        plan = plan_owned(candidate, sprite_id, args, paths, text, catalog)
```

- [ ] **Step 4: Run the whole file**

Run: `python3 -m pytest -q scripts/tests/test_wire_asset.py`
Expected: `23 passed`.

- [ ] **Step 5: Commit**

```bash
git add tools/wire_asset.py scripts/tests/test_wire_asset.py
git commit -m "tools: wire_asset.py wires pack slices as region rows on bundled sheets

sheet_sha256 matched against assets/**/*.png (slicer game_sheet hint wins);
--fallback must be public, one-hop, not pc_; unbundled -> exit 3,
BUNDLE-PENDING <sheet>, row in docs/art-bundle-pending.md. No file copies,
no manifest edits.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: `wire_asset.py` — leak invariant, candidates regen, real-tree dry run (Wave 1)

**Files:**
- Modify: `scripts/tests/test_wire_asset.py` (append)
- Verify: `tools/wire_asset.py` against the real tree with `--dry-run`

**Interfaces:**
- Produces: the pinned write allowlist (every path `wire_asset` may change).

- [ ] **Step 1: Append the invariant tests**

```python
ALLOWED = {SPRITES, FIXTURE, PROVENANCE, "docs/asset-candidates.json", "docs/asset-candidates.md",
           "docs/art-bundle-pending.md"}


def test_only_allowed_paths_change_never_manifest_or_potential(tree):
    manifest = {a["path"] for a in json.loads((tree / "wandering_inn_game/assets_manifest.json").read_text())["assets"]}
    before = snapshot(tree)
    assert run(tree, OWNED, SLICE, "--id", "parcel_stack", "--id", "crate_lidded", "--fallback", "crate_owned") == 0
    delta = changed(before, snapshot(tree))
    assert delta <= ALLOWED | {"wandering_inn_game/assets/sprites/parcel_stack/Idle-Sheet.png"}
    assert not any(p.startswith("potential_assets/") for p in delta)
    assert not any(p.removeprefix("wandering_inn_game/") in manifest for p in delta)


def test_candidates_regenerated_once_with_repo_root(tree):
    assert run(tree, OWNED, "--id", "parcel_stack") == 0
    reg = json.loads((tree / "docs/asset-candidates.json").read_text())
    batches = {b["batch"] for b in reg["batches"]}
    assert "pixellab_test/L2_props" in batches
    assert {r["sprite_id"] for r in reg["assets"] if r.get("sprite_id")} == {"crate", "crate_owned", "pc_human_m", "parcel_stack"}
    assert (tree / "docs/asset-candidates.md").read_text().startswith("# Asset candidates registry")


def test_no_regen_flag(tree):
    assert run(tree, OWNED, "--id", "parcel_stack", "--no-regen") == 0
    assert not (tree / "docs/asset-candidates.json").exists()
```

- [ ] **Step 2: Run**

Run: `python3 -m pytest -q scripts/tests/test_wire_asset.py`
Expected: `26 passed`.

- [ ] **Step 3: Real-tree dry run (nothing may change)**

```bash
python3 tools/wire_asset.py "potential_assets/pixellab_harvest_2026-10/L2_props/alley_crate_clutter.png" --id alley_crate_clutter --dry-run > "$SCRATCH/dryrun.log"; echo "rc=$?"
grep -c '^COPY potential_assets/pixellab_harvest_2026-10/L2_props/alley_crate_clutter.png -> wandering_inn_game/assets/sprites/alley_crate_clutter/Idle-Sheet.png' "$SCRATCH/dryrun.log"
grep -c '^+ "alley_crate_clutter": {' "$SCRATCH/dryrun.log"; grep -c '^+  "alley_crate_clutter/idle": 1' "$SCRATCH/dryrun.log"; grep -c 'DRY-RUN, nothing written' "$SCRATCH/dryrun.log"
git status --porcelain
```
Expected: `rc=0`, `1`, `1`, `1`, `1`; `git status --porcelain` prints nothing (the real fixture is canonical, so the fixture diff shows only the one added line; if `wire_asset` refuses "not canonical", Task 1 step 4 was not followed — regenerate the fixture with that step, do not hand-edit).

- [ ] **Step 4: Commit**

```bash
git add scripts/tests/test_wire_asset.py
git commit -m "test: wire_asset write allowlist (never potential_assets or manifest paths), regen

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Wave 1 close — preflight and handoff (Wave 1)

**Files:**
- Modify: `HANDOFF.md` (lane C state line: branch, SHA, completed evidence, "Wave 2 waits on lane A `wi_kits_lib.py` + `data/kits.json`")

- [ ] **Step 1: Run the fast preflight and the registry unit**

```bash
scripts/preflight.sh > "$SCRATCH/preflight-w1.log" 2>&1; echo "rc=$?"
grep -c 'PREFLIGHT: ALL GREEN' "$SCRATCH/preflight-w1.log"; grep 'FAIL' "$SCRATCH/preflight-w1.log"
```
Expected: `rc=0`, `1`, no FAIL lines.

- [ ] **Step 2: Leak and census**

```bash
scripts/leak_check.sh; echo "rc=$?"
python3 scripts/comment_census.py --check; echo "rc=$?"
```
Expected: `leak_check: clean …`, `rc=0`; census `rc=0`.

- [ ] **Step 3: Update HANDOFF.md and commit**

```bash
git add HANDOFF.md
git commit -m "docs: HANDOFF lane C Wave 1 (fixture migration + wire_asset) green

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push -u origin issue/607-lane-c
```

Wave 2 starts only after lane A's `wandering_inn_game/scripts/wi_kits_lib.py` and `wandering_inn_game/data/kits.json` are on `issue/607-kits-foundation`: `git rebase issue/607-kits-foundation` (or merge) and confirm `python3 -c "import sys; sys.path.insert(0,'wandering_inn_game/scripts'); import wi_kits_lib; print([n for n in ('load_kits','map_region','resolve_map','resolve_all') if hasattr(wi_kits_lib, n)])"` prints all four names.

---

### Task 9: `tools/fill_kit.py` — candidate query, filters, size classes (Wave 2)

**Files:**
- Modify: `scripts/tests/wi_fake_tree.py` (add `data/kits.json` and a candidates registry writer)
- Create: `tools/fill_kit.py`
- Create: `scripts/tests/test_fill_kit.py`

**Interfaces:**
- Consumes: `wire_asset` (`Paths`, `load_catalog`, `sha256_file`, `is_slice`, `slice_row`, `bundled_sheet_for`, `probe`, `frame_geometry`, `manifest_row`, `DEFAULT_SCALE`, `Refused`), `find_asset.words/score/TIER_RANK`, `asset_candidates.VERDICT_RANK`.
- Produces: `fill_kit.size_class(rendered_h: float) -> "S"|"M"|"L"|"XL"` (≤12, ≤24, ≤48, else), `Candidate` dataclass (`n, row, path, mode, sha, scale, rendered_h, size_class, sheet, region`), `query(paths, kind, scale) -> list[Candidate]` (unnumbered, sorted), `compatible(cands, member_classes, want) -> list[Candidate]`, `number(cands) -> list[Candidate]`, `role_pool_ids(kits, region, role) -> list[str]`, `entry_rendered_h(entry) -> float`, `GENERATION_LIST_HEADER: str`, `main(argv) -> int`.
- Size-class rule (resolved ambiguity): classes are computed from rendered gameplay height — owned candidate `bbox_h * scale` where `scale` is the role's first pool member's `render_scale` (else `DEFAULT_SCALE["owned"]`), pack slice `region_h * 1.0`, existing member `frame_h (or region_h) * render_scale`. C8's `size_class` label is informational only.

- [ ] **Step 1: Extend `wi_fake_tree.py`**

Append to `make_tree` before `return root`:

```python
    kits = {
        "_comment": "fake kits",
        "_common": {"materials": {}, "roles": {}, "cast": []},
        "invrisil": {"materials": {"floor_street": {"sheet": "res://assets/props/free_pack/Furniture.png",
                                                    "tile_px": 16, "coords": [1, 0]}},
                     "roles": {}, "cast": []},
    }
    (game / "data" / "kits.json").write_text(json.dumps(kits, indent=1) + "\n", encoding="utf-8")
```

and add module-level helpers:

```python
def registry_rows() -> list[dict]:
    """A hand-written docs/asset-candidates.json: owned rows, a byte-identical dup,
    a wrong-kind row, a REJECTED row, a bundled slice, an unbundled slice, a shipped row."""
    owned = {"kind": "prop", "tier": "owned-public", "family": "PIXELLAB-AI", "source": "pixellab", "exists": True}
    return [
        {"path": OWNED, "targets": ["parcel_stack", "crate"], "verdict": "READY", "w": 64, "h": 64,
         "pixellab_id": PIXELLAB_ID, "prompt": "stacked parcels", **owned},
        {"path": OWNED_DUP, "targets": ["parcel_stack", "crate"], "verdict": "ALT", "w": 64, "h": 64, **owned},
        {"path": STRIP, "targets": ["lamp"], "verdict": "READY", "w": 192, "h": 64, **owned},
        {"path": BENCH, "targets": ["seat", "crate"], "verdict": "REJECTED", "w": 96, "h": 32, **owned},
        {"path": SLICE, "kind": "prop", "targets": ["crate"], "verdict": "UNREVIEWED", "tier": "pack-bundle",
         "family": "PC16", "source": "pack", "exists": True, "w": 16, "h": 23},
        {"path": PENDING_SLICE, "kind": "prop", "targets": ["crate"], "verdict": "UNREVIEWED",
         "tier": "pack-bundle", "family": "PC16", "source": "pack", "exists": True, "w": 16, "h": 16},
        {"path": "wandering_inn_game/assets/sprites/crate_owned/Idle-Sheet.png", "kind": "prop",
         "targets": ["crate_owned"], "verdict": "SHIPPED", "tier": "shipped-public", "family": "",
         "source": "sprites.json", "exists": True, "sprite_id": "crate_owned", "w": 64, "h": 64},
    ]


def write_registry(root: Path, rows: list[dict] | None = None) -> None:
    (root / "docs" / "asset-candidates.json").write_text(
        json.dumps({"schema": 1, "generated_by": "test", "batches": [], "assets": rows or registry_rows()},
                   indent=1) + "\n", encoding="utf-8")
```

- [ ] **Step 2: Write the failing tests `scripts/tests/test_fill_kit.py`**

```python
#!/usr/bin/env python3
"""tools/fill_kit.py against the synthetic tree. Preview needs lane A's wi_kits_lib."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import pytest

pytest.importorskip("PIL")
from PIL import Image  # noqa: E402

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent.parent / "tools"))
import fill_kit as fk  # noqa: E402
import wire_asset as wa  # noqa: E402
from wi_fake_tree import OWNED, SLICE, changed, make_tree, snapshot, write_registry  # noqa: E402

KITS = "wandering_inn_game/data/kits.json"
GEN = "docs/art-generation-list.md"


@pytest.fixture
def tree(tmp_path: Path) -> Path:
    root = make_tree(tmp_path / "repo")
    write_registry(root)
    return root


def run(tree: Path, *argv: str) -> int:
    return fk.main([*argv, "--repo-root", str(tree)])


def kits(tree: Path) -> dict:
    return json.loads((tree / KITS).read_text())


def test_size_class_thresholds():
    assert [fk.size_class(h) for h in (12, 12.1, 24, 24.1, 48, 48.1)] == ["S", "M", "M", "L", "L", "XL"]


def test_query_filters_and_dedupes(tree, capsys):
    paths = wa.Paths(tree)
    cands = fk.number(fk.query(paths, "crate", wa.DEFAULT_SCALE["owned"]))
    assert [c.path.relative_to(tree).as_posix() for c in cands] == [OWNED, SLICE]
    assert [c.n for c in cands] == [1, 2]
    assert [(c.mode, c.size_class) for c in cands] == [("owned", "M"), ("pack", "M")]
    assert cands[1].sheet == "assets/props/free_pack/Furniture.png" and cands[1].region == [16, 8, 16, 23]
    assert "skip (bundle-pending potential_assets/Pixel Crawler - Hideout 1.0/Props.png)" in capsys.readouterr().out


def test_query_without_kind_keeps_every_eligible_row(tree):
    cands = fk.query(wa.Paths(tree), None, 0.4)
    assert {c.path.name for c in cands} == {"parcel_stack.png", "lantern_flicker.png", "Furniture__x16_y8_w16_h23.png"}


def test_size_filter(tree):
    paths = wa.Paths(tree)
    cands = fk.query(paths, "crate", 0.4)
    assert fk.compatible(cands, set(), "S") == []
    assert len(fk.compatible(cands, {"M"}, None)) == 2
    assert len(fk.compatible(cands, set(), None)) == 2


def test_listing_prints_numbered_candidates(tree, capsys):
    assert run(tree, "invrisil", "cargo", "--need", "4", "--kind", "crate") == 0
    out = capsys.readouterr().out
    assert re.search(r"^#1 +M +owned +READY +potential_assets/pixellab_test/L2_props/parcel_stack.png", out, re.M)
    assert re.search(r"^#2 +M +pack +UNREVIEWED +potential_assets/Pixel Crawler - Free Pack 2.1/", out, re.M)
    assert "-- 2 candidates for invrisil/cargo (have 0, need 4)" in out
```

- [ ] **Step 3: Run to verify failure**

Run: `python3 -m pytest -q scripts/tests/test_fill_kit.py`
Expected: `ModuleNotFoundError: No module named 'fill_kit'`.

- [ ] **Step 4: Write `tools/fill_kit.py` (query half)**

```python
#!/usr/bin/env python3
"""Fill a kit role from the asset pool (regional kits spec §4.2 steps 1-3, 6-7; C9).

  python3 tools/fill_kit.py <region> <role> --need N [--kind <tag>] [--size S|M|L|XL]
        [--contact-sheet out.png] [--select 1,3,…] [--ids a,b,…] [--pick cell|map|door]
        [--module] [--fallback <owned_id>] [--lacked "text"] [--base <sprite_id>]
        [--limit N] [--preview] [--repo-root DIR]

Pool first. Candidates come from docs/asset-candidates.json: owned PixelLab
rows (tier owned-public) and lane B's atlas slices (tier pack-bundle, rows
under _sliced/ beside SLICES.json). Filters: kind prop|setpiece, verdict !=
REJECTED, --kind words must match targets/path/prompt/notes
(find_asset.score), slices must resolve to a bundled sheet (else printed as
skip), byte-identical files collapse by sha256, size class must match the
role's existing pool (or --size). Survivors are numbered; --contact-sheet
renders them at gameplay scale (2x on top, 1x below) beside the region's
material swatches from data/kits.json.

--select wires the numbered picks through tools/wire_asset.py (ids
<region>_<role>_<n> unless --ids), appends them to data/kits.json
<region>.roles.<role>.pool with a surgical splice (a new role gets --pick,
default cell, and --module), and on a shortfall (selected < --need) writes one
open row to docs/art-generation-list.md. --preview prints the picks every map
of the region resolves to, through scripts/wi_kits_lib.resolve_map (lane A).
Step 4 of the spec, the pool art-direction read, happens between the contact
sheet and --select and is a Fable read, not code. This tool never calls
PixelLab.

Size classes are rendered gameplay height: S <= 12px, M <= 24, L <= 48, XL
above. Owned candidates use bbox height x the pool's first member's
render_scale (DEFAULT_SCALE when the pool is empty); slices use region height.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "tools"))
sys.path.insert(0, str(REPO_ROOT / "wandering_inn_game" / "scripts"))
import asset_candidates as ac  # noqa: E402
import find_asset as fa  # noqa: E402
import splice_json  # noqa: E402
import wire_asset as wa  # noqa: E402

EXIT_OK, EXIT_USAGE = 0, 2
SIZE_CLASSES = ("S", "M", "L", "XL")
CELL = 72        # contact-sheet cell edge, px
SWATCH_H = 52    # material swatch strip height (32px tile + label)
GENERATION_LIST_HEADER = """# Art generation list (living)

Rows are PixelLab generation requests the asset pool could not fill. Nothing
here is generated until the user approves a batch (regional kits spec §4.3,
Phase 3). `tools/fill_kit.py` appends a row when a role's selection falls short
of `--need`; `what the pool lacked` is the `--lacked` text the selecting agent
wrote after the pool read.

Insertion: tail — append rows at the end; one open row per (region, role) is
updated in place; a row closes by setting status to `done <sprite ids>` in the
batch PR, never by deletion.

Columns: region · role · have (ids already in the pool) · need (target pool
size) · what the pool lacked · base sprite (existing sprite id to derive
PixelLab object-state variants from) · status (`open` | `done <ids>` | `dropped`).

| region | role | have (ids) | need | what the pool lacked | base sprite | status |
|---|---|---|---|---|---|---|
"""


def size_class(rendered_h: float) -> str:
    if rendered_h <= 12:
        return "S"
    if rendered_h <= 24:
        return "M"
    if rendered_h <= 48:
        return "L"
    return "XL"


@dataclass
class Candidate:
    n: int
    row: dict
    path: Path
    mode: str                 # "owned" | "pack"
    sha: str
    scale: float              # render_scale the wired entry would get
    frame_w: int              # first-frame width (strip frame for owned, region w for pack)
    rendered_h: float
    size_class: str
    sheet: str | None         # bundled game sheet, pack only
    region: list[int] | None  # [x, y, w, h], pack only


def kits_path(paths: wa.Paths) -> Path:
    return paths.game / "data" / "kits.json"


def load_kits_text(paths: wa.Paths) -> tuple[str, dict]:
    p = kits_path(paths)
    if not p.is_file():
        raise wa.Refused(f"{p} missing (lane A ships it with _common)")
    text = p.read_text(encoding="utf-8")
    return text, json.loads(text)


def role_pool_ids(kits: dict, region: str, role: str) -> list[str]:
    spec = ((kits.get(region) or {}).get("roles") or {}).get(role)
    if spec is None:
        return []
    if isinstance(spec, str):
        return [spec]
    return [p[0] if isinstance(p, list) else p for p in spec.get("pool", [])]


def entry_rendered_h(entry: dict) -> float:
    idle = (entry.get("animations") or {}).get("idle") or {}
    h = idle["region"][3] if idle.get("region") else idle["frame_size"][1]
    return float(h) * float(entry.get("render_scale", 1.0))


def query(paths: wa.Paths, kind: str | None, scale: float) -> list[Candidate]:
    reg = paths.docs / "asset-candidates.json"
    if not reg.is_file():
        raise wa.Refused("docs/asset-candidates.json missing; run python3 tools/asset_candidates.py")
    rows = json.loads(reg.read_text(encoding="utf-8"))["assets"]
    terms = sorted(fa.words(kind)) if kind else []
    out: list[Candidate] = []
    seen: set[str] = set()
    for row in rows:
        if row.get("kind") not in ("prop", "setpiece") or row.get("verdict") == "REJECTED":
            continue
        if row.get("tier") not in ("owned-public", "pack-bundle"):
            continue
        if terms and not fa.score(row, terms, "_".join(terms)):
            continue
        path = (paths.repo_root / row["path"]).resolve()
        if not path.is_file():
            continue
        sha = wa.sha256_file(path)
        if sha in seen:
            continue
        if wa.is_slice(path):
            srow = wa.slice_row(path, paths)
            hint = srow.get("game_sheet")
            sheet = hint if hint and (paths.game / hint).is_file() else wa.bundled_sheet_for(srow["sheet_sha256"], paths)
            if sheet is None:
                print(f"skip (bundle-pending {srow['source_sheet']}): {row['path']}")
                continue
            region = [int(v) for v in srow["region"]]
            cand = Candidate(0, row, path, "pack", sha, 1.0, region[2], float(region[3]),
                             size_class(region[3]), sheet, region)
        elif row.get("tier") == "pack-bundle":
            continue  # a pack file that is not a slice: never wired loose
        else:
            try:
                with Image.open(path) as img:
                    w, h = img.size
                fw, _fh, _n = wa.frame_geometry(w, h, wa.manifest_row(path, paths).get("frame_size"))
                pr = wa.probe(path, fw)
            except wa.ProbeError as exc:
                print(f"skip (probe: {exc}): {row['path']}")
                continue
            rendered = (pr["bbox"][3] - pr["bbox"][1]) * scale
            cand = Candidate(0, row, path, "owned", sha, scale, fw, rendered, size_class(rendered), None, None)
        seen.add(sha)
        out.append(cand)
    out.sort(key=lambda c: (ac.VERDICT_RANK.get(c.row.get("verdict"), 99),
                            fa.TIER_RANK.get(c.row.get("tier"), 99), c.row["path"]))
    return out


def compatible(cands: list[Candidate], member_classes: set[str], want: str | None) -> list[Candidate]:
    allowed = {want} if want else member_classes
    if not allowed:
        return list(cands)
    return [c for c in cands if c.size_class in allowed]


def number(cands: list[Candidate]) -> list[Candidate]:
    for i, c in enumerate(cands, 1):
        c.n = i
    return cands


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("region")
    ap.add_argument("role")
    ap.add_argument("--need", type=int, default=4)
    ap.add_argument("--kind", help="kind tag / use words, e.g. crate")
    ap.add_argument("--size", choices=SIZE_CLASSES)
    ap.add_argument("--contact-sheet", type=Path)
    ap.add_argument("--select", help="comma-separated numbers from the listing")
    ap.add_argument("--ids", help="comma-separated sprite ids for --select (default <region>_<role>_<n>)")
    ap.add_argument("--pick", choices=("cell", "map", "door"), default="cell")
    ap.add_argument("--module", action="store_true")
    ap.add_argument("--fallback", help="owned public sprite id for pack picks")
    ap.add_argument("--lacked", default="", help="what the pool lacked (generation-list column)")
    ap.add_argument("--base", help="base sprite for PixelLab object-state variants")
    ap.add_argument("--limit", type=int, default=48)
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--repo-root", type=Path, default=REPO_ROOT)
    args = ap.parse_args(argv)
    paths = wa.Paths(args.repo_root)
    try:
        if args.preview:
            return preview(paths, args.region, args.role)
        return fill(args, paths)
    except (wa.Refused, wa.ProbeError) as exc:
        print(str(exc))
        return exc.exit_code


def fill(args: argparse.Namespace, paths: wa.Paths) -> int:
    _text, catalog = wa.load_catalog(paths)
    ktext, kits = load_kits_text(paths)
    pool = role_pool_ids(kits, args.region, args.role)
    members = {size_class(entry_rendered_h(catalog[i])) for i in pool if isinstance(catalog.get(i), dict)}
    like = next((i for i in pool if isinstance(catalog.get(i), dict)), None)
    scale = float(catalog[like].get("render_scale", wa.DEFAULT_SCALE["owned"])) if like else wa.DEFAULT_SCALE["owned"]
    cands = number(compatible(query(paths, args.kind, scale), members, args.size)[: args.limit])
    for c in cands:
        print(f"#{c.n:<3} {c.size_class:<2} {c.mode:<5} {c.row.get('verdict', ''):<15} {c.row['path']}")
    print(f"-- {len(cands)} candidates for {args.region}/{args.role} (have {len(pool)}, need {args.need})")
    if args.contact_sheet:
        render_contact_sheet(cands, material_swatches(kits, args.region, paths), args.contact_sheet)
        print(f"contact sheet: {args.contact_sheet}")
    if not args.select:
        return EXIT_OK
    return select(args, paths, cands, ktext, catalog, pool, like)


def preview(paths: wa.Paths, region: str, role: str) -> int:
    raise wa.Refused("preview lands with lane A's wi_kits_lib (Task 12)")


def select(args, paths, cands, ktext, catalog, pool, like) -> int:
    raise wa.Refused("--select lands in Task 11")


def render_contact_sheet(cands, materials, out: Path) -> None:
    raise wa.Refused("--contact-sheet lands in Task 10")


def material_swatches(kits: dict, region: str, paths: wa.Paths) -> list:
    raise wa.Refused("--contact-sheet lands in Task 10")


if __name__ == "__main__":
    sys.exit(main())
```

(The four tail functions are replaced wholesale in Tasks 10–12; they exist so the module imports and the listing path runs now.)

- [ ] **Step 5: Run**

Run: `python3 -m pytest -q scripts/tests/test_fill_kit.py`
Expected: `5 passed`.

- [ ] **Step 6: Commit**

```bash
git add tools/fill_kit.py scripts/tests/test_fill_kit.py scripts/tests/wi_fake_tree.py
git commit -m "tools: fill_kit.py queries and filters pool candidates by kind, tier, size class, sha

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: `fill_kit.py` — contact sheet beside the region's materials (Wave 2)

**Files:**
- Modify: `tools/fill_kit.py` (replace `render_contact_sheet`, `material_swatches`)
- Modify: `scripts/tests/test_fill_kit.py` (append)

**Interfaces:**
- Produces: `material_swatches(kits, region, paths) -> list[tuple[str, Image | None]]` (region materials override `_common`; a material whose sheet is not under the game root yields `None` and a red outline), `candidate_image(c) -> Image` (owned: bbox crop scaled by `c.scale`; pack: the slice as is), `render_contact_sheet(cands, materials, out) -> None` writing an RGBA PNG `8*CELL` wide: swatch strip, then per candidate a 2x NEAREST render (fit to `CELL`), its 1x render and the number.

- [ ] **Step 1: Append the failing test**

```python
def test_contact_sheet_renders_numbered_cells_and_swatches(tree, tmp_path):
    out = tmp_path / "cargo.png"
    assert run(tree, "invrisil", "cargo", "--need", "4", "--kind", "crate", "--contact-sheet", str(out)) == 0
    bg = (40, 40, 44, 255)
    with Image.open(out) as img:
        assert img.size == (8 * fk.CELL, fk.SWATCH_H + (fk.CELL + 28))
        tile = img.crop((4, 4, 36, 36))
        assert any(px != bg and px[3] == 255 for px in tile.getdata())   # floor_street tile from Furniture.png
        y0 = fk.SWATCH_H
        cell1 = img.crop((0, y0, fk.CELL, y0 + fk.CELL))
        assert any(px != bg and px[3] == 255 for px in cell1.getdata())   # the 2x render of #1
        label = img.crop((fk.CELL - 20, y0 + fk.CELL + 2, fk.CELL - 8, y0 + fk.CELL + 14))
        assert any(px != bg for px in label.getdata())                   # the number "1"
        empty = img.crop((2 * fk.CELL, y0, 3 * fk.CELL, y0 + fk.CELL))
        assert all(px == bg for px in empty.getdata())                   # only two candidates: cell 3 stays empty


def test_missing_material_sheet_is_outlined_not_fatal(tree, tmp_path):
    k = tree / KITS
    d = json.loads(k.read_text())
    d["invrisil"]["materials"]["wall_shop"] = {"sheet": "res://assets/tiles/absent.png", "tile_px": 16, "face": [0, 1]}
    k.write_text(json.dumps(d, indent=1) + "\n")
    out = tmp_path / "cargo.png"
    assert run(tree, "invrisil", "cargo", "--need", "4", "--kind", "crate", "--contact-sheet", str(out)) == 0
    with Image.open(out) as img:
        assert img.getpixel((76, 4)) == (200, 80, 80, 255)
```

- [ ] **Step 2: Run to verify failure**

Run: `python3 -m pytest -q scripts/tests/test_fill_kit.py -k contact`
Expected: both fail (`Refused: --contact-sheet lands in Task 10`).

- [ ] **Step 3: Replace the two stubs in `tools/fill_kit.py`**

```python
def candidate_image(c: Candidate) -> Image.Image:
    with Image.open(c.path) as raw:
        img = raw.convert("RGBA")
    if c.mode == "pack":
        return img
    pr = wa.probe(c.path, c.frame_w)
    x0, y0, x1, y1 = pr["bbox"]
    crop = img.crop((x0, y0, x1, y1))
    size = (max(1, round((x1 - x0) * c.scale)), max(1, round((y1 - y0) * c.scale)))
    return crop.resize(size, Image.NEAREST)


def material_swatches(kits: dict, region: str, paths: wa.Paths) -> list[tuple[str, Image.Image | None]]:
    mats = dict((kits.get("_common") or {}).get("materials") or {})
    mats.update((kits.get(region) or {}).get("materials") or {})
    out = []
    for name, m in mats.items():
        sheet = paths.game / str(m.get("sheet", "")).replace("res://", "")
        coords = m.get("coords") or m.get("face")
        tile = None
        if sheet.is_file() and coords:
            px = int(m.get("tile_px", 16))
            cx, cy = int(coords[0]), int(coords[1])
            with Image.open(sheet) as im:
                tile = im.convert("RGBA").crop((cx * px, cy * px, cx * px + px, cy * px + px))
        out.append((name, tile))
    return out


def render_contact_sheet(cands: list[Candidate], materials: list[tuple[str, Image.Image | None]],
                         out: Path) -> None:
    cols, swatch_h = 8, SWATCH_H
    rows = max(1, (len(cands) + cols - 1) // cols)
    sheet = Image.new("RGBA", (cols * CELL, swatch_h + rows * (CELL + 28)), (40, 40, 44, 255))
    draw = ImageDraw.Draw(sheet)
    x = 4
    for name, tile in materials:
        if tile is not None:
            sheet.alpha_composite(tile.resize((32, 32), Image.NEAREST), (x, 4))
        else:
            draw.rectangle((x, 4, x + 31, 35), outline=(200, 80, 80, 255))
        draw.text((x, 38), name[:10], fill=(220, 220, 220, 255))
        x += CELL
    for i, c in enumerate(cands):
        cx, cy = (i % cols) * CELL, swatch_h + (i // cols) * (CELL + 28)
        one_x = candidate_image(c)
        two_x = one_x.resize((one_x.width * 2, one_x.height * 2), Image.NEAREST)
        two_x.thumbnail((CELL, CELL), Image.NEAREST)
        sheet.alpha_composite(two_x, (cx + (CELL - two_x.width) // 2, cy + CELL - two_x.height))
        small = one_x.copy()
        small.thumbnail((CELL - 24, 24), Image.NEAREST)
        sheet.alpha_composite(small, (cx + 2, cy + CELL + 2))
        draw.text((cx + CELL - 20, cy + CELL + 2), str(c.n), fill=(255, 230, 120, 255))
        draw.text((cx + CELL - 20, cy + CELL + 14), c.size_class, fill=(180, 220, 180, 255))
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
```

- [ ] **Step 4: Run**

Run: `python3 -m pytest -q scripts/tests/test_fill_kit.py`
Expected: `7 passed`.

- [ ] **Step 5: Commit**

```bash
git add tools/fill_kit.py scripts/tests/test_fill_kit.py
git commit -m "tools: fill_kit.py contact sheet at gameplay scale beside kit material swatches

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: `fill_kit.py` — `--select` wires, splices `kits.json`, logs shortfalls (Wave 2)

**Files:**
- Modify: `tools/fill_kit.py` (replace `select`; add the nested-splice helpers, `next_ids`, `kits_with_pool`, `generation_list_with`)
- Modify: `scripts/tests/test_fill_kit.py` (append)

**Interfaces:**
- Consumes: `wire_asset.main(argv) -> int`, `wire_asset.regenerate_candidates(paths)`, `splice_json.scan_container_span/last_sibling_indent/reindent`.
- Produces: `add_key(text, path: list[str], key, value) -> str`, `append_item(text, path: list[str], value) -> str` (surgical nested JSON edits with placement + byte-identity proofs), `kits_with_pool(text, region, role, ids, pick, module) -> str`, `next_ids(region, role, n, catalog, pool) -> list[str]`, `generation_list_with(text, region, role, have, need, lacked, base) -> str`.

- [ ] **Step 1: Append the failing tests**

```python
def test_select_wires_and_pools(tree):
    before_common = re.search(r'^ "_common": .*$', (tree / KITS).read_text(), re.M).group(0)
    assert run(tree, "invrisil", "cargo", "--need", "2", "--kind", "crate", "--select", "1,2",
               "--fallback", "crate_owned") == 0
    cat = json.loads((tree / "wandering_inn_game/data/sprites.json").read_text())
    assert cat["invrisil_cargo_1"]["animations"]["idle"]["sheet"] == "res://assets/sprites/invrisil_cargo_1/Idle-Sheet.png"
    assert cat["invrisil_cargo_2"]["animations"]["idle"]["region"] == [16, 8, 16, 23]
    assert cat["invrisil_cargo_2"]["fallback_sprite"] == "crate_owned"
    assert kits(tree)["invrisil"]["roles"]["cargo"] == {"pick": "cell", "pool": ["invrisil_cargo_1", "invrisil_cargo_2"]}
    text = (tree / KITS).read_text()
    assert re.search(r'^ "_common": .*$', text, re.M).group(0) == before_common
    assert '"floor_street"' in text
    assert not (tree / GEN).exists()
    reg = json.loads((tree / "docs/asset-candidates.json").read_text())
    assert {"invrisil_cargo_1", "invrisil_cargo_2"} <= {r.get("sprite_id") for r in reg["assets"]}


def test_shortfall_row_is_written_once_and_updated(tree):
    assert run(tree, "invrisil", "cargo", "--need", "4", "--kind", "crate", "--select", "1",
               "--lacked", "no lidded or banded variants") == 0
    text = (tree / GEN).read_text()
    assert text.startswith(fk.GENERATION_LIST_HEADER)
    assert "| invrisil | cargo | invrisil_cargo_1 | 4 | no lidded or banded variants | invrisil_cargo_1 | open |" in text
    # the first run regenerated docs/asset-candidates.json from the fake batch (no slices
    # until lane B); restore the hand-written registry, as lane B's rebuild would list them
    write_registry(tree)
    # parcel_stack is now IN the pool, so it is no longer listed: the slice is #1
    assert run(tree, "invrisil", "cargo", "--need", "4", "--kind", "crate", "--select", "1",
               "--fallback", "crate_owned", "--lacked", "still no banded variant", "--base", "crate") == 0
    text = (tree / GEN).read_text()
    assert text.count("| invrisil | cargo |") == 1
    assert "| invrisil | cargo | invrisil_cargo_1, invrisil_cargo_2 | 4 | still no banded variant | crate | open |" in text
    assert kits(tree)["invrisil"]["roles"]["cargo"]["pool"] == ["invrisil_cargo_1", "invrisil_cargo_2"]


def test_new_region_module_role_and_explicit_ids(tree):
    assert run(tree, "liscor", "facade_window", "--need", "1", "--kind", "crate", "--select", "1",
               "--ids", "liscor_window_a", "--pick", "map", "--module") == 0
    k = kits(tree)
    assert k["liscor"]["materials"] == {} and k["liscor"]["cast"] == []
    assert k["liscor"]["roles"]["facade_window"] == {"pick": "map", "module": True, "pool": ["liscor_window_a"]}
    assert "liscor_window_a" in json.loads((tree / "wandering_inn_game/data/sprites.json").read_text())


def test_pack_pick_without_fallback_wires_nothing(tree):
    before = snapshot(tree)
    assert run(tree, "invrisil", "cargo", "--need", "2", "--kind", "crate", "--select", "2") == wa.EXIT_REFUSED
    assert snapshot(tree) == before


def test_select_validation_wires_nothing(tree):
    before = snapshot(tree)
    assert run(tree, "invrisil", "cargo", "--need", "2", "--kind", "crate", "--select", "1,9") == fk.EXIT_USAGE
    assert run(tree, "invrisil", "cargo", "--need", "2", "--kind", "crate", "--select", "1,1") == fk.EXIT_USAGE
    assert run(tree, "invrisil", "cargo", "--need", "2", "--kind", "crate", "--select", "1", "--ids", "a,b") == fk.EXIT_USAGE
    assert snapshot(tree) == before


def test_fixed_string_role_is_refused(tree):
    k = tree / KITS
    d = json.loads(k.read_text())
    d["invrisil"]["roles"]["cargo"] = "crate_owned"
    k.write_text(json.dumps(d, indent=1) + "\n")
    before = snapshot(tree)
    assert run(tree, "invrisil", "cargo", "--need", "2", "--kind", "crate", "--select", "1") == wa.EXIT_REFUSED
    assert changed(before, snapshot(tree)) == set()   # kits.json is checked BEFORE any wire_asset call


def test_never_calls_pixellab():
    src = (HERE.parent.parent / "tools" / "fill_kit.py").read_text()
    assert not re.search(r"^\s*(import|from)\s+(requests|urllib|http|socket)\b", src, re.M)
    assert "mcp__pixellab" not in src and "pixellab.ai" not in src
```

- [ ] **Step 2: Run to verify failure**

Run: `python3 -m pytest -q scripts/tests/test_fill_kit.py -k "select or shortfall or new_region or pack_pick or fixed_string or pixellab"`
Expected: the select/shortfall/new-region tests fail with `Refused: --select lands in Task 11`; `test_never_calls_pixellab` passes.

- [ ] **Step 3: Replace the `select` stub and add the helpers**

```python
# ----------------------------------------------------- surgical kits.json

def _string_end(text: str, i: int) -> int:
    """Index just past the closing quote of the JSON string that opens at text[i]."""
    j = i + 1
    while True:
        c = text[j]
        if c == "\\":
            j += 2
            continue
        if c == '"':
            return j + 1
        j += 1


def _children(text: str, open_idx: int, close_idx: int):
    """(key, key_idx, value_idx, value_end) for each depth-0 member of an object span."""
    i = open_idx + 1
    while i < close_idx:
        if text[i] in " \t\r\n,":
            i += 1
            continue
        key_end = _string_end(text, i)
        key = json.loads(text[i:key_end])
        j = text.index(":", key_end) + 1
        while text[j] in " \t\r\n":
            j += 1
        if text[j] in "{[":
            _, vc = splice_json.scan_container_span(text, text[j], "}" if text[j] == "{" else "]", j)
            val_end = vc + 1
        elif text[j] == '"':
            val_end = _string_end(text, j)
        else:
            val_end = re.compile(r"[^,\s\]}]+").match(text, j).end()
        yield key, i, j, val_end
        i = val_end


def _span(text: str, path: list[str]) -> tuple[int, int]:
    """(open_idx, close_idx) of the container reached by walking `path` from the top-level object."""
    o, c = splice_json.scan_container_span(text, "{", "}", 0)
    for key in path:
        for k, _ki, vi, _ve in _children(text, o, c):
            if k == key:
                if text[vi] not in "{[":
                    raise wa.Refused(f"kits.json: {'.'.join(path)} is not a container")
                o, c = splice_json.scan_container_span(text, text[vi], "}" if text[vi] == "{" else "]", vi)
                break
        else:
            raise wa.Refused(f"kits.json: missing key {'.'.join(path)}")
    return o, c


def _insert(text: str, o: int, c: int, body_json: str, key: str | None) -> str:
    if text[o + 1:c].strip():
        indent = splice_json.last_sibling_indent(text, o, c)
        body = splice_json.reindent(body_json, indent)
        if key is not None:
            body = '"%s": %s' % (key, body)
        tail = c
        while text[tail - 1] in " \t\n":
            tail -= 1
        return text[:tail] + ",\n" + indent + body + text[tail:]
    line_start = text.rfind("\n", 0, o) + 1
    base = re.match(r"[ \t]*", text[line_start:o]).group(0)
    indent = base + ("\t" if "\t" in base or text.startswith("{\n\t") else " ")
    body = splice_json.reindent(body_json, indent)
    if key is not None:
        body = '"%s": %s' % (key, body)
    return text[:o + 1] + "\n" + indent + body + "\n" + base + text[c:]


def _prove(before: str, after: str, path: list[str]) -> None:
    node = json.loads(after)
    for key in path:
        node = node[key]
    pre = 0
    while pre < min(len(before), len(after)) and before[pre] == after[pre]:
        pre += 1
    suf = 0
    while suf < min(len(before), len(after)) - pre and before[-1 - suf] == after[-1 - suf]:
        suf += 1
    if pre + suf < len(before):
        raise wa.Refused("kits.json splice changed bytes outside the insertion")


def add_key(text: str, path: list[str], key: str, value) -> str:
    o, c = _span(text, path)
    if text[o] != "{":
        raise wa.Refused(f"kits.json: {'.'.join(path) or '<root>'} is not an object")
    out = _insert(text, o, c, json.dumps(value, ensure_ascii=False), key)
    _prove(text, out, path + [key])
    return out


def append_item(text: str, path: list[str], value) -> str:
    o, c = _span(text, path)
    if text[o] != "[":
        raise wa.Refused(f"kits.json: {'.'.join(path)} is not an array")
    out = _insert(text, o, c, json.dumps(value, ensure_ascii=False), None)
    _prove(text, out, path)
    return out


def kits_with_pool(text: str, region: str, role: str, ids: list[str], pick: str, module: bool) -> str:
    data = json.loads(text)
    if region not in data:
        text = add_key(text, [], region, {"materials": {}, "roles": {}, "cast": []})
        data = json.loads(text)
    if "roles" not in data[region]:
        text = add_key(text, [region], "roles", {})
        data = json.loads(text)
    spec = data[region]["roles"].get(role)
    if spec is None:
        obj: dict = {"pick": pick}
        if module:
            obj["module"] = True
        obj["pool"] = list(ids)
        return add_key(text, [region, "roles"], role, obj)
    if isinstance(spec, str):
        raise wa.Refused(f"{region}.roles.{role} is a fixed sprite '{spec}'; convert it by hand before pooling")
    have = role_pool_ids(data, region, role)
    for sid in ids:
        if sid not in have:
            text = append_item(text, [region, "roles", role, "pool"], sid)
            have.append(sid)
    return text


# ------------------------------------------------------------- selection

def next_ids(region: str, role: str, n: int, catalog: dict, pool: list[str]) -> list[str]:
    out, k = [], len(pool) + 1
    while len(out) < n:
        sid = f"{region}_{role}_{k}"
        if sid not in catalog and sid not in pool:
            out.append(sid)
        k += 1
    return out


def generation_list_with(text: str, region: str, role: str, have: list[str], need: int,
                         lacked: str, base: str) -> str:
    if not text:
        text = GENERATION_LIST_HEADER
    row = f"| {region} | {role} | {', '.join(have) or '-'} | {need} | {lacked or '-'} | {base or '-'} | open |"
    lines = text.rstrip("\n").split("\n")
    for i, line in enumerate(lines):
        cells = [c.strip() for c in line.strip().strip("|").split("|")] if line.startswith("|") else []
        if len(cells) == 7 and cells[0] == region and cells[1] == role and cells[6] == "open":
            lines[i] = row
            return "\n".join(lines) + "\n"
    return "\n".join(lines + [row]) + "\n"


def select(args: argparse.Namespace, paths: wa.Paths, cands: list[Candidate], ktext: str,
           catalog: dict, pool: list[str], like: str | None) -> int:
    try:
        picks = [int(s) for s in args.select.split(",") if s.strip()]
    except ValueError:
        print(f"fill_kit: --select wants numbers from the listing, got {args.select!r}")
        return EXIT_USAGE
    known = {c.n: c for c in cands}
    if not picks or len(set(picks)) != len(picks) or any(n not in known for n in picks):
        print(f"fill_kit: --select {args.select} is not a set of listed numbers 1..{len(cands)}")
        return EXIT_USAGE
    ids = args.ids.split(",") if args.ids else next_ids(args.region, args.role, len(picks), catalog, pool)
    if len(ids) != len(picks) or any(not wa.ID_RE.match(i) for i in ids):
        print(f"fill_kit: --ids needs {len(picks)} valid id(s)")
        return EXIT_USAGE
    chosen = [known[n] for n in picks]
    if any(c.mode == "pack" for c in chosen) and not args.fallback:
        raise wa.Refused("a pack pick needs --fallback <owned public sprite_id> (public builds must not lose the pool)")
    # kits.json must be editable before any wiring happens
    kits_with_pool(ktext, args.region, args.role, ids, args.pick, args.module)
    wired: list[str] = []
    for c, sid in zip(chosen, ids):
        argv = [str(c.path), "--id", sid, "--repo-root", str(paths.repo_root), "--no-regen"]
        if c.mode == "pack":
            argv += ["--fallback", args.fallback]
        if like:
            argv += ["--like", like]
        rc = wa.main(argv)
        if rc != 0:
            raise wa.Refused(f"wire_asset exit {rc} for #{c.n} ({c.path.name}); pool not updated")
        wired.append(sid)
    wa.regenerate_candidates(paths)
    new_text = kits_with_pool(ktext, args.region, args.role, wired, args.pick, args.module)
    if new_text != ktext:
        kits_path(paths).write_text(new_text, encoding="utf-8")
    have = role_pool_ids(json.loads(new_text), args.region, args.role)
    print(f"pool {args.region}/{args.role}: {have}")
    if len(wired) < args.need:
        gl = paths.docs / "art-generation-list.md"
        gl.write_text(generation_list_with(wa.read_text(gl), args.region, args.role, have, args.need,
                                           args.lacked, args.base or (have[0] if have else "")), encoding="utf-8")
        print(f"shortfall: selected {len(wired)} < need {args.need}; open row in docs/art-generation-list.md")
    return EXIT_OK
```

Also add, right after `number`, the pool-membership filter that keeps an already-wired candidate from being listed (and re-numbered) again on the next run:

```python
def pool_signatures(catalog: dict, pool: list[str], paths: wa.Paths) -> tuple[set[str], set[tuple]]:
    """(sha256 of owned members' sheets, (sheet, region) of pack members) for the role's pool."""
    shas: set[str] = set()
    regions: set[tuple] = set()
    for sid in pool:
        entry = catalog.get(sid)
        if not isinstance(entry, dict):
            continue
        idle = (entry.get("animations") or {}).get("idle") or {}
        sheet = str(idle.get("sheet", "")).replace("res://", "")
        if idle.get("region"):
            regions.add((sheet, tuple(int(v) for v in idle["region"])))
        elif (paths.game / sheet).is_file():
            shas.add(wa.sha256_file(paths.game / sheet))
    return shas, regions


def not_yet_wired(cands: list[Candidate], shas: set[str], regions: set[tuple]) -> list[Candidate]:
    return [c for c in cands if c.sha not in shas
            and (c.mode != "pack" or (c.sheet, tuple(c.region)) not in regions)]
```

and in `fill()` replace the `cands = number(...)` line with:

```python
    shas, regions = pool_signatures(catalog, pool, paths)
    cands = number(not_yet_wired(compatible(query(paths, args.kind, scale), members, args.size), shas, regions)[: args.limit])
```

- [ ] **Step 4: Run**

Run: `python3 -m pytest -q scripts/tests/test_fill_kit.py`
Expected: `14 passed`.

- [ ] **Step 5: Commit**

```bash
git add tools/fill_kit.py scripts/tests/test_fill_kit.py
git commit -m "tools: fill_kit.py --select wires picks, splices data/kits.json pools, logs shortfalls

Nested surgical splice (placement + byte-identity proofs) for
<region>.roles.<role>.pool; pack picks need --fallback; a bad --select wires
nothing; shortfall writes one open row in docs/art-generation-list.md.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: `fill_kit.py --preview` through lane A's `wi_kits_lib.resolve_map` (Wave 2)

**Files:**
- Modify: `tools/fill_kit.py` (replace `preview`)
- Modify: `scripts/tests/test_fill_kit.py` (append)

**Interfaces:**
- Consumes (C5): `wi_kits_lib.load_kits(game_root: Path) -> dict`, `map_region(map_path: Path) -> str`, `resolve_map(map: dict, map_id: str, region: str, kits: dict) -> dict` — resolved rows carry `sprite` (concrete id) and `sprite_role` (C4).
- Produces: `preview(paths, region, role) -> int`, printing one line per resolved placement: `<map_id> <layer> [x, y] <sprite_id>`.

- [ ] **Step 1: Append the failing test**

```python
def test_preview_prints_resolved_picks_per_map(tree, capsys):
    kl = pytest.importorskip("wi_kits_lib")
    k = tree / KITS
    d = json.loads(k.read_text())
    d["invrisil"]["roles"]["cargo"] = {"pick": "cell", "pool": ["crate_owned", "crate"]}
    k.write_text(json.dumps(d, indent=1) + "\n")
    maps = tree / "wandering_inn_game/data/maps/invrisil"
    maps.mkdir(parents=True)
    m = {"biome": "inn", "grid": [8, 6], "decor": [{"sprite": "@cargo", "cell": [1, 1]}, {"sprite": "@cargo", "cell": [5, 1]},
                                                   {"sprite": "plant_pot", "cell": [2, 2]}],
         "entities": [{"id": "c", "kind": "prop", "cell": [3, 4], "sprite": "@cargo"}]}
    (maps / "test_map.json").write_text(json.dumps(m, indent=1) + "\n")
    assert run(tree, "invrisil", "cargo", "--preview") == 0
    out = capsys.readouterr().out.rstrip("\n").split("\n")
    expected = kl.resolve_map(m, "test_map", "invrisil", kl.load_kits(tree / "wandering_inn_game"))
    want = [f"test_map {layer} {row['cell']} {row['sprite']}" for layer in ("decor", "entities")
            for row in expected.get(layer, []) if row.get("sprite_role") == "cargo"]
    assert out == want and len(want) == 3
    assert all(line.split()[-1] in ("crate_owned", "crate") for line in out)
```

- [ ] **Step 2: Run to verify failure**

Run: `python3 -m pytest -q scripts/tests/test_fill_kit.py -k preview`
Expected: `Refused: preview lands with lane A's wi_kits_lib` → the test fails (or is skipped if `wi_kits_lib` is absent — then Wave 2 has not started; stop and rebase on lane A first).

- [ ] **Step 3: Replace the `preview` stub**

```python
def preview(paths: wa.Paths, region: str, role: str) -> int:
    import wi_kits_lib as kl  # lane A, C5; code from this repo, data from --repo-root
    kits = kl.load_kits(paths.game)
    maps_dir = paths.game / "data" / "maps" / region
    if not maps_dir.is_dir():
        raise wa.Refused(f"no maps under {maps_dir}")
    for mp in sorted(maps_dir.glob("*.json")):
        if mp.name.startswith("_"):
            continue
        m = json.loads(mp.read_text(encoding="utf-8"))
        resolved = kl.resolve_map(m, mp.stem, kl.map_region(mp), kits)
        for layer in ("decor", "entities"):
            for row in resolved.get(layer, []):
                if row.get("sprite_role") == role:
                    print(f"{mp.stem} {layer} {row.get('cell')} {row['sprite']}")
    return EXIT_OK
```

- [ ] **Step 4: Run the whole lane's pytest**

Run: `python3 -m pytest -q scripts/tests/test_fill_kit.py scripts/tests/test_wire_asset.py`
Expected: `41 passed`.

- [ ] **Step 5: Commit**

```bash
git add tools/fill_kit.py scripts/tests/test_fill_kit.py
git commit -m "tools: fill_kit.py --preview resolves the region's maps through wi_kits_lib

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Lane gates and close

**Files:**
- Modify: `HANDOFF.md` (lane C: done, evidence paths, next action = composition on `issue/607-kits-foundation`)

- [ ] **Step 1: Settle the tree, import, then the lane's pytest**

```bash
git status --porcelain            # must be empty
/usr/local/bin/godot --headless --path wandering_inn_game --import > "$SCRATCH/import2.log" 2>&1; echo "rc=$?"
python3 -m pytest -q scripts/tests/test_wire_asset.py scripts/tests/test_fill_kit.py; echo "rc=$?"
```
Expected: empty status, `rc=0`, `41 passed`, `rc=0`.

- [ ] **Step 2: data_lint**

```bash
python3 wandering_inn_game/scripts/data_lint.py > "$SCRATCH/data_lint.log" 2>&1; echo "rc=$?"
grep -cE 'ERROR|FAIL' "$SCRATCH/data_lint.log"
```
Expected: `rc=0`, `0`.

- [ ] **Step 3: preflight --full (GD unit suites discovered by glob, including the migrated registry test)**

```bash
scripts/preflight.sh --full > "$SCRATCH/preflight-full.log" 2>&1; echo "rc=$?"
grep -c 'PREFLIGHT: ALL GREEN' "$SCRATCH/preflight-full.log"
grep -E '^(ok|FAIL) +unit test_sprite_registry|^(ok|FAIL) +unit test_fixture_coherence|^(ok|FAIL) +python tool suites' "$SCRATCH/preflight-full.log"
```
Expected: `rc=0`, `1`, three `ok` lines.

- [ ] **Step 4: load_gate headless**

```bash
wandering_inn_game/qa/run_qa.sh load_gate headless > "$SCRATCH/load_gate.log" 2>&1; echo "rc=$?"
python3 -c "import json;print(json.load(open('wandering_inn_game/qa_output/load_gate/result.json'))['passed'])"
grep -cE 'WARNING|SCRIPT ERROR|Parse Error|ERROR:' "$SCRATCH/load_gate.log"
```
Expected: `rc=0`, `True`, `0`.

- [ ] **Step 5: leak_check and the wire_asset staging proof**

```bash
scripts/leak_check.sh; echo "rc=$?"
git ls-files potential_assets/ | wc -l
git diff --name-only issue/607-kits-foundation...HEAD | grep -cE '^potential_assets/|^wandering_inn_game/assets/' 
python3 scripts/comment_census.py --check; echo "rc=$?"
```
Expected: `leak_check: clean …` `rc=0`; `0`; `0` (lane C's branch adds nothing under `potential_assets/` or `assets/` — only dry-runs ran on the real tree); census `rc=0`.

- [ ] **Step 6: Self-review against the spec and contracts** (no code; tick each)

- §4.2 owned PNG → `assets/sprites/<id>/`, provenance appended: Task 4.
- §4.2 pack slice → `region` row on the bundled sheet, no loose copies, provenance = source sheet + region: Task 6.
- §4.2 anchor from the alpha probe; frame size and count from sheet dimensions: Tasks 4–5.
- §4.2 sprites.json entry + frame-count pin + candidates regen: Tasks 4, 7.
- §4.2 pack variants require `fallback_sprite`; wire_asset requires it to exist and be public (the ≥2-distinct-owned pool rule is lane A's lint): Task 6.
- §4.2 fixture migration generated once from `_build_expected_counts`, keeps fail-on-missing-key: Tasks 1–2 (Phase 0 exit criterion).
- §4.2 `fill_kit` steps 1–3, 6–7 (query, filter, contact sheet, wire + kits.json, generation row); step 4–5 are the Fable pool read: Tasks 9–11.
- §4.3 generation-list columns: Task 3 and `generation_list_with`.
- C7 format and the `:23-24` contract: Task 2.
- C9 CLI shapes, exit 3 + `BUNDLE-PENDING`, the two doc rows: Tasks 6, 11.
- C5 names only, Wave 2: Task 12.
- Global: no map gains `@`; no real wiring on the branch; `sprites.json` never reserialized (Task 4 surgical test); `potential_assets` never staged (Task 7 + Step 5).

- [ ] **Step 7: HANDOFF and push**

```bash
git add HANDOFF.md
git commit -m "docs: HANDOFF lane C complete (fixture, wire_asset, fill_kit) with gate evidence

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin issue/607-lane-c
```

Composition (index "Lane order and exits" step 3) happens on `issue/607-kits-foundation` after lanes A and B land: regenerate `tools/asset_candidates.py`, `tools/asset_index.py`, `derive_qa_surfaces.py`, `render_qa_notes.py --write`, then the full gate list there. Lane C ships no QA manifest change, so `derive_qa_surfaces.py --check` stays green on this branch.
