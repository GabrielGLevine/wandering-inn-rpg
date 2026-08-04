#!/usr/bin/env python3
"""Signal-profile audio candidates against the shipped anchors (the #147 method).

Emits one row per file: duration, tempo, RMS p95, spectral centroid, onset
density, chroma mode, and the composite energy score used to rank candidates
for a slot. Candidate scores are only meaningful next to the anchors, so the
shipped library is profiled in the same run.

    python3 scripts/audio_profile.py \
        --candidates potential_assets/EssentialGameAudiopackFixed \
        --out docs/design/audio-profiles.csv

Metrics (all at 22.05 kHz mono, so anchors and candidates are measured alike):
  tempo_bpm      librosa tempo estimate off the onset envelope
  rms_p95        95th-percentile frame RMS — how loud the track actually sits
  centroid_hz    mean spectral centroid — bright vs muddy
  onset_density  mean onset strength / its own p99 — how continuously struck
  onsets_per_sec detected onsets per second, the normalization-free companion
  chroma_mode    major/minor by Krumhansl-Schmuckler correlation
  energy         0.5*rms_p95 + 0.3*onset_density + 0.2*(tempo/200)

Requires librosa (and ffmpeg on PATH for mp3 decoding).

Written for issue #195; the numbers behind docs/design/2026-07-19-b9-audio-selection.md
came from an uncommitted version of this pass, which made them unreproducible.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

AUDIO_SUFFIXES = {".ogg", ".mp3", ".wav"}

# Default anchor set: everything the game currently ships as music or ambience.
DEFAULT_ANCHORS = [
    "wandering_inn_game/assets/audio/music",
    "wandering_inn_game/assets/audio/ambience",
]

SAMPLE_RATE = 22050

# Krumhansl-Schmuckler key profiles, used only for the major/minor call.
MAJOR_PROFILE = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
MINOR_PROFILE = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]

PITCH_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

# Energy score weights. RMS dominates because loudness is what makes a track
# read as "driving" in play; tempo is divided by 200 BPM to land in 0..1.
W_RMS, W_ONSET, W_TEMPO = 0.5, 0.3, 0.2
TEMPO_NORM = 200.0

FIELDS = [
    "role",
    "category",
    "name",
    "path",
    "duration_s",
    "tempo_bpm",
    "rms_p95",
    "centroid_hz",
    "onset_density",
    "onsets_per_sec",
    "chroma_mode",
    "chroma_key",
    "energy",
]


def _correlate(profile: list[float], chroma: list[float]) -> float:
    n = len(profile)
    mp = sum(profile) / n
    mc = sum(chroma) / n
    num = sum((profile[i] - mp) * (chroma[i] - mc) for i in range(n))
    den = math.sqrt(sum((profile[i] - mp) ** 2 for i in range(n))) * math.sqrt(
        sum((chroma[i] - mc) ** 2 for i in range(n))
    )
    return num / den if den else 0.0


def estimate_mode(chroma_mean) -> tuple[str, str]:
    """Best (mode, key) by rotating both KS profiles over the chroma vector."""
    chroma = [float(v) for v in chroma_mean]
    best = ("major", "C", -2.0)
    for tonic in range(12):
        rotated = chroma[tonic:] + chroma[:tonic]
        for mode, profile in (("major", MAJOR_PROFILE), ("minor", MINOR_PROFILE)):
            score = _correlate(profile, rotated)
            if score > best[2]:
                best = (mode, PITCH_NAMES[tonic], score)
    return best[0], best[1]


def profile_file(path: Path, role: str, category: str) -> dict:
    import librosa
    import numpy as np

    y, sr = librosa.load(str(path), sr=SAMPLE_RATE, mono=True)
    duration = float(len(y)) / sr if len(y) else 0.0

    if duration < 0.05 or not np.any(y):
        # Too short (or silent) for tempo/onset to mean anything; report what we can.
        return {
            "role": role,
            "category": category,
            "name": path.stem,
            "path": str(path.relative_to(REPO_ROOT)),
            "duration_s": round(duration, 3),
            "tempo_bpm": "",
            "rms_p95": 0.0,
            "centroid_hz": "",
            "onset_density": "",
            "onsets_per_sec": "",
            "chroma_mode": "",
            "chroma_key": "",
            "energy": "",
        }

    rms = librosa.feature.rms(y=y)[0]
    rms_p95 = float(np.percentile(rms, 95))

    centroid = float(np.mean(librosa.feature.spectral_centroid(y=y, sr=sr)[0]))

    onset_env = librosa.onset.onset_strength(y=y, sr=sr)
    # How continuously the track is being struck: mean onset strength against
    # its own loud-hit level. p99 rather than max, so one stray transient in a
    # four-minute score does not crush the whole track's reading.
    loud = float(np.percentile(onset_env, 99)) if onset_env.size else 0.0
    onset_density = float(np.mean(onset_env) / loud) if loud > 0 else 0.0
    onsets = librosa.onset.onset_detect(onset_envelope=onset_env, sr=sr)
    onsets_per_sec = len(onsets) / duration if duration else 0.0

    tempo_raw = librosa.feature.tempo(onset_envelope=onset_env, sr=sr)
    tempo = float(tempo_raw[0]) if len(tempo_raw) else 0.0

    chroma = librosa.feature.chroma_stft(y=y, sr=sr)
    mode, key = estimate_mode(np.mean(chroma, axis=1))

    energy = W_RMS * rms_p95 + W_ONSET * onset_density + W_TEMPO * (tempo / TEMPO_NORM)

    return {
        "role": role,
        "category": category,
        "name": path.stem,
        "path": str(path.relative_to(REPO_ROOT)),
        "duration_s": round(duration, 3),
        "tempo_bpm": round(tempo, 1),
        "rms_p95": round(rms_p95, 4),
        "centroid_hz": round(centroid, 1),
        "onset_density": round(onset_density, 4),
        "onsets_per_sec": round(onsets_per_sec, 3),
        "chroma_mode": mode,
        "chroma_key": key,
        "energy": round(energy, 4),
    }


def collect(root: Path) -> list[Path]:
    if root.is_file():
        return [root]
    return sorted(
        p
        for p in root.rglob("*")
        if p.is_file() and p.suffix.lower() in AUDIO_SUFFIXES and not p.name.startswith("._")
    )


def category_for(path: Path, root: Path) -> str:
    """Category = the candidate's directory path under its root, so pack
    structure (Loops / FullScores / AbstractSfx) survives into the report."""
    rel = path.relative_to(root).parent
    return str(rel) if str(rel) != "." else root.name


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument(
        "--candidates",
        action="append",
        default=[],
        help="file or directory of candidate audio (repeatable)",
    )
    ap.add_argument(
        "--anchors",
        action="append",
        default=[],
        help="file or directory of shipped anchors (repeatable; defaults to the shipped library)",
    )
    ap.add_argument("--out", required=True, help="CSV output path")
    ap.add_argument("--json", action="store_true", help="also write a .json sibling of the CSV")
    args = ap.parse_args()

    try:
        import librosa  # noqa: F401
    except ImportError:
        print("librosa is required: pip install librosa", file=sys.stderr)
        return 2

    anchor_roots = [Path(a) for a in (args.anchors or DEFAULT_ANCHORS)]
    candidate_roots = [Path(c) for c in args.candidates]

    jobs: list[tuple[Path, str, str]] = []
    for role, roots in (("anchor", anchor_roots), ("candidate", candidate_roots)):
        for root in roots:
            root = root if root.is_absolute() else REPO_ROOT / root
            if not root.exists():
                print(f"missing {role} root: {root}", file=sys.stderr)
                return 2
            for path in collect(root):
                jobs.append((path, role, category_for(path, root)))

    if not jobs:
        print("no audio files found", file=sys.stderr)
        return 2

    rows = []
    for i, (path, role, category) in enumerate(jobs, 1):
        print(f"[{i}/{len(jobs)}] {role}: {path.name}", file=sys.stderr)
        try:
            rows.append(profile_file(path, role, category))
        except Exception as exc:  # a single undecodable file must not sink the run
            print(f"  FAILED: {exc}", file=sys.stderr)

    out = Path(args.out)
    out = out if out.is_absolute() else REPO_ROOT / out
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    if args.json:
        out.with_suffix(".json").write_text(json.dumps(rows, indent=1) + "\n")

    print(f"\nprofiled {len(rows)}/{len(jobs)} files -> {out}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
