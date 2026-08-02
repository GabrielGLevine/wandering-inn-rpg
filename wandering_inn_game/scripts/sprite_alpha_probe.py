#!/usr/bin/env python3
"""Alpha/bbox probe for sprite sheets — THE anchor-measurement tool.

Why this exists (the Body_A trap, wi-art-and-sprites "THE ANCHOR RULE"):
the default anchor [0.5, 1.0] feet-anchors the FRAME BOTTOM, not the
figure's feet. A sheet with transparent padding under the subject draws
it a row high, so `interact` misses. Every new sheet's anchor must come
from a measured alpha bbox, never from a vendor README's claim — three of
five "born transparent" claims were false in the 2026-08-02 wave (they
carried flat opaque near-white canvases and their published anchors had
been measured against that opaque canvas).

Usage:
    python3 scripts/sprite_alpha_probe.py <png> [<png> ...]
    python3 scripts/sprite_alpha_probe.py --key <png>   # flood-key the
        border-connected near-white background to alpha 0, in place,
        then re-probe.

Reports per file: size, whether the image is effectively opaque
(no alpha < 8 anywhere), the true alpha bbox, the derived anchor
[cx/w, bottom/h], and the pad rows above/below the subject.
"""

from __future__ import annotations

import sys
from collections import deque

from PIL import Image

ALPHA_FLOOR = 8  # below this counts as transparent
KEY_TOL = 240  # channel value at/above which a border pixel reads as "background"


def _bbox(img: Image.Image) -> tuple[int, int, int, int] | None:
    alpha = img.getchannel("A")
    return alpha.point(lambda v: 255 if v >= ALPHA_FLOOR else 0).getbbox()


def key_background(path: str) -> None:
    """Border-connected flood fill of near-white pixels -> alpha 0."""
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    px = img.load()
    seen = bytearray(w * h)
    q: deque[tuple[int, int]] = deque()

    def bg(x: int, y: int) -> bool:
        r, g, b, a = px[x, y]
        return a > 0 and r >= KEY_TOL and g >= KEY_TOL and b >= KEY_TOL

    for x in range(w):
        for y in (0, h - 1):
            if not seen[y * w + x] and bg(x, y):
                seen[y * w + x] = 1
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if not seen[y * w + x] and bg(x, y):
                seen[y * w + x] = 1
                q.append((x, y))

    while q:
        x, y = q.popleft()
        px[x, y] = (0, 0, 0, 0)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and bg(nx, ny):
                seen[ny * w + nx] = 1
                q.append((nx, ny))
    img.save(path)


def probe(path: str) -> None:
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    alpha = img.getchannel("A")
    lo, _hi = alpha.getextrema()
    opaque = lo >= ALPHA_FLOOR
    box = _bbox(img)
    if box is None:
        print(f"{path}: {w}x{h} — EMPTY (fully transparent)")
        return
    x0, y0, x1, y1 = box
    cx = (x0 + x1) / 2.0
    print(
        f"{path}: {w}x{h} "
        f"{'OPAQUE-CANVAS(!)' if opaque else 'has-alpha'} "
        f"bbox=({x0},{y0},{x1},{y1}) "
        f"anchor=[{cx / w:.4f},{y1 / h:.4f}] "
        f"pad_top={y0} pad_bottom={h - y1}"
    )


def main(argv: list[str]) -> int:
    args = list(argv[1:])
    do_key = False
    if args and args[0] == "--key":
        do_key = True
        args = args[1:]
    if not args:
        print(__doc__)
        return 2
    for path in args:
        if do_key:
            key_background(path)
        probe(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
