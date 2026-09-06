---
name: wi-handling-prs
description: Triage, review, test, and decide an external Wandering Inn RPG pull request.
---

# Handle an external PR

Treat contributor code as untrusted until read. Inspect the PR metadata, files,
raw diff, and required checks before checking it out. Read changed scripts,
`@tool` code, workflows, export configuration, and dependency/download logic
before executing branch content. New binary assets need license provenance and
AI disclosure where applicable; manifest/private paths must never be tracked.

Triage scope against an open issue or accepted contribution class. Read failing
job logs. A leak-check failure or missing asset provenance requests changes
immediately. Do not spend local execution time on a known-red PR unless
diagnosing project infrastructure.

For data changes, run the existing semantic data diff as an advisory, then read
all raw/unsummarized changes. Review in this order:

1. public-asset, shipped-ID, canon/spoiler, stat-grammar, and opaque-progress
   contracts;
2. pure sim, data/behavior/presentation boundaries, and real production wiring;
3. QA steel thread: trigger, domain event, rendered confirmation, state/result,
   and windowed evidence for player-visible work;
4. correctness, maintainability, comments, and scope.

Check out only after that review. Run `scripts/leak_check.sh` and the gate set
selected by `wi-verifying-changes`, including balance and deterministic combat
routes when relevant. For player-facing work use the real overlay and inspect
windowed screenshots as a first-time player. Physical touch/device/timing
claims require their named route and remain unproven otherwise.

Request changes with file/line, violated contract, and the smallest acceptable
fix. Never push to a contributor branch without authorization. New art direction,
dialogue voice, balance philosophy, and labeled taste gates wait for the user;
prepare a concrete recommendation and state. Never merge with required CI red
or with weakened gates unless the user explicitly accepted that change.

When all checks and review pass, use the repository’s chosen merge method,
refresh the integration branch, rerun required composed-tree gates, and update
only live state in `HANDOFF.md`. Read the checks verdict separately from the
merge command because owner privileges can bypass branch protection.
