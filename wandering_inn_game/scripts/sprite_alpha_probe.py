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
[cx/w, bottom/h], the pad rows above/below the subject, and — added
after this tool watched a rug ship with a hole in it — the sheet's
INTERIOR HOLES.

WHY HOLES ARE A SEPARATE NUMBER (v0.17 L4 fix wave). `rug_woven_cream`
passed every check above: it had alpha, its bbox was full-frame, its
anchor was right. Its entire FIELD was alpha 0 — border ring, fringe and
motif islands over nothing — so at five sites the rug rendered as a hole
in the floorboards, which is the exact defect its VISUAL-LOG rows had
just been checked off for. A 64x64 thumbnail at 1x hides that
completely; a generator's own background keying is what usually causes
it. So: `holes` counts transparent pixels INSIDE the bbox that a flood
fill from the frame edge cannot reach — real enclosed gaps, not the
space between a bench's legs. A flat prop meant to read as a solid
surface (rug, tray, table, banner) should be near 0%. Anything above a
few percent on such a prop is the sheet telling you it is a lattice.

Read it, do not gate blindly on it. It counts a deliberate inset RING
the same as a keyed-out field: `rug_woven_red` scores 13.4% purely
because a 2px transparent margin separates its outer border line from
its weave, and at render_scale 0.35 that margin lands sub-pixel and
reads as part of the border (verified windowed in
qa_output/adventurers_rest_loop/02_the_common_hall.png). The number
tells you where to look; the windowed shot tells you whether it matters.
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


def interior_holes(img: Image.Image, box: tuple[int, int, int, int]) -> int:
    """Transparent pixels inside the bbox that the FRAME EDGE cannot reach.

    The flood from the border is what makes this mean something: the gap
    between a bench's legs is transparent AND border-connected, so it is
    silhouette, not damage. A rug whose weave was keyed out is enclosed
    by its own border ring, so it is unreachable — and it is a hole.
    """
    w, h = img.size
    px = img.load()
    outside = bytearray(w * h)
    q: deque[tuple[int, int]] = deque()
    for x in range(w):
        for y in (0, h - 1):
            if not outside[y * w + x] and px[x, y][3] < ALPHA_FLOOR:
                outside[y * w + x] = 1
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if not outside[y * w + x] and px[x, y][3] < ALPHA_FLOOR:
                outside[y * w + x] = 1
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if (0 <= nx < w and 0 <= ny < h and not outside[ny * w + nx]
                    and px[nx, ny][3] < ALPHA_FLOOR):
                outside[ny * w + nx] = 1
                q.append((nx, ny))
    x0, y0, x1, y1 = box
    return sum(1 for y in range(y0, y1) for x in range(x0, x1)
               if px[x, y][3] < ALPHA_FLOOR and not outside[y * w + x])


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
    area = max(1, (x1 - x0) * (y1 - y0))
    holes = interior_holes(img, box)
    print(
        f"{path}: {w}x{h} "
        f"{'OPAQUE-CANVAS(!)' if opaque else 'has-alpha'} "
        f"bbox=({x0},{y0},{x1},{y1}) "
        f"anchor=[{cx / w:.4f},{y1 / h:.4f}] "
        f"pad_top={y0} pad_bottom={h - y1} "
        f"holes={holes}/{area} ({100.0 * holes / area:.1f}% of bbox)"
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
