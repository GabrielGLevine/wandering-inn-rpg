# Harvest Wiring Implementation Plan

> Status: **ACTIVE** (user ruling 2026-10-05: best art wins per asset)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the 2026-10 PixelLab harvest (~1,900 kept owned assets, unwired) into the game so every surface shows the best art available in each build, and the public repo stops showing flat-colour placeholders.

**Architecture:** One engine mechanism (W0) — a `sprites.json` record may name a `fallback_sprite`, an owned record that resolves when any primary sheet is missing (public checkout) — then six content waves (W1–W6) that each run a per-asset A/B judgement and wire the winner as primary or as fallback. Tile and UI-chrome fallbacks are NOT drop-in (owned Wang tilesets use different atlas coordinates; owned UI kits use different 9-slice margins), so their mechanisms are designed inside their own waves.

**Tech Stack:** Godot 4.7 GDScript (`WISpriteRegistry`), JSON data (`data/sprites.json`, `data/biomes.json`, maps), Python tooling (`scripts/data_lint.py`, `tools/find_asset.py`), declarative QA (`qa/run_qa.sh … windowed`).

**Tracking:** milestone "Harvest wiring (owned art)", issues #554–#562.

**Spec:** this file + `potential_assets/pixellab_harvest_2026-10/INDEX.md` (cross-lane wiring traps) + each lane's `MANIFEST.json`/`MANIFEST.md` (per-asset target, verdict, feet plane, fixes owed). Query any target with `python3 tools/find_asset.py <use words>`.

## Global Constraints

- **Best art wins, per asset (user ruling 2026-10-05).** If the owned candidate reads better in play than the shipped pack art, it REPLACES the primary. If the pack art reads better, the pack stays primary in official builds (private bundle) and the owned asset becomes its `fallback_sprite` for public checkouts. Never downgrade an official build for licensing.
- The judgement is a windowed screenshot at gameplay scale, owned vs shipped, in the real scene. Rubric: silhouette readability at a glance, scene/style coherence with neighbours (do not drop one PIXELLAB-AI prop into an all-PC16 room if it clashes), fidelity, semantic fit. Controller decides; close calls are logged to `docs/CHOICE-LOG.md` and surfaced at wave close, never blocking the wave.
- Every wired sprite: alpha-bbox feet anchor (`anchor.y = feet_plane / frame_h`), measured `render_scale`, expected frame counts in `tests/test_sprite_registry.gd`, `shadow: true` if taller than one cell, windowed read before "done".
- Interactables must read at a glance; data_lint's <10px legibility advisory must stay quiet for wired props.
- `pc_*` ids stay player-only (registry gate); a `fallback_sprite` target may never be `pc_*`.
- Tint is not disambiguation: never wire a retint where the manifest gave a distinct silhouette.
- Owned art is SHIP-OK: commit sheets under `wandering_inn_game/assets/sprites/<id>/`, no `assets_manifest.json` row, and append provenance to `wandering_inn_game/assets/LICENSES/v019-owned-art-provenance.txt` (the tracked owned-art record; the PixelLab verdict notes under `potential_assets/` are gitignored).
- Never commit anything from `potential_assets/`; copy the chosen file into `assets/`.
- After any wave, rebuild `docs/asset-candidates.*` (`python3 tools/asset_candidates.py`) so wired assets show as SHIPPED.

## Waves

