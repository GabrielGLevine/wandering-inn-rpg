#!/usr/bin/env python3
"""Palette unification — seat every shipped art family on ONE ramp set.

WHY (visual-next-level lever 1). The world art is four families that were
never colour-matched to each other: PC16 (Pixel Crawler, the 16px
backbone and the largest volume), CUSTOM-HD (256-640px painterly rigs
downscaled via render_scale), PIXELLAB (owned 64-190px generations), and
the non-PC16 tile atlases. Each family carries its own idea of what
"dark brown" or "mid green" is, so a goblin, a floor tile and an owned
prop standing in one cell disagree about the scene's light. Naive global
quantisation would fix that by flattening everyone onto a shared palette
and destroying each sheet's internal modelling. This does the opposite:
it keeps every sheet's OWN value structure and re-seats only its CHROMA
onto PC16's ramps.

THE RAMP SET (derived, not authored). PC16 is the reference family — it
is the volume family, it is the one the eye reads as "the game's look",
and it is left BYTE-UNTOUCHED by this pass. Its pixels are bucketed by
hue into `HUE_SECTORS` sectors plus one neutral bucket (saturation below
`NEUTRAL_SAT`), and each bucket is reduced to a `RAMP_STEPS`-step value
ramp sampled at equal pixel-weighted luma quantiles. Sampling by
QUANTILE rather than by even luma spacing matters: it makes each step a
colour PC16 actually uses a lot of, so the ramps inherit PC16's own
hue-shift-as-it-darkens behaviour instead of a synthetic grey axis.

THE MAPPING (per-family, not per-pixel-nearest). For each source colour:
  1. bucket it by hue (or neutral) — a green stays green, a red stays
     red; this pass never re-hues anything;
  2. find its position t in its OWN SHEET's luma range, and take the
     master ramp step at that same relative position. The sheet's
     internal contrast survives intact; only the chroma moves;
  3. lerp source -> ramp colour by the family's PULL strength. Full
     replacement is what destroys identity, so no family is at 1.0.
Alpha is copied through untouched, always.

REVERSIBILITY — and why it is git, not a stored inverse. The obvious
design is to keep every per-file LUT and replay it backwards. That was
built and MEASURED, and it fails twice: the manifest came to 32 MB
(painterly rigs carry tens of thousands of distinct colours), and the
round trip is not byte-exact anyway — Pillow re-encodes a PNG it merely
opened and re-saved, so 208 of 389 files came back with correct pixels
and a different sha256. Preserved ORIGINALS are the brief's other
sanctioned option and git already holds them exactly, so `--apply`
records the commit it ran against and `--revert` is
`git checkout <base_ref> -- <path>` per file, verified against the
recorded pre-hash. Exact by construction, and the manifest stays small
enough to read.

LUTs are still forced INJECTIVE (a target colliding with one already
claimed is nudged a channel at a time until unique). That is no longer
about invertibility — it is what stops the ramp from folding two
neighbouring shading steps into one flat block, which is precisely the
damage the guard below measures.

DAMAGE GUARD. "A curated 90% beats a damaged 100%." Any sheet whose
mapping collapses its distinct-colour count below `MIN_COLOR_KEEP` of
the original, or moves its mean pixel further than `MAX_MEAN_SHIFT`, is
EXCLUDED and reported — the art wins the argument with the script. The
guard's unit is the RIG (the directory), not the sheet: a rig whose
Idle got re-seated and whose Hit did not would strobe between
animations mid-fight.

IDEMPOTENCE. This pass is NOT idempotent and must never run twice on
its own output — a second pull lands the sheet a third of the way from
an already-moved position, and the guard, reading the moved file as if
it were the original, silently reports different numbers. That is not
hypothetical: it is how the tracked/untracked bug below was caught (a
re-report came back 389 -> 384 sheets, and the five that vanished were
exactly the untracked ones the previous run had moved and no revert
could put back). Always `--revert` before re-applying.

Usage:
    python3 scripts/palette_unify.py --report      # dry run + stats
    python3 scripts/palette_unify.py --apply
    python3 scripts/palette_unify.py --revert
Run from the Godot project root (wandering_inn_game/).
"""

from __future__ import annotations

import argparse
import colorsys
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "scripts" / "palette_unify_manifest.json"

ALPHA_FLOOR = 8
HUE_SECTORS = 12
RAMP_STEPS = 8
NEUTRAL_SAT = 0.12

