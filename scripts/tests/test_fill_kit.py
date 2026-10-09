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
    assert re.search(r"^#2 +M +pack +UNREVIEWED +potential_assets/_sliced/Pixel Crawler - Free Pack 2.1/", out, re.M)
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


def test_top_level_sliced_layout_is_selectable(tree):
    assert SLICE.startswith("potential_assets/_sliced/") and (tree / SLICE).parent.name == "Furniture"
    assert (tree / SLICE).parent.joinpath("SLICES.json").is_file()
    assert run(tree, "invrisil", "cargo", "--need", "1", "--kind", "crate", "--select", "2",
               "--ids", "invrisil_slice_crate", "--fallback", "crate_owned") == 0
    cat = json.loads((tree / "wandering_inn_game/data/sprites.json").read_text())
    assert cat["invrisil_slice_crate"]["animations"]["idle"]["region"] == [16, 8, 16, 23]
    assert kits(tree)["invrisil"]["roles"]["cargo"]["pool"] == ["invrisil_slice_crate"]


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


def test_fallback_set_warning(tree, capsys):
    assert run(tree, "invrisil", "cargo", "--need", "1", "--kind", "crate", "--select", "2",
               "--fallback", "crate_owned") == 0
    assert "warning: public fallback set" in capsys.readouterr().out


def test_splice_helpers_are_byte_surgical():
    text = '{\n\t"a": {"x": 1},\n\t"b": {\n\t\t"r": {\n\t\t\t"pool": [\n\t\t\t\t"p"\n\t\t\t]\n\t\t}\n\t}\n}\n'
    out = fk.append_item(text, ["b", "r", "pool"], "q")
    assert json.loads(out)["b"]["r"]["pool"] == ["p", "q"] and out.startswith(text[:text.index('"p"') + 3])
    out = fk.add_key('{\n\t"a": {}\n}\n', [], "z", {"k": 1})
    assert json.loads(out) == {"a": {}, "z": {"k": 1}}
    assert json.loads(fk.add_key('{"a": {}}', ["a"], "k", 1)) == {"a": {"k": 1}}
    with pytest.raises(wa.Refused):
        fk.append_item(text, ["a"], 1)


def test_next_ids_skips_taken():
    assert fk.next_ids("r", "x", 2, {"r_x_2": {}}, ["r_x_1"]) == ["r_x_3", "r_x_4"]


def test_never_calls_pixellab():
    src = (HERE.parent.parent / "tools" / "fill_kit.py").read_text()
    assert not re.search(r"^\s*(import|from)\s+(requests|urllib|http|socket)\b", src, re.M)
    assert "mcp__pixellab" not in src and "pixellab.ai" not in src


_INLINE = ('{"_comment": "c", "_common": {"materials": {}, "roles": {}, "cast": []}, '
           '"invrisil": {"materials": {}, "roles": {"cargo": {"pick": "cell", "pool": ["a", ["b", 2]]}}, "cast": []}}\n')
_TABS = ('{\n\t"_comment": "c",\n\t"_common": {"materials": {}, "roles": {}, "cast": []},\n'
         '\t"invrisil": {\n\t\t"materials": {},\n\t\t"roles": {\n\t\t\t"cargo": {"pick": "cell", "pool": ["a", ["b", 2]]}\n\t\t},\n\t\t"cast": []\n\t}\n}\n')
_ONE = json.dumps(json.loads(_INLINE), indent=1) + "\n"
LAYOUTS = {"inline": _INLINE, "tabs": _TABS, "indent1": _ONE}


def _pure_insertion(before: str, after: str) -> bool:
    pre = 0
    while pre < min(len(before), len(after)) and before[pre] == after[pre]:
        pre += 1
    suf = 0
    while suf < min(len(before), len(after)) - pre and before[-1 - suf] == after[-1 - suf]:
        suf += 1
    return pre + suf >= len(before)


@pytest.mark.parametrize("layout", LAYOUTS)
def test_splice_survives_every_layout(layout):
    text = LAYOUTS[layout]
    base = json.loads(text)
    out = fk.kits_with_pool(text, "invrisil", "cargo", ["c"], "cell", False)
    want = json.loads(text)
    want["invrisil"]["roles"]["cargo"]["pool"].append("c")
    assert json.loads(out) == want and _pure_insertion(text, out)
    out = fk.kits_with_pool(text, "invrisil", "door", ["d1"], "door", True)
    want = json.loads(text)
    want["invrisil"]["roles"]["door"] = {"pick": "door", "module": True, "pool": ["d1"]}
    assert json.loads(out) == want and _pure_insertion(text, out)
    out = fk.kits_with_pool(text, "liscor", "cargo", ["l1"], "cell", False)
    want = json.loads(text)
    want["liscor"] = {"materials": {}, "roles": {"cargo": {"pick": "cell", "pool": ["l1"]}}, "cast": []}
    assert json.loads(out) == want and _pure_insertion(text, out)
    assert json.loads(out)["invrisil"] == base["invrisil"]
    if layout != "indent1":
        assert '["a", ["b", 2]' in out


