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
   format lives in any existing issue); the issue closes via its PR's
   `Closes #n` line at squash-merge.
2. **Implement** on branch `issue/<n>-<slug>` (PR workflow, user directive
   2026-07-15). Content = data (`data/*.json`); behavior = sim
   (`src/core/**`, PURE: no autoload/Node refs); presentation only renders.
   Worktree lanes merge into the issue branch, never straight to main.
3. **Verify green** — wi-verifying-changes. No claim without evidence.
4. **Review** — dispatch a reviewer subagent on the diff/commit (below).
5. **Fix wave** — apply Critical/Important findings, re-verify, re-review the
   fixes. Log Minors to the ledger for the milestone's final review.
6. **Open the PR** with `.github/PULL_REQUEST_TEMPLATE/issue-close.md`
   filled — choices made (with rejected alternatives), validation evidence
   (commands + results, not claims), player-visible proof, new agent
   context (traps/contracts added), deferrals. The PR body is the durable
   per-issue record: future sessions read `gh pr view`, not commit
   archaeology. Squash-merge after CI is green. **Ledger one entry**; keep
   HANDOFF current-state only (RUNNING/QUEUE — per-issue narrative lives
   in the PR). Non-issue housekeeping still commits direct to main.

## Dispatching reviewers (they earn their cost only with method hints)
Prompt must include: the commit/range, "read wandering_inn_game/AGENTS.md
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

## Role and capability ladder
- The controller assigns explicit implementer, reviewer, and Git/windowed-QA
  operator roles. Roles may share a provider; evidence and file ownership are
  the contract.
- Every dispatch records issue, branch, base SHA, owned files, verification,
  conflicts, operator needs, and next action.
- Discover capabilities per session. If an implementer cannot write `.git`,
  use a Git operator; if it cannot open windows, use a windowed-QA operator.
- Mechanical work may use a cheaper provider; design, sim semantics, canon,
  balance philosophy, specs, and plans require the strongest available reasoner.
- Same-file work remains single-implementer regardless of provider.

## Usage-aware pacing (user directive 2026-07-04)
The session has a fixed usage budget. Default the top model to orchestration
+ review; implementation goes down the ladder. Reassess at task boundaries:
burning fast → throttle top-model work, delegate more; budget to spare near
session end → upshift to higher-tier models and spend it. Same-file work is
still single-implementer: never run two agents on one file concurrently.
**Provider-scoped capacity:** controllers run `scripts/usage_status.sh` before
dispatch and at merge points. It queries the active provider only (Claude CLI
or Codex app-server). Never transfer one provider's quota tier to another.
All providers still avoid new work when their own capacity is constrained and
keep the shared no-overlapping-writers and integration discipline.
**Controller shell discipline: never `cd` into a lane worktree.** Build
review packages and inspect lanes via `git -C <worktree>`; every mutating
command (commit/merge/ledger append) runs from the repo root explicitly.
A drifted CWD has committed controller work onto a LANE'S branch
mid-review (2026-07-07, caught same-minute: cherry-pick to main +
`reset --hard` the lane tip was the recovery).
**A merge that delivers NEW `.gd` files OR NEW IMAGE ASSETS needs a
main-tree import pass BEFORE the re-gate** (`--headless --import`) —
v0.17 seam gate: L4's new sheets unimported on main read as 99/200
canonicals red ("missing sheet" on files present on disk). For `.gd`
the mechanism is class_name registration
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

## Shared-file lane wipe (2026-07-18, cost three bisect cycles)
`git checkout -- <file>` to revert ONE lane of edits also wipes every
OTHER uncommitted lane in that file — #184's walls revert silently
destroyed the sprite-wiring hunks in the same two map files, and every
subsequent visual run tested `sprite: "door"` while the "mystery" was
chased through z-sort, caches, and a full reimport. Discipline: before
reverting a shared file, `git diff <file>` and name every hunk you are
about to lose; if any belongs to another lane, commit or stash-split
FIRST. Corollary: when a feature "vanishes" mid-iteration, `git diff`
the wiring files BEFORE debugging the engine.

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

## The shared-data-source seam rule (2026-07-12, third occurrence)
Before merging a wave, enumerate every pair of lanes where one lane's
tool/validator READS a file another lane RESTRUCTURES — not just the
pairs flagged at dispatch. The 99×100 seam (a freeze generator reading
the monolith a split lane deleted) passed BOTH per-lane reviews clean
and broke only on the composed tree. Mechanical check at merge time:
for each file a lane deletes/moves, grep every OTHER lane's diff for
that path before the composed gate, and grep MAIN for it after — the
composed-tree unit run is the backstop, not the detector.

## Plan docs COMMIT BEFORE dispatch (2026-07-13, cost three lane stalls)
A lane brief referencing a plan/spec file only works if the file is IN
the commit the worktree branched from (or copied into the worktree).
The depth-wave plan sat uncommitted in main's working tree; every lane
chased a ghost path — one burned three stalled runs before a fresh
agent diagnosed it. Discipline: `git add + commit` the plan doc BEFORE
`git worktree add`, and the worktree-setup step verifies every
brief-referenced path exists inside the worktree.

