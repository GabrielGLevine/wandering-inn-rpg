#!/usr/bin/env python3
"""tools/label_tilesets.py + the tileset rows of tools/asset_candidates.py and
the material match of tools/find_asset.py, on a synthetic tree (#624).
Run: python3 -m pytest -q scripts/tests/test_label_tilesets.py"""
import json
import sys
from pathlib import Path

import pytest

pytest.importorskip("PIL")
from PIL import Image, ImageDraw  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO_ROOT / "tools"))
import asset_candidates as ac  # noqa: E402
import find_asset as fa  # noqa: E402
import label_tilesets as lt  # noqa: E402
import slice_atlases as sa  # noqa: E402

CLEAR = (0, 0, 0, 0)


def floor(path: Path, w: int, h: int, props: bool = False) -> Path:
    """Flush 16px tiles; with props, two loose sprites to the right (mixed)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    im = Image.new("RGBA", (w + (48 if props else 0), h), CLEAR)
    d = ImageDraw.Draw(im)
    for y in range(0, h, 16):
        for x in range(0, w, 16):
            d.rectangle((x, y, x + 15, y + 15), fill=(150, 70, 50, 255), outline=(40, 20, 10, 255))
    if props:
        d.rectangle((w + 4, 4, w + 14, 20), fill=(90, 90, 90, 255), outline=(0, 0, 0, 255))
        d.rectangle((w + 24, 30, w + 40, 44), fill=(90, 90, 90, 255), outline=(0, 0, 0, 255))
    im.save(path)
    return path


def tree(tmp_path: Path) -> tuple[Path, Path]:
    """Two sliced Pixel Crawler tilesets, a non-PC pack with tileset folders
    (one byte-identical twin, one AppleDouble file) and an owned tileset."""
    root = tmp_path
    assets = root / "potential_assets"
    floor(assets / "Pixel Crawler - Forge 1.2/Pixel Crawler - Forge/Assets/Tiles.png", 128, 96, props=True)
    floor(assets / "Pixel Crawler - Sewer/Pixel Crawler - Sewer/Assets/Water.png", 96, 128)
    ninja = assets / "Ninja Adventure - Asset Pack/Backgrounds/Tilesets"
    floor(ninja / "TilesetFloor.png", 64, 32)
    (ninja / "TilesetFloorCopy.png").write_bytes((ninja / "TilesetFloor.png").read_bytes())
    floor(assets / "Ninja Adventure - Asset Pack/Items/Food/Fish.png", 16, 16)
    macos = assets / "Tiny Swords (Free Pack)/__MACOSX/Terrain/Tileset"
    macos.mkdir(parents=True)
    (macos / "._Tilemap_color1.png").write_bytes(b"\x00\x05\x16\x07")
    floor(assets / "pixellab_x/tiles/brick_over_dirt.png", 64, 64)
    (assets / "pixellab_x/MANIFEST.json").write_text(json.dumps({"schema": 1, "assets": [
        {"path": "tiles/brick_over_dirt.png", "kind": "tileset", "verdict": "READY"}]}))
    assert sa.main(["--assets-root", str(assets), "--game-root", str(root / "wandering_inn_game")]) == 0
    return root, assets


def registry(root: Path, assets: Path) -> Path:
    reg = ac.build(assets, root)
    path = root / "docs/asset-candidates.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(ac.dump_registry(reg))
    return path


def tiles_of(reg_path: Path) -> dict[str, dict]:
    rows = json.loads(reg_path.read_text())["assets"]
    return {r["path"].split("potential_assets/")[1]: r for r in rows if r["kind"] == "tileset"}


def test_registry_holds_every_tileset_with_empty_material_labels(tmp_path):
    root, assets = tree(tmp_path)
    tiles = tiles_of(registry(root, assets))
    assert sorted(tiles) == [
        "Ninja Adventure - Asset Pack/Backgrounds/Tilesets/TilesetFloor.png",
        "Pixel Crawler - Forge 1.2/Pixel Crawler - Forge/Assets/Tiles.png",
        "Pixel Crawler - Sewer/Pixel Crawler - Sewer/Assets/Water.png",
        "pixellab_x/tiles/brick_over_dirt.png"]
    forge = tiles["Pixel Crawler - Forge 1.2/Pixel Crawler - Forge/Assets/Tiles.png"]
    assert (forge["layout"], forge["evidence"], forge["tile_regions"]) == ("mixed", ["content", "directory"], [[0, 0, 128, 96]])
    assert (forge["tier"], forge["family"], forge["batch"], forge["w"]) == ("pack-bundle", "PC16", "_sliced/Pixel Crawler - Forge 1.2", 176)
    water = tiles["Pixel Crawler - Sewer/Pixel Crawler - Sewer/Assets/Water.png"]
    assert (water["layout"], water["evidence"]) == ("tileset", ["content"]), "content alone registers it"
    ninja = tiles["Ninja Adventure - Asset Pack/Backgrounds/Tilesets/TilesetFloor.png"]
    assert (ninja["layout"], ninja["evidence"], ninja["family"]) == ("unsliced", ["directory"], "NINJA16")
    assert ninja["duplicate_sheets"] == ["potential_assets/Ninja Adventure - Asset Pack/Backgrounds/Tilesets/TilesetFloorCopy.png"]
    assert all(t["material_labels"] == [] for t in tiles.values())
    assert any(r["batch"] == "_sliced/Pixel Crawler - Forge 1.2/Tiles" and r["kind"] == "prop"
               for r in json.loads((root / "docs/asset-candidates.json").read_text())["assets"]), \
        "the mixed sheet's islands are slices"


def test_tileset_evidence_is_whole_words():
    yes = ["P/Environment/Tilesets/Wall_Variations.png", "P/Environment/TileSets/Floor.png",
           "P/Assets/Tiles.png", "P/Environment/Tilesets/Floors_Tiles.png", "topdown_floor_tiles_12/dirt/dirt_01.png",
           "Pixel_16_interiors_v2_free/x/tiles and items.png", "Admurin/Tileset Scroller - Summer/a.png"]
    no = ["P/Assets/Props.png", "P/Stiles/a.png", "P/Assets/Tilesetter.png", "P/Assets/Ground.png",
          "Admurin/Tileset Scroller - Summer/Preview 0.png", "Admurin/Tileset Scroller - Summer/Summer Map.png",
          "Admurin/Tileset Scroller - Summer/Thumbnail.png"]
    assert [ac.tileset_evidence(Path(p)) for p in yes] == [True] * len(yes)
    assert [ac.tileset_evidence(Path(p)) for p in no] == [False] * len(no)


def test_export_pages_and_prompt(tmp_path):
    root, assets = tree(tmp_path)
    reg = registry(root, assets)
    out = tmp_path / "pages"
    task = lt.export(reg, assets, out)
    pages = {p["page"].split("/")[-1]: p for p in task["pages"]}
    assert sorted(pages) == ["Tiles.png", "TilesetFloor.png", "Water.png", "brick_over_dirt.png"]
    forge = pages["Tiles.png"]
    assert forge["scale"] == 2 and forge["tile_regions"] == [[0, 0, 128, 96]]
    assert Image.open(forge["png"]).size == (352, 192)
    assert "Yellow boxes outline the tile part" in forge["prompt"]
    assert "Yellow" not in pages["Water.png"]["prompt"]
    assert " ".join(lt.MATERIALS) in forge["prompt"] and f'"page": "{forge["page"]}"' in forge["prompt"]
    assert json.loads((out / lt.TASK_NAME).read_text())["materials"] == list(lt.MATERIALS)


def test_large_sheets_export_at_1x(tmp_path):
    big = Image.new("RGBA", (1100, 40), (100, 100, 100, 255))
    assert lt.render_page(big, [], 1).size == (1100, 40)
    assert 1100 * 2 > lt.MAX_PAGE_PX


def test_import_merges_labels_into_registry_and_find_asset(tmp_path):
    root, assets = tree(tmp_path)
    reg = registry(root, assets)
    out = tmp_path / "pages"
    lt.export(reg, assets, out)
    answers = tmp_path / "answers"
    answers.mkdir()
    forge = "potential_assets/Pixel Crawler - Forge 1.2/Pixel Crawler - Forge/Assets/Tiles.png"
    owned = "potential_assets/pixellab_x/tiles/brick_over_dirt.png"
    (answers / "a.json").write_text(json.dumps({"page": forge, "materials": {"stone": 0.6, "brick": 0.9}}))
    (answers / "b.json").write_text(json.dumps({"page": owned, "materials": {"brick": 0.8, "dirt": 0.7}}))
    assert lt.import_labels(assets, answers, out / lt.TASK_NAME) == 0
    labels = json.loads((assets / "_sliced" / ac.LABELS_NAME).read_text())["labels"]
    assert labels[forge]["material_labels"] == ["brick", "stone"], "most confident first"
    tiles = tiles_of(registry(root, assets))
    assert tiles["Pixel Crawler - Forge 1.2/Pixel Crawler - Forge/Assets/Tiles.png"]["material_labels"] == ["brick", "stone"]
    assert tiles["pixellab_x/tiles/brick_over_dirt.png"]["material_labels"] == ["brick", "dirt"]
    rows = json.loads((root / "docs/asset-candidates.json").read_text())["assets"]
    hits = [r["path"] for _, r in fa.search(rows, ["brick"], kind="tileset")]
    assert hits[:1] == [owned] and forge in hits, "a material word matches like a target word"
    assert [r["path"] for _, r in fa.search(rows, ["stone"], kind="tileset")] == [forge]
    # a later import for one sheet keeps the other sheets' labels
    (answers / "a.json").unlink()
    (answers / "b.json").write_text(json.dumps({"page": owned, "materials": {"cobble": 0.5}}))
    assert lt.import_labels(assets, answers, out / lt.TASK_NAME) == 0
    labels = json.loads((assets / "_sliced" / ac.LABELS_NAME).read_text())["labels"]
    assert labels[forge]["material_labels"] == ["brick", "stone"] and labels[owned]["material_labels"] == ["cobble"]


def test_import_refuses_unknown_material_and_bad_confidence(tmp_path, capsys):
    root, assets = tree(tmp_path)
    out = tmp_path / "pages"
    lt.export(registry(root, assets), assets, out)
    answers = tmp_path / "answers"
    answers.mkdir()
    forge = "potential_assets/Pixel Crawler - Forge 1.2/Pixel Crawler - Forge/Assets/Tiles.png"
    (answers / "a.json").write_text(json.dumps({"page": forge, "materials": {"granite": 0.9}}))
    (answers / "b.json").write_text(json.dumps({"page": forge, "materials": {"stone": 1.5}}))
    (answers / "c.json").write_text(json.dumps({"page": "nope", "materials": {"stone": 0.5}}))
    assert lt.import_labels(assets, answers, out / lt.TASK_NAME) == 2
    text = capsys.readouterr().out
    assert "unknown material 'granite'" in text and "not in 0..1" in text and "unknown page 'nope'" in text
    assert not (assets / "_sliced" / ac.LABELS_NAME).exists()


def test_stale_labels_are_not_applied(tmp_path):
    root, assets = tree(tmp_path)
    forge = "potential_assets/Pixel Crawler - Forge 1.2/Pixel Crawler - Forge/Assets/Tiles.png"
    (assets / "_sliced" / ac.LABELS_NAME).write_text(json.dumps({"labels": {
        forge: {"material_labels": ["brick"], "sheet_sha256": "0" * 64}}}))
    tiles = tiles_of(registry(root, assets))
    assert tiles["Pixel Crawler - Forge 1.2/Pixel Crawler - Forge/Assets/Tiles.png"]["material_labels"] == []


def test_find_asset_prefers_registered_tileset_over_index_row(tmp_path):
    reg_rows = [{"path": "potential_assets/P/Assets/Tiles.png", "kind": "tileset", "targets": ["tiles"],
                 "verdict": "UNREVIEWED", "tier": "pack-bundle", "material_labels": ["plank"],
                 "duplicate_sheets": ["potential_assets/P2/Assets/Tiles.png"]}]
    reg = tmp_path / "reg.json"
    reg.write_text(json.dumps({"assets": reg_rows}))
    index = tmp_path / "index.json"
    index.write_text(json.dumps({"P": [{"path": "P/Assets/Tiles.png"}], "P2": [{"path": "P2/Assets/Tiles.png"}]}))
    import io
    import contextlib
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        assert fa.main(["tiles", "--registry", str(reg), "--pack-index", str(index), "--json"]) == 0
    shown = json.loads(buf.getvalue())
    assert [(r["path"], r["kind"]) for r in shown] == [("potential_assets/P/Assets/Tiles.png", "tileset")]
