---
name: wi-shipping
description: Use when deploying the Wandering Inn RPG to itch.io, cutting a release tag, managing the private asset overlay, handling external PRs, or debugging the CI/release workflows.
---

# Shipping (unified repo, CI, itch deploy)

## The repo model (UNIFIED as of 2026-07-07)
- **`github.com/GabrielGLevine/wandering-inn-rpg` is THE working repo** —
  development happens here, commits are PUBLIC the moment they push.
  There is no private working repo and no sync step anymore.
- **Private assets repo** `GabrielGLevine/wandering-inn-rpg-assets`:
  (1) `bundle-vN` releases = the licensed-asset overlay (fetched by
  release.yml via `PRIVATE_ASSETS_TOKEN`, and locally via
  `scripts/fetch_private_assets.sh`); (2) `potential-assets-vN` =
  parked source packs (`scripts/fetch_potential_assets.sh`).
- **The frozen archive** (pre-transition private repo, full history
  incl. licensed assets): `GabrielGLevine/wandering_inn_rpg`
  (underscores). Its history contains non-redistributable assets —
  it must NEVER be made public or pushed anywhere public. Read-only.

## The leak discipline (replaces the old sync-time check)
`scripts/leak_check.sh` runs FIRST in CI on every push/PR and fails if
any `assets_manifest.json` path (or its `.import`), any
`docs/*_api_key.txt`, or anything under `potential_assets/` is tracked.
`.gitignore` carries a GENERATED block covering every manifest path —
**regenerate it whenever assets_manifest.json changes** (the block is
labeled; scripts/fetch_private_assets.sh verifies coverage on every
overlay). Adding a NEW licensed asset = manifest entry + gitignore
block regen + `make_asset_bundle.sh` + new `bundle-vN` release, in that
order, BEFORE the sprite/data commit that references it.

## Local dev setup (fresh machine)
1. Clone the repo; `gh auth login`.
2. `scripts/fetch_private_assets.sh` — licensed art/music overlay
   (game boots on placeholders without it; fallback seam is shipped).
3. Optional: `scripts/fetch_potential_assets.sh` (~1GB source packs).
4. Key files (all gitignored, local-only): see `docs/SECRETS-SETUP.md`.
5. Import pass, then the full gate per wi-verifying-changes.

## The deploy (tag-driven, unchanged mechanics)
1. If protected assets changed: `scripts/make_asset_bundle.sh` →
   `gh release create bundle-vN ... -R GabrielGLevine/wandering-inn-rpg-assets`.
2. `git tag v0.x.y && git push origin v0.x.y` (same repo now).
3. release.yml: fetch bundle → overlay → FULL QA gate with real assets
   → wasm export → butler push to
   `sibianthegreybird/the-wandering-inn-rpg:html5`.
4. Watch: `gh run watch -R GabrielGLevine/wandering-inn-rpg <id>
   --exit-status`. Re-tag after a fix: `git push origin :refs/tags/vX`,
   `git tag -f`, re-push.

## External PRs (simplified by unification, 2026-07-07)
PRs merge NORMALLY on GitHub now — the old port-privately flow is dead.
CI (leak check + full sweep, fork-safe, zero secrets) gates every PR.
**The full end-to-end flow (triage → review bars → local test →
verdict → security posture) lives in the wi-handling-prs skill — use
it for every external PR.**

## Gotchas (each cost a real failure)
- **release.yml fetches the assets repo's LATEST release** (no tag pin) —
  a `potential-assets-vN` release created AFTER the newest bundle would
  become Latest and get overlaid as if it were the bundle. Cut every
  potential-assets release with `--prerelease` (prereleases never win
  Latest); pre-tag checklist: `gh release list -R ...-assets` and confirm
  the newest bundle carries the Latest badge. (potential-assets-v1
  predates bundle-v4 so 2026-07-08 is safe; the controller couldn't
  retro-mark it prerelease — permission-gated, flagged to user.)
- Butler broth host is **broth.itch.zone** (`.ovh` is dead — first-tag
  failure 2026-07-06).
- **Butler does NOT auto-create the itch page** with a wharf key
  ("invalid game") — the page must exist first (itch.io/game/new, kind
  HTML, slug must match ITCH_TARGET, draft is fine).
- macOS bash is 3.2: no `mapfile`; `set -u` + empty arrays need
  `${ARR[@]+"${ARR[@]}"}` (bundle-script portability bugs).
- Engine integrity = runtime check against the release's
  SHA512-SUMS.txt (no hand-pinned hashes to rot); butler version IS
  hand-pinned — bump deliberately.
- Web preset is single-threaded (`thread_support=false`) — runs on itch
  WITHOUT the SharedArrayBuffer toggle; flipping threads is a coupled
  3-part change (preset + itch toggle + web-parity runner).
- Secrets live ONLY in release.yml (tag-triggered); ci.yml must stay
  secret-free. `BUTLER_API_KEY` + `PRIVATE_ASSETS_TOKEN` on the repo.
  Local butler: `~/bin/butler`, key `docs/butler_api_key.txt`.
- The triage Action self-skips without `ANTHROPIC_API_KEY` (user has
  none — Claude Max): community triage is LOCAL, see docs/TRIAGE.md.
- **RETIRED (2026-07-07): `sync_public_export.sh` and
  `prepare_public_export.sh`** — the one-way private→public sync died
  with the unified transition. If you find a reference to "the sync,"
  it's stale doc — commits here ARE public.

## Licensing frame (user policy 2026-07-06)
Public repo = redistributable only (CC0/CC-BY/MIT/PixelLab outputs).
Redistribution-limited packs ship in the GAME via the private bundle —
nothing is cut from official builds for licensing; flag any
quality-for-licensing substitution to the user FIRST.
