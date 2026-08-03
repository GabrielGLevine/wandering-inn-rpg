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

REVERSIBILITY — git blobs, addressed by SHA, never by commit.
The obvious design is to keep every per-file LUT and replay it
backwards. That was built and MEASURED, and it fails twice: the manifest
came to 32 MB (painterly rigs carry tens of thousands of distinct
colours), and the round trip is not byte-exact anyway — Pillow re-encodes
a PNG it merely opened and re-saved, so 208 of 389 files came back with
correct pixels and a different sha256. Preserved ORIGINALS are the
brief's other sanctioned option and git already holds them exactly.

The FIRST draft of that idea stored one `base_ref` commit and reverted
with `git checkout <base_ref> -- <path>`. That is a trap in a repo whose
merge style is SQUASH: the ref it recorded was the lane commit the pass
ran on, and a squash-merge makes that commit unreachable — the pass
would have become irreversible the moment it shipped. So:

  * every record stores `blob_before`, the git BLOB sha of the original.
    `--revert` restores with `git cat-file blob <sha>`, which does not
    care which commit is reachable, only that the blob is;
  * `--apply` PROVES that durability before it writes a byte. A file
    whose original blob is not the blob at `base_ref` (a commit on the
    upstream mainline, so it survives every squash) has its original
    EMBEDDED in the manifest, zlib+base64. That is what covers art this
    same branch introduced — its blobs live only in commits the squash
    will delete;
  * `base_ref` is the durable mainline merge-base by default, never
    plain HEAD, and `--base-ref` overrides it.
`--revert` verifies every restored file against `sha_before` and only
drops the manifest when all of them match.

LUTs are still forced INJECTIVE (a target colliding with one already
claimed is nudged a channel at a time until unique) so that no two
source colours end up literally the same byte triple.

DAMAGE GUARD. "A curated 90% beats a damaged 100%." Three measurements,
any one of which excludes a sheet:

  * `color_keep` — distinct targets / distinct sources, measured on the
    RAW ramp targets, BEFORE the injectivity nudge. Measuring after the
    nudge is what the first draft did and it is meaningless: the nudge
    hands every collision a numerically distinct but visually identical
    target (+-1 on one channel), so `keep` came back >= 0.949 on all 271
    sheets and every exclusion the guard ever made came from mean shift
    alone. The banding half of the guard was dead code.
  * `band_frac` — the share of a sheet's PIXELS whose colour got merged
    with a source colour more than `BAND_EPS` away in RGB. This is the
    metric that actually means "banding": collapsing two colours that
    were already within a rounding step of each other is invisible,
    collapsing two distinct shading steps into one flat block is the
    damage. color_keep cannot tell those apart; this can.
  * `mean_shift` — pixel-weighted distance the sheet's colour moved.

The guard's unit is the RIG (the directory), not the sheet: a rig whose
Idle got re-seated and whose Hit did not would strobe between animations
mid-fight, so one damaged sheet excludes its whole directory.

IDEMPOTENCE. This pass is NOT idempotent and must never run twice on its
own output — a second pull lands the sheet a third of the way from an
already-moved position, and the guard, reading the moved file as if it
were the original, silently reports different numbers. `--apply`
therefore REFUSES to run while a manifest exists; the manifest is a
committed repo file, so a clean checkout is protected by default and the
only way forward is `--revert` first. (That is not a hypothetical
failure: the tracked/untracked bug below was caught exactly this way — a
re-report came back 389 -> 384 sheets, and the five that vanished were
the untracked ones a previous run had moved and no revert could put
back.)

Usage:
    python3 scripts/palette_unify.py --report      # dry run + stats
    python3 scripts/palette_unify.py --apply       # refuses if applied
    python3 scripts/palette_unify.py --revert
    python3 scripts/palette_unify.py --report --calibrate
