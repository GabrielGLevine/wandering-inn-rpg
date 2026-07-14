# VISUAL-LOG Wave 1: Generated Art Implementation Plan

> **Required skills:** `wi-running-the-machine`, `wi-art-and-sprites`,
> `wi-verifying-changes`, `godot-prompter:assets-pipeline`, and
> `godot-prompter:godot-testing`. Follow the repository PixelLab pipeline;
> static generation is for props/icons only, while creatures use the v2
> directional animation pipeline.
> **Parent:** `2026-07-14-visual-log-drain-master.md`

**Goal:** Replace the bounded placeholder/stand-in art with production-ready
sprites and icons that survive gameplay-scale windowed judgment.

**Architecture:** Candidate generation stays gitignored under
`potential_assets/pixellab_2026-07-14_visual_log/`. Only selected, measured
PNG sheets and their Godot import sidecars enter the public asset tree.
`data/sprites.json` remains the sole runtime catalog; consumers reference ids,
not paths. Generated art is preferred for bespoke needs, but a stronger
licensed in-hand candidate may win if it follows the private-bundle discipline.

---

## Task 1: Add failing integration contracts

**Files:**

- Modify: `wandering_inn_game/tests/test_sprite_registry.gd`
- Modify: `wandering_inn_game/tests/test_combat_data.gd`

- [ ] In `test_sprite_registry.gd`, add expected frame counts for all new ids:
  one frame for the twelve icons and every static prop; measured counts for
  `rock_crab`; and the exported PixelLab counts for every Shield Spider
  animation/direction.
- [ ] Add `_assert_visual_log_assets_are_real(catalog)` and call it after the
  catalog loop. It must assert the catalog contains every id below, every
  referenced `sheet`/`sheet_down`/`sheet_side`/`sheet_up` begins with
  `res://assets/`, `FileAccess.file_exists()` is true, and
  `WISpriteRegistry.is_fallback_sheet(path)` is false.
- [ ] Required catalog ids:

```text
icon_appraise_goods icon_called_shot icon_directed_strike
icon_disarm_trap icon_find_trap icon_flame_dart icon_flame_pillar
icon_measured_words icon_open_doors icon_perfect_hospitality
icon_piercing_volley icon_soothing_presence
rock_crab dart_slit_tell illusory_floor_tell delivery_board
guild_notice_wall deep_fissure cold_hearth gnaw_pile warren_mouth
nest_ledge shield_spider
```

- [ ] In `test_combat_data.gd`, shrink `KNOWN_ICONLESS_SKILLS` to only
  `guarding_ward`, `raskghar_maul`, and `slam`. Add an assertion that each
  other former allowlist id has an `icon` and the catalog contains it.
- [ ] Run the two tests and confirm RED for missing catalog/art/icon records:

```bash
cd wandering_inn_game
/usr/local/bin/godot --headless --path . --script tests/test_sprite_registry.gd
/usr/local/bin/godot --headless --path . --script tests/test_combat_data.gd
```

## Task 2: Generate and select the twelve skill icons

**Candidate area only:**

- Create locally: `potential_assets/pixellab_2026-07-14_visual_log/icons/`
- Do not track local drivers, responses, contact sheets, or rejects.

Generate transparent 64×64 top-down pixel-art candidates with PixelLab's
`POST /v1/generate-image-pixflux`, then nearest-neighbor downsample selected
winners to 16×16. Use no text, numerals, UI frame, cast shadow, or background.
Keep the existing hotbar palette and one dominant silhouette per icon.

| Id | Required read |
|---|---|
| `appraise_goods` | merchant lens over a small trade bundle |
| `called_shot` | marked weak point under a precise arrow |
| `directed_strike` | commanded sword-line converging on one target |
| `disarm_trap` | careful tool lifting a trap trigger |
| `find_trap` | alert eye revealing a hidden pressure mark |
| `flame_dart` | one narrow fast fire dart, distinct from bolt/pillar |
| `flame_pillar` | vertical column of flame with a grounded base |
| `measured_words` | restrained speech marks balanced like scales |
| `open_doors` | opening latch with an arcane glint |
| `perfect_hospitality` | warm tray/cup protected by a welcoming halo |
| `piercing_volley` | three arrows aligned through one armor seam |
| `soothing_presence` | calm concentric aura around a centered figure |

- [ ] Generate at most six candidates per icon; inspect at 64×64 and 16×16.
- [ ] Reject any icon whose primary read disappears at 16×16 or collides with
  an existing icon's silhouette.
- [ ] Copy winners to
  `wandering_inn_game/assets/ui/icons/icon_SKILL_ID.png`, import once with Godot,
  and keep the resulting `.png.import` sidecars.
