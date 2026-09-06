# Agent harness operation and measurement

The harness uses one project workflow, small entrypoints and conditional
references. Existing authorization carries through implementation and the issue
PR workflow. Domain constraints, independent review, real gameplay triggers,
rendered evidence and physical-device acceptance remain in the project contracts.

## Changes from issue #544

| Surface | Result |
|---|---|
| Project discovery | Personal local config disables unrelated business plugins, duplicate workflow plugins, dbt and GitLab MCP in this game repository. Browser remains available. |
| Repository contracts | Both `AGENTS.md` files describe current boundaries and point to authoritative manifests and tools. |
| Project skills | All 15 `wi-*` entrypoints remain; detailed schemas and recipes live in 10 conditional references. |
| Generic workflow | An owned personal Superpowers fork provides 14 compact methods, without compulsory approval loops or automatic startup hooks. RPG uses its own workflow. |
| Delegation | Clean-context briefs, bounded independent work, explicit ownership, one mutator per worktree and controller evidence review replace provider assumptions. |
| Verification | Preflight requires zero exit, PASS and no Godot warning/error lines. Every gate retains full output and an exit receipt. |
| Tool output | Local defaults cap tool output at 6,000 tokens; retain complete artifacts and return bounded findings. |
| Usage telemetry | Fresh native Codex session events are preferred when usable; app-server is fallback. Invalid/newer data cannot mask usable older data. EOF/startup diagnostics remain bounded and redacted. Hooks use their session ID and notify only on tier changes. |
| Handoff | `HANDOFF.md` holds live scope/holds; the local ledger holds one resumable checkpoint. Merged PRs and private backups retain history. |
| Tone and effort | Short legible prose replaces repetitive global Caveman hooks. Explicit user tone still applies. Astra/high remains default; optional routine/medium and review/high profiles are available. |

Global files, project `.codex/config.toml`, private session logs and plugin cache
contents are local. This public repository contains only project guidance,
guards, tests and aggregate measurements. Business plugins remain available
outside this repository. Five overlapping document/skill-authoring skills are
disabled globally by exact `SKILL.md` path; specialized alternatives remain.
GitLab and dbt MCP servers are disabled globally as well as in this project,
per the user’s follow-up. No authentication, sandbox permission or hook-trust
setting was weakened.

A fresh Codex session is needed to receive the full discovery change. Existing
conversations retain instructions and skill catalogs already injected into them.
Global backup: `~/.codex/harness/backups/2026-09-06/`. It contains the original
config, hooks and project files; treat it as private. Personal Superpowers source
lives at `~/.agents/plugins/plugins/superpowers/`, installed through marketplace
`personal`; retain its upstream MIT license. Do not edit the vendor cache.

## Measured savings

Same Codex 0.153.0 `debug prompt-input` task and working directory, frozen before
and after configuration; no model request is made by this command. Counts below
use `o200k_base` as a tokenizer proxy, not an Astra billing tokenizer.

| Measurement | Before | After | Reduction |
|---|---:|---:|---:|
| Actual rendered prompt text, proxy tokens | 10,958 | 5,276 | 51.9% |
| Common issue guidance chain, proxy tokens | 19,543 | 3,757 | 80.8% |
| All project guidance entrypoints, proxy tokens | 51,902 | 9,592 | 81.5% |
| All Superpowers entrypoints, proxy tokens | 31,835 | 2,832 | 91.1% |
| Project skill catalog entries | 144 | 22 | 84.7% |

The common chain is both `AGENTS.md` files plus start, execution and verification
skills. An inventory of every entrypoint does **not** imply they load together.
Conditional references add task-dependent input when read. Rendered prompt text
excludes hidden system prompts and tool definitions. These measurements prove
context reduction; they do not establish end-to-end task token or cost savings.
No fixed percentage is attributed to a writing style.

Aggregate evidence: [harness-metrics-2026-09-06.json](harness-metrics-2026-09-06.json).
Raw prompt/session artifacts stay private. Reproduce counts with:

```bash
codex debug prompt-input 'Implement the next authorized bounded issue; preserve acceptance evidence.' > /tmp/prompt-input.json
python3 scripts/harness_metrics.py --root . --prompt /tmp/prompt-input.json --tokenizer
python3 scripts/harness_metrics.py --session /path/to/explicit/session.jsonl
```

The optional tokenizer requires `tiktoken`; byte/word counts require only the
standard library. Session accounting sums `last_token_usage` after session
creation, deduplicated by session ID and cumulative usage snapshot. It excludes
inherited earlier events, rejects malformed or empty accounting input, and never sums inherited
SQLite/session totals. Native total-only records retain an explicit unattributed-token count rather
than inventing an input/output split. Inspect accounting scope before treating
totals as bills.

## Evidence and regression checks

`scripts/preflight.sh` is the fast project gate. `--full` additionally runs every
Godot unit. Logs and `.process-exit` receipts go to `${TMPDIR:-/tmp}/wi-preflight-*`,
outside the QA sweep's disposable output tree; set `PREFLIGHT_ARTIFACT_DIR` for a
chosen durable location. Unit `.verdict.json` also records PASS/noise counts and the combined gate exit.
Temporary artifacts still need archiving for long-term
retention. Never infer success from a shortened output or PASS alone.

Focused tests exercise PASS+exit42, PASS+WARNING, bare/parse/script errors,
missing PASS, complete logs, telemetry formats/freshness/fallback, startup EOF,
partial-line deadlines, redaction and transition silence. Reference mirror tests
alter real temporary reference files to prove drift is detected. Usage metric
tests inject inherited and duplicate records to prove they do not inflate totals.

Hooks are advisory: native session data requires a matching readable session
log. The hook does not spawn an app-server on every tool call; explicit
`scripts/usage_status.sh` polls provide bounded fallback when native telemetry is
unavailable. Missing telemetry is UNKNOWN, never zero capacity.

The refactor follows [OpenAI's latest-model guidance](https://developers.openai.com/api/docs/guides/latest-model):
preserve user scope and prior authorization, delegate deliberately, test
proportionally, avoid unnecessary repeated checks and keep concise readable
communication. Project-specific acceptance remains authoritative.
