# [Garden of Sanctuary] (issue #9, milestone 8a part 2) — Implementation Plan

> **For agentic workers:** dispatch-grade tasks per repo convention;
> wi-running-the-machine governs execution.

**Goal:** Erin's Garden — a small serene map off the inn, unlocked by her
milestone (ratified spec §5), carrying the rest-anywhere-equivalent bed and
the memorial hill that grows with story beats.

**Design authority:** portals-garden spec §2 (art card: impossible sky, the
ONE map with no darkness) + §5 (RATIFIED: act ≥ III AND K-of-N inn
accomplishments; Erin's own summoned door at the INN — NOT the portal menu;
no-violence = sim guard) + issue #9's superseding comment (the "expansion
key" framing is DEAD) + `docs/design/garden-art/` (direction.md, picks.md,
handoff.md — the staged biome fragments, the memorial statue vocabulary,
stoneify.py, the Old Tree conditional).

## Ratified-at-planning values
- **K = 2 of 4** qualifying accomplishments: `worked_the_inn`-class counters
  (trace the exact shipped inn-work ids), `goblins_spared`, the
  sign-defended accomplishment (trace its shipped id), `resolved_wrong_order`.
  Any two + act ≥ III opens the Garden. No single leg mandatory;
  goblins_spared never solely gates (K=2 guarantees it structurally).
- Unlock SURFACE: at the qualifying sleep, Erin's garden door APPEARS in
  the inn (a `door_when`-gated door entity — the shipped mechanism) + one
  Erin pool-line acknowledging it (she owns the Skill; the PC witnesses).
  No GDI line (this is Erin's moment, not the system's).

## Global Constraints
Everything in the 8a plan's Global Constraints block, plus: the Garden map
has NO darkness — `light_energy` day-bright at every phase (verify
atmosphere.gd's per-map override supports time-invariance BEFORE assuming a
moods.json one-liner — issue #9's danger note); combat can NEVER start on
the garden map (sim guard in `start_combat`, unit-tested, not a
data-convention); `goblins_spared` (#26) may not exist yet as a producer —
the gate must read absent-as-zero (it does by counter semantics; K=2 of 4
still reachable via the other three legs — verify, don't assume).

### Task G1 — the map, the unlock, the guard, the bed
**Files:** data/skeleton_scene.json (map `garden_sanctuary` from the art
handoff's staged fragment — one open serene space, the hill rise, fountain
centerpiece per picks.md; `garden_door` in the inn, `door_when` {act +
K-of-N — trace how compound door_when gates compose, extend the validator
if K-of-N needs a new shape and STOP if that's genuinely new machinery
rather than a door_when-class extension}; `garden_exit` back), data/moods.json
(day-bright time-invariant card — the §2 direction values from
direction.md), data/sprites.json + committed PixelLab-owned assets from the
art cache (statues, plinth, vine-arch door, sky-mist tile — SHIP-OK
convention, PIL-measured anchors), src/core/wi_game.gd (the no-violence
guard: start_combat refuses on this map — trace the ONE call site class),
Erin's unlock pool line (in her voice, no mechanics readout),
tests (the guard + the gate math), fixture `near_garden` + canonical
`garden_walkthrough` (unlock at sleep → door appears → enter → walk →
rest-bed sleep parity [the DP3 sleep_toast idiom: "Somewhere, a door
closes softly behind you." — draft your own in-register line] → exit),
registry three-way.
**Danger:** the inn door placement blast radius (the most-walked map);
licensed Garden-pack picks stay manifest-tracked/uncommitted — ONLY
PixelLab-owned assets are committed this task; placeholder fallbacks for
any licensed tile the map references.

### Task G2 — the memorial hill seam
**Files:** the memorial as an accomplishment-gated `visual_states`/decor
LIST on the hill (the art director's vocabulary: colorless statues appear
as story beats bank — v1 set: the seal beat (`sealed_the_breach`-class id,
trace it) + `cleared_the_warren` + one Wrong-Order remembrance; each a
stoneify-treated owned statue with an OBSERVE line in-voice, no names the
spoiler cutoff forbids), an [Appraise]/observe seam per statue (the
existing observe machinery), extension of `garden_walkthrough` proving one
memorial state-change live (fixture banks the counter → statue present +
observe line pinned). VISUAL-LOG windowed read of the hill at 2 memorial
states.
**Danger:** the memorial must never render progress-toward (statues are
RESULTS); Vol 1-7 scope binds what any statue may depict.

### Task GF — close
Whole-#9 review (sonnet task-scoped — the milestone's opus pass already
covered 8a's seams; adjudicate proportionality at dispatch), windowed
rotation of the garden surfaces (the eyes-closed identity test: does the
Garden read unlike every other map at a glance?), VISUAL-LOG drain,
HANDOFF playtest checklist, `Closes #9` (+ milestone 8a fully done).
