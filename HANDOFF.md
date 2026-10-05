# Wandering Inn RPG handoff

Current state only. GitHub Issues/Milestones own scheduling; merged PR bodies
own per-issue narrative; `docs/CHOICE-LOG.md` indexes durable rulings; git owns
history. Read through `wi-start-here`.

Insertion: head. Replace current facts in place. Do not add dated `DONE`,
archived, or superseded session blocks.

## Current state

- **M1 software candidate (#506 primary):** PR #551, `issue/506-touch-flow`,
  base `2d1830a9`; current QA source `93016f0b`, tree `5e90899f`.
  Owner-approved #507 creation/footer/difficulty and #508 cleared-road cover,
  #509 bark ownership, #253 import ownership and #510 scoped probes are composed.
  Production is unchanged from `ab279415` (36 local browser cases pass).
  First CI `0154a281`: browser 20 pass/6 fail from CDP latency/Erin timing.
  `082a42dd`: 21 pass/5 fail from queued drag bursts. `ee9ecad6` awaits
  touchStart delivery before pacing moves; ten focused local cases pass.
  CI `fec91f7f` passes all 26 registry cases and seven other jobs, but its
  newly reached input/audio probe expects absent licensed title music.
  `93016f0b` retains title/name context-state checks and requires actual game
  output after suspension + trusted Pause using committed SFX. Eight local
  private/public direct/iframe cases pass (31 steps each). Capture excludes
  control/suspended taps and flushes pre-resume analyser history. A retained-
  waveform/zero-fresh-output negative rejects the old sampler's false green.
  Four-second contact deadline, 80 ms drag proof and RMS thresholds are intact.
  Web CI job allowance is 60 minutes; prior run reached audio at 42 minutes.
  Native/units/balance evidence retains its original source; PR owns exact-head
  CI, independent final review, per-criterion proof and squash tree identity.
  Evidence: `/private/tmp/wi-m1-audio-private-93016f0b`, public counterpart,
  `/private/tmp/wi-m1-audio-stale-negative-93016f0b`,
  `/private/tmp/wi-m1-browser-drag-start-ee9ecad6` and `/private/tmp/wi-m1-evidence`.
  Root owns `/private/tmp/wi-m1-506` and public audio verification tree;
  other lanes are integrated/idle. Preserve untracked node_modules/companion UID
  and the unrelated PixelLab note in the original main tree's dirty HANDOFF.
  Next acceptance: #511 physical iPhone Safari/Android Chrome and three
  unfamiliar-player sessions with desktop reference; none supplied. OS keyboard,
  chooser/background/audio policy and actual itch remain unproven. Use
  `wandering_inn_game/qa/M1-OBSERVATIONS.md` with the private manifest
  (PCK `cccbe5f4…`). No release/deploy/outreach/recruitment authorized.
  M1 stays open pending physical and human results.
- **#505 scoped layout repairs merged through PR #550:** main `2197088a` is
  tree-identical to reviewed `81e66d29`. Independent source/visual review and all
  eight CI checks pass, including 259 canonical scripts, both balance policies,
  all 16 browser cases and lifecycle checks. Phone combat proves actual tutorial More, complete roster pages
  and live shrinking. The WebGL turn-marker defect is repaired without weakening
  diagnostics. Evidence: `/private/tmp/wi-505-evidence`. Keep #505/#511 open for
  physical iPhone Safari and Android Chrome acceptance.
- **#510 scoped recovery merged through PR #549:** main `0ac059a8` is identical
  to the reviewed tree; all eight CI checks pass. Continue skips unreadable
  newer saves. Both browser profiles prove actual reload of a completed durable
  manual save and subsequent touch input, plus explicitly injected malformed-save
  recovery with valid bytes preserved. Keyboard, audio, genuine backgrounding,
  itch and physical lifecycle acceptance remain open. Evidence: `/private/tmp/wi-510-evidence`.
- **#508 scoped work merged through PR #548:** reviewed tree and all eight CI
  checks pass at `6f188bbc`. Fresh Watch earns wages, buys the classless route,
  returns home and gains Rogue at sleep. Drainage, Watch, stealth-break and
  production-timing proof pass on desktop and both emulated phone profiles.
  Evidence: `/private/tmp/wi-508-evidence/composed`. Physical evidence is open.
  The owner-approved cleared-road crossing recovery is implemented on the
  M1 candidate; no enemies respawn. The issue PR records final verification.
- **#504 delivered through PR #547** (`e5b53328`; narrative in the PR body).
  Open only for physical iPhone Safari / Android Chrome observations (#511).
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

- Current local engine reports **4.7-stable (5b4e0cb0f)**; CI pins **4.7-stable**. Toolchain
  alignment is tracked in #529; report actual version with evidence.
- macOS has no `timeout`; use the documented alarm wrapper. Shell scripts
  must remain compatible with Bash 3.2.
- Windowed QA serializes. Reruns replace their `qa_output/` evidence; a full
  sweep flushes prior artifacts. Headless warnings/errors require triage.
- Licensed overlays and `potential_assets/` are local-only; never commit them.
- Provider capacity fails soft when telemetry is unavailable. Roles and
  exact file ownership govern dispatch, not historical provider assignments.
