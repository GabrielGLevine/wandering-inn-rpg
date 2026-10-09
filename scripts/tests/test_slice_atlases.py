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


def tile_floor(path: Path, w: int, h: int, im: Image.Image | None = None, x0: int = 0, y0: int = 0) -> Image.Image:
    """Flush 16px floor tiles (fill + 1px dark joint), the way a tileset lays
    them: one opaque component whose boundary runs on cell edges."""
    if im is None:
        path.parent.mkdir(parents=True, exist_ok=True)
        im = Image.new("RGBA", (w, h), CLEAR)
    d = ImageDraw.Draw(im)
    for y in range(y0, y0 + h, 16):
        for x in range(x0, x0 + w, 16):
            d.rectangle((x, y, x + 15, y + 15), fill=(120, 110, 100, 255), outline=(40, 35, 30, 255))
    im.save(path)
    return im


def layout_of(path: Path) -> tuple[str, dict]:
    a = sa.analyze(path)
    return a.layout, a.metrics


def test_eligible_rules():
    # #624: names and environment folders no longer skip; content decides.
    ok = ["Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png",
          "Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Props.png",
          "Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png",
          "Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Tiles.png",
          "Pixel Crawler - Free Pack/Environment/Tilesets/Floors_Tiles.png",
          "Pixel Crawler - Free Pack/Environment/Props/Static/Shadows.png",
          "Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Light.png",
          "Pixel Crawler - Free Pack/Environment/Structures/Stations/Anvil/Anvil.png",
          "Pixel Crawler - Free Pack/Environment/Structures/Stations/Furnace/Bricks_01-Sheet.png",
          "Pixel Crawler - Free Pack/Environment/Props/Static/Bonfire_01-Sheet.png"]
    bad = {"Admurins_Freebies-2/x/Props.png": "",
           "Pixel Crawler - Cave/Pixel Crawler - Cave/Enemies/Fungus/Idle-Sheet.png": "",
           "Pixel Crawler - Cave/Pixel Crawler - Cave/Social/Props.png": "promo_render",
           "Pixel Crawler - Free Pack/MockUps/Tavern_01.png": "promo_render",
           "Pixel Crawler - Free Pack/Weapons/Wood/Wood.png": "weapon_sheet",
           "_sliced/Pixel Crawler - Free Pack/Furniture/Furniture__x0_y0_w16_h16.png": "",
           "Pixel Crawler - Cave/_sliced/Props/Props__x0_y0_w16_h16.png": ""}
    assert [sa.eligible(Path(p)) for p in ok] == [True] * len(ok)
    assert [sa.eligible(Path(p)) for p in bad] == [False] * len(bad)
    assert {p: sa.path_skip(Path(p)) for p in bad if sa.in_scope(Path(p))} == {
        p: r for p, r in bad.items() if sa.in_scope(Path(p))}


def test_only_frame_regular_entity_strips_are_animation():
    idle = Path("Pixel Crawler - Cave/Pixel Crawler - Cave/Enemies/Fungus/Idle-Sheet.png")
    walk = Path("Pixel Crawler - Free Pack/Entities/Characters/Body_A/Animations/Walk_Base/Walk_Down-Sheet.png")
    assert sa.animation_strip(idle, (128, 32)) and sa.animation_strip(walk, (64, 256))
    assert sa.animation_strip(idle, (576, 80)), "nine 64x80 frames"
    assert not sa.animation_strip(idle, (100, 36)), "not frame-regular: content decides"
    station = Path("Pixel Crawler - Free Pack/Environment/Structures/Stations/Furnace/Bricks_01-Sheet.png")
    assert not sa.animation_strip(station, (64, 96)), "station strips are environment art"
    assert not sa.animation_strip(Path("Pixel Crawler - Cave/Pixel Crawler - Cave/Enemies/Fungus/Idle.png"))


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
    sprite_sheet(assets / "Pixel Crawler - Cave/Pixel Crawler - Cave/Enemies/Fungus/Idle-Sheet.png",
                 [(0, 0, 16, 16)], size=(128, 32))
    tile_floor(assets / "Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Tiles.png", 128, 96)
    game_fixture(tmp_path, src)
    assert run_cli(tmp_path) == 0
    out = assets / "_sliced/Pixel Crawler - Free Pack/Furniture"
    first = (out / "SLICES.json").read_text()
    names = sorted(p.name for p in out.iterdir())
    assert names == ["Furniture__x0_y0_w16_h23.png", "Furniture__x16_y0_w16_h23.png",
                     "Furniture__x32_y1_w16_h22.png", "SLICES.json", "contact.png"]
    assert not (assets / "Pixel Crawler - Free Pack 2.1/_sliced/Pixel Crawler - Free Pack").exists()
    assert not list(assets.glob("*/**/_sliced"))
    cave = assets / "_sliced/Pixel Crawler - Cave"
    assert sorted(p.name for p in cave.iterdir()) == ["SKIPPED.json", "TILESETS.json"], \
        "a tileset is registered, not sliced; the strip is listed as skipped"
    skipped = json.loads((cave / "SKIPPED.json").read_text())["files"]
    assert [(r["path"].split("/")[-1], r["reason"]) for r in skipped] == [
        ("Tiles.png", "tileset"), ("Idle-Sheet.png", "animation_strip")]
    dupes = json.loads((assets / "_sliced/Pixel Crawler - Free Pack 2.1/SKIPPED.json").read_text())["files"]
    assert [(r["reason"], r["detail"]) for r in dupes] == [
        ("duplicate", "potential_assets/Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png")]
    lists = {p: (cave / p).read_text() for p in ("SKIPPED.json", "TILESETS.json")}
    shas = {p.name: sa.sha256(p) for p in out.iterdir()}
    assert run_cli(tmp_path) == 0
    assert (out / "SLICES.json").read_text() == first
    assert {p.name: sa.sha256(p) for p in out.iterdir()} == shas
    assert {p: (cave / p).read_text() for p in lists} == lists
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


