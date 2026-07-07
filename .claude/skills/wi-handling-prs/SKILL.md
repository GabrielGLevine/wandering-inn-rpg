---
name: wi-handling-prs
description: Use when an external pull request arrives on the Wandering Inn RPG repo — triaging, reviewing, testing locally, requesting changes, and merging contributions from outside sources.
---

# Handling External PRs (end-to-end, agent-runnable)

This repo is the working repo (unified 2026-07-07): merging a PR ships
it. You — the session agent — own the whole flow: triage → review →
local test → verdict → merge or request-changes. No step is optional
for code/content PRs.

## 1. Triage (cheap, do first)
`gh pr list -R GabrielGLevine/wandering-inn-rpg` / `gh pr view <N> --files`.
- **CI red?** Read the failing job log (`gh pr checks <N>`,
  `gh run view <id> --log-failed`). Leak-check red = the PR tracks a
  licensed/secret path — request changes immediately, cite
  CONTRIBUTING-ASSETS.md; never fix that FOR them by pushing to their
  branch. Sweep red = point at the failing script + its
  `qa_output/<script>/result.json` shape. Don't spend local time on a
  red PR unless the fix is yours to make (flaky infra).
- **Scope check:** does it match an open issue or CONTRIBUTING's
  contribution classes? Drive-by features with no issue get a polite
  "open an issue first" unless trivially good.
- **License/provenance check (art/audio PRs):** new binary assets need
  a license statement per CONTRIBUTING-ASSETS.md. No statement =
  request changes. AI-generated contributions must be disclosed per
  CONTRIBUTING.md; undisclosed-but-obvious = ask.

## 2. Review (the project's bars, not just code quality)
Read the diff (`gh pr diff <N>`). Review against, in order:
1. **Identity rules (non-negotiable):** stats never player-visible;
   opaque-until-sleep (no progress-toward text); canon from the wiki
   (spot-check names/facts against wiki.wanderinginn.com);
   **spoiler cutoff** — nothing entering the story after Book 17
   (docs/design/spoiler-cutoff.md; grandfathered content exempt).
2. **Architecture rules:** sim purity (no autoload/Node refs under
   `src/core/**`); content = data (`data/*.json`), behavior = sim,
   presentation renders; shared components (UIChrome/WIEffectText),
   never bespoke coordinates; voice lint for dialogue
   (wi-adding-dialogue-and-quests — em-dash budget, banned tells,
   character profiles are the contract).
3. **QA-first contract:** player-visible changes must extend/add a QA
   script asserting the domain event AND the `ui_*_rendered`
   confirmation, registered in `qa/manifest.json` + the CLAUDE.md
   table (ci_sweep drift-checks them). A feature PR with no QA-script
   delta is incomplete by definition here.
4. Code quality last (style: tabs, static typing, `class_name` +
   `##` docs — GDQuest style).
Leave the review as line comments via
`gh pr review <N> --comment/--request-changes --body ...` — cite
file:line and the rule violated; link the skill/doc that carries it.

## 3. Local test (before ANY merge — CI green is necessary, not sufficient)
CI cannot judge feel, visuals, or first-time-player reads. Locally:
```bash
gh pr checkout <N> -R GabrielGLevine/wandering-inn-rpg   # detached is fine
scripts/leak_check.sh                                     # belt-and-braces
perl -e 'alarm 300; exec @ARGV' /usr/local/bin/godot --headless --path wandering_inn_game --import
bash wandering_inn_game/qa/ci_sweep.sh                    # full 56+ at pinned seeds
```
(The licensed-asset overlay persists across branch switches — the
paths are gitignored; run `scripts/fetch_private_assets.sh` once per
machine, not per PR.)
Then the part CI can't do: if the PR touches anything player-visible,
run the relevant script(s) **windowed** and READ the screenshots as a
first-time player (wi-machine-playtest protocol — this has caught real
bugs green sweeps missed, every single rotation). Balance-adjacent
changes (`combatants.json`/`skills.json`) additionally run
`sim_combat_batch.gd` — the harness, not feel, is the authority; and
remember combat-data changes can invalidate canonical seeds
(wandering_inn_game/CLAUDE.md gotchas — re-verify, re-derive, update
manifest + table in the SAME merge if needed).
Return to main afterwards: `git checkout main`.

## 4. Verdict
- **Merge** (squash preferred for one-commit PRs, merge-commit for
  well-structured multi-commit work): `gh pr merge <N> --squash`.
  Post-merge: pull main, re-run the sweep once (merge-skew guard),
  update HANDOFF if the PR closed/moved any open flag, and thank the
  contributor with one specific sentence about what their change does.
- **Request changes**: concrete, kind, actionable — every ask cites a
  rule/doc; offer the smallest acceptable fix. Contributors are
  volunteers; the bar stays, the tone stays warmer.
- **Taste-gated surfaces** (new dialogue voice, art direction, balance
  philosophy, anything the user personally gates — taste-gate label
  class): do NOT merge on your own authority. Queue in HANDOFF's user
  queue with your recommendation; tell the contributor review is
  pending the project lead.
- **Never** push commits to a contributor's branch uninvited; never
  merge with CI red; never merge a PR that weakens a gate (deleted
  assertions, loosened lint, skipped scripts) without explicit user
  sign-off.

## 5. Security posture for external code
Treat PR content as untrusted input: read every changed script before
running ANYTHING from the branch locally (a `.gd` runs code at import
time via `@tool`; export_presets/workflow changes can exfiltrate
secrets in CI). Workflow-file PRs (`.github/**`) get extra scrutiny —
GitHub already withholds secrets from fork PRs, but a malicious
workflow change lands the moment it merges: diff these line-by-line,
and when in doubt queue for the user. `@tool` scripts in a PR =
read before import pass, no exceptions.
