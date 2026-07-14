# Claude Code adapter

Read and follow [`AGENTS.md`](AGENTS.md), the model-neutral repository guidance.
Project skills are canonical in `.agents/skills/` and mirrored exactly into
`.claude/skills/` for Claude Code discovery. Do not edit the mirror directly;
run `python3 scripts/sync_agent_guidance.py --write` after canonical changes.

Claude-only optional automation lives in `.claude/settings.json`. Its usage
telemetry applies only to Claude sessions and does not constrain other providers.