| Wave | Scope (source lane) | Mechanism needed | Key gates |
|---|---|---|---|
| **W0** #554 | `fallback_sprite` in `WISpriteRegistry` + lint + crate pilot | this plan, Tasks 1–4 | unit + lint + public/overlay windowed pair |
| **W1** #555 | Public de-placeholder: 57 bundle-only prop ids (L2), `pc_human_m` (L3a; account char 35528619), goblins ×4 / bat / rat (L3a) — A/B each vs shipped pack art | W0 | per-asset A/B screenshot table in PR |
| **W1b** #556 | Tilesets: 23 Wang sheets (L4) vs bundle tiles per biome | biome-level `fallback` design (owned atlas has its own cell map) | `_assert_biome_tiles_build`, windowed per biome |
| **W1c** #557 | UI chrome: 10 owned kits vs Tiny Swords (`src/ui/ui_chrome.gd:16-21`, margins `:71-77`) | `chrome_texture(path, fallback_path)` + per-texture margins; hotbar numeral colour on dark slots (`src/ui/hotbar.gd:27`) | windowed panels/buttons/hotbar, phone layout (#505) |
| **W2** #558 | Icons: 116 skill (L1 `skills/`, `skills_n16/`), 70 item (L1 `items/` → `assets/icons/items/<id>.png`), owned `icon_attack`/`icon_dash` | none (code-drawn glyphs are owned already; replace outright where owned art wins) | hotbar + inventory windowed reads; sibling distinctness (VISUAL-LOG #449/#438 rows) |
| **W3** #559 | NPC rigs: 23 new (L3b), walk cycles for 12 idle-only rigs (L3b `walks/`), Selys fix (`data/maps/inn/inn.json:890` → `selys`) | none | anchor per clip; one-rig-one-named-character; walk N/S/E/W windowed |
| **W4** #560 | Enemy rigs + combat sets (L3a): footpad(+bruiser L3b), scavenger, line stalker v3, vault construct, seal warden, wards, bulky thrall, 9 static-frame beasts | none | `combat_scale` bar containment; board screenshots; balance-neutral (no stat edits) |
| **W5** #561 | Map dressing: 16 #519 before/after pairs, 83 set pieces, VISUAL-LOG prop asks (L2) | #519 state wiring per that issue | reachability/blocking unchanged; VISUAL-LOG rows closed with evidence |
| **W6** #562 | Key art: title backdrop (`title_backdrop_pro_v1`), act cards, emblem (L4) | title/act UI surfaces (`src/ui/title_screen.gd:51,153`) | 1280x720 + phone layouts; paint out baked text (`act4_v2` signature) |

W1–W6 each get their own detailed plan file at wave start (`docs/superpowers/plans/<date>-harvest-wN-<slug>.md`), written against the manifests; this file details W0 only. W2–W6 do not depend on each other; W1b/W1c depend only on their own mechanism.

## Per-asset A/B procedure (W1+)

1. `python3 tools/find_asset.py <target> --tier owned` → pick the READY row (fix USABLE-WITH-FIX rows first per their manifest note).
2. Copy the PNG/sheets to `wandering_inn_game/assets/sprites/<target>_owned/` (frames normalised to one frame size — v3 clips arrive on larger canvases than base rotations, see INDEX.md), register `<target>_owned` in `sprites.json`, measure anchor/scale.
3. Windowed screenshot of the scene with the shipped primary, then with the map row (or a QA peek script) pointing at `<target>_owned`. Read both.
4. Owned wins → point the primary's sheets at the owned files (delete `<target>_owned`, drop the pack path from `assets_manifest.json` if no other id uses it). Pack wins → keep primary, add `"fallback_sprite": "<target>_owned"`.
5. Record `target | winner | reason | screenshot` in the wave PR table.

---

## W0 file structure

- Modify `wandering_inn_game/src/world/sprite_registry.gd` — add `resolved_id()` + `_missing_any_sheet()`; route `entry_for()` and `frames_for()` through it. One responsibility stays one file: the registry owns sheet resolution already (placeholder contract).
- Modify `wandering_inn_game/tests/test_sprite_registry.gd` — new `_assert_fallback_sprite_resolution()`; main loop reads the RESOLVED entry.
- Modify `wandering_inn_game/scripts/data_lint.py` — `check_sprite_fallbacks()`.
- Modify `scripts/tests/test_data_lint.py` — tests for it.
- Create `wandering_inn_game/assets/sprites/crate_owned/Idle-Sheet.png`; modify `data/sprites.json` (`crate`, new `crate_owned`); modify `assets/LICENSES/v019-owned-art-provenance.txt`.
- Modify `.agents/skills/wi-art-and-sprites/references/asset-recipes.md` (+ mirror sync), `docs/CHOICE-LOG.md`.

