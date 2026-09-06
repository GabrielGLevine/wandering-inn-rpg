---
name: wi-usage-guard
description: Interpret provider usage status and preserve resumable state near a quota boundary.
---

# Usage guard

Run `scripts/usage_status.sh` at session start for queue/resume work, before a
worker wave, and at integration boundaries. The script is authority for tier,
exit code, cache freshness, provider label, burn projection, and thresholds; do
not duplicate its threshold table in guidance. `--fresh` requests a new
provider-local reading when supported.

Treat hooks as advisory and conditional. A transition notice matters only when
the project hook is installed, trusted, executed, and delivered in the current
environment. Polling the script remains the fallback. Provider telemetry never
borrows another provider’s quota or capabilities.

Act on the script’s reported tier:

- normal: proceed within the task;
- caution: avoid opening new speculative lanes and finish bounded work;
- wind-down: stop feeding new work, make each lane recoverable, preserve exact
  state, and leave integration for a fresh window if evidence cannot land;
- quiesce: state-saving actions only; never merge unverified work merely to save
  it.

Unknown telemetry is not zero usage, unlimited capacity, or a reason to stop all
work. Continue bounded local work, keep a conservative landing reserve, avoid
large fan-out, retry the status later, and record a persistent diagnostic in
`HANDOFF.md`. The status script should expose one bounded failure reason and
distinguish startup/EOF/permission errors from timeout; do not disable sandboxing
to make telemetry work.

A recoverable checkpoint contains objective and authorization, issue/branch/base
SHA, exact owned dirty paths, completed evidence, pending operations, real
blockers, and the next command. Work-in-progress stays on its issue/lane branch;
`main` takes only reviewed, gated integration. Wait/resume behavior follows the
current script notification and available scheduler; never assert a wake hook
exists without checking it.
