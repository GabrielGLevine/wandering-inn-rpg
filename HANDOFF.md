# Wandering Inn RPG handoff

Current state only. GitHub Issues/Milestones own scheduling; merged PR bodies
own per-issue narrative; `docs/CHOICE-LOG.md` indexes durable rulings; git owns
history. Read through `wi-start-here`.

Insertion: head. Replace current facts in place. Do not add dated `DONE`,
archived, or superseded session blocks.

## Current state

- **Active program (user, 2026-10-07), in order:**
  1. DONE: #590 (PR #594) and #591 (PR #595) closed; #513's fee shortfall,
     delivery toast and daily standing delivery merged (PR #598). Follow-ups
     #596 (bounty turn-in toast) and #597 (toast over tall panels).
  2. DONE: #514 gear rules (PR #601; closes #494/#495). #495's balance effect
     is unmeasured by the harness; follow-up #599.
  3. IN PROGRESS (user approved a third concurrent lane, 2026-10-08):
     - #453 environmental rest signposting: `/private/tmp/wi-453-rest`.
     - Pallass art (PixelLab trader, Garuda and Dullahan residents):
       `/private/tmp/wi-pallass-art`.
     - Pallass content ("Room on the Row" plus re-themes of `forge_tier_permit`,
       `tempered_standards`, `ledger_eats_first`) with placeholder sprites:
       `/private/tmp/wi-pallass-content`. Journey re-pins wait for the rest lane;
       real sprite ids swap in after the art lane. Heavy runs are staggered
       (`WI_SWEEP_JOBS=3`).
     Design docs: `docs/design/453-rest-signposting.md`, `513-pallass-income.md`.
     A third floodplains quest: not now. Runners' Post: #600.
  Each issue closes through its own PR after independent review and CI.
- **Recovery cutover is done:** #571 and #512 closed by PR #592 (`17d635f8`).
  Carried HP/MP has no switch. Five continuous journeys (martial, Rogue,
  caster, worker, imperfect) are a `journey` manifest tier, gated nightly by
  `qa/journey_gate.py` against `qa/journeys.json`; ledgers live in
  `docs/design/571-ledger-*.md`, the plan and criterion map in
  `docs/design/571-cutover-execution.md`. Linux CI runs journeys ~8x slower
  than local macOS; budgets and `timeout_sec` are CI-measured.
- **Open findings to carry:** #453 depleted chokepoints (ruled: signpost rest,
  no tuning); #513 remaining Pallass content and gear-affordability audit
  (`docs/design/513-low-gold-recovery.md`, `571-fee-audit.md`); #515 criterion
  4 (automated geometry/capture checks); #586 shutdown leak (exact lines
  deferred via `qa/noise_scan.sh`, leak still open).
- **#566–#570 stay open:** PR #578 used Refs. Reconcile each against #592's
  journeys and close what is met; device/human items move to #585/#516. The
  plan is `docs/design/2026-10-05-persistent-vitals-recovery-plan.md`; preserve
  unlimited existing kitchen access and measure it.
- **M1 mobile:** software merged through PR #551; #504/#505/#506/#510/#253/#511
  stay open only for physical iPhone Safari/Android Chrome and unfamiliar-player
  observations, deferred to #585 by the user. Prepared candidate:
  `/private/tmp/wi-m1-candidate-93016f0b/` (PCK `cccbe5f4…`); checklist
  `wandering_inn_game/qa/M1-OBSERVATIONS.md`; evidence `/private/tmp/wi-m1-evidence`
  and `/private/tmp/wi-m1-audio-stale-negative-93016f0b`. Purchases must confirm
  before any gold or item effect commits (#504, P0).
- **Constraints:** core work first; no balance or seed changes except the ruled
  #514 re-window, and re-measure on current builds rather than repeating stale
  win rates. No engine probes/builds, release, deployment, outreach or
  recruitment. Web parity may be waived as a merge bottleneck; other CI and
  review stay required.
- **Compiler (#434/#438):** work stays bounded to acceptance repairs. The
  compiled Acts I–III route last ran at seed 37 before carried HP/MP; Acts
  IV–V carried-resource pins are runtime-only, and current residue is in
  `scripts/itinerary/README.md`. #452/#348 addenda must be reconciled with
  current code before executing their remaining work.
- **Parked work:** #584 audio staging docs in `/private/tmp/wi-584-audio` and
  `stash@{0}` ("584-staging-docs"); an unverified #397 cadence partial in
  `stash@{1}`. Open presentation debt lives in `docs/VISUAL-LOG.md`.
- Preserve the untracked `wandering_inn_game/tests/test_companion_counter.gd.uid`
  and the private asset overlays.
- Latest release recorded by the repository: **v0.20.0** (2026-08-14).
  `docs/RELEASE-HISTORY.md` indexes earlier releases.

## User-held

- **#485** coverage sets and first-order names have GO; only specific
  unresolved names, unproposed mappings or post-bar exceptions need a decision.
- **#452** doctrine/spec ratification and **#347** dynamic unique classes keep
  their user gates; #347 is deferred.
- **#584 audio:** music adds and the swish-on-miss change need an explicit ear
  verdict; new footsteps, beds and foley are ear-checked in place (acceptance 5)
  through a prepared playtest state.
- **#19:** any paid Steam path needs pirateaba's explicit permission.
- Human and real-device milestone gates stay open until actually observed. No
  numeric progression UI, new canon or doctrine exception is authorized merely
  by a roadmap issue.

## Queue

Live index: [Roadmap #502](https://github.com/GabrielGLevine/wandering-inn-rpg/issues/502)
and its milestones. Work by milestone, then priority and stated dependencies;
`successor-ready` means a brief can start. Refresh issue comments and
CHOICE-LOG before treating an old hold as a current blocker.

## Commands and environment

```sh
gh issue list -R GabrielGLevine/wandering-inn-rpg --state open
/usr/local/bin/godot --path wandering_inn_game          # play
scripts/preflight.sh --full                             # units + tools
wandering_inn_game/qa/run_qa.sh load_gate headless
wandering_inn_game/qa/ci_sweep.sh                       # full canonical sweep
python3 wandering_inn_game/qa/journey_gate.py           # continuous journeys
python3 scripts/journey_ledger.py <qa_output>/<script>/events.jsonl
python3 scripts/sync_agent_guidance.py --write
python3 scripts/render_qa_notes.py --write
```

- Local engine **4.7-stable (5b4e0cb0f)**; CI pins **4.7-stable** (#529).
- macOS has no `timeout`; use the alarm wrapper. Shell stays Bash 3.2-safe,
  and zsh does not word-split unquoted variables in loops.
- Windowed QA serializes. Reruns replace `qa_output/`; a full sweep flushes it.
- Godot 4.7 web export templates and Playwright are installed locally, so
  `qa/web/run_web_qa.sh` and `qa/web/run_browser_suite.py` run here.
- A new lane worktree needs the private overlay copied
  (`git ls-files --others --ignored --exclude-standard wandering_inn_game/assets`)
  and a Godot `--import` pass before QA.
- Licensed overlays and `potential_assets/` stay local; never commit them.
  Backup: the private `potential-assets-v2` release.
