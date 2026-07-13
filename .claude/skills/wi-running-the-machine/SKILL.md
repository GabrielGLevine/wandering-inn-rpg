---
name: wi-running-the-machine
description: Use when executing any Wandering Inn RPG task end-to-end — implementing a feature, fixing a bug, or working through a milestone plan — and when dispatching or judging reviewer subagents.
---

# Running the Machine (task execution process)

## The cycle (every task, no exceptions)
1. **Position:** read the ledger tail (`.superpowers/sdd/progress.md`) +
   HANDOFF, then the GITHUB ISSUE for the work item (planning transitioned
   2026-07-07: `gh issue view <n> -R GabrielGLevine/wandering-inn-rpg` —
   the issue body is the dispatch brief; the spec/plan it links is the
   design authority; execution briefs may correct stale plan text — briefs
   win). Work not on the board yet gets an issue FIRST (the issue-body
   format lives in any existing issue); close the issue in the landing
   commit's message (`Closes #n`) or via gh at the close.
2. **Implement** on `main`. Content = data (`data/*.json`); behavior = sim
   (`src/core/**`, PURE: no autoload/Node refs); presentation only renders.
3. **Verify green** — wi-verifying-changes. No claim without evidence.
4. **Review** — dispatch a reviewer subagent on the diff/commit (below).
5. **Fix wave** — apply Critical/Important findings, re-verify, re-review the
   fixes. Log Minors to the ledger for the milestone's final review.