# ---------------------------------------------------------------- #624 layouts

def test_dense_grid_is_a_tileset_and_census_counts_cells(tmp_path):
    src = tmp_path / "Tiles.png"
    tile_floor(src, 128, 96)
    layout, m = layout_of(src)
    assert layout == "tileset"
    assert (m["full_cells"], m["nonempty_cells"], m["islands"], m["blocks"]) == (48, 48, 1, 1)
    labels, boxes = sa.components(Image.open(src).tobytes()[3::4], 128, 96)
    assert sa.edge_alignment(labels, 1, 128, 96, boxes[0]) == 1.0


def test_organic_canopy_is_props_even_with_many_full_cells(tmp_path):
    # A round canopy: dozens of fully opaque cells, but its outline crosses
    # cells anywhere (~0.25 on cell edges), so it is never a tile block.
    src = tmp_path / "Tree.png"
    im = Image.new("RGBA", (192, 192), CLEAR)
    ImageDraw.Draw(im).ellipse((2, 3, 189, 186), fill=(40, 120, 50, 255), outline=BLACK)
    im.save(src)
    layout, m = layout_of(src)
    assert m["full_cells"] >= sa.BLOCK_CELLS and m["full_share"] >= sa.SHEET_FULL
    assert m["max_align"] < sa.BLOCK_ALIGN and layout == "props"