# Per-family pull toward the PC16 ramp. CALIBRATED AGAINST THE DAMAGE
# GUARD, not guessed: CUSTOM-HD started at 0.55 (it is the family that
# disagrees hardest with the backbone, so more pull looked right) and
# the guard rejected 12 of its 17 rigs outright — every goblin sheet on
# `keep`, every raskghar/river_wolf/rock_crab sheet on `shift`. At 0.35
# the same guard passes 116 of 130 CUSTOM-HD sheets. That is the guard
# working as designed: it measured that a painterly rig cannot absorb
# more than about a third of the way onto a 16px ramp before it stops
# being itself. PIXELLAB is lowest because those sheets were already
# generated against the PC16 style kernel and only need a nudge; tiles
# sit under everything, so their pull is a whole-room decision.
FAMILY_PULL = {
    "CUSTOM-HD": 0.35,
    "PIXELLAB": 0.30,
    "TILES": 0.35,
}

MIN_COLOR_KEEP = 0.60
MAX_MEAN_SHIFT = 46.0

# PC16 = the reference family. Read to build the ramps, never written.
PC16_PREFIXES = (
    "assets/props/free_pack/",
    "assets/tiles/free_pack/",
    "assets/sprites/body_a/",
    "assets/sprites/pc_",
    "assets/sprites/citizen_f/",
)

# Painterly high-native rigs (the render_scale family).
CUSTOM_HD_DIRS = {
    "goblin_base", "goblin_female", "goblin_sword", "bat", "mothbear",
    "river_wolf", "corusdeer", "kingslayer_spider", "rock_crab",
    "shield_spider", "raskghar_scout", "raskghar_awakened",
    "vault_construct", "forge_golem", "watchgolem", "skeleton_ally",
    "razorbeak",
}

# Never touched: UI lives in a different visual contract from world art
# (chrome, fonts, the 16x16 skill icons), fx is code-generated, and
# Admurin's pack ships under a no-AI-training clause — rendered output
# is fine but a derived recolour of the source sheet is not a fight
# worth having for iconography that never sits in a world cell.
EXCLUDE_PREFIXES = (
    "assets/ui/",
    "assets/icons/",
    "assets/fonts/",
    "assets/fx/",
    "assets/props/admurin/",
)


def rel(p: Path) -> str:
    return str(p.relative_to(ROOT)).replace(os.sep, "/")


def family_of(relpath: str) -> str | None:
    """None = do not touch."""
    if relpath.startswith(EXCLUDE_PREFIXES):
        return None
    if relpath.startswith(PC16_PREFIXES):
        return "PC16"
    parts = relpath.split("/")
    if relpath.startswith("assets/sprites/") and len(parts) > 2:
        return "CUSTOM-HD" if parts[2] in CUSTOM_HD_DIRS else "PIXELLAB"
    if relpath.startswith("assets/tiles/"):
        return "TILES"
    if relpath.startswith("assets/props/"):
        return "PIXELLAB"
    return None


def luma(c: tuple[int, int, int]) -> float:
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def bucket_of(c: tuple[int, int, int]) -> int:
    """Hue sector index, or -1 for the neutral bucket."""
    h, _l, s = colorsys.rgb_to_hls(c[0] / 255.0, c[1] / 255.0, c[2] / 255.0)
    if s < NEUTRAL_SAT:
        return -1
    return min(HUE_SECTORS - 1, int(h * HUE_SECTORS))


def tracked_assets() -> set[str]:
    """Paths git knows about, relative to the Godot project root.

    THE HARD BOUNDARY of this pass. `assets/` in a working checkout also
    contains the PRIVATE BUNDLE overlay — redistribution-limited packs
    that are gitignored by path (.gitignore lists them individually) and
    installed on top. Those files have NO preserved original anywhere in
    this repo, so a pass whose whole reversibility story is "git holds
    the originals" must not touch them; a first draft of this script did,
    and altered 105 of the user's licensed pack extracts with no way to
    put them back. Untracked = out of scope, always.
    """
    out = subprocess.check_output(
        ["git", "-C", str(ROOT.parent), "ls-files", ROOT.name + "/assets"]
    ).decode().splitlines()
    prefix = ROOT.name + "/"
    return {p[len(prefix):] for p in out if p.startswith(prefix)}


