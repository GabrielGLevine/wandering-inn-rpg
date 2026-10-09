#!/usr/bin/env python3
"""tools/slice_atlases.py: synthetic atlases only (CI has no potential_assets/).
Run: python3 -m pytest -q scripts/tests/test_slice_atlases.py"""
import json
import sys
from pathlib import Path

import pytest

PIL = pytest.importorskip("PIL")
from PIL import Image, ImageDraw  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO_ROOT / "tools"))
import slice_atlases as sa  # noqa: E402

BLACK = (0, 0, 0, 255)
BROWN = (140, 90, 40, 255)
CLEAR = (0, 0, 0, 0)


def outlined_box(im, x, y, w, h, fill=BROWN):
    """A sprite with a 1px near-black outline and a light fill."""
    d = ImageDraw.Draw(im)
    d.rectangle((x, y, x + w - 1, y + h - 1), fill=fill, outline=BLACK)


def packed_crates(path: Path) -> Image.Image:
    """The #398 sheet: two 16x23 crates flush at x0-31 (double outline at x15/x16)
    and a barrel flush at x32-47 (double outline at x31/x32): ONE alpha component.
    65x33 is deliberately not a 16/32 multiple, so no grid expansion applies and
    the trimmed seam pieces are what the tests see."""
    im = Image.new("RGBA", (65, 33), CLEAR)
    outlined_box(im, 0, 0, 16, 23)
    outlined_box(im, 16, 0, 16, 23)
    outlined_box(im, 32, 1, 16, 22, fill=(90, 70, 50, 255))
    im.save(path)
    return im


def rgba(im):
    data = im.tobytes()
    return data, data[3::4], im.size[0], im.size[1]


def test_components_are_8_connected_with_exclusive_boxes():
    im = Image.new("RGBA", (8, 8), CLEAR)
    im.putpixel((1, 1), BROWN)
    im.putpixel((2, 2), BROWN)   # diagonal neighbour joins
    im.putpixel((6, 6), BROWN)   # separate
    data, alpha, w, h = rgba(im)
    labels, boxes = sa.components(alpha, w, h)
    assert boxes == [[1, 1, 3, 3, 2], [6, 6, 7, 7, 1]]
    assert labels[1 * w + 1] == labels[2 * w + 2] == 1 and labels[6 * w + 6] == 2


def test_double_outline_seam_splits_fused_crates(tmp_path):
    im = packed_crates(tmp_path / "Furniture.png")
    data, alpha, w, h = rgba(im)
    labels, boxes = sa.components(alpha, w, h)
    assert len(boxes) == 1, "flush sprites fuse into one alpha component"
    pieces = sa.split_box(data, labels, 1, w, boxes[0])
    assert [(p[0][:4], p[1]) for p in pieces] == [
        ([0, 0, 16, 23], "seam"), ([16, 0, 32, 23], "seam"), ([32, 1, 48, 23], "seam")]


def test_single_dark_column_is_not_a_seam():
    # One shared outline column between two fills: cutting it would strip an edge.
    present = [23] * 20
    dark = [23, 0, 0, 0, 0, 0, 0, 0, 0, 23, 0, 0, 0, 0, 0, 0, 0, 0, 0, 23]
    assert sa.seams(present, dark) == []


def test_solid_dark_mass_is_not_a_seam():
    # A black 24-wide block: every column is dark, no light flanks, no cut.
    assert sa.seams([24] * 24, [24] * 24) == []
    # A 3-wide dark band is a drawn stripe, not two outlines.
    band = [0] * 20
    band[9] = band[10] = band[11] = 20
    assert sa.seams([20] * 20, band) == []
    # Double dark columns WITH lighter flanks cut once, between k=9 and k=10,
    # even when a flank is 75% dark (a barrel's curved second column).
    dark = [0] * 20
    dark[9] = dark[10] = 20
    dark[11] = 15
    assert sa.seams([20] * 20, dark) == [10]


def test_tall_components_are_never_seam_split():
    # Two flush 16x65 "tree trunks" share a double outline but exceed SEAM_MAX_H.
    im = Image.new("RGBA", (33, 66), CLEAR)
    outlined_box(im, 0, 0, 16, 65)
    outlined_box(im, 16, 0, 16, 65)
    data, alpha, w, h = rgba(im)
    labels, boxes = sa.components(alpha, w, h)
    assert sa.split_box(data, labels, 1, w, boxes[0]) == [([0, 0, 32, 65, boxes[0][4]], "component")]


