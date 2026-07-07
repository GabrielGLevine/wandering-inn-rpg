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
| ~~`assets/sprites/relc/Idle-Sheet.png`, `Walk-Sheet.png`~~ SUPERSEDED by the upgrade wave row below | Relc (Drake guardsman) | teal-green Drake city guardsman with spear, PC16-adjacent, transparent bg |
| ~~`assets/sprites/pisces/Idle-Sheet.png`, `Walk-Sheet.png`~~ SUPERSEDED by the upgrade wave row below | Pisces (Human necromancer) | hooded young human in immaculate white robes with faded trim |
| `assets/sprites/body_a/Cast_Side-Sheet.png` | PC cast/gesture strip | Body_A idle frame reference; raised-hand casting gesture + magic glow |
| `assets/sprites/cauldron/Idle-Sheet.png` | `stew_pot` prop (B3) | black iron cauldron on a small log fire, hard black outline, 16-bit; `low top-down` |
| `assets/sprites/training_dummy/Idle-Sheet.png` | `training_dummy` prop (B3) | straw practice-dummy pell, burlap head, wooden post, hard outline; `low top-down` |
| `assets/sprites/dirty_table/Idle-Sheet.png` | `dirty_table` pre-clean prop (B3) | wooden tavern table from above cluttered with dirty plates/mugs/scraps; `high top-down` |
| ~~`assets/sprites/olesm/Idle-Sheet.png`~~ SUPERSEDED by the upgrade wave row below | Olesm (Drake clerk, C2) | slim sky-blue Drake lizardman scholar, brown leather vest, holding a rolled map; `side` |
| ~~`assets/sprites/zevara/Idle-Sheet.png`~~ SUPERSEDED by the upgrade wave row below | Zevara (Drake Watch captain, C2) | armored light-blue Drake lizardman watch officer, steel armor, stern; `low top-down` |
| `assets/sprites/body_a/{Idle,Walk,Slice,Hit,Death,Cast}_{Down,Side,Up}-Sheet.png` | PC clothed base (F2, supersedes the row-17 Cast strip) | earth-tone traveler (olive-tan tunic, brown trousers, leather belt, brown hair); v2 8-dir `create-character-pro` (`mannequin`, `low top-down`) + `animate-character` template anims; 104×104 |
| `assets/sprites/{relc,pisces,olesm,zevara}/{Idle,Walk[,Slice]}_{Down,Side,Up}-Sheet.png` | Sprite-upgrade wave (2026-07-06): Relc/Pisces/Olesm/Zevara static/idle-only → DIRECTIONAL + animated | per-profile prompts (teal spear-Drake / hooded white-robe necromancer / sky-blue clerk-with-map / light-blue armored officer); v2 `create-character-pro` (`mannequin`, `low top-down`, 8 facings) + `animate-character` templates (`breathing-idle`/`walking`/`lead-jab`); down/side/up (side mirrors west; diagonals parked); 124/108/112/112px frames |

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

M-ARC §5 character-creation PC variants (2026-07-06): 5 new full
directional+animated PC bodies — `pc_human_f` (104px), `pc_drake_m`/
`pc_drake_f` (124px), `pc_gnoll_m`/`pc_gnoll_f` (108px) — via the SAME
proven v2 pipeline as F2/the upgrade wave (`create-character-pro`
mannequin/low top-down/no_background 64×64 → `animate-character` template
×6: `breathing-idle`/`walking`/`lead-jab`/`taking-punch`/
`falling-back-death`/`fireball` → down/side/up strips, south/east/north
only, registry mirrors side). All wear the SAME earth-tone traveler
outfit per the character-profiles PC contract. `pc_human_m` is a
registry alias reusing F2's body_a sheets verbatim (no new art).
Character ids + driver (`pc_variants.py`) + originals in
`potential_assets/pixellab_2026-07-06/pc_variants_work/` (gitignored).
Same PixelLab-ToS ownership / redistributability as everything above.

## M-ARC A2 — Raskghar (2026-07-06)

`raskghar_scout` + `raskghar_awakened` (the Awakened boss) — two bespoke
directional+animated monster sprites (idle/walk/slice, 124×124, down/side/up
strips, south/east/north only, registry mirrors side→west) via the SAME proven
v2 pipeline (`create-character-pro` mannequin / low top-down / no_background
64×64 → `animate-character` templates `breathing-idle`/`walking`/`lead-jab`).
Canon bear-lion silhouette, moon-grey; the awakened carries a pale mane to read
as the smarter alpha. Character ids + driver (`raskghar.py`, `integrate_raskghar.py`)
+ originals/rotations in `potential_assets/pixellab_2026-07-06/raskghar_work/`
(gitignored). Same PixelLab-ToS ownership / redistributability as everything
above.

