# Wandering Inn RPG Handoff

Live current-state doc. Per-issue narrative lives in merged PR bodies
(`gh pr list --state merged`); adjudications in CHOICE-LOG; build
history in git. Read order for a fresh session: wi-start-here.

## Current state (2026-07-28)

**v0.14.0 AND v0.15.0 ARE TAGGED AND SHIPPED** (both cut 2026-07-28):
v0.14.0 Release run 30324073065 green, v0.15.0 Release run 30370380971 +
Pages run 30370380285 green — full QA on real assets, itch html5, Win/Linux
desktops. Freeze step-0 done for both (#303: 669 ids, `finale_played`
hand-added to STRUCTURAL_LITERALS both lists; #317: 697 ids, 28 adds all
data-derived, zero hand-adds). Board bookkeeping done: #269/#270 closed.

- **v0.14 "Main Quest"** (PRs #291–#302): acts I–V reframed off
  "post-game", "The Dig" backport, FotI roster to ten, the
  Riverfarm→Invrisil→Pallass pilgrimage spine, Act V's three-path
  conclusion + finale (epilogue retired), difficulty ladder. Plan:
  docs/superpowers/plans/2026-07-26-main-quest-foti-wave.md (DONE).
- **v0.15 "Legibility & Life"** (PRs #310–#317): delivery layer
  (openings/leads/lore), viewports + endings acknowledgment, guest
  arc-windows + hygiene batch, the population pass, readability/rigs/map
  lights. Close: 30/30 unit suites, 167/167 sweep, 16/16 windowed
  machine-playtest runs, VISUAL-LOG drained.

**v0.16 "Region Depth" IS EXECUTING (this session, 2026-07-28).**
Authority: docs/design/2026-07-28-v0.16-region-depth-spec.md + issues
#305 (Riverfarm) #306 (Invrisil) #307 (Pallass) #308 (Floodplains).
User directives this session: highly-parallel workflow execution, and
**each region gets its OWN spec+plan doc before implementation — no
user approval gate** (wave-autonomy discipline; forks go to CHOICE-LOG,
taste items surface at close as Playtest-State asks).

## 🎯 RUNNING (v0.16 wave state — keep current)

1. ✅ Recon (5 readers) → 4 per-region plan docs → adversarial verify
   (42 findings: 4 BLOCK, 11 HIGH) → fix wave → **plans committed
   c087559** (docs/superpowers/plans/2026-07-28-v016-*.md) + CHOICE-LOG
   wave block + character-profiles stub scaffold.
2. ✅ USER DIRECTIVE mid-wave: Invrisil nobility layer — amendment in
   the Invrisil plan (client → "A Lady with a Ring Box", Reinhart
   ambient at the Rest/stationer); full thread filed as **#318 (v0.17,
   spec-first)**.
3. ⏳ IMPLEMENTATION FLEET IN FLIGHT: workflow wf_55262b42-410 — 4
   lanes × (3 implement stages → traced adversarial review → fix wave),
   Opus implementers, worktrees .claude/worktrees/v016-{riverfarm,
   invrisil,pallass,floodplains} on branches issue/305-riverfarm-depth /
   306-invrisil-depth / 307-pallass-depth / 308-floodplains-price-kept,
   all from main c087559, asset overlays copied (185 files each).
   Lane commits stay LOCAL; controller owns PRs. Per-lane progress:
   <worktree>/.lane-progress.md.
4. ⏳ Then: PR per lane ([ci-full] heads, 6 checks), merge-train with
   composed-tree re-gates (census on MERGED tree per merge;
   derive_qa_surfaces + render_qa_notes --write re-run per merge).
5. ⏳ Wave close: cross-region machine playtest + VISUAL-LOG drain +
   helper-pace re-run + economy-axes pass + deferred leads rows (after
   freeze step-0) + hygiene (AGENTS.md (4,8) portal note; nine dead
   *_inn_settled lines) + tag v0.16.0.

## NEXT ACTIONS (after / alongside the wave)

**WAVE-CLOSE ECONOMY PASS (queued 2026-07-28, from v0.15 Phase 4 —
now folds into the v0.16 close).** Lane B's regional-work props moved a
number no gate watches: risk-free wage floor 1g → 7g per waking,
`[Perfect Hospitality]` rider +1g → +4g, and 33 → 44 `talk_pool` NPCs
raised the per-waking `heard_gossip` ceiling (feeds Barmaid/Innkeeper
`requires_any` + half of `[Diplomat]`'s entry). `sim_progression_pace`
cannot see either axis. v0.16 adds MORE carry-job props and talk_pool
NPCs — re-measure BOTH axes at the v0.16 close, price against the #92
ladder. Wages are NOT the cut lever — regions should pay; the lever is
the ladder. Full numbers: docs/CHOICE-LOG.md v0.15 T4.4 entry.

**v0.15 FOLLOW-UP BATCH (agent-actionable, carried 2026-07-28)**
- **P5 legacy figure sweep — 8 ids** under the 1.25 floor, never
  photographed as defects; each needs its OWN windowed read before its
  scale moves: `river_wolf_a/_b/_c` + `wolf_companion` (0.62),
  `shield_spider` (0.75), `goblin_raider` (0.96), `goblin_shaman` (1.00),
  `goblin_chieftain` (1.07). Nothing ships over the ceiling.
- **Pre-invitation Horns window** (pre-existing): Ceria/Yvlon x2, Ksmvr x3
  before the invitation; wants delve-arc presence windows that don't exist.
- **`heard_gossip` ceiling** — see economy pass above.
- **Nine dead `*_inn_settled` lines** (pre-existing; `door_awakened`
  cannot be held inside the original window) — v0.16 content-pass
  candidate (hygiene rider), not a lint fix.
- **`{addr}` coverage**: scan covers dialogue + quests.json + items.json;
  remaining surfaces unscanned.
- **`test_copy_fit` blind spots**: `sleep_veil.gd` line tables + dialogue
  `text_variants` unmeasured (VEIL-COPY/UNMEASURED, P4).
- Touch residue: two-finger index leak on pan reset, 2–6px slop boundary
  unprobed, touch-native branches only mouse-emulated.
- **`pc_sprite` payload asymmetry**; evidence-dir convention (v0.15 close
  wrote `qa_output/machine_playtest_2026-07-28_v015_close/`).
- **Five findings from the v0.15 close playtest**, all in
  docs/VISUAL-LOG.md: HUD/LEGEND-OVERLAP (P2), BOARD/STACKED-HP-BARS (P3),
  BOARD/TINT-NUMERAL-CONTRAST (P3), HUD/HINT-BAR-BLEED (P4),
  MAP/FORGE-MOLTEN-BLOCK (P4).
- From P5: ~~**no QA script fights `forge_hall`**~~ **CLOSED 2026-07-28 by
  v0.16 #307** — `pallass_standards_fight` fights the arena on the board and
  the windowed board shot is read in docs/VISUAL-LOG.md; Klbkch rig rebuild
  (defect confirmed, ~$0.54–0.81,
  never gated); SPRITE/ARC-CLIMAX FIELD half (companion-offset rule
  needed — Relc's cell follows the player).

**Dev-arch residue:** **#283** (vacuously-true `invrisil_anchor_stone`
`portal_menu_when`; lint allowlists it — closing = wrap the gate + drop
the allowlist entry + canonical re-check) and **#280 DEFERRED** (revival
criteria in docs/design/2026-07-26-dev-arch-eval-275-280.md).

**Door-chain polish pair (small, Codex-sized):** #271 `dungeon_attuned`
banks silently in `sleep_beat.gd` — add one bank-site toast (nudge idiom,
GH#167). #272 Selys sponsorship copy contradiction — copy-only fix ruled
in the issue.

## 🧑‍⚖️ TASTE QUEUE (user-held, in rough value order)

- **⭐ THE v0.15 PLAYTEST-STATE BUNDLE — six asks, one sitting.** Top of
  docs/VISUAL-LOG.md's Open list, each with a prepared-state name and a
  load/do/judge line: (1) camouflage tints; (2) Ruin Warden at 3.51 cells;
  (3) toast over an open journal; (4) `pallass_market`/`pallass_forge`
  lights by day; (5) Grimalkin in the inn (measurement refuted the scale
  claim — lever is seat or art); (6) the finale's paced lines (the one ask
  no agent can answer).
- **#195 Ove Melaa audio listen** (~30 files) → wiring pass after.
- **#211 challenge-weighted leveling FEEL** (shipped flag-on; knobs data).
- **3 Rags reads** (b1 content: meeting/mercy/betrayal voice).
- Standing visual asks: vault-fight windup overlay (brightened ~2.5x, no
  in-fight windowed read); rock-crab relc_downed band 0.62 vs infeasible
  ~0.5 (frontier in the combatant _comment).
- Economy ledger pass someday: ~82g three-city travel spend (#65).
- Lore-gated: #134 Wave-D classes, #141 [Acolyte]→[Priest].
- User-deferred: #253 itch/mobile Import Save picker. Pre-existing flake:
  #140 Metal windowed screenshot corruption. On hold: #19 Steam.

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
