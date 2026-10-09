#!/usr/bin/env python3
"""tools/label_slices.py: export/import/check on synthetic slices.
Run: python3 -m pytest -q scripts/tests/test_label_slices.py"""
import json
import sys
from pathlib import Path

import pytest

pytest.importorskip("PIL")
from PIL import Image, ImageDraw  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO_ROOT / "tools"))
import label_slices as ls  # noqa: E402
import slice_atlases as sa  # noqa: E402

CLEAR = (0, 0, 0, 0)


def sheet_with_boxes(path: Path, n: int, size=None) -> Path:
    """n outlined 10x10 sprites on a 16px grid, left to right then down."""
    cols = 8
    size = size or (cols * 16, -(-n // cols) * 16)
    im = Image.new("RGBA", size, CLEAR)
    d = ImageDraw.Draw(im)
    for i in range(n):
        x, y = (i % cols) * 16 + 3, (i // cols) * 16 + 3
        d.rectangle((x, y, x + 9, y + 9), fill=(140, 90, 40, 255), outline=(0, 0, 0, 255))
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)
    return path


def sliced_fixture(tmp_path, n=45, wired=None):
    assets = tmp_path / "potential_assets"
    game = tmp_path / "wandering_inn_game"
    src = sheet_with_boxes(assets / "Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png", n)
    dst = game / "assets/props/free_pack/Furniture.png"
    dst.parent.mkdir(parents=True)
    dst.write_bytes(src.read_bytes())
    (game / "data").mkdir()
    sprites = {"_comment": "x"}
    for sid, (sheet, region) in (wired or {}).items():
        sprites[sid] = {"animations": {"idle": {"sheet": sheet, "region": region}}}
    (game / "data/sprites.json").write_text(json.dumps(sprites))
    assert sa.main(["--assets-root", str(assets), "--game-root", str(game)]) == 0
    return assets, game


def test_export_pages_numbered_and_capped_at_40(tmp_path):
    assets, _ = sliced_fixture(tmp_path, n=45)
    task = ls.export(assets)
    pages = task["pages"]
    assert [p["page"] for p in pages] == ["Pixel Crawler - Free Pack/Furniture/p01", "Pixel Crawler - Free Pack/Furniture/p02"]
    assert list(pages[0]["numbers"]) == [str(i) for i in range(1, 41)]
    assert list(pages[1]["numbers"]) == [str(i) for i in range(41, 46)]
    assert pages[0]["numbers"]["1"]["size_class"] == "S" and pages[0]["numbers"]["1"]["region"] == [0, 0, 16, 16]
    for p in pages:
        for key in ("png_2x", "png_1x", "slices_json"):
            assert (tmp_path / p[key]).exists(), key
    two = Image.open(tmp_path / pages[0]["png_2x"])
    one = Image.open(tmp_path / pages[0]["png_1x"])
    assert two.size[0] > one.size[0]
    assert json.loads((assets / "_sliced_task.json").read_text()) == task
    assert "{page}" not in ls.PROMPT_TEMPLATE.format(page="x", png_2x="a", png_1x="b", numbers="1-40")
    for kind in sa.KINDS:
        assert kind in ls.PROMPT_TEMPLATE


def write_answer(answers: Path, page: str, labels: dict) -> None:
    answers.mkdir(exist_ok=True)
    (answers / (page.replace("/", "__") + ".json")).write_text(json.dumps({"page": page, "labels": labels}))


def test_import_merges_labels_into_slices_json(tmp_path):
    assets, _ = sliced_fixture(tmp_path, n=3, wired={"crate": ("res://assets/props/free_pack/Furniture.png", [16, 0, 16, 16])})
    ls.export(assets)
    answers = tmp_path / "answers"
    write_answer(answers, "Pixel Crawler - Free Pack/Furniture/p01",
                 {"1": {"kind": "barrel", "confidence": 0.8}, "2": {"kind": "crate", "confidence": 0.95}})
    assert ls.import_labels(assets, answers) == 0
    rows = json.loads((assets / "_sliced/Pixel Crawler - Free Pack/Furniture/SLICES.json").read_text())["assets"]
    assert (rows[0]["label_kind"], rows[0]["label_confidence"], rows[0]["targets"]) == ("barrel", 0.8, ["barrel"])
    assert (rows[1]["label_kind"], rows[1]["targets"]) == ("crate", ["crate"]), "kind first, wired id kept"
    assert rows[1]["size_class"] == "S", "measured size class is never overwritten"
    assert (rows[2]["label_kind"], rows[2]["label_confidence"]) == ("", 0.0), "unanswered stays unlabeled"


def test_import_rejects_bad_kind_and_bad_number(tmp_path, capsys):
    assets, _ = sliced_fixture(tmp_path, n=3)
    ls.export(assets)
    answers = tmp_path / "answers"
    write_answer(answers, "Pixel Crawler - Free Pack/Furniture/p01",
                 {"1": {"kind": "chest", "confidence": 0.8}, "9": {"kind": "crate", "confidence": 1.0},
                  "2": {"kind": "crate", "confidence": 1.5}})
    assert ls.import_labels(assets, answers) == 2
    out = capsys.readouterr().out
    assert "unknown kind 'chest'" in out and "number 9" in out and "confidence 1.5" in out
    rows = json.loads((assets / "_sliced/Pixel Crawler - Free Pack/Furniture/SLICES.json").read_text())["assets"]
    assert all(r["label_kind"] == "" for r in rows), "an invalid answer file writes nothing"


SHEET = "res://assets/props/free_pack/Furniture.png"


def labeled_fixture(tmp_path, labels: dict, wired: dict):
    assets, game = sliced_fixture(tmp_path, n=3, wired=wired)
    ls.export(assets)
    answers = tmp_path / "answers"
    write_answer(answers, "Pixel Crawler - Free Pack/Furniture/p01", labels)
    assert ls.import_labels(assets, answers) == 0
    return assets, game


def test_check_passes_at_full_agreement_and_strips_old_notes(tmp_path, capsys):
    assets, game = labeled_fixture(
        tmp_path, {"1": {"kind": "crate", "confidence": 0.9}, "2": {"kind": "barrel", "confidence": 0.9}},
        {"crate": (SHEET, [0, 0, 16, 16]), "barrel": (SHEET, [19, 3, 10, 10])})
    sj = assets / "_sliced/Pixel Crawler - Free Pack/Furniture/SLICES.json"
    doc = json.loads(sj.read_text())
    doc["assets"][0]["notes"] = "keep me check-miss: stale"
    sj.write_text(json.dumps(doc))
    assert ls.check(assets, game) == 0
    out = capsys.readouterr().out
    assert "agreement 2/2 = 100.0%" in out
    assert json.loads(sj.read_text())["assets"][0]["notes"] == "keep me"


def test_check_fails_under_threshold_and_writes_misses(tmp_path, capsys):
    assets, game = labeled_fixture(
        tmp_path, {"1": {"kind": "crate", "confidence": 0.9}, "2": {"kind": "plant", "confidence": 0.5}},
        {"crate": (SHEET, [0, 0, 16, 16]), "barrel": (SHEET, [16, 0, 16, 16]),
         "ghost": (SHEET, [100, 100, 8, 8])})
    ls.WIRED_KINDS["ghost"] = "other"
    try:
        assert ls.check(assets, game) == 1
    finally:
        del ls.WIRED_KINDS["ghost"]
    out = capsys.readouterr().out
    assert "agreement 1/3 = 33.3%" in out
    assert "barrel -> plant" in out and "ghost" in out
    doc = json.loads((assets / "_sliced/Pixel Crawler - Free Pack/Furniture/SLICES.json").read_text())
    assert doc["assets"][1]["notes"] == "check-miss: wired barrel expects barrel, got plant"
    assert doc["check_notes"] == ["check-miss: wired ghost expects other, got no overlapping slice"]
    assert doc["assets"][0]["notes"] == ""


def test_check_excludes_unsliced_sheets(tmp_path, capsys):
    assets, game = labeled_fixture(
        tmp_path, {"1": {"kind": "crate", "confidence": 0.9}},
        {"crate": (SHEET, [0, 0, 16, 16]),
         "library_desk": ("res://assets/tiles/library/Tiles.png", [160, 272, 48, 32]),
         "sconce": ("res://assets/props/free_pack/Bonfire_01-Sheet.png", [0, 0, 128, 32])})
    assert ls.check(assets, game) == 0
    out = capsys.readouterr().out
    assert "agreement 1/1 = 100.0%" in out
    assert "excluded 2 wired regions on unsliced sheets" in out and "library_desk" in out


def test_check_skips_ids_outside_wired_kinds(tmp_path, capsys):
    assets, game = labeled_fixture(tmp_path, {"1": {"kind": "crate", "confidence": 0.9}},
                                   {"crate": (SHEET, [0, 0, 16, 16]), "brand_new_id": (SHEET, [16, 0, 16, 16])})
    assert ls.check(assets, game) == 0
    assert "SKIP brand_new_id: not in WIRED_KINDS" in capsys.readouterr().out


def test_best_slice_prefers_exact_size_over_spanning_piece():
    rows = [{"region": [98, 466, 44, 62], "label_kind": "table"},
            {"region": [112, 514, 16, 14], "label_kind": "seat"},
            {"region": [736, 73, 32, 23], "label_kind": "crate"}]
    best, ratio = ls.best_slice(rows, [112, 514, 16, 14])
    assert (best["label_kind"], ratio) == ("seat", 1.0)
    best, ratio = ls.best_slice(rows, [752, 74, 16, 22])
    assert (best["label_kind"], ratio) == ("crate", 1.0), "a wired sub-region of a fused slice still matches"
    assert ls.best_slice([], [0, 0, 1, 1]) == (None, 0.0)


def test_main_dispatch(tmp_path):
    assets, game = sliced_fixture(tmp_path, n=2)
    assert ls.main(["export", "--assets-root", str(assets)]) == 0
    assert ls.main(["check", "--assets-root", str(assets), "--game-root", str(game)]) == 0, "no wired regions: vacuous pass"
