#!/usr/bin/env python3
"""Turn an audio-profile CSV into per-slot shortlists and a listening queue.

    python3 scripts/audio_shortlist.py docs/design/audio-profiles.csv

Reads the CSV written by scripts/audio_profile.py and applies the slot rules
below, printing a markdown report. Every threshold is named here rather than
applied by eye, so a re-run reproduces the same shortlist from the same
numbers — the 2026-07-19 pass on this pack could not be re-derived because its
selection lived only in prose.

Slot rules
  menu/title   score-length (>=40 s), <=125 BPM, lowest onset density first
  jingle       3-10 s, split major (success class) / minor (failure class)
  stinger      <=3 s, clustered by centroid: impact <1500 Hz,
               ui-foley 1500-3500 Hz, shimmer >3500 Hz; loudest first
  ambient bed  >=60 s and quieter + less struck than the shipped ambience floor
"""

from __future__ import annotations

import argparse
import csv
import statistics
import sys
from pathlib import Path

MENU_MIN_DURATION = 40.0
MENU_MAX_TEMPO = 125.0
JINGLE_RANGE = (3.0, 10.0)
STINGER_MAX = 3.0
BED_MIN_DURATION = 60.0
CENTROID_IMPACT = 1500.0
CENTROID_SHIMMER = 3500.0
TOP_N = 5


def load(path: Path) -> list[dict]:
    with path.open() as fh:
        rows = list(csv.DictReader(fh))
    for r in rows:
        for key in ("duration_s", "tempo_bpm", "rms_p95", "centroid_hz", "onset_density", "onsets_per_sec", "energy"):
            r[key] = float(r[key]) if r.get(key) not in (None, "") else None
    return rows


def fmt(r: dict) -> str:
    def n(key: str, digits: int = 2) -> str:
        v = r.get(key)
        return "-" if v is None else f"{v:.{digits}f}"

    return (
        f"`{r['name']}` — {n('duration_s', 1)} s, {n('tempo_bpm', 0)} BPM, "
        f"rms {n('rms_p95', 3)}, {n('centroid_hz', 0)} Hz, onset {n('onset_density', 3)} "
        f"({n('onsets_per_sec', 2)}/s), {r['chroma_mode'] or '?'}, energy {n('energy', 3)}"
    )


def band(rows: list[dict], key: str) -> str:
    vals = [r[key] for r in rows if r.get(key) is not None]
    if not vals:
        return "n/a"
    return f"min {min(vals):.3f} / median {statistics.median(vals):.3f} / max {max(vals):.3f}"