### Task 1: `fallback_sprite` resolution in the registry

**Files:**
- Modify: `wandering_inn_game/src/world/sprite_registry.gd:46-48` (`entry_for`), `:88-113` (`frames_for`)
- Test: `wandering_inn_game/tests/test_sprite_registry.gd`

**Interfaces:**
- Produces: `static func resolved_id(sprite_id: String) -> String` — returns `entry.fallback_sprite` when that id exists in the catalog AND any `sheet*` path of the primary entry fails `ResourceLoader.exists`; else `sprite_id`. `entry_for()`, `anchor_for()` (via `entry_for`) and `frames_for()` return the resolved entry's data. `has_sprite()` is unchanged (keys on the requested id). `sprites.json` holds only presentation keys (`animations`, `render_scale`, `anchor`, `shadow`, `directional`, `field_y_sort_bias_px`), so swapping the whole entry is correct.

- [ ] **Step 1: Write the failing test** — append to `tests/test_sprite_registry.gd` and call it from `_init()` next to `_assert_missing_sheet_fallback()`:

```gdscript
func _assert_fallback_sprite_resolution() -> void:
	# Synthetic entries: never depends on whether the private overlay is installed.
	var real_sheet := "res://assets/sprites/door_locked_heavy/Idle-Sheet.png"
	assert(ResourceLoader.exists(real_sheet), "fixture sheet moved: " + real_sheet)
	WISpriteRegistry._load_catalog()
	var cat: Dictionary = WISpriteRegistry._catalog
	cat["__t_owned"] = {"render_scale": 0.4, "anchor": [0.5, 0.75],
		"animations": {"idle": {"sheet": real_sheet, "frame_size": [64, 64], "fps": 1}}}
	cat["__t_missing"] = {"render_scale": 1.0, "fallback_sprite": "__t_owned",
		"animations": {"idle": {"sheet": "res://assets/__nonexistent_pack__.png", "frame_size": [16, 23], "fps": 1}}}
	cat["__t_present"] = {"render_scale": 1.0, "fallback_sprite": "__t_owned",
		"animations": {"idle": {"sheet": real_sheet, "frame_size": [64, 64], "fps": 1}}}
	cat["__t_dangling"] = {"fallback_sprite": "__t_nope",
		"animations": {"idle": {"sheet": "res://assets/__nonexistent_pack__.png", "frame_size": [16, 16], "fps": 1}}}
	assert(WISpriteRegistry.resolved_id("__t_missing") == "__t_owned", "missing primary must resolve to its fallback")
	assert(WISpriteRegistry.resolved_id("__t_present") == "__t_present", "present primary must stay primary")
	assert(WISpriteRegistry.resolved_id("__t_dangling") == "__t_dangling", "unknown fallback id must not resolve")
	assert(is_equal_approx(WISpriteRegistry.anchor_for("__t_missing").y, 0.75), "anchor must follow the fallback art")
	assert(is_equal_approx(float(WISpriteRegistry.entry_for("__t_missing")["render_scale"]), 0.4), "render_scale must follow the fallback art")
	var frames := WISpriteRegistry.frames_for("__t_missing")
	var tex := frames.get_frame_texture("idle", 0) as AtlasTexture
	assert(tex.region.size == Vector2(64, 64), "frames must use the fallback geometry, not the 16x23 pack frame")
	assert(not WISpriteRegistry.is_fallback_sheet(real_sheet), "fallback art is real art, not a placeholder")
	for k: String in ["__t_owned", "__t_missing", "__t_present", "__t_dangling"]:
		cat.erase(k)
		WISpriteRegistry._cache.erase(k)
```

- [ ] **Step 2: Run to verify it fails**

Run: `/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_sprite_registry.gd`
Expected: FAIL — parse error / "Invalid call. Nonexistent function 'resolved_id'".

- [ ] **Step 3: Implement** in `sprite_registry.gd` (below `anchor_for`), and route the two readers:

