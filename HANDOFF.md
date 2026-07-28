# Wandering Inn RPG Handoff

Live current-state doc. Per-issue narrative lives in merged PR bodies
(`gh pr list --state merged`); adjudications in CHOICE-LOG; build
history in git. Read order for a fresh session: wi-start-here.

## Current state (2026-07-28)

**v0.15 "Legibility & Life" IS DEPLOYED TO MAIN, PENDING TAG.** Five phases,
PRs #310-#314, all `[ci-full]` green, plus this wave-close PR. The tag cut is
the CONTROLLER'S next job — see the freeze inventory below; it is already
walked and clean.

Closed at the wave close (2026-07-28), all gates re-run on `close/v015`:
30/30 unit suites green on the three-check bar (exit code + `^PASS` + zero
noise), `data_lint` clean, `derive_qa_surfaces --check` and `render_qa_notes`
both match, doc-drift PASS, comment census GDScript 13.1% / DATA 15.0% (both
inside target), and the **full `ci_sweep.sh` at 167/167 green with zero grep
hits**. Then the MILESTONE-CLOSE machine playtest: **16 windowed runs, all
`passed: true`**, every v0.15 visual claim re-verified on fresh screenshots
rather than on the phase reports' word. Drained into docs/VISUAL-LOG.md.

**v0.16 "Region Depth" is SPECCED, NOT EXECUTED.** The next session
implements from `docs/design/2026-07-28-v0.16-region-depth-spec.md` and
issues **#305-#308** — the design work is done; do not re-design it.

**Record correction worth carrying:** the phase reports cite BRANCH commits
and all five phases landed as squash merges, so none of those hashes is an
ancestor of `main`. The citable set is `a085cfb` (#310), `63a431b` (#311),
`4a95a9c` (#312), `60f1887` (#313), `ed24c4f` (#314).

---

**THE MAIN QUEST WAVE IS MERGED TO MAIN — v0.14, UNTAGGED.** Nine phases,
seven PRs, all `[ci-full]` green: #291 acts I–V reframed off "post-game"
(Act IV opens on the seal), #297 "The Dig" (the Horns door-retrieval quest
backported to day one + the Liscor link), #293 FotI PR2a (Olesm+Pisces),
#294 PR2b (Relc+Zevara), #295 the roster to ten (Klbkch, Rags, Wilovan,
Grimalkin — quest-gated), #299 the Riverfarm→Invrisil→Pallass pilgrimage
spine + Act V's three-path conclusion + the finale sequence (epilogue
retired), #300 the difficulty ladder (each stop one band above the last).
The line plays start→finale; the whole-line machine playtest is drained
into docs/VISUAL-LOG.md. Board bookkeeping still owed: **#269 and #270 are
open issues whose work merged** — close #269, and either close #270 or
re-scope it to its unshipped Pallass-return B-side (`pallass_return_carved`
was never authored). Plan + freeze list:
docs/superpowers/plans/2026-07-26-main-quest-foti-wave.md (Status: DONE).

**Release-freeze step-0 (do this BEFORE the v0.14 tag):** bump `RELEASE` in
`wandering_inn_game/scripts/generate_shipped_ids.py`, regen, commit ahead of
the tag. 21 of the wave's new counters derive from data automatically; the
ONE exception is **`finale_played`** (bare `record_accomplishment` literal in
`src/ui/sleep_veil.gd`), which must be hand-added to `STRUCTURAL_LITERALS` in
BOTH lists — `generate_shipped_ids.py:92` and `tests/test_shipped_ids.gd:6`.
Tag-cut commits carry `[ci-full]`; bundle-latest check before tagging.

## Current release

