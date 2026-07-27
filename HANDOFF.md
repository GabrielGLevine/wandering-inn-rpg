# Wandering Inn RPG Handoff

Live current-state doc. Per-issue narrative lives in merged PR bodies
(`gh pr list --state merged`); adjudications in CHOICE-LOG; build
history in git. Read order for a fresh session: wi-start-here.

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

**v0.14 SPECS READY (2026-07-20)**: the next-session implementation
briefs are committed — docs/design/2026-07-20-foti-pr2-spec.md
(#269: Friends of the Inn PR2a/2b: Olesm+Pisces then Relc+Zevara, window
math + seat cells + register-purity rules all pre-derived) and
docs/design/2026-07-20-door-continuation-spec.md (#270: "What the Seal Was
Feeding": 3 beats, 3-path parity, Act V slot, the detected_wardwork
quartet payoff; PR A data-only → PR B map+warden → PR C Pallass
return anchor). Both evidence-verified this session (workflow
research); START THERE.

**Dev-arch wave #275-280 EXECUTED (2026-07-26, same session as the
adjudication)**: 7 PRs merged — #282 wi_data_lib + --touching fix
(#281), #284 data_lint (#276, wired ci_sweep pre-flight + leak-check
job; wi-verifying-changes now mandates it first on any data edit),
#285 live reload (#278: FIVE stale caches — review found audio.json as
the fifth; `reload_data` step + `reload_loop` canonical; edit→Save→Load
tuning loop documented in wi-machine-playtest), #286 ship-asset release
gate + audio `pending:true` slots (#277, itch job only, disk-only,
lands green as a ratchet; #195 slots can now merge ahead of files),
#288 4-way parallel CI sweeps (#287, user-reported bottleneck:
**6m50s → 2m22s** on the PR gate), #289 data_diff advisory summarizer
(#275 — use per wi-handling-prs on any data PR). #290 IN FLIGHT
(#279 debug overlay: F3/`toggle_overlay`, read-only, debug builds
only, `overlay_loop` canonical) — merge when its 6 checks green.
#280 DEFERRED (revival criteria in the plan doc). NEW: #283 filed —
the shipped vacuously-true `invrisil_anchor_stone` portal_menu_when
(lint allowlists it; closing #283 = wrap it + drop the allowlist entry,
needs canonical re-check). Plan/danger-list authority:
docs/design/2026-07-26-dev-arch-eval-275-280.md. #269/#270 remain
START THERE for content sessions.

**#111 rename FULLY VERIFIED 2026-07-20**: native rehearsal passed on
real data (5 saves + settings byte-true, marker, v4 dir intact) AND
the user confirmed the web migration on the live deploy ("Rename
migration successful"). Nothing in flight. The board is fully
user-gated (taste queue below), apart from the new machine-playtest
follow-up below; next milestone planning is open — docs/ROADMAP.md;
Three Pillars (spec approved) is the standing next big rock.

**MACHINE-PLAYTEST P1 → FIXED in v0.13.1 (GH#273, 2026-07-20):**
independently re-verified, root cause REFINED — the render arm was never
missing; the pointer (and the quest-start toast, worse than first
reported) queued last at the wake beat and `_clear_toast()`'s transition
wipe discarded the pending queue. Fixed via sticky-toast re-queue +
PINNED render asserts in arc_flow/climax_chain/raskghar_entry_loop (the
old bare `ui_toast_rendered` wait was the false-pass mechanism — sweep
for that pattern is follow-up in #273). Still open from the same pass:
dark-arena enemy visibility below the prior bar and deep-tunnel climax
sprite stacking (evidence/owners in `docs/VISUAL-LOG.md`). User eyes
wanted: a real-rig windowed read of arc_flow's `01_tremor_pointer` shot
(container GL too slow to catch the 0.4s toast hold on camera).

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
