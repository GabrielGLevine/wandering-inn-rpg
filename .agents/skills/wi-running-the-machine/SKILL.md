---
name: wi-running-the-machine
description: Execute an authorized Wandering Inn RPG task from scope through reviewed PR evidence.
---

# Run the task

The user request is the process owner. For issue work, use its acceptance
criteria and approved design; routine reversible implementation needs no new
design ceremony. Ask only for a missing choice that materially changes the
result or a real taste/canon decision.

1. Resolve the task, branch, exact base SHA, acceptance clauses, owned files,
   and current dirty state. Preserve unrelated user changes. Issue work uses
   `issue/<n>-<slug>` and closes through a PR.
2. Read the nested `AGENTS.md`, the one matching domain skill, and only the
   source/schema sections needed. Turn every player-facing clause into a steel
   thread: actual trigger → sim/domain event → renderer → `ui_*_rendered` →
   QA assertion → windowed observation.
3. Implement the smallest coherent mechanism. Fix root causes and failure
   classes. Keep content in data, behavior in pure sim, and presentation thin.
   Use meaningful red/green tests when behavior changes; docs/config/copy need
   proportional checks.
4. Review the diff against every acceptance clause. Verify scope with
   `git diff --name-only <base>...HEAD`. Inspect fixture/pin edits explicitly;
   they can hide behavior changes. A gate is meaningful only if it exercises
   shipped input through the real path and is actually invoked.
5. Run `wi-verifying-changes` on the settled current tree. Preserve exact
   command, tree SHA, exit, success marker/noise scan, result artifacts, and
   windowed screenshots. Device/touch/timing clauses require their named route;
   report unavailable evidence honestly.
6. Obtain independent review for issue-closing or high-risk work. Frame review
   to refute concrete claims and cite observed evidence. Reuse the same reviewer
   for fixes when practical. Do not let any reviewer mutate-test a worktree
   while another process writes it.
7. Compose lanes into the issue branch, regenerate derived files there, then
   rerun integration gates. Fill the issue-close PR template from observed
   evidence. Read the checks table as a separate step; merge only after required
   CI and review pass.

Use parallel workers only for independent, high-value tasks. Cap active
implementation workers at two. Each mutator gets a disjoint worktree and file
ownership; shared catalogs, generated files, and same-region maps serialize.
Read-only reviewers may share source snapshots but mutation probes require
isolation. The controller integrates and decides the verdict; roles do not
depend on provider names.

Read [references/integration-and-evidence.md](references/integration-and-evidence.md)
before dispatching lanes, composing a shared tree, or preparing a close PR.
Use `wi-delegating-to-codex` for compact native dispatch mechanics and
`wi-usage-guard` when telemetry or a usage notification affects pacing.
