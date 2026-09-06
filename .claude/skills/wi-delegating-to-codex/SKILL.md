---
name: wi-delegating-to-codex
description: Dispatch bounded implementation, diagnosis, or review work to native agents with clean context and verifiable evidence.
---

# Delegate by role

Roles are controller, implementer, independent reviewer, and Git/windowed-QA
operator. Any capable provider may hold one or several roles; no provider has
exclusive verification or merge authority. The controller owns integration and the final
evidence verdict. A worker may run checks, but its close summary remains a claim
until the controller verifies required artifacts on the composed tree.

Delegate only when independent work repays setup/context cost. Use at most two
concurrent implementation workers. Each mutator gets a disjoint worktree and
explicit non-overlapping files; never write or mutation-test a worker’s tree
concurrently.

Native dispatch defaults to `fork_turns: "none"` with a compact brief:

- task/issue and exact base SHA/branch;
- numbered acceptance criteria and concrete exclusions;
- owned files plus shared/generated surfaces that serialize;
- relevant architecture/product/domain contracts;
- exact evidence/artifacts required and what the worker cannot observe;
- dirty state and exact handoff action.

Reuse the same worker for a fix round so the evidence context survives. Start a
fresh worker if capabilities or write access are lost rather than fighting a
stale execution context. Discover Git, network, window, and device capability
from actual tools; never infer it from model/provider identity.

Review common failure modes explicitly: omitted acceptance clauses; artifacts
claimed but absent; fixture/pin edits that suppress a real change; source-grep
tests instead of production wiring; guards that cannot fail or are not invoked;
symptom fixes that preserve the failure class; unverified hashes or quoted
verdicts. Review fixture diffs and scope against the base. Ask reviewers to
refute named claims, not broadly “verify” them.

Do not depend on legacy forwarders, companion job paths, or model-specific
configuration unless their callable interface is present in the current
session. Apply `wi-running-the-machine` integration rules and
`wi-verifying-changes` before closure.
