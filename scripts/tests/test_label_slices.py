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
    rows = json.loads((assets / "Pixel Crawler - Free Pack/_sliced/Furniture/SLICES.json").read_text())["assets"]
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
    rows = json.loads((assets / "Pixel Crawler - Free Pack/_sliced/Furniture/SLICES.json").read_text())["assets"]
    assert all(r["label_kind"] == "" for r in rows), "an invalid answer file writes nothing"
