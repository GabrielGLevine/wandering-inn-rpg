# Itinerary compiler (M1)

Compile the fixture-free Act I spine from the repository root:

```sh
python3 scripts/itinerary/compile_itinerary.py scripts/itinerary/act1.yaml \
  --out scripts/itinerary/generated/act1.json
```

M1 accepts `goto`, `talk`, and `sleep`. Every node needs a stable `id`; every
dialogue fork needs `why`. The compiler asks `qa/oracle.gd` for paths, visible
dialogue rows, and progression outcomes, then emits driver steps stamped with
`_itin`. Generated JSON is disposable and must never be hand-edited.

RNG is one global stream. Adding or removing a draw-consuming itinerary step
reshuffles every later fight, so an itinerary is recompiled and re-verified
wholesale. Pins are never patched around a changed RNG epoch.

