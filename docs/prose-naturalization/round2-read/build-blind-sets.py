#!/usr/bin/env python3
"""build-blind-sets.py -- GH#397 round 2, Task 4 instrument.

Builds the round-2 blind-read packet from the LIVE tree. Run it only once the
corpus is final (after the cadence rebalance and the mop-up), because it reads
current text off disk.

WHAT IS DIFFERENT FROM PHASE 5, AND WHY

1. ONE SHUFFLED FILE, NO SETS. Phase 5 shipped three files (A/B/C) and C's
   generated header leaked its holdout role to both readers, which forced the
   controller to discount C-role reasoning after the fact. Here every row --
   revised and control alike -- lands in a single shuffled list with identical
   formatting. There is no set boundary to infer, so there is no role to leak.
   The revised/control split exists only in the key file, which the readers
   never see.

2. SAME SAMPLED ROWS AS PHASE 5. The revised rows are exactly the 120 map ids
   in sample-key.json's `maps` block -- the same strings reader 1 scored at a
   52 midpoint. Re-rendering those same rows over round-2 text makes the two
   reads directly comparable row by row, instead of comparing two different
   samples of one corpus.

3. LIKE-FOR-LIKE CONTROL. The control is drawn from holdout.json's map ids
   (116 available, all ten regions), which no pass has ever touched. The
   exclusion list is honoured: the three excluded ids moved for reasons
   outside this pass and are not controls.

The bar this packet has to answer (plan Task 4): revised midpoint <= 45 on the
reader's own scale AND >= 10 points below that same reader's control midpoint,
with neither reader naming a surviving template family. The control is what
makes the second leg meaningful -- Phase 5 established that these readers score
untouched prose near 53, so a raw number alone says very little.
"""

import json
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
DOCS = ROOT / "docs" / "prose-naturalization"
OUT = DOCS / "round2-read"
SHUFFLE_SEED = 3970202  # recorded, not arbitrary: issue 397, round 2, take 2


def live_text(file_rel, field_path):
    data = json.loads((ROOT / file_rel).read_text())
    node = data
    for part in field_path.lstrip("$.").replace("]", "").split("."):
        if "[" in part:
            name, idx = part.split("[")
            if name:
                node = node[name]
            node = node[int(idx)]
        else:
            node = node[part]
    return node


def id_to_file(sid):
    # map:<region>/<file>.json:$.<path>
    rest = sid[len("map:"):]
    rel, field_path = rest.split(":", 1)
    return f"wandering_inn_game/data/maps/{rel}", field_path


def main():
    key = json.loads((DOCS / "sample-key.json").read_text())["maps"]
    hold = json.loads((DOCS / "holdout.json").read_text())
    excluded = set(hold.get("excluded", {}))
    control_ids = [i for i in hold["ids"]
                   if i.startswith("map:") and i not in excluded]

    rows = []
    for n in sorted(key, key=int):
        sid = key[n]
        f, p = id_to_file(sid)
        rows.append({"id": sid, "role": "revised", "phase5_row": int(n),
                     "text": live_text(f, p)})
    for sid in control_ids:
        f, p = id_to_file(sid)
        rows.append({"id": sid, "role": "control", "phase5_row": None,
                     "text": live_text(f, p)})

    random.Random(SHUFFLE_SEED).shuffle(rows)

    body = [
        "MAP PROSE SAMPLE",
        "",
        f"{len(rows)} strings of environmental/object prose from a game, one per",
        "numbered line, in no particular order. Score each per the rubric you",
        "were given. Whitespace is normalised to one line; nothing else is",
        "changed.",
        "",
    ]
    for i, r in enumerate(rows, 1):
        body.append(f"{i:3}. {' '.join(r['text'].split())}")
        body.append("")

    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "blind-sample.txt").write_text("\n".join(body))
    keyout = {
        "_note": ("Round-2 blind read key. Readers never see this. `role` is "
                  "the only thing that distinguishes a revised row from an "
                  "untouched control row; the sample file itself is a single "
                  "shuffled list with no set boundary."),
        "_shuffle_seed": SHUFFLE_SEED,
        "_counts": {"revised": sum(1 for r in rows if r["role"] == "revised"),
                    "control": sum(1 for r in rows if r["role"] == "control")},
        "rows": {str(i): {"id": r["id"], "role": r["role"],
                          "phase5_row": r["phase5_row"]}
                 for i, r in enumerate(rows, 1)},
    }
    (OUT / "blind-key.json").write_text(json.dumps(keyout, indent=1) + "\n")
    print(f"wrote {OUT/'blind-sample.txt'}: {len(rows)} rows "
          f"({keyout['_counts']['revised']} revised / "
          f"{keyout['_counts']['control']} control), seed {SHUFFLE_SEED}")


if __name__ == "__main__":
    sys.exit(main())
