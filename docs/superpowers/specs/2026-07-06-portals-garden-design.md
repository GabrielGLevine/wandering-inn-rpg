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
