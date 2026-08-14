# Choice log

Durable controller/user rulings that still explain shipped behavior or constrain
open work. The standing 2026-07-18 directive permits controller judgment calls
when the user has not reserved the decision.

Insertion: head within the relevant section. Amend or supersede an existing
entry instead of appending a second story about the same choice. Keep the call,
the rejected alternative when it matters, and one sentence of rationale.
Implementation chronology, review findings, measurements, and verification
belong in issue-closing PR bodies.

The pre-condensation record remains recoverable with
`git show 1aee127d:docs/CHOICE-LOG.md`. Earlier context also lives in merged PR
bodies and `git log -p -- docs/CHOICE-LOG.md`.

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

- **Resonance semantics DEFERRED to after this tag; Hedault upgrades
  may hold or LOWER resonance (user, 2026-08-14).** The shipped fiction
  calls resonance interference ("before the pieces start arguing") while
  the shipped numbers scale it UP with power — canon says better gear
  interferes LESS, i.e. the inverse. Full ruling parked on #494 with the
  evidence; lanes write no resonance doctrine meanwhile, and fix
  domination defects as defects. Approved direction: a Hedault trueing
  keeping resonance flat or reducing it is the right upgrade axis — his
  craft buys room to wear more, which beats +1 HP.
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
  (user, 2026-08-13).** Binding design principle: NO build auto-wins —
  any build the Warden can never beat regardless of tuning is a red
  flag to surface, not tune around. Warden-side movement is hereby a
  sanctioned frozen-block exception (the #451 shape); the lane is
  measurement-led: capstone growth trims first, warden second, full
  re-window + #441-pattern re-fixture blast after (every act5 row +
  steel thread move), too-weak spines get composition/kit relief.
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
  named class ([Frostblade Warrior]/[Frostblade Knight] register), NOT
  reuse into the base target — base x base pairs (warrior x mage ->
  [Spellsword]) keep the base target. Controller produces the full
  wiki-verified name-mapping proposal on #485 for approval (post-bar
  candidates via the clearance flow). Also ruled: **swordsman renames
  to [Blademaster]** (display name; the shipped id stays frozen) —
  rename lane re-derives every prose/pin surface.

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
  Rides the combined class-authoring lane with [Wild Sage] +
  [Skirmisher] (both approved same day). SUPERSEDED MECHANISM NOTE
  (post-#482 narrowing): reuse mappings no longer get a maps_to
  annotation — a reuse pair goes live only when its coverage is
  AUTHORED (upgrades/inherits rows proving no Skill loss); the class
  lane reports the per-pair coverage tables for the naming batch.

- **Orphan consolidation mappings APPROVED as inventoried**; swordsman
  x mage (and its ice/fire siblings) map into [Spellsword] — target
  reuse with the warrior pairs explicitly accepted. Controller to
  propose 1-2 additional authored targets that reduce family reuse
  (answered on #438: beast_master x mage-line and spearmaster x
  archer-line, names wiki-verified at build).
- **KIT walls resolved by RULED MULTICLASSING (option c).** Civil
  spines are expected to carry a martial line to clear combat
  chokepoints; the viability table's civil-spine climax losses are
  design, not defects, and the civil pace overshoot (G6) is the
  multiclass level budget — no band-column, no re-slope. Instrument
  annotation follows.
- **Producer gaps G1-G5 APPROVED at recommended shapes**: G1 [Mage] L2
  requires_any {won_combat 3, spell_cast 4}; G2 scout Act I sneak-past
  ambush entry arm; G3 tactic ladder widened before it steepens
  (flanking_step L7->L6 + threshold trim per measurement); G4
  ranged_hit quest grants on the bow-shaped forks; G5 tended_beasts on
  the_price_kept's camp grant.
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
  allowed), (2) advancement paths for consolidated classes stay OPEN:
  a [Spellsword] (warrior x mage) can still level toward the warrior x
  ice_mage target by meeting ice_mage requirements — consolidated
  classes carry their parents' lineage credit for future
  consolidations. Design spec before implementation (Fable).

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
  (1) [Evil Eye] gains `field: true` + an occult ambient read (spec §2
  already repoints hollow_true_knot to it; combat-only was a data
  oversight; prints stay distinct from Tactician vocabulary). (2) Free
  scenery reads apply to ARMLESS props only; armed props (plate, cache,
  bed, doors) keep their interact action and retire their standalone
  flavor reads — except danger-bearing props, which the trap-perception
  family must cover. Rejected: a new free-inspection mechanism (scope
  creep). (3) Passive tactic-family Skills emit `tactic_used` at their
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
  [Spellsword]; it consolidates into its own class — [Spellspear] —
  spellsword-baselined consolidation skills, spear-flavored, lineage
  kit via inherits. This is #347's high-level-unique-class case
  realized on the existing static machinery; rejected alternatives:
  consolidation recipes accepting evolved parents into the SAME target
  (erases lineage identity), and evolution deferring while
  consolidation is in reach. Full implementable spec on #449.
  **WIKI VERIFY DISCHARGED (2026-08-13, before the id was cut):**
  no canon collision for [Spellspear] or the [Magic Spearmaster]
  fallback; the wiki's attested [Spellsword] ("Hybrid [Swordsman]/
  [Mage]") corroborates the split. [Spellspear] SHIPPED as the id.
