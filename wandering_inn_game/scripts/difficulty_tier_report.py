#!/usr/bin/env python3
"""GH#360 (a) -- the cross-tier arithmetic for difficulty_tier_sweep.sh.

Split out of the sweep script on purpose: the four godot legs cost ~2 minutes,
the analysis costs nothing, and every gate proposal below will want re-reading
against the SAME saved legs rather than a fresh (and differently-seeded-looking)
sweep. Run it standalone with:

    scripts/difficulty_tier_report.py qa_output/difficulty_tier_sweep

Reads {plain,bronze,silver,gold}.txt as written by the sweep script. Exit 1 only
on the ONE thing this sweep asserts -- that an explicit x1.0 leg is byte
identical to a plain, env-unset run (wi_combat.gd's standing "Silver IS the
shipped balance" promise, and precisely what the WI_DIFFICULTY_MULT hook could
silently break). Everything else is report-only until #360's gates are ratified.
"""

import argparse
import pathlib
import re
import sys

# Every cell line ends in the same tail; the leading bracketed "[family / name]"
# is the identity the four legs share. "(measured)" marks an ungated cell.
LINE = re.compile(r"^\[(?P<id>[^\]]+)\](?P<mid>.*?)win_rate=(?P<wr>[0-9.]+) median_rounds=(?P<md>\d+)")
FAIL = re.compile(r"^FAIL \[(?P<id>[^\]]+)\]: win rate (?P<wr>[0-9.]+) outside band (?P<lo>[0-9.]+)-(?P<hi>[0-9.]+)")

# 100 runs per cell puts sigma at ~0.05 around p=0.5, so a monotonicity report
# only fires past one sigma. Same discipline the ladder's own LADDER_TIE uses.
NOISE = 0.05
# A cell already sitting within this much of an extreme at Silver is SATURATED,
# not flipped -- 0.98 -> 1.00 at Bronze is arithmetic, not a design failure. The
# #360 expectation ("no 0%/100% flips at Bronze/Gold") is about cells that carry
# a real coin at Silver and lose it at a tier.
EXTREME_MARGIN = 0.10


def read_leg(outdir, leg):
    rows, order, gated = {}, [], {}
    fails = {}
    for line in (outdir / f"{leg}.txt").read_text().splitlines():
        m = FAIL.match(line)
        if m:
            fails[m.group("id").strip()] = (float(m.group("wr")), float(m.group("lo")), float(m.group("hi")))
            continue
        m = LINE.match(line)
        if not m:
            continue
        cid = m.group("id").strip()
        if cid == "ladder":
            continue
        rows[cid] = (float(m.group("wr")), int(m.group("md")))
        gated[cid] = "(measured)" not in m.group("mid")
        order.append(cid)
    return rows, order, gated, fails


