# Skill-Gated Areas: the Two-Mode Rule (design spec)

Status: DESIGN SPEC (user directive 2026-08-05). No code ships from this
doc; it feeds an implementation issue. Authored on branch
`spec/skill-gated-areas` to stay clear of the active 390/396/397 session
on main. Wave-autonomy rulings are logged in §9 of this doc (CHOICE-LOG
and HANDOFF are owned by the running main session; the close that merges
this spec should copy §9 into CHOICE-LOG).

## 1. Directive

> There should be areas of the map that are only accessible by
> leveraging different skills. Areas walled off by briars that you have
> to use Flame Jet or another fire spell to burn your way through or a
> martial skill to hack apart, islands surrounded by water that you have
> to freeze the water around to access or [Flash Step] across, secret
> rooms with locked or trapped entrances that require a Rogue skill to
> unlock or Warrior skill to beat down. Ideally each area should have at
> least two different modes of access. They can gate higher level
> encounters, special loot, higher level quests, etc.

Two claims in there, and they are separable:
1. **Content**: pockets of map gated behind skill use, paying out in
   higher-band encounters, loot, and quests.
2. **A design rule**: every pocket has **at least two access modes** —
   so no build is locked out of the world, but the *route in* expresses
   the build.

## 2. What already exists (this is NOT greenfield)

The verbs are almost all shipped and QA-proven. The gap is level design:
the whole game currently has **three** traversal gates (two sewers freeze
cells, one floodplains pond-edge cell, plus the burnable sewer_debris),
each single-mode, each a shortcut rather than a gated pocket.

Substrate inventory (file:line as of `0673e43c`):

