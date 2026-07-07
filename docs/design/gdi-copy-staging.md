# GDI copy staging — opener rewrite + epilogue de-cheese

User rulings 2026-07-07 (HANDOFF RESOLVED items 10/11): M-ARC climax copy
APPROVED as shipped; the GDI epilogue framing reads cheesy — rewrite; the
opener drops its race branches for ONE strong opener leaning the
"Class: none. Skills: none." system-readout vibe.

Night task 6b assembles this into `src/ui/sleep_veil.gd`. Line COUNTS are
pin-relevant: opener stays 4 lines (char_creation pins lines:4 — the
payload's `race` key may remain; the copy converges), epilogue framing
stays 2 open + 2 close (arc_flow pins lines:7 with the near_act3 fixture's
2 class lines).

## Opener (replaces OPENER_LINES_HUMAN/DRAKE/GNOLL with ONE const;
## `_opener_lines()` loses its race match — keep the function, return the
## single const, so call sites don't change)

```
[Class: none.]
[Skills: none.]
This world watches what you do.
[Begin.]
```

Rationale: cold-open on the readout the user named; the one prose line
cut to its first clause per the user's edit 2026-07-07 (the em-dash
continuation read as an AI tell — the bare statement is stronger and the
class recount at the epilogue pays it off anyway). Race-neutral by
construction. USER-APPROVED as written — apply verbatim, no further
taste flag on the opener.

## Epilogue framing (class-recount mechanism UNCHANGED — it is the good
## part; only the const pairs change)

EPILOGUE_LINES_OPEN:
```
[When you came to Liscor, there was nothing to record.]
[This is no longer true.]
```

EPILOGUE_LINES_CLOSE:
```
[The warren is sealed.]
[The record remains open.]
```

EPILOGUE_LINK_LINE: unchanged ("— The story continues at wanderinginn.com —").

Rationale: the old framing announced its sentiment ("Now Liscor knows your
name", "The world keeps counting") — aphorism is the cheese. The rewrite is
ledger-voiced understatement: the system states facts and lets the class
recount carry the weight; "[The record remains open.]" does the
post-game-continues work without a wink.

## Assembly notes
- Grep every quoted line above and every OLD line before swapping — the
  opener's old lines are pinned in char_creation.json (drake branch copy)
  and possibly title/tutorial flows; the epilogue's old lines may be pinned
  in arc_flow.json. Re-pin to the new text in the same edit.
- `_opener_lines()`'s race match is deleted; OPENER_LINES_DRAKE/GNOLL
  consts deleted; the `race` key in UI_GDI_OPENER_RENDERED's payload may
  stay (harmless) or drop (then re-pin char_creation's payload_contains).
- Voice-lint self-check run on all 8 new lines: no banned tells, no
  triads, no over-named emotion. The epilogue rewrite is USER-APPROVED as
  written (2026-07-07) — apply verbatim; no open taste flag remains on
  this doc.
