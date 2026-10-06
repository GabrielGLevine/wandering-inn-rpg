# Wandering Inn RPG handoff

Current state only. GitHub Issues/Milestones own scheduling; merged PR bodies
own per-issue narrative; `docs/CHOICE-LOG.md` indexes durable rulings; git owns
history. Read through `wi-start-here`.

Insertion: head. Replace current facts in place. Do not add dated `DONE`,
archived, or superseded session blocks.

## Current state

- **#512 route checkpoint, ready for controller composition:**
  `issue/512-route-recon`, `/private/tmp/wi-512-routes`, dispatch7429cd62.
  Owned scope: QA routes/manifest/generated notes/docs only; no gameplay edits.
  Rogue3464 completes actual fresh creation→open ending→Inn epilogue:4gold,
 53HP/16MP,18sleeps,8victories/3defeats; real rollback/recovery retained.
  Earned58gold purchased set follows all required regional costs; exact ledger
  and artifacts are in docs/design/512-continuous-journeys.md.
  Final log: /private/tmp/wi-512-evidence/current/rogue-ending2.log; archived
  rogue-full-ending-current has result/events/checkpoints. Exit0/PASS but
 5shaderRID ERRORs make the authoritative gate INVALID. No full-route window
  or physical-touch claim. Root/capacity570 own lifecycle investigation.
  Worker bounded recovery: free chest armor/rest earns Mage4, then eligible
 Zevara3+4→Traveler5 and seventh sleep earns Diplomat6. Both retries lose
 round6 with boss10HP. Final1302 atc2d5a964 PASS/exit0 but2shaderERRORs INVALID;
 exact rollback3gold/50HP15MP/1HotMeal, five defeats/three victories. Evidence
 worker-bounded-final-journey_worker + matchinglog under current evidence.
 load_gate2/combat_abandon54 clean; lint/derived/notes pass.
 **Next:** root composes current UI/renderer fix for clean replay/window.
 Tree released, no active process; no further attempts/farming/production/
 native changes. Preserve companion UID.

- **User-directed resumption:** finish art-blocked roadmap work, checkpoint often.
  Art577 merged0bbd96aa; reviewed e89770de/squash share tree0e843291.
  Original art checkout remains separately owned and untouched.
- **User CI permission:** bypass Web parity when it bottlenecks PR merges;
  record each waiver without calling it a pass. Other CI/review and actual
  gameplay/device evidence remain required.
- **Designs closed:** #517/PR575 squash5823356f/treee3203d51; #521/PR579
  squash53bd4c68/tree95341cea. Reviewed/squash trees match; seven non-Web CI
  jobs passed and Web was sole waived blocker. Runtime stays #518/#520/#522.
- **Staged resources:** #566/PR57285af0621, #567/PR5780e55e381,
  #570/PR5738676a0be. Carry/HUD/capacity have bounded review. All59Godot units
  pass; four lint pins fixed,282Python/109subtests pass. Both full combat
  policies pass atdcac4795. Final canonical pending. Native40images read.
  No partial activation before recovery/#571. Physical devices unproven.
- **Integration:** root owns `/private/tmp/wi-567-hud-contract`. Latest reported
  checkpoint c4b00465 fixes phone opening-touch cancel and hotbar name/AP
  overlap; independent review and both browser poison67 routes pass. Root
  full gates/window rotation remain active; physical devices remain unproven.
  This QA tree has earlier composed frontend3bd7f529 and warning198a7711,
  plus driver ff6b8741/e48edf4c. Recompose before final acceptance.
- **Owners:** resource_plan releases #512 QA tree after this checkpoint.
  Capacity570 owns isolated shader-lifecycle diagnosis; root owns shared
  integration/windows. Core568206f36ac and56991bdac25 are earlier committed
  work, not active source ownership here. Preserve private overlays, local
  node_modules/.gdignore, companion UID and the original art worktree.
- **#565 accepted plan:** `docs/design/2026-10-05-persistent-vitals-recovery-plan.md`
  governs #566–#571. Preserve unlimited existing kitchen access and measure it.
  M1 devices and #494/#495 choices remain open.

- **M1 software:** PR551 merged6148d1e5, reviewed tree78200963. Software
  checks passed; physical iPhone/Android and unfamiliar-player evidence stay
  open under #511. Original evidence and provenance remain in PR551. No release
  or outreach is authorized by this route task.
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