def test_grid_detection_and_cell_expansion():
    boxes = [[3, 3, 13, 13, 100], [19, 3, 29, 13, 100], [35, 3, 45, 13, 100], [3, 19, 13, 29, 100]]
    assert sa.sheet_grid(64, 32, boxes) == 16
    assert sa.cell_box(boxes[1], 16) == [16, 0, 32, 16]
    assert sa.sheet_grid(65, 33, boxes) is None, "sheet dims must be cell multiples"
    straddle = [[3, 3, 20, 13, 100], [19, 3, 29, 13, 100], [35, 3, 45, 13, 100], [3, 19, 13, 29, 100]]
    assert sa.sheet_grid(64, 32, straddle) is None, "2 of 4 clean is under GRID_CLEAN"
    assert sa.intersects([0, 0, 16, 16], [15, 15, 20, 20]) and not sa.intersects([0, 0, 16, 16], [16, 0, 20, 20])


def test_size_class_shadow_and_overlap():
    assert [sa.size_class(16, 9), sa.size_class(17, 9), sa.size_class(64, 1), sa.size_class(65, 1)] == ["S", "M", "L", "XL"]
    im = Image.new("RGBA", (8, 8), CLEAR)
    outlined_box(im, 1, 1, 6, 5)
    assert sa.has_shadow(im) is False
    im.putpixel((3, 7), (0, 0, 0, 90))
    assert sa.has_shadow(im) is True
    assert sa.overlap_ratio([736, 73, 16, 23], [720, 73, 48, 23]) == 1.0, "containment counts as full"
    assert sa.overlap_ratio([0, 0, 16, 16], [8, 0, 16, 16]) == 0.5
    assert sa.overlap_ratio([0, 0, 16, 16], [16, 0, 16, 16]) == 0.0
    assert sa.iou([736, 73, 16, 23], [720, 73, 48, 23]) == pytest.approx(1 / 3)
    assert sa.iou([0, 0, 16, 16], [0, 0, 16, 16]) == 1.0
    assert set(sa.KINDS) == {"crate", "barrel", "sack", "door", "window", "lamp", "table", "seat",
                             "shelf", "bed", "plant", "rock", "debris", "tool", "sign",
                             "wall_module", "container", "other"}


def sprite_sheet(path: Path, boxes, size=(64, 32)) -> Image.Image:
    path.parent.mkdir(parents=True, exist_ok=True)
    im = Image.new("RGBA", size, CLEAR)
    for x, y, w, h in boxes:
        outlined_box(im, x, y, w, h)
    im.save(path)
    return im


def test_eligible_rules():
    ok = ["Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png",
          "Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Props.png",
          "Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png"]
    bad = ["Admurins_Freebies-2/x/Props.png",
           "Pixel Crawler - Cave/Pixel Crawler - Cave/Enemies/Fungus/Idle-Sheet.png",
           "Pixel Crawler - Cave/Pixel Crawler - Cave/Social/Props.png",
           "Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Tiles.png",
           "Pixel Crawler - Free Pack/Environment/Tilesets/Floors_Tiles.png",
           "Pixel Crawler - Free Pack/Environment/Props/Static/Shadows.png",
           "Pixel Crawler - Free Pack/Environment/Structures/Stations/Anvil/Anvil.png",
           "Pixel Crawler - Free Pack/Environment/Props/Static/Bonfire_01-Sheet.png",
           "_sliced/Pixel Crawler - Free Pack/Furniture/Furniture__x0_y0_w16_h16.png",
           "Pixel Crawler - Free Pack/MockUps/Tavern_01.png"]
    assert [sa.eligible(Path(p)) for p in ok] == [True] * 3
    assert [sa.eligible(Path(p)) for p in bad] == [False] * len(bad)


