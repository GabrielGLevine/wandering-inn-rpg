# Wave B Completion Spec (#132) — resume from salvaged tree

**Authority chain:** `docs/design/class-expansion-spec.md` §7 (verbs) + §3
Wave-B skill table, plus two controller rulings already issued:
(R1) blink clear-line = cardinal `is_cell_blocked()` scan that may pass
OVER cells in the map's `freezable` set (water) but stops at any other
blocked cell; landing = farthest walkable, unoccupied, non-freezable cell
within `blink_range`; refusal toast otherwise. Document the wall-vs-water
distinction — load-bearing. (R2) field casts are MP-INFORMATIONAL (the
shipped [Invisibility] precedent); `mp_cost` is real on combat halves
only; note the convention in flash_step's `_comment`.

**Position:** branch `issue/132-wave-b-verbs`. Commit `e9e5380` salvages a
PARTIAL previous run (that run wedged: 4h+ with no writes — canceled).
Already present (verify, don't re-do blindly): five grant-slot fills
(double_step runner L5, flash_step necro L7 + mage L11, animate_dead
necro L5, hearthward_charm hedge_witch L5, greater_hearthward witch L10);
`skeleton_ally` in combatants.json; field_skills.gd/wi_game.gd verb work;
save.gd persistence fields; wi_events.gd events; test additions
(test_sim_core/test_save/test_progression/test_combat_sim); sim rows;
sprites.json icon entries; qa/manifest.json entries.

## Step 0 — WEDGE DIAGNOSIS (before any new work)

The previous run almost certainly hung inside a gate: **a failed
`assert()` HANGS a `--script` run** (see CI's own watchdog comment).
macOS has NO `timeout` command — wrap EVERY gate invocation:

```sh
perl -e 'alarm 180; exec @ARGV' /usr/local/bin/godot --headless --path . --script res://tests/test_X.gd
```

Run the FULL unit suite this way, one file at a time. Any alarm-kill or
SCRIPT ERROR marks the wedge — fix the underlying code/test (class-level
fix, not a pin), then continue. Report which test wedged and why.

## Completion checklist (delta against original criteria 1–10)

For each item: check the tree first; finish only what's missing.

1. **Blink verb** per R1 + spec §7.1 (PLAYER_TELEPORTED event,
   `blinked_past_danger` trigger-crossing bank with `danger:<id>` dedup,
   landing-inside-radius fires normally).
2. **Ward verb** per §7.2 (faced cell → nearest armed trigger_radius
   encounter containing it; save-persisted; `_check_trigger_radius`
   skips warded; banks `warded_danger` + `witch_craft_used` dedup'd;
   sleep decrements `ward_sleeps`, default 1; refusal toast).
3. **Companion** per §7.3 (consume faced bone_pile_* prop; save-persisted
   companion state; `start_combat` appends skeleton_ally AFTER
   ally_requires filtering, BEFORE ally_hp_penalty; combat death or
   sleep clears).
4. **World layer** (likely MISSING — check src/world/): afterimage streak
   on PLAYER_TELEPORTED honoring reduced-motion; placed charm sprite +
   faint ring on warded cells; follower sprite trailing the player while
   companion state is set. Presentation only renders — no sim reads back.
5. **Icons ×5** (double_step, flash_step, animate_dead, hearthward_charm,
   greater_hearthward): sprites.json entries exist — verify PNGs
   generated via tools/sync_assets.py placeholder shapes + registry test
   counts. **TRAP: sync_assets regenerates placeholder sfx WAVs as binary
   churn — `git checkout -- wandering_inn_game/assets/audio` before
   finishing (do not stage WAVs).**
6. **Sim**: with-skeleton cells for both dual-class builds, GATED
   0.55–0.95 / 3–12 by cell selection only; document bands in the doc
   block beside the Wave-A cells' comment.
7. **QA loops ×3** + hand-authored fixtures per wi-writing-qa-scripts:
   (a) floodplains road-ambush triple-answer script — sneak, ward, and
   blink each bypass the same ambush banking their three DISTINCT
   counters; (b) ward loop (place → suppressed → sleep expiry);
   (c) companion loop (animate → ally appears in combat.combatants →
   cleared after sleep). Each with a can-fail proof (mutate → red →
   revert → green; paste all three).
8. **render_qa_notes**: `python3 scripts/render_qa_notes.py --write`
   after QA additions (CI's leak job runs `--check`).
9. **Gates** (ALL alarm-wrapped, foreground, paste results): isolated-HOME
   smoke (zero project warnings); full unit suite per-file (PASS line AND
   no SCRIPT ERROR/WARNING — CI's exact bar); full sim harness;
   `qa/ci_sweep.sh --tier smoke` + the three new loops + `--touching`
   for every data file edited.
10. **Boundaries**: no dialogue, no docs edits except a VISUAL-LOG icon
    drain note, no .git, pure-sim discipline in src/core/** (no
    autoload/Node refs). STOP (NEEDS_CONTEXT) on any spec-silent design
    question instead of inventing.

## Report format

Tree-inventory table (criterion → found/finished/evidence), the wedge
diagnosis, sim table, three can-fail proofs, CRITERIA NOT MET (empty only
if truly none), NEEDS_CONTEXT.