- [ ] Add one-frame 16×16 catalog records to `data/sprites.json` and set each
  skill's `icon` field to `icon_SKILL_ID` in `data/skills.json`.
- [ ] Run `test_combat_data.gd` and `test_sprite_registry.gd`; expected GREEN.
- [ ] Run a windowed script that displays each changed class kit. Use the
  shortest existing canonical/fixture routes; add a temporary icon-gallery
  probe only if existing hotbars cannot show all twelve. Copy keeper frames,
  then delete the probe.

## Task 3: Generate and integrate the static prop set

**Selected public paths:**

```text
assets/sprites/dart_slit_tell/Idle-Sheet.png
assets/sprites/illusory_floor_tell/Idle-Sheet.png
assets/sprites/delivery_board/Idle-Sheet.png
assets/sprites/guild_notice_wall/Idle-Sheet.png
assets/sprites/deep_fissure/Idle-Sheet.png
assets/sprites/cold_hearth/Idle-Sheet.png
assets/sprites/gnaw_pile/Idle-Sheet.png
assets/sprites/warren_mouth/Idle-Sheet.png
assets/sprites/nest_ledge/Idle-Sheet.png
```

All props are transparent, static, nearest-filtered PNGs with one semantic
purpose and a measurable contact plane. Generate no more than six candidates
per subject and compare candidates against their actual scene-family crop.

| Subject | Palette/silhouette contract |
|---|---|
| dart slit | Cemetery brown-grey masonry; narrow wall slit, not a grate |
| illusory floor | Cemetery floor family; subtle seam/crack that remains visible under yellow/red state tint |
| delivery board | indoor timber, clustered slips and route strings; no grass base; distinct from request board |
| notice wall | pinned overlapping papers on wall backing; less formal than request board; not a shelf |
| deep fissure | collapsed black crack with broken cave lip and downward depth |
| cold hearth | dead coals/ash ring, horizontal and low; no active flame |
| gnaw pile | pale chewed bone/scrap cluster; unmistakable from a boulder |
| warren mouth | dark tunnel maw with clawed/crumbled edge; strong threshold read |
| nest ledge | broken sewer-brick overlook lip; horizontal wall-family geometry |

- [ ] For every winner, measure PNG dimensions, alpha bounding box, contact
  plane, and recommended anchor before adding its catalog record.
- [ ] Add or replace `data/sprites.json` records with the measured frame size,
  anchor, scale, one-frame idle animation, and a compressed provenance comment.
- [ ] Wire consumers:
  - `data/maps/dungeon/trapped_halls.json`: `dart_slit_a` →
    `dart_slit_tell`; retain the two visual-state tints on
    `illusory_floor_a` while replacing its art record.
  - `data/maps/liscor/runners_guild.json`: `runner_board` → `delivery_board`;
    remove compensating tint if the selected art reads correctly unmodified.
  - `data/maps/liscor/guild.json`: `guild_notice_wall` →
    `guild_notice_wall`; remove the shelf tint/stand-in treatment.
  - `data/maps/sewers/sewers.json`: `deep_fissure` → `deep_fissure` and
    `nest_ledge` → `nest_ledge`.
  - `data/maps/sewers/deep_tunnels.json`: `cold_hearth`, `gnaw_pile`, and
    `warren_mouth` each use their same-named sprite id.
- [ ] Run `test_sprite_registry.gd`, `test_sim_core.gd`, and `load_gate`.
- [ ] Run `delve_skill`, `delivery_loop`, `guild_interior_walkthrough`,
  `cisterns_scout`, and `deep_descent` windowed; inspect each prop at the
  gameplay camera and reject/regenerate any candidate that only works in a
  contact sheet.

## Task 4: Generate the boulder-mimic Rock Crab

**Files:**

- Replace: `wandering_inn_game/assets/sprites/rock_crab/Idle-Sheet.png`
- Modify: `wandering_inn_game/data/sprites.json`

- [ ] Generate from the live floodplains `boulder` palette and silhouette:
  neutral cool grey layered shell, irregular rock outline when tucked, legs
  and eyes readable only on closer inspection, no warm salmon/brown body, no
  grass base. Produce a restrained four-frame idle/tuck loop.
- [ ] Reject body plans that read as a generic beach crab, become smaller than
  the nearby boulder, or disappear completely under floodplains foliage.
- [ ] Integrate under the existing `rock_crab` sprite id so map/combatant data
  and shipped ids remain stable. Re-measure anchor/render scale instead of
  retaining `0.469/0.75/2.57` by assumption.
