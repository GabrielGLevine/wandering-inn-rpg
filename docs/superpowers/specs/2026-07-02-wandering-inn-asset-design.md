# Wandering Inn v4: Asset & Visual-Design Document

**Status:** draft for morning review. Not a plan — no task breakdown is committed to yet; Section 6 sketches sequencing for a future "M-Art" milestone.

**Scope note:** this doc's only game-side inputs are reads of `wandering_inn_game_v4/data/*.json`, `wandering_inn_game_v4/src/**` (for the entity/rendering inventory), and `wandering_inn_game_v4/CLAUDE.md`. No files under `wandering_inn_game_v4/` were modified to produce this document — an active pipeline is editing that tree concurrently. All findings below reflect a snapshot taken 2026-07-02.

---

## 0. TL;DR for the morning read

- **429 files** in `potential_assets/`, three packs, all by the same itch.io author family (Anokolisa's Pixel Crawler + two "Tiny RPG Character Asset Pack" freebies). Only **one** pack ships a license file.
- The two "Tiny RPG" character packs are **not** top-down field sprites — they're single-facing, ~100×100 canvas "battler" sprites (JRPG-battle-screen convention), visually and structurally incompatible with Pixel Crawler's top-down 4-direction convention. This is the single biggest art-direction decision this doc raises.
- Current game rendering is **100% placeholder** (`ColorRect` squares + `Label` text, see `src/world/world.gd` and `src/combat/combat_screen.gd`) — there is no sprite pipeline to retrofit, which is good news: whatever we pick, we're not fighting existing wiring.
- Coverage with in-hand assets alone: environment/props/tileset for the inn and a generic street ≈ 90% covered; player + generic female/male townsfolk ≈ 80% covered; **all combat-relevant enemies (goblins, Cave Spider, Goblin Chieftain) and the named Drake NPC (Relc) are a hard 0%** — nothing in either pack is a goblin, spider, or drakonid. VFX (line/frost/shield) and status/UI icons are also 0% (Icons/ folder has no exported PNGs at all, source-only).
- Recommend: keep Pixel Crawler as the environment + generic-human backbone, treat Tiny RPG packs as **non-goal for field/combat sprites** (maybe scavenge for portrait/dialogue busts only), and source goblins/spider/drake from a same-author or palette-compatible pack rather than mixing pixel densities.

---

## 1. Inventory & licenses

### 1.1 Directory census

```
potential_assets/                                          429 files total
├── Pixel Crawler - Free Pack/                              359 files
│   ├── Entities/Characters/Body_A/Animations/...            (player-customizable base body, directional)
│   ├── Entities/Characters/New_Version/Walk/                (2 .aseprite only, no PNG — WIP/incomplete, skip)
│   ├── Entities/Mobs/Orc Crew/{Orc, Rogue, Shaman, Warrior}  (single-facing combat mobs)
│   ├── Entities/Mobs/Skeleton Crew/{Base, Mage, Rogue, Warrior}
│   ├── Entities/Npc's/{Knight, Rogue, Wizzard}               (single-facing combat-style NPCs)
│   ├── Entities/Npc's/Citizen_F/Tavern_A/                    (directional field NPC — ONLY female NPC in either pack)
│   ├── Environment/Props/{Animated, Static}/                 (furniture, farm, tools, trees, esoteric/magic props)
│   ├── Environment/Structures/Buildings/{Interior, Roofs, Walls, Props, Shadows}
│   ├── Environment/Structures/Stations/{Alchemy, Anvil, Bonfire, Cooking, Furnace, Sawmill, Workbench}
│   ├── Environment/Tilesets/{Dungeon_Tiles, Floors_Tiles, Wall_Tiles, Wall_Variations, Water(_tiles)}
│   ├── Icons/Resources.aseprite                              (SOURCE ONLY — no exported PNG icon sheet)
│   ├── MockUps/{Tavern_01, Tavern_02}.png                    (author's own promo scenes, 1280×1280)
│   ├── Weapons/{Bone, Hands, Wood}                           (attachable weapon overlays)
│   └── Terms.txt                                             (the ONLY license file in all 429 files)
├── Tiny RPG Character Asset Pack 01 v2.0 -Free Soldier&Orc/  35 files — Soldier + Orc, battler-style
└── Tiny RPG Character Asset Pack 02 -Free Demon_A&Blood Monster_A/ 35 files — Demon_A + Blood Monster_A, battler-style
```

### 1.2 Licenses — read in full

**Pixel Crawler — `Terms.txt`** (only license doc found in the entire tree), author Anokolisa (AnomalyPixel@gmail.com, Patreon/Twitter @Anokolisa):
1. Credit not required, appreciated if given.
2. Assets may be altered in any shape/color/pattern; altered assets still **cannot be sold or marketed as a final product** without the author's authorization.
3. Assets cannot be resold as a standalone final product — only the original author sells the assets themselves.
4. **Commercial use in a finished game/project is explicitly allowed** ("creating commercial products, study or any other project where they are functional").

Net: safe to use, safe to recolor/edit, safe to ship in a commercial game. Not safe to extract and resell the sprites themselves.

**Tiny RPG Character Asset Pack 01 (Soldier & Orc) and 02 (Demon_A & Blood Monster_A) — NO license/terms/readme file present anywhere in either folder.** I verified this by walking every file in both packs (`find ... -iname "*licen*" -o -iname "*terms*" -o -iname "*readme*"` returns nothing for either). **VERIFY-BEFORE-USE.** Both packs use the "Tiny RPG Character Asset Pack" naming convention associated with itch.io creator **Free-Game-Assets / Anokolisa-adjacent "Tiny RPG" series** — I cannot confirm the exact publisher or license terms from disk. Before using either pack in any build (even a prototype), check:
- The itch.io page for "Tiny RPG Character Asset Pack 01 -Free Soldier&Orc" and "...02 -Free Demon_A&Blood Monster_A" for the license text itch.io requires publishers to state.
- Whether these are also Anokolisa (same visual family as Pixel Crawler judging by naming/versioning convention) or a different author entirely — the terms could differ materially (some "Tiny RPG" packs on itch are CC0, others are "credit required," others restrict commercial use).
Until that's confirmed, treat both Tiny RPG packs as **not clear to ship**, prototype-only.

### 1.3 Visual inspection findings

**Tavern_02 mockup** (`Pixel Crawler - Free Pack/MockUps/Tavern_02.png`, 1280×1280): a complete multi-room inn — kitchen (stove, ovens, prep counters, hanging pans), a bar with stools and a bottle rack, a dining hall (long blue-clothed banquet table, red round tables, wall sconces/chandeliers, trophy heads, wall-mounted weapons), a cellar/root-cellar with barrels and a bathtub, and three separate guest bedrooms each with a bed (blue/blue/red spreads), nightstand, rug, and window. Palette is warm wood-brown/stone-grey with saturated accent colors (red tablecloths, teal bath, green rugs). Two NPC sprites are visible in-scene (a cook and a barmaid), both drawn in the same directional-top-down convention as Body_A/Citizen_F. This mockup is essentially a ready-made floor plan for "The Wandering Inn" itself — directly reusable as reference or even as a paint-over base for a hand-built inn map.

**Character sheet, Pixel Crawler NPC convention** (`Entities/Npc's/Knight/Idle/Idle-Sheet.png`, 128×32 = 4 frames @ 32×32; `Run/Run-Sheet.png`, 384×64 = 6 frames @ 64×64): confirmed the Idle and Run animations for the same character ship on **different canvas sizes** (32×32 vs 64×64) — not a pixel-density inconsistency, just a canvas-bounds difference (Run needs more vertical travel for the bob), but it means naive fixed-grid slicing will break; frames must be sliced per-animation, not assumed uniform across an entity. Confirmed the same pattern on Rogue and Wizzard (Idle 128×32, Run 384×64) — consistent within the pack.

**Character sheet, Pixel Crawler player-body convention** (`Entities/Characters/Body_A/Animations/Idle_Base/Idle_Down-Sheet.png`, 256×64 = 4 frames @ 64×64): the customizable player body and Citizen_F both use **64×64** frames uniformly across all animations and both use the Down/Side/Up split-by-direction file convention (separate PNG per facing, to be mirrored for the 4th). This is the "field" convention — directly walkable, directly usable for the PC and for generic NPCs.

**Tileset sheet** (`Environment/Tilesets/Dungeon_Tiles.png`, 400×400): dungeon floor/wall autotile blob set, vine/foliage overlay tiles, wood plank/beam structural pieces, a spike trap row, blood-splatter decals, and colored crystal/gem props (red/blue/green). `Floors_Tiles.png` (400×400) is a matching blob-tileset for grass, dirt, sand, gravel, snow, and cobble/stone floors, using the classic 47-tile (or reduced) wang-blob layout. Palette across Dungeon_Tiles/Floors_Tiles/Interior_Props/Furniture is internally consistent — same desaturated wood-brown/stone-grey/forest-green family seen in the Tavern mockups. **All environment art in Pixel Crawler is one coherent palette family.**

**Tiny RPG character sheets** (`Soldier_Idle.png` 600×100 = 6 frames @ 100×100; `Orc_Idle.png` same; `Demon_A_Idle.png`/`Blood Monster_A_Idle.png` same): all four are **single-facing** (character faces right, presumably mirrored for left, with no distinct up/down poses), rendered small-and-centered inside a padded 100×100 canvas with a drop shadow — the classic "battler" sprite convention used for side-view JRPG battle screens or fighting-game-style select-and-attack setups, not a top-down walk cycle. Frame counts: Idle 6, Walk 8 (Soldier only checked; Orc/Demon/Blood Monster presumably match given identical canvas widths pattern), Attack01 6 (Soldier) / 7 (Demon_A), Death 4. Outline style is a soft dark-brown outline with painterly shading — visibly softer/more rendered than Pixel Crawler's flat-shaded, harder-outlined style. Palette: Soldier is blue-grey armor, Orc is olive-green, Demon_A is dark red/black, Blood Monster_A is a red blob creature — all darker/more saturated than Pixel Crawler's mid-tone palette.

**Verdict on cross-pack cohesion:** Pixel Crawler is internally consistent (one artist, one convention, one palette family, confirmed across Body_A/Citizen_F/Knight/Rogue/Wizzard/Orc-mobs/Skeleton-mobs/tilesets/props/mockups). The two Tiny RPG packs are internally consistent with **each other** (same 100×100 battler canvas, same soft-shaded style) but **not** with Pixel Crawler — different perspective convention (single-facing battler vs. 4-direction top-down), different line/shading treatment (soft painterly vs. flat/hard), and a darker, more saturated palette. Placing a Tiny RPG sprite directly into a Pixel Crawler top-down scene would look like a jarring pop-in — this is a real clash, not a minor nitpick.

---

## 2. Art direction

**Proposed direction (evaluated below):** 16px-class pixel art, top-down 3/4 perspective, Pixel Crawler as the environment backbone, Tiny RPG packs for characters.

**Honest judgment: half of this proposal holds, half doesn't.**

- Pixel Crawler as environment backbone: **holds.** It's the only pack with tilesets, structures, props, and stations at all — there's no alternative in-hand for environment art regardless. Its top-down 3/4 perspective is also the correct fit for the existing sim (a `Vector2i` grid world with 4-directional movement and door-based map transitions, per `data/skeleton_scene.json`).
- Tiny RPG packs as the character backbone: **does not hold**, per Section 1.3. They are single-facing battler sprites; the game's field is a 4-directional walk-around and its combat is a full 2D positional grid (`arenas.json`: 12×8 grid, flanking-relevant LoS, cardinal line-effects per the M3 plan) where enemies and allies can approach from any side. A sprite that only faces one direction (mirror for left/right, no up/down) will read as visibly wrong the first time a Cave Spider approaches from the north or a goblin flanks from behind — worse than placeholder squares, because now the player has a directional-motion expectation the art won't satisfy.
- Pixel Crawler's own **player-customizable Body_A + Citizen_F** convention (directional, 64×64, Down/Side/Up-mirrored) is the correct character backbone instead — it matches the field's movement model exactly and shares Pixel Crawler's palette/outline family with the environment, so PC and NPCs won't clash with the tavern they're standing in.
- Pixel Crawler's own **Mobs** (Orc Crew, Skeleton Crew) and combat-style **NPCs** (Knight, Rogue, Wizzard) are single-facing too (32×32 idle / 64×64 run canvas, one direction) — so even staying entirely inside Pixel Crawler doesn't fully solve directional combat sprites. This is a real, pack-wide limitation, not just a Tiny-RPG problem. Two honest options: (a) accept single-facing + horizontal-mirror-only for combat sprites, which is a common and acceptable simplification in many tactics games (units always "face" left or right, never up/down, positioning conveyed by grid position not sprite facing) — cheapest, ships with what's in-hand; (b) source or commission genuinely 4/8-directional mob sprites later, which is strictly a sourcing/cost problem, not a blocker for M-Art's first pass.

**Recommendation:** adopt Pixel Crawler exclusively as both environment and character backbone (drop Tiny RPG packs from the field/combat rendering plan entirely). Reserve the Tiny RPG packs for a narrow, optional secondary use — static single-frame "portrait" busts in the dialogue panel (`src/ui/dialogue_panel.gd`), where a single soft-shaded facing pose reads as a stylistic portrait rather than a broken walk-cycle, IF their license clears (Section 1.2). Do not recolor Tiny RPG sprites into Pixel Crawler's palette to try to unify them — the outline/shading treatment differs enough that a recolor won't fix the clash; it's a linework problem, not a palette problem.

Accept as a known, documented limitation: Pixel Crawler's own Mobs/NPC-battler sprites are single-facing. Ship with mirror-only facing for M-Art v1; revisit if playtesting shows it reads badly on the tactical grid.

---

## 3. Entity → sprite mapping

Source: `data/skeleton_scene.json` (field entities), `data/combatants.json` (current combatants), M3 plan (`docs/superpowers/plans/2026-07-02-wandering-inn-m3-combat-depth.md`, upcoming Cave Spider / Goblin Chieftain / cave arena / Dusty Scroll).

| Entity | Kind | Current data source | Best in-hand asset | Fit | Notes |
|---|---|---|---|---|---|
| PC ("Traveler") | player | `skeleton_scene.json` player, `combatants.json` "pc" | Pixel Crawler `Entities/Characters/Body_A` (directional, 64×64, Down/Side/Up + mirror) | **GOOD** | Customizable base body is the intended "blank slate" player avatar; matches field movement model exactly. |
| Erin | NPC (field) | `skeleton_scene.json` | Pixel Crawler `Entities/Npc's/Citizen_F/Tavern_A` (directional, 64×64) | **PARTIAL** | Only female-coded directional sprite in either pack. Generic "tavern girl" look, not Erin-specific (no apron/overalls, no distinctive hair). Usable as a placeholder-with-personality but not a true Erin likeness. |
| Lyonette | NPC (field) | `skeleton_scene.json` | Pixel Crawler `Entities/Npc's/Citizen_F/Tavern_A` (same asset as Erin) | **GAP (asset reuse conflict)** | Only one female directional sprite exists — using it for both Erin and Lyonette makes them visually identical, which actively confuses a first-time player (a Section-4-relevant "visually indistinguishable" trap per this repo's own gotcha list). Needs at minimum a recolor/hair-swap, ideally a second body. |
| Selys | NPC (field) | `skeleton_scene.json` | none directional-female left after Erin/Lyonette claim Citizen_F | **GAP** | Same asset-scarcity problem, worse — third female NPC, zero unclaimed directional female sprites remain. |
| Relc (Drake) | ally combatant | `combatants.json` "relc", allies in street encounters | none | **GAP — no drakonid/lizardman sprite anywhere in either pack** | Relc is one of the most visually load-bearing named characters (a Drake — bipedal reptilian, tail, scales) and there is nothing remotely matching in-hand. Placeholder-worthy at best; needs sourcing (Section 4). |
| Goblin Raider | enemy combatant | `combatants.json`, arena `goblin_ambush` | none | **GAP — no goblin sprite anywhere in either pack** | Confirmed via full-tree search (`find potential_assets -iname "*goblin*"` → zero hits). Orc Crew is the closest thematically (small green humanoid raider) but is a different named creature — using it plainly mislabels the enemy. |
| Goblin Shaman | enemy combatant | `combatants.json`, casts `flame_bolt` | none | **GAP** | Same as above; also needs a visible "casting" pose/VFX tell distinct from the melee raider. |
| Cave Spider | enemy combatant (M3-T7, arriving) | M3 plan `cave_mouth` arena | none | **GAP — no spider/arachnid sprite anywhere in either pack** | Confirmed via full-tree search. Also mechanically distinct (melee, high DEX) — will want a lower-profile, four/eight-legged silhouette that reads differently from the goblins at a glance. |
| Goblin Chieftain | enemy combatant (M3-T7, arriving) | M3 plan `chieftains_raid` encounter | none | **GAP** | Same root gap as the other goblins; ideally a recognizable "elite" recolor/bigger silhouette of whatever goblin base gets sourced. |
| Dusty Scroll | prop (M3-T5, arriving) | M3 plan, inn cell [8,5] | Pixel Crawler `Environment/Props/Static/Esoteric.png` (contains a parchment/tome icon) | **GOOD** | Esoteric.png includes book/parchment-style icons appropriate for a "strange symbols" scroll prop. |
| Dirty Table / bed / generic furniture | prop | `skeleton_scene.json` | Pixel Crawler `Environment/Structures/Buildings/Interior/Interior_Props_01.png` + `Environment/Props/Static/Furniture.png` | **GOOD** | Confirmed visually: beds (blue/red spreads), tables, benches, cabinets, doors, windows all present and match the Tavern mockup's furnishing exactly. |
| Doors (inn_door, street_door) | door | `skeleton_scene.json` | Pixel Crawler `Environment/Structures/Buildings/Interior/Interior_Props_01.png` (door tiles visible in sheet) | **GOOD** | Multiple door styles present (wood plank, framed). |
| Inn/street map tiles | environment | `skeleton_scene.json` maps | Pixel Crawler `Environment/Tilesets/{Floors_Tiles, Dungeon_Tiles, Wall_Tiles, Wall_Variations}` + `Structures/Buildings/{Walls, Roofs}` | **GOOD** | Full interior + street-adjacent exterior tile coverage; the Tavern mockups are close to a ready-made "inn" floor plan. |
| Combat arena floor (`goblin_ambush`, future `cave_mouth`) | arena | `arenas.json` | Pixel Crawler `Environment/Tilesets/Dungeon_Tiles.png` / `Floors_Tiles.png` (dirt/gravel/stone variants) | **GOOD** for goblin_ambush (street-adjacent, use dirt/cobble); **PARTIAL** for cave_mouth (Dungeon_Tiles has cave-adjacent stone/dungeon blocks but no purpose-built "cave mouth" set — workable, not purpose-built). | |

**Rough coverage tally:** of the ~14 mapped rows, 6 are GOOD, 2 are PARTIAL, 6 are GAP or asset-reuse-conflict. Everything environment/prop-side is covered; everything named-character or monster-side that isn't the generic PC is a gap. See Section 6 for the percentage framed against total asset need.

---

## 4. Gap list + sourcing

For every GAP, candidate packs are drawn from author/publisher names I have prior knowledge of from itch.io/OpenGameArt as active, real pixel-art asset publishers. **I have not fetched or verified any of these pages in this session — every entry below is marked with its verification status and none should be treated as confirmed until checked.**

### 4.1 Relc (Drake NPC + combat ally)
- **Anokolisa's other Pixel Crawler tiers/expansions** (paid "Pixel Crawler" DLC packs on itch.io, same author as the in-hand free pack) — if a lizardman/reptilian race pack exists in that line, it would be a perfect palette/style match since it's literally the same artist. **VERIFY**: does Anokolisa's paid Pixel Crawler catalog include a reptilian/lizardfolk race? Check itch.io/Anokolisa storefront.
- **Sanctumpixel** (itch.io monster/creature pixel-art publisher, known for RPG-style monster sets including reptilian beasts) — **VERIFY**: exact pack name and whether it includes a bipedal drakonid (not just a quadruped lizard/dragon) and its license terms.
- **CraftPix.net free section** — CraftPix regularly publishes free "lizardman"/"dragonborn" character packs with directional top-down sprites; their free tier is typically "free for commercial use with attribution," paid tier removes the attribution requirement. **VERIFY**: exact pack name, current license text (CraftPix terms vary pack-to-pack), and whether a free-tier lizardman exists right now vs. only paid.

### 4.2 Female human NPCs (Erin, Lyonette, Selys — need 2+ more distinct bodies/recolors beyond Citizen_F)
- **Recolor/re-hair Citizen_F in Aseprite** — cheapest option, zero new licensing risk (Pixel Crawler terms explicitly allow alteration), but only differentiates by color, not silhouette; may still read as "the same NPC in a different shirt" to a careful player. Not a sourcing gap, an art-time gap — flag for the aseprite pipeline in Section 5.
- **Shubibubi** ("cozy people"-style itch.io pixel-art publisher, known for small top-down character packs with a soft/rounded aesthetic similar in spirit to Pixel Crawler's own softness) — **VERIFY**: does their catalog include additional female top-down bodies at a compatible frame size/perspective, and license terms (Shubibubi packs are often "free, credit appreciated" similar to Anokolisa, but confirm per-pack).
- **Kenney** (kenney.nl, CC0 universally, extremely well-documented and always safe license-wise) — Kenney's "Tiny Town"/"RPG Urban Pack" character sets exist but Kenney's pixel density and outline style is flatter/more geometric than Pixel Crawler's — likely a *bigger* visual clash than the Tiny RPG packs already on disk. Only worth it if the direction pivots to a flatter style overall. **VERIFY** if considered.

### 4.3 True goblins (Raider, Shaman, Chieftain)
- **Anokolisa's paid Pixel Crawler tiers** — same reasoning as Relc: if the paid DLC line includes a goblin race, it's a same-artist, zero-clash source. **VERIFY** on itch.io/Anokolisa.
- **CraftPix.net free goblin packs** — CraftPix has published free goblin/orc top-down RPG character sets before; would need palette/outline comparison against Pixel Crawler once identified. **VERIFY** exact pack name + license.
- **Pixel-frog / "Tiny Swords"-adjacent goblin sets** — several itch.io publishers ship goblin sprites as part of small-scale strategy-game asset packs; likely wrong perspective (isometric or strategy-scale) rather than RPG top-down. **VERIFY** perspective before considering.
- **Fallback:** reskin/recolor Pixel Crawler's existing Orc Crew (already in-hand, same-pack, zero new license risk) as a stand-in "goblin-sized orc" and rename in UI copy only if lore accuracy is judged less important than shipping something coherent — NOT recommended given this repo's canon-fidelity standard (Orc ≠ Goblin, visually or lore-wise), but noted as the zero-cost fallback if sourcing stalls.

### 4.4 Cave Spider
- **Sanctumpixel** — again, this publisher's catalog reportedly spans multiple monster types including arachnids. **VERIFY** exact pack + license.
- **CraftPix.net free monster packs** — spiders are a common free-tier CraftPix monster. **VERIFY**.
- **BDragon1727** (itch.io, prolific free pixel-art VFX AND creature publisher) — has published creature packs alongside their well-known VFX packs (see 4.6). **VERIFY** whether their creature catalog includes an arachnid and whether it's top-down.

### 4.5 Status icons + UI frame/font
- **Kenney's UI Pack / Game Icons** (CC0, kenney.nl) — Kenney is the single safest, best-documented source for a UI icon set (status effect icons, generic RPG icons) and a UI panel/frame kit; CC0 means zero license research burden. Style will be flatter than Pixel Crawler but **UI chrome is more forgiving of style mixing than character/environment art** (players tolerate a clean flat-icon HUD over painterly game art far more than they tolerate mismatched character sprites) — this is a reasonable place to accept a style seam if needed. **VERIFY** current pack name/URL (Kenney reorganizes pack names periodically).
- **Pixel Crawler's own `Icons/Resources.aseprite`** — exists but has **no exported PNG**, confirmed by direct file check (`find .../Icons -type f` returns only the `.aseprite` source). This is a same-pack, zero-license-risk source **if** someone exports it from the source file — not a sourcing gap so much as a "someone needs to open Aseprite and hit export" gap. Flag for the aseprite pipeline (Section 5) before looking externally.
- **Font**: no pixel font shipped in any pack (confirmed — no `.ttf`/`.otf`/`.fnt` files anywhere in `potential_assets/`). **Kenney Fonts** (CC0, several pixel-style bitmap fonts) or **itch.io "m5x7"/"Pixel Operator"** (both well-known free pixel fonts, common license: free for commercial use, credit appreciated — **VERIFY** current terms per font) are standard, safe choices.

### 4.6 Spell VFX (line-jet, frost, shield) + status icons
- **BDragon1727** (itch.io) — widely-cited free/cheap pixel VFX publisher covering fire/ice/magic-shield effect sheets; plausibly has assets matching Flame Jet (fire line/beam), Frost Bolt (ice projectile/slow puff), and Mana Shield (barrier flash) needs directly. **VERIFY** exact pack names, current license terms (BDragon1727 packs are typically itch.io "pay what you want" with a free tier — confirm per-pack, don't assume blanket terms).
- **Pimen** (itch.io, VFX-focused pixel-art publisher, well-known for elemental spell-effect sheets: fire, ice, lightning, shield/barrier) — strong thematic fit for exactly this need (fire line, frost bolt, mana shield all map to Pimen's typical catalog categories). **VERIFY** exact pack names + license (Pimen's free vs. paid tiers differ).
- **Pixel Crawler's own `Bonfire/Fire_01`, `Fire_02`, `Smoke` animated sheets** (already in-hand, `Environment/Structures/Stations/Bonfire/`) — these are static-fire-pit VFX, not a projectile/line effect, but could be cannibalized/re-timed as a rough Flame Jet stand-in with zero new sourcing, same-pack palette match. Worth prototyping before reaching externally.

---

## 5. Integration plan

### 5.1 Cell-size decision

Current state (confirmed by direct read): field renders at `CELL := 64` (`src/world/world.gd`), combat renders at `CELL := 48` (`src/combat/combat_screen.gd`) — two different placeholder-square sizes chosen independently, no sprite assumption baked in either way.

Pixel Crawler's native frame size is also split: player/NPC field bodies are 64×64 canvas (art content roughly 32-40px tall within that canvas, walking-figure convention), combat mobs are 32×32 (idle) / 64×64 (run) canvas. Tilesets are 32×32 per-tile at native pixel scale (400×400 sheets, blob-tileset convention, confirmed via `Dungeon_Tiles.png`/`Floors_Tiles.png` dimensions and visual blob-tile pattern).

**Recommendation: unify on 64px cells for both field and combat**, i.e. change combat's `CELL` from 48 to 64 to match the field and match Pixel Crawler's native body/tile canvas 1:1 (no runtime scaling, crispest possible pixel-art result at any integer window zoom). Reasons:
- 64 already matches the field, the player body sprite's canvas, and is a clean 2x multiple of the 32px tile-native unit, so tiles and characters both drop in without off-grid scaling artifacts.
- Combat's grid is 12×8 (`arenas.json`) — at 64px that's a 768×512 board, comfortably inside a normal window; no forced shrink needed.
- The alternative (scale everything down to a tight 48px combat grid) would require non-integer scaling of 64px-native art, producing visible pixel-art shimmer/blur — avoid.

### 5.2 TileMapLayer strategy: hand-painted vs. data→codegen

This is the sharpest tension against the repo's stated content-is-data principle (`CLAUDE.md`: "Content is data + code: new entities/skills go in `data/*.json`; new behavior goes in the sim; presentation only renders... no hand-authored .tscn beyond the trivial `src/world/world.tscn` root").

- **Hand-painted TileMapLayer scenes** (paint the inn/street/cave_mouth by hand in the Godot editor) would be the fastest path to a *good-looking* result — the Tavern mockups are essentially reference floor plans ready to trace — but directly violates the "no hand-authored scenes beyond the trivial root" convention this project has held since M0, and reintroduces exactly the kind of drift-from-data risk the QA-first architecture was built to avoid (a hand-painted scene can't be regenerated from `skeleton_scene.json`, and a data change no longer guarantees a matching visual change).
- **Data→codegen** (extend `skeleton_scene.json`'s `grid`/`blocked` schema with a tile-type-per-cell or a small per-map "biome" tag, and have `world.gd`'s `_build_floor()` emit `TileMapLayer.set_cell()` calls instead of `ColorRect`s) preserves the content-is-data principle exactly, keeps the QA harness's structural assertions valid (grid dimensions, blocked cells, entity positions are still pure data), and is the option consistent with everything M0-M3 already built. Cost: visual richness will be plainer than a hand-painted mockup-quality scene (autotile blob rules can only do so much without hand placement of furniture/props), and prop placement (the Tavern mockup's beds/tables/chandeliers) would need its own data schema extension (e.g. a `props: [{id, cell, sprite}]` list per map, which `skeleton_scene.json` partially already has via the `entities` array's `prop` kind — extending that array's schema with a `sprite` field is a small, natural step, not a new pattern).

**Recommendation: data→codegen**, extending the existing `entities`/`grid` schema rather than introducing hand-authored scenes. This keeps M-Art inside the architecture the rest of the project trusts, at the cost of "good, not stunning" first-pass visuals — acceptable for a QA-first prototype where the win condition is "readable and correct," not "portfolio screenshot."

### 5.3 AnimatedSprite2D entity rendering

Scene JSON (`skeleton_scene.json`, `combatants.json`, `arenas.json`) gains a `sprite` reference per entity/combatant — e.g. `"sprite": "pixel_crawler/body_a"` or `"sprite": "pixel_crawler/npc_citizen_f"` — resolved by a small sprite-registry lookup (mirroring the existing `skills.json`/`classes.json` catalog-by-id pattern already used throughout the sim) rather than hardcoding paths in `world.gd`/`combat_screen.gd`. `_make_square()` (world.gd) and its combat-screen equivalent get replaced by an `AnimatedSprite2D` (or `Sprite2D` + manual `SpriteFrames` built from the registry) driven by the same domain events that currently move `ColorRect`s.

### 5.4 Animation states needed per system vs. what packs provide

| System | States needed | Pixel Crawler provides (Body_A / directional NPCs) | Pixel Crawler provides (Mobs / battler NPCs) |
|---|---|---|---|
| Field movement | idle, walk (×4 directions or ×3 + mirror) | **Idle_Base, Walk_Base** (Down/Side/Up + mirror) — full coverage | n/a (mobs don't walk the field) |
| Combat — melee | idle, attack (slice/pierce), hurt, death | Idle_Base + **Slice_Base, Pierce_Base** (attack), **Hit_Base** (hurt), **Death_Base** — full coverage for Body_A-based PC | Idle, Run, Death only — **no distinct attack or hurt pose**; attacks would have to reuse Idle or Run as a stand-in, and "hurt" has no dedicated frame at all |
| Combat — ranged/caster | idle, cast, hurt, death | no dedicated "cast" animation on Body_A (would reuse Idle or a held-prop pose) | Skeleton - Mage exists as a distinct mob variant but shares the same Idle/Run/Death-only limitation |
| Combat — movement (Dash, per M3) | a distinguishable "dash/lunge" beat, or reuse walk/run at higher speed | **Run_Base** covers this adequately (reuse run cycle, no new animation needed) | Run covers this too |
| Status feedback (slowed, mana shield) | a visual tint/overlay or a small icon badge, not a full animation | none — needs a shader tint (e.g. blue tint for slowed) or an icon overlay, not sprite-provided | same |
| Line/spell VFX (Flame Jet, Frost Bolt) | a traveling or line-shaped particle/sprite effect | none (see Section 4.6 gap) | none |

**Net:** Body_A (PC) has full animation coverage in-hand. Mob/NPC-battler sprites (everything currently planned as an enemy) are missing dedicated attack and hurt animations — Idle/Run/Death only. First-pass M-Art should accept Idle-as-attack-pose and a simple flash/tint-as-hurt-feedback (already how many small pixel-art tactics games handle it) rather than blocking on sourcing dedicated attack/hurt frames for every mob.

### 5.5 QA impact analysis

- **Event-based assertions are unaffected.** The QA harness (`qa/test_driver.gd`) asserts on `ObservableBus` domain events and `Game.sim.snapshot()` state — none of that changes when `ColorRect` becomes `AnimatedSprite2D`; the sim stays pure and rendering stays a downstream concern, per the architecture's own separation.
- **Screenshot baselines change.** Every `windowed` QA script that reads PNGs to "see what a player sees" (per `wandering_inn_game_v4/CLAUDE.md`) will produce visually different screenshots once real sprites land — any QA script or report that embeds or diffs against a specific placeholder-square screenshot needs re-capture, not just re-running. No pixel-diff assertions currently exist in the harness (it's presence/absence and event-payload based per the CLAUDE.md description), so this is a one-time re-capture cost, not a new fragile dependency — but flag it explicitly so the next session doesn't compare fresh sprite screenshots against stale placeholder ones and think something broke.
- **Windowed size**: combat's window/board sizing is currently tuned around `CELL=48` on a 12×8 grid (576×384 board within whatever the window default is); moving to `CELL=64` (Section 5.1) grows that to 768×512 — verify the QA harness's windowed screenshot capture region/window size is not hardcoded smaller than this anywhere in `qa/test_driver.gd` or the run scripts before landing the cell-size change.

### 5.6 Editor-MCP revisit note

The repo's user-memory notes a standing preference for headless CLI over the Godot MCP server (context-cost reasons). This doc's recommendation (Section 5.2: data→codegen, no hand-authored TileMapLayer scenes) means that preference doesn't need revisiting yet — codegen'd tilemaps are inspectable via headless screenshot the same way placeholder rects are today. **If a future decision reverses course toward hand-painted tilemap scenes** (e.g. if data→codegen's visual ceiling proves too plain even after a fair prototype), *that* would be the trigger to re-evaluate a free Godot editor MCP for interactive tile-painting — not before. Flagging this explicitly so it isn't silently relitigated.

### 5.7 Aseprite pipeline

Every Pixel Crawler asset ships its `.aseprite` source alongside the exported `.png` (confirmed: 178 PNGs vs. 179 .aseprite files in the pack — near 1:1, the one extra `.aseprite` being `New_Version/Walk/` which has no PNG export yet). Pixel Crawler's Terms.txt explicitly permits alteration ("The arts present can be altered in any shape, color or pattern"), so the pipeline for recolors (Section 4.2's Citizen_F re-hair/recolor need) and for exporting the missing `Icons/Resources.aseprite` (Section 4.5) is: open in Aseprite, edit/export, drop the PNG into the project's sprite-registry path. No new tooling needed — this is exactly the workflow the asset author designed for (source files are the deliverable, not just the PNGs).

---

## 6. Cost & sequencing

### 6.1 What's achievable with in-hand assets alone

Rough coverage estimate, weighted by what actually renders on screen most often (not a flat entity count):

- **Environment (inn interior, street, generic dungeon/cave tiles, props/furniture):** ~90% covered. This is Pixel Crawler's deepest, most complete category (233 of its 359 files are Environment). The Tavern mockups double as floor-plan reference. Cave-specific tiles (for the upcoming `cave_mouth` arena) are only partially purpose-built (Dungeon_Tiles reads as "generic stone dungeon," not distinctly "cave mouth") but workable.
- **Player character (PC):** 100% covered — Body_A has full directional walk + full combat animation set (idle/slice/pierce/hit/death).
- **Generic/background NPCs:** ~50% covered — only one directional female body exists in either pack (Citizen_F), and zero directional male bodies distinct from Body_A itself (Knight/Rogue/Wizzard are single-facing battler-style, not field-walkable). Named NPCs (Erin, Lyonette, Selys) currently must share or reuse this single asset, which Section 3 flags as an active player-confusion risk, not just an aesthetic shortfall.
- **Named/lore-critical characters (Relc) and all current+upcoming enemies (goblins ×3 variants, Cave Spider):** **0% covered.** Nothing in-hand matches any of these. This is the single largest gap and the one most likely to block a visually-complete combat screen even after everything else in this doc ships.
- **VFX (Flame Jet line, Frost Bolt, Mana Shield) and UI (status icons, HUD frame, font):** **0% covered** from exported assets (Icons folder is source-only; no VFX sheets beyond the reusable-but-imperfect Bonfire fire loop; no font anywhere in the tree).

**Overall estimate: roughly 55-60% of what a fully-dressed build needs is achievable from in-hand assets alone** (weighted toward environment/PC being disproportionately screen-time-heavy relative to any single enemy type) — but the **combat screen specifically**, which per M3 is where the project's active development effort is concentrated, is closer to **20-25% covered** (arena floor tiles yes, every combatant sprite no) since literally every combatant except the PC is currently a gap.

### 6.2 What needs sourcing

In priority order (highest player-visible impact first):
1. **Goblins (Raider, Shaman, Chieftain)** — appear in every current and near-term combat encounter; zero in-hand coverage; blocks the combat screen from ever showing a "real" enemy.
2. **Relc** — a named, recurring ally combatant and a canon Drake; currently would have to render as a generic placeholder indefinitely without sourcing.
3. **Cave Spider** — arrives in M3-T7, same zero-coverage problem as goblins.
4. **Spell VFX** (Flame Jet line, Frost Bolt, Mana Shield feedback) — M3 has already implemented these mechanically (per the plan's T3/T4 tasks); they currently have zero visual representation, which is a real gap between "mechanically real" and "player can see it," the exact failure mode this repo's own CLAUDE.md warns about ("Passing tests... do not prove a feature is visible/usable to a player").
5. **Status/UI icons + font** — lower urgency (text-based fallback is legible, per the M3 plan's own text-glyph approach: "move-pool pips (distinct glyph `○` beside AP `●`)" already shows the project defaulting to text/glyph UI in the absence of icon art) — nice-to-have polish, not a functional blocker.
6. **Second/third female NPC body (or recolor)** for Erin/Lyonette/Selys differentiation — lower cost (Section 5.7's aseprite recolor path may fully solve this without any new sourcing) but real player-confusion risk if left unaddressed.

### 6.3 Suggested task breakdown for an "M-Art" milestone

Sketch only — not a committed plan (per this doc's Status note):

1. **T1 — Cell-size unification + sprite registry scaffold.** Land the 64px combat-cell change (5.1), build the id→SpriteFrames registry pattern (5.3), wire `skeleton_scene.json`/`combatants.json`/`arenas.json` schemas to carry a `sprite` field. No new art yet — pure plumbing, fully QA-harness-verifiable via existing event/snapshot assertions.
2. **T2 — Environment codegen.** Replace `_build_floor()`'s ColorRect with TileMapLayer-driven rendering per 5.2, using Pixel Crawler tiles for inn + street. Re-capture windowed QA screenshots (5.5).
3. **T3 — PC + generic-NPC sprites.** Wire Body_A (PC) and Citizen_F (Erin/Lyonette/Selys placeholder) through the registry; do the Section 5.7 recolor pass to differentiate the three female NPCs from each other.
4. **T4 — Combat entity sprites, in-hand only.** Wire whatever's already usable (PC via Body_A's combat animations) into the combat screen at the new 64px cell size; goblins/spider/Relc remain gap-flagged placeholders pending sourcing.
5. **T5 — Sourcing pass.** Resolve Section 4's VERIFY items (goblins, Relc/drakonid, Cave Spider, VFX, font) — licensing research plus acquisition, gated on this doc's morning review producing a go/no-go per gap.
6. **T6 — VFX + status/UI polish.** Only after T5 lands sourced VFX assets (or a decision to ship T2-era Bonfire-fire-loop reuse as the Flame Jet stand-in per 4.6); status icons/font last, lowest urgency per 6.2.

Each task should get its own QA-script extension per the repo's standing convention ("When you add ANY player-visible feature, extend a QA script... run it before claiming the feature works" — `wandering_inn_game_v4/CLAUDE.md`), with explicit windowed-screenshot review before claiming any T is done, given this doc's own finding that passing tests don't prove visual correctness.
