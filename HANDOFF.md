# Wandering Inn RPG handoff

Current state only. GitHub Issues/Milestones own scheduling; merged PR bodies
own per-issue narrative; `docs/CHOICE-LOG.md` indexes durable rulings; git owns
history. Read through `wi-start-here`.

Insertion: head. Replace current facts in place. Do not add dated `DONE`,
archived, or superseded session blocks.

## Current state

- **Regional kits (#606).** User, 2026-10-08: "write all plans and execute without further approval".
  - Spec: `docs/superpowers/specs/2026-10-08-regional-kits-design.md`. Plans: `docs/superpowers/plans/2026-10-08-regional-kits-*.md`.
  - Ledger: `.superpowers/sdd/2026-10-08-regional-kits-rollout/progress.md`.
  - Rules:
    - Pool first, starting from `docs/kits-allocation.md`; gaps go to `docs/art-generation-list.md`.
    - A region closes only on a blind Fable read (§5.2). Read dusk/night views when ambience is phase-gated.
    - G2 counts art identity (#625): a regional pin must be exclusive *art*, not just a new sprite id.
  - Done: #607 (PR #609); #608 Invrisil (PRs #614, #619); #621 bundle-v8 + allocation (PR #622); #623 art-identity G2/G3 + `_common` guardrails (PR #625); #624 intake coverage (PR #626); 31-kind labels (PR #627); re-intake allocation, 618 pieces (PR #628); **#620 Liscor R1 (PR #630, `56dd2573`; G2 art: Liscor 68.83%, Invrisil 56.92%)**. Fetch bundle-v8 before QA in main (`scripts/fetch_private_assets.sh`).
  - User decisions, 2026-10-09 (CHOICE-LOG): all four design-led cuts are YES for now (Liscor sandstone-brick wall/gate + brick ground storey + shingle roofs from existing art; window night-glow overlay; Pallass lamp = `crystal_lamp` + glow cone; Invrisil alley workbench -> cargo-yard cluster). Earlier rulings: global allocation; `_common` Tier A utility props only, 30% cap; design-led gap pass before any generation.
  - Next, in order:
    1. #629: Liscor identity build-out (decision 1), bundle-v9 (24 sheets), Liscor-only waystone alias, inn-table duplicate art, official dirt seams (N6).
    2. `_common` Tier A pool population, then R2 (underground) per the rollout plan.
    3. #610 generation batch, deferred: firm list is 4 items (Antinium worker rig, owned cold wall lantern, owned stool, second owned street door). Needs PixelLab renewal + user approval.
  - Restart backup: `.superpowers/restart-backup-2026-10-09/` (scratchpad, art evidence, WIP worktree patches; `README.md` restore steps; `FRESH-SESSION-PROMPT.md`). Remaining worktrees are WIP and backed up: `wi-584-audio`, `wi-art-public`, `wi-browser-ready`. If a reboot wipes `/private/tmp`, run `git worktree prune` and restore from the README.
  - Lessons:
    - Writing tools take `--repo-root <worktree>` only.
    - Capture scripts hard-code `official` in output names; public recaps rename via `recap-*.sh`.
    - Run `pytest -q scripts/` before every push: CI's scope; journey re-routes shift itinerary pins and map edits need a G3 regen.
    - Never `git stash`: the stash is shared across worktrees.
  - Skill-library proposal, for Fable to apply to `wi-art-and-sprites`:
    - the intake -> `fill_kit` -> `wire_asset` pipeline;
    - running slicing from the main checkout;
    - the intake coverage gate (#624).
- Pre-existing debt: pytest warnings come from `Image.getdata` in `data_lint.py`, which Pillow 14 removes, and from unclosed files in `harness_metrics.py:58`.
- **Active program (user, 2026-10-07), in order:**
  1. DONE: #590 (PR #594) and #591 (PR #595) closed; #513's fee shortfall,
     delivery toast and daily standing delivery merged (PR #598). Follow-ups
     #596 (bounty turn-in toast) and #597 (toast over tall panels).
  2. DONE: #514 gear rules (PR #601; closes #494/#495). #495's balance effect
     is unmeasured by the harness; follow-up #599.
  3. DONE (2026-10-08): #453 rest signposting (PR #602, `06eea743`); Pallass
     resident art (PR #603, `1c364227`); Pallass "Room on the Row" plus three
     quests re-themed off paperwork (PR #604, `038caf8a`). #453 and #513 stay
     open (per-spine verification; gear audit and worker band). Follow-ups:
     #605 (lead proxy → `wool_trade_started` at next freeze), #600 (Runners'
     Post). Visual debt in `docs/VISUAL-LOG.md`: bedrolls, arrows-in-turf,
     opened containers, the bend jig, the stocked shelf, Dullahan occlusion.
  Each issue closes through its own PR after independent review and CI.
- **Recovery cutover is done:** #571 and #512 closed by PR #592 (`17d635f8`).
  Carried HP/MP has no switch. Five continuous journeys (martial, Rogue,
  caster, worker, imperfect) are a `journey` manifest tier, gated nightly by
  `qa/journey_gate.py` against `qa/journeys.json`; ledgers live in
  `docs/design/571-ledger-*.md`, the plan and criterion map in
  `docs/design/571-cutover-execution.md`. Linux CI runs journeys ~8x slower
  than local macOS; budgets and `timeout_sec` are CI-measured.
- **Open findings to carry:** #453 per-spine verification (rest signposting
  shipped in #602; no tuning); #513 gear-affordability audit and the worker
  under band at Act III (`docs/design/513-low-gold-recovery.md`,
  `571-fee-audit.md`); #515 criterion 4 (automated geometry/capture checks); #586 shutdown leak (exact lines
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
  and zsh does not word-split unquoted variables in loops; write `${rev}:path`
  in zsh, since `$rev:w…` is read as a history modifier.
- PixelLab's subscription lapsed 2026-10-06. #603 was paid from prepaid credit
  via the REST API ($0.40; $0.05 left). More art needs a renewal (user purchase).
- Skill-library proposals (for Fable): document the QA-only `stage_sprite`
  action in the QA DSL reference; record the PixelLab REST credit route and
  its one-job concurrency limit in `wi-art-and-sprites`; trap for scene work:
  dialogue separation pushes the NPC away from the player, so keep props off
  an NPC's cardinal axes or the NPC hides behind them (#604).
- Windowed QA serializes. Reruns replace `qa_output/`; a full sweep flushes it.
- Godot 4.7 web export templates and Playwright are installed locally, so
  `qa/web/run_web_qa.sh` and `qa/web/run_browser_suite.py` run here.
- A new lane worktree needs the private overlay copied
  (`git ls-files --others --ignored --exclude-standard wandering_inn_game/assets`)
  and a Godot `--import` pass before QA.
- Licensed overlays and `potential_assets/` stay local; never commit them.
  Backup: the private `potential-assets-v2` release.