- [ ] Keep `tests/test_sprite_registry.gd` at the exported frame count.
- [ ] Run `crab_cull_loop` and the focused crab/boulder probe windowed.
  Acceptance requires boulder-family camouflage in the field frame and a
  readable creature in combat, with neither feet/contact drift nor player
  occlusion.

## Task 5: Generate the animated Shield Spider

**Selected public paths:**

```text
assets/sprites/shield_spider/Idle_Down-Sheet.png
assets/sprites/shield_spider/Idle_Side-Sheet.png
assets/sprites/shield_spider/Idle_Up-Sheet.png
assets/sprites/shield_spider/Slice_Down-Sheet.png
assets/sprites/shield_spider/Slice_Side-Sheet.png
assets/sprites/shield_spider/Slice_Up-Sheet.png
assets/sprites/shield_spider/Hit_Down-Sheet.png
assets/sprites/shield_spider/Hit_Side-Sheet.png
assets/sprites/shield_spider/Hit_Up-Sheet.png
assets/sprites/shield_spider/Death_Down-Sheet.png
assets/sprites/shield_spider/Death_Side-Sheet.png
assets/sprites/shield_spider/Death_Up-Sheet.png
```

- [ ] Use PixelLab v2
  `/create-character-with-8-directions` (or the higher-fidelity pro/v3 form)
  for a low top-down quadrupedal/arachnid base: eight legs, broad overlapping
  shield-like banded carapace, black/silver cave palette, no wings, no bat
  ears, no humanoid torso.
- [ ] Animate the existing character id with the closest stable templates for
  idle, melee lunge (`slice` consumer), hit reaction, and death. Reject any
  template that introduces a humanoid gait or changes the leg count/body plan.
- [ ] Export south/east/north; mirror east for west. Park diagonals and raw zip
  in the gitignored candidate area.
- [ ] Build directional sheets, measure alpha/contact across every frame, and
  register `shield_spider` with `directional: true`, real frame counts, anchor,
  render scale, shadow, and `idle/slice/hit/death` animations.
- [ ] Update both consumers:
  - `data/combatants.json` shield_spider → `sprite: "shield_spider"`; remove
    the bat-stand-in comment.
  - `data/maps/sewers/sewers.json` `shield_spiders` →
    `sprite: "shield_spider"`; remove the bat compensating tint.
- [ ] Run `test_sprite_registry.gd`, `test_combat_data.gd`,
  `test_combat_visuals.gd`, and `cisterns_fight` headless.
- [ ] Add before-autoplay and action/death screenshots temporarily to
  `cisterns_fight`, run windowed, copy evidence, then restore the canonical
  script unless those frames materially improve permanent coverage.
  Acceptance requires a clear field nest, two distinct arena bodies, a stable
  melee/hit/death sequence, and no frame-to-frame identity or anchor drift.

## Task 6: Provenance, import, verification, and commit

**Files:**

- Modify: `wandering_inn_game/assets/LICENSES/pixellab-ai-generated-verdict.md`
- Modify: `wandering_inn_game/data/sprites.json`
- Modify: all consumer/test files named above

- [ ] Append date, endpoint/pipeline, character/job ids, prompts, selected
  outputs, transformations, rejected-candidate reasons, and the statement that
  PixelLab outputs are redistributable under the repo policy.
- [ ] Run a Godot import pass and confirm every selected PNG has a committed
  `.png.import` sidecar and no fallback sheet is reported.
- [ ] If any licensed candidate won instead, complete the private manifest,
  ignore-block regeneration, bundle creation/release, and leak verification
  before this consumer commit.
- [ ] Run:

```bash
cd wandering_inn_game
/usr/local/bin/godot --headless --path . --quit
/usr/local/bin/godot --headless --path . --script tests/test_sprite_registry.gd
/usr/local/bin/godot --headless --path . --script tests/test_combat_data.gd
/usr/local/bin/godot --headless --path . --script tests/test_combat_visuals.gd
/usr/local/bin/godot --headless --path . --script tests/test_sim_core.gd
qa/run_qa.sh load_gate headless
cd ..
scripts/leak_check.sh
scripts/comment_census.py --check
git diff --check
```

Expected: all PASS, zero fallbacks for the new ids, zero tracked candidate/key
files, and zero warnings.

- [ ] Update the corresponding VISUAL-LOG rows with after-evidence paths and
  check only accepted art items.
- [ ] Update `HANDOFF.md`, then commit:

```bash
git add wandering_inn_game/assets wandering_inn_game/data \
  wandering_inn_game/tests docs/VISUAL-LOG.md HANDOFF.md
git commit -m "Replace VISUAL-LOG art stand-ins (#113)"
```
