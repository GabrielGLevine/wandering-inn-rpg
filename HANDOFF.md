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
- **M1 has actionable work.** #503's diagnostic matrix/touch baseline and
  #477's schema-reader fixes remain delivered. #505/#506/#510 are ready for
  scoped audits and repairs; missing phones hold physical acceptance, not
  repair dispatch. #507 can progress independent guidance while preparing
  any unresolved presentation choice. Follow the
  [execution contract](https://github.com/GabrielGLevine/wandering-inn-rpg/issues/502#execution-contract).
- **Reopened acceptance corrections:** #504 needs actual browser-touch
  purchase proof; #508 needs fight-first/force-crate recovery, fresh Watch
  acquisition, and accurate stealth-break guidance; #509 needs production
  timing and real queued-message/modal proof; #253 needs target-device/itch
  import verification. Preserve useful implementations from PRs #535–#537;
  merged partial work does not satisfy their missing criteria.
- **#434 completion evidence is blocked by #542/#543 corrections.** #542
  repairs golden event-history/checkpoint and terminal-movement false
  positives; #543 repairs bypass predictions for warded encounters. At
  reviewed base `5d93e48f`, Act I still lacked a hotbar assertion. Act II's
  earlier zero-residue report must be remeasured with the repaired comparator.
  M3.6 remains unmet; do not follow the superseded automatic Act III→V queue
  or advance M4. Coordinate an active owner's safe checkpoint before edits;
  ordinary route authoring remains possible with existing tools.
- Real-device columns of `qa/MOBILE-PARITY.md` stay UNTESTED until hardware
  observations (#511). CI's web-parity job had been a silent no-op since it
  was written; it now runs for real (combat parity, touch smoke, save port).
- Local dev env now has Godot 4.7.2 web export templates + Playwright, so
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

- **#507 presentation reconciliation affects only the disputed placement.**
  Continue staged guidance and prepare concrete rendering options before
  requesting any necessary reversal. The issue asks to name every creation
  choice and add difficulty descriptions, but (a) "Playtest hotfix #3" removed race/gender labels from
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

1. #508 recovery/acquisition, #504 browser-touch purchases, and available
   #253 target-environment reproduction/verification.
2. #505 layout, #506 continuous touch flows and #510 critical lifecycle;
   #503's prerequisite is satisfied. Serialize shared UI/core files.
3. #509 production-timing/modal evidence and #507 independent guidance.
4. #511 shared physical-phone observations and composed unfamiliar-player
   acceptance; observations can feed implementation issues before final verdict.
5. Bound compiler work to a safe checkpoint and #542/#543 acceptance repairs
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

- Current local engine reports **4.7.2**; CI pins **4.7-stable**. Toolchain
  alignment is tracked in #529; report actual version with evidence.
- macOS has no `timeout`; use the documented alarm wrapper. Shell scripts
  must remain compatible with Bash 3.2.
- Windowed QA serializes. Reruns replace their `qa_output/` evidence; a full
  sweep flushes prior artifacts. Headless warnings/errors require triage.
- Licensed overlays and `potential_assets/` are local-only; never commit them.
- Provider capacity fails soft when telemetry is unavailable. Roles and
  exact file ownership govern dispatch, not historical provider assignments.
