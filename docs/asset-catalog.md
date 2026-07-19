# potential_assets/ Qualitative Catalog

**What this is:** a model-readable description of what every asset pack in
`potential_assets/` *looks and sounds like*, plus opinionated casting
suggestions for Wandering Inn entities. It exists so that a Claude/Codex
session doing game design can pick assets **without loading PNGs into
context**. Written 2026-07-03 from direct visual inspection of every pack's
mockups and key spritesheets.

**2026-07-19 refresh:** the game now generates its own sprites — see the new
**sec. 3c** (PixelLab generation batches: what's already generated and which
picks are already wired into `sprites.json`, so a c-lane task does not
regenerate) and **sec. 3d** (open c-lane art issues #198/#210/#222–#225 with a
coverable-from-pack vs needs-generation verdict each). The mechanical
`docs/asset-index.md`/`.json` were regenerated the same day to index every
PixelLab batch. Read 3c before generating anything; note the balance flag.

**2026-07-05 addendum:** three new packs (Ninja Adventure Asset Pack, Cute
Fantasy Free, Pixel_16_interiors_v2_free — families `NINJA16`/`CUTE16`/
`PC16-ADJACENT?` in sec. 1) were catalogued from **filenames, directory
structure, and PNG-header dimension scans only — no visual read performed**.
Their style-family placement is explicitly flagged LOW-CONFIDENCE pending a
windowed screenshot, per the mandatory-verification rule. All existing
Pixel Crawler themed packs were re-enumerated and confirmed unchanged (no
new ones); sec. 3a records that check plus a prop-gap filename hunt.

**Companion documents — division of labor:**

- `docs/asset-index.md` / `docs/asset-index.json` — the *mechanical* index
  (every PNG path, dimensions, frame counts). Use it to get exact file paths
  and sheet geometry after this catalog tells you *which* pack/entity to use.
  It covers PNGs only; audio packs appear only here.
- `wandering_inn_game/data/sprites.json` + `tools/sync_assets.py` — what is
  *already wired into the game*. Anything marked **IN USE** below is already
  in the sync manifest; extend that manifest rather than re-copying by hand.
- `docs/superpowers/specs/2026-07-02-wandering-inn-asset-design.md` — the
  original art-direction spec. Still correct about conventions, but its
  inventory is stale (written when only 3 packs existed; there are now ~24).

**Standing rule (from `wandering_inn_game/CLAUDE.md`):** any tile/sprite
region pick must be verified by a windowed QA screenshot — this catalog gets
you to the right sheet, not the right pixel coordinates.

---

## 1. Style families

Every visual pack belongs to one of five families. Mixing families inside
the same scene layer (e.g. two characters standing side by side) reads as a
clash; mixing across layers (world art vs. UI chrome) is acceptable.

### Family `PC16` — Pixel Crawler (Anokolisa)
- 11 distinct packs (12 directories — Free Pack is unzipped twice), all one
  artist, one coherent palette family (desaturated wood-brown/stone-grey
  base with per-biome accent colors).
- Top-down 3/4 perspective, flat-shaded, hard 1px outlines. Tile grids: the
  game's `biomes.json` slices Free Pack sheets at **16px** and the Cave
  sheet at 16px; treat 16px as the working tile unit (world `CELL := 16`
  since M5 R3).
- Characters: 64x64 frame canvas, figure ~32-40px tall.
- **Two character conventions inside this family:**
  - *Directional field characters* (`Body_A`, `Citizen_F`, Cemetery's
    `A_Hunter`): separate Down/Side/Up sheets, mirror Side for the 4th
    facing. Fully walkable.
  - *Single-facing battler mobs* (every `Enemies/`/`Mobs/` crew): Idle, Run,
    Hit, Death sheets, ONE facing, mirror-only. No attack animation — the
    game already handles this (flash/tint on hit, idle-as-attack).
- This is the game's world-art backbone. Field + combat cells render at 16px
  logical scale in the scaled viewport (M5); the registry's `render_scale`
  handles the rest.

### Family `CUSTOM-HD` — commissioned/generated goblin-family sheets
- `goblin-pack` (3 variants), `goblin-huts-pack`, `goblin_watchtower`,
  `topdown_floor_tiles_12`, `Bat_Fur`, `Small_Bat`.
- Much larger native canvases (256px character cells, 540-640px props),
  soft/painterly shading, no hard pixel grid. Downscaled through
  `render_scale` in `sprites.json` they sit next to PC16 art acceptably —
  this is already proven in-game (goblins + bat are IN USE).
- Spanish READMEs with exact grid/origin metadata; some ship `.animations.json`
  / `.atlas.json` import descriptors and per-frame PNGs in `frames/`.
- No license files, but not a concern: **all packs in `potential_assets/`
  are user-attested as fully licensed and usable** (standing decision,
  2026-07-03). The only remaining license *obligation* anywhere in the tree
  is the Super Dialogue pack's CC BY attribution line (sec. 4).

### Family `ADMURIN` — Admurin's Freebies (one big multi-pack)
- Single directory `Admurins_Freebies-2/` holding ~12 sub-packs by one
  artist (Admurin). Style: **small chibi figures** (~16-24px art inside 32
  or 64px frames), soft anti-aliased shading with a dark outline, top-down
  3/4. Native scale is close to PC16's logical 16px, so it downscales/sits
  next to PC16 more comfortably than the 256px CUSTOM-HD goblins — but the
  softer shading still reads as a *different hand* beside PC16 characters;
  keep Admurin creatures in their own encounters or accept a mild seam.
- Why this pack matters: it **closes three of the catalog's hard gaps**
  (skill-icon glyphs, pixel font, general RPG iconography) and adds a deep
  monster menagerie + a layered paint-doll character. Full breakdown in
  sec. 3.
- **License nuance (only one in the tree worth flagging):** `License.txt`
  permits commercial game use and modification but explicitly forbids
  (a) reselling/redistributing as a standalone asset and (b) **using the
  assets to train AI**. Shipping them rendered in the game is fine; the
  train-AI clause is worth remembering given the repo's open-source
  direction (publishing the PNGs in a public repo is redistribution-
  adjacent — verify against the open-source asset-audit gate before the
  repo goes public). Credit appreciated, not required.

### Family `TS-CARTOON` — Tiny Swords (Pixel Frog)
- 2 packs. Chunky, bold, bright cartoon strategy-game art. Units are ~192px
  frames with big silhouettes and painted swooshes on attacks; buildings are
  large multi-tile pieces. Terrain is soft rolling grass/sand/water autotile.
- **Clashes hard with PC16 as world art** — do not put a Tiny Swords unit on
  a Pixel Crawler map. Its value is (a) the excellent **UI kit** (9-slice
  buttons, ribbons, banners, icons, pointers — style seam in UI chrome is
  fine and already shipped) and (b) **VFX sheets** (Fire, Explosion) which,
  cropped and scaled, are style-agnostic enough for spell effects.

### Family `PIXELLAB-AI` — AI-generated directional characters (PROVISIONAL)
- `Relc/`, `Relc1/` — two PixelLab generations of the *same* character
  (Relc, the Drake), from the PixelLab "mannequin" template
  (`export_version 3.0`, generated 2026-07-04). Painterly-pixel hybrid render,
  softer than PC16's hard 1px outline — closer to CUSTOM-HD's hand than to the
  flat world backbone. First reptilian humanoid anywhere in the tree.
- **128×128 frames, 8 directional rotations** (S/SE/E/NE/N/NW/W/SW), "high
  top-down" view — a finer facing set than any other family (PC16 field chars
  ship 4 facings + mirror). BUT the hard limitation:
- **ROTATIONS ONLY — zero animations** (`"animations": {}` in both metadata
  files). Eight static directional poses, nothing else. Walk / attack / hit /
  death would each need separate generation before this is usable as a combat
  or walking sprite; as-is it can only render as a static / idle-only figure.
- Provenance: the M5 stretch **F2 Drake AI-gen exploration** landing (parked in
  the M4 spec §0, carried through M5). `Relc` vs `Relc1` are two takes of one
  prompt — pick one after a side-by-side; they are not two characters.
- **Style/scale match to PC16 world art is UNVERIFIED.** 128px high-top-down
  beside 16px flat-shaded PC16 tiles is the largest seam in the tree; needs
  aggressive `render_scale` downscaling (like the CUSTOM-HD goblins) AND a
  controller windowed-screenshot verdict (mandatory region/scale rule, v4
  CLAUDE.md) before use. Not yet in `sprites.json`, not yet imported.
- License: user-generated, ship-OK under the tree-wide attestation (sec. 1
  licensing note); no third-party clause.

