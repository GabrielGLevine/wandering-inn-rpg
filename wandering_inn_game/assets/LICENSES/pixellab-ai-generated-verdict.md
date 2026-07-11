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

## Floodplains Wandering Inn facade (2026-07-08)

| Path | Subject | Source / notes |
|---|---|---|
| `assets/sprites/wandering_inn_facade/Idle-Sheet.png` | The Wandering Inn exterior on the floodplains | Bespoke alpha composite of two cached, user-owned PixelLab v2 `/map-objects` outputs: `prop_longhouse_thatch` (job `b7d617b0-b94b-4b9a-adc3-0afadf899583`) supplies the broad hall and roof wings; `prop_cottage_thatch_b` (job `b71044f1-7193-405c-8538-d4b9a90ea353`) supplies the central gabled entrance. Both were nearest-neighbor scaled and composited without paint-over, then cropped to the 120×73 alpha bounds. Zero new generations: shell DNS and the in-app browser path were unavailable. |

Anchor `[0.5, 1.0]` is measured from the cropped alpha bounds: the content
touches row 72 of the 73px frame, so the feet plane is the frame bottom.
Same PixelLab-ToS ownership / redistributability as the cached source
outputs above.

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

## Issue #9 Task G1 — the Garden of Sanctuary (2026-07-07)

Two owned assets from the pre-staged `potential_assets/pixellab_2026-07-07_garden/`
cache (art lane, direction.md/picks.md/handoff.md), generated ahead of this
wiring task via the same v1 static-prop recipe (`/generate-image-pixflux`,
`no_background: true`, hard-outline 16-bit top-down). The cache's other
outputs (memorial statues, the empty plinth, alternate door/sky-mist takes)
are G2/later-task scope, not committed this pass.

| Path | Subject | Source / notes |
|---|---|---|
| `assets/sprites/garden_door/Idle-Sheet.png` | `garden_door_inner` prop (Erin's own vine-wreathed garden door, the inn side) | `garden_door_v2.png` (the winning candidate; `garden_door.png` is an earlier rejected pass, NOT used). Static, 34×48, 1 frame. Alpha bbox rows 7–41 of 48 (feet plane 42/48 ≈ 0.875) — `anchor: [0.5, 0.875]` set in sprites.json per the ANCHOR RULE; `render_scale: 0.5` (matches the shipped `door`/`pantry_door_glow` props' scale at a near-identical native frame size). |
| `assets/tiles/garden/sky_mist.png` | Garden biome `skirt` tile (the impossible bright sky beyond the hedge hem) | `sky_mist_final.png` (the winning candidate over `sky_mist_tile.png`/`sky_mist_v2.png`, earlier passes, NOT used). Seamless, 32×32, `skirt_tile_px: 32`. |

Same PixelLab-ToS ownership / redistributability as everything above.

## Issue #9 Task G2 — the memorial hill (2026-07-07)

