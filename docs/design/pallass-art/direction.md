# PALLASS — direction card (art-director lane, 2026-07-07)

Region: Pallass v1, two stacked tier-maps (market tier + forge tier),
issue #16. Sources: `docs/design/city-identity-bible.md` §PALLASS,
issue #16 brief, `docs/design/character-profiles-staging.md` §Pallass.

**⚑ SEED-LABEL FLAG (not resolved here):** the city-identity bible
labels the Pallass seed **"8f"** (§"Pallass expansion seed (8f…)")
while GOAL-CHAIN.md ratifies the chain position as **"8e. PALLASS"**
(and names 8f as THE VOICE PASS). Per the dispatch: flagged for the
controller/user; this doc follows GOAL-CHAIN and says **8e**.

## The identity claim (what the mockup must prove)

**You are standing on a shelf of a machine.** Every Pallass map is a
horizontal slice of a vertical city: a band with a *rising wall* at
its back (the tier above), an *engineered floor* underfoot, and a
*parapet over open dark* at its front (the tiers below). The two-band
composite must make a first-time player read the vertical stack in
under 2 seconds — one shelf above another, connected by a bronze
elevator tower that crosses both bands at the same x.

## The shelf grammar (the vertical-tier read, solved as layout law)

Every Pallass tier map is composed of three fixed zones, top to bottom:

1. **The rising wall (north edge, 1.5–2 cells):** engineered slate
   masonry facade with bronze pilasters — the flank of the next tier
   up. Never sky, never generic "wall": the ceiling of your world is
   the next floor's foundation. Crystal lamps run along its base in a
   ruler-straight row.
2. **The shelf floor:** the engineered-masonry tile family (below).
   Precisely cut slabs in a hard grid — laid by [Engineers], not
   masons. No organic wear, no mud, no grass.
3. **The parapet + void (south edge, 1–1.5 cells):** the Wang-tileset
   drop edge — a bronze-trimmed rim, then near-black under-tier
   darkness with *sparse distant lamp glints* (the tiers below, far
   down) and rising steam. The player walks along an edge over a city
   that keeps going down.

The **Grand Lift** tower is the one element that violates the band —
deliberately. It spans from band to band at the same screen x in the
two-map composite, physically stitching the slices into one machine.
That continuity is the whole vertical argument in a single prop.

**Canon orientation (wiki-verified, see cites):** Pallass is an
inverted-pyramid city of **10+ levels** — markets/Watch on floors
1–3, the **Blacksmith's Quarter on floor 9**, battlements above. So
in the stacked composite the **forge tier band sits ABOVE the market
tier band** (the instinctive "forges in the basement" read is wrong
for Pallass — the fires are up in the sky). Bonus read: a faint warm
furnace rim along the *top* of the market tier's rising wall — the
forge tier's glow bleeding over its parapet — tells the player
something burns overhead. NOTE: the bible says "nine-tiered"; the
wiki reads "at least 10 levels" — treat tier COUNT as flavor, never
name a specific total in player-facing text.

## Palette — forge-bronze on slate (quarantine row three)