def sheet_pngs() -> list[Path]:
    tracked = tracked_assets()
    out = []
    for p in sorted((ROOT / "assets").rglob("*.png")):
        r = rel(p)
        if r in tracked and family_of(r) is not None:
            out.append(p)
    return out


def color_histogram(path: Path) -> dict[tuple[int, int, int], int]:
    img = Image.open(path).convert("RGBA")
    hist: dict[tuple[int, int, int], int] = {}
    for count, px in img.getcolors(maxcolors=1 << 24) or []:
        if px[3] < ALPHA_FLOOR:
            continue
        key = (px[0], px[1], px[2])
        hist[key] = hist.get(key, 0) + count
    return hist


def build_master_ramps() -> dict[int, list[tuple[int, int, int]]]:
    """Pixel-weighted luma quantiles per hue bucket, over PC16 only."""
    buckets: dict[int, list[tuple[float, tuple[int, int, int], int]]] = {}
    tracked = tracked_assets()
    for p in sorted((ROOT / "assets").rglob("*.png")):
        if rel(p) not in tracked or family_of(rel(p)) != "PC16":
            continue
        for c, n in color_histogram(p).items():
            buckets.setdefault(bucket_of(c), []).append((luma(c), c, n))

    ramps: dict[int, list[tuple[int, int, int]]] = {}
    for b, entries in buckets.items():
        entries.sort(key=lambda e: e[0])
        total = sum(e[2] for e in entries)
        if total == 0:
            continue
        steps: list[tuple[int, int, int]] = []
        for i in range(RAMP_STEPS):
            target = total * (i / max(1, RAMP_STEPS - 1))
            acc = 0
            pick = entries[-1][1]
            for lum, c, n in entries:
                acc += n
                if acc >= target:
                    pick = c
                    break
            steps.append(pick)
        ramps[b] = steps
    return ramps


def build_lut(
    path: Path, family: str, ramps: dict[int, list[tuple[int, int, int]]]
) -> tuple[dict[str, str], float, float] | None:
    hist = color_histogram(path)
    if not hist:
        return None
    pull = FAMILY_PULL[family]
    lumas = [luma(c) for c in hist]
    lo, hi = min(lumas), max(lumas)
    span = max(1e-6, hi - lo)

    claimed: set[tuple[int, int, int]] = set()
    lut: dict[str, str] = {}
    shift_sum = 0.0
    weight = 0
    for c in sorted(hist):
        b = bucket_of(c)
        ramp = ramps.get(b) or ramps.get(-1)
        if not ramp:
            continue
        t = (luma(c) - lo) / span
        step = ramp[min(RAMP_STEPS - 1, max(0, round(t * (RAMP_STEPS - 1))))]
        tgt = tuple(round(c[i] + (step[i] - c[i]) * pull) for i in range(3))
        # Injectivity: a LUT that collapses two sources onto one target
        # cannot be inverted, so nudge until unique.
        ch = 0
        while tgt in claimed:
            tgt = list(tgt)
            tgt[ch % 3] = max(0, min(255, tgt[ch % 3] + (1 if ch % 2 == 0 else -1)))
            tgt = tuple(tgt)
            ch += 1
            if ch > 32:
                break
        claimed.add(tgt)
        lut["%02x%02x%02x" % c] = "%02x%02x%02x" % tgt
        d = sum((tgt[i] - c[i]) ** 2 for i in range(3)) ** 0.5
        shift_sum += d * hist[c]
        weight += hist[c]
    mean_shift = shift_sum / max(1, weight)
    keep = len(set(lut.values())) / max(1, len(hist))
    return lut, mean_shift, keep


