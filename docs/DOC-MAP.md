# Documentation map

> Last verified: **2026-08-11** (docs/lanes cruft purge).

The GitHub issue board is the work queue. Documentation records current
contracts, decisions, or history; a plan file never reopens completed work.

| Location | Purpose | Authority / lifecycle |
|---|---|---|
| `AGENTS.md` | Repository bootstrap, invariants, workflow | Current; canonical for all agents |
| `wandering_inn_game/AGENTS.md` | Game bootstrap contracts, authority map, commands, architecture boundaries, gotchas | Current; compact mandatory context |
| `CLAUDE.md`, `wandering_inn_game/CLAUDE.md` | Claude Code discovery adapters | Generated policy: small pointers only |
| `HANDOFF.md` | Live queue, taste gates, unresolved choices, environment notes | Current-state only; shipped narrative belongs in git history |
| `docs/CHOICE-LOG.md` | Compact index of unresolved and still-governing rulings | Amend in place; implementation narrative belongs in PR bodies/git history |
| `docs/README.md` | Documentation directory guide | Current |
| `docs/VISUAL-LOG.md` | Open visual debt and taste observations | Current; prune resolved entries |
| `docs/design/character-profiles.md` | Shipped character voice/art contract | Current writing authority |
| `docs/design/character-profiles-staging.md` | Compatibility pointer to live profiles and archived expansion source | Pointer stub; never add profiles here |
| `docs/design/dialogue-drafts/home_region_2/` | Unshipped Home-Region II copy | Live staging |
| `docs/design/dialogue-drafts/pools/` | Shared pool drafts with explicit open seams | Live staging; audit at consumption |
| `docs/design/*.md` | City identity, canon verdicts, spoiler cutoff, narrator bible, prose review rubric | Current unless the file says otherwise |
| `docs/dialogue-voice-bible.md`, `docs/dialogue-voice-cards/` | Dialogue writing contract: bible, per-cluster cards, cluster manifest, 11-tell critique | Current writing authority; a card overrides the bible on conflict |
| `docs/steam/` | Store-page capsules, screenshots, submission checklist | Current release assets |
| `docs/superpowers/specs/` | Approved designs, explorations, and decision records | Dated design authority; a header may refine lifecycle, but GitHub owns current scheduling |
| `docs/superpowers/plans/` | Execution instructions | Header says `DONE` or `ACTIVE`; only ACTIVE is open work |
| `docs/archive/design/` | Shipped/superseded art and assembly direction | Archive; do not execute as current instructions |
| `docs/archive/staging/` | Consumed copy, profiles, and generated-candidate provenance | Archive; shipped data is authoritative |
| `wandering_inn_game/docs/ARCHITECTURE.md` | Machine-oriented structural map: layers, module registry, data catalog, seams, extension recipes | Current; session-bootstrap architecture authority |
| `wandering_inn_game/docs/ARCHITECTURE-HISTORY.md` | Detailed current mechanisms, history, and rationale | On-demand mechanism authority; current boundaries live in game `AGENTS.md` |
| `wandering_inn_game/docs/QA-SCRIPT-NOTES.md` | Generated canonical QA inventory | Generated from `qa/manifest.json`; exact routes live in `qa/scripts/` |
| `wandering_inn_game/qa/MACHINE-PLAYTEST.md` | Player-eyes screenshot playtest protocol | Current QA procedure |
| `wandering_inn_game/qa/playtest_saves/` | Organic player-save regression snapshots | Retained QA evidence; not canonical fixtures |
| `wandering_inn_game/qa/baselines/` | Frozen corpora the prose and dialogue-voice gates diff against | Gate fixtures, not docs; see its README for which files are pins vs derivatives |
| `docs/reports/`, `.superpowers/`, `lanes/`, `LANE-*.md` | Generated reports, ledgers, screenshots, lane briefs and evidence | Gitignored; never bootstrap authority |

## Drift checks

- `python3 scripts/sync_agent_guidance.py` checks provider adapters and the
  `.agents/skills/` → `.claude/skills/` mirror.
- `python3 scripts/render_qa_notes.py` checks the complete QA inventory against
  `wandering_inn_game/qa/manifest.json`.
- `python3 scripts/check_doc_drift.py` checks this map, retired-file absence,
  README demo link, plan status headers, and the character-profile staging
  stub. CI runs all three.