```gdscript
## Best-art-wins contract (user ruling 2026-10-05): an entry whose primary
## sheets ship only in the private bundle may name `fallback_sprite` -- an
## OWNED record drawn instead when any primary sheet is missing (a public
## checkout). The WHOLE entry swaps (anchor, render_scale, frame geometry)
## because pack art and owned art differ; sprites.json holds presentation
## keys only, so nothing gameplay-facing is lost. An unknown fallback id
## falls through to the placeholder contract below.
static func resolved_id(sprite_id: String) -> String:
	_load_catalog()
	var entry: Dictionary = _catalog.get(sprite_id, {})
	var fallback := String(entry.get("fallback_sprite", ""))
	if fallback == "" or not _catalog.has(fallback):
		return sprite_id
	return fallback if _missing_any_sheet(entry) else sprite_id


static func _missing_any_sheet(entry: Dictionary) -> bool:
	for anim: Variant in (entry.get("animations", {}) as Dictionary).values():
		if not anim is Dictionary:
			continue
		for key: String in (anim as Dictionary):
			if key.begins_with("sheet") and not ResourceLoader.exists(String(anim[key])):
				return true
	return false
```

`entry_for` becomes:

```gdscript
static func entry_for(sprite_id: String) -> Dictionary:
	_load_catalog()
	return _catalog.get(resolved_id(sprite_id), {})
```

In `frames_for`, replace `var entry: Dictionary = _catalog[sprite_id]` with:

```gdscript
	var entry: Dictionary = _catalog[resolved_id(sprite_id)]
```

(keep the cache keyed on the requested `sprite_id`; resolution is fixed for a run.)

- [ ] **Step 4: Make the catalog loop read the resolved entry** — in `_init()`, the per-sprite loop must compare frames against the entry that was actually built, or public CI breaks the first time a fallback resolves:

```gdscript
		var resolved: String = WISpriteRegistry.resolved_id(sprite_id)
		var entry: Dictionary = catalog[resolved]
```

and key the expected-count lookup on `resolved`:

```gdscript
				var expected: int = expected_counts.get("%s/%s" % [resolved, anim_name], -1)
				assert(expected >= 0, "no expected frame count for %s/%s" % [resolved, anim_name])
```

- [ ] **Step 5: Run to verify it passes**

Run: `/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_sprite_registry.gd`
Expected: exit 0, no assertion output.

- [ ] **Step 6: Commit**

```bash
git add wandering_inn_game/src/world/sprite_registry.gd wandering_inn_game/tests/test_sprite_registry.gd
git commit -m "feat(sprites): fallback_sprite resolves owned art when primary sheets are missing"
```

### Task 2: Lint the fallback contract

**Files:**
- Modify: `wandering_inn_game/scripts/data_lint.py` (new `check_sprite_fallbacks`, call it beside `check_sprites(parsed, errors)` at ~`:2646`)
- Test: `scripts/tests/test_data_lint.py`

**Interfaces:**
- Consumes: `fallback_sprite` key shape from Task 1.
- Produces: `check_sprite_fallbacks(parsed: dict, errors: list) -> None`, errors for: unknown target, self-target, chained fallback (target has its own `fallback_sprite`), `pc_*` target, target whose sheets are bundle-only in `assets_manifest.json` (a fallback that is itself missing in public is pointless).

- [ ] **Step 1: Write the failing tests** in `scripts/tests/test_data_lint.py` (inside the class holding `test_sprites_missing_animations`):

