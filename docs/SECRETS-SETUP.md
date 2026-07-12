# Secrets & Local Keys (unified repo, 2026-07-07)

Nothing secret is tracked. The leak check (`scripts/leak_check.sh`,
CI job 1) enforces this.

## Local key files (gitignored `docs/*_api_key.txt` — recreate by hand)
| File | What | Where to get it |
|---|---|---|
| `docs/butler_api_key.txt` | itch.io butler push (local use) | itch.io → account → API keys |
| `docs/pixellab_api_key.txt` | PixelLab sprite generation | pixellab.ai account |
| `docs/siliconflow_api_key.txt` | SiliconFlow cheap-delegate LLM | siliconflow account |
| `docs/retrodiffusion_api_key.txt` | RetroDiffusion (barely used) | retrodiffusion account |

One key per file, raw string, no quotes/newline decoration.

## Repo Actions secrets (Settings → Secrets → Actions)
- `BUTLER_API_KEY` — release.yml's itch deploy.
- `PRIVATE_ASSETS_TOKEN` — fine-grained PAT with read access to
  `GabrielGLevine/wandering-inn-rpg-assets`; user-minted (agents cannot
  create PATs). Used by release.yml's bundle fetch.
- ci.yml uses NO secrets by design (fork-PR safe).

## Steam build account (release.yml's `steampipe-upload` job, issue #19)
USER ACTION, full step-by-step (partner account, app fee, depots, the
private/unlisted branch, all the reasoning): `docs/steam/CHECKLIST.md`.
Short version of what lands here once provisioned — the job stays a
green no-op skeleton (`if: vars.STEAM_APP_ID != ''`) until all of these
exist:
- `STEAM_BUILD_ACCOUNT` (secret) — username of a dedicated
  limited-permission Steam build account (not the personal login).
- `STEAM_CONFIG_VDF` (secret) — base64 of a `config.vdf` produced by a
  ONE-TIME interactive `steamcmd +login` on a trusted local machine
  (captures the Steam Guard-authorized session so CI never sees a 2FA
  prompt); re-mint whenever the build account's password/Guard state
  changes.
- `STEAM_APP_ID` / `STEAM_BRANCH` / `STEAM_DEPOT_ID_WINDOWS` /
  `STEAM_DEPOT_ID_LINUX` (repo Variables, not secrets — `if:` conditions
  can't read Secrets pre-job). `STEAM_BRANCH` must never be `default`;
  the job refuses to run against the public depot.

## Private asset access (not a secret, but access-gated)
`scripts/fetch_private_assets.sh` / `fetch_potential_assets.sh` use
your `gh` login; you need read access to the private assets repo.
