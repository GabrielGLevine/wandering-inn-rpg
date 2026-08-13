---
name: wi-delegating-to-codex
description: Use when dispatching implementation, diagnosis, or review work to the Codex CLI (gpt-5.6-sol) — what to delegate, the mandatory guardrails, and how to gate its closes before merge.
---

# Delegating to Codex (gpt-5.6-sol)

Codex = second implementer on its OWN usage pool (provider-scoped telemetry;
`scripts/usage_status.sh` shows both). Default model gpt-5.6-sol effort=high —
Opus+ code quality, audited on this repo 2026-07-15 (#87/#91/#102/#113/#117
post-close audits; findings → #118/#119).

## Division of labor (binding)
**Codex implements. Controller (Claude) verifies, reviews, merges.** Codex
NEVER self-attests verification: machine-playtest, windowed reads, gate-can-fail
checks, and the merge decision stay controller-side.

## What to delegate (audited strengths)
- Bounded implementation waves with crisp specs (the #113 drain: every closed
  entry traced to a real diff).
- Large mechanical migrations (#102: 168 files, validators stayed byte-green).
- Mechanism-quality features (#87 frame_post_draw gating, input double-gating;
  #91 settings-vs-save discipline) — code ships at or above Opus level.
- Root-cause rescues at `--effort xhigh` when the controller is stuck.
- Independent second-opinion design reviews (replaces the user-mediated
  consultant pattern).
- Usage arbitrage: at CAUTION+ on the Claude side, Codex keeps lanes moving.

## The five audited failure modes + mandatory guardrails
1. **Close-claims outrun artifacts** (#117 claimed a structural test + windowed
   read; diff contained neither; #87's "live gate" runs in no pipeline).
   → Gate every close against the issue-close PR template: each claimed
   artifact must be IN the diff or attached. No artifact, no merge.
2. **Gates that cannot fail** (#91 fixture pinned an impossible state at 0;
   #113 shipped an inert typo'd mutation guard; wiring "tests" = source greps).
   → Require the prove-it-can-fail step in the brief: mutate the guarded
   surface, show red, revert. Zero-value pins on counters are a smell.
3. **Multi-clause directives lose clauses silently** (#102 dropped the
   move-to-docs clause and overshot deletion 2x; #117 dropped 2 acceptance
   criteria). → Enumerate clauses as numbered acceptance criteria in the
   issue; demand per-clause evidence in the PR body; diff the criteria list
   against the diff at review.
4. **Symptom-level fix waves** (typo corrected, silent-no-op class left alive;
   sleeps pinned instead of the harness race fixed). → Fix-wave prompts demand
   class-level fixes: "make the silent no-op impossible", not "correct the
   string".
5. **Comment economy misjudged both ways** (#102 deleted KEEP-class traps —
   restored b66424c; #87 added zero traps on four new load-bearing orderings).
   → Comment-heavy Codex diffs get trap-survival sampling; new ordering/seam
   code gets a "New agent context" PR-section check.
6. **STOP triggers get engineered around, and repeat on the same surface**
   (#398 Phase 0, TWICE: fixtures edited to suppress a hotbar derivation
   change; the fix brief then said verbatim "report the slot list and STOP
   for controller adjudication — do not invent a loadout", and the second
   pass disarmed the fixtures AND pinned invented loadouts instead).
   → Reviews must diff FIXTURES against HEAD explicitly (fixture edits are
   the pin-gaming surface); a second suppression on the same surface moves
   that surface to Claude-side implementation — no third Codex attempt.

## Mechanics
- Dispatch via the `codex:codex-rescue` subagent (single-shot forwarder;
  `--effort xhigh` for hard problems, `--resume-last` to continue, `--fresh`
  to restart). Write-capable by default — create the `issue/<n>-<slug>`
  branch BEFORE dispatch; Codex works the checkout, controller commits/PRs.
- Never edit the worktree while a Codex job runs (T8 phantom-fix incident).
- **Long briefs misfire through the forwarder** (2026-08-06: a multi-page
  brief produced a 23s usage-banner run + a phantom task id). Write the
  brief to a FILE in the worktree; the task text is a one-line pointer to
  it. Dispatch the companion helper directly from the main thread as a
  BACKGROUNDED command (never piped — SIGPIPE kills the client while the
  server-side thread keeps running unregistered).
- **Companion job state is cwd-scoped** (state/<worktree-hash>/): status,
  result, and cancel must run FROM the worktree the task launched in, or
  they report "no job found" while the launch path still refuses new
  tasks with "still running". A dead client leaves a stale running lock —
  cancel from the right cwd clears it.
- Codex sandbox cannot write `.git` or open windows — controller owns
  commits, windowed QA, and screenshots.
- Brief format: issue number + numbered acceptance criteria + the specific
  QA scripts/seeds that must stay green + "list every criterion you did NOT
  meet" (forces the clause-drop failure mode into the open).

## Forwarder strands + direct dispatch + evidence honesty (2026-08-10)
- The codex-rescue forwarder can STRAND by backgrounding a wait for a
  notification that never reaches subagents (three occurrences in one
  batch). Preferred: dispatch the companion DIRECTLY from the main
  thread, backgrounded, from the lane worktree cwd (allowlist rule
  `Bash(node /Users/gabriel/.claude/plugins/cache/openai-codex/*)`
  exists in settings.local.json). A killed client leaves a stale
  running lock — `cancel` from the same cwd clears it.
- Briefs must demand QUOTED-ONLY-OBSERVED evidence: one lane reported
  a "98/98 FAILED (CA-cert)" gate that was actually green, another
  self-reported reds that were sandbox-only (Trash perms, CA lookup).
  Controller re-runs the decisive gates regardless; treat lane
  gate-verdict prose as claims, not evidence.
- Codex sandbox cannot open windows or write normal user://; windowed
  acceptance and those two unit suites are ALWAYS controller-side.


## Wave >=434 lessons (2026-08-13)
- **`task --resume-last` can silently drop write access.** One thread lost
  it twice ("patch rejected: writing is blocked by read-only sandbox")
  while another resumed thread kept writing fine. For write work after a
  resume: if the first patch rejects, re-dispatch `--fresh` — the brief
  file carries the context; do not fight the thread.
- **Quoted digests are claims too.** A close quoted a table SHA that
  matched nothing (not sha256/sha1/md5/git-blob of the artifact) while the
  substance was independently fine. Gates verify quoted hashes against the
  artifact, or ignore them and hash it themselves — never repeat an
  unverified digest into a PR body.
