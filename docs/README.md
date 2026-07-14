# docs/ — what lives where

**The plan lives on GitHub** (issues/milestones/labels + the Projects
board), not here. These docs are references, records, and state.

## Living references (edit in place)
| Doc | What |
|---|---|
| `DOC-MAP.md` | Agent-facing documentation ownership, status, and authority map |
| `ROADMAP.md` | Pointer to the GitHub board + label taxonomy |
| `VISUAL-LOG.md` | Standing visual-defect log — every milestone drains it |
| `TRIAGE.md` | Community-issue triage flow (local, no CI secrets) |
| `SECRETS-SETUP.md` | Fresh-machine key/secret provisioning |
| `asset-catalog.md` / `asset-index.{md,json}` / `scene-assembly-guide.md` | Art-sourcing workflow (index is consumed by tooling + registry tests — don't hand-edit the json) |

## `design/` — content design (living)
Character profiles (the writing contract), the city-identity bible,
canon verdicts (`k3-canon-verdicts.md`), and the **binding spoiler cutoff**
(`spoiler-cutoff.md`). `character-profiles-staging.md` is intentionally a
pointer stub. Only the Home-Region II and shared-pool dialogue drafts remain
live; shipped Riverfarm/Invrisil copy and art-direction staging are archived.

## `superpowers/` — the design record (append-only)
Specs and implementation plans per milestone, named
`YYYY-MM-DD-<topic>.md`. Plans carry an explicit `DONE` or `ACTIVE` header;
checkboxes inside executed plans are historical instructions, not open work.
Issues cite specs as design authority; never delete one an open issue references.

## `archive/` — shipped design and consumed-copy provenance
Superseded art direction plus staged dialogue/copy corpora that already
shipped into `data/` (kept because they answer "where did this come from").
The retired Fable→Opus operating manual also lives here; `AGENTS.md` and the
`wi-*` skills supersede its provider-specific workflow and ownership rules.
Session-lifecycle
artifacts (morning summaries, night goals, old handoff bodies) are NOT
kept here — they live in git history and the frozen-archive repo
(`GabrielGLevine/wandering_inn_rpg`, private).

## Generated docs — do NOT commit
Session-generated artifacts are gitignored by pattern: root
`MORNING_SUMMARY*.md` / `NIGHT-GOAL*.md`, `docs/reports/` (the landing
zone for any future generated report), `docs/*_api_key.txt` (secrets),
and everything under `.superpowers/` (ledgers, lane reports, shots).
If a new generator needs a home, point it at `docs/reports/`.