- **The warden wakes for every descent; endings stay three-path
  (2026-08-12).** #437's measurements refuted the "warden stat wall"
  (competent-policy WIN 0.73 at the shipped build; 0.77 at band) — so
  #440 does zero stat work. The chokepoint ruling is satisfied
  structurally: the fight fires before `the_choice` resolves, all three
  shipped endings (open / fed / re-ward) become post-fight resolutions,
  and sneak holders get an in-fight edge, never a skip. Preserves the
  v0.14 three-path seal conclusion AND the chokepoint directive.
  Shipped mechanism: the alcove's `encounter_when` reads
  `read_the_feeding_ward` and its `on_victory` banks
  `seal_warden_downed`, which the choice row compounds onto its
  ward-fact gate. Two durable constraints fall out. (1) The seal door's
  `door_when` is deliberately NOT gated on the new counter: it would be
  inert behind the choice gate, and `seal_opened` is a frozen shipped id
  whose existing holders carry nothing to satisfy a second gate — the
  refusal a player meets is a `variants` rung, not a closed door. (2) A
  save holding any resolution counter without `seal_warden_downed` is
  unreachable and `test_fixture_coherence` now fails it, so the bypass
  cannot be reopened by a fixture edit.
- **QA proves completability; sims prove balance (user finding,
  2026-08-11).** Dumb-autoplay victory pins had become a balance
  ratchet: retunes that make a pinned fight autoplay-losable red CI, so
  fights stay winnable by the weakest policy and ship ~a tier easier
  than intended. Doctrine: pinned combat canonicals fixture at/over
  band so the dumb policy wins deterministically; encounter difficulty
  is tuned against #437's competent-policy-at-band column. Never tune
  an encounter to green an autoplay pin.
- **Combat chokepoints are sanctioned leveling gates (user ruling,
  2026-08-11 debrief).** Acts must require leveling progress: an
  unwinnable spine encounter is the intended signal to do side content
  (#439 per-act bands). The Seal Warden is the climactic chokepoint —
  its item bypass (worn [Invisibility] sneak-past) is a defect, not a
  feature; every player fights it (#440). This REFINES the three-pillars
  directive: pillars govern breadth of viable playstyles, not that every
  gate is bypassable. The worn-abilities systems mechanic itself stands;
  the finale's exposure to it goes. Sequenced: bands → warden retune →
  steel-thread Act V reauthored to fight at band.

- **The steel thread is continuous (user directive).** One PC, title to
  epilogue, true act order, zero `install_fixture`/`teleport` (grep-gated);
  rewritten in place — the stitched six-fixture album misrepresented act
  order and mixed four PC iterations. In-run controller calls: reward kept
  at Selys (spine purchases need coin), crate + cisterns by force, halls by
  Ksmvr's plates, the favor mediated, Coyle exposed, seal OPENED with the
  warden passed by cloak; night-watch wolves replaced by the track leg
  (night phase unschedulable on a portal route); teleport-only album legs
  (garden/barracks/runners-guild) dropped.
- **Worn-accessory abilities are known while worn (user ruling).** The
  measured wall behind it: the Seal Warden is unwinnable by the continuous
  build and none of the three non-fight forks was reachable, while Zevara's
  moon_bone_amulet grants [Invisibility] that `fold_abilities` confined to
  combat. `known_skills()` now folds equipped-accessory abilities; the
  field bar re-renders on equip/unequip; effect-text drops "in combat"
  exactly for field-capable abilities (invisibility, eagle_eyes). Rejected
  alternatives: warden retune (erases the intended wall), mage-grind route
  (8 hand-scripted nights), shipping the red finale.


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
- **Combat figure acceptance is measured from the animation actually rendered.**
  The audited bar is 1.25–3.55 cells; move subject data rather than relaxing the
  bar. `combat_scale` replaces field scale, and `combat_tint` is board-only.
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
- “Duplicate refusal bounds cudgel production” → **false**; use consumes the
  item and re-arms the producer. #432 made the balance call: production stays
  unbounded, the meal payoff caps at the strongest single meal.
- “Armed next-fight meal mods sum” → **false since #432**; `_merge_pending_meal`
  keeps the per-key maximum. The summing behaviour was #334 ruling 5's fix for
  wholesale replacement and outlived its purpose.
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
