# 8d — The Liscor Dungeon, with the Horns of Hammerad (DESIGN)

Status: user-seeded; the demo's endgame. Fable-authored with art/quest/
dialogue direction. Canon: the Dungeon of Liscor (trap-dense, ancient,
the Raskghar's home); the Horns of Hammerad — Ceria Springwalker
(half-Elf [Cryomancer]), Pisces (OURS ALREADY — his Horns membership is
the retcon-safe hook: v1 keeps him inn-adjacent, his Horns beat is the
BRIDGE), Yvlon Byres (human [Wardancer]-line), Ksmvr (Antinium —
**the ratified s21/s33 sprites finally land**). Wiki-verify everything.

## 1. Maps (2 + arena)

- **The dungeon approach** (~16x12): the sealed M-ARC gallery
  REOPENS (the seal-beat's "for now" pays off) into a proper
  entrance chamber. Art card "old dark": pre-Liscor masonry vs the
  sewers' city-stone — different tile family (PixelLab tileset gen
  candidate — the v2 /create-tileset endpoint's first real use),
  trap tells as floor-variant props.
- **The trapped halls** (~20x14): the dungeon's identity = TRAPS, not
  monsters — 3-4 trap classes as data props (pressure plate [observe
  reveals], dart line [dash-through or disarm], illusory floor
  [keen-eye tells], a snare that starts a fight). The SKILL pillar's
  showcase map.
- **The vault arena** (boss): a guardian construct or Raskghar war
  party (canon-check which fits the depth we claim; the construct
  reads more "dungeon" — flag both, user picks at plan).

## 2. The Horns (party machinery's biggest test)

- Ceria + Yvlon + Ksmvr field as CONTEXT ALLIES for the delve (the
  Relc pattern ×3 — the roster's first 4-ally fight; harness cells
  will need real attention; Pisces joins as the bridge beat [his
  reveal: "I delved with them once. Before your inn. Some debts one
  repays in person."]).
- Art: three full v2-pipeline characters per profiles (Ceria: circlet,
  skeletal hand HIDDEN v1 [canon-sensitive — flag]; Yvlon: silver
  armor, metal arms hinted at the sleeves; Ksmvr: s21/s33 finally
  integrated + a third arm-pair read at 64px is the sprite challenge —
  the profiles' Antinium entry governs).
- Dialogue direction: Ceria dry-professional ("Traps first. Glory
  after. Ksmvr, do NOT touch the—"), Ksmvr earnest-literal ("I have
  not touched it. I am considering touching it. I will report before
  touching it."), Yvlon blunt-kind.

## 3. Quest design: "What the Seal Kept" (the endgame delve)

- Open: Olesm's survey stipend + the Horns arrive at the Guild board
  (M-DEPTH board seeds it) → the approach → the halls (trap gauntlet
  where each PILLAR opens a different safe route: fight the snare
  nest / talk Ksmvr through the plates (party-member skill assist —
  new beat class, small) / skill-solve the tells) → the vault fight →
  the FIND: not treasure — a DOOR deeper still, sealed with the same
  runes as the inn's (the two arcs shake hands; the demo's final
  image before the epilogue re-run).
- Post: the Horns take residence at the inn (pool presences — the inn
  gets fuller; Social II stages extend to them later).

## 4. QA/scope

Canonicals: approach+halls walkthrough, the delve per-path, the vault
fight pinned. Trap seams: data props on existing response machinery
where possible (observe/requires_skill/trigger); anything genuinely
new escalates. Non-goals v1: the dungeon's full canon depth (Facets,
the raid plots), Ceria's hand reveal, playable-Horns, loot beyond
2-3 vault items (M-GEAR band).