| Mechanism | State | Where |
|---|---|---|
| Property table (skill flag × target tag → outcome) | SHIPPED (#348 slice 1-2) | `data/interactions.json`; dispatch `src/core/field_skills.gd:113-209`; contracts `tests/test_interactions_table.gd`, `tests/test_traversal_seams.gd` |
| freezes × freezable → walkable ice (until sleep) | SHIPPED | [Snap Freeze] `frost_touch`, [Ice Floor] `icy_floor`; ALL water freezable by user ruling (loader derives from `water: true`) |
| burns × burnable → remove prop, clear cell (permanent) | SHIPPED | [Firefly] `kindle`; `_outcome_remove_scorch` field_skills.gd:300-313 |
| Blink over blocked cells | SHIPPED | [Flash Step] range 4 (Mage L11/Necromancer L7), [Double Step] range 2 (Runner L5); banks `blinked_past_danger` |
| Force barred door / shift boulder | SHIPPED (#380) | [Greater Strength] authored arm + `_door_openable` wi_game.gd:720-726 |
| Break rubble with pick in pack | SHIPPED (#380) | [Durable Picks]: `requires_item` without `remove_item` (wi_game.gd:621-640) |
| Find/disarm traps | SHIPPED | [Find Trap] L3 / [Disarm Trap] L5 (Rogue); 6 `requires_skill: disarm_trap` arms across maps |
| Sneak/observe gating | SHIPPED | `sneak`, `observe` arms (mercantile_alleys, sewers) |
| Reward gating | SHIPPED | `present_when` / `encounter_when` (wi_game.gd:1064-1131) |
| Cross ice as a martial | SHIPPED (#380) | [Even Footing] passive |

What does NOT exist:
- A martial **cut-through-vegetation** verb (fire has `burns`; blades
  have nothing in field context).
- Any **two-mode** gate. Nothing enforces or even records that a pocket
  has alternate routes.
- A **lockpick** skill (Rogue's field kit is traps + stealth only).
- Pockets as *destinations* (encounter + loot + quest hook behind the
  gate) rather than shortcuts.

## 3. Design: the Two-Mode Rule

**Rule: every gated pocket ships with ≥2 access modes whose granting
class sets are not identical** — at least two different builds can each
get in using their own kit. Modes may differ in cost, noise, and
side-effects (a forced door can bank a `noisy_entry` counter that
dialogue reacts to; a blink banks `blinked_past_danger`).

Mode taxonomy (all resolve through existing seams):

- **M-PROP** — property-table row: any skill carrying the flag works
  (`burns` × `burnable`, `freezes` × water, new `cuts` × `cuttable`).
- **M-BLINK** — geometry: a ≤blink-range crossing with walkable landing
  and LoS. Costs nothing but the class.
- **M-ARM** — authored `requires_skill`/`requires_item` arm on a prop
  (greater_strength forces the bar, durable_picks breaks the seam,
  disarm_trap clears the snare). Carries bespoke toasts/yields.
- **M-SOCIAL** — a dialogue path opens the way (option gated on class/
  skill/counter flips a `present_when` blocker off). Three-pillars
  mandate: at least one wave-1 pocket must carry a social mode.
- **M-ENDURE** — spring the trap and eat it: authored `endure_damage: N`
  on a trap prop lets any build pay HP to pass (refused at HP ≤ N — no
  traversal deaths). The one genuinely new arm (§5 D4, optional).

**Explicit-cast doctrine holds** (CHOICE-LOG 2026-07-10): no mode
auto-fires. Walking at a briar wall with [Firefly] known does nothing;
you select the skill on the hotbar and cast at the faced cell/prop.
Refusal/hint toasts (`locked_toast`, `skill_hint_toast`) do the teaching.

### The gate registry (makes the rule machine-checkable)

New optional map-level block:

```json
"skill_gates": {
  "pond_island": {
    "modes": [
      {"mechanism": "property", "skill_property": "freezes", "cells": [[10,17]]},
      {"mechanism": "blink", "min_range": 2, "from": [9,16], "to": [11,16]}
    ],
    "rewards": ["pond_cache", "pond_guardian"]
  }
}
```

`data_lint` arms (all HARD except the last):
1. Every gate has ≥2 modes with **distinct mechanisms or distinct skill
   properties**.
2. The union of classes granting mode-1's skills ≠ union for mode-2's
   (derived from skills.json/classes.json — this is the "different
   builds" check; blink modes count their blink-skill granters).
3. Mode carriers exist: cells are real map cells, prop ids resolve,
   `min_range` ≤ max shipped blink range with LoS-plausible geometry
   (structural only — QA proves the actual crossing).
4. `rewards` resolve to entities on the same map whose
   `present_when`/`encounter_when`/position sits behind the gate.
5. ADVISORY: a map with a `freezable`-adjacent island or a `burnable`
   blocking line but no `skill_gates` entry flags — catches future maps
   drifting back to single-mode.

Registry is *descriptive*, not executive: the engine never reads it.
Gates keep working exactly as their carriers (props/cells/arms) already
do; the registry exists for lint + QA-surface derivation. Zero runtime
blast radius.

## 4. Wave-1 placement matrix

One pocket per region, sized to the region's level band. Encounters get
statted at implementation time under `wi-adding-an-encounter` (+
sim_combat_batch cells); this matrix fixes geometry, modes, rewards.

| # | Map | Pocket | Modes | Reward |
|---|---|---|---|---|
| P1 | floodplains | **The pond island** — real island (3-4 cells) in the existing pond, extending the shipped (10,17) freeze beat | M-PROP freezes (Snap Freeze/Ice Floor + Even Footing pairing) · M-BLINK (Double Step r2 across the narrows; Flash Step trivially) | cache prop (unique item) + `pond_guardian` encounter ~+2 band + journal hook |
| P2 | sewers/deep_tunnels | **The collapsed gallery** — rubble line sealing a side gallery | M-ARM Durable Picks (pick in pack) · M-ARM Greater Strength (shift the fallen beam, distinct prop) · M-PROP burns (tarred shoring timber) | nest encounter above region band + strongbox; banks differ per mode (`broke_through` vs `burned_through`) |
| P3 | dungeon/trapped_halls | **The warded side vault** — snare-trapped entrance, inner cache | M-ARM Find Trap→Disarm Trap · M-ARM Greater Strength (pry the mechanism, springs it harmlessly, noisy) · M-ENDURE (eat `endure_damage`, if D4 ships) | vault loot (special item) + higher-band construct encounter |
| P4 | invrisil/mercantile_alleys | **The counting-room** — locked factor's room off the alleys | M-SOCIAL (dialogue: a Trader/Diplomat-gated option gets you invited in) · M-ARM sneak/observe timing (the existing alley idiom) · M-ARM Greater Strength barred rear door (banks `noisy_entry`, factor dialogue reacts) | trade-goods loot + quest hook (fence thread) |
| P5 | ruin_surface | **The briar-choked arch** — briar wall line (blocking props) across a collapsed arch | M-PROP burns (Firefly/any fire-flagged) · M-PROP cuts (NEW — §5 D1, martial bladed actives) | ruin pocket: ~+3 band encounter + quest hook toward the dungeon thread |
| P6 | riverfarm | **DEFERRED** — witch_hollow/riverfarm pockets wave-2, AFTER #396 merges (its lanes own those maps; briar combatants are 396 Lane B property) | — | — |

Fire-mode note: `burns` rows answer ANY skill carrying the flag — wave-1
gives [Flame Jet] `burns: true` alongside [Firefly] so the directive's
"Flame Jet or another fire spell" is literally true (one data field +
canonical extension; #383's Flame-Jet-corpse package is untouched).

## 5. Engine deltas (small, all in existing seams)

- **D1 — `cuts` skill property** (the only new vocabulary): field-tag
  the two weapon-gated martial actives ([Power Strike] sword,
  [Piercing Strikes] spear) with `cuts: true` + `field: true`; rows
  `cuts × cuttable → remove` reusing the `remove_scorch` outcome shape
  (row-parameterized terrain "cleared" + own toast/counter — add a
  sibling verb ONLY if the toast/counter semantics genuinely diverge;
  K2 guards this). Briar props carry `cuttable: true` + `burnable: true`.
  Canon: both skills shipped/attested; no new names, no ACK needed.
- **D2 — briar wall carrier**: blocking prop kind reusing the shipped
  burnable-prop shape; needs a distinct briar-wall sprite (silhouette
  rule: tint-is-not-disambiguation, 2026-08-02) — one PixelLab prop or
  pack tile, art lane.
- **D3 — blink-over-water proof**: likely zero-code (water blocks walk,
  not LoS); a canonical leg pins Double Step crossing the P1 narrows.
  If LoS code disagrees, that finding goes back to this spec before any
  engine edit.
- **D4 — M-ENDURE arm (OPTIONAL, cut first)**: `endure_damage: N` on
  trap props; interact offers "push through" costing N HP, refused at
  HP ≤ N. P3 has two modes without it; ship D4 only if it survives
  review as a one-arm diff in the interact path.
- **D5 — `skill_gates` registry + lint arms** (§3): data_lint only,
  engine never reads it.
- **NOT built** (ruled out, §8): lockpicking skill (wave-2,
  canon-check), `requires_skill` any-of arrays (mode taxonomy makes
  them unnecessary — YAGNI), key/lock tiers, reversible gate state
  (K3 state-creep fence: cleared stays cleared, frozen thaws at sleep —
  both idioms already shipped).

## 6. Rewards discipline

- Encounters: +2-4 above region band, statted via sim_combat_batch
  cells like any combatant (`wi-adding-an-encounter`); pockets are the
  sanctioned home for above-band fights since the player self-selected
  by unlocking the route.
- Loot: unique/special items (`data/items.json`), `present_when`-gated
  props; no gold-only caches (economy ledger debt, #65).
- Quests: each pocket carries at least a hook (observe line or journal
  entry); P4's fence thread and P5's dungeon pointer are the wave-1
  quest payloads. Full new quests ride wave-2 once #396's quest lanes
  clear quests.json.
- Every mode banks a distinct counter where flavor allows — the
  `blinked_past_danger` precedent; sleep-growth can react later.

## 7. QA plan (the gate for every pocket)

Per pocket, one canonical extension (or new script where a region has
none touching the pocket):
1. **Mode-A leg**: cast/use → gate opens → reach reward cell → assert
   reward entity interactable + counter banked.
2. **Mode-B leg** (separate fixture with the other build's kit): same
   destination through the other mode.
3. **Negative leg**: no qualifying kit → gate refuses (locked/hint
   toast asserted), reward cell unreachable, reward entity absent or
   un-interactable.

Plus: data_lint arms (§3) self-tested per data_lint convention;
`derive_qa_surfaces.py` regen; `ci_sweep.sh --touching` per edited map;
full sweep at close; windowed machine-playtest reads of each new
player-visible surface (briar wall, island, vault) per
wi-machine-playtest; existing traversal canonicals byte-identical where
untouched (K1).

## 8. Approaches considered

- **A — authored arms only** (no registry, no new property): cheapest;
  but the two-mode rule lives in nobody's head after this session, the
  fifth gate ships single-mode, and fire-mode stays [Firefly]-only.
  Rejected: the *rule* is the directive's core, and unenforced rules on
  this project have a documented drift record.
- **B — property-layer extension + descriptive registry + lint
  (CHOSEN)**: one new skill property (`cuts`), one optional arm (D4),
  everything else data + content; the rule becomes a data_lint arm.
  Matches #348's build-reduced trajectory and its kill criteria.
- **C — lock-and-key engine** (lock tiers, skill checks, keys): builds
  state and vocabulary no wave-1 pocket needs; #348-K3 territory.
  Rejected as over-build; if wave-2's lockpick work wants a tier, it
  writes its own spec.

## 9. Rulings (wave-autonomy; copy into CHOICE-LOG at merge)

1. **Two-mode rule is lint-enforced** via a descriptive `skill_gates`
   registry (§3) — engine never reads it; structural checks in
   data_lint, reachability proven by QA legs.
2. **Riverfarm/witch_hollow pockets deferred to wave-2** behind the
   #396 merge (its lanes own those maps; briar combatants are 396
   Lane B property). No exceptions during implementation.
3. **No lockpick skill in wave-1.** Rogue's wave-1 expression is
   traps + stealth + timing (P3, P4). A lockpick skill needs a
   wiki-attested name (Rope-Work precedent: invented names want an
   ACK) — filed as a wave-2 canon-check item in the issue.
4. **[Flame Jet] gains `burns: true`** so fire-mode reads "any fire
   spell", per the directive's own wording. One data field; #383's
   corpse package unaffected.
5. **D4 (M-ENDURE) is optional and cut first** if scope presses; P3
   retains two modes without it.
6. **Spec lives on `spec/skill-gated-areas`**, not main — the running
   390/396/397 session owns main's HANDOFF/CHOICE-LOG; this doc carries
   its own rulings block until merge.

## 10. Kill criteria

- **K1 (byte-identity)**: untouched traversal canonicals must stay
  byte-identical through D1/D5; drift = stop, re-scope.
- **K2 (verb creep)**: any pocket demanding >1 genuinely new outcome
  verb → that pocket is redesigned to shipped verbs, not the engine
  extended.
- **K3 (state creep)**: any mode wanting reversible or new save state
  beyond the shipped permanent-removal/until-sleep idioms → mode is cut
  (per #348-K3).
- **K4 (lint allowlist)**: if the two-mode class-disjointness arm needs
  an allowlist to pass wave-1 content, the placement matrix is wrong —
  fix the content, never waive.
- **K5 (discovery)**: if machine-playtest + the next human sitting
  never finds a second mode unprompted, the teaching (hint toasts) is
  failing — presentation seam goes to #335, content investment pauses
  after wave-1.
