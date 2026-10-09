# Regional Kits Phase 0 (Foundations) Implementation Plan

> Status: **ACTIVE**
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the kit resolver, the atlas-slicing supply pipeline and the pool-first wiring tools without changing any shipped map (issue #607).

**Architecture:** Three file-disjoint lanes compose on `issue/607-kits-foundation`:
- **Lane A** adds compose-time kit resolution and its Python mirror and lint.
- **Lane B** slices pack atlases into indexed, labeled candidates.
- **Lane C** migrates the frame-count pins to data and adds the wiring and kit-filling tools.

The lane plans are separate files. This index pins the shared contracts that all three must use verbatim.

**Tech Stack:** Godot 4.7 GDScript (headless tests in `wandering_inn_game/tests/`), Python 3 (tools and `scripts/tests` pytest), declarative QA (`wandering_inn_game/qa/`).

**Spec:** `docs/superpowers/specs/2026-10-08-regional-kits-design.md`

**Lane plans:**
- Lane A: `docs/superpowers/plans/2026-10-08-regional-kits-phase0-lane-a.md`
- Lane B: `docs/superpowers/plans/2026-10-08-regional-kits-phase0-lane-b.md`
- Lane C: `docs/superpowers/plans/2026-10-08-regional-kits-phase0-lane-c.md`

## Global Constraints

- **Branches:**
  - The issue branch is `issue/607-kits-foundation`, from `main` at `7155db91`.
  - Lane branches are `issue/607-lane-a`, `issue/607-lane-b` and `issue/607-lane-c`, each in its own worktree under `/private/tmp/wi-607-<lane>`.
  - At most two implementation workers are active at once.
- **No player-visible change in Phase 0.**
  - No map JSON gains a `@` reference.
  - `data/kits.json` ships with `_common` only, holding empty `roles`, `materials` and `cast`.
  - Biome rows are added but referenced by no map.
- **Paths:** `tools/` and `docs/` are at the repo root. `scripts/`, `qa/`, `data/`, `src/`, `tests/` and `assets/` are under `wandering_inn_game/`. Repo-root `scripts/tests/` holds the pytest suites, which preflight runs.
- **Assets and licensing:**
  - Never track `potential_assets/` or any `assets_manifest.json` path; `scripts/leak_check.sh` is authoritative.
  - No private bundle release is allowed (HANDOFF constraint).
  - Pack art may only be wired as a `region` row on a pack sheet that is already present under `wandering_inn_game/assets/`.
- **Map JSON:** edit shipped mixed-format JSON surgically (`scripts/splice_json.py` for appends). Never re-sort map rows.
- **Hygiene:**
  - Comment ceilings are enforced by `scripts/comment_census.py --check`.
  - New `.gd` files need an import pass (`/usr/local/bin/godot --headless --path wandering_inn_game --import`), and their `.uid` sidecars are committed.
  - A new lane worktree needs the private overlay copied in (see HANDOFF "Commands and environment") before QA.
- **Evidence:** preserve the exit code and success marker; reject `SCRIPT ERROR`, `Parse Error`, `ERROR:` and `WARNING`. Never pipe a gate into `head` or `tail`.

## Shared contracts (use verbatim)

### C1. `data/kits.json` schema

```json
{
  "_comment": "Regional kits: role pools, materials and anonymous casts per region. Spec docs/superpowers/specs/2026-10-08-regional-kits-design.md.",
  "_common": {"materials": {}, "roles": {}, "cast": []},
  "<region>": {
    "materials": {"<name>": {"sheet": "res://…", "tile_px": 16, "coords": [0, 0], "tone": {}, "fallback_render": {}}},
    "roles": {
      "<role>": "<sprite_id>",
      "<role>": {"pick": "cell|map|door", "module": false, "pool": ["<id>", ["<id>", 2]], "light": {}}
    },
    "cast": ["<sprite_id>"]
  }
}
```

- Keys beginning with `_` other than `_common` are comments.
- A map's region is its folder under `data/maps/`; a top-level map `"kit"` overrides it.
- Lookup order: region, then `_common`, then a hard assert or lint error.

### C2. References in map JSON

- `decor[].sprite` / `entities[].sprite`: `"@<role>"`.
- `floor_layers[].material`, `walls.material`, `walls.segments[].material`: `"@<material>"`. Material fields fill only the keys the row lacks.

### C3. Pick algorithm (GDScript and Python must agree bit for bit)

- `H(key)` is the first 32 bits of SHA-256 over the UTF-8 key:
  - GDScript: `key.sha256_text().substr(0, 8).hex_to_int()`;
  - Python: `int(hashlib.sha256(key.encode("utf-8")).hexdigest()[:8], 16)`.

  The two were verified identical on 2026-10-08, including non-ASCII keys, and the parity test pins them. This amends the original `String.hash()` (djb2), which is linear and collapses picks (lane A Task 2 review).
- Keys:
  - variant key: `"%s|%s|%s" % [map_id, role, variant]`;
  - placement key: `"%s|%s|%s|%d,%d" % [map_id, role, variant, x, y]`.
- `score(key, weight) = -ln((H(key) + 0.5) / 4294967296.0) / weight`. The **smallest** score wins.
- **Subset:**
  - `k = clamp(2 + n // 6, 2, 4)` then `k = min(k, len(pool))`, where `n` is the number of placements of that role in the map.
  - The subset is the k variants with the smallest variant-key score.
- **Ranking:** `rank_p` is the subset sorted by placement-key score (ascending; ties by variant id).
- **Resolve:**
  - Visit the role's placements in `(y, x)` order.
  - Choose the first variant in `rank_p` not already chosen by a same-role placement at Chebyshev distance `<= r`.
  - `r = 0` for `pick: "door"`, `1` for `module: true`, otherwise `2`.
  - If every variant is excluded, choose `rank_p[0]`.
- **`pick: "map"`:** every placement takes `subset[0]`. That is the smallest variant-key score, so the subset is not sized by `n` here.
- **`pick: "door"`:**
  - The key map id is the unordered portal pair `min(map_id, to_map) + "<>" + max(map_id, to_map)`, and there is no cell component.
  - Each placement takes the smallest-score variant.
  - It is only valid on `kind: "door"` entities that have `to_map`.
- **Plain string role:** a fixed sprite.

### C4. Compose output

- A resolved row keeps every authored field.
- `sprite` is replaced by the concrete id, and `"sprite_role": "<role>"` is added.
- Material refs are replaced by merged concrete fields, plus `"material_ref": "<name>"`.
- A role-level `light` is copied only if the row has no `light`.
- Resolution happens in `WISceneCatalog._compose()` right after `_expand_talk_banks`.
- The resolver is a pure static class `WIKitResolver` in `src/core/kit_resolver.gd`. The catalog reads `res://data/kits.json` and passes the dictionary in.
- **Signatures:**
  - `WIKitResolver.resolve_map(map: Dictionary, map_id: String, region: String, kits: Dictionary) -> Dictionary`
  - `WIKitResolver.hash32(key: String) -> int`
  - `WIKitResolver.score(key: String, weight: float) -> float`

### C5. Python mirror `wandering_inn_game/scripts/wi_kits_lib.py`

- `godot_string_hash(s: str) -> int`
- `score(key: str, weight: float) -> float`
- `load_kits(game_root: Path) -> dict`
- `map_region(map_path: Path) -> str`
- `resolve_map(map: dict, map_id: str, region: str, kits: dict) -> dict` (same output as C4)
- `resolve_all(game_root: Path) -> dict[str, list[dict]]`, mapping map_id to `[{"layer": "decor"|"entities", "cell": [x, y], "sprite_role": str, "sprite": str}]` for resolved rows only.

### C6. Events

- `ui_entity_visual_rendered` gains `"sprite_role"` when the entity row has one.
- A new `ui_decor_rendered {map: String, roles: {role: [variant, …]}}` is emitted once per map build. Roles appear only when decor rows carry `sprite_role`; the event is emitted even when empty.

### C7. Frame-count fixture `wandering_inn_game/qa/fixtures/sprite_frame_counts.json`

- Format: `{"_comment": "...", "counts": {"<sprite_id>/<anim>": <int>, …}}`.
- `tests/test_sprite_registry.gd` reads it instead of `_build_expected_counts`.
- A missing key still fails the assert at `:23-24`.

### C8. Slice candidates

- Each `potential_assets/_sliced/<pack>/<sheet-stem>/SLICES.json` (top-level root; pack folders may be read-only) is `{"assets": [row, …]}`.
- A row: `{"path": "potential_assets/_sliced/<pack>/<stem>/<stem>__x{X}_y{Y}_w{W}_h{H}.png", "kind": "prop", "targets": ["<kind-tag>", …], "verdict": "UNREVIEWED", "notes": "", "source_sheet": "potential_assets/…/<sheet>.png", "region": [X, Y, W, H], "sheet_sha256": "<hex>", "method": "grid16|grid32|seam|component|override", "has_shadow": false, "size_class": "S|M|L|XL", "label_confidence": 0.0}`
- Kind vocabulary (closed): `crate barrel sack door window lamp table seat shelf bed plant rock debris tool sign wall_module container other`.

### C9. Wiring CLI

- `python3 tools/wire_asset.py <candidate_path>… --id <sprite_id> [--kind prop] [--fallback <owned_sprite_id>] [--dry-run]`.
- A pack slice resolves to the bundled game sheet by matching `sheet_sha256` against the files under `wandering_inn_game/assets/`. If nothing matches, it exits 3 and prints `BUNDLE-PENDING <source_sheet>`.
- `python3 tools/fill_kit.py <region> <role> --need N [--kind <tag>] [--contact-sheet out.png] [--select id,id,…]`.
- A shortfall appends one row to `docs/art-generation-list.md`, and a bundle-pending candidate appends one row to `docs/art-bundle-pending.md`.

## Lane order and exits

1. **Wave 1:** Lane A and Lane C tasks 1–3 (fixture migration and `wire_asset`) run in parallel.
2. **Wave 2:** Lane B, plus Lane C `fill_kit`, which imports `wi_kits_lib` from Lane A.
3. **Composition:** merge the lanes into `issue/607-kits-foundation` and regenerate the derived files: `python3 tools/asset_candidates.py`, `python3 tools/asset_index.py`, `wandering_inn_game/scripts/derive_qa_surfaces.py`, `scripts/render_qa_notes.py --write`. Then run:
   - `python3 wandering_inn_game/scripts/data_lint.py`
   - `scripts/preflight.sh --full`
   - `wandering_inn_game/qa/run_qa.sh load_gate headless`
   - `wandering_inn_game/qa/ci_sweep.sh --touching wandering_inn_game/src/core/scene_catalog.gd,wandering_inn_game/src/world/world.gd`
   - `scripts/leak_check.sh`
   - `python3 scripts/comment_census.py --check`
4. **Close:** PR `Closes #607` from the issue-close template after an independent review and green required CI, then squash-merge.
