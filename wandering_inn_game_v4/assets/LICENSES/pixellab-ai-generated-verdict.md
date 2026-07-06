# PixelLab AI-generated sprites — SHIP-OK (redistributable)

**Verdict: SHIP-OK.** Sprites generated via the PixelLab.ai API
(`api.pixellab.ai/v1`, `/generate-image-pixflux` + `/animate-with-text`)
using the account key at `docs/pixellab_api_key.txt` (gitignored). Per
PixelLab's Terms of Service, generated outputs are owned by the generating
user and are redistributable (usable in commercial and open-source
projects). No third-party pack license attaches to these — they are
original generations, not pack extracts.

## Shipped assets from this source (Track B1, 2026-07-06)

| Path | Subject | Prompt gist |
|---|---|---|
| `assets/sprites/relc/Idle-Sheet.png`, `Walk-Sheet.png` | Relc (Drake guardsman) | teal-green Drake city guardsman with spear, PC16-adjacent, transparent bg |
| `assets/sprites/pisces/Idle-Sheet.png`, `Walk-Sheet.png` | Pisces (Human necromancer) | hooded young human in immaculate white robes with faded trim |
| `assets/sprites/body_a/Cast_Side-Sheet.png` | PC cast/gesture strip | Body_A idle frame reference; raised-hand casting gesture + magic glow |

Base frames generated with `no_background: true` (transparent), 64×64,
`view: low top-down`. Walk/cast frames via `/animate-with-text` fed the
base/reference frame. All post-processed (recentred, feet-plane aligned)
before integration. Non-directional (single facing) — `/rotate` drifted at
64px so a 4-directional set was parked, not shipped.

Provenance and the full candidate set (including parked/rejected ones) live
in `potential_assets/pixellab_2026-07-06/` (gitignored).
