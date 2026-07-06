# toll_goblin.json — companion notes

**Narrative purpose:** "The Bridge Toll" (spec §2) — the game's first joke
quest. Tone target: comedy from SPECIFICITY (the sash, the rock pile, the
counted planks), never from mocking him — his dignity is the joke's floor,
not its target.

## Canon cites
- Goblins earning/taking their own names is canon (Rags, Pyrite, Noears —
  deed-names and self-names). "Toll" the self-named toll-goblin extends
  that pattern. **OPEN (canon-plausible outlier, per spec):** a non-hostile
  entrepreneurial goblin is deliberately an outlier; spec already flags it.
- Broken-Common goblin speech is canon register (early Rags-tribe chapters).
- The hired pool's gossip is mechanically true in-game: the corusdeer herd
  ("antlers ORANGE. Not on fire. Checked twice"), the Rock Crab ("boulder
  ... MOVED"), and the post-Act-II raid escalation ("more goblins on gate
  road") — the spec's "mechanical informant" made literal.

## Invented / OPEN
- **Speaker name "Toll"** — ORIGINAL+flag (self-named). If the user wants
  him nameless pre-hire, swap speaker to "Goblin" and have the hire beat
  mint the name — one-node change, and arguably funnier. Flagged for taste.
- **Toll prices** (2 gold / haggled 1): sized as a light economy sink
  against the ~4-gold work day. Repeatable by design (no hide on pay).
- **The shiny rock** is diegetic text only (no item spent). If inventory
  wants a real pebble item, that's a wiring choice — recommend against
  (the gag reads cleaner as text).
- **[Diplomat] class gate on the hire chain** — an in-fiction exception to
  the "gate on in-conversation actions" policy, same as goblin_parley's
  warrior gate; the spec names it "a [Diplomat] chain," so this is
  spec-directed. Visible-locked (tease) per the gating split.

## Wiring notes
- `toll_goblin_scrap` encounter: he FLEES (low HP flee or scripted rout)
  and the entity returns after 2 sleeps — the dormant-respawn machinery as
  comedy (spec). `fought_toll_goblin` banks on_victory to unlock the
  "special price, no hitting" hub variant.
- `_hired_talk_pool` (top of file) is skeleton_scene entity data
  (`talk_pool_post`, requires `hired_toll_goblin`), NOT graph nodes —
  Lyonette C4 precedent. His pre-hire base pool draft lives in
  pools/talk_pools.json.
- `hired_toll_goblin` is the spec's "unique counter" — a lookup surface
  for future content (his pool can grow with new region events).
- Suggested quest id `the_bridge_toll`; beats: meet (`paid_bridge_toll`
  OR `fought_toll_goblin` OR `hired_toll_goblin` — an any-of beat may
  need quest-machinery thought, else make the quest hire-path only and
  leave pay/fight as unquested gags. **OPEN.**

## Softlock audit
Hub: hidden/locked options + ungated "Not today." ✓. start_combat only on
an `end: true` option ✓. haggle/standoff/hire nodes all keep an ungated
back-out ✓.