def test_find_sheets_dedupes_by_sha_and_records_duplicates(tmp_path):
    assets = tmp_path / "potential_assets"
    a = assets / "Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png"
    b = assets / "Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png"
    c = assets / "Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Props.png"
    sprite_sheet(a, [(0, 0, 16, 16)])
    b.parent.mkdir(parents=True)
    b.write_bytes(a.read_bytes())
    sprite_sheet(c, [(0, 0, 16, 16), (32, 0, 16, 16)])
    trees = assets / "Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_03"
    sprite_sheet(trees / "Size_03-export.png", [(0, 0, 16, 16), (16, 0, 16, 16)])
    (trees / "Size_03.png").write_bytes((trees / "Size_03-export.png").read_bytes())
    found = sa.find_sheets(assets)
    assert [s.relative_to(assets).parts[0] for s, _ in found] == [
        "Pixel Crawler - Cave", "Pixel Crawler - Free Pack", "Pixel Crawler - Free Pack"]
    assert found[1][1] == ["potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png"]
    assert found[0][1] == []
    assert found[2][0].name == "Size_03.png", "the shorter twin is primary"
    assert found[2][1] == ["potential_assets/Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_03/Size_03-export.png"]
    assert [s.name for s, _ in sa.find_sheets(assets, only="Cave")] == ["Props.png"]


def test_sheet_stem_prefixes_non_generic_parent():
    assert sa.sheet_stem(Path("P/Environment/Props/Static/Furniture.png")) == "Furniture"
    assert sa.sheet_stem(Path("P/Assets/Props.png")) == "Props"
    assert sa.sheet_stem(Path("P/Environment/Structures/Buildings/Props.png")) == "Props"
    assert sa.sheet_stem(Path("P/Environment/Props/Static/Trees/Model_01/Size_02.png")) == "Model_01_Size_02"


def test_bundled_index_and_wired_regions(tmp_path):
    game = tmp_path / "wandering_inn_game"
    sheet = game / "assets/props/free_pack/Furniture.png"
    sprite_sheet(sheet, [(0, 0, 16, 16)])
    (game / "data").mkdir()
    (game / "data/sprites.json").write_text(json.dumps({
        "_comment": "x",
        "crate": {"animations": {"idle": {"sheet": "res://assets/props/free_pack/Furniture.png",
                                          "region": [0, 0, 16, 16]}}},
        "walker": {"animations": {"idle": {"sheet": "res://assets/sprites/w/Idle-Sheet.png"}}}}))
    idx = sa.bundled_index(game)
    assert idx == {sa.sha256(sheet): "res://assets/props/free_pack/Furniture.png"}
    assert sa.wired_regions(game) == {"res://assets/props/free_pack/Furniture.png": [("crate", [0, 0, 16, 16])]}
    assert sa.wired_regions(tmp_path / "nowhere") == {}


def game_fixture(tmp_path, sheet_src: Path, wired=None):
    game = tmp_path / "wandering_inn_game"
    dst = game / "assets/props/free_pack" / sheet_src.name
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(sheet_src.read_bytes())
    (game / "data").mkdir(exist_ok=True)
    sprites = {"_comment": "x"}
    for sid, region in (wired or {}).items():
        sprites[sid] = {"animations": {"idle": {"sheet": "res://assets/props/free_pack/" + sheet_src.name,
                                                "region": region}}}
    (game / "data/sprites.json").write_text(json.dumps(sprites))
    return game


def test_slice_sheet_rows_follow_c8_and_record_bundled_and_wired(tmp_path):
    assets = tmp_path / "potential_assets"
    src = assets / "Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png"
    src.parent.mkdir(parents=True)
    packed_crates(src)
    game = game_fixture(tmp_path, src, {"crate": [16, 0, 16, 23]})
    out_dir = sa.out_dir_for(src, assets, sa.sha256(src))
    assert out_dir == assets / "_sliced/Pixel Crawler - Free Pack/Furniture"
    doc, crops = sa.slice_sheet(src, assets, out_dir, [], sa.bundled_index(game), sa.wired_regions(game), ["dupe"])
    rows = doc["assets"]
    assert [r["region"] for r in rows] == [[0, 0, 16, 23], [16, 0, 16, 23], [32, 1, 16, 22]]
    crate = rows[1]
    assert crate["path"] == "potential_assets/_sliced/Pixel Crawler - Free Pack/Furniture/Furniture__x16_y0_w16_h23.png"
    assert crate["source_sheet"] == "potential_assets/Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png"
    assert crate["sheet_sha256"] == sa.sha256(src) and crate["method"] == "seam"
    assert (crate["kind"], crate["verdict"], crate["notes"], crate["has_shadow"]) == ("prop", "UNREVIEWED", "", False)
    assert crate["size_class"] == "M" and crate["label_confidence"] == 0.0 and crate["label_kind"] == ""
    assert crate["bundled"] is True and crate["game_sheet"] == "res://assets/props/free_pack/Furniture.png"
    assert crate["wired_ids"] == ["crate"] and crate["targets"] == ["crate"]
    assert rows[0]["wired_ids"] == [] and rows[0]["targets"] == []
    assert crate["duplicate_sheets"] == ["dupe"]
    assert doc["grid"] is None and doc["tier"] == "pack-bundle" and doc["family"] == "PC16"
    assert crops[1].size == (16, 23)


