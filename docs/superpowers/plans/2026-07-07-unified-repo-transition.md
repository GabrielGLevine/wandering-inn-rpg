# Unified-Repo Transition (user-directed 2026-07-07)

**Goal:** the public repo `GabrielGLevine/wandering-inn-rpg` becomes THE
working repo. The private repo freezes as a history archive. A fresh
agent session in the new repo prompted "Continue project work" must be
able to position itself from the repo + its GitHub issues and proceed.

**Why the split existed:** 160 asset paths (licensed packs, verdict
FORBIDDEN/NEEDS-ATTESTATION in `wandering_inn_game/assets_manifest.json`)
+ 4 gitignored API-key files + 1.8GB of `potential_assets/` source packs.
Everything else already ships publicly. The split's cost — one-way sync,
generated history, a PR flow that couldn't use the merge button — now
outweighs it.

## The new model

- **One repo.** Develop in the public repo's working copy; commits are
  public immediately. CI (full QA sweep) gates every push/PR; external
  PRs merge NORMALLY on GitHub (the port-privately flow retires).
- **Private asset overlay:** licensed assets live ONLY as bundle
  tarballs on the private `wandering-inn-rpg-assets` repo (as today, for
  release.yml). Locally, `scripts/fetch_private_assets.sh` downloads +
  extracts them into the working tree; a generated `.gitignore` block
  covers every manifest path so they can never be committed. Without the
  overlay the game still boots on placeholders (shipped fallback seam).
- **Leak guard:** `scripts/leak_check.sh` (extracted from the old sync
  script) fails CI if any manifest path, `.import` sidecar of one, or
  key-file pattern is ever tracked.
- **potential_assets parking:** per-pack tarballs uploaded to the
  private assets repo as release `potential-assets-v1` (licenses forbid
  redistribution — the assets repo is private; this is storage, not
  distribution). Local dir stays as an untracked cache;
  `scripts/fetch_potential_assets.sh` restores it on a fresh machine.
- **HANDOFF.md becomes tracked** (it was excluded as "internals"; the
  archive copies already shipped publicly via docs/archive/ and contain
  nothing sensitive — scrub-check is a phase gate anyway).
- **Secrets:** the 4 key files stay LOCAL-ONLY (gitignored, patterns
  hardened); `docs/SECRETS-SETUP.md` documents what exists and how to
  re-provision on a fresh machine. CI/release secrets unchanged
  (`BUTLER_API_KEY`, `PRIVATE_ASSETS_TOKEN` on the repo).

## Phases

- **P0 Inventory** ✅ (exclusion set, manifest count, remote states).
- **P1 Park potential_assets:** per-pack tarballs → assets-repo release.
- **P2 Overlay + guard scripts:** fetch_private_assets.sh,
  fetch_potential_assets.sh, leak_check.sh (+ CI wiring), generated
  ignore block.
- **P3 Docs/skills rewrite for the unified model:** top CLAUDE.md
  (+ the "Continue project work" bootstrap contract), wi-shipping,
  wi-start-here, wi-running-the-machine, CONTRIBUTING.md, HANDOVER doc;
  HANDOFF tracked; sync scripts retired with tombstones.
- **P4 Final sync + local migration:** last-ever sync ships all of the
  above; copy operational state (keys, ledger) into the public working
  copy; fetch overlay; run the FULL gate there (56/56 + units + smoke)
  — proof local dev is unimpeded.
- **P5 Cutover:** old private repo gets a DEPRECATED banner + final
  push to its (private) origin as the archive; the public working copy
  is renamed to `~/wandering-inn-rpg` as the canonical dir; agent
  memory updated; **successor rehearsal** — a fresh agent in the new
  dir prompted "Continue project work" (report-only) must derive
  position + a correct next action from the repo alone.

## Hard rules during transition

- The private repo's HISTORY can never be pushed anywhere public
  (licensed assets are IN it). Archive = private origin only.
- No other lanes write to either working tree between the final sync
  (P4) and cutover (P5).
- Every phase ends green or rolls back; the game must be deployable
  (tag-triggered release.yml) at every point.
