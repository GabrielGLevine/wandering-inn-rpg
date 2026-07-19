# GOAL — v0.13 Depth + Polish Wave (charter, 2026-07-18)

Executes AFTER v0.12.1 ships (mobile hotfix: #196/#197/#202 + gold caps).
User directive: continue autonomously; judgment calls to docs/CHOICE-LOG.md;
user defers to recommendations to keep things moving. No user playtest gates
except the items marked USER-GATED below.

## Cold-start bootstrap (fresh session, zero context)
1. Read in order: `CLAUDE.md` → `wandering_inn_game/AGENTS.md` → `HANDOFF.md`
   → `docs/design/2026-07-18-v0.13-depth-polish-wave.md` (the wave map) →
   this file. The `.claude/skills/wi-*` library is the process canon —
   `wi-start-here` first, then `wi-running-the-machine` before any task and
   `wi-shipping` before any release step.
2. `git status` must be clean on `main`, synced with origin. Run
   `bash scripts/usage_status.sh` (guard tiers in `wi-usage-guard`).
   Fresh clone only: `scripts/fetch_private_assets.sh` then a headless
   `--import` pass.
3. Where truth lives: GitHub issues = dispatch briefs (`gh issue view <n>`);
   merged PR bodies = per-issue history; `docs/CHOICE-LOG.md` =
   adjudications; **issue #211's comments carry the user's leveling
   directives VERBATIM** — read them before touching the progression
   package, the two block-quotes there are the design authority.
4. v0.12.1 (shipped just before this charter activates) contained: dialogue
   tap-advance + page events + `qa_real_paging` driver opt-out (#196),
   title gesture catcher (#197), Recent-Messages transient noise class
   (#202), `gold_once_per_waking` on dirty_table + whole-prop
   `once_per_waking` on 7 scavenge props, and QA registration for
   gate_visual_check / credits_visual_check / mobile_tap_check. Do not
   re-litigate; `git show v0.12.1` for the diff.

## Model usage directive (user, 2026-07-19): PUSH FABLE HARD
Fable access ENDS after tomorrow (~2026-07-20). Invert the usual
throttle-the-top-model pacing for this window:
- **Spend the Fable budget aggressively** on Fable-class work while it
  exists: the #194 seam extractions, the #211 challenge-weighted
  progression design + sim implementation, wave-package design briefs,
  whole-branch reviews, and any canon/balance adjudication. Do NOT save
  budget for later — there is no later.
- Delegate mechanical/bounded work down the ladder (Codex gpt-5.6-sol per
  wi-delegating-to-codex; cheaper Claude tiers for grunt sweeps) so Fable
  hours go only where the reasoning ceiling matters.
- Usage guard still runs, but at OK/CAUTION prefer UPSHIFTING Fable onto
  the hardest queued package over idling; only WINDDOWN/QUIESCE curb it.
- **Front-load durable artifacts**: every Fable session ends with its
  learnings folded into `.claude/skills/wi-*` (the Fable-only edit rule
  holds until access ends, then the rule converts to propose-via-HANDOFF),
  design decisions written into issues/docs verbatim, and GOAL.md/HANDOFF
  current — successor Opus/Sonnet sessions must be able to execute the
  remainder of this charter from the artifacts alone.
- Sequencing consequence: prioritize the packages where Fable's judgment
  is least replaceable (#194a/b, #211, b1 Rags design, balance bars)
  ahead of mechanical placements (c2/c5) and copy passes, even where the
  plan doc's lane order would allow otherwise.

## Mission
Ship v0.13.0 as a significant depth + polish release: textures, visual
fixes, side quests, interiors/interactions, sprite & prop diversity,
mobile-input completeness, pacing, and the challenge-weighted progression
redesign. Plan of record:
**docs/design/2026-07-18-v0.13-depth-polish-wave.md** (18 packages, 3
file-ownership lanes). Board: issues #194–#225.

## Execution order
1. **#194a/#194b god-file seams FIRST** (lane a) — one seam per PR,
   byte-identical event streams at pinned seeds. Everything in lanes b/c
   that touches interact routing or banking waits for #194a.
2. **Challenge-weighted leveling (#211 + user directives in its comments)**
   — adversity-not-repetition: challenge weight (enemy power vs player
   power) on combat-sourced counters, per-encounter repetition decay,
   fractional banking (save VERSION bump + migration), and
   resolution-path-exclusive quest experience (diplomatic vs combat closes
   feed ONLY the resolving class line). Design doc + sim harness
   (progression-pace traces Act I→III) before data tuning. This is the
   wave's largest sim package — schedule right after #194a while the
   banking seam is freshly extracted.
3. **Lanes a/b/c in parallel** per the plan doc's dependency tables
   (mobile combat a3 + tap completeness a4; Rags b1 + Ratici b2 + parleys
   b3 + Grimalkin b4 + Invrisil aftermath b5 + Hedault b6 + ack/affordance
   wave b7 + audio b9 + ruin stone b10; art batches c1→c2, c3, c4→c5,
   floors c6). Same-file work = single implementer; lanes never share
   files.
4. **Pacing a6** (day ~2x, #206) and **hotbar auto-slot a7** (#208) are
   small and independent — slot into any gap.
4b. **#111 rename SPEC ONLY** (user directive 2026-07-19): author the
   safe-project-rename spec — save-compatibility strategy (config/name
   drives the user:// path, so a rename strands every existing save;
   enumerate migration options: path migration on first boot, dual-path
   read + single-path write, or export-preset-only rename), rollout
   order across itch/Pages/desktop, QA proof plan (fixture saved under
   the OLD name must load post-rename), and the recommended cut.
   Fable-class design work — front-load it per the model directive.
   IMPLEMENTATION stays USER-GATED; the spec ends with an explicit
   go/no-go ask.
5. Release mechanics at wave end (wi-shipping): rotation playtest, freeze
   cut, tag v0.13.0, watch all three deploy targets. Interim tags
   (v0.12.2…) allowed if hotfix-class findings land before the wave
   completes.

## USER-GATED (do not proceed without explicit go)
- PixelLab batch B fauna/icon items (VISUAL-LOG Wave D-2 standing gate).
- Dark-map legibility lift (a5): ships behind a prepared-save Playtest
  State for the user's windowed eye-read.
- #111 project rename: IMPLEMENTATION on hold — the SPEC is in-scope
  this wave (item 4b) and ends with a go/no-go ask. #19 Steam remains
  HOLD entirely.

## Standing rules (unchanged)
- PR-per-issue on `issue/<n>-<slug>`; verified 6/6 checks table before
  merge; issue-close PR template; reviewer subagent per task with method
  hints; prove-gates-can-fail (mutation) for new QA surfaces.
- Full sweep + exit-code-aware unit bar before every push; the sweep's
  zero-SCRIPT-ERROR grep is part of the bar (standalone run_qa is not).
- New QA scripts register in qa/manifest.json + AGENTS seed table +
  `python3 scripts/render_qa_notes.py --write` (all three, or CI's drift
  checks red).
- Usage guard at dispatch/merge points (wi-usage-guard); Codex available
  for bounded implementation waves per wi-delegating-to-codex.
- CHOICE-LOG every adjudication; HANDOFF stays current-state; new traps
  fold into .claude/skills/wi-* (Fable-only edit rule stands until
  handover).
- Spoiler bar: Book 17 content ceiling, Vol 7 advertised; Rags is
  early-volume-safe; say "Magical Door", never the Vol-9 name.

## Traps most likely to bite THIS wave (newest first; full library in wi-*)
- The QA driver's `match` takes the FIRST arm: grep
  `qa/test_driver.gd` for an action name before adding one — a duplicate
  arm shadows the original silently (cost 7 sweep reds on 2026-07-18).
  `click_dialogue_option` is 1-BASED.
- Standalone `run_qa.sh` does NOT grep SCRIPT ERROR; the sweep does. A
  standalone green can hide a runtime error — the sweep + exit-code-aware
  unit bar is the only real bar.
- New QA scripts need ALL THREE: `qa/manifest.json` entry + `AGENTS.md`
  seed-table row + `python3 scripts/render_qa_notes.py --write`
  (surfaces via `python3 scripts/derive_qa_surfaces.py` from
  wandering_inn_game/). CI has separate drift checks for each.
- `payload_contains` option lists are EXACT-list matches; adding one
  option to a pinned node reds every pinning script. Driver timeout
  failures print subset + cursor — read them before seed-shopping.
- Reverting a shared file (`git checkout -- <file>`) wipes SIBLING
  uncommitted hunks in it — `git diff <file>` and name every hunk first.
- Dialogue QA jumps to the LAST page by contract; scripts testing paging
  set `"qa_real_paging": true`. Dialogue `cancel` is NOT a dialogue
  action — it opens the pause menu over everything; close conversations
  via an end option.
- `once_per_waking` gates a whole prop; `gold_once_per_waking` caps only
  the payout (the Helper curve NEEDS unlimited clean counts — work_loop
  pins it). Both reset at sleep via `entity_first_use`.
- Shipped-JSON appends go through `wandering_inn_game/scripts/splice_json.py`
  (format-preserving); whole-file json.dump churns hundreds of lines.
- Controller shell: never `cd` into worktrees; absolute paths (CWD drift
  has misrouted edits twice).

## Progress (2026-07-19, wave day 1 — one Fable session)
DONE: **#194a COMPLETE** (PRs #227/#228/#229 — WIInteractions, WISleepBeat,
WICombatBanking; byte-identity-proven each). **#211 SHIPPED FLAG-ON**
(PR #230 — weight×decay×grants, power_level ×53, save v7, 12-canonical
re-derivation; leveling-feel entry in HANDOFF taste queue). #111 SPEC on
main + go/no-go on the issue. CHOICE-LOG carries all adjudications.
NEXT (charter order): #194b world.gd seams, then lanes b/c are OPEN
(a1 dependency met) — b1 Rags design is the next Fable-class package;
a3/a4 mobile + c1 art batch delegatable per the model directive.

## Definition of done
All 18 wave packages merged or explicitly deferred with CHOICE-LOG
rationale; #196–#214 user notes all closed or rolled into packages;
v0.13.0 tagged with all three deploy targets green; wave retrospective
appended to CHOICE-LOG; this file updated or retired.