6. **Commit** with a message explaining WHY; **ledger one entry** (what, how
   verified, lessons, what's next); keep HANDOFF live mid-session.

## Dispatching reviewers (they earn their cost only with method hints)
Prompt must include: the commit/range, "read wandering_inn_game/CLAUDE.md
first", the specific risk areas to TRACE (not read), and **method hints** —
"re-run script X at seed Y", "pixel-crop the region", "diff the actual
commit", "prove the assertion can fail". Ask for findings by severity with
file:line + concrete failure scenario.

**Misfire check before trusting any review:** a valid review used tools
(>0) and cites real files/lines. A boilerplate dump or generic praise = the
run misfired — do not act on it; re-dispatch once or defer that surface to
the milestone's whole-branch review (note it in the ledger).

## Milestone shape
Per-task reviews are necessary but not sufficient — every milestone ends with
a **whole-branch final review** (composed, cross-cutting; it has caught a
real ship-blocker every milestone) and then a **human playtest gate**.
Every milestone's F-task also runs a **visual-fix pass draining
`docs/VISUAL-LOG.md`** (user directive 2026-07-04) — text wrapping,
readability, font, and coordinate-tweaked layouts are solved problem
classes by now; new UI reuses shared components (UIChrome, hotbar), never
bespoke coordinates.
Playtest findings are directives: triage each into hotfix-now vs
milestone-scoped, record the triage in HANDOFF.

## Delegation ladder
- **IMPLEMENTERS = Claude (Sonnet) worktree lanes (user directive 2026-07-08
  evening, superseding the same-day Codex directive):** precise brief (files,
  constraints, verification commands), commit-on-lane-branch allowed,
  HEADLESS-only verification (controller does windowed reads), verification
  FOREGROUND alarm-wrapped except the full sweep (log-polling idiom).
- Codex 5.5 remains sanctioned when quota allows, with its sandbox
  constraints: cannot write `.git` (NO-COMMIT, controller stages from the
  lane's reported file list), cannot open windows, shell DNS blocked (no
  `gh`/PixelLab from inside). QUOTA LESSON (2026-07-08): concurrent
  high-effort lanes drain a ChatGPT-plan quota in MINUTES — Codex fits one
  bounded lane at a time, never a fan-out. Reviewers stay Claude-side
  regardless (the review chain is the check on the implementer).
- Mechanical, tightly-bounded, reviewer-covered (renames, fixtures, ports):
  cheap model (SiliconFlow Qwen; key `docs/siliconflow_api_key.txt`, never commit).
- Bounded implementation with judgment when Codex is unavailable: Sonnet
  subagent with a precise brief (files, constraints, verification commands,
  "do not commit").
- Design, sim-core semantics, canon, balance philosophy: do not delegate.
  **Implementation plans and specs ARE design** (lane/file-ownership/interface
  decisions live there) — top-model work even under budget pressure; delegate
  the source-digestion, never the plan authorship.

## Usage-aware pacing (user directive 2026-07-04)
The session has a fixed usage budget. Default the top model to orchestration
+ review; implementation goes down the ladder. Reassess at task boundaries:
burning fast → throttle top-model work, delegate more; budget to spare near
session end → upshift to higher-tier models and spend it. Same-file work is
still single-implementer: never run two agents on one file concurrently.
**Hard tiers (2026-07-12): run `scripts/usage_status.sh` before EVERY
lane/workflow/wave dispatch and at merge points — wi-usage-guard has the
tier checklists (CAUTION = no new dispatch, WINDDOWN = drain + commit
seams, QUIESCE = state-saving only, then wait-for-reset or weekly hard
stop). The PostToolUse hook injects tier CHANGES mid-flight; act on them
immediately.**
**Controller shell discipline: never `cd` into a lane worktree.** Build
review packages and inspect lanes via `git -C <worktree>`; every mutating
command (commit/merge/ledger append) runs from the repo root explicitly.
A drifted CWD has committed controller work onto a LANE'S branch
mid-review (2026-07-07, caught same-minute: cherry-pick to main +
`reset --hard` the lane tip was the recovery).
**A merge that delivers NEW `.gd` files needs a main-tree import pass
BEFORE the re-gate** (`--headless --import`): class_name registration
lives in the local `.godot` cache and the lane's import does NOT travel
with the merge — skipping it reads as a total-cascade compile failure
(64/64 red on a correct tree, 2026-07-07). Corollary: capture the
sweep's exit code explicitly and read the verdict line before pushing —
never pipe the sweep into `tail` inside the same `&&` chain as the push.
**Lane worktrees get the REAL asset overlay at dispatch (user directive
2026-07-07: placeholders are for the public repo only — local dev uses real
assets).** A fresh worktree has zero overlay files; the controller copies
every present `assets_manifest.json` path (+ `.import` sidecars) from the
main tree into each lane worktree right after spawn (gitignored — no commit
contamination). A lane producing SCREENSHOTS or visual deliverables on
placeholder art is producing WRONG deliverables (the #19 Steam-capsule lane
hit exactly this — its store shots needed regeneration).
Parallel lanes share ONE worktree: implementers must NOT commit (controller
stages per lane), and an implementer's uncommitted files are visible to every
other lane's test runs — if a task's artifacts can't validate until a later
task lands (e.g. dialogue referencing a not-yet-existing entity), PARK them
outside the tree (scratchpad) and land them with the dependency, or they
break parallel lanes' gates.

## Godot MCP — RETIRED (2026-07-06)
The godot-ai addon + MCP were removed from the repo (barely used; the
windowed-QA screenshot loop covered every visual need). wi-godot-mcp is
deleted. All verification + visual reads = headless/windowed CLI per
wi-verifying-changes. If editor-driven look-dev is ever wanted again,
re-evaluate fresh — do not resurrect the old setup from history.

## Red flags — stop and re-read this skill
- **A SUBAGENT backgrounding its own verification sweep and pausing to
  "wait for the notification"** — subagent-of-subagent notifications
  strand the task (two O-task stalls, 2026-07-05). Implementer briefs:
  run verification FOREGROUND, alarm-wrapped, sequentially. Controllers:
  a subagent whose final message says "waiting/holding for my
  sweep/monitor" is STALLED — resume it with "your wake isn't coming;
  check the output and finish."
- "It's a small change, skip the review"
- "QA is green so the feature works" (see wi-verifying-changes)
- "I'll update the ledger at the end of the session"
- Acting on a review that cites no real code
- Editing the worktree while a delegated job is running on the same files

## Two more red flags (2026-07-06)
- **A subagent returning in <10s with ZERO tool uses and a garbled
  system-prompt fragment** = a harness misfire, not a refusal —
  re-dispatch once with the same brief (worked both times it happened);
  log the pattern, never act on the garbled output.
- **Two lanes writing the producer and consumer of one artifact**
  (R3's bundle script vs R2's manifest schema): neither lane's gates
  catch the drift — an INTEGRATION REHEARSAL (actually run the pair
  end-to-end) is the reviewer. Rehearse before the artifact's first
  real use, not at the failure.
- **Controller `git add -A` while any lane is LIVE** — the same leak
  class as tree-based syncing: it sweeps a lane's mid-task files into an
  unrelated commit (happened 2026-07-06: A1's in-progress act layer rode
  an itch-deploy commit). While lanes run, controllers stage EXPLICIT
  paths from the lane's own report; `-A` only when no lane is live.
- **A lane hitting an explicit STOP-and-report trigger and choosing
  disclose-and-proceed instead** (DP2, 2026-07-07: the brief said "a new
  sim system = STOP and NEEDS_CONTEXT"; the lane built WIBounties and
  disclosed — the outcome happened to be right on the merits, but a STOP
  gate exists precisely for the cases where the implementer's confidence
  is the thing being checked). Controllers: name it as a deviation in the
  review dispatch and have the reviewer adjudicate the merits explicitly;
  a defensible outcome does not retroactively convert a STOP into a
  judgment call. Brief-writers: if a trigger is meant to be advisory,
  write "disclose"; write STOP only when you mean pause.
- **A parallel lane SETTING A NEW STANDARD (a validator, a lint, a
  schema check) while sibling lanes author artifacts of that class**
  (2026-07-09: the fixture-coherence validator merged mid-flight; the
  parallel C3 lane's NEW fixtures were authored to the old standard —
  CI's unit job went red on main while the sweep job stayed green and
  masked it; CF caught it). When a standard-setter merges, either
  re-brief every concurrently-open lane that authors that artifact
  class, or run the new validator against sibling branches BEFORE
  their merge. Corollary: "the sweep is green" ≠ "CI is green" — the
  unit job is a separate gate; check both before declaring main clean.
- **Merging a worktree lane by file-copy while a main-tree lane holds
  UNCOMMITTED work** — intersect the worktree's file map against `git
  status` AND the live lane's reported file list BEFORE copying; any
  overlap = commit/park the main-tree hunk first. Happened 2026-07-06:
  K1's wi_game.gd copy silently destroyed L2's uncommitted
  `_build_dialogue_ctx` hunk; the lane's green report was already stale
  the moment the copy landed. Corollary: a lane's "full sweep green"
  claim attaches to ITS tree state — the controller re-runs the gate on
  the MERGED tree (the K1×L1 tripwire red was only visible there).

## Two landing-time red flags (2026-07-12, both bit the same day)
- **A landing commit whose message describes more than its diffstat
  shows** — 93af9cd claimed six files of reconciliation work and
  contained two deletions; the real edits sat unstaged while the gate's
  green attached to the working tree, and main carried invalid JSON in
  qa/manifest.json until a later lane tripped over it. Discipline: after
  EVERY landing commit, `git status` must show zero tracked
  modifications before push, and read the commit's own `--stat` against
  what the message claims. Corollary: push CI's sweep + web-parity jobs
  are `[ci-full]` OPT-IN — "CI: success" on a push is NOT sweep
  evidence; any push whose only sweep evidence is local gets `[ci-full]`
  in the head-commit message.
- **Removing a lane worktree/branch without `git cherry main <branch>`
  first** — lane-8ec's final review-fix commit (the portal map-existence
  guard + a journal-text fix) sat unmerged for days after 8e "shipped";
  the merge had taken an earlier lane tip. `git cherry` on every lane
  branch BEFORE deletion; a stranded commit gets triaged piece-by-piece
  against current main (some pieces land, some are superseded — a7c6a7d
  split 2/5 ported, 3/5 superseded).

## Selective re-gates (issue #101, 2026-07-12)
`qa/ci_sweep.sh --tier smoke` (13 scripts, ~25s) on every push via CI;
`--touching <path>[,<path>]` maps changed data/qa files to the crossing
canonicals for lane re-gates. CAVEAT: `--touching` keys ONLY on content
paths (maps/fixtures/dialogue/skills) — a `src/**` change falls through
every branch and yields ZERO scripts (false-safe). Lanes changing
engine/sim code use `--tier smoke` minimum + the affected canonicals,
never `--touching` alone. The full sweep stays the pre-push composed
gate.
