#!/usr/bin/env python3
"""tools/asset_coverage.py on a synthetic potential_assets/ tree (CI has none).
Run: python3 -m pytest -q scripts/tests/test_asset_coverage.py"""
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO_ROOT / "tools"))
import asset_coverage as cov  # noqa: E402

PNG = b"\x89PNG\r\n\x1a\n"


def touch(root: Path, rel: str) -> None:
    p = root / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(PNG)


def tree(tmp_path: Path) -> tuple[Path, Path, Path]:
    assets = tmp_path / "potential_assets"
    pc = "Pixel Crawler - Forge 1.2/Pixel Crawler - Forge"
    for rel in (f"{pc}/Assets/Props.png", f"{pc}/Assets/Tiles.png", f"{pc}/Assets/Odd.png",
                f"{pc}/Enemy/Stone/Idle/Idle-Sheet.png", f"{pc}/Social/MockUp-01.png",
                "Pixel Crawler - Forge 2/Assets/Props.png",
                "Ninja Adventure/Ui/Theme/button.png", "Ninja Adventure/FX/Magic/spark.png",
                "16-bit RPG Music/cover.png",
                "pixellab_x/L2_props/crate.png", "pixellab_x/L3a_rigs/bard/rotations/south.png",
                "pixellab_x/L2_props/_work/crate_draft.png",
                "goblin-pack/goblin-pack/frames/up/up_01.png",
                "goblin-huts-pack/frames/hut_01.png",
                "Ninja Adventure/Backgrounds/Animated/Flag/FlagRed.png",
                "pixellab_x/L2_props/trough__after.png",
                "_sliced/Pixel Crawler - Forge 1.2/Props/Props__x0_y0_w16_h16.png",
                "license-notes/scan.png"):
        touch(assets, rel)
    sliced = assets / "_sliced/Pixel Crawler - Forge 1.2/Props/SLICES.json"
    huts = assets / "_sliced/goblin-huts-pack/huts/SLICES.json"
    huts.parent.mkdir(parents=True)
    touch(assets, "goblin-huts-pack/goblin-huts-spritesheet.png")
    huts.write_text(json.dumps({"sheet": "potential_assets/goblin-huts-pack/goblin-huts-spritesheet.png",
                                "frame_exports": {"potential_assets/goblin-huts-pack/frames/hut_01.png": [0, 0, 64, 64]},
                                "assets": [{"region": [2, 2, 40, 40]}]}))
    sliced.write_text(json.dumps({"sheet": f"potential_assets/{pc}/Assets/Props.png", "assets": [
        {"region": [0, 0, 16, 16], "duplicate_sheets": ["potential_assets/Pixel Crawler - Forge 2/Assets/Props.png"]},
        {"region": [16, 0, 16, 16], "duplicate_sheets": ["potential_assets/Pixel Crawler - Forge 2/Assets/Props.png"]}]}))
    registry = tmp_path / "asset-candidates.json"
    registry.write_text(json.dumps({"assets": [
        {"path": f"potential_assets/{pc}/Assets/Tiles.png", "kind": "tileset"},
        {"path": "potential_assets/pixellab_x/L2_props/crate.png", "kind": "prop"},
        {"path": "potential_assets/pixellab_x/L3a_rigs/bard/", "kind": "rig"},
        {"path": "wandering_inn_game/assets/x.png", "kind": "prop"}]}))
    excl = tmp_path / "exclusions.json"
    excl.write_text(json.dumps({"pending_rulings": [
        {"glob": "Ninja Adventure/**/Backgrounds/Animated/**", "reason": "NINJA16 family unverified"},
        {"glob": "pixellab_*/**/*__after.png", "reason": "needs L2_props MANIFEST row + verdict"}], "exclusions": [
        {"glob": "Ninja Adventure/**", "reason": "a broad exclusion never swallows a pending ruling"},
        {"glob": "Pixel Crawler - */**/Social/**", "reason": "promo renders"},
        {"glob": "pixellab_*/**/_work/**", "reason": "PixelLab work files"},
        {"glob": "goblin-pack/**", "class": "rig_or_animation", "reason": "goblin rig frames"},
        {"glob": "nothing/**", "reason": "matches nothing"}]}))
    return assets, registry, excl


def test_every_class_and_first_match_wins(tmp_path):
    assets, registry, excl = tree(tmp_path)
    sliced = cov.sliced_index(assets)
    files, dirs = cov.registry_index(registry)
    rules = cov.load_exclusions(excl)
    got = {rel: cov.classify(rel, sliced, files, dirs, rules) for rel in cov.list_pngs(assets)}
    pc = "Pixel Crawler - Forge 1.2/Pixel Crawler - Forge"
    assert got == {
        f"{pc}/Assets/Props.png": ("sliced", "2"),
        "Pixel Crawler - Forge 2/Assets/Props.png": ("sliced", "duplicate"),
        f"{pc}/Assets/Tiles.png": ("tileset", "tileset"),
        f"{pc}/Assets/Odd.png": ("UNCLASSIFIED", ""),
        f"{pc}/Enemy/Stone/Idle/Idle-Sheet.png": ("rig_or_animation", "path"),
        f"{pc}/Social/MockUp-01.png": ("excluded", "Pixel Crawler - */**/Social/**"),
        "Ninja Adventure/Ui/Theme/button.png": ("ui_or_icon", "path"),
        "Ninja Adventure/FX/Magic/spark.png": ("rig_or_animation", "path"),
        "16-bit RPG Music/cover.png": ("audio", "path"),
        "pixellab_x/L2_props/crate.png": ("owned_wired", "prop"),
        "pixellab_x/L3a_rigs/bard/rotations/south.png": ("rig_or_animation", "rig"),
        "pixellab_x/L2_props/_work/crate_draft.png": ("excluded", "pixellab_*/**/_work/**"),
        "goblin-pack/goblin-pack/frames/up/up_01.png": ("rig_or_animation", "goblin-pack/**"),
        "goblin-huts-pack/goblin-huts-spritesheet.png": ("sliced", "1"),
        "goblin-huts-pack/frames/hut_01.png": ("sliced", "frame export"),
        "Ninja Adventure/Backgrounds/Animated/Flag/FlagRed.png": (
            "pending_ruling", "Ninja Adventure/**/Backgrounds/Animated/**"),
        "pixellab_x/L2_props/trough__after.png": ("pending_ruling", "pixellab_*/**/*__after.png"),
    }, "_sliced/ and license-notes/ are outside the universe"


