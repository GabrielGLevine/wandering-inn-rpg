# Documentation map

> Last verified: **2026-07-13** (issue #103).

The GitHub issue board is the work queue. Documentation records current
contracts, decisions, or history; a plan file never reopens completed work.

| Location | Purpose | Authority / lifecycle |
|---|---|---|
| `AGENTS.md` | Repository bootstrap, invariants, workflow | Current; canonical for all agents |
| `wandering_inn_game/AGENTS.md` | Game architecture, commands, QA seed table, gotchas | Current; seed table is manifest-checked |
| `CLAUDE.md`, `wandering_inn_game/CLAUDE.md` | Claude Code discovery adapters | Generated policy: small pointers only |
| `HANDOFF.md` | Live queue, taste gates, unresolved choices, environment notes | Current-state only; shipped narrative belongs in git history |
| `docs/README.md` | Documentation directory guide | Current |
| `docs/ROADMAP.md` | Board and label pointers | Current; GitHub owns priority/state |
| `docs/VISUAL-LOG.md` | Open visual debt and taste observations | Current; prune resolved entries |
| `docs/design/character-profiles.md` | Shipped character voice/art contract | Current writing authority |
| `docs/design/character-profiles-staging.md` | Compatibility pointer to live profiles and archived expansion source | Pointer stub; never add profiles here |
| `docs/design/dialogue-drafts/home_region_2/` | Unshipped Home-Region II copy | Live staging |
| `docs/design/dialogue-drafts/pools/` | Shared pool drafts with explicit open seams | Live staging; audit at consumption |
| `docs/design/*.md` | City identity, canon verdicts, spoiler cutoff | Current unless the file says otherwise |
| `docs/superpowers/specs/` | Approved designs, explorations, and decision records | Dated design authority; a header may refine lifecycle, but GitHub owns current scheduling |
| `docs/superpowers/plans/` | Execution instructions | Header says `DONE` or `ACTIVE`; only ACTIVE is open work |
| `docs/archive/design/` | Shipped/superseded art and assembly direction | Archive; do not execute as current instructions |
| `docs/archive/staging/` | Consumed copy, profiles, and generated-candidate provenance | Archive; shipped data is authoritative |
| `docs/archive/HANDOVER-FABLE-TO-OPUS-2026-07-02.md` | Retired provider-era operating manual | Archive; superseded by `AGENTS.md` and `wi-*` skills |
| `docs/FULL-GAME-PLAYTEST.md` | Human playtest route for the v0.4.1 candidate | Historical route; re-audit before using against a later release |
| `wandering_inn_game/docs/ARCHITECTURE-HISTORY.md` | Detailed mechanism history and rationale | Historical; current summary lives in game `AGENTS.md` |
| `wandering_inn_game/docs/QA-SCRIPT-NOTES.md` | Generated canonical QA inventory | Generated from `qa/manifest.json`; exact routes live in `qa/scripts/` |
| `docs/reports/`, `.superpowers/` | Generated reports, ledgers, screenshots | Gitignored; never bootstrap authority |

## Drift checks

- `python3 scripts/sync_agent_guidance.py` checks provider adapters and the
  `.agents/skills/` → `.claude/skills/` mirror.
- `python3 scripts/render_qa_notes.py` checks the complete QA inventory against
  `wandering_inn_game/qa/manifest.json`.
- `python3 scripts/check_doc_drift.py` checks this map, plan status headers,
  and the character-profile staging stub. CI runs all three.