The three-city stress test, side by side. Liscor and Invrisil rows are
REFERENCE derivations (Liscor from shipped values/bible; Invrisil's
card is its own 8c lane's to ratify) — the Pallass row is ratified by
this card.

| City | Base / field | Accent (the quarantined hue) | Light |
|---|---|---|---|
| **LISCOR** | warm stone `#8F7A5F` (34° S34 V56), mud `#6B5A3E` | **amber lamp-glow `#F2B450`** (37° S67 V95) | warm amber, flickering hearths |
| **INVRISIL** | pale marble `#D8D4C8` (45° S7 V85), cool daylight `#AEB8C4` | **coin-gold `#E3B341`** (42° S71 V89) | cool daylight outside, warm expensive interiors |
| **PALLASS** | slate `#39424E` (214° S27 V31) / `#5A6673`, under-tier dark `#212836` | **forge-bronze `#A66A33`** (29° S69 V65), hi `#C98A4B`, lo `#6E4520` | **steam-white crystal `#E9EEF2`** in ruler-straight rows; furnace glow `#F65510` (18° S93 V96) — forge tier ONLY |

**Quarantine argument (discipline #2, third-city stress test):**

- **Bronze vs Liscor amber:** nearest-collision pair, held apart on
  two axes. (a) *Role:* amber is a LIGHT (a glow in the air); bronze
  is a MATERIAL (metal trim bolted to slate) — **Pallass lamplight is
  steam-WHITE, never amber**. If a Pallass lamp ever renders warm
  yellow, it has become Liscor — that is the failure mode to check in
  every windowed screenshot. (b) *Value:* amber V95 luminous vs
  bronze V65 metallic; bronze always sits ON slate (214° field),
  Liscor's amber floats over warm browns (34–37° field) — opposite
  temperature fields.
- **Bronze vs Invrisil coin-gold:** gold is yellower (42° vs 29°) and
  brighter (V89 vs V65) — mint-bright coinage vs industrial alloy.
  Invrisil gold trims PALE marble; Pallass bronze rivets DARK slate;
  the field contrast does most of the work at 16px.
- **Furnace glow `#F65510` scoping rule:** red-orange 18° — hotter and
  redder than amber, and it is scoped: *forge tier only, always a
  LIGHT (molten channels, furnace mouths, PointLight2D), never a trim
  color, never on the market tier.* Nothing flickers unless it is a
  forge (bible: crystal lamps hold steady).
- Secondary tell available if needed: verdigris patina `#4E7A6A` on
  old bronze — no other city owns a green-teal accent. Used sparingly
  (aged lift machinery), not required v1.

**The lava-glow call (benchmark ruling, coordinator input 2026-07-07):**
`potential_assets/_benchmarks/benchmark-forge-lava-interior.png` was
PIL-scanned (never rendered — provenance was unstated, and the scan
settled it: 25% of its 16px cells are EXACT pixel matches to the
Pixel Crawler Forge `Tiles.png`, 0% to Cave — it is Forge-pack-
composed, licensed vocabulary). Ruling in two halves:
- **Lava glow STAYS in the Pallass card** — forges are canon Pallass
  identity (Blacksmith's Quarter, floor 9) and the benchmark's lava
  `#f04800` (18°) is the same hue register as the ratified furnace
  glow `#F65510`. The scoping rule above already contains it: forge
  tier only, always a LIGHT.
- **The benchmark's FIELD is rejected for Pallass.** Its darks are
  warm maroon (`#180000` 30%, `#483030` 14% — red-led darkness: a
  "fire dungeon interior" register). A Pallass tier keeps a COOL
  charcoal/slate field under the glow (the generated brick family
  already does) — the warm-field version reads as a different place
  (a smithy interior / dungeon heat, the Forge pack's own catalog
  casting), and would let tier three drift toward Liscor-warmth.
- **Composition ceiling adopted (numeric):** the benchmark holds
  bright molten to ~5% of scene area over ~45% near-dark — ONE
  dominant lava mass, sparse glints elsewhere. The two-tier mockup's
  forge band runs 23% warm (a deliberate postcard exaggeration in a
  narrow cross-section band); **in-game forge-tier maps budget bright
  molten ≤8% of walkable-view area, one dominant channel, darkness
  carrying the rest** — the windowed check for the wiring pass.

Measured from the accepted PixelLab outputs (dominant-color scan):
elevator bronze `#C09048`/`#786048` on dark navy `#303048`; lamp post
bronze `#906030` with `#F0F0F0` crystal; tileset upper slabs
`#6078A8`/`#487890` over void `#000018`–`#181860`. The generated slab
family runs lighter/bluer than the target slate row — acceptable at
mockup stage (it holds the cool field); flag for the wiring pass to
re-grade via mood tint or a regenerate if the user wants it darker.

## Landmark reads (2-second recognitions)

| Landmark | Read | Source |
|---|---|---|
| **The Grand Lift** | bronze riveted cage tower, glowing gate, spans BOTH bands at one x — "that machine connects the floors" | PixelLab `prop_great_elevator` (KEEP, batch 1) |
| **Parapet + void edge** | bronze-trimmed rim, black drop, distant lamp glints below — "this floor ends in sky" | PixelLab `tileset_slate_over_void` (KEEP) |
| **Posted-price board** | slate board, white chalk rows, bronze stand — "prices are posted; nobody haggles here" (the anti-Invrisil) | PixelLab `prop_price_board` (KEEP) |
| **Crystal lamp row** | white steady light on bronze posts, ruler-straight spacing — "engineered light, nothing flickers" | PixelLab `prop_crystal_lamp` (KEEP) |
| **Public forge station** | anvil + furnace mouth glowing orange — the forge tier's interactable | PixelLab `prop_forge_station` (batch 2) |
| **Steam vents** | bronze grates, white puffs (ambience emitters) | PixelLab `prop_steam_vent` (KEEP) + GPUParticles |

**Never anonymous architecture (bible "Never" list):** every
structure on either tier carries a FUNCTION marker — the signage
motif is a small bronze plaque bar with white glyphs over every door
(guild hall, smithy, Watch post, lift office). No unlabeled building
fronts; if a facade has no function, it doesn't get placed.

## Tile-family inventory

- **Floor, market tier:** "engineered masonry" slab family — PixelLab
  `tileset_slate_over_void` (16 Wang tiles, 16px, upper terrain =
  slab floor; OWNED, committable). Full-slab fill tiles: atlas cells
  with all-`upper` corners; parapet edges: mixed-corner tiles.
- **Floor, forge tier:** dark engineered brick + molten-channel
  family — PixelLab `tileset_brick_over_molten` (batch 2; OWNED).
  Licensed reinforcement: Pixel Crawler Forge molten block + brick
  fills (see `picks.md`) via the private bundle.
- **Under-tier void:** tileset lower-terrain tiles (near-black navy
  with faint glints). Licensed alt: Cave blocked fill `rgb(28,29,19)`
  (already wired in `biomes.json` cave entry) if a pure-dark fill is
  needed.
- **Walls/structures:** `prop_tier_wall` facade segment (batch 2,
  repeatable 128×48) for the rising wall; Castle slate-checker cells
  as licensed interior-floor alt (see `picks.md`).
- **Decor:** great elevator, crystal lamps, price boards, market
  stalls (uniform civic design — deliberately identical stall frames,
  the QUALIFY verb applied to commerce), forge stations, steam vents,
  bronze signage plaques.
- **Scatter:** NONE on the market tier (an engineered city sweeps its
  plazas — the absence of rubble/scatter is itself a distinctness
  tell vs Liscor's mud and the 8a ruin's debris). Forge tier allows
  sparse work-clutter only at stations (ingot stacks, tool racks —
  future picks).
- **Ambience/light:** steam-white GPUParticles from vents and from
  the void edge (rising past the parapet); PointLight2D white for
  crystal lamps (steady, `flicker: none`), orange `#F65510` for
  furnace mouths/molten channels (forge tier only); market tier gets
  NO warm light sources. Sound note for the wiring pass: hammer
  rhythm layers distance-mixed on the forge tier, elevator bell at
  the lift, steam hiss at vents (bible §Pallass sound).

## Mood-card DRAFT (values only — NOT wired; moods.json is out of bounds this pass)

```
"pallass_market": {
  "day":   {"tint": [0.92, 0.97, 1.06], "vignette": 0.30},
  "dusk":  {"tint": [0.85, 0.88, 1.02], "vignette": 0.35},
  "night": {"tint": [0.62, 0.68, 0.88], "vignette": 0.38},
  "_intent": "cool engineered daylight; slate stays cold at every
   phase; lamps carry white light after dusk (light color #E9EEF2)"
},
"pallass_forge": {
  "tint": [1.02, 0.86, 0.78], "vignette": 0.42,
  "_intent": "TIME-INVARIANT (a forge hall works day and night,
   inn_upstairs/sewers precedent); warm-dark field so the molten
   channels and furnace PointLight2Ds (#F65510) do the lighting"
}
```

## Manifest entries required for licensed picks (controller lands these)

| Manifest path | Source pack | Status |
|---|---|---|
| `assets/tiles/forge/Tiles.png` | Pixel Crawler - Forge 1.2 | **NEW** (verdict FORBIDDEN, bundle:true, fallback:placeholder — same shape as every Pixel Crawler entry) |
| `assets/tiles/castle/Tiles.png` | Pixel Crawler - Castle Environment 0.3 | already in manifest (8a) — no new entry |
| `assets/tiles/cave/Tiles.png` | Pixel Crawler - Cave | already in manifest — no new entry |

PixelLab outputs are user-owned + redistributable (TIER-PUBLIC) — no
manifest entries needed; provenance note goes in
`assets/LICENSES/pixellab-ai-generated-verdict.md` at wiring time.

## Canon cites

- wiki.wanderinginn.com/Pallass — inverted-pyramid structure, 10+
  levels, floors 1–3 markets/Watch/poorer housing, floor 9 Blacksmith's
  + Alchemist's Quarters, battlements above; **Grand Lifts: eight
  non-magical counterweight platforms** ("descend when loaded, cranked
  back up when empty") plus magical elevators; **four great stairways
  bottom-to-top with lane discipline — ascending, descending, and a
  lane reserved for Runners** (bureaucracy painted on the ground — a
  gift detail: lane markings on stairs/plazas are cheap tiles that
  scream QUALIFY); population Drakes, Gnolls, Dullahans, Garuda;
  the Liscor door lands on the 8th floor ("newest floor still under
  development", guardpost nearby).
- Door link is Volume 5 (spoiler-cutoff.md §3 pre-verified) — safe.
- Spoiler check: everything above enters by Vol 5–7; nothing past the
  Book 17 bar is referenced. Tier count kept vague per the
  bible-vs-wiki mismatch noted above.

## Self-review vs the bible's disciplines

1. **Verb-first:** every surface above names QUALIFY — posted prices,
   uniform stalls, lane markings, function plaques, permit-gated lift.
2. **Palette quarantine:** three rows side-by-side above; bronze≠amber
   argued on role+value, bronze≠coin-gold on hue+field; white-lamp
   rule is the enforcement check for every future screenshot. PASS.
3. **Population texture:** not this lane's surface (uniformed
   rotations are 8e's population pass) — but stall/signage uniformity
   pre-seeds it.
4. **Traversal signature:** LIFTS — the Grand Lift is the composite's
   spine, crossing both bands. PASS.
5. **PC race read:** dialogue seam, out of art scope; noted for
   handoff.
6. **Music keys:** percussion-forward noted in ambience section for
   the audio pass.
- **Stats-hidden rule:** no stat text on any prop (price board rows
  are unreadable-glyph chalk marks at 16px — by design). PASS.
- **Never-list:** no haggling surface, no anonymous architecture
  (plaque motif), arrival-as-quest is the Door lane's beat. PASS.
