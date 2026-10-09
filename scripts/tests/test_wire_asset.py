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
from wi_fake_tree import (BENCH, OWNED, OWNED_DUP, PACK, PENDING_SLICE, PIXELLAB_ID, SLICE, STRIP,  # noqa: E402
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
    sj = tree / f"potential_assets/_sliced/{UNBUNDLED_PACK}/Props/SLICES.json"
    d = json.loads(sj.read_text())
    d["assets"][0]["game_sheet"] = "assets/props/free_pack/Furniture.png"
    d["assets"][0]["sheet_sha256"] = sha(tree / "wandering_inn_game/assets/props/free_pack/Furniture.png")
    sj.write_text(json.dumps(d, indent=1) + "\n")
    assert run(tree, PENDING_SLICE, "--id", "hinted_crate", "--fallback", "crate_owned") == 0
    assert sprites(tree)["hinted_crate"]["animations"]["idle"]["sheet"] == "res://assets/props/free_pack/Furniture.png"


def _set_hint(tree, hint):
    sj = tree / f"potential_assets/_sliced/{UNBUNDLED_PACK}/Props/SLICES.json"
    d = json.loads(sj.read_text())
    d["assets"][0]["game_sheet"] = hint
    sj.write_text(json.dumps(d, indent=1) + "\n")


def test_hint_with_wrong_sha_is_ignored(tree, capsys):
    from wi_fake_tree import png_box
    png_box(tree / "wandering_inn_game/assets/props/other.png", 32, 32, (1, 1, 20, 20))
    _set_hint(tree, "assets/props/other.png")
    before = snapshot(tree)
    assert run(tree, PENDING_SLICE, "--id", "hinted_crate", "--fallback", "crate_owned") == wa.EXIT_BUNDLE_PENDING
    assert "BUNDLE-PENDING" in capsys.readouterr().out
    assert "hinted_crate" not in sprites(tree) and SPRITES not in changed(before, snapshot(tree))


def test_hint_with_wrong_sha_falls_back_to_index(tree):
    sj = tree / f"potential_assets/_sliced/{PACK}/Furniture/SLICES.json"
    d = json.loads(sj.read_text())
    d["assets"][0]["game_sheet"] = "assets/sprites/crate_owned/Idle-Sheet.png"
    sj.write_text(json.dumps(d, indent=1) + "\n")
    assert run(tree, SLICE, "--id", "crate_lidded", "--fallback", "crate_owned") == 0
    assert sprites(tree)["crate_lidded"]["animations"]["idle"]["sheet"] == "res://assets/props/free_pack/Furniture.png"


def test_hint_outside_assets_is_ignored(tree):
    sj = tree / f"potential_assets/_sliced/{PACK}/Furniture/SLICES.json"
    d = json.loads(sj.read_text())
    d["assets"][0]["game_sheet"] = "assets/../data/../../potential_assets/x.png"
    sj.write_text(json.dumps(d, indent=1) + "\n")
    (tree / "potential_assets/x.png").write_bytes((tree / "wandering_inn_game/assets/props/free_pack/Furniture.png").read_bytes())
    assert run(tree, SLICE, "--id", "crate_lidded", "--fallback", "crate_owned") == 0
    assert sprites(tree)["crate_lidded"]["animations"]["idle"]["sheet"] == "res://assets/props/free_pack/Furniture.png"


def test_missing_manifest_refuses_fallback(tree):
    (tree / "wandering_inn_game/assets_manifest.json").unlink()
    before = snapshot(tree)
    assert run(tree, SLICE, "--id", "crate_lidded", "--fallback", "crate_owned") == wa.EXIT_REFUSED
    assert snapshot(tree) == before


def test_sheet_bundled_after_first_lookup_is_found(tree):
    paths = wa.Paths(tree) if hasattr(wa, "Paths") else None
    assert wa.bundled_sheet_for("0" * 64, paths) is None
    from wi_fake_tree import png_box
    late = png_box(tree / "wandering_inn_game/assets/props/late.png", 16, 16, (1, 1, 14, 14))
    assert wa.bundled_sheet_for(sha(late), paths) == "assets/props/late.png"


def test_real_res_form_hint_short_circuits_index(tree, monkeypatch):
    sj = tree / f"potential_assets/_sliced/{UNBUNDLED_PACK}/Props/SLICES.json"
    d = json.loads(sj.read_text())
    d["assets"][0]["game_sheet"] = "res://assets/props/free_pack/Furniture.png"
    d["assets"][0]["sheet_sha256"] = sha(tree / "wandering_inn_game/assets/props/free_pack/Furniture.png")
    sj.write_text(json.dumps(d, indent=1) + "\n")
    monkeypatch.setattr(wa, "bundled_sheet_for", lambda *a, **k: pytest.fail("index rebuilt despite valid hint"))
    assert run(tree, PENDING_SLICE, "--id", "hinted_crate", "--fallback", "crate_owned") == 0
    assert sprites(tree)["hinted_crate"]["animations"]["idle"]["sheet"] == "res://assets/props/free_pack/Furniture.png"


def test_misses_rebuild_index_at_most_once(tree, monkeypatch):
    paths = wa.Paths(tree)
    wa._SHEET_INDEX.clear()
    calls = []
    real = wa.sha256_file
    monkeypatch.setattr(wa, "sha256_file", lambda p: calls.append(p) or real(p))
    for i in range(6):
        assert wa.bundled_sheet_for(f"{i:064x}", paths) is None
    n_png = len(list(paths.assets.rglob("*.png")))
    assert len(calls) <= 2 * n_png


ALLOWED = {SPRITES, FIXTURE, PROVENANCE, "docs/asset-candidates.json", "docs/asset-candidates.md",
           "docs/art-bundle-pending.md"}


def test_only_allowed_paths_change_never_manifest_or_potential(tree):
    manifest = {a["path"] for a in json.loads((tree / "wandering_inn_game/assets_manifest.json").read_text())["assets"]}
    before = snapshot(tree)
    assert run(tree, OWNED, SLICE, "--id", "parcel_stack", "--id", "crate_lidded", "--fallback", "crate_owned") == 0
    delta = changed(before, snapshot(tree))
    assert delta <= ALLOWED | {"wandering_inn_game/assets/sprites/parcel_stack/Idle-Sheet.png"}
    assert not any(p.startswith("potential_assets/") for p in delta)
    assert not any(p.removeprefix("wandering_inn_game/") in manifest for p in delta)


def test_candidates_regenerated_once_with_repo_root(tree):
    assert run(tree, OWNED, "--id", "parcel_stack") == 0
    reg = json.loads((tree / "docs/asset-candidates.json").read_text())
    batches = {b["batch"] for b in reg["batches"]}
    assert "pixellab_test/L2_props" in batches
    assert {r["sprite_id"] for r in reg["assets"] if r.get("sprite_id")} == {"crate", "crate_owned", "pc_human_m", "parcel_stack"}
    assert (tree / "docs/asset-candidates.md").read_text().startswith("# Asset candidates registry")


def test_no_regen_flag(tree):
    assert run(tree, OWNED, "--id", "parcel_stack", "--no-regen") == 0
    assert not (tree / "docs/asset-candidates.json").exists()


def test_owned_path_refuses_pack_png_and_unverified_codex(tree, capsys):
    from wi_fake_tree import png_box
    pack = "potential_assets/Pixel Crawler - Free Pack 2.1/Env/Chest.png"
    codex = "potential_assets/codex_test/L2_props/chest.png"
    png_box(tree / pack, 64, 64, (8, 8, 40, 40))
    png_box(tree / codex, 64, 64, (8, 8, 40, 40))
    before = snapshot(tree)
    assert run(tree, pack, "--id", "pack_chest") == wa.EXIT_REFUSED
    assert "pack_chest" not in sprites(tree)
    assert run(tree, codex, "--id", "codex_chest") == wa.EXIT_REFUSED
    assert "--allow-unverified" in capsys.readouterr().out
    assert not changed(before, snapshot(tree))
    assert run(tree, codex, "--id", "codex_chest", "--allow-unverified", "--dry-run") == 0


def test_symlinked_potential_assets_root_is_accepted(tree, tmp_path):
    """A worktree's potential_assets is a symlink to the real pack store; resolved candidates must still match."""
    import shutil
    real = tmp_path / "real_store"
    shutil.move(str(tree / "potential_assets"), str(real))
    (tree / "potential_assets").symlink_to(real, target_is_directory=True)
    assert run(tree, OWNED, "--id", "parcel_stack") == 0


def test_candidate_outside_symlinked_potential_assets_is_refused(tree, tmp_path, capsys):
    import shutil
    real = tmp_path / "real_store"
    shutil.move(str(tree / "potential_assets"), str(real))
    (tree / "potential_assets").symlink_to(real, target_is_directory=True)
    stray = tmp_path / "stray" / "parcel_stack.png"
    stray.parent.mkdir()
    shutil.copy(real / "pixellab_test/L2_props/parcel_stack.png", stray)
    before = snapshot(tree)
    assert run(tree, str(stray), "--id", "parcel_stack") == wa.EXIT_REFUSED
    assert snapshot(tree) == before
    assert "potential_assets" in capsys.readouterr().out


def _symlink_store(tree, tmp_path):
    import shutil
    real = tmp_path / "real_store"
    shutil.move(str(tree / "potential_assets"), str(real))
    (tree / "potential_assets").symlink_to(real, target_is_directory=True)
    return real


def test_slice_helpers_accept_resolved_candidate_under_symlinked_root(tree, tmp_path):
    _symlink_store(tree, tmp_path)
    paths = wa.Paths(tree)
    resolved = (tree / SLICE).resolve()
    assert wa.is_slice(resolved)
    assert wa.logical_candidate(resolved, paths) == paths.potential / resolved.relative_to(paths.potential.resolve())
    row = wa.slice_row(resolved, paths)
    assert row["region"] == [16, 8, 16, 23]


def test_pack_slice_wires_through_symlinked_potential_assets(tree, tmp_path):
    _symlink_store(tree, tmp_path)
    assert run(tree, SLICE, "--id", "crate_lidded", "--fallback", "crate_owned") == 0
    assert sprites(tree)["crate_lidded"]["animations"]["idle"]["region"] == [16, 8, 16, 23]


# ---------------------------------------------------------------- #623 duplicate art

def _twin_crate(tree):
    """Point the shipped `crate` at the slice's region: the slice's art is then already registered."""
    p = tree / SPRITES
    cat = json.loads(p.read_text())
    cat["crate"]["animations"]["idle"]["region"] = [16, 8, 16, 23]
    p.write_text(json.dumps(cat, indent=1) + "\n")


def test_pack_slice_of_registered_art_is_refused_naming_the_id(tree, capsys):
    _twin_crate(tree)
    before = snapshot(tree)
    assert run(tree, SLICE, "--id", "crate_lidded", "--fallback", "crate_owned") == wa.EXIT_DUPLICATE == 6
    out = capsys.readouterr().out
    assert "DUPLICATE-ART crate_lidded" in out and "already registered as crate." in out
    assert "--alias-of crate --reason" in out
    assert snapshot(tree) == before


def test_owned_byte_identical_copy_is_refused(tree, capsys):
    assert run(tree, OWNED, "--id", "parcel_stack") == 0
    before = snapshot(tree)
    assert run(tree, OWNED_DUP, "--id", "parcel_stack_b") == wa.EXIT_DUPLICATE
    assert "already registered as parcel_stack" in capsys.readouterr().out
    assert snapshot(tree) == before


def test_another_scale_does_not_hide_a_duplicate(tree, capsys):
    assert run(tree, SLICE, "--id", "crate_lidded", "--fallback", "crate_owned") == 0
    before = snapshot(tree)
    assert run(tree, SLICE, "--id", "crate_big", "--fallback", "crate_owned", "--like", "crate_owned") == wa.EXIT_DUPLICATE
    assert "already registered as crate_lidded" in capsys.readouterr().out
    assert snapshot(tree) == before


def test_alias_of_records_the_alias_and_reason(tree):
    _twin_crate(tree)
    argv = (SLICE, "--id", "crate_lidded", "--fallback", "crate_owned", "--alias-of", "crate",
            "--reason", "quest crate keeps its own id")
    assert run(tree, *argv) == 0
    e = sprites(tree)["crate_lidded"]
    assert list(e)[:3] == ["_comment", "_alias_of", "_alias_reason"]
    assert e["_alias_of"] == "crate" and e["_alias_reason"] == "quest crate keeps its own id"
    assert e["animations"]["idle"]["region"] == [16, 8, 16, 23]
    before = snapshot(tree)
    assert run(tree, *argv) == 0
    assert snapshot(tree) == before


def test_alias_of_must_name_a_twin(tree, capsys):
    _twin_crate(tree)
    before = snapshot(tree)
    assert run(tree, SLICE, "--id", "crate_lidded", "--fallback", "crate_owned",
               "--alias-of", "crate_owned", "--reason", "x") == wa.EXIT_DUPLICATE
    assert "already registered as crate." in capsys.readouterr().out
    assert run(tree, OWNED, "--id", "parcel_stack", "--alias-of", "crate_owned", "--reason", "x") == wa.EXIT_REFUSED
    assert "no registered id draws this art" in capsys.readouterr().out
    assert snapshot(tree) == before


@pytest.mark.parametrize("extra", [("--alias-of", "crate"), ("--reason", "why"), ("--alias-of", "crate", "--reason", " ")])
def test_alias_flags_go_together(tree, extra):
    before = snapshot(tree)
    assert run(tree, SLICE, "--id", "crate_lidded", "--fallback", "crate_owned", *extra) == wa.EXIT_USAGE
    assert snapshot(tree) == before


def test_alias_takes_one_candidate(tree):
    before = snapshot(tree)
    assert run(tree, OWNED, SLICE, "--id", "a_one", "--id", "a_two", "--fallback", "crate_owned",
               "--alias-of", "crate", "--reason", "x") == wa.EXIT_USAGE
    assert snapshot(tree) == before


def test_rerun_of_a_wired_id_is_not_a_duplicate(tree, capsys):
    assert run(tree, SLICE, "--id", "crate_lidded", "--fallback", "crate_owned") == 0
    _twin_crate(tree)   # a legacy twin appears later; re-running the finished wiring stays a no-op
    before = snapshot(tree)
    assert run(tree, SLICE, "--id", "crate_lidded", "--fallback", "crate_owned") == 0
    assert "no change" in capsys.readouterr().out
    assert snapshot(tree) == before


def test_near_identical_rect_is_refused(tree, capsys):
    # #623 review I1: the slice [16,8,16,23] vs a hand-cut [16,9,16,22] of the same picture (IoU 0.96)
    p = tree / SPRITES
    cat = json.loads(p.read_text())
    cat["crate"]["animations"]["idle"]["region"] = [16, 9, 16, 22]
    p.write_text(json.dumps(cat, indent=1) + "\n")
    before = snapshot(tree)
    assert run(tree, SLICE, "--id", "crate_lidded", "--fallback", "crate_owned") == wa.EXIT_DUPLICATE
    assert "already registered as crate." in capsys.readouterr().out
    assert snapshot(tree) == before
    assert run(tree, SLICE, "--id", "crate_lidded", "--fallback", "crate_owned", "--alias-of", "crate",
               "--reason", "tight slice of the same crate") == 0
    assert sprites(tree)["crate_lidded"]["_alias_of"] == "crate"


@pytest.mark.parametrize("label,recorded", [("crate", "crate"), ("spaceship", None), (None, None)])
def test_slice_label_kind_is_recorded(tree, label, recorded):
    # #623 review I2: the kind on record that data_lint's _common Tier A rule reads
    sj = tree / f"potential_assets/_sliced/{PACK}/Furniture/SLICES.json"
    d = json.loads(sj.read_text())
    if label:
        d["assets"][0]["label_kind"] = label
    sj.write_text(json.dumps(d, indent=1) + "\n")
    assert run(tree, SLICE, "--id", "crate_lidded", "--fallback", "crate_owned") == 0
    e = sprites(tree)["crate_lidded"]
    assert e.get("kind") == recorded
    if recorded:
        assert list(e)[:2] == ["_comment", "kind"]