def test_splice_failure_is_refused_not_a_traceback(monkeypatch):
    monkeypatch.setattr(fk, "_insert", lambda *a, **k: "{ not json")
    with pytest.raises(wa.Refused):
        fk.add_key(_INLINE, [], "z", 1)


def _fail_second_wire(monkeypatch):
    real, calls = wa.main, []

    def flaky(argv):
        calls.append(argv)
        return 4 if len(calls) == 2 else real(argv)
    monkeypatch.setattr(wa, "main", flaky)
    return real


def test_failed_selection_is_resumable_without_duplicates(tree, monkeypatch, capsys):
    real = _fail_second_wire(monkeypatch)
    args = ("invrisil", "cargo", "--need", "2", "--kind", "crate", "--select", "1,2", "--fallback", "crate_owned")
    assert run(tree, *args) == wa.EXIT_REFUSED
    out = capsys.readouterr().out
    assert "invrisil_cargo_1" in out and "python3 tools/fill_kit.py invrisil cargo" in out and "--select 1,2" in out
    assert "invrisil_cargo_1" not in kits(tree)["invrisil"]["roles"].get("cargo", {}).get("pool", [])
    monkeypatch.setattr(wa, "main", real)
    write_registry(tree)
    assert run(tree, *args) == 0
    cat = json.loads((tree / "wandering_inn_game/data/sprites.json").read_text())
    assert sorted(k for k in cat if k.startswith("invrisil_cargo")) == ["invrisil_cargo_1", "invrisil_cargo_2"]
    assert kits(tree)["invrisil"]["roles"]["cargo"]["pool"] == ["invrisil_cargo_1", "invrisil_cargo_2"]


def test_reuse_only_matches_this_roles_ids(tree):
    # the shipped `crate` entry shares the slice's sheet region but must never become a pool member
    assert run(tree, "invrisil", "cargo", "--need", "1", "--kind", "crate", "--select", "2",
               "--fallback", "crate_owned") == 0
    assert kits(tree)["invrisil"]["roles"]["cargo"]["pool"] == ["invrisil_cargo_1"]


def test_filled_pool_closes_the_open_row(tree):
    assert run(tree, "invrisil", "cargo", "--need", "2", "--kind", "crate", "--select", "1",
               "--lacked", "x") == 0
    assert "| open |" in (tree / GEN).read_text()
    write_registry(tree)
    assert run(tree, "invrisil", "cargo", "--need", "2", "--kind", "crate", "--select", "1",
               "--fallback", "crate_owned") == 0
    text = (tree / GEN).read_text()
    assert "| invrisil | cargo | invrisil_cargo_1, invrisil_cargo_2 | 2 | x | invrisil_cargo_1 | done invrisil_cargo_1, invrisil_cargo_2 |" in text
    assert "| open |" not in text


def test_shortfall_counts_the_whole_pool(tree):
    assert run(tree, "invrisil", "cargo", "--need", "2", "--kind", "crate", "--select", "1") == 0
    write_registry(tree)
    assert run(tree, "invrisil", "cargo", "--need", "2", "--kind", "crate", "--select", "1",
               "--fallback", "crate_owned") == 0
    assert "| open |" not in (tree / GEN).read_text()   # 1 new pick < need, but the pool of 2 is full


def test_generation_cells_are_sanitized():
    out = fk.generation_list_with("", "r", "x", ["a"], 2, "no | pipes\nor lines", "b|c")
    row = out.rstrip("\n").split("\n")[-1]
    assert row == "| r | x | a | 2 | no / pipes or lines | b/c | open |"


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


def test_preview_unresolved_ref_exits_nonzero_and_writes_nothing(tree, capsys):
    pytest.importorskip("wi_kits_lib")
    maps = tree / "wandering_inn_game/data/maps/invrisil"
    maps.mkdir(parents=True)
    m = {"biome": "inn", "grid": [8, 6], "decor": [{"sprite": "@nosuchrole", "cell": [1, 1]}]}
    (maps / "bad_map.json").write_text(json.dumps(m, indent=1) + "\n")
    before = snapshot(tree)
    assert run(tree, "invrisil", "nosuchrole", "--preview") == fk.EXIT_UNRESOLVED
    assert "unresolved:" in capsys.readouterr().err
    assert not changed(before, snapshot(tree))
