# Wandering Inn RPG handoff

Current state only. GitHub Issues/Milestones own scheduling; merged PR bodies
own per-issue narrative; `docs/CHOICE-LOG.md` indexes durable rulings; git owns
history. Read through `wi-start-here`.

Insertion: head. Replace current facts in place. Do not add dated `DONE`,
archived, or superseded session blocks.

## Current state

- **Active #566 foundation (separate from #564 art):** owner is this Codex
  session; worktree `/private/tmp/wi-566-foundation`, branch
  `issue/566-persistent-vitals-foundation`, base `b1c4b02b` (origin/main).
  Authorized slice: pure resource state, shared maxima, explicit PC battle
  initialization, sleep ordering, versioned saves and contract tests.
  Owned paths: `wandering_inn_game/src/core/{wi_game.gd,combat_build.gd,save.gd,vitals.gd}`,
  `wandering_inn_game/src/core/combat/wi_combat.gd`, new
  `wandering_inn_game/tests/test_vitals*.gd` and their UIDs, the version pin
  in `tests/test_save.gd`, this worktree's
  HANDOFF and `docs/design/566-vitals-foundation.md`.
  Forbidden: art checkout, assets/maps/content, event/key catalogs,
  UI/world/combat presentation, `core/game.gd`, QA manifests/driver/generated
  outputs. No gameplay cutover or #566 closure in this slice.
  Next: red/green resource/save contracts, full units/canonical sweep/balance,
  independent review, draft PR using Refs #566. Shared presentation/autosave/
  terminal handoff acceptance remains for serialized follow-up and #571.

- **Recovery program #565:** #566–#571 own core, HUD, consumables, food,
  capacity and composed cutover. Plan:
  `docs/design/2026-10-05-persistent-vitals-recovery-plan.md`.
  Begin staged #566 and independent #570, serialize core/save/UI writers;
  #571 gates removal of battle refills. Three safe MP doses per waking,
  4 HP excess loss and resonance 4→5 are tuning proposals. M1 device gates
  and #494/#495 choices stay open. #564 owns the primary art checkout.

- **M1 software merged through PR #551:** squash `6148d1e5`, tree
  `78200963`. Reviewed branch `issue/506-touch-flow` head `83fc36ae`
  (standalone tree `5e8af12d`); QA/export source `93016f0b`.
  CI run `37355007466` passes all eight jobs on composed checkout `4f315958`,
  whose tree exactly matches the squash. Independent source and post-merge
  reviews approve. Incoming #552/#553 tooling and backup guidance are preserved.
  #507/#508/#509 are closed; #504/#505/#506/#510/#253/#511 and M1 stay open
  for their physical/actual-host/human criteria. Production is unchanged from
  the `ab279415` 36-case local browser baseline.
  PR #551 records final native/browser/audio evidence and causal fixes.
  Private candidate: `/private/tmp/wi-m1-candidate-93016f0b/m1-web-93016f0b.zip`,
  manifest and observation checklist alongside; PCK `cccbe5f4…`.
  Evidence: `/private/tmp/wi-m1-evidence`, private/public audio roots and
  `/private/tmp/wi-m1-audio-stale-negative-93016f0b`.
  Root's implementation tree is `/private/tmp/wi-m1-506`; final handoff only
  uses `/private/tmp/wi-m1-closeout`, based on merged main `6148d1e5`.
  Other lanes are integrated/idle. Preserve untracked node_modules/companion UID
  and the unrelated PixelLab note in the original main tree's dirty HANDOFF.
  **Exact next action:** collect #511 physical iPhone Safari/Android Chrome
  observations and three unfamiliar-player sessions with desktop reference,
  using the same private candidate and `qa/M1-OBSERVATIONS.md`. None supplied.
  OS keyboard/chooser/background/audio policy and actual itch remain unproven.
  No release/deploy/outreach/recruitment authorized. M1 stays open.