**v0.13.0 SHIPPED 2026-07-20, all three targets green** (Release run
29716161272: full QA on real assets, itch html5 deploy, Win/Linux
desktop exports; Pages deploy green on the tag trigger). Contents: the Depth +
Polish wave — #209 journal tabs, #247 Friends of the Inn (Selys+Krshia
servable guests), #225 interior floors, **#111 project rename
("Wandering Inn RPG") + first-boot save carry-over**, #123 honest
canonicals, and the full art wave (#198 scroll split + sweep, #222
stalls/benches/statue, #224 batch B, #210 bespoke Erin, #223 rigs:
Rags/Ceria+cast/Ruin Warden) + pantry-door consolidation + the
scroll's earned decipher (PRs #260-268). 647 ids frozen at 0.13.0
(28 new). Prior: v0.12.1 (2026-07-19), v0.12.0 (2026-07-18), v0.11.x,
v0.10.0, v0.9.0, v0.8.0.

## 🎯 NEXT ACTIONS

**THE TAG CUT (controller, first).** Freeze inventory for v0.15 is walked and
clean — re-derived at the close, not assumed:
- Producer walk (`generate_shipped_ids.build_payload()` against the live
  catalogs, dry — nothing written): **classes 35, skills 119, items 72, maps
  22 — all UNCHANGED, 0 adds, 0 removals.** Accomplishments **421 → 449, 28
  adds, 0 removals**, so no freeze violation in any of the five id classes.
- The 28: `cleared_halls_by_force`, `riverfarm_field_jobs`,
  `invrisil_errands_run`, `pallass_fetches_run`, plus P4's population set —
  `chatted_with_forge_smith`, `chatted_with_lift_attendant`,
  `chatted_with_ksmvr_dig_camp`, `chatted_with_yvlon_dig_camp`,
  `chatted_with_invrisil_extra_1..7`, `eyed_the_billet_rack`,
  `eyed_the_dig_rope`, `eyed_the_dig_spoil`, `eyed_the_forge_tools`,
  `eyed_the_public_scales`, `eyed_the_quench_barrel`, `eyed_the_slag_heap`,
  `eyed_the_survey_stakes`, `found_the_cold_camp`,
  `leaned_on_the_parapet_rail`, `read_the_dig_notes`,
  `read_the_posted_ordinances`, `read_the_shift_slate`.
- **NO new bare code literals.** `STRUCTURAL_LITERALS` is byte-identical to
  v0.14.0 in BOTH lists (`generate_shipped_ids.py` and
  `tests/test_shipped_ids.gd`), the literal grep over `src/**` returns the
  identical 15-id set at v0.14.0 and at HEAD, and `record_accomplishment` call
  sites are 23 → 23. **All 28 adds are data-derived**, so unlike v0.14's
  `finale_played` this cut needs NO hand-add — bump `RELEASE`, regen, commit
  ahead of the tag, done.
- **`lore_notes` is a SAVE FIELD, not a counter** — a top-level Array on the
  save dict (`save.gd:36` serialize, `:110` migration default `[]`, `:201`
  type guard, `:271`/`:307` restore). It is not in the frozen accomplishments
  and needs no freeze action. Do not "add" it.
- Both v0.14 and v0.15 are merged and untagged; decide whether the cut is one
  tag or two. `[ci-full]` on the cut commits; bundle-latest check before
  tagging.

**WAVE-CLOSE ECONOMY PASS (queued 2026-07-28, v0.15 Phase 4).** Lane B's
regional-work props moved a number no gate watches. The risk-free wage floor
went **1g → 7g per waking** (the interact branch's `once_per_waking` + `gold`
set grew from `serving_tray` alone to four props), and `[Perfect Hospitality]`'s
+1-per-prop rider grew with it: **+1g → +4g, a helper-only standing premium**.
Separately the world went 33 → 44 `talk_pool` NPCs, raising the per-waking
`heard_gossip` ceiling that feeds the Barmaid/Innkeeper `requires_any` alternate
and half of `[Diplomat]`'s entry. `sim_progression_pace` measures TOTAL LEVEL on
a fixed chore budget and cannot see either axis, so its holstered verdict is
correct and narrow. At the wave close: price both axes against the #92 ladder,
and either scale the harness's social chore budget with the world's talkable
census or scope the pace claim explicitly to a fixed routine. Wages are NOT the
thing to cut if it reads rich — regions should pay; the lever is the ladder.
Full numbers: docs/CHOICE-LOG.md, v0.15 T4.4 entry.