def test_file_names_never_classify(tmp_path):
    # An environment sheet named like a UI or rig file still needs intake.
    assert cov.dir_words("Pack/Assets/Icons.png") == {"pack", "assets"}
    assert cov.dir_words("Pack/Npc's/UI Elements/x.png") == {"pack", "npc", "s", "ui", "elements"}


def test_glob_semantics():
    rx = cov.glob_regex("Pixel Crawler - */**/Social/**")
    assert rx.match("Pixel Crawler - Cave/Social/Tiles.png")
    assert rx.match("Pixel Crawler - Cave/Pixel Crawler - Cave/Social/a/b.png")
    assert not rx.match("Pixel Crawler - Cave/Assets/Social.png")
    assert not rx.match("Other/Pixel Crawler - Cave/Social/x.png")
    one = cov.glob_regex("Pack/*.png")
    assert one.match("Pack/a.png") and not one.match("Pack/sub/a.png")


def test_exclusion_entries_must_carry_reason_and_known_class(tmp_path):
    bad = tmp_path / "bad.json"
    bad.write_text(json.dumps({"exclusions": [{"glob": "a/**"}]}))
    try:
        cov.load_exclusions(bad)
    except ValueError:
        pass
    else:
        raise AssertionError("an exclusion without a reason must be refused")
    bad.write_text(json.dumps({"exclusions": [{"glob": "a/**", "reason": "r", "class": "sliced"}]}))
    try:
        cov.load_exclusions(bad)
    except ValueError:
        pass
    else:
        raise AssertionError("sliced/tileset/owned cannot be asserted by an exclusion")
    bad.write_text(json.dumps({"exclusions": [{"glob": "a/**", "reason": "r", "class": "pending_ruling"}]}))
    try:
        cov.load_exclusions(bad)
    except ValueError:
        pass
    else:
        raise AssertionError("a pending ruling lives in pending_rulings, never folded into exclusions")


def test_zero_slice_sheet_is_not_covered(tmp_path):
    assets = tmp_path / "potential_assets"
    touch(assets, "P/Assets/Props.png")
    sj = assets / "_sliced/P/Props/SLICES.json"
    sj.parent.mkdir(parents=True)
    sj.write_text(json.dumps({"sheet": "potential_assets/P/Assets/Props.png", "assets": []}))
    assert cov.classify("P/Assets/Props.png", cov.sliced_index(assets), {}, [], []) == ("UNCLASSIFIED", "")


def test_check_mode_writes_nothing_and_fails_on_unclassified(tmp_path, capsys):
    assets, registry, excl = tree(tmp_path)
    out = tmp_path / "asset-coverage.md"
    base = ["--assets-root", str(assets), "--registry", str(registry), "--exclusions", str(excl),
            "--out", str(out)]
    assert cov.main(base + ["--check"]) == 1
    text = capsys.readouterr().out
    assert "PENDING 1 pixellab_*/**/*__after.png" in text and "1 UNCLASSIFIED, 2 pending_ruling" in text
    assert "UNCLASSIFIED Pixel Crawler - Forge 1.2/Pixel Crawler - Forge/Assets/Odd.png" in text
    assert "WARN exclusion glob matches nothing: nothing/**" in text
    assert not out.exists()
    assert cov.main(base) == 0
    md = out.read_text()
    assert "| Pixel Crawler - Forge 1.2 | 5 | 1 [2] | 1 | 1 |  |  |  |  | 1 | 1 |" in md
    assert "| Pixel Crawler - Forge 2 | 1 | 1 [0] |" in md, "a duplicate's slices are counted once"
    assert "| goblin-huts-pack | 2 | 2 [1] |" in md, "a frame export counts as sliced, slices once"
    assert "2 pending_ruling" in md.splitlines()[9]
    pend = md.index("## Pending rulings (2)")
    assert pend < md.index("## Per pack") and pend < md.index("## Exclusions in use")
    assert "- **`Ninja Adventure/**/Backgrounds/Animated/**`** (1 PNGs): NINJA16 family unverified" in md
    assert "  - `pixellab_x/L2_props/trough__after.png`" in md
    assert "Backgrounds/Animated/**` | pending_ruling" not in md, "pending rulings are not exclusions"
    assert "- `Pixel Crawler - Forge 1.2/Pixel Crawler - Forge/Assets/Odd.png`" in md
    first = md
    assert cov.main(base) == 0 and out.read_text() == first, "output is deterministic"
    (assets / "Pixel Crawler - Forge 1.2/Pixel Crawler - Forge/Assets/Odd.png").unlink()
    assert cov.main(base + ["--check"]) == 0


def test_missing_assets_root_skips_with_note(tmp_path, capsys):
    assert cov.main(["--assets-root", str(tmp_path / "absent"), "--check"]) == 0
    assert "SKIP asset coverage" in capsys.readouterr().out
