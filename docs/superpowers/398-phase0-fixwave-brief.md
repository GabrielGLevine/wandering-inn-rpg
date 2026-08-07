# ISSUE #398 PHASE 0 FIX WAVE (Codex brief — review verdict attached below)

Work THIS checkout. No git commands. Your Phase-0 tree was reviewed:
DO NOT MERGE as-is. Apply exactly these, then re-verify. Class-level
fixes only — no symptom patches. LIST EVERY ITEM NOT DONE at the end.

1. (C2/H1/H2/M5 — one root cause, one class fix) WEAPON-GATE the field
   context for cuts skills: in the field dispatch/hotbar-derivation
   path, a `cuts` skill is field-visible and castable ONLY when the
   player's equipped weapon matches the skill's weapon family (reuse
   the existing weapon-family mechanism the interact path uses —
   interactions.gd's _holds_weapon_family idiom; the spec calls these
   "the two weapon-gated martial actives"). Consequences you must land:
   (a) REVERT both martial fixture edits (martial_field_start,
   martial_field_armed) — then re-run the canonicals: unarmed fixtures
   must go green UNMODIFIED (barehanded warriors gain no slots);
   (b) for any still-red canonical whose fixture models an ARMED
   warrior: the +1 slot is the intended player-visible change — re-pin
   the expected hotbar contents HONESTLY (never a fixture loadout edit
   to suppress the change). If an armed bar exceeds 9 slots, report the
   exact fixture + slot list and STOP that script's re-pin for
   controller adjudication — do not invent a loadout.
   (c) property_seams must return to byte-stable payloads (its fixture
   is unarmed).
   (d) a new can-fail proof: barehanded cast of power_strike at a
   cuttable → refusal (no removal, no counter); armed cast → works.
2. (C1 + scope verdict a) REVERT wandering_inn_game/data/maps/sewers/
   sewers.json entirely — Phase-1 P2 owns that map and will build the
   gallery with reward gating answering both counters.
3. (scope verdict b) shipped_ids.json: revert, then splice ONLY
   cut_through_growth via scripts/splice_json.py (placement proof).
   KEEP both generator changes; ADD the missing mirror check between
   generate_shipped_ids.py's FROZEN_RETIRED_ACCOMPLISHMENTS and
   test_shipped_ids.gd's RETIRED_ACCOMPLISHMENTS (a drift must red one
   of the suites — prove it can fail).
4. (M2) Write the five skill_gates lint arms into
   scripts/tests/test_data_lint.py per that file's own convention —
   one can-fail case per arm minimum, plus the good-registry pass case.
5. (M1) Arm (b): a mode whose skill-granter union is EMPTY fails HARD
   unless the mode declares an explicit non-skill gate field (design
   the minimal declaration, e.g. "gate": "dialogue"|"item"|"endure" —
   document it in the arm's message). Add the can-fail case to the
   self-tests.
6. (M3) interactions.json cuts row: toast_from "target" + toast_key
   "cut_toast", keeping the row toast as fallback default.
7. (M4) terrain "cleared": wire it into world.gd's terrain match with
   minimal visual feedback (reuse the existing removal-poof path the
   burn outcome uses; no new vfx system). If that exceeds a small
   bounded diff, report instead and change the row's terrain semantics
   honestly.
8. (L4) Fix the min_range-None lint message. (L5) Update the two stale
   doc notes (martial_field_loop.json:1239 comment + the manifest
   note) to say what the assertion now proves. (L1) Make arm-2
   distinctness pairwise across ALL modes.
9. Re-verify EVERYTHING: data_lint rc 0; census rc 0 (own rc); the
   NINE previously-red canonicals at their pinned seeds (field_skills_
   loop, sewers_walkthrough, social_loop, rogue_earn_loop,
   hotbar_tab_loop, archer_earn_loop, garden_walkthrough, mouse_loop
   seed 9; journal_categories seed 3) — all green; property_seams +
   ice_floor_loop + blink_bypass_loop + martial_field_loop green; all
   33 unit suites rc 0 zero-warning; scripts/tests/test_data_lint.py
   green; derive_qa_surfaces --check OK. THEN run the FULL sweep:
   bash wandering_inn_game/qa/ci_sweep.sh — ALL scripts green (the
   review proved units-green ≠ sweep-green).
Final output: per-item evidence + not-done list + command ledger w/ rcs.