## Branch protection on main (2026-07-19, user directive)
main requires the SIX status checks (sweep, leak, smoke boot, smoke
sweep, units, web parity) to merge a PR — a PR head whose commit
message lacks `[ci-full]` never gets the sweep/parity contexts and is
UNMERGEABLE until one is pushed. `[ci-full]` on every PR head is now
platform-enforced, not convention. Force-pushes and deletion of main
are blocked. enforce_admins is OFF deliberately: the owner-auth
direct-to-main housekeeping flow (HANDOFF/ledger/skill commits) still
works; do not "fix" that by enabling it without a user ruling.

## Anchored-append merge trains (v0.16, four content lanes)
When multiple lanes append to the same shipped arrays/consts, assign
each lane a NAMED anchor row it does not share (quests[], combatants[],
manifest scripts[], moods keys, LANDMARK_TOKENS, seed table, test-file
locals get lane prefixes) — the v0.16 train composed four lanes with
only TWO content seams, both at the one unanchored boundary. Union
conflicts (CHOICE-LOG/VISUAL-LOG/HANDOFF appends) resolve
ours-then-theirs mechanically; generated files (scene-dynamism report,
QA notes) are never hand-merged — take either side, REGENERATE on the
composed tree, commit the regen. Squash-merges resurrect
convention-untracked files silently (two lanes re-added the lane
ledger after it was deliberately untracked) — enforce local-only
conventions with .gitignore, not convention.

## Owner-auth merges bypass required checks (v0.16 close, bit for real)
enforce_admins is OFF (deliberately, for the housekeeping flow), so an
owner-auth `gh pr merge` SUCCEEDS on a PR with a FAILED required check —
protection only guards non-admin merges. The v0.16 close PR was merged
with Unit suites red because the merge ran in the same compound command
as the verdict read (the exact class the commit/push rule already
names). Discipline, extended: READ THE CHECKS TABLE AS ITS OWN STEP and
parse pass/fail BEFORE any merge command; a merge is never compounded
with its verdict. Corollary from the same incident: a close/hygiene PR
gets the FULL 30-suite bar locally, not a hand-picked trio — the red
suite (test_sim_core) was the one not picked; and exact-array pins on
derived surfaces (active_leads) live in SIM tests too, not only QA
scripts — grep tests/ for the surface (active_leads, lead_lines) before
landing rows that grow it.

## `[ci-full]` belongs on the FINAL head, not the head you prepared (2026-08-07)
Amending `[ci-full]`, then pushing one more commit (a CHOICE-LOG fold),
left a head without the flag: `gh pr checks` reported "no checks
reported on the branch", the sweep/parity contexts were never created,
and the PR was unmergeable against the six required checks. Re-amend
and force-push the ACTUAL final head. Discipline: add `[ci-full]` as
the LAST action before opening the PR, and if any commit lands after
it, re-check `git log -1 --pretty=%s | grep -c ci-full` before waiting
on checks.

## Verify a squash merge by TREE, never by `git cherry` (2026-08-07)
After a squash, `git cherry main <lane>` reports every lane commit as
unmerged (patch-ids differ by construction) — on a 12-lane train that
reads as 240 stranded commits and invites a panic re-merge. The real
check is one line:
`[ "$(git rev-parse <train-tip>^{tree})" = "$(git rev-parse HEAD^{tree})" ]`
Identical trees prove the squash landed everything. Keep `git cherry`
for NON-squash lane tips (its documented use: catching a lane whose
final review-fix commit never made the merge).

## Blind-read instruments: ONE shuffled packet, roles joined afterwards
When a pass must be judged by readers, do not hand them separate
"revised" and "control" files — a Phase-5 read leaked the control's
identity through a generated header and its reasoning had to be
discounted. Ship one shuffled packet with identical formatting and no
set boundary, keep the key controller-side, and join scores to roles
only after the sheets return. The payoff is decisive: when both #397
round-2 readers named a surviving rhetorical engine (which reads as a
FAIL), the key showed its core specimens were 15/15 CONTROL rows and
the hostile reader's own counter-case was 9/9 REVISED. A separated
design cannot produce that discrimination, and the criterion would have
been adjudicated on vibes instead of evidence.

## Fix at the root, not the symptom's surface (user teaching, 2026-08-09)
Before dispatching any fix — especially art/polish — ask the level-up
question: "why does this thing exist at all? does it need to?" The
teaching case: three rounds of sprite work tried to make a crate read
better UNDERWATER (mis-sliced sliver → bold dry crate → submerged
variant, still occluded by the crab) before the real question landed —
the fiction says the cache is under silt, so NOTHING should be
visible; the sprite chase was unjustifiable from the start, and the
affordance chain (bank prose + freeze-route teach + adjacency marker)
never needed it. Removal beat improvement. Symptoms of being at the
wrong level: iterating art/params on something whose existence is
unexamined, fixing the same surface a second time, or a reviewer
scoring your fix against the wrong baseline. Cost of the miss here:
one PixelLab generation, one review finding, one fix-wave redirect.