def test_grid_sheet_expands_to_cells_and_marks_method(tmp_path):
    assets = tmp_path / "potential_assets"
    src = assets / "Pixel Crawler - Free Pack/Environment/Props/Static/Meat.png"
    sprite_sheet(src, [(3, 3, 10, 10), (19, 3, 10, 10), (35, 3, 10, 10), (3, 19, 10, 10)], size=(64, 32))
    doc, crops = sa.slice_sheet(src, assets, sa.out_dir_for(src, assets, "x"), [], {}, {}, [])
    assert doc["grid"] == 16
    assert [r["region"] for r in doc["assets"]] == [[0, 0, 16, 16], [16, 0, 16, 16], [32, 0, 16, 16], [0, 16, 16, 16]]
    assert {r["method"] for r in doc["assets"]} == {"grid16"} and {r["size_class"] for r in doc["assets"]} == {"S"}
    assert doc["assets"][0]["bundled"] is False and doc["assets"][0]["game_sheet"] == ""


def test_override_replaces_overlapping_auto_slice(tmp_path):
    assets = tmp_path / "potential_assets"
    src = assets / "Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png"
    src.parent.mkdir(parents=True)
    packed_crates(src)
    doc, _ = sa.slice_sheet(src, assets, sa.out_dir_for(src, assets, "x"), [[0, 0, 32, 23]], {}, {}, [])
    assert [(r["region"], r["method"]) for r in doc["assets"]] == [([0, 0, 32, 23], "override"), ([32, 1, 16, 22], "seam")]
    assert doc["overrides"] == [[0, 0, 32, 23]]


def test_shadow_flag_from_semi_alpha(tmp_path):
    assets = tmp_path / "potential_assets"
    src = assets / "Pixel Crawler - Desert/Pixel Crawler - Desert/Assets/Props.png"
    im = sprite_sheet(src, [(2, 2, 12, 12), (34, 2, 12, 12)], size=(64, 32))
    for x in range(34, 46):
        im.putpixel((x, 15), (0, 0, 0, 80))
    im.save(src)
    doc, _ = sa.slice_sheet(src, assets, sa.out_dir_for(src, assets, "x"), [], {}, {}, [])
    assert [r["has_shadow"] for r in doc["assets"]] == [False, True]


def run_cli(tmp_path, *extra):
    assets = tmp_path / "potential_assets"
    game = tmp_path / "wandering_inn_game"
    return sa.main(["--assets-root", str(assets), "--game-root", str(game), *extra])


def test_cli_is_idempotent_and_skips_strips_and_dupes(tmp_path, capsys):
    assets = tmp_path / "potential_assets"
    src = assets / "Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png"
    src.parent.mkdir(parents=True)
    packed_crates(src)
    dupe = assets / "Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png"
    dupe.parent.mkdir(parents=True)
    dupe.write_bytes(src.read_bytes())
    sprite_sheet(assets / "Pixel Crawler - Cave/Pixel Crawler - Cave/Enemies/Fungus/Idle-Sheet.png", [(0, 0, 16, 16)])
    sprite_sheet(assets / "Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Tiles.png", [(0, 0, 16, 16)])
    game_fixture(tmp_path, src)
    assert run_cli(tmp_path) == 0
    out = assets / "_sliced/Pixel Crawler - Free Pack/Furniture"
    first = (out / "SLICES.json").read_text()
    names = sorted(p.name for p in out.iterdir())
    assert names == ["Furniture__x0_y0_w16_h23.png", "Furniture__x16_y0_w16_h23.png",
                     "Furniture__x32_y1_w16_h22.png", "SLICES.json", "contact.png"]
    assert not (assets / "Pixel Crawler - Free Pack 2.1/_sliced/Pixel Crawler - Free Pack").exists()
    assert not list(assets.glob("*/**/_sliced"))
    assert not (assets / "_sliced/Pixel Crawler - Cave").exists()
    shas = {p.name: sa.sha256(p) for p in out.iterdir()}
    assert run_cli(tmp_path) == 0
    assert (out / "SLICES.json").read_text() == first
    assert {p.name: sa.sha256(p) for p in out.iterdir()} == shas
    doc = json.loads(first)
    assert doc["assets"][0]["duplicate_sheets"] == [
        "potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png"]
    assert "sliced 1 sheets (1 duplicates skipped) -> 3 slices" in capsys.readouterr().out


