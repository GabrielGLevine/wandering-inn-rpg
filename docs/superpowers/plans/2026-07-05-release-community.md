# M-RELEASE Implementation Plan

> Status: **DONE** — executed; retained as a design record.

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Project skills READ-ONLY for subagents. Controller commits per green task.

**Goal:** The ratified M-RELEASE design (spec `docs/superpowers/specs/2026-07-05-release-community-design.md` §1–§8): public MIT repo with fallback-art contract, private asset bundle, tag-driven itch.io wasm deploy, DCO, and the three community lanes.

**Architecture:** Two repos (public fresh-init + private assets overlay); GitHub Actions `ci.yml` (PR gate, secret-free) + `release.yml` (tag → bundle → wasm → butler); label-gated Opus triage. The QA suite is the CI.

**Tech Stack:** GitHub Actions, Godot 4.7 headless + wasm export templates (pinned), itch.io butler, DCO app, GitHub Issue Forms, claude-code-action.

## Global Constraints

- Code license MIT; asset license-in CC-BY-4.0 or MIT; DCO sign-off required (spec §1).
- CI test stage: `pull_request` event, ZERO secrets; deploy only in `release.yml` on `v*` tags (spec §3/§4/§7).
- Web demo: browser-local saves only; itch page needs SharedArrayBuffer toggle (spec §1/§4).
- Public checkout must pass the FULL QA gate with fallback art — no protected asset may be load-bearing for any QA assertion (spec §2/§7).
- Protected-asset set + history-scrub scope come from the audit report (`.superpowers/sdd/fp-handoff/release-asset-audit.md`) — R2/R6 read it as authority; R6 additionally needs explicit USER go.
- Stats-hidden + all repo conventions apply to every doc/template shown to contributors (they're our public voice).
- Concurrency: R1–R5 are new-files-only; R2's validation sweep runs only when the canonical suite is stable (post-O5 land).

---

### Task R1: `ci.yml` — the PR gate

**Files:** Create `.github/workflows/ci.yml`; Create `.github/pull_request_template.md`; Modify `wandering_inn_game_v4/CLAUDE.md` (one CI note line).
- Jobs (all on `pull_request` + `push: main`; no secrets): (1) engine setup — download the EXACT pinned Godot 4.7 headless build (explicit URL + sha256 check; do NOT float a third-party image tag); (2) smoke `--headless --quit`; (3) unit suites (enumerate the 13 from CLAUDE.md; alarm-wrapped); (4) full canonical sweep via `qa/run_qa.sh <script> headless --seed=<pinned>` reading the canonical table — implement as a matrix or a loop script `qa/ci_sweep.sh` that exits nonzero on any red AND greps logs for `SCRIPT ERROR|Parse Error|WARNING` (game_helper exempt) — the grep discipline is IN CI, not just convention; (5) web-parity script.
- PR template: gate-green checklist, windowed shots for player-visible changes, DCO note.
- Verification: `act` is NOT assumed — validate YAML (`actionlint` if available, else careful review) + run `qa/ci_sweep.sh` locally end-to-end; CI's first real run happens in the public repo (R6) — note this residual risk in the report.

### Task R2: BUILD the fallback-art path + asset manifest (rescoped per audit)

**AUDIT CORRECTION (2026-07-05):** `WISpriteRegistry` hard-asserts on any missing sheet — no runtime fallback exists (only 17 procedural skill icons degrade). R2 BUILDS it.

**Files:** Modify `src/**` sprite registry (missing-sheet path: render a legible placeholder chip — flat color by entity family + 1-2 char initial, feet-anchored, cell-sized — instead of asserting; same for missing audio: silent no-op with one logged line; NO behavior change when sheets present); Create `wandering_inn_game_v4/assets_manifest.json` (from the audit report: each FORBIDDEN/protected path, bundle source, fallback class); Create `qa/check_fallback_boot.sh` (copy tree to scratch MINUS manifest-protected paths → boot smoke → 3-4 representative canonical scripts incl. one windowed boot shot → green = contract holds); unit case: registry with a deleted sheet returns chip, no crash.
- **Gated on:** O5 landed (stable suite). Audit report = the manifest authority.
- Windowed fallback boot shot → controller-read (chips legible, nothing crashes, UI intact). Expect spartan — the FORBIDDEN set is the visual backbone; acceptable for the contributor path.

### Task R3: `release.yml` + private bundle + itch wiring

**Files:** Create `.github/workflows/release.yml` (trigger `push: tags: v*`; fetch private bundle via `PRIVATE_ASSETS_TOKEN` → overlay `assets/` → full gate re-run → wasm export w/ pinned 4.7 templates → `butler push build/web user/wandering-inn-demo:html5 --userversion $TAG` via `ITCH_API_KEY`); Create `scripts/make_asset_bundle.sh` (packs manifest-listed paths from THIS private repo into the bundle layout — run by user when assets change); Create `export_presets.cfg` web preset (browser-local saves note in the title footnote rides here or in R4's docs; canvas resize policy, thread support per itch SharedArrayBuffer).
- USER ACTIONS documented in the task report (not performable by agents): create private assets repo, itch project + API key, repo secrets, tag protection rule.
- Verification: local wasm export builds + boots in a local COOP/COEP server (`scripts/serve_web.sh` with the two headers); butler dry-run if butler installed, else documented as first-tag risk.

### Task R4: community docs lane

**Files:** Create `LICENSE` (MIT, user's name/year); `CONTRIBUTING.md` (build/run, QA loop front door, gate-green + shots requirement, DCO how-to, the "tune data never sim" + stats-hidden conventions stated for contributors); `CONTRIBUTING-ASSETS.md` (spec §6.3's real pipeline specs verbatim from wi-art-and-sprites + direction cards; license-in requirement); `CODE_OF_CONDUCT.md` (Contributor Covenant 2.1); `README.md` public-facing (what the game is, play-the-demo link placeholder, screenshots placeholder, contribution pointers, "saves live in your browser").
- Copy discipline: docs are player/contributor-facing — no internal codenames (M-FP, O5…), no stats leakage in screenshots chosen later.

### Task R5: issue forms + Opus triage action

**Files:** Create `.github/ISSUE_TEMPLATE/quest-idea.yml`, `dialogue-script.yml`, `skill-interaction.yml`, `map-suggestion.yml` (+ `config.yml` disabling blank issues); Create `.github/workflows/triage.yml` (trigger: `issues: labeled` == `triage`; runs claude-code-action (Opus) with a triage prompt file `.github/triage-prompt.md`); Create `.github/triage-prompt.md` (viability vs canon [wiki source-of-truth stated] + three-pillars balance + scope guard; output contract: EITHER a draft-spec comment in brainstorm format OR a needs-info comment; NEVER commits code; NEVER approves lore — flags lore calls for the user).
- Verification: form YAML schema-valid; workflow reviewed for permission scope (`issues: write` only, no `contents: write`); triage prompt dry-run locally against the user's example submission ("The player goes with the Rags tribe to eliminate a mothbear infestation") — output shape checked.

### Task R6: fresh-history public re-init (USER-GATED)

**Files:** Create `scripts/prepare_public_export.sh` (rsync tree → scratch, EXCLUDE: audit FORBIDDEN set, `potential_assets/`, gitignored scratch/ledger, `docs/siliconflow_api_key.txt` + any credential grep hits [run a secrets scan — `git grep` patterns + filename sweep], private HANDOFF internals if user wants; then `git init` + first commit); dry-run produces a report of what's in/out (tree listing + sizes) for USER REVIEW before anything is pushed anywhere.
- **Hard gates:** audit report verdicts final; user reviews the dry-run manifest; user creates the public GitHub repo + pushes. Nothing outward-facing happens without explicit user action.
- Post-push checklist (user): enable Actions, add secrets (R3's), tag protection, DCO app, branch protection (user-only merge), itch page SharedArrayBuffer toggle.

### Task RF: gate + docs + opus whole-branch review

- Full local gate (suite must be stable — post-O5); `qa/check_fallback_boot.sh` green; all YAML lint-clean; secrets scan clean.
- HANDOFF: M-RELEASE state + the user-action checklist (R3/R6 items) as a punch list.
- Opus review method hints: fork-PR secret exposure trace (every workflow × every event type), the fallback contract (pick 3 protected assets, trace registry fallback), manifest completeness vs audit report diff, triage action permission scope, DCO + license-in coherence (can a CC-BY asset legally ship in the MIT repo? — attribution file mechanism), prepare_public_export exclusion completeness (adversarial: find one leaked path).

## Self-review notes
- Spec §3→R1, §2/§5/§7→R2, §4→R3, §6.1/§6.3→R4, §6.2→R5, §5-reinit→R6, §7→RF. §1 decisions ride in every task's constraints.
- Attribution mechanism (CC-BY assets inside MIT repo) surfaced as an RF hint rather than a task — if R4 hits it concretely, add `ATTRIBUTION.md` there (cheap).
- Order: R1→R4→R5 anytime (new files); R2 post-audit+post-O5; R3 after R1 (shares engine-pin decisions); R6 after everything + user; RF last. R1/R4/R5 parallelizable lanes (disjoint files) if budget wants it.
