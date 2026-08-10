# LANE-BRIEF — #423 Hedault's Enchanter shop + [Pick Lock] debut (lane H)

Worktree: /tmp/wi-423 (branch issue/423-hedault-shop, base aef1fe82 = the #417 lane head; its derive_qa_surfaces already walks install_fixture).
Read wandering_inn_game/AGENTS.md FIRST, then docs/superpowers/plans/2026-08-10-reachability-wave-417-421-423-424.md (CHOICE-LOG 28 is the design authority), then `gh issue view 423` + its dispatch comment.

## Deliverables

1. **New interior map** `data/maps/invrisil/enchanter_shop.json` — Hedault's
   respectable indoor Enchanter's shop. Model schema/size on stationer.json
   (small interior; grid, blocked, walls, floor_layers, decor, ambience,
   entities). Door pair: boulevard north wall y=1 at an open x in 19..27
   (avoid [18,1]/[20,1]) <-> shop exit door. Both directions land on
   standable cells. Shop fiction: enchanting workbench (the apothecary/
   enchanting bench fiction moves here from the alleys), display shelving,
   Hedault stationed WALK-REACHABLE (>=1 orthogonally-adjacent standable
   cell reachable from the shop door — the exact defect this issue fixes;
   the #424 suite will assert it).
2. **Hedault moves** out of mercantile_alleys (0,6); alleys corner
   re-dressed (Cups stays; invrisil_apothecary_bench disposition: audit
   its QA/dialogue references before moving or leaving — report either way).
3. **[Pick Lock] skill**: id `pick_lock`, display_name "[Pick Lock]",
   ACTIVE exploration field skill (deliberate cast; CHOICE-LOG 24), icon
   per existing icon conventions (check data_lint check_skill_icons —
   field skills need icons; reuse-with-precedent or generate is a
   controller call: STOP if no suitable existing icon fits and say so).
   Grant: classes.json rogue L2 (slot empty, requires sneaked_past_danger:2
   — do not change the requires).
4. **Debut gate**: locked back room in the shop (door or curtained
   doorway + locked_toast). TWO MODES, contents identical:
   - [Pick Lock] cast (skill-gated interaction via the existing gate
     machinery — [Disarm Trap]/[Greater Strength] rows are the pattern).
   - Legitimate path: Hedault unlocks it via a trust beat in his own
     content — propose ONE: a_setting_for_a_lady completion, or an
     enchant-commerce beat in hedault_enchanting. Dialogue-effect
     unlock (accomplishment) is the expected mechanism.
   Back-room contents: FIRST CANDIDATE is the existing item
   `hedaults_wardstone` — the #424 lint found it shipped with NO
   acquisition path (orphan), and wiring it here clears that advisory
   row. Audit its definition/band first; if its band does not fit a
   back-room reward, keep the wardstone unwired (report why) and band a
   new modest item field-for-field against a shipped comparable
   (sealed_factor_bale / riverfarm_ferry_tally precedent). One-shot via
   container_state.
5. **Existing-door audit**: inn_upstairs hallway_door_a/b + lyonette_door,
   barracks cell_door. Propose AT MOST one fiction-fitting [Pick Lock]
   conversion (literal lock + meaningful gated content + a legitimate
   alternate mode); default is NO conversion — a proposal in the report,
   not an implementation, unless it is genuinely clean.
6. **QA re-anchor**: hedault_fragment_loop + hedault_enchant_loop +
   fixtures re-anchored to the shop, WALK-REACHABLE this time — fixtures
   must not pre-stage adjacency (the machine-green vs player-truth gap
   this issue exists to close); scripts WALK from the shop door. Negative
   leg pins lane-CREATED state (created-state doctrine: a pin that passes
   with the lane's changes deleted is inert). Grep qa/scripts +
   qa/fixtures for EVERY hedault/alleys-cell reference (spine_reach,
   invrisil_setting_skill, invrisil_setting_talk, invrisil_v016_gate_check
   are known; enumerate the rest) and re-pin. New canonical for the
   back-room gate: both modes proven (pick mode at seed, key mode at
   seed), plus a no-skill-no-key refusal leg.
7. **Route growth**: invrisil_walkthrough + steel_thread gain the shop
   leg (steel_thread is the composed windowed instrument — keep its
   duration honest per its own conventions).
8. **#424 waiver note**: the interactable-reachability suite
   (test_interactable_reachability.gd) lives on the UNMERGED #424 lane —
   NOT in your tree. Do not hunt for it. Your obligation: Hedault (and
   every entity you place/move) ends with >=1 orthogonally-adjacent
   standable cell reachable from the shop/boulevard doors. The
   controller removes the suite's hedault waiver at composed-merge and
   re-runs it there.
9. **Manifest**: register new/changed scripts via derive_qa_surfaces
   regen (post-#417 tool — it now walks install_fixture).

## Constraints
- Content = data. NO src/** edits expected; the existing gate machinery
  must carry the lock (if it cannot, STOP — NEEDS_CONTEXT with the exact
  missing capability; do not build a sim system).
- Two-mode rule everywhere; virtuous path is a USER DIRECTIVE, not
  optional.
- Voice/prose: new map talk/observe prose obeys the anti-duplication
  gate (banks/@refs) + voice-bible register; run the maps voice gate;
  hedault_enchanting edits re-run the dialogue voice gate vs baseline.
- Sprites: reuse shipped sprites/props (door, benches, shelves); any new
  sprite need = STOP and list it (controller owns art calls;
  tint-is-not-disambiguation).
- Fixtures: grant-derived, honest (no pre-staged adjacency, no
  pre-granted lock states); v6 key-set conventions.

## Verification (foreground, sequential, alarm-wrapped)
data_lint; full unit bar; `--touching` over every edited
map/fixture/script + `--tier smoke`; all re-anchored canonicals at
pinned seeds; both voice gates; preflight.sh.
PROVE-CAN-FAIL x3: (a) back-room reward one-shot (container_state
round-trip); (b) lock refusal leg reds if the gate row is deleted;
(c) the re-anchored loop's WALK leg reds if Hedault's adjacent
standable cell is re-blocked (temporary map mutation, restore).

## Report
/tmp/wi-423/LANE-REPORT.md — full re-anchor inventory, door-audit
proposal, key-mode design as implemented, gate commands + verbatim
verdicts, can-fail proofs, diffstat. Final message: 8-line summary +
report path.