- Prior scoped M1 repairs (#504/#505/#508/#510) are merged through PRs
  #547–#550; PR #551 owns composed proof and cleared-road Rogue recovery.
  Physical acceptance remains open. Earlier evidence:
  `/private/tmp/wi-505-evidence`, `/private/tmp/wi-510-evidence`,
  `/private/tmp/wi-508-evidence/composed`. Do not rerun completed software
  closure solely because device observations are outstanding.
- Current roadmap: [#502](https://github.com/GabrielGLevine/wandering-inn-rpg/issues/502). Five outcome milestones prioritize
  mobile parity and a clear opening, progression trust, a living inn/world,
  tactical identity, and an accessible reliable release candidate.
- User-confirmed mobile targets: **iPhone Safari and Android Chrome**,
  compared with desktop. Rogue discovery is a priority; purchases require
  explicit confirmation before any gold or item effects commit.
- **M1 local machine verification is complete.** #503 diagnostics and #477 schema
  readers remain delivered. The #506 issue PR records the composed software
  repairs for #507/#508/#509 and scoped #253/#510 evidence. Physical and human
  acceptance belongs to #511; keep device-dependent issues open until the
  named observations land. Follow the
  [execution contract](https://github.com/GabrielGLevine/wandering-inn-rpg/issues/502#execution-contract).
- **Remaining acceptance corrections:** #504 needs physical-device purchase
  observations; the M1 issue PR records #508/#509 software closure evidence.
  #253 still needs physical target-device/itch import
  verification. Preserve useful implementations from PRs #535–#537;
  merged partial work does not satisfy their missing criteria.
- **Compiler corrections in PR #545:** comparator #542 preserves event-history
  mode, checkpoint order, movement tails, and single-use facing-bump credit;
  #543 obtains bypass credit and waking/ward state from real sim projections.
  Unknown-clock phase-sensitive crossings fail explicitly. Act III route
  authoring and dialogue/post-fight pins are retained; no gameplay rules changed.
  Current authored slice residue is Act I **1 exact / 0 net** (missing hotbar
  assertion), Act II **1 exact / 0 net** (Mage-toast history-mode mismatch),
  Act III **0 / 0**. The compiled 1,077-step Acts I–III route passes at seed 37.
  #434 remains open for those claims, later acts, and caster acceptance; M3.6
  and M4 are not complete. Resume actionable M1 work before more act expansion.
- Real-device columns of `qa/MOBILE-PARITY.md` stay UNTESTED until hardware
  observations (#511). CI's web-parity job had been a silent no-op since it
  was written; it now runs for real (combat parity, touch smoke, save port).
- Local dev env now has Godot 4.7 stable web export templates + Playwright, so
  `qa/web/run_web_qa.sh` runs here.
- Preserve pre-existing untracked `wandering_inn_game/tests/test_companion_counter.gd.uid`.
- Latest release recorded by the repository: **v0.20.0** (2026-08-14).
  Shipped IDs and asset manifests remain their own authorities; this roadmap
  does not cut a release or alter gameplay.
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

- **#494 resonance semantics** and **#495 gear damage/scaling semantics** need
  explicit recorded choices. Their post-tag scheduling hold has elapsed;
  roadmap authorization does not select a model. Implementation is #514.
- **#485's six coverage sets and proposed first-order names already have GO**
  (August comments and CHOICE-LOG). The blanket hold is removed. Inventory
  shipped versus remaining authorized work; only specific unresolved names,
  unproposed mappings or post-bar exceptions need a new decision. Parked
  pairs remain loss-proof until coverage exists; do not wait on all #452 tooling.
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

1. #511 shared physical-phone observations and three unfamiliar-player sessions
   with desktop reference. The owner retained these gates and offered results;
   no observations have arrived. Software repairs and automated gates are done.
2. Diagnose supplied observations against the same candidate; close only the
   corresponding #504/#505/#506/#510/#253 physical/actual-host criteria that
   pass. A failed observation may authorize a scoped repair in its issue.
3. Bound compiler work to a safe checkpoint and #542/#543 acceptance repairs
   before further equivalence claims. No new compiler expansion wave ahead
   of actionable M1 work without a concrete dependency or owner reprioritization.

Later milestones and dependencies are linked from the index. Respect
`roadmap:blocked` and `taste-gate`; `successor-ready` means a brief can start,
not that a later milestone outranks current P0 work.

#524/#528 are dependency-ready but remain M4/M5 work. Refresh issue comments
and CHOICE-LOG before treating historical approval holds as current blockers.

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

- Current local engine reports **4.7-stable (5b4e0cb0f)**; CI pins **4.7-stable**. Toolchain
  alignment is tracked in #529; report actual version with evidence.
- macOS has no `timeout`; use the documented alarm wrapper. Shell scripts
  must remain compatible with Bash 3.2.
- Windowed QA serializes. Reruns replace their `qa_output/` evidence; a full
  sweep flushes prior artifacts. Headless warnings/errors require triage.
- Licensed overlays and `potential_assets/` are local-only; never commit them.
  Backup: private `potential-assets-v2` release.
- Provider capacity fails soft when telemetry is unavailable. Roles and
  exact file ownership govern dispatch, not historical provider assignments.
