# topdown_floor_tiles_12 license verdict

Pack: topdown_floor_tiles_12
Source: potential_assets/topdown_floor_tiles_12/
Reviewed files:
- potential_assets/topdown_floor_tiles_12/README.txt
  (copied verbatim to assets/LICENSES/topdown-floor-tiles-12-README.txt)

License text summary:
The README only describes pack contents (12 cropped 540x540 PNG tiles: 4
grass, 4 dirt, 4 transition) and tile size. It states no copyright owner,
license name, redistribution grant, commercial-use grant, or attribution
requirement -- there is no Terms.txt or LICENSE file anywhere in the pack
directory (confirmed via directory search).

Used for: M5 R4 immersion pass -- street biome skirt fill (dirt_01.png),
street/goblin_ambush dirt-transition edge strips (transition_01.png), and
scattered grass-tuft floor-layer variants (grass_01.png). Each is used as a
single whole-image "tile" (tile_px = its own 540px dimension, coords [0,0]),
not cropped further.

Verdict: SHIP-OK (user-attested, per the 2026-07-02 blanket attestation:
"all user-provided packs are fully licensed and usable, terms-file or not" --
same standing as goblin-pack/goblin-female-pack/goblin-sword-pack, which
carried the identical no-terms-file gap and were upgraded from ASK-USER to
SHIP-OK under that attestation).

Notes:
Flagging explicitly per task instructions since this is a genuinely new pack
directory with no terms file at all (stronger gap than Castle Environment,
which does ship a Terms.txt) -- re-ask the user directly if the blanket
attestation is ever narrowed or revoked.
