# The Magical Door (issue #8, milestone 8a) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development
> via the repo's wi-running-the-machine cycle. Tasks below are dispatch-grade
> briefs (repo convention — the M-DEPTH DP1-DP5 shape), not 2-minute steps:
> each carries its own files/interfaces/verification and ends committable.

**Goal:** the inn's pantry door becomes the earned expansion gate — the
4-beat "Door That Goes Elsewhere" chain (per spec §5 ratification) ending in
a portal menu with Liscor fast-travel, plus the anchor-stone seam every
future region milestone plugs into.

**Architecture:** content = data (skeleton_scene/quests/dialogue/combatants
JSON); the one new sim surface is a small portal-menu module riding the
WIBounties `build_picker_graph` runtime-graph precedent + `transition()`
(teleport-class — structurally exempt from `trigger_radius`, the O2 rule).
Pisces's study-over-sleeps rides the existing talk-pool stage machinery
(opaque-until-sleep). Door art = `visual_states` + the light machinery.

**Design authority:** `docs/superpowers/specs/2026-07-06-portals-garden-design.md`
— §5 (RATIFIED earn conditions) SUPERSEDES §1's beat-3 fetch text (no sewers
item, no Erin gate; recovery run in a NEW dedicated ruin map + Krshia
catalyst).

## Global Constraints

- Player/public-facing name is **"the Magical Door"** — NEVER the Vol-9
  Skill name (spoiler cutoff, `docs/design/spoiler-cutoff.md`).
- The door prop NEVER speaks — the GDI voices its milestones
  (gold-on-black one-liners). Portal-menu options are the PLAYER's choices,
  not door dialogue.
- Opaque-until-sleep: Pisces's N-sleep study shows ZERO progress text —
  only his talk-pool lines shifting; awakening announces at a sleep beat.
- O2 rule: portal travel goes through `transition()` only; `move_player`'s
  `_check_trigger_radius`/door-arrival helpers are never called by it —
  the portal_menu canonical must assert no trigger fires on arrival.
- Stats never player-visible; HP/MP/gold/damage numbers allowed.
- New encounters: balance-harness cells per `wi-adding-an-encounter`
  (gated 0.55–0.95 win band unless adjudicated measured-only).
- Art: licensed Pixel Crawler extracts go through the overlay pipeline
  (manifest + ignore regen + private-bundle release FIRST — wi-shipping);
  committed placeholders keep the public tree green. PixelLab billing is generation-count, generations AVAILABLE
  (user-corrected 2026-07-07; the usd-balance probe was the wrong metric).
  v1 glow still ships via tint `visual_states` + a phase-gated PointLight2D
  (A1 verified zero new art needed); the rune-glow inpaint spec in
  docs/design/8a-asset-assembly.md MAY be generated at DF if wanted.
