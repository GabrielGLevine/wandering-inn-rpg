# Machine-Driven Playtest Protocol

How an agent plays the game with player eyes, as opposed to running the QA sweep.
The sweep proves the logic; a playtest judges what a player actually sees and reads.
A green `QA_RESULT: PASS` is the entry ticket, not the finding — **the screenshots
are the product**. Consultant-validated 2026-07-07 (found the boulder sheet-label
artifact, the toast third-line fold clipping, and the street readability gap this way;
all invisible to headless asserts).

## When to run (loop integration)

- After any wave that touched a player-facing surface (sprites, panels, copy,
  maps, mood/lighting) — before claiming the wave done.
- At every milestone close, full rotation.
- Budget ~15–20 min for a 6–8 script pass. Rotate the subset run-to-run, but
  ALWAYS include: one dark map, one panel-heavy script, one script covering the
  newest feature.

## Step 1 — Isolation decision

If the working tree is dirty or another session is mid-refactor, playtest a
known-good commit in a detached worktree — never trust a mid-surgery tree
(observed failure: `dialogue_panel.gd` nil spam from a half-applied refactor
masquerading as a game bug):

```bash
git worktree add --detach /tmp/wi-playtest HEAD
/usr/local/bin/godot --headless --path /tmp/wi-playtest/wandering_inn_game --import   # REQUIRED in a fresh worktree
/tmp/wi-playtest/wandering_inn_game/qa/run_qa.sh load_gate headless                   # sanity gate
# ... playtest runs ...
git worktree remove /tmp/wi-playtest   # when done
```

Clean tree → run in place, skip this.

## Step 2 — Pick scripts (must have screenshot steps)

Not every canonical script screenshots (`combat_walkthrough` is shotless by
design). Check: `grep -l screenshot qa/scripts/*.json`. Proven coverage matrix:

| Surface | Script |
|---|---|
| Cold-start onboarding | `tutorial_flow` --seed=9 |
| Character creation UI | `char_creation` |
| Street/exploration | `gate_district_walkthrough` --seed=9 |
| Mood / day-dusk cycle | `atmosphere_check` --seed=9 |
| Inventory/gear panels | `gear_loop` --seed=9 |
| Social + journal | `social_loop` --seed=9 |
| Dark map + dark combat | `sewers_walkthrough` --seed=9 |
| Combat feed/status/readout | `status_first_encounter` --seed=9 |
| Whole arc + boss + epilogue | `arc_flow` --seed=9 |

```bash
qa/run_qa.sh <script> windowed --seed=<seed>
```

Treat a missing `result.json` or any `SCRIPT ERROR` line as a crash finding,
not a flaky run.

## Step 3 — READ every screenshot as a first-time player

Open each PNG in `qa_output/<script>/` with the Read tool and actually look.
Checklist (each item has caught a real shipped issue):

- **Text clipping**: does any line ride a parchment fold or panel edge?
  Check toasts (3rd wrapped line), tutor panel, dialogue pages, item cards.
- **Baked sheet artifacts**: any floating garbled text or off-theme pixels?
  (The boulder region included the sheet's "PALETTE :" label — visible on 3 maps.)
- **Dark-scene legibility**: can you find every enemy? Read every HP numeral?
  If you have to squint at a 4x screenshot, a player at 1x is lost.
- **Map readability**: is floor-vs-wall unambiguous? Do interactables pop?
- **UI furniture accumulation**: what's permanently on screen, and does it
  grow with progression (field-skill legend, hint toasts)?
- **Sprite overlap/anchoring**: NPCs standing "inside" each other during
  dialogue, feet a row off their logical cell.
- **Page starts**: does any dialogue page open mid-sentence with no
  continuation cue?

## Step 4 — Read the copy from the event log

Rendered text can be truncated while the payload carries the full line — diff
them to separate authoring bugs from render clipping:

```bash
grep -o '"text":"[^"]*"' qa_output/<script>/events.jsonl | head -40
```

Judge voice, tone consistency, and whether the best lines survive rendering
(a punchline that only exists in the payload is a bug).

## Step 5 — Report

Rank findings player-visible-first: (1) bugs a new player would screenshot,
(2) friction/design-level, (3) what genuinely lands (keep this — it tells the
next session what NOT to break). Every claim cites its screenshot path. New
visual findings go to `docs/VISUAL-LOG.md`; anything blocking goes to
HANDOFF.md's next-steps.