def apply_lut(path: Path, lut: dict[str, str]) -> None:
    img = Image.open(path).convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < ALPHA_FLOOR:
                continue
            v = lut.get("%02x%02x%02x" % (r, g, b))
            if v:
                px[x, y] = (int(v[0:2], 16), int(v[2:4], 16), int(v[4:6], 16), a)
    img.save(path)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(mode: str) -> int:
    ramps = build_master_ramps()
    print("master ramps: %d buckets x %d steps (PC16-derived)" % (len(ramps), RAMP_STEPS))

    if mode == "revert":
        if not MANIFEST.exists():
            print("no manifest — nothing to revert")
            return 1
        man = json.loads(MANIFEST.read_text())
        base = man["base_ref"]
        paths = [rec["path"] for rec in man["files"]]
        # --pathspec-from-file, not an argv list: 384 paths blows past the
        # shell's argument limit and git exits non-zero having reverted
        # nothing, silently.
        proc = subprocess.run(
            ["git", "-C", str(ROOT.parent), "checkout", base,
             "--pathspec-from-file=-"],
            input="\n".join(ROOT.name + "/" + p for p in paths).encode(),
            capture_output=True,
        )
        if proc.returncode != 0:
            print("git checkout %s failed — nothing reverted:\n%s"
                  % (base, proc.stderr.decode()[:800]))
            return 1
        bad = 0
        for rec in man["files"]:
            if sha(ROOT / rec["path"]) != rec["sha_before"]:
                print("  REVERT MISMATCH %s" % rec["path"])
                bad += 1
        print("reverted %d files from %s, %d mismatches" % (len(paths), base, bad))
        if not bad:
            MANIFEST.unlink()
        return 1 if bad else 0

    # Built per sheet, judged per RIG. A rig whose Idle got re-seated and
    # whose Hit did not would strobe between animations mid-fight, so the
    # damage guard's unit is the directory the player sees as one thing.
    candidates: list[dict] = []
    for p in sheet_pngs():
        fam = family_of(rel(p))
        if fam == "PC16":
            continue
        built = build_lut(p, fam, ramps)
        if built is None:
            continue
        lut, shift, keep = built
        candidates.append({"path": rel(p), "family": fam, "lut": lut,
                           "mean_shift": round(shift, 2), "color_keep": round(keep, 3)})

    def rig_of(relpath: str) -> str:
        parts = relpath.split("/")
        return "/".join(parts[:3]) if len(parts) > 3 else relpath

    damaged_rigs: dict[str, tuple] = {}
    for rec in candidates:
        if rec["color_keep"] < MIN_COLOR_KEEP or rec["mean_shift"] > MAX_MEAN_SHIFT:
            rig = rig_of(rec["path"])
            prev = damaged_rigs.get(rig)
            if prev is None or rec["mean_shift"] > prev[2]:
                damaged_rigs[rig] = (rig, rec["family"], rec["mean_shift"],
                                     rec["color_keep"], rec["path"])

    files = [r for r in candidates if rig_of(r["path"]) not in damaged_rigs]
    excluded = sorted(damaged_rigs.values())

    by_fam: dict[str, int] = {}
    for f in files:
        by_fam[f["family"]] = by_fam.get(f["family"], 0) + 1
    print("in scope: %d sheets %s" % (len(files), by_fam))
    print("EXCLUDED rigs (damage guard, whole-rig): %d" % len(excluded))
    for e in excluded:
        print("  %s [%s] worst shift=%s keep=%s (%s)" % e)

    if mode == "report":
        return 0

    base_ref = subprocess.check_output(
        ["git", "-C", str(ROOT.parent), "rev-parse", "HEAD"]).decode().strip()
    for rec in files:
        p = ROOT / rec["path"]
        rec["sha_before"] = sha(p)
        apply_lut(p, rec.pop("lut"))
        rec["sha_after"] = sha(p)
    MANIFEST.write_text(json.dumps(
        {"_comment": "Generated by scripts/palette_unify.py --apply. "
                     "base_ref holds the ORIGINALS: --revert is a git "
                     "checkout of these paths at that commit, verified "
                     "against each sha_before. Re-running --apply on an "
                     "already-applied tree would double-pull; revert first.",
         "base_ref": base_ref, "hue_sectors": HUE_SECTORS,
         "ramp_steps": RAMP_STEPS, "neutral_sat": NEUTRAL_SAT,
         "family_pull": FAMILY_PULL,
         "master_ramps": {str(b): ["#%02x%02x%02x" % c for c in steps]
                          for b, steps in sorted(ramps.items())},
         "excluded": excluded, "files": files}, indent=1) + "\n")
    print("applied to %d sheets; manifest at %s (base_ref %s)"
          % (len(files), rel(MANIFEST), base_ref[:8]))
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--report", action="store_true")
    g.add_argument("--apply", action="store_true")
    g.add_argument("--revert", action="store_true")
    a = ap.parse_args()
    return run("report" if a.report else "apply" if a.apply else "revert")


if __name__ == "__main__":
    raise SystemExit(main())
