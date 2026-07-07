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

## Private asset access (not a secret, but access-gated)
`scripts/fetch_private_assets.sh` / `fetch_potential_assets.sh` use
your `gh` login; you need read access to the private assets repo.