**USER-GATED, decide before the next content wave (2026-07-27):**
1. ~~**Guest-row arc windows**~~ — **RULED IN + SHIPPED** (v0.15 ruling 1,
   Phase 3): `GUEST_POOL_GATES` takes an ANY-of Array; zevara and pisces
   carry arc windows, relc audited and deliberately not gated, and
   `test_content._validate_guest_gate_windows` now derives the window from
   pool gate AND rows so the two can never disagree. Residual: zevara's
   window opens at `heard_the_deep_tremor`, not at the earlier
   `watch_runner_pointed` — cost of the wider edge logged in
   docs/CHOICE-LOG.md; a Playtest-State ask if the user wants it.
2. ~~**Grimalkin sprite re-measure**~~ — **REFUTED v0.15 P5, nothing shipped.**
   The "~98px, about 2.3× Relc" figure was FRAME height (224 × 0.463) compared
   against Relc's FIGURE height — apples to oranges, and a rig frame is mostly
   transparent margin. Measured off the sheet's own alpha he is **49.1px =
   1.25× Relc**, exactly canon's "bigger than Relc"; deriving him to the 43.4px
   convention would have made him the SAME height as Relc and broken canon.
   What crowds the inn is his 2.9-cell arms-out WIDTH, which no `render_scale`
   changes. Remains a FEEL ask only (bundle item 5) — the lever is the seat or
   the art.
3. **The tag cut — now v0.14 AND v0.15**, both merged and untagged.
   Release-freeze step-0 above (v0.15's inventory is pre-walked in NEXT
   ACTIONS), `[ci-full]` on the cut commits, bundle-latest check before
   tagging.

**FOLLOW-UP BATCH (agent-actionable, from the wave's final whole-branch
review, 2026-07-27)** — dead fixture keys, the `interactions.gd` variant
guard and the `hedault_enchanting.json` fragment arm all SHIPPED in v0.15
Phase 3 (hygiene batch), alongside the Pallass arrival cell, the em-dash
sweep, the golem name split and the `{addr}`/variant/arrival lint arms.
Still open from that batch:
- `test_copy_fit` blind spots: the `sleep_veil.gd` line tables and dialogue
  `text_variants` are still unmeasured (VEIL-COPY/UNMEASURED, P4). Phase 3
  closed the `skill_uses` toast blind spot only.
- ~~COMBAT/FEED-FOLD~~ — **CLOSED in v0.15 P2 (`63a431b`)** and re-verified at
  the wave close on a fresh windowed shot: `riverfarm_fight/02_briar_deep_wave`
  now renders four FULL feed rows with the wrapped "for 13!" whole and clear of
  the fold. Cause was not the budget model but the label — `SHRINK_CENTER` +
  CENTER alignment parked the content block 5px into the fold band. This entry
  was stale in HANDOFF while docs/VISUAL-LOG.md already had it ticked.

**v0.15 FOLLOW-UP BATCH (agent-actionable, carried out of the wave, 2026-07-28)**
- **P5 legacy figure sweep — 8 ids.** The measured board bar is scoped to the
  rosters v0.15 audited and says so. Eight LEGACY ids still ship UNDER the 1.25
  floor and have never been photographed as defects, so asserting them would be
  a verdict no windowed read has made: `river_wolf_a/_b/_c` + `wolf_companion`
  (0.62), `shield_spider` (0.75), `goblin_raider` (0.96), `goblin_shaman`
  (1.00), `goblin_chieftain` (1.07). Nothing ships over the ceiling. Each needs
  its OWN windowed read before its scale moves, exactly as the audited rosters
  got one. (The three goblins' numbers were themselves re-derived at this close
  — they were logged as their `idle_down` rows, and the board plays `idle_side`.)
