# PixelLab AI-generated sprites — SHIP-OK (redistributable)

**Verdict: SHIP-OK.** Sprites generated via the PixelLab.ai API
(`api.pixellab.ai/v1`, `/generate-image-pixflux` + `/animate-with-text`)
using the account key at `docs/pixellab_api_key.txt` (gitignored). Per
PixelLab's Terms of Service, generated outputs are owned by the generating
user and are redistributable (usable in commercial and open-source
projects). No third-party pack license attaches to these — they are
original generations, not pack extracts.

## Shipped assets from this source (Track B1 + B3, 2026-07-06)

| Path | Subject | Prompt gist |
|---|---|---|
| `assets/sprites/relc/Idle-Sheet.png`, `Walk-Sheet.png` | Relc (Drake guardsman) | teal-green Drake city guardsman with spear, PC16-adjacent, transparent bg |
| `assets/sprites/pisces/Idle-Sheet.png`, `Walk-Sheet.png` | Pisces (Human necromancer) | hooded young human in immaculate white robes with faded trim |
| `assets/sprites/body_a/Cast_Side-Sheet.png` | PC cast/gesture strip | Body_A idle frame reference; raised-hand casting gesture + magic glow |
| `assets/sprites/cauldron/Idle-Sheet.png` | `stew_pot` prop (B3) | black iron cauldron on a small log fire, hard black outline, 16-bit; `low top-down` |
| `assets/sprites/training_dummy/Idle-Sheet.png` | `training_dummy` prop (B3) | straw practice-dummy pell, burlap head, wooden post, hard outline; `low top-down` |
| `assets/sprites/dirty_table/Idle-Sheet.png` | `dirty_table` pre-clean prop (B3) | wooden tavern table from above cluttered with dirty plates/mugs/scraps; `high top-down` |
| `assets/sprites/olesm/Idle-Sheet.png` | Olesm (Drake clerk, C2) | slim sky-blue Drake lizardman scholar, brown leather vest, holding a rolled map; `side` |
| `assets/sprites/zevara/Idle-Sheet.png` | Zevara (Drake Watch captain, C2) | armored light-blue Drake lizardman watch officer, steel armor, stern; `low top-down` |
| `assets/sprites/body_a/{Idle,Walk,Slice,Hit,Death,Cast}_{Down,Side,Up}-Sheet.png` | PC clothed base (F2, supersedes the row-17 Cast strip) | earth-tone traveler (olive-tan tunic, brown trousers, leather belt, brown hair); v2 8-dir `create-character-pro` (`mannequin`, `low top-down`) + `animate-character` template anims; 104×104 |

**Track F2 (2026-07-06)** replaced the naked Body_A PC via the **v2 character
pipeline** (`api.pixellab.ai/v2`; Tier-1 "Pixel Apprentice" subscription — the
trial's 40 free generations were exhausted by B1/B3/C2, prompting the
purchase). One consistent 8-direction clothed base (`create-character-pro`),
six template animations (`animate-character`, mode `template`:
`breathing-idle`/`walking`/`lead-jab`/`taking-punch`/`falling-back-death`/
`fireball`), frames pulled from the per-direction animation URLs. Only
south/east/north were animated (our `sprites.json` uses down/side/up; the
registry mirrors side for west). Character id
`35528619-54b4-4139-96eb-dbe2e6bf6e33`. Same PixelLab-ToS ownership /
redistributability as the v1 assets above.

Track B3 (2026-07-06) props are STATIC 1-frame sheets
(`/generate-image-pixflux`, `no_background: true`, 64×64) — no animation,
so no `/animate-with-text` pass. They closed the last three parked
VISUAL-LOG prop items (grill-reuse `stew_pot`, crate-placeholder
`training_dummy`, tint-only `dirty_table`).

Base frames generated with `no_background: true` (transparent), 64×64,
`view: low top-down`. Walk/cast frames via `/animate-with-text` fed the
base/reference frame. All post-processed (recentred, feet-plane aligned)
before integration. Non-directional (single facing) — `/rotate` drifted at
64px so a 4-directional set was parked, not shipped.

Provenance and the full candidate set (including parked/rejected ones) live
in `potential_assets/pixellab_2026-07-06/` (gitignored).
