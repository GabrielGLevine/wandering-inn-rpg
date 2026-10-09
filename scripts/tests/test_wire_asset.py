#!/usr/bin/env python3
"""tools/wire_asset.py against the synthetic tree (scripts/tests/wi_fake_tree.py)."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

pytest.importorskip("PIL")   # Pillow is the dev dependency sprite_alpha_probe.py already needs
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent.parent / "tools"))
import wire_asset as wa  # noqa: E402
from wi_fake_tree import (BENCH, OWNED, PENDING_SLICE, PIXELLAB_ID, SLICE, STRIP,  # noqa: E402
                          UNBUNDLED_PACK, changed, make_tree, sha, snapshot)

SPRITES = "wandering_inn_game/data/sprites.json"
FIXTURE = "wandering_inn_game/qa/fixtures/sprite_frame_counts.json"
PROVENANCE = "wandering_inn_game/assets/LICENSES/v019-owned-art-provenance.txt"


@pytest.fixture
def tree(tmp_path: Path) -> Path:
    return make_tree(tmp_path / "repo")


def run(tree: Path, *argv: str) -> int:
    return wa.main([*argv, "--repo-root", str(tree)])


def sprites(tree: Path) -> dict:
    return json.loads((tree / SPRITES).read_text())


def fixture(tree: Path) -> dict:
    return json.loads((tree / FIXTURE).read_text())["counts"]


def provenance(tree: Path) -> str:
    return (tree / PROVENANCE).read_text()


def test_refuses_pc_id(tree, capsys):
    before = snapshot(tree)
    assert run(tree, OWNED, "--id", "pc_gnoll_x") == wa.EXIT_REFUSED
    assert snapshot(tree) == before
    assert "pc_" in capsys.readouterr().out


def test_id_count_must_match_candidates(tree):
    before = snapshot(tree)
    assert run(tree, OWNED, STRIP, "--id", "only_one") == wa.EXIT_USAGE
    assert snapshot(tree) == before


def test_owned_static_wires(tree):
    assert run(tree, OWNED, "--id", "parcel_stack") == 0
    dst = tree / "wandering_inn_game/assets/sprites/parcel_stack/Idle-Sheet.png"
    assert sha(dst) == sha(tree / OWNED)
    assert sprites(tree)["parcel_stack"] == {
        "render_scale": 0.4, "anchor": [0.5, 0.9375], "shadow": True,
        "animations": {"idle": {"sheet": "res://assets/sprites/parcel_stack/Idle-Sheet.png",
                                "frame_size": [64, 64], "fps": 1}}}
    assert fixture(tree)["parcel_stack/idle"] == 1
    lines = [l for l in provenance(tree).splitlines() if l.startswith("parcel_stack/Idle-Sheet.png:")]
    assert len(lines) == 1 and sha(dst) in lines[0] and PIXELLAB_ID in lines[0] and OWNED in lines[0]
    reg = json.loads((tree / "docs/asset-candidates.json").read_text())
    assert any(r.get("sprite_id") == "parcel_stack" for r in reg["assets"])


def test_rerun_is_noop(tree, capsys):
    assert run(tree, OWNED, "--id", "parcel_stack") == 0
    before = snapshot(tree)
    assert run(tree, OWNED, "--id", "parcel_stack") == 0
    assert snapshot(tree) == before
    assert "no change" in capsys.readouterr().out


def test_existing_id_with_different_content_is_refused(tree):
    assert run(tree, OWNED, "--id", "parcel_stack") == 0
    p = tree / SPRITES
    cat = json.loads(p.read_text())
    cat["parcel_stack"]["render_scale"] = 0.5
    p.write_text(json.dumps(cat, indent=1) + "\n")
    before = snapshot(tree)
    assert run(tree, OWNED, "--id", "parcel_stack") == wa.EXIT_REFUSED
    assert snapshot(tree) == before


def test_existing_sheet_with_different_bytes_is_refused(tree):
    dst = tree / "wandering_inn_game/assets/sprites/parcel_stack/Idle-Sheet.png"
    dst.parent.mkdir(parents=True)
    dst.write_bytes((tree / STRIP).read_bytes())
    before = snapshot(tree)
    assert run(tree, OWNED, "--id", "parcel_stack") == wa.EXIT_REFUSED
    assert snapshot(tree) == before


def test_resumes_after_partial_copy(tree):
    dst = tree / "wandering_inn_game/assets/sprites/parcel_stack/Idle-Sheet.png"
    dst.parent.mkdir(parents=True)
    dst.write_bytes((tree / OWNED).read_bytes())
    assert run(tree, OWNED, "--id", "parcel_stack") == 0
    assert "parcel_stack" in sprites(tree) and fixture(tree)["parcel_stack/idle"] == 1


def test_dry_run_prints_diff_and_writes_nothing(tree, capsys):
    before = snapshot(tree)
    assert run(tree, OWNED, "--id", "parcel_stack", "--dry-run") == 0
    out = capsys.readouterr().out
    assert snapshot(tree) == before
    assert ("COPY potential_assets/pixellab_test/L2_props/parcel_stack.png -> "
            "wandering_inn_game/assets/sprites/parcel_stack/Idle-Sheet.png") in out
    assert '+ "parcel_stack": {' in out
    assert '+  "parcel_stack/idle": 1' in out
    assert "+parcel_stack/Idle-Sheet.png:" in out


def test_sprites_json_edit_is_surgical(tree):
    before = (tree / SPRITES).read_text()
    assert run(tree, OWNED, "--id", "parcel_stack") == 0
    after = (tree / SPRITES).read_text()
    head = before.rstrip()[:-1].rstrip()   # every byte up to the final closing brace
    assert after.startswith(head + ",\n") and after.endswith("\n}\n")
    assert json.loads(after)["crate"] == json.loads(before)["crate"]


def test_fixture_rejects_non_integer_pins(tree):
    f = tree / FIXTURE
    d = json.loads(f.read_text())
    d["counts"]["crate/idle"] = 1.5
    f.write_text(json.dumps(d, indent=1, sort_keys=True) + "\n")
    before = snapshot(tree)
    assert run(tree, OWNED, "--id", "parcel_stack") == wa.EXIT_REFUSED
    assert snapshot(tree) == before