- **Pre-invitation Horns window** (pre-existing, carried not created). Ceria and
  Yvlon appear x2 and Ksmvr x3 (inn + delve staging + halls) BEFORE the
  invitation; byte-identical under v0.14's gate. Post-invitation is overlap-free.
  Wants delve-arc presence windows that do not exist yet.
- **`heard_gossip` ceiling.** The world went 33 → 44 `talk_pool` NPCs, raising
  the per-waking ceiling that feeds the Barmaid/Innkeeper `requires_any`
  alternate and half of `[Diplomat]`'s entry. `sim_progression_pace` measures
  total level on a fixed chore budget and structurally cannot see this axis.
- **Nine dead `*_inn_settled` lines** (pre-existing): `door_awakened` cannot be
  held inside the original's window, so they never render. Deliberately not
  resurrected in v0.15 — a v0.16 content-pass item, not a lint fix.
- **`{addr}` coverage.** P3 extended the scan to `quests.json` + `items.json`
  and Ksmvr's `{addr}` became "comrade"; the remaining surfaces have no scan.
- **Two-finger index leak on the pan reset** (pre-existing, narrow — no
  per-index isolation), the 2–6px slop boundary unprobed by committed tests,
  and touch-native branches covered only by mouse emulation.
- **`pc_sprite` payload asymmetry**, and the recurring **gitignored
  evidence-path citation** problem — consider a committed evidence-dir
  convention (this close wrote its own to
  `qa_output/machine_playtest_2026-07-28_v015_close/`).
- **Five NEW findings from the close playtest**, all in docs/VISUAL-LOG.md:
  HUD/LEGEND-OVERLAP (P2 — the field-skill legend draws over the flavor toast
  and eats 52 characters of authored copy mid-word; worsens as the legend grows
  with progression), BOARD/STACKED-HP-BARS (P3 — four instances; partly caused
  by the wave's own scale increases), HUD/HINT-BAR-BLEED (P4),
  BOARD/TINT-NUMERAL-CONTRAST (P3 — the invoice for the T5.1 tints),
  MAP/FORGE-MOLTEN-BLOCK (P4, fidelity).
- Also still filed from P5: no QA script fights `forge_hall` (the arena half of
  the forge fix is unit-proven but has no board screenshot anywhere in the
  suite; the fight is reachable by declining the golem's parley), the Klbkch
  rig rebuild (defect confirmed, feasibility proven at ~$0.54–0.81, never
  gated), and SPRITE/ARC-CLIMAX's FIELD half (Relc is a COMPANION so his cell
  follows the player — needs a presentation-side companion-offset rule).

**Dev-arch wave #275-280 (2026-07-26) — residue only:** all seven PRs
merged (#282 wi_data_lib, #284 data_lint, #285 live reload, #286
ship-asset gate + pending audio slots, #288 4-way parallel CI sweeps,
#289 data_diff, #290 debug overlay). Still live: **#283** (the shipped
vacuously-true `invrisil_anchor_stone` portal_menu_when — lint allowlists
it; closing it = wrap the gate + drop the allowlist entry, needs a
canonical re-check) and **#280 DEFERRED** (revival criteria in
docs/design/2026-07-26-dev-arch-eval-275-280.md).