Run from the Godot project root (wandering_inn_game/).
"""

from __future__ import annotations

import argparse
import base64
import colorsys
import hashlib
import json
import os
import subprocess
import zlib
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "scripts" / "palette_unify_manifest.json"

ALPHA_FLOOR = 8
HUE_SECTORS = 12
RAMP_STEPS = 8
NEUTRAL_SAT = 0.12

# Per-family pull toward the PC16 ramp. CALIBRATED AGAINST THE DAMAGE
# GUARD over THIS SCRIPT'S OWN SCOPE, which is git-TRACKED assets only
# (see tracked_assets) — reproduce with `--report --calibrate`.
#
# In-scope population, measured: PIXELLAB 255 sheets, CUSTOM-HD 48
# sheets across 13 rigs, TILES 5, PC16 93 (read-only), 118 excluded by
# prefix. NOTE for anyone re-deriving these numbers: four names in
# CUSTOM_HD_DIRS (goblin_base, goblin_female, goblin_sword, bat) have
# ZERO tracked files — they are private-bundle overlay art — so the
# goblins are NOT part of any measurement this script can make. An
# earlier version of this comment cited "17 rigs / 130 sheets / every
# goblin sheet on keep"; those figures came from a first draft that
# walked `assets/` directly, including the overlay, and they are not
# reproducible in the shipped scope. Corrected here and in CHOICE-LOG.
#
# The calibration itself (measured, `--report --calibrate`, 2026-08-02):
#     CUSTOM-HD pull=0.35 ->  2/13 rigs excluded, 18/48 sheets dropped
#     CUSTOM-HD pull=0.45 ->  7/13 rigs excluded, 34/48 sheets dropped
#     CUSTOM-HD pull=0.55 ->  8/13 rigs excluded, 35/48 sheets dropped
# Every one of those exclusions is on MEAN SHIFT — the painterly rigs
# simply travel too far, they do not band (see BAND_EPS below). 0.35 is
# where the guard stops taking the family apart. PIXELLAB at 0.30 is
# lowest because those sheets were generated against the PC16 style
# kernel and only need a nudge; tiles sit under everything, so their
# pull is a whole-room decision.
FAMILY_PULL = {
    "CUSTOM-HD": 0.35,
    "PIXELLAB": 0.30,
    "TILES": 0.35,
}

# Damage thresholds. See DAMAGE GUARD above for what each one measures.
# BAND_EPS is the RGB distance below which merging two source colours is
# invisible (a rounding step, not a shading step).
#
# CALIBRATED off a pull sweep on the two sheets that collapse hardest,
# corusdeer_doe/Idle-Sheet.png and tiles/garden/sky_mist.png (both
# reproducible by hand with build_lut(..., pull_override=)):
#     pull  0.30  0.50  0.60  0.70  0.80  0.85  0.90
#     keep  .834  .671  .619  .505  .360  .272  .179
#     band  .000  .001  .000  .001  .000  .639  .859
# Banding has a KNEE, and it sits between keep 0.36 and keep 0.27 — above
# it the merges are all sub-BAND_EPS neighbours (invisible), below it the
# ramp starts folding real shading steps and band_frac goes to 0.6-0.9 in
# one step. MIN_COLOR_KEEP 0.60 is therefore a coarse backstop placed a
# long way above the knee; MAX_BAND_FRAC 0.10 is the sharp test, and it
# is the one that would actually fire on a banded sheet.
#
# WHAT THE SHIPPED PULLS MEASURE (and this is the honest headline): at
# 0.30-0.35 the source colour still contributes 65-70% of every channel,
# so two distinct sources cannot round onto one target unless they were
# already within ~1 per channel. band_frac is 0.0000 on all 271 sheets
# and MIN_COLOR_KEEP does not bind either — every exclusion in the
# shipped manifest is MAX_MEAN_SHIFT. That is a measurement, not an
# assumption, and it is only sayable because the metric is now live:
# the previous draft computed keep AFTER the injectivity nudge, where it
# was pinned at >= 0.949 by construction and could never have fired.
MIN_COLOR_KEEP = 0.60
MAX_BAND_FRAC = 0.10
BAND_EPS = 8.0
MAX_MEAN_SHIFT = 46.0

# How many bytes of embedded originals the manifest will carry before it
# refuses. Embedding is for the handful of sheets a branch introduces in
# the same wave as the pass; if hundreds of files need embedding, the
# base_ref is wrong and the operator must say which commit holds the
# originals rather than have a multi-megabyte JSON written for them.
MAX_EMBED_BYTES = 2 * 1024 * 1024

# PC16 = the reference family. Read to build the ramps, never written.
PC16_PREFIXES = (
    "assets/props/free_pack/",
    "assets/tiles/free_pack/",
    "assets/sprites/body_a/",
    "assets/sprites/pc_",
    "assets/sprites/citizen_f/",
)

# Painterly high-native rigs (the render_scale family). Names with no
# tracked files are private-bundle overlay art and are listed anyway so
# that a bundle-aware run has the roster; they are never reached here.
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


def git(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", "-C", str(ROOT.parent), *args], capture_output=True)


def git_ok(*args: str) -> str | None:
    proc = git(*args)
    if proc.returncode != 0:
        return None
    return proc.stdout.decode().strip()


def repo_path(relpath: str) -> str:
    return ROOT.name + "/" + relpath


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
    out = git_ok("ls-files", ROOT.name + "/assets")
    if out is None:
        raise SystemExit("git ls-files failed — cannot establish scope")
    prefix = ROOT.name + "/"
    return {p[len(prefix):] for p in out.splitlines() if p.startswith(prefix)}


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
    path: Path,
    family: str,
    ramps: dict[int, list[tuple[int, int, int]]],
    pull_override: float | None = None,
) -> tuple[dict[str, str], float, float, float] | None:
    hist = color_histogram(path)
    if not hist:
        return None
    pull = FAMILY_PULL[family] if pull_override is None else pull_override
    lumas = [luma(c) for c in hist]
    lo, hi = min(lumas), max(lumas)
    span = max(1e-6, hi - lo)

    claimed: set[tuple[int, int, int]] = set()
    lut: dict[str, str] = {}
    # RAW (pre-nudge) target -> the source colours that landed on it.
    # The guard reads THIS, not the nudged LUT: the nudge exists to keep
    # the mapping injective and it makes every collision look unique.
    raw_groups: dict[tuple[int, int, int], list[tuple[int, int, int]]] = {}
    shift_sum = 0.0
    weight = 0
    for c in sorted(hist):
        b = bucket_of(c)
        ramp = ramps.get(b) or ramps.get(-1)
        if not ramp:
            continue
        t = (luma(c) - lo) / span
        step = ramp[min(RAMP_STEPS - 1, max(0, round(t * (RAMP_STEPS - 1))))]
        raw = tuple(round(c[i] + (step[i] - c[i]) * pull) for i in range(3))
        raw_groups.setdefault(raw, []).append(c)
        # Injectivity: a LUT that collapses two sources onto one target
        # cannot be inverted, so nudge until unique.
        tgt = raw
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
    keep = len(raw_groups) / max(1, len(lut))

    # Banding: pixels whose colour merged with a VISIBLY different one.
    # The bbox diagonal of a group is the max pairwise distance in it,
    # and it is O(n) instead of O(n^2) on rigs with 30k+ colours.
    band_weight = 0
    for srcs in raw_groups.values():
        if len(srcs) < 2:
            continue
        spread = sum(
            (max(s[i] for s in srcs) - min(s[i] for s in srcs)) ** 2
            for i in range(3)
        ) ** 0.5
        if spread > BAND_EPS:
            band_weight += sum(hist[s] for s in srcs)
    band = band_weight / max(1, weight)
    return lut, mean_shift, keep, band


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


def hash_object(path: Path) -> str:
    out = git_ok("hash-object", "--", str(path))
    if out is None:
        raise SystemExit("git hash-object failed for %s" % path)
    return out


def resolve_base_ref(explicit: str | None) -> str:
    """The commit whose blobs are the ORIGINALS.

    NEVER plain HEAD. On a lane branch HEAD is a commit the merge train
    squashes away, and a manifest that points at it is a manifest with
    no inverse the day after it merges. The default is the merge-base
    with the upstream mainline, which is on main's own first-parent
    history and therefore permanent.
    """
    if explicit:
        got = git_ok("rev-parse", "--verify", explicit + "^{commit}")
        if got is None:
            raise SystemExit("--base-ref %s does not resolve" % explicit)
        return got
    for cand in ("origin/main", "main", "origin/master", "master"):
        if git_ok("rev-parse", "--verify", cand + "^{commit}") is None:
            continue
        mb = git_ok("merge-base", "HEAD", cand)
        if mb:
            return mb
    got = git_ok("rev-parse", "HEAD")
    if got is None:
        raise SystemExit("cannot resolve any base ref")
    return got


def restore(rec: dict, base: str | None) -> bytes | None:
    """Original bytes for one record, by the most durable route first."""
    if rec.get("orig_z"):
        return zlib.decompress(base64.b64decode(rec["orig_z"]))
    blob = rec.get("blob_before")
    if blob:
        proc = git("cat-file", "blob", blob)
        if proc.returncode == 0:
            return proc.stdout
    if base:
        proc = git("show", "%s:%s" % (base, repo_path(rec["path"])))
        if proc.returncode == 0:
            return proc.stdout
    return None


def do_revert() -> int:
    if not MANIFEST.exists():
        print("no manifest — nothing to revert")
        return 1
    man = json.loads(MANIFEST.read_text())
    base = man.get("base_ref")
    bad = 0
    restored = 0
    already = 0
    for rec in man["files"]:
        p = ROOT / rec["path"]
        if p.exists() and sha(p) == rec["sha_before"]:
            already += 1
            continue
        data = restore(rec, base)
        if data is None:
            print("  NO ORIGINAL AVAILABLE %s" % rec["path"])
            bad += 1
            continue
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(data)
        if sha(p) != rec["sha_before"]:
            print("  REVERT MISMATCH %s" % rec["path"])
            bad += 1
        else:
            restored += 1
    print("reverted %d files (%d already original), %d failures"
          % (restored, already, bad))
    if not bad:
        MANIFEST.unlink()
        print("manifest removed — tree is back on the originals")
    return 1 if bad else 0


def collect(ramps, pull_overrides: dict[str, float] | None = None) -> list[dict]:
    candidates: list[dict] = []
    for p in sheet_pngs():
        fam = family_of(rel(p))
        if fam == "PC16":
            continue
        over = (pull_overrides or {}).get(fam)
        built = build_lut(p, fam, ramps, over)
        if built is None:
            continue
        lut, shift, keep, band = built
        candidates.append({"path": rel(p), "family": fam, "lut": lut,
                           "mean_shift": round(shift, 2),
                           "color_keep": round(keep, 4),
                           "band_frac": round(band, 4)})
    return candidates


def rig_of(relpath: str) -> str:
    parts = relpath.split("/")
    return "/".join(parts[:3]) if len(parts) > 3 else relpath


def judge(candidates: list[dict]) -> tuple[list[dict], list[tuple]]:
    damaged_rigs: dict[str, tuple] = {}
    for rec in candidates:
        why = []
        if rec["color_keep"] < MIN_COLOR_KEEP:
            why.append("keep")
        if rec["band_frac"] > MAX_BAND_FRAC:
            why.append("band")
        if rec["mean_shift"] > MAX_MEAN_SHIFT:
            why.append("shift")
        if not why:
            continue
        rig = rig_of(rec["path"])
        prev = damaged_rigs.get(rig)
        if prev is None or rec["mean_shift"] > prev[2]:
            damaged_rigs[rig] = (rig, rec["family"], rec["mean_shift"],
                                 rec["color_keep"], rec["band_frac"],
                                 "+".join(why), rec["path"])
    files = [r for r in candidates if rig_of(r["path"]) not in damaged_rigs]
    return files, sorted(damaged_rigs.values())


def quantiles(vals: list[float]) -> str:
    if not vals:
        return "n/a"
    v = sorted(vals)
    def q(f: float) -> float:
        return v[min(len(v) - 1, int(f * len(v)))]
    return "min=%.4f p05=%.4f med=%.4f p95=%.4f max=%.4f" % (
        v[0], q(0.05), q(0.50), q(0.95), v[-1])


def run(mode: str, base_ref_arg: str | None, calibrate: bool) -> int:
    ramps = build_master_ramps()
    print("master ramps: %d buckets x %d steps (PC16-derived)"
          % (len(ramps), RAMP_STEPS))

    if mode == "revert":
        return do_revert()

    if mode == "apply" and MANIFEST.exists():
        print("REFUSING: %s exists, so this tree is already applied.\n"
              "This pass is NOT idempotent — a second run pulls each sheet\n"
              "a third of the way off an ALREADY-MOVED position and the\n"
              "guard would read the moved file as if it were the original.\n"
              "Run --revert first (it removes the manifest), then --apply."
              % rel(MANIFEST))
        return 1

    candidates = collect(ramps)
    files, excluded = judge(candidates)

    by_fam: dict[str, int] = {}
    for f in files:
        by_fam[f["family"]] = by_fam.get(f["family"], 0) + 1
    print("in scope: %d sheets %s" % (len(files), by_fam))
    print("EXCLUDED rigs (damage guard, whole-rig): %d" % len(excluded))
    for e in excluded:
        print("  %s [%s] shift=%s keep=%s band=%s by=%s (%s)" % e)
    print("color_keep   %s" % quantiles([c["color_keep"] for c in candidates]))
    print("band_frac    %s" % quantiles([c["band_frac"] for c in candidates]))
    print("mean_shift   %s" % quantiles([c["mean_shift"] for c in candidates]))

    if calibrate:
        pop: dict[str, int] = {}
        for p in sheet_pngs():
            fam = family_of(rel(p)) or "?"
            pop[fam] = pop.get(fam, 0) + 1
        rigs = {rig_of(rel(p)) for p in sheet_pngs()
                if family_of(rel(p)) == "CUSTOM-HD"}
        print("\nCALIBRATION (reproducible scope census)")
        print("  tracked sheets by family: %s" % dict(sorted(pop.items())))
        print("  CUSTOM-HD rigs in scope: %d %s"
              % (len(rigs), sorted(r.split("/")[-1] for r in rigs)))
        print("  CUSTOM_HD_DIRS with zero tracked files (bundle overlay): %s"
              % sorted(CUSTOM_HD_DIRS - {r.split("/")[-1] for r in rigs}))
        for trial in (0.35, 0.45, 0.55):
            cand = collect(ramps, {"CUSTOM-HD": trial})
            hd = [c for c in cand if c["family"] == "CUSTOM-HD"]
            _keep, exc = judge(cand)
            hd_exc = [e for e in exc if e[1] == "CUSTOM-HD"]
            dropped = sum(1 for c in hd
                          if rig_of(c["path"]) in {e[0] for e in hd_exc})
            print("  CUSTOM-HD pull=%.2f -> %d/%d rigs excluded, "
                  "%d/%d sheets dropped, reasons=%s"
                  % (trial, len(hd_exc), len(rigs), dropped, len(hd),
                     sorted({e[5] for e in hd_exc})))

    if mode == "report":
        return 0

    base_ref = resolve_base_ref(base_ref_arg)
    print("base_ref (durable originals): %s" % base_ref)

    # PROVE reversibility for every file BEFORE mutating any of them.
    embed_bytes = 0
    for rec in files:
        p = ROOT / rec["path"]
        rec["sha_before"] = sha(p)
        rec["blob_before"] = hash_object(p)
        # `<rev>:<path>` already yields the BLOB sha. Do NOT append the
        # `^{blob}` peel — git rejects the combination with "Needed a
        # single revision", every lookup fails, and the pass concludes
        # nothing is durable and tries to embed the entire corpus.
        at_base = git_ok("rev-parse", "--verify",
                         "%s:%s" % (base_ref, repo_path(rec["path"])))
        if at_base == rec["blob_before"]:
            continue
        raw = p.read_bytes()
        embed_bytes += len(raw)
        if embed_bytes > MAX_EMBED_BYTES:
            print("REFUSING: %d+ bytes of originals are not present at\n"
                  "base_ref %s, so they would have to be embedded in the\n"
                  "manifest. That means the base ref is wrong for this\n"
                  "tree. Re-run with --base-ref <commit holding the\n"
                  "originals>. Nothing was written."
                  % (embed_bytes, base_ref))
            return 1
        rec["orig_z"] = base64.b64encode(zlib.compress(raw, 9)).decode()

    embedded = sum(1 for r in files if "orig_z" in r)
    for rec in files:
        p = ROOT / rec["path"]
        apply_lut(p, rec.pop("lut"))
        rec["sha_after"] = sha(p)

    MANIFEST.write_text(json.dumps(
        {"_comment": "Generated by scripts/palette_unify.py --apply. Each "
                     "record carries blob_before, the git BLOB sha of the "
                     "original; --revert restores with `git cat-file blob`, "
                     "which survives the squash-merge that would make any "
                     "single base_ref COMMIT unreachable. Files whose "
                     "original is not in base_ref (art this branch added) "
                     "carry orig_z, the zlib+base64 original inline. "
                     "--apply refuses to run while this file exists.",
         "base_ref": base_ref, "hue_sectors": HUE_SECTORS,
         "ramp_steps": RAMP_STEPS, "neutral_sat": NEUTRAL_SAT,
         "family_pull": FAMILY_PULL,
         "guard": {"min_color_keep": MIN_COLOR_KEEP,
                   "max_band_frac": MAX_BAND_FRAC,
                   "band_eps": BAND_EPS,
                   "max_mean_shift": MAX_MEAN_SHIFT},
         "master_ramps": {str(b): ["#%02x%02x%02x" % c for c in steps]
                          for b, steps in sorted(ramps.items())},
         "excluded": excluded, "files": files}, indent=1) + "\n")
    print("applied to %d sheets (%d originals embedded); manifest at %s"
          % (len(files), embedded, rel(MANIFEST)))
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--report", action="store_true")
    g.add_argument("--apply", action="store_true")
    g.add_argument("--revert", action="store_true")
    ap.add_argument("--base-ref", default=None,
                    help="commit whose blobs are the ORIGINALS "
                         "(default: merge-base with the upstream mainline)")
    ap.add_argument("--calibrate", action="store_true",
                    help="with --report: print the scope census and the "
                         "CUSTOM-HD pull sweep the FAMILY_PULL comment cites")
    a = ap.parse_args()
    mode = "report" if a.report else "apply" if a.apply else "revert"
    return run(mode, a.base_ref, a.calibrate)


if __name__ == "__main__":
    raise SystemExit(main())