### Family `NINJA16` — Ninja Adventure Asset Pack (PROVISIONAL, LOW-CONFIDENCE)
- Single directory, ~1915 PNGs, one of the largest packs in the tree. 16px
  native grid confirmed **mechanically** (Walk sheets 64x64, Idle/Attack/
  Jump 64x16 = 4 frames @16px, Dead/Item/Special 16x16 single frame,
  combined `SpriteSheet.png` 64x112 = 7 rows x 4 cols @16px) — same working
  tile unit as PC16 (`CELL := 16`). **Visual style is inferred from
  filenames/structure only, not confirmed by a visual read** — flagging
  LOW-CONFIDENCE. Structure strongly resembles the well-known itch.io
  "Ninja Adventure" pack (RPG-Maker-chibi lineage: blocky heads, saturated
  flat colors, simpler linework than PC16's hard-outline detail work) —
  if that inference holds, it reads as a *third* distinct hand alongside
  PC16 and ADMURIN, and should get its own encounters/scenes rather than
  mix mid-scene with either, pending a windowed side-by-side screenshot.
- **Massive roster**: `Actor/Character` (903 files, 95 named NPCs — Ninja
  variants x10 colors, Samurai/Gladiator/Monk/Sultan/Noble/Villager x6/
  Eskimo/Caveman family/robots/demons, **`Shaman`, `SorcererBlack`,
  `SorcererOrange`** — the tree's first non-Admurin caster-NPC candidates,
  useful for a Mage's Guild member or a necromancer-flavored antagonist),
  `Actor/Monster` (132, small critters — Axolot/Bamboo/Bear/etc, single
  64x64 `SpriteSheet.png` per creature, no visible directional/attack
  split at a glance), `Actor/Boss` (116, named bosses e.g. `DemonCyclop`,
  `DragonBlue` — Idle/Walk/Hit strips, distinct part-based `Body1/Body2`
  files for some — likely segmented/multi-part rigs, needs a visual read
  to use).
- **Items** (Weapons 45, Food 24, Treasure 9 incl. `BigTreasureChest.png`/
  `LittleTreasureChest.png`, Potion 6, Scroll 7, Tool 8, Object 11 incl.
  dice/hourglass/moneybag/gourd — all tiny icon-scale, mostly <16px).
- **FX**: `Slash`, `Magic` (Aura/Boost/Circle/Shield/Spirit/Spark), and
  **`Elemental`** (Explosion/Flam/Ice/Plant/Rock/RockSpike/Thunder/Water —
  animated multi-frame strips, e.g. `Ice/SpriteSheet.png` 320x32/10 frames,
  `Rock/SpriteSheet.png` 420x30/14 frames) — a second full elemental VFX
  set alongside Tiny Swords' Fire/Explosion, worth a crop+scale test for
  frost_bolt/flame_bolt style-agnostic impacts.
- **UI**: `Skill Icon` (121 icons at 24x24 — a third grid size, not 16/32;
  categories include "Items & Weapon" glyphs Amulet/Armor/Arrow/Boot/Guard/
  Helmet each with a **`*Disabled`** greyed variant — ready-made
  locked-slot pairs), `Theme` (55, full 9-slice button/checkbox/slider
  widget kit, "Theme Wood"), `Receptacle` (33, heart/life-bar UI + item
  slot backgrounds by material — Bag/Bamboo/Bottle/Scroll/Wood), `Emote`
  (30), `Dialog` (8), `Font` (2, bitmap fonts — a second font family
  besides Admurin's), `Input` (109, keyboard/gamepad glyphs).
- **Backgrounds/Tilesets** (23): generic Interior/Desert/Dungeon/Field/
  House/Hole sheets plus a literal **`Pipes.png`** (240x48) — best-named
  candidate for sewer-adjacent dressing if the Pixel Crawler Sewer pack's
  own grate needs a second source.
- No filename evidence of a cauldron, sewer grate, training dummy, or
  cluttered/dirty table anywhere in this pack (checked `Items/Object`,
  `Backgrounds/Tilesets` — nothing named `Cauldron`/`Grate`/`Dummy`/
  `Stand`/`Table`); those gaps are NOT closed by this pack.
- **License: CC0 1.0 Universal** (`LICENSE.txt`) — full public-domain
  dedication, no attribution or usage restriction of any kind. The
  cleanest license in the entire tree, better than the blanket
  user-attestation for every other pack.

### Family `CUTE16` — Cute Fantasy Free (PROVISIONAL, LOW-CONFIDENCE)
- Small pack, 23 PNGs. 16px native grid confirmed **mechanically** — every
  file's dimensions are multiples of 16 (`Grass_Middle`/`Path_Middle`/
  `Water_Middle` are raw 16x16 single tiles; `Chicken`/`Cow`/`Pig`/`Sheep`
  64x64; `Player.png` 192x320; `Slime_Green.png` 512x192). Same working
  tile unit as PC16. **Style is filename-inferred only** (no visual read
  yet) — this is the well-known itch.io "Cute Fantasy" line (softer,
  rounder chibi shading than Ninja Adventure's blockier look, closer in
  spirit to ADMURIN's softness but a different artist/hand) — LOW
  CONFIDENCE, flag for a windowed side-by-side before mixing with any
  other family.
- Contents: `Animals/` (Chicken/Cow/Pig/Sheep — farm critters, direct
  overlap with Admurin's Bovine pack for inn livestock/farmstead
  dressing), `Enemies/` (`Skeleton.png` 192x320, `Slime_Green.png`
  512x192 — a second slime + skeleton source), `Player/` (`Player.png`
  192x320 full action sheet, `Player_Actions.png` 96x576 — likely a
  combat-action strip, unconfirmed), `Outdoor decoration/` (bridge,
  **closed chest icon** `Chest.png` 16x16 — small, static, not an
  open-animation container, House_1 building base, Oak_Tree x2 sizes,
  a `Fences.png`, and `Outdoor_Decor_Free.png` 112x192 grab-bag), `Tiles/`
  (Beach/Cliff/FarmLand/Path/Water — a small generic outdoor tileset,
  16px grid, could supplement PC16 Free Pack's Floors_Tiles if a
  visually-matching accent is needed).
- No sewer grate, cauldron, training dummy, or cluttered-table filename
  candidate in this pack either.
- **License: "Free Version" (`read_me.txt`), NOT the tree's blanket
  attestation** — explicitly restrictive: *"You can use these assets in
  non-commercial projects... You can not redistribute or resale, even if
  modified."* This is the **first pack in the tree whose own license text
  contradicts unrestricted commercial use** — flag for the user before
  this pack's assets ship in anything commercial or before the
  open-source-direction audit (repo CLAUDE.md: "Open source direction" —
  gradual public release, asset-license redistribution audit is the
  gate). Safe for internal dev/prototyping now; do not treat as
  ship-cleared under the standing blanket attestation without an explicit
  user re-confirmation, since the text directly says otherwise.

### Family `PC16-ADJACENT?` — Pixel_16_interiors_v2_free (UNRESOLVED, single file)
- Exactly one PNG: `tiles and items.png`, 200x200. The "Pixel_16" name
  implies a 16px grid, but 200 doesn't factor evenly by 16 (12.5) — grid
  size is **not confirmed**, possibly a mixed-size interior-item atlas
  (tiles + furniture icons packed non-uniformly, common in itch.io "free
  demo slice" packs) rather than a uniform tile sheet. No sub-region
  filenames exist (it's one flat PNG) so nothing beyond "an interior
  tiles+items sheet" can be said without a visual read — flag as the
  best-candidate windowed-screenshot target if a cluttered/dirty interior
  table or small furniture accent is needed and PC16's own Interior_Props/
  Furniture sheets don't have the right piece.
- No terms/license/readme file shipped with this pack at all — falls
  under the tree-wide user-attestation by default (no contradicting text
  found, unlike Cute Fantasy Free above).

### Audio packs (no family)
`Minifantasy_Dungeon_SFX`, `Minifantasy_Dungeon_Music`, `xDeviruchi - 16 bit
Fantasy & Adventure`, `Super Dialogue Audio Pack v1`. See section 4.

### Licensing note update (supersedes the CUSTOM-HD note below)
Tree-wide the packs are user-attested ship-OK. Three packs carry a *credit,
usage, or restriction* nuance worth keeping in view: Super Dialogue (CC BY —
attribution required, sec. 4), Admurin's Freebies (no-AI-training clause,
above), and **Cute Fantasy Free (non-commercial-only per its own license
text, above — the one pack whose license actively contradicts the blanket
attestation)**. None but the last blocks in-game use outright; Cute Fantasy
Free needs explicit user sign-off before any commercial/public-release use.
Ninja Adventure Asset Pack, by contrast, is CC0 — the cleanest license of
any pack in the tree, no nuance at all.

---

## 2. Visual packs — Pixel Crawler line (family PC16)

Licensing (applies tree-wide): **every pack in `potential_assets/` is
user-attested fully licensed and usable — treat licensing as settled and
never block work on it.** For reference, Pixel Crawler packs each ship a
`Terms.txt` (commercial use OK, alteration OK, no reselling assets
standalone, credit optional).

### Pixel Crawler — Free Pack / Free Pack 2.1
**NOTE: the two directories are byte-identical PNG-for-PNG (verified by
diff). The game syncs from `Free Pack 2.1/`; treat plain `Free Pack/` as a
redundant unzip and ignore it.**
- The backbone pack: the only one with generic tilesets
  (`Floors_Tiles` grass/dirt/sand/gravel/snow/cobble blob-autotiles,
  `Dungeon_Tiles`, walls, water), building structures (interior walls,
  roofs), crafting stations (alchemy, anvil, bonfire w/ fire+smoke loops,
  cooking, furnace, sawmill, workbench), furniture/props (beds, tables,
  barrels, doors, esoteric/magic props incl. parchment scroll), and weapons.
- Characters: **Body_A** (directional, full combat set: Idle/Walk/Run/
  Slice/Pierce/Hit/Death — IN USE as PC) and **Citizen_F/Tavern_A**
  (directional tavern girl, apron-less brown-haired barmaid look — IN USE as
  Erin stand-in). Single-facing battlers: **Orc Crew** (Orc/Rogue/Shaman/
  Warrior — olive-green brutes) and **Skeleton Crew** (Base/Mage/Rogue/
  Warrior), plus battler-style NPCs Knight/Rogue/Wizzard.
- Mockups `Tavern_01/02.png` (1280x1280): complete multi-room inn — kitchen,
  bar with stools, dining hall with tablecloth banquet tables, cellar,
  three bedrooms. **A ready-made floor-plan reference for The Wandering Inn
  itself.** Warm wood-brown/stone-grey with red/teal accents.
- Scanned depth: `Furniture.png` alone holds ~100 items (beds incl. bunks,
  dressers w/ mirrors, bookcases, dining tables, workbenches, cabinets,
  armor stands, chandeliers, braziers, barred windows) — the inn can be
  furnished entirely from this one sheet plus Interior_Props. `Esoteric.png`
  ~25 alchemical/mystical items (potion vials, scrolls, quills, grimoires,
  runes, candles) — scroll prop already IN USE (dusty_scroll).
- Gotcha from the spec: Icons/ folder is `.aseprite` source only, no PNG.

### Pixel Crawler — Castle Environment 0.3
- Mockup: dark, regal stone interior at night — throne room with red carpet,
  purple wall banners, stone busts/statues, stained-glass windows glowing
  orange, fireplaces, diagonal blue-grey checkered floors, shields on walls.
- Enemies "Royal Crew": Archer, Knight, Priest, Soldier (single-facing
  battlers, Idle/Run/Hit/Death). Human soldiers in livery.
- WI fit: Liscor Council hall, a noble's estate, Watch barracks interior;
  Royal Crew = human guardsmen/soldier enemies or Liscor Watch stand-ins
  (though canon Watch is Drakes/Gnolls — see gaps).

### Pixel Crawler — Cave
- Mockup: organic cavern — brown rock walls, mossy green floor, giant purple
  glow-fringed mushrooms, red trumpet fungi, pebbles, glowing flora accents.
  Distinctly "living cave," not worked stone. Tileset is a 16px grid
  (already handled in `biomes.json` — IN USE for the cave arena biome).
- Enemies: **Fungus crew** — Heavy, Immature, Long, Old (single-facing
  mushroom monsters). Weapons: Spore_Roots.
- WI fit: cave_mouth arena (shipped), deeper cave maps toward the Ruins;
  fungus mobs = non-canon but plausible dungeon vermin under Liscor.

### Pixel Crawler — Cemetery 0.4
- No mockup; props sheet shows grey gravestones, crosses (some blood-marked),
  ornate skull-relief monuments, statue fragments, a scythe. Has its own
  floor/tiles/walls/roof sheets + bare tree — bleak grey-green palette.
- **`A_Hunter` — the only fully-directional character outside the Free
  Pack**: Down/Side/Up sheets for Idle/Walk/Run/Hit + THREE attack types
  (Slice/Pierce/Crush) + Collect. Visual: a dark, hooded/wrapped grim figure.
  Casting gold: a named adventurer NPC, a [Hunter]/[Rogue]-class character,
  or an alternate player body.
- Mobs: Zombies — Banshee, Base, Muscle, Overweight (single-facing).
- WI fit: crypts near the Ruins of Liscor, undead encounters; A_Hunter could
  read as a Bloodfields scavenger or a grim mercenary like Halrac.

### Pixel Crawler — Desert
- Mockups: bright orange sand, eroded mesa/cliff outcrops, giant bleached
  ribs/horns half-buried, cacti, dead shrubs. Hot, harsh, empty.
- Enemies: **Mummy crew** — Base, Mage, Rogue, Warrior. Weapons: gold set.
- WI fit: Zeikhal/the Great Desert if the story ever goes there; nearer-term,
  the bone props work for Bloodfields-adjacent wasteland flavor.

### Pixel Crawler — Fairy Forest 1.7
- Mockups: dense night-lit enchanted forest — deep greens with purple canopy
  accents, glowing blue rune stones, orange glow-flowers, cliff faces, giant
  trees, stumps with orange fungus. The most "magical" environment in hand.
- Enemies: **Elf crew** — Base, Druid, Hunter, Ranger (single-facing).
- WI fit: forests south of Liscor; frost-faerie territory when Winter
  Sprites matter. Elves are non-canon for WI (no elves alive) — reskin
  candidates for half-Elves ONLY with edits; otherwise avoid lore collision.

### Pixel Crawler — Forge 1.2
- Mockup: dwarven-foundry hellscape — dark red brick walls, channels of
  glowing molten metal, anvils, chain grates, stone bust statues, orange
  rim-light everywhere. Reads "industrial fire dungeon."
- Enemies: **Stone crew** — Base, Broken, Lava, Golem. Weapons: fire set.
- WI fit: a smithy interior (Pelt's forge in Invrisil, Hedault-adjacent
  scenes) if dressed lighter; golems = classic dungeon constructs. Fire
  weapons sheet could source flame-skill iconography crops.

### Pixel Crawler — Garden Environment
- Mockup: formal palace garden — trimmed hedges, topiary cypresses, pink
  flowerbeds, stone paths, tiered fountain, statue pond with lily pads,
  benches, grape trellises. Muted daylight.
- Enemies: Medusa, Old, Feminine, Masculine. Scanned: **animated stone/clay
  statues** (museum pieces that move), not plants or humans; Medusa's
  snake-hair crown is the only strong identifier — Feminine/Masculine are
  near-interchangeable gender-coded statues.
- WI fit: **the Garden of Sanctuary** is the obvious casting — fountain +
  statues + serene enclosed green space is nearly literal, and
  statues-that-animate suits its guardian mystique. Also Magnolia
  Reinhart's estate grounds.

### Pixel Crawler — Hideout 1.0
- Mockup: bandit den under a building — torchlit cellar rooms, wine barrels,
  potion racks (green bottles), skull-painted banner rags, spilled purple
  wine stains, cobwebs, crates, a brewing/alchemy table. Cozy-sinister.
- Enemies: **"Baldits"** [sic — bandits] — Fighter, Scout, Sorcerer, Tracker.
- WI fit: basement of the inn (!), smuggler dens in Liscor, Sisters-of-Chell
  style bandit encounters on the road. The bandit crew is the best in-hand
  "human raider" enemy set — more thematically right for road ambushes than
  orcs.

### Pixel Crawler — Library
- Mockup: grand two-story library — floor-to-ceiling bookshelves with
  section signage, teal marble columns and curtains, brass candelabra
  reading desks, ornate teal/gold rug, balcony rails, rolling ladders.
  Wealthy, scholarly, warm wood + teal/gold palette.
- "Enemies": **Scholar crew** — Cataloguer, Censor, Director, Researcher.
  Scanned: they read as **pacifist civilians** — hats/robes, zero weapons
  or hostile posture. Cast them as *staff NPCs* (Mage's Guild clerk,
  Adventurer's Guild receptionist desk-warmer, [Scribe]s), not monsters.
- Weapons sheet is the standout: ~35 arcane items (cyan/purple glowing
  staves ×8, wands, orbs, enchanted blades) — best in-tree source for
  magic-item iconography crops.
- WI fit: Wistram Academy interiors; Liscor's Mage's Guild; Selys's
  Adventurer's Guild counter borrows desks/shelving props.

### Pixel Crawler — Sewer
- Mockup: brown-brick underground with copper pipes everywhere, a channel of
  bright toxic-green sewage, metal grates, plank bridges, spike traps, wall
  lanterns. Grimy but readable.
- Enemies: **Rat crew** — Base, Mage, Rogue, Warrior. Scanned: these are
  **quadruped rodents** (round body, thick tail), not ratfolk — roles shown
  by overlays (Mage = clean purple glow aura, Rogue = leather wrap,
  Warrior = red-purple plating). Weapons: poison-green set (curved swords,
  daggers, spears, glowing staves, alchemical bombs — good icon-crop
  source for poison/toxin skills).
- WI fit: **Liscor's sewers are canon** (Skinner arc) — direct hit for a
  sewer map/arena. Quadruped rats read as giant-rat vermin, which is
  actually the more lore-plausible enemy than ratfolk.

### Mob/NPC visual quick-reference (scanned idle sheets, all crews)

Caster tells that read at small scale: **Orc Shaman** (red-orange headdress
+ staff), **Skeleton Mage** (bright red robe + staff), **Rat Mage** (purple
glow aura), **Wizzard** (tall saturated purple robe — most readable sprite
in the tree), Elf Druid (pink hair puff). Melee/tank tells: Knight
(blue-grey plate), Orc Warrior (chest plate), Zombie Muscle (red-brown
bulk), Stone Lava (glowing veins).

Confusion risks when mixing rosters (flagged by scan): Orc Base vs Skeleton
Base (both tan/olive), Skeleton vs Zombie Base (both pale green-grey), NPC
Rogue vs Orc Rogue (both brown leather). Keep these crews in separate
encounters or recolor. Fungus crew is the only non-humanoid silhouette
family — strongest at-a-glance contrast with everything else.

Weapons-sheet tier language across packs (useful for future gear UI):
Hideout rustic (crude wood/moss) → Forge (glowing orange-red forged metal)
reads as a natural upgrade curve; Cemetery cursed (purple/black), Sewer
poison (yellow-green), Desert gold (ornate curved), Library arcane
(cyan/purple glow) are themed sets ~20-35 items each.

---

## 3. Visual packs — custom + Tiny Swords

### goblin-pack (goblin / goblin-female / goblin-sword) — family CUSTOM-HD — IN USE
- Three 1536x1024 sheets, 4 rows (down/up/left/right) x 6 frames, 256px
  cells, feet at y=220, 10 FPS, per-frame PNGs in `frames/`,
  `.animations.json` descriptors. **True 4-directional walk cycles** — the
  only 4-row-directional characters in the whole tree.
- Visual: chibi-proportioned green goblins — oversized heads, huge amber
  eyes, pointed ears, underbite fangs, ragged brown tunics with gold
  buckles. Soft antialiased shading. Female variant has a brown ponytail;
  sword variant carries a blade. Charming rather than menacing.
- IN USE as `goblin_base`, `goblin_female`, `goblin_sword` (Raider/Shaman/
  Chieftain casting solved). Remaining headroom: recolors for elite goblins
  (Chieftain could be tinted/scaled bigger for silhouette distinction).

### goblin-huts-pack + goblin_watchtower — family CUSTOM-HD
- Huts: 1280x1280 sheet, 4 hide-tent huts (640px cells) — stitched leather
  domes on wooden palisade posts, bone spikes, skull banners (red/purple),
  one damaged/torn variant. Painterly, reads instantly "goblin camp."
  Atlas JSON included. Origin (320,580).
- Watchtower: single structure, 341x566 per frame, 4 views (front/back/
  left/right) + animated GIF — wooden tower, hide roof, bone spikes, skull
  banner, ladder.
- NOT yet in use. Casting: dress the goblin_ambush / chieftains_raid arenas
  or a future goblin-camp field map. At 16px cell scale these are multi-cell
  props — budget render_scale and blocked-cell footprints (hut ~3x3, tower
  ~2x3).

### Bat_Fur + Small_Bat — family CUSTOM-HD (Pixel-Crawler-convention sheets) — IN USE (bat)
- Both follow the Down/Side/Up sheet convention at 96px frames: Idle(4),
  Move(8), Hit(4), Death(6); Bat_Fur adds Attack_01(6). Sprite is small in
  frame: dark-brown furred bat, folded wings at idle.
- `bat` is IN USE (cave arena flyer). Small_Bat = smaller silhouette variant
  for swarms. These are the de-facto "Cave Spider replacement" — the flying
  cave vermin role is covered; an actual arachnid is still a gap (sec. 6).

### topdown_floor_tiles_12 — family CUSTOM-HD
- 12 tiles, 540x540 each: grass x4 (lush green, flowers, dirt patches),
  dirt x4, grass-dirt transition x4. Painterly-pixel hybrid, brighter and
  softer than PC16's Floors_Tiles.
- Partially IN USE: `dirt_01` is the street biome's floor + skirt in
  `biomes.json` (whole-image single-tile pick). Grass/transition tiles
  unmined — test side-by-side with PC16 grass first; mixing two grass
  styles across adjacent maps will look like two games.

### Tiny Swords (Update 010) — family TS-CARTOON — IN USE (UI chrome)
- Full strategy-game kit: **Factions** (Knights: Archer/Pawn/Warrior troops
  + Castle/House/Tower buildings; Goblins: Torch/TNT/Barrel troops +
  Wood House/Tower), each troop in 4 team colors; **Resources** (gold mine,
  sheep, trees, gold/meat/wood pickups); **Terrain** (flat + elevation
  autotile grass/sand, water, bridge, rocks, animated foam); **Deco** (17
  small props); **Effects** (Fire, Explosion sheets); **UI** (buttons,
  ribbons, banners, icons, pointers — 9-slice-ready, blue/red/yellow).
- Units are ~192px frames, egg-shaped bold cartoon bodies, painted attack
  swooshes, idle bob. Charming but a different universe from PC16.
- IN USE: `Carved_9Slides` + `Button_Blue_9Slides(+Pressed)` as hotbar/UI
  chrome (M5 H1). **Recommended further mining: UI only, plus Fire/Explosion
  VFX crops for flame_jet/flame_bolt impact flashes.** Do not field the
  units/buildings/terrain next to PC16 world art.
- Scanned detail (full report of both packs' UI/FX):
  - **Update 010 icons: 10 glyphs × 3 baked states (Regular/Pressed/
    Disable)** — crossed swords, wrench, speaker, torch, "2", "3",
    cart, plus/health-cross, divider bar, **padlock** (padlock = ready-made
    locked-skill-slot overlay for the hotbar).
  - **Effects/Fire.png**: 896x128, 7 frames, looping warm flame.
    **Effects/Explosions.png**: 1728x192, 18 frames (9x2), white flash →
    gold bloom → char → debris — the best impact VFX in the tree.
  - Banners (horizontal/vertical parchment cloth, text-overlay-ready),
    Ribbons (3 colors, connector variants), hand-cursor Pointers.
  - Deco: gems, shells, bushes, pumpkin, water barrel. Resources: gold
    mine (active/destroyed states), 8-frame idle sheep, coin sprite.

### Tiny Swords (Free Pack) — family TS-CARTOON — IN USE (2 icons)
- Complementary, NOT a subset: **Units** in 5 colors x Archer/Lancer/Monk/
  Pawn/Warrior (Lancer and Monk don't exist in Update 010), Dead sprites,
  Buildings, Terrain, **UI Elements** (incl. the Icons_XX sheet — Icon_05
  crossed-swords and Icon_07 arrow are IN USE as hotbar attack/dash icons),
  Particle FX.
- Free Pack icon sheet enumerated (12 glyphs): hammer, chestplate, gold
  coin, red potion flask, crossed sword+dagger (= in-use icon_attack),
  blue/white kite shield, green forward play-arrow (= in-use icon_dash;
  reads gem-like out of context), orange gem, red X, gear, info circle,
  music notes. Confirms `sync_assets.py`'s note: **no fire/frost/burst
  glyph in either pack** — the four spell icons remain code-drawn.
  Unmined wins: potion (inventory/consumables), shield (guard/defend),
  red X (refusal feedback), padlock from Update 010 (locked slots).
- **Particle FX dir** (Free Pack): Dust x2, Explosion x2, Fire x3, **Water
  Splash** (arcing teal droplets) + .aseprite source — small, fairly
  style-agnostic loops usable over PC16 scenes (footstep dust, splash).

### Admurin's Freebies — family ADMURIN (gap-filler multi-pack, NOT in use yet)
Path: `Admurins_Freebies-2/Admurin's Freebies/`. One artist, ~12 sub-packs.
Chibi 16-24px figures, soft-shaded, dark outline. The single most useful new
pack in the tree because it closes three gaps the rest could not. License:
game-use OK, no-AI-training clause (see family note, sec. 1).

**Icons — closes the skill-glyph AND general-icon gaps.**
- `Icons/Freebies_Full_Icons.png` (672x640, 32px grid ≈ 420 icons): weapons
  (swords/axes/bows/staves/daggers/shields), armor pieces, gems, a big
  food/fruit run, **dialogue-emote speech bubbles** (`...`, `?`, `!`,
  `Zzz`, `!!`, music, ellipsis — ideal for the dialogue system's NPC
  emote beats), skulls/bones, mushrooms, multi-color leaves, potions,
  coins/money, insects.
- `Icons/Freebies_Icons_Skills.png` (288x256, 32px ≈ 72 icons): **elemental
  spell-cast palms** — fire hand, frost/ice hand, wind/holy hand, plus
  fists, shields, healing crosses, status-heart body poses, footsteps,
  shout/sound waves. **This is the direct replacement for the four
  code-drawn placeholder skill icons** (`flame_bolt`/`flame_jet`/
  `frost_bolt`/`power_strike` in `sync_assets.py`) — fire palm → flame
  skills, ice palm → frost_bolt, fist → power_strike. Highest-value single
  file in the pack.
- Category sub-sheets also present: Armory, Botany, Emoticons, Fishing,
  General, Halloween, Insects, Miscellaneous, Potions, Steampunk — pick a
  themed subset instead of the full 420 when wiring a specific UI.

**UI Packs — closes the pixel-font gap.**
- `UI Packs/{Gold,Iron,Paper,Platinum,Steel,Wood}/` each ship **full bitmap
  fonts** (digits, A-Z upper+lower incl. accented ñ/ç, punctuation, symbols)
  in that theme color, with **Shadow and No-Shadow variants** and 1-2
  typefaces (`UI_<theme>.png` + `UI_<theme>_Icons_Free.png` are two
  typefaces; naming is misleading — "Icons_Free" is a second FONT, not
  icons). Plus `_Logos_Free.png` = brand/social logos (Steam, Discord,
  Twitch, etc. — skip for this project). **This is the only pixel font in
  the whole tree** — the standing "no .ttf/.fnt anywhere" gap is now
  answerable by rendering text through one of these sheets (Godot BitmapFont
  or a glyph-atlas Label). Paper/Wood read most neutral-fantasy; Gold/
  Platinum for emphasis headers.

**Monster menagerie (`Enemy_Galore_I/` + Monster Packs).** Frame convention
mostly 256x64 = 4 frames @ 64px (single-facing, Idle/Run/Attack/Hit/Death,
many with `_FX` overlay sheets for the attack effect); the two "character"-
scale sheets (Witch Doctor, the paint-doll) are 512x512 directional 4x4.
- **Wolves** (`Canines/`, 4 colors black/brown/gray/white, full anim
  incl. attack/death, ~6-frame side profiles): clean grey/brown **wolves** —
  the best-fitting new WI creature. Road-predator wildlife, wolf-pack
  ambushes; palette-swap gives a 4-strong pack instantly.
- **Crab** (red, multi-attack A/B/C + ability): the nearest thing to an
  arthropod in the tree — a plausible **Cave Spider substitute** silhouette
  (low, many-legged) better than the bat that currently fills that role,
  though still a crab not a spider.
- **Golem** (armored + no-armor variants, armor-break/upgrade/reset frames,
  navy-stone): dungeon construct; the armor-break animation is a nice
  two-phase boss beat.
- **Slime** (spiked, jump attack), **Pebble** (tiny rock elemental — golem
  minion), **Rat** (with ability), **Bat** (fly/attack), **Single Skull**
  (floating bone flyer): standard dungeon vermin/undead filler.
- **Gollux** (`Gollux/`, single-facing, large hunched dark-red rock brute,
  idle/move/attack A+B/heal/hit): reads **boss-tier** — a rock troll/greater
  golem. Candidate boss silhouette (still no Drake, but a real elite).
- **Skeleton + Witch Doctor** (`Monster Pack 40`): Skeleton = classic undead;
  **Witch Doctor** = dark-robed directional **caster** with a bone-wand
  (4x4 directional, has a Skill sheet) — a rare directional caster enemy.
- **Rabbits** (plain + **horned**), **Boar / Pig / Piggy** (`Bovine` pack):
  woodland/farm critters — Pig/Piggy suit inn livestock or a farmstead map;
  horned rabbit = low-tier magical beast.
- **Seasonal** (`Monster Pack 82/83`): Christmas snowmen (7 variants) +
  reindeer + Christmas kid/ghost. Event-only; ignore unless a winter event
  ships.

**Layered paint-doll character (`Monster Pack Character (Free)/`).**
A base body (`Character_Idle/Move/Attack/Death.png`, directional) plus a
folder of **transparent equipment overlays that stack on the same frame
grid**: Beard, Hair, Hat, Chestplate, Gloves, Boots, Leggings, Sword (x2).
Confirmed by inspection — each overlay draws only its garment at matching
frame positions. This is a **customizable PC with visible equipment** — the
one asset in the whole tree that supports gear-that-shows-on-the-sprite. Big
for a player avatar whose armor/weapon changes are visible, if the project
ever wants that (PC16's Body_A has no equip-layer system). Bare-body base is
small/plain; the value is the layering, not the base look.

**Animated loot chests (`Animated Chests/Chests.png`, 240x256, 5x8).**
Open-animation chests in ~4-5 material tiers (wood/dark/red-gold/gold/
silver-blue) + a `Chests_Snow` variant. Ready-made animated loot containers —
pairs with the Minifantasy chest-open SFX (sec. 4). Fills the "future loot"
note left open under the SFX pack.

---

## 3a. Pixel Crawler line re-verification (2026-07-05) + prop candidate hunt

**Enumeration check requested for this pass: are there any NEW Pixel
Crawler themed packs beyond what's already in section 2?** Full directory
listing of `potential_assets/Pixel Crawler - *` (12 directories) diffed
against section 2's 11-pack roster (Castle Environment, Cave, Cemetery,
Desert, Fairy Forest, Forge, Free Pack + Free Pack 2.1 [dupe], Garden
Environment, Hideout, Library, Sewer): **exact match, zero new Pixel
Crawler packs.** Nothing to catalog here; section 2 remains current.
`tools/asset_index.py --keep-notes` was re-run and confirms 12/12
directories indexed, counts unchanged from the existing table.

**Prop-gap filename hunt (sewer grate / cauldron / open chest / training
dummy) across all Pixel Crawler packs:** grepped every PNG filename in the
tree for `grate`/`cauldron`/`pot`/`chest`/`dummy`/`stand`/`armor` —
**zero hits**. Every Pixel Crawler pack bundles props as sub-tiles inside
multi-item atlas sheets (`Props.png`, `Furniture.png`, `Tiles.png`,
`Esoteric.png`) with no per-item filenames, so **none of these four can be
confirmed by filename alone** — consistent with the standing
mandatory-windowed-screenshot rule. Best-candidate sheets for a later
windowed pick, reasoned from the existing (2026-07-03) visual-mockup pass
in section 2:

- **(a) sewer grate** — `Pixel Crawler - Sewer/.../Assets/Props.png`
  (176x256) or the larger `Social/Props.png` (704x1024). The Sewer
  mockup's visual description already names "metal grates" among its
  contents (sec. 2) but the sub-tile position is unconfirmed — needs a
  windowed crop pick.
- **(b) cauldron / cooking pot** — `Pixel Crawler - Free Pack/.../
  Stations/Cooking Station/Cooking Station.png` (288x224) or `Estructure.png`
  (288x224, already flagged "candidate (unwired)" in the mechanical index's
  M5 E3 table) is the best Free-Pack candidate; Hideout's mockup separately
  describes "a brewing/alchemy table" but Hideout ships no dedicated
  Furniture/Props sheet (only `Assets/Tiles.png`, 416x400) — that table is
  presumably a sub-region of `Tiles.png` itself. **Neither has been
  visually confirmed to contain a round cauldron specifically** (the
  Cooking Station sheets read as stove/hearth structures in the mockup,
  not confirmed as a cauldron shape) — flag LOW-CONFIDENCE, needs a
  windowed read.
- **(c) open-chest frame** — **no Pixel Crawler pack has a chest-labeled
  file or a mockup description mentioning a chest at all.** Best blind
  candidate to check visually: Free Pack's `Environment/Props/Static/
  Dungeon_Props.png` (400x400, never visually scanned in the 2026-07-03
  pass) or `Esoteric.png` (400x400, scanned but described only as
  potions/books/runes — no chest mentioned, so likely absent). **The
  actual best in-tree answer for an open/animated chest remains Admurin's
  `Animated Chests/Chests.png`** (already FILLED, sec. 3/5) — if a
  PC16-family chest specifically is required, `Dungeon_Props.png` is the
  only unscanned candidate left and needs a windowed read to confirm
  presence at all, let alone an open-frame variant.
- **(d) training dummy / armor stand** — **already visually confirmed**
  (2026-07-03 visual-notes pass, `docs/asset-index.md`): Free Pack's
  `Furniture.png` (800x864) right-hand region (~col 6-10) was scanned and
  described as containing "decorative heads, shields, **armor stands**,
  small vessels." This is the strongest of the four answers — a real
  armor-stand sub-tile is confirmed to exist, just not yet pixel-located.
  A literal stuffed *training* dummy (vs. a decorative armor stand) is
  NOT separately confirmed — the armor stand is the closest existing
  match and the best candidate for a windowed crop pick.

## 3b. 8a Magical Door — ruin + garden pixel-level pass (2026-07-07)

**Task A1 (lane γ, issue #8 milestone 8a).** Full region/scale/anchor table
lives in `docs/archive/design/8a-asset-assembly.md`; this section is the qualitative
summary + pack-choice reasoning, per the standing division of labor (sec.
"Companion documents" above). Method: PIL alpha-channel + mean-color/
texture-variance grid scans and connected-component bbox scans (never a
direct image view) — the same discipline as sec. 3a's prop hunt, extended to
produce actual pixel coordinates rather than just candidate-sheet names.

**Ruin floor + wall (`ruin_surface`, Task D1):** Cemetery 0.4 is the primary
pick over Castle — its own casting note already says "crypts near the Ruins
of Liscor" (sec. 2), vs. Castle's "regal, still-standing interior" read,
and the PIL scan confirms it: `Environment/TileSets/Floor.png` has a clean,
fully-opaque, near-flat dark-olive stone tile (`(60,58,24)`, texture-std 1.6)
repeating through its occupied block; `Environment/Structures/Walls.png` has
both a flat warm-grey fill tile and a rougher masonry-textured alternate in
the same palette family. Cave's `Assets/Tiles.png` (already scanned
2026-07-02, sec. "Visual notes" in the mechanical index) supplies an organic
rock-formation alternate for a "ruins reclaimed by nature" read, consistent
with its own casting note ("deeper cave maps toward the Ruins," sec. 2).
Castle's `Assets/Tiles.png` is kept as a tertiary candidate for a
still-intact inner chamber (Warmage Thresk's own room, if the ruin design
ever wants one) — its stone-wall cell reads warmer/cleaner than Cemetery's,
appropriate for "regal," not "ruined."

**Pedestal + rubble scatter (`anchor_stone_pedestal`, D1):** Cemetery's
`Environment/Props/Props.png` has an isolated, dense (84% opaque) 48x48px
blob at native (64,0) reading as a compact monument/altar silhouette — the
pedestal candidate. `Environment/Props/Graves.png` has a taller (24x78px)
standing-slab blob at (132,114) as an alternate "broken monument" pedestal
if a taller read is wanted. Both sheets also carry several small (10-30px)
isolated debris blobs in the same grey-brown palette, proposed as a 2-3
piece rubble scatter (props-over-tiles rule — real debris props, not a
recolored floor tile). Exact bboxes + proposed render_scale in the
assembly doc.

**Pantry-door awakened state (`pantry_door`, Task D4):** per the milestone
plan's Global Constraints, v1 ships with **zero new art** — the existing
`door` sprite entry (`sprites.json`, Free Pack `Furniture.png` region
`[222,279,34,44]`, already IN USE) gets a `visual_states` tint + a
phase-gated `PointLight2D`, the exact `unlit_lantern` precedent (sec.
5 casting table has no row for this since it's a reuse, not a new asset).
No Pixel Crawler pack in the Castle/Cemetery/Cave/Garden roster has an
arcane-doorway motif worth swapping in over the existing door prop. A
PixelLab generation spec for a real rune-glow frame (for when balance is
topped up) is queued in the assembly doc per the deferral note in sec. 4's
sibling asset-index and the milestone plan — **nothing generated this
pass** (balance $0.00, per directive).

**Garden of Sanctuary pre-work (issue #9, out of charter for 8a — picks
only, no wiring):** confirms sec. 5's existing "near-literal fit" casting
call. `Garden Environment/Assets/Tiles.png` (480x480, 30x30 @16px) has: a
flat teal water tile (`(69,114,121)`, std 0.0 — fountain-basin water), a
bright yellow-green textured foliage tile (`(114,122,35)` — trimmed-hedge
top-face), and three flower-bed color swatches at the sheet's bottom rows
(magenta/pink `(143,2,79)`, red `(144,30,9)`, purple `(69,3,144)`) — the
magenta swatch is the closest match to the catalog's "pink flowerbeds"
mockup read (sec. 2) and is the proposed source color for a petal
`GPUParticles2D` ambience emitter (the existing atmosphere-layer pattern,
`wandering_inn_game/CLAUDE.md` "Ambience layer" block). Garden ships no
dedicated Props.png (confirmed via directory listing, unlike Cave/Cemetery)
— hedge/fountain/statue objects live as multi-cell regions inside the one
Tiles.png sheet; a full fountain *structure* crop (basin + rim + statue,
not just the water fill tile) is deferred to #9's own asset pass since it
needs a windowed screenshot to compose correctly and #9 is out of scope
here by charter.

## 3c. PixelLab generation batches (2026-07-19 refresh) — read before generating anything

**Why this section exists:** sections 1–3b were written 2026-07-03…07, before
the game began generating its own sprites with PixelLab. Since 2026-07-11 the
tree has accumulated **eight dated PixelLab batches** in `potential_assets/`,
and *most of their picks are already wired into `data/sprites.json`*. A c-lane
art task that skips this section will either (a) regenerate a sprite that
already exists, wasting scarce balance, or (b) re-derive a prop that is already
placed. **Read this first; the mechanical `docs/asset-index.md` now lists every
PNG in these batches (regenerated 2026-07-19).** Provenance/license for ALL of
them: user-owned + redistributable, **TIER-PUBLIC**, per
`assets/LICENSES/pixellab-ai-generated-verdict.md` — no third-party clause,
ship-OK in public and bundle builds alike. Family = `PIXELLAB-AI` (sec. 1).

**⚠ Balance flag (the art lane's gate):** the 2026-07-16 drain
(`pixellab_2026-07-16_drain/MANIFEST.md`) ended at **18 / 2000 generations
remaining**. Almost every open c-lane issue (#198/#210/#222/#223/#224) needs
*fresh* generation (see the per-issue notes below), and 18 will not cover a
character batch. The user holds a paid PixelLab subscription (can top up) —
**verify current balance via `GET api.pixellab.ai/v2/balance` before queueing
batch A or B**, and do not start a character rig without confirming headroom.

### Batch inventory (potential_assets/, newest-relevant first)

| Batch dir | Contents (metadata only) | Status |
|---|---|---|
| `pixellab_2026-07-18` | `arch_1..3`, `gatehouse_1..3` (architecture props) | candidates, unwired |
| `pixellab_2026-07-16_drain` | **has `MANIFEST.md`.** (A) 14 skill-icon subjects × ~2 variants + 32px sources (hedge_remedy, evil_eye, bone_dart, deathbolt, detect_magic, advanced_cooking, signature_dish, eagle_eyes, marked_quarry, double_step, flash_step, animate_dead, hearthward_charm, greater_hearthward — PICKs called in manifest); (B) **Ratici rig** `ratici_teal/` (PICK: animated directional + `/characters/{id}/zip`; wiring data measured — anchor `[0.5,0.7596]`, render_scale 0.4528; `ratici_plum` = reject); (C) `prop_hat_stand_v1` (PICK) | candidates, unwired — the manifest is the authority on picks |
| `pixellab_2026-07-14_visual_log` | 139 PNGs: props (`delivery_board`, `guild_notice_wall`, `cold_hearth`, `deep_fissure`, `warren_mouth`, `nest_ledge`, `gnaw_pile`), trap tells (`dart_slit_tell`, `illusory_floor_tell`), creatures (`shield_spider_v2`, `rock_crab`), ~12 skill icons | **mostly WIRED** — see list below |
| `pixellab_2026-07-12_pallass_rigs` | 1 PNG (Pallass rig work) | see #133 line |
| `pixellab_2026-07-11_trap_props` | `dart_slit`, `illusory_floor`, `pressure_plate`, `snare_coil` | `snare_coil`/tells WIRED |
| `pixellab_2026-07-11_tilesets` | 2 PNGs (tileset gen) | candidates |
| `pixellab_2026-07-06 … 07-08` (`_garden`/`_invrisil`/`_pallass`/`_riverfarm`/`_invrisil_combat`/`_witch`) | region character/prop batches incl. the original Relc take (sec. 1 `PIXELLAB-AI`) | region sprites largely wired |

### Already WIRED into `data/sprites.json` — DO NOT regenerate these

Verified present in `sprites.json` (2026-07-19): `shield_spider`,
`kingslayer_spider`, `rock_crab`, `deep_fissure`, `dart_slit_tell`,
`illusory_floor_tell`, `snare_coil`, `nest_ledge`, `warren_mouth`,
`cold_hearth`, `gnaw_pile`, `delivery_board`, `guild_notice_wall`,
`training_dummy`, `dungeon_statue`, `dungeon_rubble`, `market_stall_pallass`,
`food_basket`, `steam_vent`, the `memorial_statue_*` set, plus the shipped
`icon_*` skill-glyph family. If a c-lane need maps onto one of these, the work
is **placement/repoint (map JSON) not generation** — and placement/data edits
belong to a data lane, not this art-scout charter.

### Candidate-only (generated, picked, NOT yet wired)

`ratici_teal` rig, `prop_hat_stand_v1`, the 14 drain skill-icon picks, the
`pixellab_2026-07-18` arch/gatehouse props, `shield_spider_v2`. Wiring these is
a sprites.json + sync_assets edit (data/code lane) — the art already exists.

## 3d. Open c-lane art issues — coverage verdict (2026-07-19)

Per-issue answer to "coverable from an in-hand pack, or needs PixelLab
generation?" — the art-lane work-list. Current-sprite facts verified against
`data/sprites.json` + the region map JSON on 2026-07-19. **Placement/repoint
and floor_layers wiring are DATA-lane edits (map JSON / biomes.json), not this
art-scout charter** — flagged as follow-ups, not done here.

| Issue | Need | Verdict |
|---|---|---|
| **#198** inn ledger/wardwork/runes | `inn_room_ledger`(10,5), `cellar_wardwork`(13,5), `pantry_door_runes`(14,5) all wear `dusty_scroll` (the genuine scroll is at (12,7)) | **NEEDS GENERATION.** No bound-ledger / chalk-ward-sigil / distinct-note sprite exists in any pack or batch; PC16 `Esoteric.png` carries only the parchment scroll (= today's `dusty_scroll`). Batch A: bound ledger on a stand, ward sigil, parchment note. Subsumed by #222. |
| **#222** Batch A + placement | 10 `dusty_scroll` placements across 6 maps (inn/sewers/invrisil/riverfarm/barracks) span ~3–7 semantics (genuine scroll / ledger ×3 / note ×4 / ward-rune ×2); plus chessboard, market stalls, alchemy-bench variants, trap tells | **MIXED, mostly NEEDS GENERATION.** ledger/note/ward-rune/chessboard/alchemy-bench = generate. `market_stall_pallass`, `food_basket`, trap tells (`dart_slit_tell`/`snare_coil`/`illusory_floor_tell`) **already exist** — the "food_basket dresses a person on the street" fix is a repoint (DATA lane). Placement sweep = DATA lane. |
| **#210 / #223** Erin sprite | `erin` entity wears `sprite: citizen_f` (the shared PC16 villager base — indistinct from Riverfarm villagers) | **NEEDS GENERATION.** Not covered by any pack (Citizen_F is the *only* PC16 directional female, and indistinctness is the whole bug) and not in any batch. v2 8-dir character pipeline from `docs/design/character-profiles.md` (Erin profile present). |
| **#223** other characters | Ruin Warden rig (`ruin_guardian`+wards fight as `training_dummy`), Ceria cast (falls back to idle), Rags (#199) | **NEEDS GENERATION** (v2 character rigs, directional + combat frames). No candidate exists. Budget-gated — a character batch will not fit in 18 generations. |
| **#224** Batch B + placement | ladder/fissure/seam transitions; sewers web+moss; cart/tea; dormant-guardian statue; distinctive ruin rubble (#205) | **MIXED.** `deep_fissure` already wired. `dormant_guardian_marker`(dungeon_approach 8,9) wears the **boss** sprite `vault_construct` → could **REUSE existing `dungeon_statue`** (coverable, verify via screenshot) or generate a dormant variant. `phosphor_moss`→`mushroom_purple_m` and `warded_seam`→`illusory_floor_tell` are semantic mismatches → generate moss + a distinct seam. web / cart / tea / distinctive rubble → generate. Fauna+icon items **USER-GATED** per VISUAL-LOG Wave D-2. |
| **#225** interior floor differentiation | 7/21 maps render identical inn floors; 3 maps have zero `floor_layers` | **COVERABLE FROM EXISTING PACKS — no generation.** Every biome floor tile is in-hand (Free Pack `Floors_Tiles`, plus Cave/Cemetery/Castle/Sewer/Library/Garden own floor sheets, and `topdown_floor_tiles_12`). The work is `biomes.json` per-building variants + map `floor_layers` wiring = **DATA lane**; the art side is fully unblocked. |

**Net:** #198, #222 (ledger/note/rune/chessboard/alchemy), #210, #223 all
require fresh PixelLab generation; #224 is mostly generation with one possible
`dungeon_statue` reuse; #225 needs zero generation. The gating risk is balance
(18/2000 at last check) — top up before batch A/B.

## 4. Audio packs

### Minifantasy_Dungeon_SFX — IN USE (curated set)
- 62 raw one-shot/loop files (58 wav + 4 mp3 door sounds), 8-bit-flavored
  fantasy foley in numbered groups: chest/crate/sack open-close, door open/close, human + orc
  attack/charge/special/damage/jump/land/death/footsteps, sword hit x3,
  sword miss x3.
- `_curated/` holds 19 renamed, game-role-named picks (attack_hit, dash,
  level_up, ui_confirm, victory, skill_fire/frost/arcane/physical, ...) —
  all already synced to `assets/audio/sfx/` with measured normalization
  (M5 A3). All raw files are short one-shots (≤0.7s for hits/steps/
  containers, ~1.4s doors, 2-3s charging loops/deaths). Remaining unmined
  material: container SFX (chest/crate/sack — future loot), door
  open/close (map transitions), orc vocal set (natural goblin voices —
  charge/damage/death/special), footstep variants.

### Minifantasy_Dungeon_Music
- Exactly 2 wav tracks by Leohpaz: `Goblins_Den_(Regular)` (0:58) —
  brooding dungeon ambience, and `Goblins_Dance_(Battle)` (0:53) — driving
  battle loop. Short loops, tight for repeated encounters. NOT in use.
  Obvious casting: goblin-camp map ambience / goblin battle theme —
  thematically literal for this game.

### xDeviruchi — 16 bit Fantasy & Adventure (2025)
- Full 22-track chiptune RPG OST in wav+ogg+mp3 (use ogg in Godot). Track
  names describe casting: Title Theme, Definitely Our Town, Silent Forest,
  Battle 1/2, Victory!, Shop, Lost Shrine, The Mighty Kingdom, Frozen
  Abyss, Decisive Battle 1&2, Peaceful Night, The Calm Before The Storm,
  Never Give Up, Where The Winds Roam, The Journey, Final Battle,
  The Final of The Fantasy, Falling Apart (Prologue), Tales of Firelight
  Town.
- `_curated/` = 5 tracks IN USE (title_theme, definitely_our_town [inn],
  port_town, battle_1, victory). Durations measured: loops run 1:55-6:00
  (Title 2:13, Our Town 4:18, Silent Forest 4:28, Battle 1 3:30, Battle 2
  3:21, Shop 2:52, Lost Shrine 4:51, Decisive Battle 1 5:33, Final Battle
  5:26, The Final of The Fantasy 6:01) — EXCEPT two stingers: **Peaceful
  Night 0:11** and **Never Give Up 0:08**. That makes Peaceful Night a
  one-shot *sleep-beat jingle* (not a loop) — arguably a better fit for
  the sleep/level-up sequence than any loop; Never Give Up = defeat/retry
  stinger. High-value unmined loops: **Silent Forest** (road maps),
  **Battle 2 / Decisive Battle 1** (boss fights: Chieftain, Skinner),
  **Shop** (Liscor market), **Lost Shrine** (Ruins).

### Super Dialogue Audio Pack v1 (Dillon Becker)
- 1090 voice-line wavs: 10 categories (Completion, Confirmation, Greeting,
  Farewell, Refusal, Miscellaneous, Damage, Death, Grunting, Shouting) x
  Male/Female x 5 actors total (M: Alex Brodie, Ian Lampert, Sean Lenhart;
  F: Karen Cenon, Meghan Christian). Real spoken English lines + combat
  vocalizations. `Reference Sheet.pdf` lists every line's text. Only two
  distinct female voices — three distinct female NPCs would need pitch
  variation or sharing.
- License: **CC BY 4.0 — attribution to Dillon Becker REQUIRED** (the only
  pack in the tree with a mandatory credit; put it in credits screen copy).
- Full script extracted (70 shared spoken lines; same script per actor):
  greetings ("Hello/Hey/Howdy/Yo/What's up?"), confirmations ("You got
  it/On my way/On it"), refusals ("No can do/Nah/Not happening"),
  farewells ("See ya/Take care/Good luck"), completions (incl.
  game-UI-ish "Objective complete"), misc ("We're under attack", "Enemy
  spotted", "Low on health", laughter/sigh/gasp/cough vocal effects).
  Tone: **modern-colloquial, not period-fantasy.**
- Opinionated casting given that tone: the colloquial register is
  *canon-correct for Erin specifically* (modern-Earth transplant — "What's
  up?" is literally her voice); risky for period NPCs like Lyonette. The
  wordless sets (Damage/Death/Grunting/Shouting) are tone-safe for ALL
  combatants and the lowest-effort win: female hurt/death barks for Erin,
  male for the PC, shouts for goblin aggro. Only two distinct female
  voices exist — three distinct female NPCs would need pitch-shift or
  sharing.

---

## 5. Casting table — Wandering Inn entity → best in-hand asset

| Need | Asset | Status / note |
|---|---|---|
| PC (Traveler) | Free Pack `Body_A` | IN USE; full directional combat set |
| Erin | Free Pack `Citizen_F/Tavern_A` | IN USE; still the only PC16 directional female — recolor pass still owed for distinctness |
| Lyonette / Selys | `Citizen_F` recolors (aseprite sources ship in-pack) | GAP until recolor; do NOT reuse identical sprite (player-confusion gotcha) |
| Goblin Raider / Shaman / Chieftain | goblin-pack base/female/sword | IN USE; consider scale/tint elite variant for Chieftain |
| Cave flyer (bat) | Bat_Fur | IN USE; Small_Bat free for swarm variant |
| Cave Spider (canon) | none — nearest: reuse bat or Fungus crew | HARD GAP (no arachnid in any pack) |
| Relc (Drake) | `Relc`/`Relc1` PixelLab AI-gen (family PIXELLAB-AI) | PROVISIONAL — first Drake sprite; 8 static rotations, NO anims, style/scale unverified (sec. 1 PIXELLAB-AI). Fills a *static* Drake NPC once screenshot-approved; combat/walk use needs anim generation |
| Klbkch / Antinium | none | HARD GAP (no insectoid); most WI-load-bearing missing race |
| Human bandits (road ambush) | Hideout "Baldits" crew | ready; single-facing battlers |
| Undead (Ruins arc) | Cemetery Zombie crew x4 | ready |
| Sewer encounter | Sewer Rat crew + Sewer tiles | ready; Liscor sewers are canon |
| Named grim adventurer (e.g. Halrac) or alt PC body | Cemetery `A_Hunter` | ready; ONLY other fully-directional character, 3 attack anims |
| The Wandering Inn map | Free Pack tiles/props + Tavern mockups as floor plan | partially IN USE |
| Garden of Sanctuary | Garden Environment pack | ready; near-literal fit (fountain, statues, hedges) |
| Liscor guild/council interiors | Library pack (guild), Castle pack (council) | ready |
| Goblin camp map/arena dressing | goblin-huts + watchtower + Minifantasy goblin music | ready, unmined |
| Smithy / fire dungeon | Forge pack | ready |
| Desert (Zeikhal, far future) | Desert pack | ready |
| Enchanted forest / faerie flavor | Fairy Forest pack (avoid Elf mobs — lore collision) | ready |
| Spell VFX (flame_jet impact etc.) | Tiny Swords Effects (Fire, Explosion) | best in-hand option; crop + scale test needed |
| UI chrome / buttons | Tiny Swords UI kits | IN USE (hotbar); ribbons/banners unmined |
| Skill icons (fire/frost/burst) | **Admurin `Freebies_Icons_Skills.png`** (fire/ice/wind palms, fists) | FILLED — replaces code-drawn placeholders |
| Pixel font | **Admurin UI Packs** (6 themed bitmap fonts, shadow variants) | FILLED — first/only font in tree |
| General RPG icons (weapons/food/emotes) | **Admurin `Freebies_Full_Icons.png`** (~420) | FILLED; dialogue-emote bubbles incl. Zzz/?/! |
| Wolves / road predators | **Admurin Canines** (4 colors, full anim) | FILLED — best-fitting new creature |
| Cave Spider substitute | **Admurin Crab** (multi-leg silhouette) | closer than bat; still not a true spider |
| Dungeon golem / boss brute | **Admurin Golem (armor-break) + Gollux** | FILLED for a generic elite; not a Drake |
| Directional caster enemy | **Admurin Witch Doctor** (4x4, bone-wand) | rare directional caster |
| Animated loot chest | **Admurin `Animated Chests`** (4-5 tiers) | FILLED; pairs with Minifantasy chest SFX |
| Customizable PC with visible gear | **Admurin paint-doll** (base + equip overlays) | only equip-layer character in tree |
| Inn livestock / farm critters | **Admurin Pig/Piggy/Boar/Rabbit** | for farmstead/inn dressing |
| Sleep-beat jingle | xDeviruchi "Peaceful Night" (0:11 stinger, not a loop) | unmined, one-line add |
| Defeat/retry stinger | xDeviruchi "Never Give Up" (0:08) | unmined |
| Boss battle music | xDeviruchi "Decisive Battle 1/2" | unmined |
| Goblin camp music | Minifantasy Goblins_Den + Goblins_Dance | unmined, thematically literal |
| Erin voice barks | Super Dialogue female actor (modern lines = her canon register) | unmined; CC BY — credit Dillon Becker |
| Combat hurt/death vocals (all) | Super Dialogue wordless Damage/Death/Grunt/Shout sets | unmined, tone-safe |
| Goblin vocals | Minifantasy orc charge/damage/death set | unmined |
| Loot/door SFX | Minifantasy chest/crate/sack/door groups | unmined |
| Locked hotbar slot overlay | Tiny Swords Update-010 padlock icon (3 states) | unmined |
| Footstep dust / water splash | Tiny Swords Free Pack Particle FX | unmined, style-agnostic |
| Big impact VFX | Tiny Swords Explosions.png (18-frame) | unmined; crop+scale test |
| Mage/necromancer-flavored NPC (non-Admurin) | **Ninja Adventure `Shaman`/`SorcererBlack`/`SorcererOrange`** (family NINJA16, LOW-CONFIDENCE) | new candidate; style/scale match to PC16 unverified, 16px grid confirmed mechanically |
| Second elemental VFX set | **Ninja Adventure `FX/Elemental`** (Ice/Rock/Thunder/Water/Explosion, multi-frame) | unmined; crop+scale test, alongside Tiny Swords Fire/Explosion |
| Second bitmap font | **Ninja Adventure `Ui/Font`** | unmined |
| Locked-slot icon pairs (Regular+Disabled) | **Ninja Adventure `Ui/Skill Icon` "Items & Weapon"** (24px grid, `*Disabled` variants) | unmined; third icon-grid size in tree (not 16/32) |
| Sewer grate (needs visual pick) | Pixel Crawler Sewer `Assets/Props.png` or `Social/Props.png` | best-candidate sheet only, NOT filename-confirmed — see sec. 3a |
| Cauldron / cooking pot (needs visual pick) | Pixel Crawler Free Pack `Cooking Station.png`/`Estructure.png` | best-candidate sheet only, NOT visually confirmed as a cauldron shape — see sec. 3a |
| Open-chest frame (PC16-family, if needed over Admurin's) | Pixel Crawler Free Pack `Dungeon_Props.png` (unscanned) | speculative; Admurin `Animated Chests` remains the actual FILLED answer — see sec. 3a |
| Training dummy / armor stand | Pixel Crawler Free Pack `Furniture.png` (~col 6-10) | **visually confirmed** armor-stand sub-tile exists (2026-07-03 pass); exact pixel region unlocated — see sec. 3a |
| Farm/inn livestock (2nd source) | Cute Fantasy Free `Animals/` (Chicken/Cow/Pig/Sheep) | family CUTE16, LOW-CONFIDENCE; overlaps Admurin Bovine pack |
| Cluttered/dirty interior furniture accent | Pixel_16_interiors_v2_free `tiles and items.png` (single sheet, grid unconfirmed) | UNRESOLVED — no sub-region filenames, needs a windowed read before any pick |

## 6. Remaining hard gaps (nothing in-hand fits)

1. **Gnolls + animated Drakes (Selys-as-Drake, the Liscor Watch, Relc in
   motion).** The `Relc`/`Relc1` PixelLab packs (family PIXELLAB-AI) now give
   the tree's first reptilian humanoid — but only as 8 *static* rotations
   (no walk/attack/hit/death) with an unverified style/scale match to PC16.
   Good enough for a static Drake NPC once screenshot-approved; a moving/
   fighting Drake needs anim generation, and beastfolk (Gnolls) remain a full
   gap. Until filled, Citizen_F/battler stand-ins misrepresent race —
   acceptable placeholder, flagged.
2. **Antinium (Klbkch, Pawn)** — no insectoid humanoids. Second priority;
   story spine will need them before the Hive matters.
3. **Arachnids (Cave Spider is canon-named in combatants.json)** — Admurin
   Crab is now the closest multi-legged silhouette (better than the bat),
   but a true spider is still missing.
4. Directional female bodies beyond Citizen_F — recolors mitigate; the
   Admurin paint-doll could also be gender-styled via equipment overlays.

**Gaps CLOSED by Admurin's Freebies (2026-07-03, was #4/#5 here):**
skill-icon glyphs (`Freebies_Icons_Skills.png`), pixel font (UI Packs, 6
themed bitmap fonts), general RPG iconography (`Freebies_Full_Icons.png`),
animated loot chests, plus wolves/golem/boss/caster creature coverage. See
sec. 3 Admurin entry. Antinium and Drakes/Gnolls remain the two hard racial
gaps — Admurin adds no reptilian or insectoid humanoids.