def mean(vals):
    return sum(vals) / len(vals) if vals else 0.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("legs_dir")
    ap.add_argument("--note", default="")
    args = ap.parse_args()
    outdir = pathlib.Path(args.legs_dir)

    plain, order, gated, _ = read_leg(outdir, "plain")
    bronze, _, _, bronze_fails = read_leg(outdir, "bronze")
    silver, _, _, _ = read_leg(outdir, "silver")
    gold, _, _, gold_fails = read_leg(outdir, "gold")

    print()
    print("=" * 78)
    print("GH#360 (a) DIFFICULTY-TIER SWEEP -- Bronze x0.75 / Silver x1.0 / Gold x1.3")
    if args.note:
        print(args.note)
    print("=" * 78)

    # --- THE ONE ASSERTION -------------------------------------------------
    drift = [c for c in order if plain.get(c) != silver.get(c)]
    if drift:
        print("FAIL inert-at-Silver: the x1.0 leg diverged from a plain run on %d cell(s):" % len(drift))
        for c in drift[:20]:
            print("   %-52s plain=%s  x1.0=%s" % (c, plain.get(c), silver.get(c)))
        return 1
    print("PASS inert-at-Silver: all %d cells identical between a plain run and the explicit x1.0 leg"
          % len(order))
    n_gated = sum(1 for c in order if gated[c])
    print("       %d cells, %d gated / %d measured" % (len(order), n_gated, len(order) - n_gated))
    print()

    # --- pooled ------------------------------------------------------------
    print("POOLED WIN RATE           bronze %.4f   silver %.4f   gold %.4f" % (
        mean([bronze[c][0] for c in order]),
        mean([silver[c][0] for c in order]),
        mean([gold[c][0] for c in order])))
    print("POOLED DELTA vs Silver    bronze %+.4f              gold %+.4f" % (
        mean([bronze[c][0] - silver[c][0] for c in order]),
        mean([gold[c][0] - silver[c][0] for c in order])))
    mid = [c for c in order if 0.10 <= silver[c][0] <= 0.90]
    print("POOLED DELTA, unsaturated cells only (silver 0.10-0.90, n=%d)" % len(mid))
    print("                          bronze %+.4f              gold %+.4f" % (
        mean([bronze[c][0] - silver[c][0] for c in mid]),
        mean([gold[c][0] - silver[c][0] for c in mid])))
    print()

    # --- monotonicity ------------------------------------------------------
    viol = [(c, bronze[c][0], silver[c][0], gold[c][0]) for c in order
            if silver[c][0] - bronze[c][0] > NOISE or gold[c][0] - silver[c][0] > NOISE]
    print("MONOTONICITY (expect bronze >= silver >= gold; tolerance %.2f = ~1 sigma at 100 runs)" % NOISE)
    if not viol:
        print("   CLEAN: 0 of %d cells invert beyond tolerance" % len(order))
    else:
        print("   %d of %d cells invert beyond tolerance:" % (len(viol), len(order)))
        for c, b, s, g in viol:
            print("   %-52s bronze %.2f  silver %.2f  gold %.2f" % (c, b, s, g))
    print()

    # --- material extreme flips -------------------------------------------
    material, saturated = [], 0
    for c in order:
        b, s, g = bronze[c][0], silver[c][0], gold[c][0]
        for tier, v in (("bronze", b), ("gold", g)):
            if v not in (0.0, 1.0):
                continue
            if abs(s - v) <= EXTREME_MARGIN:
                saturated += 1
            else:
                material.append((c, tier, v, s, gated[c]))
    print("EXTREME FLIPS -- a cell reaching 0.00/1.00 at a tier where Silver carried a real coin")
    print("   (a Silver value already within %.2f of the extreme is SATURATION, counted separately)" % EXTREME_MARGIN)
    if not material:
        print("   CLEAN: 0 material flips; %d saturation touches" % saturated)
    else:
        print("   %d material flip(s), %d saturation touches:" % (len(material), saturated))
        for c, tier, v, s, g in material:
            print("   %-52s %-6s %.2f (silver %.2f)%s" % (c, tier, v, s, "  [GATED]" if g else ""))
    print()

    # --- gated cells leaving their Silver band ----------------------------
    for tier, fails in (("BRONZE", bronze_fails), ("GOLD", gold_fails)):
        print("GATED CELLS OUTSIDE THEIR SILVER BAND AT %s (%d of %d gated)"
              % (tier, len(fails), n_gated))
        for c, (wr, lo, hi) in sorted(fails.items(), key=lambda kv: kv[0]):
            edge = "below floor by %.2f" % (lo - wr) if wr < lo else "above ceiling by %.2f" % (wr - hi)
            print("   %-52s %.2f  band %.2f-%.2f  (%s)" % (c, wr, lo, hi, edge))
        print()

    # --- biggest movers ----------------------------------------------------
    for tier, rows in (("BRONZE", bronze), ("GOLD", gold)):
        deltas = sorted(((rows[c][0] - silver[c][0], c) for c in order), key=lambda t: -abs(t[0]))
        print("LARGEST %s DELTAS vs Silver (top 12)" % tier)
        for d, c in deltas[:12]:
            print("   %+.2f  %-52s  silver %.2f -> %.2f" % (d, c, silver[c][0], rows[c][0]))
        print()

    print("PER-CELL TABLE  bronze / silver / gold, [median rounds]; * = gated")
    for c in order:
        b, s, g = bronze[c], silver[c], gold[c]
        print("   %s %-54s %.2f[%d]  %.2f[%d]  %.2f[%d]"
              % ("*" if gated[c] else " ", c, b[0], b[1], s[0], s[1], g[0], g[1]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
