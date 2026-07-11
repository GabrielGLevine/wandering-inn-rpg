# 8d — The Liscor Dungeon + the Horns of Hammerad (IMPLEMENTATION PLAN)

Spec: `docs/superpowers/specs/2026-07-06-liscor-dungeon-design.md` (design
authority). Issues: #14 (dungeon maps + traps + vault), #15 (Horns party
content). One milestone, five phases; A runs background from day one.

## USER GATES (park in HANDOFF taste-queue; phases note their blocks)
1. **Boss pick: RATIFIED 2026-07-11 — GUARDIAN CONSTRUCT** (user, in
   chat). C3 unblocked. Art rides Phase A (character-pro gen); combat
   identity: a trap that fights back — slow, heavy, telegraphed AP
   spikes, terrain interplay with the halls' trap classes.
2. **Ksmvr sub-arm legibility**: same flag as Klbkch — the 4-arm read at
   sprite scale. The antinium_worker attempt-3 prompt kernel ("four-armed
   ant man: TWO PAIRS...") is the proven recipe; user eyeballs the result
   beside Klbkch's.
3. Ceria's skeletal hand stays HIDDEN v1 (spec-flagged canon-sensitive;
   proceeding as spec'd — surfacing here for visibility, not blocking).

## Phase A — art pipeline (background lane; starts immediately)
- A1: "old dark" tile family. FIRST /create-tileset EXPERIMENT DONE
  (tileset 86d6dd3d, 2026-07-11): the endpoint does TERRAIN-BLEND
  semantics — two ground types + 16 transition tiles (dual-grid
  corners), NOT floor-vs-wall; both prompts rendered near-identical
  dark brick joined by a transition curve. LEARNINGS: (a) use it for
  FLOOR VARIETY (lower=flagstone, upper=worn/cracked flagstone —
  organic patches of wear, exactly what a trapped hall wants);
  (b) the dark blue-grey brick PALETTE from the experiment is right —
  reuse the prompt kernel; (c) WALLS stay separate (walls.segments
  render path). SECOND EXPERIMENT (floor-wear pair, tileset 3a7f4643):
  the transition CRACK lines read well, but terrain differentiation is
  weak at 16px — 'heavily worn/rubble' rendered as the same brick.
  A1 VERDICT after 2 of the budgeted attempts: base floor+wall from
  the LICENSED families (Pixel Crawler cave/castle per the catalog —
  the fidelity ceiling is higher), pixflux for trap-tell accents and
  the rune-carved feature tiles; /create-tileset parked (both attempts
  in potential_assets/pixellab_2026-07-11_tilesets/). Fresh ANCHOR
  MEASUREMENT per the gotcha. Windowed adjacency read before any map
  authoring consumes it.
- A2: three Horns characters, v2 create-character-pro → animate
  (idle+walk; slice for Yvlon/Ksmvr who field as allies) → zips.
  PROFILES FIRST (wiki-verified) into character-profiles.md: Ceria
  (half-Elf, circlet, blue robes, hand hidden), Yvlon (silver armor,
  sleeve-hinted metal arms), Ksmvr (Antinium, the worker kernel + a
  harness/belt to distinguish him from Workers). Klbkch/worker scale
  precedents: ~28-30px on-screen, feet-plane anchors measured.
- A3: trap-tell props (pressure plate, dart slit, illusory-floor shimmer
  tile, snare coil) — pixflux flat-swap recipe (`view:"high top-down"`),
  16px world scale. Tells must read AT A GLANCE against the old-dark
  floor (windowed reads; the interactables-must-read rule).

## Phase B — maps + traps (Sonnet lane; after A1's family lands)
- B1: `dungeon_approach` (~16x12) in skeleton_scene.json — the sealed
  M-ARC gallery REOPENS into it (the seal-beat "for now" hook).
  RE-VERIFY `climax_seal` + `arc_flow` canonicals (the danger-list item:
  a reopened seal must not break the closed arc's pins).
- B2: `trapped_halls` (~20x14). Trap classes as DATA PROPS on existing
  machinery: pressure plate = observe-reveals + trigger; dart line =
  trigger with a dash-through window OR requires_skill disarm; illusory
  floor = observe/keen-eye tell + blocked-cell illusion (verify the
  existing visual_states seam covers "floor that isn't"; if it needs a
  NEW mechanism, STOP — the icy_floor lesson says escalate, don't
  force-fit); snare = trigger_radius encounter (exists).
- B3: gallery-reopen gating: enterable only post-`arc_flow` epilogue
  state + the quest open (C1) — sequence-break checked (the door_recap
  lesson: a player who wanders early gets a diegetic locked read).

## Phase C — party machinery + vault (Sonnet lane; C3 gated on user)
- C1: quest "What the Seal Kept" data: Olesm survey stipend + Horns
  arrive via the Guild board (M-DEPTH board seeds it).
- C2: the 4-ally fight: Ceria/Yvlon/Ksmvr as context allies (Relc
  pattern ×3) + Pisces bridge beat. HARNESS ATTENTION: first 4-ally
  cells — new sim_combat_batch rows, bands derived fresh (not assumed);
  PC-death-instant-defeat re-check (ally-carried wins can't win).
- C3 (GATED: boss pick): vault arena + boss data + the FIND beat (the
  deeper door, same runes as the inn's — data + toast/veil copy only,
  no new mechanism).
- C4: party-member skill assist (talk-Ksmvr-through-the-plates) — the
  spec calls it a NEW BEAT CLASS, small. Shape it as a dialogue-effect
  arm riding existing machinery if possible; genuine new sim ground =
  STOP-and-report per the standing rule.

## Phase D — quest dialogue + canon voice (CONTROLLER — not delegated)
- D1: Horns dialogue files (Ceria dry-professional, Ksmvr
  earnest-literal, Yvlon blunt-kind — spec direction lines), Pisces
  bridge beat, Olesm stipend hub addition.
- D2: post-delve: Horns take inn residence (pool presences only v1;
  Social II stages explicitly deferred).

## Phase E — close (controller + one review wave)
- E1: canonicals — `dungeon_walkthrough` (approach+halls),
  `delve_fight`/`delve_talk`/`delve_skill` (per-pillar routes),
  `vault_fight` (pinned seed via harness search). Manifest + CLAUDE.md
  rows. Machine-playtest rotation incl. BOTH dark maps.
- E2: whole-branch opus review (milestone rule) + VISUAL-LOG drain +
  HANDOFF playtest checklist for the user.

## Lane/file ownership (the parallelism contract)
- A-lane: assets/**, sprites.json entries, character-profiles.md.
- B-lane: skeleton_scene.json (dungeon maps ONLY — new map keys, no
  edits to existing maps beyond the gallery door), moods.json rows.
- C-lane: quests.json, combatants.json/arenas.json (new entries),
  sim_combat_batch cells.
- D (controller): data/dialogue/**, skeleton entity dialogue fields.
- SERIALIZE B3 (gallery door edit) behind whichever of B/C merges first
  if both need the gallery entity — it's one entity edit; controller
  can carry it.
- manifest/CLAUDE.md seed-table rows: E1 only (controller), so lanes
  never conflict on the tails.

## Order of operations
A1+A2+A3 fire immediately (background gen). B after A1. C1/C2 parallel
with B (disjoint files). D after C1's quest ids exist. C3 whenever the
user ratifies the boss. E last. The 8c standard-drift lesson applies:
any validator/schema change mid-flight re-briefs open lanes.