def section(title: str, rows: list[dict], limit: int = TOP_N) -> None:
    print(f"\n### {title} ({len(rows)} qualify)")
    if not rows:
        print("\n_nothing qualifies._")
        return
    print()
    for r in rows[:limit]:
        print(f"- {fmt(r)}")
    if len(rows) > limit:
        print(f"- _...{len(rows) - limit} more in the CSV_")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("csv", help="profile CSV from scripts/audio_profile.py")
    ap.add_argument("--queue", help="write the flat listening queue (one path per line) here")
    ap.add_argument(
        "--stage",
        help="copy the queue into this directory, numbered and slot-labelled, for the ear-gate",
    )
    args = ap.parse_args()

    path = Path(args.csv)
    if not path.exists():
        print(f"missing {path}", file=sys.stderr)
        return 2
    rows = load(path)

    anchors = [r for r in rows if r["role"] == "anchor"]
    cands = [r for r in rows if r["role"] == "candidate"]
    if not cands:
        print("no candidates in the CSV", file=sys.stderr)
        return 2

    music_anchors = [a for a in anchors if "/music" in a["path"] or a["category"].endswith("music")]
    amb_anchors = [a for a in anchors if a not in music_anchors]

    print(f"# Audio shortlist — {len(cands)} candidates vs {len(anchors)} shipped anchors")
    print(f"\nSource: `{path}`. Regenerate: `python3 scripts/audio_shortlist.py {path}`.")
    print("\n## Anchor calibration\n")
    print(f"- shipped music ({len(music_anchors)}): energy {band(music_anchors, 'energy')}")
    print(f"- shipped music: centroid {band(music_anchors, 'centroid_hz')}")
    print(f"- shipped music: onset density {band(music_anchors, 'onset_density')}")
    print(f"- shipped ambience ({len(amb_anchors)}): rms {band(amb_anchors, 'rms_p95')}")
    print(f"- shipped ambience: onset density {band(amb_anchors, 'onset_density')}")

    # The ambience floor is what a candidate bed has to sit at or under to read
    # as a bed rather than as foreground music.
    amb_rms = [a["rms_p95"] for a in amb_anchors if a["rms_p95"] is not None]
    amb_onset = [a["onset_density"] for a in amb_anchors if a["onset_density"] is not None]
    bed_rms_ceiling = max(amb_rms) if amb_rms else 0.0
    bed_onset_ceiling = max(amb_onset) if amb_onset else 0.0

    timed = [c for c in cands if c["duration_s"] is not None]
    print("\n## Census\n")
    buckets = {
        "stingers (<=3 s)": [c for c in timed if c["duration_s"] <= STINGER_MAX],
        "jingles (3-10 s)": [c for c in timed if JINGLE_RANGE[0] < c["duration_s"] <= JINGLE_RANGE[1]],
        "10-60 s": [c for c in timed if 10 < c["duration_s"] <= 60],
        "long (>60 s)": [c for c in timed if c["duration_s"] > 60],
    }
    for label, group in buckets.items():
        print(f"- {label}: {len(group)}")

    menu = sorted(
        (
            c
            for c in timed
            if c["duration_s"] >= MENU_MIN_DURATION
            and c["tempo_bpm"] is not None
            and c["tempo_bpm"] <= MENU_MAX_TEMPO
        ),
        key=lambda c: c["onset_density"] if c["onset_density"] is not None else 9,
    )
    section("Menu / title candidates", menu)

    jingles = [c for c in timed if JINGLE_RANGE[0] < c["duration_s"] <= JINGLE_RANGE[1]]
    major = sorted((j for j in jingles if j["chroma_mode"] == "major"), key=lambda c: -(c["rms_p95"] or 0))
    minor = sorted((j for j in jingles if j["chroma_mode"] == "minor"), key=lambda c: -(c["rms_p95"] or 0))
    section("Jingles — major (success / level-up class)", major)
    section("Jingles — minor (failure / night class)", minor)

    stingers = [c for c in timed if c["duration_s"] <= STINGER_MAX and c["centroid_hz"] is not None]
    clusters = {
        f"Stingers — impact (<{CENTROID_IMPACT:.0f} Hz)": [s for s in stingers if s["centroid_hz"] < CENTROID_IMPACT],
        f"Stingers — ui-foley ({CENTROID_IMPACT:.0f}-{CENTROID_SHIMMER:.0f} Hz)": [
            s for s in stingers if CENTROID_IMPACT <= s["centroid_hz"] <= CENTROID_SHIMMER
        ],
        f"Stingers — shimmer / magic (>{CENTROID_SHIMMER:.0f} Hz)": [
            s for s in stingers if s["centroid_hz"] > CENTROID_SHIMMER
        ],
    }
    for label, group in clusters.items():
        section(label, sorted(group, key=lambda c: -(c["rms_p95"] or 0)))

    beds = sorted(
        (
            c
            for c in timed
            if c["duration_s"] >= BED_MIN_DURATION
            and (c["rms_p95"] or 1) <= bed_rms_ceiling
            and (c["onset_density"] or 1) <= bed_onset_ceiling
        ),
        key=lambda c: (c["rms_p95"] or 1),
    )
    print(
        f"\n_Bed thresholds from the shipped ambience: rms <= {bed_rms_ceiling:.3f}, "
        f"onset density <= {bed_onset_ceiling:.3f}._"
    )
    section("Ambient bed candidates", beds)

    # The queue is what the ear-gate actually plays: each slot's top few, in
    # the order they were shortlisted. Menu and beds keep their own ordering
    # (quietest / least struck first); the rest lead with the loudest.
    loudest = lambda group: sorted(group, key=lambda c: -(c["rms_p95"] or 0))
    queue: list[tuple[str, dict]] = []
    seen: set[str] = set()
    for slot, group, take in (
        ("menu", menu, 3),
        ("jingle-major", loudest(major), 4),
        ("jingle-minor", loudest(minor), 4),
        ("stinger-impact", loudest(clusters[f"Stingers — impact (<{CENTROID_IMPACT:.0f} Hz)"]), 5),
        ("stinger-uifoley", loudest(clusters[f"Stingers — ui-foley ({CENTROID_IMPACT:.0f}-{CENTROID_SHIMMER:.0f} Hz)"]), 5),
        ("stinger-shimmer", loudest(clusters[f"Stingers — shimmer / magic (>{CENTROID_SHIMMER:.0f} Hz)"]), 5),
        ("bed", beds, 3),
    ):
        for r in group[:take]:
            if r["path"] not in seen:
                seen.add(r["path"])
                queue.append((slot, r))

    print(f"\n## Listening queue ({len(queue)} files)\n")
    for i, (slot, r) in enumerate(queue, 1):
        print(f"{i:2d}. [{slot}] {r['path']}")

    if args.queue:
        Path(args.queue).write_text("\n".join(r["path"] for _, r in queue) + "\n")
        print(f"\n_queue written to {args.queue}_")

    if args.stage:
        import shutil

        stage = Path(args.stage)
        stage.mkdir(parents=True, exist_ok=True)
        for i, (slot, r) in enumerate(queue, 1):
            src = Path(r["path"])
            src = src if src.is_absolute() else Path(__file__).resolve().parent.parent / src
            shutil.copy2(src, stage / f"{i:02d}_{slot}_{src.stem}{src.suffix}")
        print(f"\n_staged {len(queue)} files to {stage}_")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
