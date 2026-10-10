# Generation review: regional kits (Invrisil, Liscor, plus gaps from the allocation pass)

Sources:
- `docs/art-generation-list.md` on branch `issue/620-kits-liscor` (25 open rows);
- the reads `scene-read-1a*.md`, `scene-read-1b*.md` and `scene-read-r1-r2.md`;
- `allocation/ALLOCATION-identity.md`.

The ranking is by how much regional identity each item unlocks.

## Tier 1: architecture and materials (what makes a region read as itself)
1. **Liscor brick facade kit:** plain, window, door-in-facade and corner modules, plus a matching hipped roof set. The Liscor reader calls this "the single ask that makes the region read warm brick".
2. **Liscor city wall and gate tower:** warm sandstone or brick, with cap and face tiles and a gate arch. It replaces the grey castle wall that frames every street shot.
3. **Invrisil interior floor and wall:** a pale limestone/checker floor and a plaster wall with wainscot and a gold cornice. This is the remaining gap in the 1b read: rooms read as "cold tile / brown timber" before "wealthy".
4. **Invrisil facade modules, roofline and rooftop mass.** The public build repeats one window 14 times, and the band above the facade is a flat stone mass.
5. **Liscor street paving:** a warm sandstone-sett Wang atlas, plus a civic interior wall and floors for the Runners' Guild and the barracks.
6. **Invrisil curb tiles:** marble curb and transition tiles around the fountain square, plus a cross-street paving apron.

## Tier 2: signature props and lights
7. **Pallass identity lamp:** a bronze arm with a white lamp, in day and lit states. Pallass has no fitting lamp at all. (Allocation gap.)
8. **Underground lit fixtures** for ruin, dungeon and sewers. Check the uncontested standing brazier first.
9. **Invrisil wall lantern:** bracket, glass and flame, with an owned public fallback. Also a tall street lamp.
10. **Liscor civic sets:**
    - barracks duty set: kit rack, bunk row, weapon rack and roster;
    - Runners' sorting set: pigeonholes and a satchel pile;
    - guild board wall;
    - a second counter set.
11. **Invrisil interior furniture:** oak chair and settee family, axis-aligned rugs, a glass-and-gold display counter, and a workbench set-piece.

## Tier 3: stand-ins, recuts, fallbacks
12. **Invrisil stand-ins:** a crate stack for "A Good Vantage", a shadowed nook, a sealed bale, and a tray with contents.
13. **Invrisil signs and doors:** a third shop sign (the Rest's cards-and-hat sign), a second owned street door, a third shop door, and a framed work-room door.
14. **Liscor recuts:**
    - a cold hearth that reads as a hearth;
    - the mud-tracked table;
    - the Antinium worker silhouette at gameplay scale;
    - an official seat family.
15. **Public fallbacks:** a stool with legs; a smaller pebble (data-fixed for now); windows with a night state (#618).

## Cost and logistics
- About 35–40 assets. PixelLab's subscription lapsed on 2026-10-06, with about $0.05 of credit left, so generation needs a renewal.
- Each batch is wired pool-first through `wire_asset`, then gets a scoped blind re-read of the affected region.

## Cost estimate (checked against PixelLab help and the account balance on 2026-10-09)
- **Account:** subscription expired 2026-10-06. Credits are $0.05. The plan's 2,000 generations are frozen and unlock on renewal.
- **Per-call costs (generations):**
  - tileset: 3–4
  - `create_map_object`: 1
  - Pro Flash object: 5–6
  - `create_object_state` (for example, a lit state): 10–25
  - building kit: 10–25 (needs 15 available to start)
  - character, pro: 10–25, plus 8 for an 8-direction animation
- **Estimate including retries** (best of 2 or 3 per asset for art direction):
  - Tier 1: about 150–250
  - Tier 2: about 250–300
  - Tier 3: about 150–200
  - **Total: about 550–750 generations, roughly 1,000 worst case.**
- **Cheapest route:** one month of Tier 1, at $12 for 2,000 generations, covers all three tiers with about 2x headroom. Credits-only is possible, but per-call USD prices vary by tool (see pixellab.ai/pixellab-api). For scale, #603's three 8-direction rigs cost $0.40.