- Canon from the wiki; Albez flavor for the ruin (Warmage Thresk's door).

## Lane map (parallelism, file-ownership-disjoint)

- **Lane α (main-thread sequence): D1 → D3 → D4 → DF** (share
  `skeleton_scene.json` + Erin/Pisces dialogue files — serialized).
- **Lane β (parallel with D1): D2 combat data** — owns
  `data/combatants.json` + `data/arenas.json` + `tests/sim_combat_batch.gd`
  cells ONLY. Interface contract locked below (encounter/arena ids).
- **Lane γ (parallel with everything): A1 asset prep** — owns
  `docs/asset-*`, `wandering_inn_game/assets_manifest.json`,
  placeholder-fallback art files, private-bundle prep notes. Touches NO
  lane-α/β file.
- Registry appends (`qa/manifest.json`, CLAUDE.md seed table,
  QA-SCRIPT-NOTES) happen in lane α tasks only — β/γ never add canonicals.

---

### Task D1 — the ruin map family + beat-1 flicker surface

**Files:** Modify `data/skeleton_scene.json` (new map `ruin_surface`; new
`ruin_door` entity on `floodplains`' east edge; new `pantry_door` prop in
`inn` with `visual_states`), `data/moods.json` (ruin card: cold daylight,
dusty), `data/sprites.json` (placeholder-fallback regions for ruin tiles +
`pantry_door` states — lane γ upgrades later). New fixture
`qa/fixtures/near_ruin.json` + canonical `ruin_walkthrough` (registry
updates included). Follow `wi-adding-a-scene` (blocking/reachability) +
`wi-verifying-changes`.

**Interfaces (locked for other tasks):**
- Map id `ruin_surface` (sewers-sized, one map). Entry door id `ruin_door`
  (floodplains side) / `ruin_exit` (inside). Gate: `door_when
  {accomplishment: {door_chain_started: 1}}` (D3 banks it at beat 1 —
  before that the ruin door toasts locked flavor).
- Dormant encounter PLACEMENTS (entities with ids, no combat data):
  `rift_vermin_leak` (inn cellar-adjacent, beat-2 FIGHT trigger via
  interact, NOT trigger_radius) and `ruin_guardian` (ruin_surface, guards
  the anchor-stone pedestal). Combat DATA is Task D2's (lane β).
- Prop `anchor_stone_pedestal` (ruin): `contains: ["anchor_stone"]`,
  container gated `door_when`-style on the guardian encounter's clearing
  OR the TALK/SKILL routes' accomplishments (D3 wires the alternates; D1
  ships it FIGHT-gated with a `_comment` naming D3's amendment).
- Prop `pantry_door` (inn): `visual_states` keyed on accomplishments —
  `default`, `flicker` (active once `door_chain_started`), `awakened`
  (once `door_awakened`). Interact pre-awakening = flavor toast; D4
  rewires the awakened interact to the portal menu.
- Item `anchor_stone` (data/items.json, no combat mods, lore line
  Albez-true).

**Verification:** headless smoke + all 16 units + new `ruin_walkthrough`
(enter gated ruin via a fixture with `door_chain_started`, walk the map
bounds, read the pedestal-locked toast) + affected canonicals
(`inn_walkthrough`, `work_loop`, `gate_district_walkthrough`) + full sweep.
Windowed shots controller-read (ruin biome placeholder look, pantry_door
states via debug fixture).

**Danger:** the inn map is the most-walked map in the suite — enumerate the
pantry_door cell's blast radius against every inn-touching canonical BEFORE
placement (the DP1 Selys precedent). `ruin_door` on floodplains must not
sit on any shipped route (tutorial_flow's gate road!).

### Task D2 — combat data: rift vermin + ruin guardian (lane β, parallel with D1)

**Files:** Modify `data/combatants.json` (encounters `rift_vermin_leak`:
2-3 small vermin-class, reuses a vermin rig; `ruin_guardian`: one
mid-weight construct/undead-class guardian + escorts), `data/arenas.json`
(`inn_cellar` reuse or new `ruin_court` arena), extend
`tests/sim_combat_batch.gd` with cells for both (gated band 0.55–0.95 at
the expected player level ~L8-12 kit; guardian may be adjudicated
`win_lo/win_hi` like the deep_descent boss — justify in the cell comment).
NO skeleton_scene edits (placements are D1's).

**Interfaces:** encounter ids exactly `rift_vermin_leak` / `ruin_guardian`;
arena id `ruin_court`; `on_victory` accomplishments `cleared_the_leak` /
`cleared_ruin_guardian`.

**Verification:** test_combat_data + test_combat_sim + full harness run
(new cells in band, EXISTING cells byte-identical) + smoke. No canonical
additions (D3/D4 canonicals exercise the fights end-to-end).

**Danger:** canon-check both enemy concepts against the wiki (Rock
Crab-class fauna is HR-II's, don't collide; Albez guardian = construct-ish,
cite). Changing any SHARED combatant stat is out of charter — new entries
only.

### Task D3 — the chain, beats 1–3 (quests + dialogue + counters)

**Files:** Modify `data/quests.json` (quest `door_that_goes_elsewhere`,
staged complete_when on the counter chain), `data/dialogue/erin_errand.json`
(beat-1 flicker line — spec §3 Erin key, banks `door_chain_started`),
`data/dialogue/pisces_*.json` (mage-consult node chain: FIGHT sends to the
`rift_vermin_leak` interact, TALK = persuasion branch banking
`door_understood` directly, SKILL = [Appraise Foe]/observe-the-runes seam
banking via the field-skill first-use idiom), Krshia stall (catalyst item
`resonant_catalyst`, 35g, her charms counter — data/items.json +
`krshia_*.json` buy node), skeleton_scene amendments D1 reserved
(pedestal alternate gates; flicker visual_state trigger). New fixture +
canonical `door_chain_paths` (all three consult paths via three fixture
starts, the cisterns_fight/talk/scout precedent — OR three scripts if one
script can't hold parity cleanly; justify in `_comment`).

**Interfaces:** accomplishment chain (consumed by D4): `door_chain_started`
→ `door_understood` (any path) → `recovered_anchor_stone` (pedestal loot)
+ `bought_catalyst` (Krshia purchase) → D4's study counter starts at the
first sleep with ALL THREE banked.

**Verification:** test_quests + test_dialogue + test_content (validator
sweep) + the new canonical(s) + affected: `quest_errand_*`, `stages_loop`,
`economy_loop` (Krshia stall grew), `crate_*` (Pisces graph touched),
full sweep.

**Danger:** 3-path parity is an identity rule — every path must bank the
SAME `door_understood`. No em-dash overdraft in new copy (voice lint).
Krshia's 35g price is inside the ratified 30–40g band — do not tune
elsewhere.

### Task D4 — study, awakening, the portal menu + fast travel

**Files:** New `src/core/portals.gd` (`WIPortals`, pure sub-sim per the
ARCH-4 injection pattern: owns `attuned_destinations()` from an
accomplishment-keyed table in `data/portals.json`, `build_portal_graph()`
riding the WIBounties runtime-graph precedent), modify `src/core/wi_game.gd`
(inject WIPortals; sleep-beat hook: with the three beat-3 counters banked,
each sleep advances a hidden `door_study_sleeps` counter — at N=3,
`door_awakened` banks + the GDI line queues; pantry_door awakened interact
opens the portal graph; choosing a destination calls `transition()`),
`data/portals.json` (v1: Liscor destinations — `street` gate district +
the inn — the fast-travel pair; schema carries the anchor-stone-per-region
seam: each destination row = `{id, map, cell, requires_accomplishment}` so
#10/#12/#16 add rows, zero code), GDI copy (awakening one-liner per spec
§1 + the milestone surface's existing machinery), Pisces study-period
pool lines (2 lines shifting across the N sleeps — opaque). New canonicals
`door_awakening` (full chain, TALK path end-to-end incl. N sleeps) +
`portal_menu` (fast-travel round-trip: menu → street arrival →
`map_changed` pair pinned → NO `combat_started`/trigger events → return
trip). Registry updates.

**Interfaces:** consumes D3's counter chain verbatim. Produces the
`data/portals.json` destination schema (#10/#12/#16 contract) and
`WIPortals.build_portal_graph()`.

**Verification:** new unit `tests/test_portals.gd` (attunement table
gating, graph construction, study-counter arithmetic incl. the
counters-banked-mid-waking edge) + both canonicals + `upstairs_walkthrough`
/`inn_walkthrough`/`save_load_roundtrip` (sleep hook touched; save gains
`door_study_sleeps` additive field) + full sweep + windowed shots (awakened
door glow state, the portal menu panel).

**Danger:** the sleep beat is the most load-bearing seam in the sim
(progression resolves there) — the study hook must run AFTER progression's
resolution order, additive only. `transition()` arrival cells must be
walk-verified (the DP3 stairs blast-radius discipline). GDI line ≤ the
gold-on-black surface's fitted width.

### Task DF — milestone close

Whole-branch opus review (range = D1..D4 merged) + machine-playtest
rotation (wi-machine-playtest) + VISUAL-LOG drain (incl. the deferred
PixelLab rune-glow item if balance still $0) + HANDOFF playtest checklist
+ `gh issue close 8` in the landing commit + ledger.

### Task A1 — asset prep (lane γ, dispatch at t0, runs through the milestone)

**Files:** `docs/asset-catalog.md`/`asset-index.md` additions (ruin picks
from Pixel Crawler Castle/Cemetery/Cave packs; garden picks from Pixel
Crawler Garden Environment — #9 pre-work, its "obvious casting" per the
catalog), a NEW `docs/design/8a-asset-assembly.md` (region/scale/anchor
table for: ruin floor+wall tiles, pedestal, rubble scatter, pantry-door
awakened frame candidates, garden hedge/fountain/petals for #9),
`wandering_inn_game/assets_manifest.json` entries + ignore-block regen
prep for every licensed path (NOT the extracts themselves — bundle release
is a user gate, wi-shipping), committed PLACEHOLDER fallbacks where D1
needs paths to exist. NO skeleton_scene/dialogue/combat files.

**Verification:** `scripts/leak_check.sh` green; docs cross-reference the
catalog (never browse pack PNGs into context — PIL scans per
wi-art-and-sprites).

**Danger:** Cute_Fantasy_Free is NON-COMMERCIAL free-tier (catalog flag) —
do not source from it. PixelLab balance $0 — queue generation specs in the
assembly doc, generate nothing.

## Self-review notes

- Spec coverage: §1 beats 1-4 → D1/D3/D4; §2 art → D1 placeholders + A1 +
  VISUAL-LOG deferral (PixelLab $0); §3 dialogue keys → D3/D4 verbatim
  starting points; §4 QA → D4's two canonicals + D3's path canonical; §5
  ratification → D1 (dedicated ruin), D3 (ruin+Krshia only, no Erin gate),
  D4 (portals.json = the anchor-stone-per-region seam). Garden (§5) is
  issue #9, out of scope here by charter.
- Type/name consistency: accomplishment ids appear in exactly one spelling
  each (`door_chain_started`, `door_understood`, `recovered_anchor_stone`,
  `bought_catalyst`, `door_study_sleeps`, `door_awakened`,
  `cleared_the_leak`, `cleared_ruin_guardian`).
- No placeholder steps: every task names exact files, ids, and gates;
  content copy intentionally drafts at dispatch (voice work is the
  implementer's + reviewer's surface, staged keys quoted in the spec).