def test_aligned_rug_on_a_sparse_prop_sheet_stays_props(tmp_path):
    # Interior_Props_01: a grid-aligned 45-cell piece among 100+ props. Its
    # sheet has 17% full cells, so SHEET_FULL keeps the whole atlas props.
    src = tmp_path / "Interior_Props_01.png"
    im = Image.new("RGBA", (320, 320), CLEAR)
    tile_floor(src, 96, 96, im)
    for i in range(40):
        x, y = 112 + (i % 10) * 20, (i // 10) * 20 + 4
        outlined_box(im, x, y, 12, 12)
        outlined_box(im, (i % 10) * 20 + 4, 120 + (i // 10) * 40, 12, 30)
    im.save(src)
    layout, m = layout_of(src)
    assert m["full_cells"] == 36 and m["full_share"] < sa.SHEET_FULL and layout == "props"


def test_mixed_sheet_slices_islands_and_records_tile_part(tmp_path):
    assets = tmp_path / "potential_assets"
    src = assets / "Pixel Crawler - Forge 1.2/Pixel Crawler - Forge/Assets/Tiles.png"
    src.parent.mkdir(parents=True)
    im = Image.new("RGBA", (192, 96), CLEAR)
    tile_floor(src, 128, 96, im, x0=8)    # floor x 8..135: 42 full cells
    outlined_box(im, 137, 3, 10, 10)      # its 16px cell holds floor pixels
    outlined_box(im, 164, 40, 20, 30)     # clear of the floor: grid-expanded
    outlined_box(im, 140, 80, 8, 8)
    im.save(src)
    doc, crops = sa.slice_sheet(src, assets, sa.out_dir_for(src, assets, "x"), [], {}, {}, [])
    assert doc["layout"] == "mixed" and doc["tile_regions"] == [[8, 0, 128, 96]]
    assert [(r["region"], r["method"]) for r in doc["assets"]] == [
        ([137, 3, 10, 10], "component"), ([160, 32, 32, 48], "grid16"), ([140, 80, 8, 8], "component")]
    assert list(doc) == ["schema", "source", "tier", "family", "sheet", "sheet_sha256", "grid",
                         "layout", "tile_regions", "overrides", "check_notes", "assets"]
    a = sa.analyze(src)
    assert sa._holds_block(a.labels, a.blocks, 192, [128, 0, 144, 16])
    assert not sa._holds_block(a.labels, a.blocks, 192, [160, 32, 192, 80])


def test_props_doc_keys_are_unchanged(tmp_path):
    src = tmp_path / "Pixel Crawler - Free Pack/Environment/Props/Static/Meat.png"
    sprite_sheet(src, [(3, 3, 10, 10), (19, 3, 10, 10)], size=(64, 32))
    doc, _ = sa.slice_sheet(src, tmp_path, sa.out_dir_for(src, tmp_path, "x"), [], {}, {}, [])
    assert list(doc) == ["schema", "source", "tier", "family", "sheet", "sheet_sha256", "grid",
                         "overrides", "check_notes", "assets"]


def test_translucent_and_empty_sheets_are_skipped(tmp_path):
    shadow = Image.new("RGBA", (64, 32), CLEAR)
    ImageDraw.Draw(shadow).ellipse((4, 4, 40, 20), fill=(0, 0, 0, 80))
    assert sa.opaque_skip(shadow) == "translucent_overlay"
    assert sa.opaque_skip(Image.new("RGBA", (16, 16), CLEAR)) == "empty"
    lamp = shadow.copy()
    outlined_box(lamp, 44, 4, 12, 20)
    assert sa.opaque_skip(lamp) == "", "a light sheet with a lamp is sliced"
    flat = Image.new("RGBA", (64, 32), CLEAR)
    ImageDraw.Draw(flat).ellipse((4, 4, 40, 20), fill=(57, 88, 100, 255))
    assert sa.opaque_skip(flat) == "flat_overlay", "Fairy Forest Shadown.png: one opaque colour"


def test_cli_writes_tilesets_skipped_and_merges_only_runs(tmp_path):
    assets = tmp_path / "potential_assets"
    pack = assets / "Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout"
    tile_floor(pack / "Assets/Tiles.png", 128, 64)
    light = Image.new("RGBA", (64, 32), CLEAR)
    ImageDraw.Draw(light).ellipse((0, 0, 40, 30), fill=(255, 200, 80, 60))
    outlined_box(light, 44, 4, 12, 20)
    light.save(pack / "Assets/Light.png")
    shadow = Image.new("RGBA", (32, 32), CLEAR)
    ImageDraw.Draw(shadow).rectangle((2, 2, 20, 20), fill=(0, 0, 0, 90))
    shadow.save(pack / "Assets/Shadows.png")
    sprite_sheet(pack / "Weapons/Rustic.png", [(0, 0, 16, 16)])
    assert run_cli(tmp_path) == 0
    base = assets / "_sliced/Pixel Crawler - Hideout 1.0"
    tiles = json.loads((base / "TILESETS.json").read_text())
    assert [(t["sheet"].split("/")[-1], t["layout"], t["evidence"], t["tile_regions"]) for t in tiles["sheets"]] == [
        ("Tiles.png", "tileset", ["content", "directory"], [[0, 0, 128, 64]])]
    skipped = {r["path"].split("/")[-1]: r["reason"] for r in json.loads((base / "SKIPPED.json").read_text())["files"]}
    assert skipped == {"Tiles.png": "tileset", "Shadows.png": "translucent_overlay", "Rustic.png": "weapon_sheet"}
    assert (base / "Light/SLICES.json").is_file(), "Light.png holds a lamp: sliced"
    assert all(json.loads((base / "SKIPPED.json").read_text())["files"][i]["why"] for i in range(3))
    # an --only run replaces its own rows and keeps the rest
    assert run_cli(tmp_path, "--only", "Shadows") == 0
    again = {r["path"].split("/")[-1] for r in json.loads((base / "SKIPPED.json").read_text())["files"]}
    assert again == {"Tiles.png", "Shadows.png", "Rustic.png"}
    assert json.loads((base / "TILESETS.json").read_text()) == tiles


def test_measure_writes_nothing(tmp_path, capsys):
    assets = tmp_path / "potential_assets"
    tile_floor(assets / "Pixel Crawler - Cave/Assets/Tiles.png", 128, 64)
    assert run_cli(tmp_path, "--measure") == 0
    assert not (assets / "_sliced").exists()
    assert "tileset" in capsys.readouterr().out


GOLDEN = REPO_ROOT / "scripts/tests/fixtures/slices_golden_cemetery.json"
LIVE_ASSETS = REPO_ROOT / "potential_assets"


def test_golden_cemetery_slices_and_layouts_are_stable():
    """The 61 Cemetery 0.4 slices fed docs/kits-allocation.md before #624;
    content classification must keep their ids and regions, and pin the
    layout of every other Cemetery sheet. Local only: CI has no packs."""
    golden = json.loads(GOLDEN.read_text())
    if not (LIVE_ASSETS / golden["pack"]).is_dir():
        pytest.skip("potential_assets/ absent (CI)")
    got_layouts = {}
    for rel, want in golden["sheets"].items():
        src = LIVE_ASSETS / rel
        a = sa.analyze(src)
        skip = sa.opaque_skip(a.im)
        got_layouts[rel] = skip or a.layout
        if "tile_regions" in want:
            assert sa.tile_regions(a) == want["tile_regions"], rel
        if "slices" in want:
            out_dir = LIVE_ASSETS / "_sliced" / golden["pack"] / sa.sheet_stem(src)
            doc, _ = sa.slice_sheet(src, LIVE_ASSETS, out_dir, [], {}, {}, [], a)
            assert [[Path(r["path"]).name, r["region"], r["method"]] for r in doc["assets"]] == want["slices"], rel
    assert got_layouts == {rel: w["layout"] for rel, w in golden["sheets"].items()}
