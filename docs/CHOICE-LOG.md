# Choice log

Durable controller/user rulings that still explain shipped behavior or
constrain open work. The 2026-07-18 directive permits controller judgment
calls when the user has not reserved the decision.

Insertion: head within the relevant section. Amend or supersede an existing
entry instead of appending a second story about the same choice. Keep the call,
the rejected alternative when it matters, and one sentence of rationale.
Implementation chronology, review findings, measurements, and verification
belong in issue-closing PR bodies.

Pre-condensation record: `git show 1aee127d:docs/CHOICE-LOG.md`. Earlier
context lives in merged PR bodies and `git log -p -- docs/CHOICE-LOG.md`.

## Open decisions

- **#19 — Steam commercial gate:** free-on-Steam is recommended. A paid path
  requires pirateaba's explicit permission before store or release work.

- **[Blademaster]'s aspiration — naming ruling wanted (2026-08-14).**
  `data/classes.json` still points the class at "the title of
  [Swordmaster]", but the canon spike
  (`docs/superpowers/spike/wiki-warrior-line.md:91`) puts
  `[Blademaster]` ALONGSIDE `[Swordmaster]`, not beneath it — the text
  now aims a class at a peer. Keep it, promote to `[Sword Saint]`, or
  retire it. The ruled rename ships ahead of this.

## Current product and system rulings

### User rulings 2026-08-13 (#438 wave-close batch)

### User rulings 2026-08-14 (tag night)

- **wild_sage V 0.96 ACCEPTED, parked post-tag.** A step, not a slope:
  the counter reads 0.94 at mult 2.0 and 0.65 at 2.2, nothing between,
  because the window is whether one blow kills a 30-or-34-HP companion —
  and the setting that lands wild_sage puts **druid at 0.36, below the
  floor**. Shipped druid-in-window; wild_sage surfaced per NO-AUTO-WIN.
- **spellspear I/IV and skirmisher I/IV ACCEPTED as corrected
  measurement, parked post-tag.** NOT regressions: the gate ported only
  the `holdable_line` fix onto origin/main and reproduced 0.88/0.92 and
  0.88/0.89 exactly. The only lever (capping [Piercing Strikes] once
  per round) moves the ship column up to 0.12 — it re-authors
  steel-thread victory pins, so it needs its own budgeted lane.
- **The spine harness was measuring builds no player can hold.**
  `derived_stat_bonuses` sums `growth[stat] * held` with no table-floor
  check; Acts I-IV impose levels 2/3/5/7 while all 16 evolved classes
  floor at 10. Naming an evolved parent in `parent_lines` is the
  consolidation CONVENTION (spear-owns-its-hybrids, #449), not one
  commit's narrowing — so every future evolved-lineage target needs the
  holdable-line walk this adds. Whole of spellspear III.

### User rulings 2026-08-14 (post-wave decision batch, 11 calls)

- **M3.6 §6.3 tightening EXTENDS to compiled-only `wait_for_event`**
  (reclassifies 12 of 50; M4 unblocks on the remaining 38 exact + 9
  net). A compiled-only wait is strictly stricter and cannot hide — if
  it never fires the run fails, which `ITINERARY_RUN_GREEN` gates.
  Rejected: per-node emitter keys, which push corpus knowledge back
  into itineraries.
- **[Ranger]'s Warden wall gets a kit-gap lane** like skirmisher's.
  BINDING: must not push any other cell above 0.85.
- **`act2_cistern_nest` 0.40 ACCEPTED as an intended wall.** Reachable,
  but the cheapest reaching edit trades one wall for two ceiling
  breaches (act3→0.88, act1→0.96), and Acts I–IV measure PARENT lines —
  a mid-act wall before consolidation is correct.
- **The six WINDOW DRIFT cells are ONE lane** (spellspear III 0.92;
  wild_sage II/III/V 0.91/0.90/0.98; druid II/III 0.91/0.90) — one
  re-window covers the set; wild_sage V is the NO-AUTO-WIN case. Same
  lane repairs `beast_master14` 0.63→0.27 by **broadening growth to
  con 1 + str 1**; the flat-growth rule itself stands.
- **The Warden gains a COUNTER to companions**, not a companion nerf:
  the wolf is worth +0.79 there but is the spine's identity, and a boss
  that can threaten a companion generalises to every future one.
- **Book 17 = the WIKI's ebook index** (*Lady of Fire*, Vol 7 Pt 3),
  superseding this repo's *Garden of Sanctuary* (Vol 7 Pt 1) reading.
  LOOSENS the bar ~18 chapters, so nothing shipped needs re-auditing;
  the discrepancy note in `docs/design/spoiler-cutoff.md` retires.
- **"Runner's Sandals of the Second Wind" CLEARED** — [Second Wind]
  already ships as a grandfathered Skill, so the name introduces no new
  canon element.
- **[Blademaster]'s aspiration promotes to [Sword Saint]** (wiki-verify
  at build): canon groups [Blademaster] alongside [Swordmaster], so the
  old text aimed a class at a peer.
