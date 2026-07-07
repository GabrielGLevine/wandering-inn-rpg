# docs/ — what lives where

**The plan lives on GitHub** (issues/milestones/labels + the Projects
board), not here. These docs are references, records, and state.

## Living references (edit in place)
| Doc | What |
|---|---|
| `ROADMAP.md` | Pointer to the GitHub board + label taxonomy |
| `VISUAL-LOG.md` | Standing visual-defect log — every milestone drains it |
| `TRIAGE.md` | Community-issue triage flow (local, no CI secrets) |
| `SECRETS-SETUP.md` | Fresh-machine key/secret provisioning |
| `HANDOVER-FABLE-TO-OPUS.md` | The operating manual: model, lessons, §0 unified-repo bootstrap |
| `asset-catalog.md` / `asset-index.{md,json}` / `scene-assembly-guide.md` | Art-sourcing workflow (index is consumed by tooling + registry tests — don't hand-edit the json) |

## `design/` — content design (living)
Character profiles (the writing contract), the city-identity bible,
canon verdicts (`k3-canon-verdicts.md`), the **binding spoiler cutoff**
(`spoiler-cutoff.md`), and pre-authored content for the 8b–8f
expansions (`character-profiles-staging.md`, `dialogue-drafts/`).

## `superpowers/` — the design record (append-only)
Specs and implementation plans per milestone, named
`YYYY-MM-DD-<topic>.md`. Issues cite these as design authority; never
delete one an open issue references. Predecessor-era (v2/v3) docs were
pruned 2026-07-07 — they live in the frozen-archive repo.

## `archive/staging/` — consumed copy provenance
Staged dialogue/copy corpora that already shipped into `data/` (kept:
they answer "where did this line come from"). Session-lifecycle
artifacts (morning summaries, night goals, old handoff bodies) are NOT
kept here — they live in git history and the frozen-archive repo
(`GabrielGLevine/wandering_inn_rpg`, private).

## Generated docs — do NOT commit
Session-generated artifacts are gitignored by pattern: root
`MORNING_SUMMARY*.md` / `NIGHT-GOAL*.md`, `docs/reports/` (the landing
zone for any future generated report), `docs/*_api_key.txt` (secrets),
and everything under `.superpowers/` (ledgers, lane reports, shots).
If a new generator needs a home, point it at `docs/reports/`.