```python
    def test_sprite_fallback_contract(self):
        anim = lambda sheet: {"idle": {"sheet": sheet, "frame_size": [16, 16]}}  # noqa: E731
        parsed = {data_lint.DATA / "sprites.json": {
            "ok": {"fallback_sprite": "ok_owned", "animations": anim("res://assets/props/a.png")},
            "ok_owned": {"animations": anim("res://assets/sprites/ok_owned/Idle-Sheet.png")},
            "dangling": {"fallback_sprite": "nope", "animations": anim("res://x.png")},
            "selfish": {"fallback_sprite": "selfish", "animations": anim("res://x.png")},
            "chain": {"fallback_sprite": "ok", "animations": anim("res://x.png")},
            "pc_ref": {"fallback_sprite": "pc_human_m", "animations": anim("res://x.png")},
            "pc_human_m": {"animations": anim("res://assets/sprites/pc/Idle.png")},
            "to_bundle": {"fallback_sprite": "bundled", "animations": anim("res://x.png")},
            "bundled": {"animations": anim("res://assets/props/free_pack/Furniture.png")},
        }}
        bundle = {"assets/props/free_pack/Furniture.png"}
        errs = []
        data_lint.check_sprite_fallbacks(parsed, errs, bundle_paths=bundle)
        joined = "\n".join(errs)
        for bad in ("'dangling'", "'selfish'", "'chain'", "'pc_ref'", "'to_bundle'"):
            self.assertIn(bad, joined)
        self.assertNotIn("'ok'", joined)
        self.assertEqual(len(errs), 5)
```

- [ ] **Step 2: Run to verify it fails**

Run: `python3 -m pytest -q scripts/tests/test_data_lint.py -k fallback`
Expected: FAIL — `AttributeError: module 'data_lint' has no attribute 'check_sprite_fallbacks'`.

- [ ] **Step 3: Implement** in `data_lint.py` after `check_sprites`:

```python
def _bundle_paths() -> set:
	manifest = GAME_ROOT / "assets_manifest.json"
	if not manifest.exists():
		return set()
	data = json.loads(manifest.read_text(encoding="utf-8"))
	return {a["path"] for a in data.get("assets", []) if a.get("bundle")}


def check_sprite_fallbacks(parsed: dict, errors: list, bundle_paths: set | None = None) -> None:
	"""Best-art-wins (2026-10-05): `fallback_sprite` names the OWNED record a
	public checkout draws when the primary's bundle-only sheets are missing.
	It must exist, not be itself, not chain, not be a pc_* skin, and must not
	itself be bundle-only (it would be missing in exactly the case it serves)."""
	sprites = parsed.get(DATA / "sprites.json") or {}
	bundle = _bundle_paths() if bundle_paths is None else bundle_paths
	for sid, entry in sprites.items():
		if not isinstance(entry, dict) or "fallback_sprite" not in entry:
			continue
		target = str(entry["fallback_sprite"])
		where = f"sprites.json: '{sid}' fallback_sprite '{target}'"
		if target == sid:
			errors.append(f"{where} points at itself")
			continue
		if target not in sprites:
			errors.append(f"{where} is not a sprite id")
			continue
		if target.startswith("pc_"):
			errors.append(f"{where} is a player-only pc_* skin")
			continue
		tgt = sprites[target]
		if "fallback_sprite" in tgt:
			errors.append(f"{where} chains to another fallback")
			continue
		sheets = [str(v).replace("res://", "") for a in tgt.get("animations", {}).values()
			if isinstance(a, dict) for k, v in a.items() if k.startswith("sheet")]
		if any(s in bundle for s in sheets):
			errors.append(f"{where} is itself bundle-only (missing in the public checkout it serves)")
```

and call it right after `check_sprites(parsed, errors)`:

```python
	check_sprite_fallbacks(parsed, errors)
```

(`data_lint.py` indents with tabs and already imports `json` and `GAME_ROOT`.)

- [ ] **Step 4: Run to verify it passes**

Run: `python3 -m pytest -q scripts/tests/test_data_lint.py && python3 wandering_inn_game/scripts/data_lint.py`
Expected: tests PASS; lint exits 0 on the real data (no fallbacks exist yet).

- [ ] **Step 5: Commit**

```bash
git add wandering_inn_game/scripts/data_lint.py scripts/tests/test_data_lint.py
git commit -m "feat(lint): enforce the fallback_sprite contract"
```

### Task 3: Crate pilot (end-to-end proof in both builds)