- **Over-levelled harness builds get FIXED, not relabelled** —
  t6/t12/s16 measure 17.8–24.7 effective power against a 14–16 band, so
  any "capstone too strong" reading of those rows is unsound.
- **Eye-gates ride a PREPARED SAVE** (Playtest-States): autoplay cannot
  cast, so the PC death-cast recolour needs a save the user loads.

- **Resonance semantics DEFERRED past this tag (user, 2026-08-14);
  evidence and the full question on #494.** The shipped fiction calls
  resonance interference while the shipped numbers scale it UP with
  power; canon implies the inverse. Lanes write NO resonance doctrine
  meanwhile and fix domination defects as defects. Approved direction:
  a Hedault trueing holding or LOWERING resonance is the right upgrade
  axis — his craft buys room to wear more.
- **Rename lanes change RENDERS of a class name, never common-noun
  prose that shares the word (controller call, 2026-08-14).** Pisces'
  "you hold yourself like a swordsman" survives the [Blademaster]
  rename: it is gated on conversation flags, not on holding the class,
  and means "someone who fights with a sword". "Blademaster" would
  assert mastery the line does not; anything else is unrequested new
  prose.
- **#485 name proposal: blanket GO, user edits stragglers later
  (2026-08-13 night).** All proposed first-order names proceed;
  wiki-verify at build still binds; post-bar hits still return for
  clearance; any user edit later supersedes the shipped display name
  (ids freeze at release cut only).
- **Equipment sketch GO (2026-08-13 night)** — the nine-item table in
  docs/superpowers/specs/2026-08-13-equipment-gaps-design.md
  implements under its balance rails.

- **Act V capstone trivialization: trim capstone stat growth AND/OR
  raise Warden difficulty, then re-balance builds that fall too weak
  (user, 2026-08-13).** Binding: **NO build auto-wins**, and any build
  the Warden can never beat regardless of tuning is a red flag to
  surface, not tune around. Warden-side movement is a sanctioned
  frozen-block exception; too-weak spines get composition/kit relief.
  SHIPPED #488 (every at-band climax row now in window).
- **Skirmisher walls are a kit/Skill gap (user, 2026-08-13).** Fill
  the kit: measure what the spearmaster x archer spine lacks at act2
  and act5, propose skill/kit additions (names via the clearance
  flow), implement to window.
- **#432 RULED: cap pending_meal stacking (user, 2026-08-13).**
  Repeatable produce/use props no longer stack next_fight meal
  modifiers; implementation default: strongest-single-meal cap,
  re-eating refreshes rather than stacks (controller detail, document
  in-data). The Open-decisions entry retires.

- **#485 naming: six kit decisions GO; evolved/elemental pairs earn
  DISTINCT names (user, 2026-08-13).** Coverage authoring for all six
  sets proceeds. Naming layer amended: a pair with real combined
  identity (e.g. swordsman x ice_mage) resolves to its OWN excitingly
  named class ([Frostblade Knight] register), NOT reuse into the base
  target — base x base pairs (warrior x mage → [Spellsword]) keep the
  base target. Name-mapping proposal lives on #485. Also ruled:
  **swordsman renames to [Blademaster]** (display only; id frozen) —
  SHIPPED #492.

