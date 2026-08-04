#!/usr/bin/env python3
"""GH#360 (a) -- the cross-tier arithmetic for difficulty_tier_sweep.sh.

Split out of the sweep script on purpose: the four godot legs cost ~2 minutes,
the analysis costs nothing, and every gate proposal below will want re-reading
against the SAME saved legs rather than a fresh (and differently-seeded-looking)
sweep. Run it standalone with:

    scripts/difficulty_tier_report.py qa_output/difficulty_tier_sweep

Reads {plain,bronze,silver,gold}.txt as written by the sweep script.

THREE things fail this report now (#384 item 1 ratified two of them 2026-08-04):

  1. INERT-AT-SILVER -- an explicit x1.0 leg must be byte identical to a plain,
     env-unset run. wi_combat.gd's standing "Silver IS the shipped balance"
     promise, and precisely what the WI_DIFFICULTY_MULT hook could silently
     break. Never was report-only.
  2. MONOTONICITY -- bronze >= silver >= gold per cell, within NOISE. RATIFIED
     off a clean 0/141 read (CHOICE-LOG v018-close #5 called it ready).
  3. EXTREME FLIPS -- no cell may reach 0.00/1.00 at a tier where Silver carried
     a real coin, EXCEPT the named entries in EXTREME_FLIP_WHITELIST, each of
     which carries the justification that earned it. Anything not on that list
     reds, which is the whole point of a named list over a loosened threshold.

`--report-only` restores the pre-ratification behaviour (prints everything,
fails on nothing but 1) -- for exploring a candidate tune without a red.
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
# DO NOT WIDEN THIS TO SILENCE A FLIP. Widening is tuning the gate for the gate's
# benefit; the whitelist below is the sanctioned way to accept one, because it
# costs a written justification and leaves the next flip red.
EXTREME_MARGIN = 0.10

# RATIFIED 2026-08-04 (#384 item 1). NAMED exceptions, keyed by (cell id exactly
# as this report prints it, tier) so a rename fails CLOSED -- the entry goes
# stale, the flip stops being whitelisted, and the gate reds.
EXTREME_FLIP_WHITELIST = {
    ("invrisil / alley_fence_t3_warrior10_solo", "bronze"):
        "Bronze exists to make fights easier. An 0.81-Silver social-region fence "
        "fight saturating at the easiest tier is the knob working as intended, "
        "not a regression, and re-tuning the cell to preserve a sub-1.00 Bronze "
        "would be tuning data for the gate's benefit -- backwards. Gold still "
        "carries a real coin on the same cell (0.36), so it is not flat.",
    ("ruin / ruin_guardian_w8_solo", "gold"):
        "The mirror case at the other rail. NOT in the #384 ruling's premise, "
        "which named one flip -- this read found two, both pre-existing at HEAD "
        "(sim_combat_batch reads none of this lane's files). 0.13 Silver on an "
        "UNGATED cell -- the deliberately-losing SOLO read of a boss the region "
        "fields Relc for -- reaching 0.00 at the hardest tier is the same knob "
        "working. A cell sitting 0.13 off the floor was never carrying a coin "
        "the way an 0.81 cell is. Revocable: the alternative is a gate that is "
        "red on the day it ratifies.",
}


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


def _wrap(text, width):
    line, out = "", []
    for word in text.split():
        if line and len(line) + 1 + len(word) > width:
            out.append(line)
            line = word
        else:
            line = word if not line else line + " " + word
    if line:
        out.append(line)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("legs_dir")
    ap.add_argument("--note", default="")
    ap.add_argument("--report-only", action="store_true",
                    help="print everything, fail on nothing but inert-at-Silver "
                         "(the pre-#384 behaviour; for exploring a tune)")
    args = ap.parse_args()
    outdir = pathlib.Path(args.legs_dir)
    gate = not args.report_only
    failures = []

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
    print("MONOTONICITY (RATIFIED GATE, #384 item 1 -- expect bronze >= silver >= gold;")
    print("              tolerance %.2f = ~1 sigma at 100 runs)" % NOISE)
    if not viol:
        print("   CLEAN: 0 of %d cells invert beyond tolerance" % len(order))
    else:
        print("   %d of %d cells invert beyond tolerance:" % (len(viol), len(order)))
        for c, b, s, g in viol:
            print("   %-52s bronze %.2f  silver %.2f  gold %.2f" % (c, b, s, g))
        failures.append("monotonicity: %d cell(s) invert beyond %.2f" % (len(viol), NOISE))
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
    print("EXTREME FLIPS (RATIFIED GATE, #384 item 1) -- a cell reaching 0.00/1.00 at a tier")
    print("   where Silver carried a real coin (a Silver value already within %.2f of the" % EXTREME_MARGIN)
    print("   extreme is SATURATION, counted separately and never gated)")
    unlisted = []
    fired = set()
    if not material:
        print("   CLEAN: 0 material flips; %d saturation touches" % saturated)
    else:
        print("   %d material flip(s), %d saturation touches:" % (len(material), saturated))
        for c, tier, v, s, g in material:
            key = (c, tier)
            listed = key in EXTREME_FLIP_WHITELIST
            if listed:
                fired.add(key)
            else:
                unlisted.append((c, tier, v, s, g))
            print("   %-52s %-6s %.2f (silver %.2f)%s%s"
                  % (c, tier, v, s, "  [GATED]" if g else "", "  [WHITELISTED]" if listed else "  <-- NOT WHITELISTED"))
    for key, why in sorted(EXTREME_FLIP_WHITELIST.items()):
        print()
        print("   WHITELISTED %s @ %s%s" % (key[0], key[1], "" if key in fired else "   [STALE -- no longer flips]"))
        for chunk in _wrap(why, 70):
            print("      %s" % chunk)
    if unlisted:
        print()
        print("   %d flip(s) are NOT on the whitelist. Either the difficulty knob broke a" % len(unlisted))
        print("   fight's shape, or the flip is defensible and owes a written justification")
        print("   in EXTREME_FLIP_WHITELIST. Widening EXTREME_MARGIN is not the third option.")
        failures.append("extreme-flip: %d unwhitelisted flip(s)" % len(unlisted))
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

    print()
    print("=" * 78)
    if not gate:
        print("REPORT-ONLY (--report-only): the ratified gates above printed but did not fail.")
        if failures:
            print("They WOULD have failed on: %s" % "; ".join(failures))
        return 0
    if failures:
        print("FAIL: %s" % "; ".join(failures))
        return 1
    print("PASS: inert-at-Silver + monotonicity + extreme-flip (whitelist honoured)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
