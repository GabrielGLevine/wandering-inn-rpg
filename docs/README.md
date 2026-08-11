# docs/ — what lives where

**The plan lives on GitHub** (issues/milestones/labels + the Projects
board), not here. These docs are references, records, and state.

The rule that keeps this directory readable: **a file belongs in `docs/` only
if someone will read it to answer a question.** Working files a wave produced
on its way to a merge — lane briefs, lane reports, evidence bundles, run
reports, blind-read samples, per-phase worklists — are not that, and are
gitignored by pattern (see below). Gate fixtures are not that either: those
live next to the gate, in `wandering_inn_game/qa/baselines/`.

## Living references (edit in place)
| Doc | What |
|---|---|
| `DOC-MAP.md` | Agent-facing documentation ownership, status, and authority map |
| `ROADMAP.md` | Living milestone doc — the next-release shape |
| `CHOICE-LOG.md` | Unresolved and still-governing rulings |
| `VISUAL-LOG.md` | Standing visual-defect log — every milestone drains it |
| `TRIAGE.md` | Community-issue triage flow (local, no CI secrets) |
| `SECRETS-SETUP.md` | Fresh-machine key/secret provisioning |
| `asset-catalog.md` / `asset-index.{md,json}` / `scene-assembly-guide.md` | Art-sourcing workflow (index is consumed by tooling + registry tests — don't hand-edit the json) |
| `dialogue-voice-bible.md` + `dialogue-voice-cards/` | The dialogue writing contract: corpus-wide bible, per-cluster constraint cards, the cluster manifest, and the 11-tell critique the cards answer to |

## `design/` — content design (living)
Character profiles (the writing contract), the city-identity bible, the
narrator bible and prose review rubric, canon verdicts
(`k3-canon-verdicts.md`), and the **binding spoiler cutoff**
(`spoiler-cutoff.md`). `character-profiles-staging.md` is intentionally a
pointer stub. Only the Home-Region II and shared-pool dialogue drafts remain
live; shipped Riverfarm/Invrisil copy and art-direction staging are archived.

## `superpowers/` — the design record
Specs and implementation plans per milestone, named
`YYYY-MM-DD-<topic>.md`. Plans carry an explicit `DONE` or `ACTIVE` header;
checkboxes inside executed plans are historical instructions, not open work.
Issues cite specs as design authority; never delete one an open issue references.

Only the four subdirectories (`plans/`, `specs/`, `spike/`, `consultant/`)
belong here — `check_doc_drift.py` fails a loose file at the top level,
because that is where dispatch briefs and wave notes used to pile up.

## `steam/` — store-page assets
Capsule art, screenshots, the generator script, and the submission checklist.

## `archive/` — shipped design and consumed-copy provenance
Superseded art direction plus staged dialogue/copy corpora that already
shipped into `data/` (kept because they answer "where did this come from").
Session-lifecycle artifacts, retired operating manuals, completed dispatch
briefs, and obsolete roadmaps are not retained as files: git history is their
archive. This directory keeps only design and content provenance that still
answers where shipped work came from.

## Not in docs/ — do NOT commit here
Gitignored by pattern: root `MORNING_SUMMARY*.md` / `NIGHT-GOAL*.md` /
`LANE-BRIEF*.md` / `LANE-REPORT*.md`, the whole `lanes/` tree, any
`*-evidence/` directory, `docs/**/report-*.json`, `docs/reports/` (the landing
zone for any future generated report), `docs/*_api_key.txt` (secrets), and
everything under `.superpowers/` (ledgers, lane reports, shots).
If a new generator needs a home, point it at `docs/reports/`. If a new gate
needs a frozen corpus, point it at `wandering_inn_game/qa/baselines/`.