`crate` is the second most-used bundle-only prop (35 map refs; `data/sprites.json` `crate` → `res://assets/props/free_pack/Furniture.png` region `[736,73,16,23]`). The pilot proves the mechanism and the A/B procedure; it does not decide crate's winner in advance.

**Files:**
- Create: `wandering_inn_game/assets/sprites/crate_owned/Idle-Sheet.png` (copy of `potential_assets/pixellab_harvest_2026-10/L2_props/crate.png`, 64x64)
- Modify: `wandering_inn_game/data/sprites.json`, `wandering_inn_game/tests/test_sprite_registry.gd` (`_build_expected_counts`), `wandering_inn_game/assets/LICENSES/v019-owned-art-provenance.txt`

**Interfaces:**
- Consumes: Task 1 (`fallback_sprite`), Task 2 (lint).
- Produces: sprite id `crate_owned`; `crate` gains `"fallback_sprite": "crate_owned"` OR (if owned wins) `crate` points at the owned sheet.

- [ ] **Step 1: Copy and measure**

```bash
mkdir -p wandering_inn_game/assets/sprites/crate_owned
cp potential_assets/pixellab_harvest_2026-10/L2_props/crate.png wandering_inn_game/assets/sprites/crate_owned/Idle-Sheet.png
python3 - <<'EOF'
from PIL import Image
im = Image.open("wandering_inn_game/assets/sprites/crate_owned/Idle-Sheet.png").convert("RGBA")
bbox = im.getchannel("A").getbbox()
print("bbox", bbox, "feet_plane", bbox[3], "anchor_y", round(bbox[3] / im.height, 4),
      "scale_for_23px", round(23 / (bbox[3] - bbox[1]), 3))
EOF
```