**Door-chain polish pair (filed 2026-07-20, small)**: #271
`dungeon_attuned` banks silently in `sleep_beat.gd` — no toast, no
quest beat; add one bank-site toast (nudge idiom, GH#167). #272 Selys
`pallass_sponsored_reaction` copy says "give it a day or so" while the
sponsor node says "same-day" and no wait exists — copy-only fix ruled
in the issue (sleep-gate alternative rejected: re-pins
pallass_walkthrough). Both are clean Codex-sized dispatches. Came out
of a progression-map audit; cost-curve concern folded into the
existing #65 economy-ledger taste item, not a new issue.

## 🧑‍⚖️ TASTE QUEUE (user-held, in rough value order)

- **⭐ THE v0.15 PLAYTEST-STATE BUNDLE — six asks, one sitting.** At the top
  of docs/VISUAL-LOG.md's Open list, with a prepared-state name and a
  load/do/judge line each: (1) the camouflage tints — magic-touched or
  recoloured; (2) does the Ruin Warden still land at 3.51 cells after falling
  from 7.62; (3) toast over an open journal — lively or broken (the
  information-losing case is FIXED; what remains is deliberate); (4)
  `pallass_market`/`pallass_forge` lights by day; (5) Grimalkin in the inn
  (refuted on measurement — if he still FEELS big the lever is the seat or the
  art, never the scale); (6) the finale's paced lines, which are structurally
  invisible to QA and are the one ask no agent can answer.
- **v0.14 wave asks** (detail in USER-GATED above): the tag cut — now covering
  v0.14 AND v0.15, both merged and untagged. The guest-row arc-window call
  SHIPPED (v0.15 P3) and Grimalkin's re-measure was REFUTED on measurement
  (v0.15 P5); the whole-line playtest's visual items (Act IV pending-itinerary,
  journal half-row, briar camouflage, Pallass forge floor, warden rig scale)
  are ALL closed and ticked in docs/VISUAL-LOG.md.
- **#195 Ove Melaa audio listen** (~30 files) → wiring pass after.
- **#211 challenge-weighted leveling FEEL** (shipped flag-on; all
  knobs data).
- **3 Rags reads** (b1 content: meeting/mercy/betrayal voice).
- Standing visual asks: windup overlay visibility in the vault fight
  (brightened ~2.5x without an in-fight windowed read — your eyes);
  rock-crab relc_downed band sits at 0.62 vs the infeasible ~0.5
  target (frontier documented in the combatant _comment).
- Economy ledger pass someday: the cumulative ~82g three-city travel
  spend (each fee individually sanctioned; flagged at #65).
- Lore-gated: #134 Wave-D classes (Alchemist/Druid/Priest), #141
  [Acolyte]→[Priest].
- User-deferred: #253 itch/mobile Import Save picker bug. Pre-existing
  flake: #140 Metal windowed screenshot corruption. On hold: #19 Steam.

## Reference

```sh
# Play (human)
/usr/local/bin/godot --path wandering_inn_game

# Agent verification (primary; seed table in wandering_inn_game/AGENTS.md)
wandering_inn_game/qa/run_qa.sh <script> headless --seed=<N>
/usr/local/bin/godot --headless --path wandering_inn_game --quit   # smoke; zero warnings
wandering_inn_game/qa/ci_sweep.sh                                  # full canonical sweep
```

- Godot **4.7.stable** at `/usr/local/bin/godot`; 4.6.2 preserved at
  `/Applications/Godot4.6.app` for the frozen v2 only.
- PixelLab via the `pixellab` MCP server (pipeline + traps in
  wi-art-and-sprites); ~$2.7 overage credits as of 2026-07-20.
- Web QA deps installed (export templates 4.7, Playwright chromium,
  qa/web/node_modules). `potential_assets/` is gitignored — never
  commit it.
- **Windowed-exit flake**: ~1/3 windowed runs print an ObjectDB leak
  notice AFTER `QA_RESULT: PASS` (audio teardown race, pre-existing,
  never headless, results unaffected) — do not re-diagnose. Godot 4.7
  also rarely SIGABRTs at shutdown (cosmetic; if phantom FAILs appear
  with clean QA_RESULT lines, suspect exit-134 first).
- macOS: no `timeout` (use `perl -e 'alarm N; exec @ARGV'`); bash 3.2
  (no mapfile; `${ARR[@]+"${ARR[@]}"}` for empty arrays under set -u);
  zsh does not word-split unquoted vars.

*(Older narrative — closed milestones, the 2026-07 wave logs, and the
numbered adjudication ledger through v0.13.0 — lives in this file's git
history and the merged PR bodies; pre-2026-07-05 material in the frozen
archive repo at docs/archive/HANDOFF-archive-2026-07.md.)*
