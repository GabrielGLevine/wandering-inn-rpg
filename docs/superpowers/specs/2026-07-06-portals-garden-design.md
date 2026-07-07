# 8a — The Magical Door + [Garden of Sanctuary] (DESIGN)

Status: earn-shape user-ratified 2026-07-06 (story-earned at arcs).
Fable-authored with art/quest/dialogue direction. Task plan at boundary.

## 1. Quest design: "The Door That Goes Elsewhere"

The inn's cellar door (upstairs shipped in M-DEPTH establishes
inn-as-home; the DOOR chain starts post-M-ARC epilogue):
- **Beat 1 — the flicker:** post-epilogue sleep, a GDI-free beat: Erin
  mentions the pantry door "went somewhere wrong this morning."
  Investigate: the door shows a one-frame elsewhere (visual_states
  flicker + a cold-air toast).
- **Beat 2 — the mage consult (3-path parity):** FIGHT: clear the
  disturbance that's "leaking" through (a small rift-vermin encounter);
  TALK: persuade Pisces to examine it (his necromancy-adjacent senses;
  persuaded_someone chain); SKILL: [Observe]/[Keen Eye] the doorframe
  runes yourself (scouted-intelligence path, Olesm assist beat).
- **Beat 3 — attunement:** any path banks door_understood → a
  multi-step fetch ACROSS existing content (a focus item from the
  sewers' deep gallery [the sealed passage cracks open for ONE room —
  the M-ARC seal pays interest], a catalyst bought from Krshia [economy
  sink, ~30-40g], Erin's blessing beat [her stage-2 relationship line
  if Social II landed — soft-gate, not hard]).
- **Beat 4 — awakening:** the door AWAKENS (GDI line: "[The inn has a
  Door. The Door has opinions.]") → the PORTAL MENU: a door-side
  dialogue graph listing attuned destinations (Liscor fast-travel
  first; Riverfarm/Invrisil attune as their expansions open — each
  expansion's ARRIVAL quest starts at this door).
- **[Garden of Sanctuary]** (separate, later beat — after 8b or 8c):
  a key turns up in expansion content (canon: the Garden responds to
  need); one-beat unlock; the Garden = a small serene map off the inn
  (mechanical surface: a rest-anywhere-equivalent bed + a memorial
  wall that grows with story beats — the game's remembrance surface).

## 2. Art direction

- **The door itself:** the pantry door prop gains awakened
  visual_states (rune-edge glow, color per destination when open —
  Riverfarm warm green, Invrisil cold white, Liscor amber). PixelLab
  prop gen per the high-top-down recipe; glow via the light machinery.
- **The Garden:** its own direction card — impossible sky (bright
  ceiling gradient in a windowless space), soft greens, drifting
  petals (ambience preset reuse: leaves, recolored), the memorial
  hill's statues as silhouetted props. Mood: the ONE map with no
  darkness — light_energy day-bright at every phase.
- **Rift flicker:** 2-frame elsewhere-glimpse baked as a visual_states
  sprite swap, not a shader (cheap, readable).

## 3. Dialogue direction (keys)

- Erin (breathless, delighted-then-businesslike): "It went somewhere
  COLD this morning. Doors shouldn't have moods. …Can you look? If it
  eats you, yell."
- Pisces (TALK path, grudging fascination): "A spatial anchor. Crude.
  Fascinating. Whoever built your inn, adventurer, built it on
  something that remembers being elsewhere."
- The door's own surface never speaks — the GDI voices its milestones
  (gold-on-black one-liners; the veil's fourth cameo).

## 4. QA / scope

`door_awakening` canonical (the chain, any path) + `portal_menu`
coverage (fast-travel round-trip asserts map_changed pairs + no
trigger leaks — teleport-class transition, the O2 rule: portals never
fire trigger_radius). Garden ships with its unlock beat only when its
expansion lands. Non-goals: inter-continental canon destinations;
door mana-capacity simulation; moving the door.

## 5. EARN CONDITIONS — RATIFIED (user session, issue #7, 2026-07-07)

Binding for issues #8/#9; supersedes any conflicting earlier text above.

**The Door (earn shape: the Pisces recovery chain, canon-closest):**
1. Beat structure confirmed: flicker → mage-consult (Pisces, 3-path
   FIGHT/TALK/SKILL) → recovery run → Pisces studies at the inn over
   N sleeps (opaque-until-sleep: his talk-pool stages shift, zero
   progress text) → awakening + portal menu.
2. **The recovery run lives in a small DEDICATED ruin map family**
   (Albez-flavored surface ruin, sewers-sized, one map) — 8a owns its
   whole arc; 8d's dungeon untouched; no M-ARC ripple.
3. **Attunement components: ruin + Krshia ONLY** — the anchor stone
   from the ruin run + a purchased Krshia catalyst (~30–40g, her
   charms counter). The old draft's sewers deep-gallery item is OUT
   (the sealed passage stays sealed).
4. **No Erin gate on the chain** — she reacts via existing pool lines,
   gates nothing.
5. **ANCHOR-STONE-PER-REGION RATIFIED as the expansion-scaling idiom:**
   every future region milestone (8b Riverfarm, 8c Invrisil, 8e
   Pallass) ships an "attune a new mana stone" beat as its Door hook —
   the Door grows per region, never a one-shot unlock. Issues
   #10/#12/#16 inherit this.

**The Garden (earn shape: Erin's milestone, player-witnessed):**
1. Unlock condition: `act ≥ III` AND **K of N qualifying inn
   accomplishments** (K tuned at planning so no single playstyle is
   mandatory — explicitly: goblins_spared counts toward K but never
   solely gates).
2. **Qualifying set ratified (all four):** inn work (meals/chores
   counters), `goblins_spared`, the sign-defended beat, and
   `resolved_wrong_order` (double-reads as Erin's own arc advancing).
3. It is ERIN'S Skill — the PC witnesses/participates via the counters.
   No-violence rule = sim guard: combat can never start on the garden
   map.
4. Spoiler cutoff holds: "the Magical Door" everywhere player-facing
   (never the Vol-9 Skill name); all content within Vol 1–7 material.