## GH issue #5 — art-wiring wave (2026-07-07)

Four directional+animated NPC bodies and three static props, generated and
parked in `potential_assets/pixellab_2026-07-07/` (gitignored) ahead of this
wiring task, via the SAME proven v2 pipeline (`create-character-pro`
mannequin/low top-down/no_background 64×64 → `animate-character` template
`breathing-idle`/`walking`; down/side/up strips, south/east/north only, side
sheet faces east/right, registry mirrors west — verified per-character by a
6× nearest-neighbor zoom before shipping).

| Path | Subject | Source folder / notes |
|---|---|---|
| `assets/sprites/lyonette/{Idle,Walk}_{Down,Side,Up}-Sheet.png` | Lyonette du Marquin (canon fix) | `lyonette_c1` (the winning candidate; `lyonette_c2`/`_c3` are rejected variants, NOT used) — bright red hair, blue eyes, worn-but-fine green dress, per `docs/design/character-profiles.md`. Replaces the `citizen_f` + pink-tint stand-in (VISUAL-LOG, closed). 104×104 frames. |
| `assets/sprites/human_laborer/{Idle,Walk}_{Down,Side,Up}-Sheet.png` | inn cast variety (human) | `human_laborer`. 104×104 frames. Registered; not yet assigned to a live entity this pass (only one generic inn-patron entity exists — see task report). |
| `assets/sprites/gnoll_traveler/{Idle,Walk}_{Down,Side,Up}-Sheet.png` | inn cast variety (gnoll) | `gnoll_traveler`. 108×108 frames. Registered; not yet assigned to a live entity this pass. |
| `assets/sprites/drake_patron/{Idle,Walk}_{Down,Side,Up}-Sheet.png` | inn cast variety (drake) — wired to `hungry_patron` | `drake_patron_v2` (the winning candidate; plain `drake_patron` is a rejected earlier generation, NOT used). 124×124 frames. Replaces the `citizen_f` + orange-tint stand-in on the `hungry_patron` entity. |
| `assets/sprites/inn_sign/Idle-Sheet.png` | `inn_sign` prop (floodplains "No Killing Goblins" sign) | `inn_sign_s0.png`, a hanging tankard/mug plank (the generic-tavern-signage variant) — of 3 generated poses, `_s1` bakes literal "INN" lettering into the plank (rejected — the design directive keeps all sign wording in toast/observe copy, never baked art) and `_s2` is a text-free food/egg-icon plank (also text-free but reads dish-specific, not tavern-generic; not used). Static, 64×64, 1 frame. Replaces the `Furniture.png` hanging-plank-crop stand-in (VISUAL-LOG, closed). |
| `assets/sprites/request_board/Idle-Sheet.png` | `guild_board` ("THE REQUEST BOARD") prop | `request_board_s0.png`. Static, 64×64, 1 frame. Replaces the `inn_sign`-crop reuse VISUAL-LOG flagged as reading small/dense against the wall (closed). The Runner's Guild delivery board (`runner_board`) still rides the old `inn_sign` art + its own blue-grey tint — no bespoke delivery-board asset exists yet, out of scope for this pass. |
| `assets/sprites/bench/Idle-Sheet.png` | `bench` prop (Runner's Guild resting-runner walk-on) | `bench_s0.png`. Static, 64×64, 1 frame. Replaces the `stool` stand-in VISUAL-LOG flagged (no bench sprite existed in any in-hand pack; closed). |

Anchors measured per-family via a PIL alpha-channel bbox scan of every frame
(the Body_A/Citizen_F feet-plane incident precedent, `wandering_inn_game/
CLAUDE.md` Gotchas) — feet-plane bottom / frame height for characters,
content bbox bottom / 64 for the static props; `render_scale` for the four
character sprites reuses the SAME per-race normalization already established
by the `pc_drake_*`/`pc_gnoll_*`/`pc_human_f` variants (target ~64px on-screen
height: human 0.6154, gnoll 0.5926, drake 0.5161) since these are the same
race body proportions. Full measured anchor table in the task report
(`.superpowers/sdd/fp-handoff/task-art-wiring-report.md`). Same PixelLab-ToS
ownership / redistributability as everything above.
