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


def _px(im):
    return list(im.get_flattened_data()) if hasattr(im, "get_flattened_data") else list(im.getdata())


def test_contact_sheet_renders_numbered_cells_and_swatches(tree, tmp_path):
    out = tmp_path / "cargo.png"
    assert run(tree, "invrisil", "cargo", "--need", "4", "--kind", "crate", "--contact-sheet", str(out)) == 0
    bg = (40, 40, 44, 255)
    with Image.open(out) as img:
        assert img.size == (8 * fk.CELL, fk.SWATCH_H + (fk.CELL + 28))
        tile = img.crop((4, 4, 36, 36))
        assert any(px != bg and px[3] == 255 for px in _px(tile))   # floor_street tile from Furniture.png
        y0 = fk.SWATCH_H
        cell1 = img.crop((0, y0, fk.CELL, y0 + fk.CELL))
        assert any(px != bg and px[3] == 255 for px in _px(cell1))   # the 2x render of #1
        label = img.crop((fk.CELL - 20, y0 + fk.CELL + 2, fk.CELL - 8, y0 + fk.CELL + 14))
        assert any(px != bg for px in _px(label))                   # the number "1"
        empty = img.crop((2 * fk.CELL, y0, 3 * fk.CELL, y0 + fk.CELL))
        assert all(px == bg for px in _px(empty))                   # only two candidates: cell 3 stays empty


def test_missing_material_sheet_is_outlined_not_fatal(tree, tmp_path):
    k = tree / KITS
    d = json.loads(k.read_text())
    d["invrisil"]["materials"]["wall_shop"] = {"sheet": "res://assets/tiles/absent.png", "tile_px": 16, "face": [0, 1]}
    k.write_text(json.dumps(d, indent=1) + "\n")
    out = tmp_path / "cargo.png"
    assert run(tree, "invrisil", "cargo", "--need", "4", "--kind", "crate", "--contact-sheet", str(out)) == 0
    with Image.open(out) as img:
        assert img.getpixel((76, 4)) == (200, 80, 80, 255)


def _cand(tmp_path, n, w, h, color=(10, 200, 30, 255)):
    p = tmp_path / f"c{n}.png"
    Image.new("RGBA", (w, h), color).save(p)
    return fk.Candidate(n, {"path": p.name}, p, "pack", "x", 0.4, w, h, fk.size_class(h), None, None)


def test_one_x_render_is_exact_scale_for_tall_candidates(tmp_path):
    out = tmp_path / "s.png"
    fk.render_contact_sheet([_cand(tmp_path, 1, 16, 40)], [], out)
    with Image.open(out) as img:
        strip_y = fk.SWATCH_H + max(fk.CELL, 80)   # 2x area (80 tall) ends here; 1x strip below
        rows = {y for y in range(strip_y, img.height)
                for x in range(img.width) if img.getpixel((x, y)) == (10, 200, 30, 255)}
        assert len(rows) == 40


def test_reduced_two_x_prints_its_real_scale(tmp_path):
    out = tmp_path / "s.png"
    fk.render_contact_sheet([_cand(tmp_path, 1, 16, 100)], [], out)   # 2x = 200 tall, over the cap
    with Image.open(out) as img:
        # label "<f>x" sits top-left of the cell; absent when 2x is exact
        corner = img.crop((2, fk.SWATCH_H + 2, 40, fk.SWATCH_H + 14))
        assert any(px not in ((40, 40, 44, 255), (10, 200, 30, 255)) for px in _px(corner))


def test_swatches_wrap_instead_of_clipping(tree, tmp_path):
    k = tree / KITS
    d = json.loads(k.read_text())
    mat = next(iter(d["invrisil"]["materials"].values()))
    d["invrisil"]["materials"] = {f"m{i}": dict(mat) for i in range(10)}
    k.write_text(json.dumps(d, indent=1) + "\n")
    out = tmp_path / "cargo.png"
    assert run(tree, "invrisil", "cargo", "--need", "4", "--kind", "crate", "--contact-sheet", str(out)) == 0
    n = len(fk.material_swatches(json.loads(k.read_text()), "invrisil", wa.Paths(tree)))
    bg = (40, 40, 44, 255)
    assert n >= 10
    with Image.open(out) as img:
        for i in range(n):
            x, y = 4 + (i % 8) * fk.CELL, 4 + (i // 8) * fk.SWATCH_H
            assert any(px != bg for px in _px(img.crop((x, y, x + 32, y + 32)))), i


def test_number_labels_differ_between_cells(tmp_path):
    out = tmp_path / "s.png"
    fk.render_contact_sheet([_cand(tmp_path, 1, 16, 16), _cand(tmp_path, 2, 16, 16)], [], out)
    with Image.open(out) as img:
        y = fk.SWATCH_H + fk.CELL + 2
        a = img.crop((fk.CELL - 20, y, fk.CELL - 8, y + 12))
        b = img.crop((2 * fk.CELL - 20, y, 2 * fk.CELL - 8, y + 12))
        assert _px(a) != _px(b)