def test_rerun_preserves_labels_and_removes_orphans(tmp_path):
    assets = tmp_path / "potential_assets"
    src = assets / "Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png"
    src.parent.mkdir(parents=True)
    packed_crates(src)
    assert run_cli(tmp_path) == 0
    sj = assets / "_sliced/Pixel Crawler - Free Pack/Furniture/SLICES.json"
    doc = json.loads(sj.read_text())
    doc["assets"][1].update({"label_kind": "crate", "label_confidence": 0.9, "targets": ["crate"],
                             "verdict": "READY", "notes": "hand-checked"})
    sj.write_text(json.dumps(doc))
    assert run_cli(tmp_path, "--split", "Furniture:0,0,16,23") == 0
    doc2 = json.loads(sj.read_text())
    crate = [r for r in doc2["assets"] if r["region"] == [16, 0, 16, 23]][0]
    assert (crate["label_kind"], crate["label_confidence"], crate["targets"], crate["verdict"], crate["notes"]) == \
        ("crate", 0.9, ["crate"], "READY", "hand-checked")
    assert [r["method"] for r in doc2["assets"]] == ["override", "seam", "seam"]
    assert run_cli(tmp_path, "--split", "Furniture:0,0,8,23") == 0
    names = sorted(p.name for p in sj.parent.glob("*.png"))
    assert "Furniture__x0_y0_w16_h23.png" not in names and "Furniture__x0_y0_w8_h23.png" in names


def test_stem_collision_gets_sha_suffix(tmp_path):
    # Two generic parents (Assets/, Props/) give the same stem with different content.
    assets = tmp_path / "potential_assets"
    a = assets / "Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Props.png"
    b = assets / "Pixel Crawler - Cave/Pixel Crawler - Cave/Props/Props.png"
    sprite_sheet(a, [(0, 0, 16, 16)])
    sprite_sheet(b, [(0, 0, 16, 16), (32, 0, 16, 16)])
    assert run_cli(tmp_path) == 0
    dirs = sorted(p.name for p in (assets / "_sliced/Pixel Crawler - Cave").iterdir())
    assert dirs == ["Props", "Props-" + sa.sha256(b)[:8]]
    assert run_cli(tmp_path) == 0
    assert sorted(p.name for p in (assets / "_sliced/Pixel Crawler - Cave").iterdir()) == dirs


def test_dry_run_writes_nothing(tmp_path, capsys):
    assets = tmp_path / "potential_assets"
    src = assets / "Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png"
    src.parent.mkdir(parents=True)
    packed_crates(src)
    assert run_cli(tmp_path, "--dry-run") == 0
    assert not (assets / "_sliced/Pixel Crawler - Free Pack").exists()
    assert "Furniture.png" in capsys.readouterr().out


def test_outputs_land_in_top_level_sliced_even_when_pack_is_read_only(tmp_path):
    import os
    assets = tmp_path / "potential_assets"
    pack = assets / "Pixel Crawler - Free Pack"
    src = pack / "Environment/Props/Static/Furniture.png"
    src.parent.mkdir(parents=True)
    packed_crates(src)
    snapshot = sorted(p.relative_to(pack).as_posix() for p in pack.rglob("*"))
    dirs = [pack, *[d for d in pack.rglob("*") if d.is_dir()]]
    for d in dirs:
        os.chmod(d, 0o555)
    try:
        assert run_cli(tmp_path) == 0
    finally:
        for d in dirs:
            os.chmod(d, 0o755)
    assert sorted(p.relative_to(pack).as_posix() for p in pack.rglob("*")) == snapshot
    assert not list(pack.rglob("_sliced"))
    out = assets / "_sliced/Pixel Crawler - Free Pack/Furniture"
    assert (out / "SLICES.json").is_file()
    row = json.loads((out / "SLICES.json").read_text())["assets"][0]
    assert row["path"].startswith("potential_assets/_sliced/Pixel Crawler - Free Pack/Furniture/Furniture__x")
