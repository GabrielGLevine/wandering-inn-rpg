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


def test_strip_frames_from_height(tree):
    assert run(tree, STRIP, "--id", "lantern_flicker") == 0
    idle = sprites(tree)["lantern_flicker"]["animations"]["idle"]
    assert idle["frame_size"] == [64, 64] and idle["fps"] == 6
    assert sprites(tree)["lantern_flicker"]["anchor"] == [0.5, 0.9531]
    assert fixture(tree)["lantern_flicker/idle"] == 3
    line = [l for l in provenance(tree).splitlines() if l.startswith("lantern_flicker/Idle-Sheet.png:")][0]
    assert "frames 3 of 64x64" in line and "11111111-2222-4333-8444-555555555555" in line


def test_manifest_frame_size_wins(tree):
    assert run(tree, BENCH, "--id", "wide_bench", "--fps", "4") == 0
    idle = sprites(tree)["wide_bench"]["animations"]["idle"]
    assert idle["frame_size"] == [48, 32] and idle["fps"] == 4
    assert fixture(tree)["wide_bench/idle"] == 2


def test_frame_pin_conflict_refused(tree):
    f = tree / FIXTURE
    d = json.loads(f.read_text())
    d["counts"]["lantern_flicker/idle"] = 4
    f.write_text(json.dumps(d, indent=1, sort_keys=True) + "\n")
    before = snapshot(tree)
    assert run(tree, STRIP, "--id", "lantern_flicker") == wa.EXIT_REFUSED
    assert snapshot(tree) == before


def test_odd_sheet_is_a_probe_error(tree):
    from wi_fake_tree import png_box
    odd = tree / "potential_assets/pixellab_test/L2_props/odd.png"
    png_box(odd, 100, 64, (2, 2, 60, 60))
    before = snapshot(tree)
    assert run(tree, str(odd), "--id", "odd_prop") == wa.EXIT_PROBE
    assert snapshot(tree) == before


def test_pack_slice_becomes_region_row(tree):
    before = snapshot(tree)
    assert run(tree, SLICE, "--id", "crate_lidded", "--fallback", "crate_owned") == 0
    e = sprites(tree)["crate_lidded"]
    assert e["animations"]["idle"] == {"sheet": "res://assets/props/free_pack/Furniture.png",
                                       "frame_size": [16, 23], "region": [16, 8, 16, 23], "fps": 1}
    assert e["fallback_sprite"] == "crate_owned" and e["render_scale"] == 1.0
    assert e["anchor"] == [0.5, 1.0] and "shadow" not in e
    assert e["_comment"].startswith("slice of potential_assets/Pixel Crawler - Free Pack 2.1/Furniture.png "
                                    "region [16, 8, 16, 23]")
    assert fixture(tree)["crate_lidded/idle"] == 1
    after = snapshot(tree)
    assert not any(p.startswith("wandering_inn_game/assets/") for p in set(after) - set(before))
    for untouched in ("wandering_inn_game/assets_manifest.json", PROVENANCE):
        assert after[untouched] == before[untouched]


def test_pack_slice_rerun_is_noop(tree):
    assert run(tree, SLICE, "--id", "crate_lidded", "--fallback", "crate_owned") == 0
    before = snapshot(tree)
    assert run(tree, SLICE, "--id", "crate_lidded", "--fallback", "crate_owned") == 0
    assert snapshot(tree) == before


@pytest.mark.parametrize("fallback", [None, "crate", "pc_human_m", "nope"])
def test_pack_slice_requires_public_one_hop_fallback(tree, fallback):
    before = snapshot(tree)
    argv = [SLICE, "--id", "crate_lidded"] + (["--fallback", fallback] if fallback else [])
    assert run(tree, *argv) == wa.EXIT_REFUSED
    assert snapshot(tree) == before


def test_unbundled_sheet_exits_3_and_logs_pending(tree, capsys):
    before = snapshot(tree)
    assert run(tree, PENDING_SLICE, "--id", "hideout_crate", "--fallback", "crate_owned") == wa.EXIT_BUNDLE_PENDING
    assert f"BUNDLE-PENDING potential_assets/{UNBUNDLED_PACK}/Props.png" in capsys.readouterr().out
    assert changed(before, snapshot(tree)) == {"docs/art-bundle-pending.md"}
    doc = (tree / "docs/art-bundle-pending.md").read_text()
    assert doc.startswith(wa.BUNDLE_PENDING_HEADER)
    assert doc.count("Props__x0_y0_w16_h16.png") == 1 and "| hideout_crate | [0, 0, 16, 16] |" in doc
    assert run(tree, PENDING_SLICE, "--id", "hideout_crate", "--fallback", "crate_owned") == wa.EXIT_BUNDLE_PENDING
    assert (tree / "docs/art-bundle-pending.md").read_text() == doc


def test_unbundled_dry_run_logs_nothing(tree):
    before = snapshot(tree)
    assert run(tree, PENDING_SLICE, "--id", "hideout_crate", "--fallback", "crate_owned",
               "--dry-run") == wa.EXIT_BUNDLE_PENDING
    assert snapshot(tree) == before


def test_slicer_game_sheet_hint_short_circuits_hash(tree):
    sj = tree / f"potential_assets/{UNBUNDLED_PACK}/_sliced/Props/SLICES.json"
    d = json.loads(sj.read_text())
    d["assets"][0]["game_sheet"] = "assets/props/free_pack/Furniture.png"
    sj.write_text(json.dumps(d, indent=1) + "\n")
    assert run(tree, PENDING_SLICE, "--id", "hinted_crate", "--fallback", "crate_owned") == 0
    assert sprites(tree)["hinted_crate"]["animations"]["idle"]["sheet"] == "res://assets/props/free_pack/Furniture.png"