- **Class AND Skill names past the spoiler bar are PROPOSABLE with
  user clearance (user, 2026-08-13, extended to Skills same day).** The
  wiki-verify flow gains a third outcome: a canon-attested name that
  sits past the Book-17 bar may be PROPOSED to the user and ships only
  on explicit clearance — no more silent auto-fallback when the best
  name is post-bar. Content spoilers are unchanged (the
  [Door of Portals]-class rule stands); this covers class and [Skill]
  NAMES only.

- **Necromancer becomes consolidation-eligible (user, 2026-08-13).**
  New family seeded warrior-line x necromancer: one authored base
  target covers warrior x necromancer and swordsman x necromancer
  (approved reuse pattern); spearmaster x necromancer follows the
  spear-owns-its-hybrids precedent (exempt pending naming unless
  authored in the same pass). Target name wiki-verifies at build.
  Post-#482: a reuse pair goes live only when its coverage is AUTHORED
  (upgrades/inherits rows proving no Skill loss), not via a `maps_to`
  annotation.

- **Orphan consolidation mappings APPROVED as inventoried**; swordsman
  x mage (and its ice/fire siblings) map into [Spellsword] — target
  reuse with the warrior pairs explicitly accepted. Two reuse-reducing
  targets added on #438: beast_master x mage-line, spearmaster x
  archer-line.
- **KIT walls resolved by RULED MULTICLASSING (option c).** Civil
  spines are expected to carry a martial line to clear combat
  chokepoints; their climax losses are design, not defects, and the
  civil pace overshoot (G6) is the multiclass level budget.
