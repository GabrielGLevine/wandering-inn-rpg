---
name: wi-shipping
description: Use when deploying the Wandering Inn RPG to itch.io, syncing the public GitHub repo, building the private asset bundle, cutting a release tag, or debugging the CI/release workflows.
---

# Shipping (public repo, CI, itch deploy)

## The three repos
- **Private working repo** (this one): all development, full history,
  all assets.
- **Public repo** `github.com/GabrielGLevine/wandering-inn-rpg`
  (fresh history; working copy at `../wandering-inn-rpg-public`):
  everything MINUS assets_manifest.json's paths, keys, scratch,
  HANDOFF/NIGHT-GOAL internals. CI (ci.yml) runs the full QA gate on
  every push — secret-free, fork-safe.
- **Private assets repo** `GabrielGLevine/wandering-inn-rpg-assets`:
  bundle tarballs as releases; fetched by release.yml via the
  `PRIVATE_ASSETS_TOKEN` secret (fine-grained PAT, user-minted — agents
  CANNOT create PATs).

## The sync (after every committed change to public-shipped files)
`scripts/sync_public_export.sh -m "message"` — rsyncs (same exclusion
set as the initial export), leak-checks the manifest paths, commits +
pushes. The init-time `prepare_public_export.sh` is INIT-ONLY — never
re-run it against the pushed repo.

## The deploy (tag-driven)
1. Bundle current? If protected assets changed:
   `scripts/make_asset_bundle.sh OUT.tar.gz` → attach to a new release
   on the assets repo (`gh release create bundle-vN ... -R
   GabrielGLevine/wandering-inn-rpg-assets`).
2. From `../wandering-inn-rpg-public`:
   `git tag v0.x.y && git push origin v0.x.y`.
3. release.yml: fetch bundle → overlay → FULL QA gate with real assets
   → wasm export → butler push to
   `sibianthegreybird/the-wandering-inn-rpg:html5`.
4. Watch: `gh run watch -R GabrielGLevine/wandering-inn-rpg <id>
   --exit-status`. Re-tag after a fix: delete remote tag
   (`git push origin :refs/tags/vX`), `git tag -f`, re-push.

## Gotchas (each cost a real failure)
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
  secret-free. `BUTLER_API_KEY` + `PRIVATE_ASSETS_TOKEN` on the public
  repo. Local butler: `~/bin/butler`, key `docs/butler_api_key.txt`.
- The triage Action self-skips without `ANTHROPIC_API_KEY` (user has
  none — Claude Max): community triage is LOCAL, see docs/TRIAGE.md.

## Licensing frame (user policy 2026-07-06)
Public repo = redistributable only (CC0/CC-BY/MIT/PixelLab outputs).
Redistribution-limited packs ship in the GAME via the private bundle —
nothing is cut from official builds for licensing; flag any
quality-for-licensing substitution to the user FIRST.

## HEAD-based sync (hard rule, 2026-07-06)
`sync_public_export.sh` ships `git archive HEAD`, never the working
tree — a live implementer lane's uncommitted files once leaked
half-finished PC sprites into a release build. Never "fix" the script
back to tree-based; never hand-copy working-tree files to the public
repo while any lane is running.
