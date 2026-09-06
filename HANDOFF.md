# Wandering Inn RPG handoff

Current state only. GitHub Issues/Milestones own scheduling; merged PR bodies
own per-issue narrative; `docs/CHOICE-LOG.md` indexes durable rulings; git owns
history. Read through `wi-start-here`.

Insertion: head. Replace current facts in place. Do not add dated `DONE`,
archived, or superseded session blocks.

## Current state

- Current roadmap: [#502](https://github.com/GabrielGLevine/wandering-inn-rpg/issues/502). Five outcome milestones prioritize
  mobile parity and a clear opening, progression trust, a living inn/world,
  tactical identity, and an accessible reliable release candidate.
- User-confirmed mobile targets: **iPhone Safari and Android Chrome**,
  compared with desktop. Rogue discovery is a priority; purchases require
  explicit confirmation before any gold or item effects commit.
- **M1 wave 1 landed** as train PR #535 (`5493bbfe`, 2026-09-06): #504
  purchase confirmation, #503 mobile parity matrix + real-touch QA tier,
  #477 gained_by any-arm readers, #253 web Import Save. Per-issue records:
  PRs #531–#534 (closed as superseded). Agent merges work as a BARE
  `gh pr merge …` (the allow rule is prefix-matched; no `cd` prefix).
- **#508 landed** (PR #536, `067cf95f`): leads for both classless entries,
  Krshia's Watch pointer, bypass toast, first-[Stealth] pointer, and the
  COMPILED fresh-save route `rogue_discovery_cut_route` (the itinerary planner
  models cover-served and sneaking band crossings). Dialogue prose corpus sits
  ONE word under the 24.5k+5% tripwire — the next dialogue edit trims elsewhere
  or re-baselines.
- **#509 landed** (PR #537): the arrival bark was rendering UNDER FieldHotbar's
  readout (same layer, 81% overlap) — line panel moved to the toast layer and
  `assert_dialogue_displayed` now measures occlusion; 1.2s readable floor
  before a movement dismiss (0 under QA); `game_saved` + hint-ribbon "Saved"
  pill; `message_lifecycle_loop` canonical; two VISUAL-LOG rows closed.
- **M1 dispatchable queue is now empty**: #507 waits on the label ruling
  below; #505/#506/#510 are `roadmap:blocked` on real-device findings; #511
  is the human gate. Real iPhone/Android observations remain the unblock.
- **#434 Act II at golden equivalence (PR #541 merged 2026-09-06).**
  Act II slice diff 0 exact / 0 net; compiled Act I-II runs green headless
  at seed 37 (729 steps). Act I residue: one shipped-only row (ambush
  `ui_hotbar_rendered {slots: 4}`). Read `scripts/itinerary/README.md`
  "Act II is at golden equivalence" before touching the emitter: a golden
  PASS is not a runtime PASS. NEXT (fresh branch off main): Act III
  authoring (shipped 559-~810) on `issue/434-act-iii`, `goldens.py
  --slices`, then Acts IV-V and the caster-variant acceptance. Session
  2026-09-06 ended on the usage guard (QUIESCE) right after the merge.
- Real-device columns of `qa/MOBILE-PARITY.md` stay UNTESTED until hardware
  observations (#511). CI's web-parity job had been a silent no-op since it
  was written; it now runs for real (combat parity, touch smoke, save port).
- Local dev env now has Godot 4.7.2 web export templates + Playwright, so
  `qa/web/run_web_qa.sh` runs here.
- Roadmap-session base: `main` at `7780925b`. Owned local housekeeping:
  `HANDOFF.md`, `docs/ROADMAP.md`, and the assessment's appended difficulty
  explanation finding in `docs/VISUAL-LOG.md`.
  Preserve pre-existing untracked `wandering_inn_game/tests/test_companion_counter.gd.uid`.
- Latest release recorded by the repository: **v0.20.0** (2026-08-14).
  Shipped IDs and asset manifests remain their own authorities; this roadmap
  does not cut a release or alter gameplay.
- Existing compiler **#434 M3.6 exit remains unmet**: golden residue is still
  the blocker for compiler M4. Read the current issue and `qa/STEEL-THREAD.md` before
  dispatch; do not restart from the original pre-implementation brief.
- #438 retains playthrough-engine/caster acceptance ownership. Oracle,
  checkpoints and pre-sim pieces #435/#436/#437 already shipped. New journey
  work can proceed independently using existing tools.
- #452 and #348 began as exploration/implementation briefs and now overlap
  shipped tooling/content. Their roadmap addenda require reconciling current
  code and merged PRs before executing only the remaining work.
- Open presentation debt lives in `docs/VISUAL-LOG.md`, including inn/HUD
  clearance, dialogue lifetime and pending sprite/icon/ear reads. Fresh
  captures under `qa_output/` are disposable; inspect before rerunning.
- GitHub repository milestones, issue labels and dependency links are updated.
  Projects v2 board synchronization was unavailable because the current token
  lacks `read:project`; no authentication settings were changed.

## User-held

- **#507 onboarding labels vs two standing rulings — needs your call before
  dispatch.** The issue asks to name every creation choice and add difficulty
  descriptions, but (a) "Playtest hotfix #3" removed race/gender labels from
  the picker cards on purpose (`char_creation.gd` PC_OPTIONS block: identity
  must read from the art) and (b) #447's one-voice ruling removed the
  difficulty descriptor tails, moving the explanation to the Settings Help
  page. Options: (1) keep both rulings, satisfy #507 with a single footer
  line under the selected card ("Human · woman — looks only; nothing
  mechanical") and a one-line difficulty blurb under the prompt ribbon on
  that step only; (2) restore card labels + descriptor tails (reverses both
  rulings); (3) leave creation as is and scope #507 to staged hints +
  discoverability only. Recommendation: (1) — it names the choice without
  putting text on the art and keeps the Help page the durable explanation.
- **#494 resonance semantics** and **#495 gear damage/scaling semantics** need
  explicit recorded choices. Their post-tag scheduling hold has elapsed;
  roadmap authorization does not select a model. Implementation is #514.
- **#485 consolidation coverage/naming** retains its six-set choice surface.
  Parked pairs remain loss-proof and inactive until approved coverage exists.
  Prepare from current inventory; do not wait on all remaining #452 tooling.
- **#452 doctrine/spec ratification** and **#347 dynamic unique-class scope**
  retain existing user gates. #347 is deferred beyond the committed outcomes.
- Prior class-specific balance flags and sanctioned tuning limits remain in
  #453 and `docs/CHOICE-LOG.md`. Re-measure against current builds rather than
  repeating stale win rates or assuming old walls still exist.
- **#19 commercial/distribution gate:** any paid Steam path requires
  pirateaba's explicit permission. M-STEAM remains separate from this roadmap.
- Milestone human/real-device gates remain open until actually observed.
  Unavailable hardware/testers do not prevent diagnostics and scoped repairs.
  No numeric progression UI, new canon, or doctrine exception is authorized
  merely by adding a roadmap issue.

## Queue

The live index and milestones are authoritative:

- [Roadmap #502](https://github.com/GabrielGLevine/wandering-inn-rpg/issues/502)
- [M1: mobile parity and first session](https://github.com/GabrielGLevine/wandering-inn-rpg/milestone/13)

Immediate dispatch order:

1. #504 purchase confirmation (independent).
2. #503 mobile parity matrix; publish findings to unblock repairs.
3. #508 fresh-save Rogue discovery and #477 schema-consumer repair.
4. #253 mobile import and #507 opening/creation guidance.
5. #505 responsive layout, #506 touch flows, #510 critical mobile lifecycle,
   and #509 message readability; serialize shared UI/core files.
6. #511 composed unfamiliar-player and real-phone acceptance.

Later milestones and dependencies are linked from the index. Respect
`roadmap:blocked` and `taste-gate`; `successor-ready` means a brief can start,
not that a later milestone outranks current P0 work.

## Commands and environment

```sh
# Queue
gh issue list -R GabrielGLevine/wandering-inn-rpg --state open
gh issue view 502 -R GabrielGLevine/wandering-inn-rpg

# Play
/usr/local/bin/godot --path wandering_inn_game

# Verification (choose exact gates through wi-verifying-changes)
scripts/preflight.sh --full
wandering_inn_game/qa/run_qa.sh load_gate headless
wandering_inn_game/qa/ci_sweep.sh
python3 scripts/sync_agent_guidance.py
python3 scripts/render_qa_notes.py
```

- Current local engine reports **4.7.2**; CI pins **4.7-stable**. Toolchain
  alignment is tracked in #529; report actual version with evidence.
- macOS has no `timeout`; use the documented alarm wrapper. Shell scripts
  must remain compatible with Bash 3.2.
- Windowed QA serializes. Reruns replace their `qa_output/` evidence; a full
  sweep flushes prior artifacts. Headless warnings/errors require triage.
- Licensed overlays and `potential_assets/` are local-only; never commit them.
- Provider capacity fails soft when telemetry is unavailable. Roles and
  exact file ownership govern dispatch, not historical provider assignments.