Expected: a bbox line; use `anchor_y` and `scale_for_23px` (matches the pack crate's 23px rendered height) below.

- [ ] **Step 2: Register** in `data/sprites.json` next to `crate` (values from Step 1):

```json
"crate_owned": {
 "_comment": "Owned PixelLab crate (harvest 2026-10, L2_props/crate.png) -- public fallback for the bundle-only `crate` (best-art-wins A/B in the W0 PR).",
 "render_scale": <scale_for_23px>,
 "anchor": [0.5, <anchor_y>],
 "shadow": true,
 "animations": {"idle": {"sheet": "res://assets/sprites/crate_owned/Idle-Sheet.png", "frame_size": [64, 64], "fps": 1}}
}
```

add to `_build_expected_counts()`:

```gdscript
	counts["crate_owned/idle"] = 1  ## single 64x64 frame
```

and add `"fallback_sprite": "crate_owned"` to the `crate` entry.

- [ ] **Step 3: Import + lint + unit**

```bash
/usr/local/bin/godot --headless --path wandering_inn_game --import
python3 wandering_inn_game/scripts/data_lint.py
/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_sprite_registry.gd
```

Expected: all exit 0.

- [ ] **Step 4: A/B windowed read — overlay checkout (official build)**

Find a crate-dense map with `grep -l '"sprite": "crate"' wandering_inn_game/data/maps/*/*.json | head`, add a peek script `wandering_inn_game/qa/scripts/harvest_crate_peek.json` modelled on `qa/scripts/sprite_upgrade_peek.json` (teleport beside the crates, `wait_frames` 12, `screenshot`). Run `wandering_inn_game/qa/run_qa.sh harvest_crate_peek windowed` with the private overlay installed (`scripts/fetch_private_assets.sh`). Then temporarily set the crate row(s) on that map to `crate_owned`, rerun, read both screenshots, revert the temporary edit.

- [ ] **Step 5: Public-mode windowed read**

```bash
git worktree add /tmp/wi-public-check HEAD   # a worktree has no gitignored overlay = public checkout
/usr/local/bin/godot --headless --path /tmp/wi-public-check/wandering_inn_game --import
/tmp/wi-public-check/wandering_inn_game/qa/run_qa.sh harvest_crate_peek windowed
git worktree remove /tmp/wi-public-check
```

Expected: crates draw as the owned crate (not a flat chip) at the same footprint; read the screenshot.

- [ ] **Step 6: Decide and finalise** — owned wins → point `crate`'s `idle.sheet` at the owned sheet with the owned frame/anchor/scale, delete `crate_owned` and its expected count, and remove `Furniture.png` from `assets_manifest.json` only if no other sprite id uses it (`grep -c Furniture.png wandering_inn_game/data/sprites.json`). Pack wins → keep as wired. Append to `assets/LICENSES/v019-owned-art-provenance.txt`:

```
assets/sprites/crate_owned/Idle-Sheet.png
    PixelLab AI (harvest 2026-10, object 3bce8a00...; L2_props/MANIFEST.md),
    user-owned + redistributable. Public fallback for the bundle-only crate.
```

- [ ] **Step 7: Commit**

```bash
git add wandering_inn_game/assets/sprites/crate_owned wandering_inn_game/data/sprites.json wandering_inn_game/tests/test_sprite_registry.gd wandering_inn_game/assets/LICENSES/v019-owned-art-provenance.txt wandering_inn_game/qa/scripts/harvest_crate_peek.json
git commit -m "feat(art): crate pilot for best-art-wins fallback"
```

(If the peek script is kept, register it in `qa/manifest.json` as a non-canonical peek per `wi-writing-qa-scripts`; otherwise delete it before committing.)

### Task 4: Guidance + ruling + full gates

**Files:**
- Modify: `.agents/skills/wi-art-and-sprites/references/asset-recipes.md` (then `python3 scripts/sync_agent_guidance.py --write`), `docs/CHOICE-LOG.md` (section "Current product and system rulings", head), `docs/asset-candidates.*` (regenerated)

- [ ] **Step 1: Recipe** — append to the `## Registry` section of `asset-recipes.md`:

```markdown
Best art wins per asset (2026-10-05). When owned art loses an A/B to
bundle-only pack art, keep the pack record and add
`"fallback_sprite": "<id>_owned"`: `WISpriteRegistry.resolved_id()` swaps
the whole record (geometry, anchor, scale) when any primary sheet is missing,
so public checkouts draw real owned art instead of a placeholder chip.
`data_lint` rejects dangling, self, chained, `pc_*` and bundle-only targets.
```

- [ ] **Step 2: Ruling** — insert at the head of "Current product and system rulings" in `docs/CHOICE-LOG.md`:

```markdown
- **Best art wins, per asset (user, 2026-10-05).** Owned generated art
  replaces pack art only when it reads better in play; otherwise the pack
  stays primary in official builds and the owned asset becomes the public
  checkout's `fallback_sprite`. Rejected: replacing all pack art with owned
  art for licensing simplicity (would downgrade official builds).
```

- [ ] **Step 3: Regenerate + full gates**

```bash
python3 scripts/sync_agent_guidance.py --write
python3 tools/asset_candidates.py
scripts/preflight.sh --full
python3 -m pytest -q scripts/
scripts/leak_check.sh
```

Expected: all green; `find_asset.py crate` now shows `crate_owned` as SHIPPED.

- [ ] **Step 4: Commit and open the W0 PR** with the A/B screenshot pair (overlay vs owned vs public) in the body.

```bash
git add .agents/skills/wi-art-and-sprites .claude/skills/wi-art-and-sprites docs/CHOICE-LOG.md docs/asset-candidates.json docs/asset-candidates.md
git commit -m "docs(art): best-art-wins ruling + fallback_sprite recipe"
```

## Self-review notes

- Spec coverage: ruling → Global Constraints + Task 4; mechanism → Tasks 1–2; proof in both builds → Task 3 Steps 4–5; every harvest lane maps to a wave row; tile/UI non-drop-in risk → W1b/W1c rows.
- Names used across tasks: `resolved_id`, `_missing_any_sheet`, `fallback_sprite`, `check_sprite_fallbacks(parsed, errors, bundle_paths=None)`, `crate_owned` — consistent.
- Known risk: public CI is the first place a fallback resolves for real; Task 1 Step 4 keeps the catalog loop honest there.