- **Producer gaps G1-G5 APPROVED at recommended shapes** (per-gap
  detail in #478's PR body). SHIPPED.
- **Ladder stop-order: RESTORE via hired_blades composition** (frozen
  stat blocks hold); ordering assert re-arms on the competent column
  once monotone.
- **Tactician-split Act V ceiling: fix without trivializing the
  climax** — measurement-led, composition/class-data levers only,
  STOP-and-report if the window is unreachable without policy or
  frozen-stat movement.
- **Equipment gaps: ADD missing gear across tracks (spear first)** via
  vendors, encounter loot, trap/puzzle/sealed-area treasure, quest
  rewards, and Hedault upgrades of existing gear — a content lane.
- **Coyle bounty completion suppresses alley-nest re-arming** (other
  respawners unchanged); cisterns/arc_flow headroom flags accepted as
  monitors; #448 with-Relc ruling number restated to the measured 0.78.
- **CONSOLIDATION IS AUTOMATIC (supersedes the #472 ruling request).**
  No player choice: consolidation fires when qualified, with two
  binding constraints — (1) it never removes existing Skills (upgrades
  allowed), (2) advancement paths stay OPEN: a [Spellsword] can still
  level toward the warrior × ice_mage target, i.e. consolidated classes
  carry their parents' lineage credit. SHIPPED #482.

### Sol wave ≥434 — controller calls under wave autonomy (2026-08-12)

- **Ladder ordering claims are demoted to report-only until re-ruled
  (2026-08-13).** Post-cap, the main-quest stop ladder is non-monotone
  under BOTH policies (floor 2/3 by 0.09; competent 1/2 by 0.01 past the
  tie band) — an ordering assert has no honest column to ride. The
  wiring pin (all rungs measured) stays hard. Reopening the claim means
  pulling a composition or stat lever on hired_blades (user batch).
- **Ruled balance bands CI-gate via RULED_WINDOWS (2026-08-13).** A
  user-ruled band (first case: the #448 veto solo at [0.35,0.45]) gates
  in the sim at 100 seeds both edges, and in calibration with measured
  per-row slack (RULED_SLACK, documented in-file) — never by widening
  the reference window and never by a 0.5 categorical that the defect
  shape would pass.

- **#450 spec contradictions ruled (three, all intent-preserving).**
  (1) [Evil Eye] gains `field: true` + an occult ambient read.
  (2) Free scenery reads apply to ARMLESS props only; armed props keep
  their interact action, except danger-bearing ones, which the
  trap-perception family must cover. Rejected: a new free-inspection
  mechanism. (3) Passive tactic-family Skills emit
  `tactic_used` at their
  proc site (weapon-family tally precedent); actives tally on use.
  Rejected: an ap_cost==0 activation engine change (blast radius =
  every passive becomes slottable).

- **#444 fix shape:** ship option 1 only (move Hedault's frontage door out of
  the [23,1] sign adjacency into the open facade band). Option 3 (bespoke
  enchanter sign) deferred to a VISUAL-LOG follow-up if the windowed read still
  misleads; option 2 (real Coyle door) rejected here — it belongs to the Coyle
  quest line, not a polish lane.
- **#451 scope:** once-per-round cap at L2 ships alone. [Improved Counter
  Strike] is NOT shipped this wave — the lane reports a martial-table
  recommendation and the reopen stays a controller/user adjudication.
- **#452 B1 exemption posture:** every inventoried orphan pair ships as
  `_exempt` pending the user's naming pass (spearmaster×mage exempt-annotated
  as resolved-by-#449); nothing is scaffolded into existence silently and main
  goes green immediately.
- **#475 was a shape test, not a design exclusion (2026-08-13).** The
  [Dangersense] overlay's `encounter_when` filter was a defect, not a rule — it
  hid the one Act I fight a player cannot walk around. Overlay parity is now by
  construction: the overlay reads the sim's predicate instead of keeping a
  second rule. `counting_room_guard` gains
  `encounter_when.requires{counting_room_open}` so no aura glows inside the
  #398 sealed pocket, rather than a new OR arm in the gate vocabulary.
- **#474 mothbear determination: placement clean (2026-08-13).**
  `road_mothbears` was never on water; the "on the pond" read was
  `goblin_night_patrol`, which stood inside the pond until this wave walked it
  ashore to (7,21). One entity, one defect.

### Steel thread and item abilities (2026-08-11)

- **#347 doctrine RATIFIED (user, 2026-08-12).** "Authored uniques,
  derived triggers" is standing policy, plus the combination rule:
  every consolidation-eligible lineage pair (evolved lines included)
  resolves to a unique authored target class. Enforcement machinery is
  #452; generative-at-runtime stays NO-BUILD per the spec's four fatal
  grounds.
- **Relc's veto branches to a hard solo fight, not a wall (user
  ruling, 2026-08-12, #448).** Target ~0.35-0.45 competent-at-band via
  a DIFFERENT solo composition — and explicitly must NOT trivialize
  the with-Relc fight (current 0.70 stands). The veto is a hard-mode
  choice, not a trap and not a free skip.
- **Evolved lineages consolidate into unique classes (user ruling,
  2026-08-12, #449).** Spearmaster + mage does NOT lineage-carry into
  [Spellsword]; it consolidates into its own class, [Spellspear] —
  #347's high-level-unique-class case on the existing machinery.
  Rejected: recipes accepting evolved parents into the SAME target
  (erases lineage identity), and evolution deferring while
  consolidation is in reach. SHIPPED.
- **The warden wakes for every descent; endings stay three-path
  (2026-08-12).** #437 refuted the "warden stat wall" (competent 0.73
  shipped, 0.77 at band), so #440 does zero stat work. Satisfied
  structurally: the fight fires before `the_choice` resolves, all three
  endings become post-fight resolutions, and sneak holders get an
  in-fight edge, never a skip.
  Two durable constraints (mechanism detail in #440's PR body): (1) the
  seal door's `door_when` is deliberately NOT gated on the new counter —
  it would be inert behind the choice gate, and `seal_opened` is a
  frozen shipped id; the refusal is a `variants` rung, not a closed
  door. (2) A save holding any resolution counter without
  `seal_warden_downed` is unreachable and `test_fixture_coherence`
  fails it, so the bypass cannot be reopened by a fixture edit.
- **QA proves completability; sims prove balance (user finding,
  2026-08-11).** Dumb-autoplay victory pins were a balance ratchet:
  fights stayed winnable by the weakest policy and shipped ~a tier easy.
  Doctrine: pinned combat canonicals fixture at/over band so the dumb
  policy wins deterministically; difficulty is tuned against the
  competent-policy-at-band column. **Never tune an encounter to green an
  autoplay pin.**
- **Combat chokepoints are sanctioned leveling gates (user ruling,
  2026-08-11 debrief).** Acts must require leveling progress: an
  unwinnable spine encounter is the intended signal to do side content
  (#439 bands). The Seal Warden is the climactic chokepoint and its
  item bypass is a defect; every player fights it (#440). REFINES the
  three-pillars
  directive: pillars govern breadth of viable playstyles, not that every
  gate is bypassable. The worn-abilities mechanic stands; the finale's
  exposure to it goes.

- **The steel thread is continuous (user directive).** One PC, title to
  epilogue, true act order, zero `install_fixture`/`teleport`
  (grep-gated); the stitched six-fixture album misrepresented act order
  and mixed four PC iterations. Its in-run route choices are recorded in
  `qa/STEEL-THREAD.md`.
- **Worn-accessory abilities are known while worn (user ruling).**
  `known_skills()` folds equipped-accessory abilities; the field bar
  re-renders on equip/unequip; effect-text drops "in combat" exactly for
  field-capable abilities. Rejected: warden retune (erases the intended
  wall), mage-grind route, shipping the red finale.


### Skills, classes, and field interactions

- **[Ice Floor] is one dual-context skill id.** Extend `icy_floor`; do not mint
  a second skill with the same display name. Its field behavior is data-driven
  through the property system.
- **Final martial allocation:** [Greater Strength] remains; [Power Strike] and
  [Piercing Strikes] are combat-only; [Basic Repair] moved to helper L2;
  [Basic Swordwork] owns the sword-required `cuts` field action. The separate
  `field_weapon` key gates field use without filtering combat passives.
- **[Dangersense]** is granted to rogue L4 (warrior L5 already existed) and is
  a passive-held field aura over existing encounter trigger regions.
- **[Pick Lock]** is an active rogue L2 skill. Its debut is Hedault's locked
  work room: a legitimate non-skill trust route reaches identical contents.
  Only literal locks qualify; bars, tripwires, and wedged crates do not. The
  `icon_open_doors` reuse is interim and remains visual debt.
- **[Rope Arrow]** is the final, user-approved display name; the stable id stays
  `rope_work`. This supersedes the invented [Rope Work] name.
- **[Firefly]/`kindle`** is granted by hedge_witch L2. **[Snap Freeze]/
  `frost_touch`** is granted by hedge_witch L4. The earlier Eloise dialogue-
  grant proposal is void because dialogue has no skill-grant verb.
- **[Flame Jet] has field `burns`.** This later #398 ruling supersedes the
  v0.19 planning call that would have kept corpse cooking as its only field
  effect.
- **[Durable Picks] remains deferred** until a granting labour-line class
  exists; classless skill rows are dead content.
- **Field gates have two honest modes.** A gated pocket needs a skill route and
  a legitimate alternative, with equivalent payoff where the user directed it.
  Negative QA legs walk into the gate and assert refusal; they do not teleport.
- **Property effects stay declarative.** `cell_properties` replaced the narrow
  freeze flag; shipped verbs started with `state_set`/`thaw_cell` and widened
  deliberately. Target counters can override the default, and one skill use
  may bank multiple accomplishments.

### Items, rewards, and economy

- **Hedault's 40g bead option grants `hedaults_wardstone`.** The lesser
  `hedaults_warded_setting` remains the fragment-commission product; this
  restores the intended base-to-upgrade chain.
- **`improvised_cudgel`** is yielded by using [Bar Fighting] on taproom
  furniture. **`solid_oak_spear`** is stocked in the barracks spare-kit crate.
- **Meal buffs cap at the strongest single meal (#432).** `_merge_pending_meal`
  keeps the MAXIMUM per key, never a sum: a stronger meal replaces that key, an
  equal-or-weaker one refreshes it. The cap is per key, so #334 ruling 5 (pay
  twice, get both) still holds for different keys. Cudgel and food-prop
  production stays unbounded-on-precedent — duplicate refusal bounds only what
  is carried, and consuming re-arms the producer — but the loop is now a
  walk-cost rather than a damage curve.
- **Serve remains cooking-gated.** Requirements use item `source_hint` text to
  tell a blocked player where the needed meal comes from; combat builds are not
  entitled to bypass the cooking pillar.
- **Regional odd jobs use once-per-waking props, not bounty/delivery systems.**
  Base pay is flat; the accepted ceiling is 12g per waking for a marker-holding
  helper with [Perfect Hospitality].
- **Quest rewards describe the route actually taken.** Single-ending quests
  use resolution fallbacks; OR-gated beats use `complete_when_any`; force and
  disarm routes carry distinct accomplishments rather than sharing a false
  fallback.

### World, content, and narrative

- **Three Pillars is a standing content gate:** meaningful talk/help/fight
  routes must all remain real. It is a review criterion, not a future feature.
- **Riverfarm was redesigned rather than reskinned (#396).** `a_winter_of_teeth`
  replaces `what_the_thicket_keeps` for new saves; legacy completion remains;
  briar fights are solo-gated; `the_makings` wraps the [Hedge Witch] grant.
- **The Invrisil mothbear encounter belongs on the floodplains road verge.** It
  remains an original wilderness placement, not a fabricated canon citation.
- **Horns presence reconciliation defers until dialogue ends.** This prevents
  actors popping out while their conversation is open; same-map
  `present_when` changes are safe and reconcile on accomplishment. The old
  claim that same-map presence was unsafe is withdrawn.
- **Inn visitors (#371) will schedule one canonical party at a time.** This is
  queued v0.20 work; do not revive the earlier always-present crowd shape.
- **Unique-Class creation (#347) remains behind its designed migration/feature
  gate.** Do not expose prototype naming as shipped behavior, and do not use
  “Five Families” in player copy under the spoiler cutoff.
- **Dead content must be honest while queued.** Remove hints that advertise an
  unobtainable skill, but keep truthful data/use copy when a grant path is
  planned. Orphan detectors promote to hard-fail category-by-category once the
  shipped set is clean.

### Prose and dialogue

- **Discovery beats instruction.** Field-gate prose should describe physical
  capability, not tell the player to select a named menu skill. Receipt toasts
  may state what the used Skill did.
- **Zero-inference scenery is the default for map-register prose.** Preserve
  character-bearing peaks, quoted documents, and facts; do not invent motives,
  quantities, ownership, or outcomes from decorative objects.
- **Uniform plainness is also a machine signature.** The #397 round-two pass
  removed button closers, then rebalanced sentence cadence before the blind
  read. Its revised corpus passed the purpose test even though readers detected
  a withheld-agent pattern that lived in control rows.
- **#406 is one follow-up pass:** draw a fresh holdout, release the held rows,
  drain the named residue/“Nothing there.” family, and address missing
  interruption/silence shapes together. Do not split off a separate
  ending-variety rewrite.
- **Conversation hubs are append-sensitive.** Add hidden options last unless a
  lane explicitly re-derives every index-based QA path. Reactive copy uses the
  least invasive existing mechanism (`text_variants`, pool stages, or twin
  presence rows) that preserves first-interact behavior.

### Simulation, reachability, and QA

- **`qa/manifest.json` is the canonical script/seed inventory.** Generated QA
  notes and the sweep derive from it; prose docs must not duplicate the table.
- **Reachability uses two authorities:** data lint owns grant/item/dialogue/door
  graph reachability; GDScript tests over the real loader own cell adjacency and
  walkability. A Python mirror must not redefine sim truth.
- **A declared resource is not a wire.** Grant-path checks require a real
  producer and cell checks require a reachable interaction surface. Categories
  become blocking only after existing orphans are drained or explicitly
  allowlisted.
- **Difficulty x1.0 is inert.** Tier sweeps must preserve monotonic direction;
  named extreme-flip exceptions are allowed only with written justification.
  `weapon_die`, not constitution, was the accepted rung-4 tuning lever.
- **Time of day is a loop, not a progress meter.** The indoor cue is a compact
  day/dusk/night glyph; no action count or fill bar implies progress toward a
  deadline.
- **Presence gates distinguish structure from activation.** `present_when`
  controls existence; `encounter_when` controls trigger/interact eligibility.
  Tests must walk the real cell and assert both blocking and non-trigger states.
- **Verification reads Godot output, not exit code alone.** Unit scripts require
  `PASS` and reject `SCRIPT ERROR`, `Parse Error`, or `WARNING`; a green process
  code can still contain a failed assertion.

### Presentation and art

- **Tint is not identity.** Distinct adjacent/named subjects need distinct
  silhouettes. Anonymous extras may share a rig when separated; named
  characters should not share another named character's rig.
- **`pc_*` sprites are player-only.** A registry test rejects map entities or
  decor using player skins.
- **Combat figure acceptance is measured from the animation actually rendered**
  (bar 1.25–3.55 cells; move subject data rather than relax it).
- **Blocked board cells use biome prop data before renderer fallbacks.** A cell
  that affects pathing is gameplay geometry, not dim background dressing.
- **Named payoff moments need visible lanes.** Event emission alone does not
  prove a toast, class evolution, hint, or sprite reached pixels. Windowed eyes
  arbitrate player-facing claims.
- **Pause scrim:** one full-rect black `ColorRect`, alpha 0.55,
  `MOUSE_FILTER_STOP`, unless a windowed read justifies a small opacity change.

## Superseded calls — do not resurrect

- `[Rope Work]` → **[Rope Arrow]**; id remains `rope_work`.
- `frost_touch` via Eloise dialogue → **hedge_witch L4**; no dialogue grant
  mechanism exists.
- [Flame Jet] without `burns` → **field `burns` enabled** in #398.
- “Same-map `present_when` is unsafe” → **false**; accomplishment reconciliation
  and dialogue-end deferral make it safe.
- “Duplicate refusal bounds cudgel production” and “armed next-fight meal
  mods sum” → **both false since #432**; production stays unbounded and
  `_merge_pending_meal` keeps the per-key maximum. The summing was #334
  ruling 5's fix for wholesale replacement and outlived its purpose.
- “Passing event assertions proves a visible feature” → **false**; windowed
  rendering is required for player-visible claims.
- #397 round-one “engineering green means prose exit met” → **false**; blind
  readers failed it. Round two passed after map-register re-authorship and
  cadence correction; #406 carries the explicit-instruction/holdout residue.

## Historical release index

This section is intentionally terse. Follow the cited issue/PR or the archived
pre-condensation file for alternatives, review chronology, and measurements.

- **v0.19 / #398, #400, #403, #404, #412–#414, #417, #421, #423, #424,
  #429:** field-skill pockets, martial re-scope, [Dangersense], [Pick Lock],
  [Rope Arrow], canonical steel-thread QA, reachability enforcement, and orphan
  drain. Current rulings are folded above.
- **#397 prose naturalization:** round one failed blind reading despite green
  engineering gates. User approved map-register-only round two under the
  discovery/zero-inference rules; the final blind read passed. #406 owns the
  fresh-control holdout release.
- **v0.18 / #347, #348, #359, #360:** data-composed property verbs, gated
  dynamic-Class prototype, looping phase clock, and tier-sweep instrumentation.
  The property table enters through `WISceneCatalog.compose()` rather than a new
  game-core registry.
- **v0.17:** feedback/atmosphere, settings/difficulty, cooldowns, voice pass,
  four-member Horns continuity, and the first dynamic-Class/property designs.
  Atmosphere ownership stayed data/UI-side; image assets joined the import
  purity rule.
- **v0.16–v0.16.2:** region-depth quests, friend-playtest fixes, named-character
  sprite cleanup, and the Coyle sign. Pallass interiors use globally unique map
  stems; forge encounters are interact-only; quest-local counters do not feed
  unrelated bounties. The mothbear moved outside Invrisil.
- **v0.15:** delivery/leads/lore UI, endings, guest windows, regional
  population, and measured board legibility. Dialogue-open presence deferral,
  route-honest quest resolutions, biome-backed blocked props, and the combat
  figure bar became standing contracts.
- **v0.14:** Acts I–V main quest, pilgrimage spine, three-path seal conclusion,
  finale, roster expansion, and difficulty ladder. Shipped ids froze at release
  and later migrations preserve them.
- **v0.13:** rename/save carry-over, journal tabs, Floors of the Inn pilot,
  interiors, art, and honest canonicals. Public naming changes require explicit
  save migration rather than silent key replacement.
- **v0.12:** god-file dissections, challenge-weighted leveling, content/UX waves,
  and mobile hotfixes. Rank-aware fixture expansion was declined when the
  existing contract already represented the intended state.
- **v0.10–v0.11:** economy, rank-tiered bounties, Second Wind, Hedault
  enchanting, early class waves, music intake, and release automation. The
  public demo/release path is verified independently from local green tests.