Five more owned assets from the same pre-staged cache G1 left uncommitted
(pixellab-batch.md's "KEEP" set — memorial statues + the empty plinth).
**Zero new PixelLab generations this task**, per the batch note's own
finding: "any sprite the game ever ships can become a remembrance statue
with zero new generations." Provenance chain per file: raw PixelLab
generation (cache, gitignored, not committed) → `stoneify.py` (the cache's
deterministic, alpha-preserving luminance→4-step-ramp recolor, keyed to the
pack statues' beige `rgb(130,117,100)`; script stays in the cache, not this
repo) → the `_stone.png` output committed below.

| Path | Subject | Source / notes |
|---|---|---|
| `assets/sprites/memorial_plinth/Idle-Sheet.png` | Waiting plinth (every memorial plot's base sprite) | `plinth_empty_stone.png` (batch item 5; raw `plinth_empty` rendered its "mist" as water, the ramp recolor fixed it). Static, 32×32, 1 frame. Anchor `[0.5, 0.75]` (alpha bbox feet plane 24/32). |
| `assets/sprites/memorial_statue_human/Idle-Sheet.png` | Memorial roster, human (apron + offering bowl) | `statue_human_stone.png` (batch item 4). Static, 32×48, 1 frame. Anchor `[0.5, 0.979]`. |
| `assets/sprites/memorial_statue_gnoll/Idle-Sheet.png` | Memorial roster, gnoll (sword point-down) | `statue_gnoll_v4_stone.png` (batch item 13, the winning pass after 3 rejects — v1/v2/v3 stay in the cache, NOT committed). Static, 32×48, 1 frame. Anchor `[0.5, 0.938]`. |
| `assets/sprites/memorial_statue_drake/Idle-Sheet.png` | Memorial roster, drake (soldier, spear + shield) | `statue_drake_stone.png` (batch item 2). Static, 32×48, 1 frame. Anchor `[0.5, 1.0]` (measured, not assumed — happens to equal the default). |
| `assets/sprites/memorial_statue_goblin/Idle-Sheet.png` | Memorial roster, goblin (reserved for the `goblins_spared` plot, no producer yet in this worktree) | `statue_goblin_v2_stone.png` (batch item 9, the winning pass after 1 reject). Static, 32×44, 1 frame. Anchor `[0.5, 0.977]`. |

All 5 anchors PIL-measured (alpha bbox bottom / frame height) per the
ANCHOR RULE, windowed-verified via `garden_walkthrough`. Same PixelLab-ToS
ownership / redistributability as everything above.

## Riverfarm 8b, Task R2 (2026-07-08) — combat data lane

Three static single-frame combat sprites, `/v1/generate-image-pixflux`
(`no_background: true`, 64×64, `view: "low top-down"`), one accepted
candidate each (3 gens total, no rejects). Provenance/raw outputs +
generator script: `/private/tmp/.../scratchpad/riverfarm_r2_gens/`
(session scratchpad, not committed — the PNGs below are the only
artifact). Anchors PIL alpha-bbox-measured per the ANCHOR RULE but **NOT
windowed-screenshot-verified** (R2 is a data-only lane with no skeleton_scene
placement in scope this task) — flagged for the RF-close machine-playtest
pass to confirm feet-plane/scale reads correctly once lane α wires the
encounter entities.

| Path | Subject | Prompt gist / notes |
|---|---|---|
| `assets/sprites/briar_collector/Idle-Sheet.png` | `briar_collectors` encounter roster (plant-class) | "animated briar bramble creature, thorned vine limbs, dark green foliage with wound-red berries, hunched menacing plant construct" — canon-cite wiki.wanderinginn.com/Plants (Birevine: "vines stronger than steel rope, covered in razor-sharp thorns"). Static, 64×64, 1 frame. Anchor `[0.5, 0.9531]`, `render_scale: 0.35`. |
| `assets/sprites/briar_collector_deep/Idle-Sheet.png` | `briar_collectors_deep` encounter roster (escalated wave, same canon-cite) | "larger animated briar thicket creature, denser thorned vine limbs, near-black foliage with many deep wound-red berries, taller hunched menacing plant construct" — deliberately darker/taller silhouette so the escalation reads visually. Static, 64×64, 1 frame. Anchor `[0.5, 0.9531]`, `render_scale: 0.4`. |
| `assets/sprites/river_wolf/Idle-Sheet.png` | `river_wolf_pack` (night-gated village-edge) roster | "mundane grey wolf, lean pack predator, low top-down game creature, fur texture, alert stance" — canon-cite wiki.wanderinginn.com/Monsters (Wilwolf, an attested wild-wolf monster whose fur is a crafting material, distinct from the goblin-tamed Carn Wolf). Chosen as an OWNED generation over the licensed Admurin Canine candidate `docs/design/riverfarm-art/picks.md` §6 flags, specifically so this lane never touches assets_manifest.json/the bundle (R2's charter). Static, 64×64, 1 frame. Anchor `[0.5, 0.7188]`, `render_scale: 0.32`. |

Same PixelLab-ToS ownership / redistributability as everything above.

## Invrisil 8c, Task C2 (2026-07-08) — combat data lane, `hired_blade` rig

The `hired_blades` roster (the merchant-prince's enforcers, warehouse fight)
is the game's first all-human combatant family — the design spec (§2/§5,
`docs/superpowers/specs/2026-07-06-invrisil-design.md`) requires a
merchant-livery palette EXPLICITLY NOT Watch-alike (the game's existing
Watch read is `royal_soldier`, steel/armored, tinted blue/brown for
`watch_sergeant`/`duty_sergeant` — no in-hand human rig carries civilian
"doublet + club" livery), so this task spent PixelLab v2 character-pipeline
generations rather than reusing/tinting an existing sprite. `footpad`
enemies (the alley sneak targets) needed no new generation — they reuse the
existing `human_laborer` rig verbatim (an honest civilian-clothes match,
zero gens).

**v2 character pipeline** (`/create-character-with-8-directions` standard
mode + `/animate-character` template mode, SEQUENTIAL per the ops rule —
one job polled to completion before the next was submitted): 1 character
create (1 generation) + `breathing-idle` animate ×3 directions (south/east/
north, 1 gen/direction) + `walking` animate ×3 directions (1 gen/direction)
= **7 generations spent** (balance 698 → 691, confirmed via `GET /balance`
before/after — within the task's ≤8 budget). Provenance (job records +
character zip export): `potential_assets/pixellab_2026-07-08_invrisil_combat/`.

| Path | Subject | Prompt gist / notes |
|---|---|---|
| `assets/sprites/hired_blade/Idle_Down-Sheet.png`, `Idle_Side-Sheet.png`, `Idle_Up-Sheet.png`, `Walk_Down-Sheet.png`, `Walk_Side-Sheet.png`, `Walk_Up-Sheet.png` | `hired_blades` encounter roster (all 3 members share this one rig, distinguished only by `combatants.json` stats/skills — same convention as `briar_collector`/`river_wolf`) | "a gritty human thug, tough muscular build, fitted burgundy doublet jacket with brass buttons over a cream shirt, dark brown trousers, tall leather boots, no armor, no helmet, gripping a wooden club in one hand, merchant hired muscle, menacing scowl, top-down RPG game character" — burgundy/maroon doublet + brass trim is the merchant-livery palette; deliberately warm-toned and unarmored, quarantined from `royal_soldier`'s cool steel-armor Watch read (no shared hue, no plate/mail silhouette). Directional + animated (idle=`breathing-idle`(4 frames), walk=`walking`(6 frames), down/side/up — side mirrors for west, same template family as `human_laborer`/`lyonette`). Native frame 148×148 (`create-character-with-8-directions` pads beyond the requested 104×104), `render_scale: 0.4324` (64/148, matches the shipped 64px apparent footprint). Anchor `[0.5, 0.8716]` — PIL alpha-bbox measured across idle/walk frames in all 3 directions (feet plane 126–131 of 148, stable; not windowed-screenshot-verified — this is a combat-data-only lane with no `skeleton_scene.json` placement in scope, flagged for the encounter-wiring task's own machine-playtest pass). |

Same PixelLab-ToS ownership / redistributability as everything above.

## Hotfix wave 2, item 6 (2026-07-09) — the anchor-stone waystone sprite

Playtest directive: the anchor-stone-per-region props (`street_anchor_stone`/
`riverfarm_anchor_stone`/`invrisil_anchor_stone`) all reused `boulder` and
read as plain rocks, not portals. One bespoke static prop,
`/v1/generate-image-pixflux` (`no_background: true`, 64×80,
`view: "low top-down"`), 2 candidates generated (well under the ≤6
budget), the second accepted on sight — a freestanding weathered/mossy
stone waystone archway with a faint painted glow in the empty opening,
no runes/text baked in (the #8 rune-glow rejection stands: target too
small for legible runes, so silhouette + glow carries the read). Raw
candidates: `/private/tmp/.../scratchpad/pixellab_waystone/gen1.png`
(rejected — read more like a doorway built into a wall than a
freestanding monument) and `gen2.png` (accepted, committed below).

| Path | Subject | Notes |
|---|---|---|
| `assets/sprites/anchor_waystone/Idle-Sheet.png` | `anchor_waystone` — the ONE portal-anchor sprite, wired to all three anchor-stone entities (data/portals.json's contract: one `sprites.json` entry swap, no per-site art) | Static, 64×80, 1 frame. Anchor `[0.5, 0.95]` (PIL alpha-bbox measured, bottom row 76 of 80). `render_scale: 0.4`. Each entity keeps its own `tint` (cold grey-blue / weathered grey / coin-gold, unchanged) plus a stronger, steady (non-flickering) `light` — street's is awakened-state-gated (matching its pre-awakening inert-stone fiction), riverfarm's is unconditional. `invrisil_anchor_stone` gets the sprite swap only, NO new light: `invrisil_boulevard`'s 8 `street_lamp` decor entries already sit at the hard 8-light-per-map budget (`WIWorld._rebuild_field`'s assertion) — a 9th light hard-failed the map build (caught live by `invrisil_walkthrough`'s SCRIPT ERROR before this was reverted). |

Same PixelLab-ToS ownership / redistributability as everything above.

## Invrisil 8c, Task C1 (2026-07-08) — maps/cast/arrival lane, the boulevard signature set

Five OWNED PixelLab statics, generated by the 2026-07-07 Invrisil art-director
lane (NOT by this task — zero generations spent here; full batch record with
endpoints, prompts, per-job `usage` costs, failure notes, and job ids:
`docs/design/invrisil-art/pixellab-batch.md`; per-job `job_*.json` provenance
records cached at `potential_assets/pixellab_2026-07-07_invrisil/`). This task
promoted them from the gitignored cache to real committed files (the garden
`sky_mist.png` precedent), wired via `data/sprites.json` + `data/biomes.json`.

| Path | Subject | Batch notes (see pixellab-batch.md for full params) |
|---|---|---|
| `assets/tiles/invrisil/tileset_marble_wang4x4.png` | `invrisil_street`/`invrisil_alley` biome floor (+ the boulevard's marble-plaza `floor_layers` patch) | `/create-tileset` wang corner set, 64×64 = 16 tiles of 16px, row-major by wang id (pure paving id 0 = [0,0] `#736c77`, pure marble id 15 = [3,3] `#f4f2ec`); tileset_id `bb9a3d67-a59e-4532-9787-840c90d7866e`. Batch cost 3. |
| `assets/sprites/invrisil/fountain_v2.png` | `plaza_fountain` (the boulevard landmark — "The Adventurer's Fountain", ORIGINAL, canon-ALIGNED with the City of Adventurers epithet) | `/map-objects` 80×96, first-try hero per the batch verdict. Static, 1 frame. Anchor `[0.4938, 0.9583]` (art lane PIL-measured), `render_scale: 0.6`. Cost 1. |
| `assets/sprites/invrisil/streetlamp_v2.png` | `street_lamp` (the lamp-row signature, 8 anchors, non-flicker gold pools) | `/map-objects` 32×64. Static, 1 frame. Anchor `[0.5312, 0.9531]`, `render_scale: 0.6`. Cost 1. |
| `assets/sprites/invrisil/shop_sign_v2.png` | `coin_shop_sign` (hanging coin-emblem shop boards) | `/map-objects` 32×32. Static, 1 frame. Anchor `[0.4688, 0.9375]`, `render_scale: 0.75`. Cost 1. |
| `assets/sprites/invrisil/guild_banner_v2.png` | `guild_banner` (cream+gold vertical facade banner; emblem re-roll spec queued in the batch doc, deliberately not spent) | `/map-objects` 32×64. Static, 1 frame. Anchor `[0.5, 0.9688]`, `render_scale: 0.5`. Cost 1. |

Same PixelLab-ToS ownership / redistributability as everything above.

## v0.4.1 playtest-fix batch (2026-07-09)

| Path | Subject | Notes |
|---|---|---|
| `assets/sprites/trail_gap/Idle-Sheet.png` | `trail_gap` (forest-trail-entrance door affordance; first use: the riverfarm↔witch-hollow door pair, which previously wore an ordinary tree sprite and was unfindable) | v1 `/generate-image-pixflux` 64×64, low top-down, first-try pass. Static, 1 frame, full-bleed. `render_scale: 0.6`. Cost 1. |

Same PixelLab-ToS ownership / redistributability as everything above.
| `assets/sprites/stairs_up/Idle-Sheet.png` | `stairs_up` (interior-staircase door affordance; first use: the inn's upstairs door — plain `door` sprite read as just another room, playtest finding 8) | v1 `/generate-image-pixflux` 64×64, low top-down, first-try pass. Static, 1 frame. `render_scale: 0.5`. Cost 1. |

## Item-icon batch (2026-07-10, inventory panel corner)
`assets/icons/items/<item_id>.png` — 25 icons, one per data/items.json
entry, PATH-BY-CONVENTION (no per-item data field; the inventory panel
derives the path from the item id and falls back gracefully when a
future item ships before its icon). v1 `/generate-image-pixflux` 32×32,
no_background, single-object-centered prompts. Cost 25.
Same PixelLab-ToS ownership / redistributability as everything above.

## Antinium batch (2026-07-11, issue #51)
| Asset | Consumer | Provenance |
|---|---|---|
| `assets/sprites/klbkch/{Idle,Walk}_{Down,Side,Up}-Sheet.png` | `klbkch` NPC (street gate plaza) | v2 create-character-with-8-directions char `085b8d4f` ("Antinium Worker guardsman, ant-like insectoid...") -> animate-character breathing-idle(4) + walking(6); 92x92 frames, side=east. |
| `assets/sprites/antinium_worker/Idle_{Down,Side,Up}-Sheet.png` | `antinium_worker_a/_b` ambient extras | v2 create-character-pro char `c46d1038` ("four-armed ant man drone...") -> breathing-idle(4); 116x116, idle-only by design. Attempt 1 (char `28eb787e`, two-armed) and a failed retry parked unused. |
| `assets/ui/icons/icon_invisibility.png` | `[Invisibility]` hotbar/journal icon | NOT PixelLab: hand-drawn 16px 2-tone glyph (controller), icon_sneak palette. Listed here for the icon set's audit trail. |

## 8d Phase A batch (2026-07-11)
| Asset | Consumer | Provenance |
|---|---|---|
| `assets/sprites/ceria/*` | Horns delve ally (8d) | pro char `0f4f644e` (half-Elf ice mage, wiki profile; NO circlet — Vol-8+ catch) → breathing-idle(4)+walking(6); 152px. |
| `assets/sprites/yvlon/*` | Horns delve ally | pro char `ec33c32c` (silversteel arms V6-honest) → idle(4)+walk(6)+jab(3); 176px. |
| `assets/sprites/ksmvr/*` | Horns delve ally | pro char `3dc39703` (four-arm worker kernel + gear harness) → idle(4)+walk(6)+jab(3); 128px. |
| `assets/sprites/klbkch/Slice_*` | GH#69 companion combat | jab(3) on char `085b8d4f`. |
| (pending integration) vault construct | 8d C3 boss | pro char `367edfed` v2 ("headless, rune-eye chest, full-frame"; v1 `ab80bd56` head-clipped, parked) 220px; anims generating. |
