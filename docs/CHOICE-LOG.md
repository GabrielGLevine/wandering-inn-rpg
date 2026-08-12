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

- **#432 — `next_fight` stacking:** repeatable food/cudgel props can produce,
  consume, then produce again; `_merge_pending_meal` sums their damage modifier
  without a cap. Current behavior stays unbounded because food already shipped
  that loop. The user must choose a cap/reset rule before the class is changed.
- **#19 — Steam commercial gate:** free-on-Steam is recommended. A paid path
  requires pirateaba's explicit permission before store or release work.

## Current product and system rulings

### Steel thread and item abilities (2026-08-11)

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
- **Cudgel production is currently unbounded-on-precedent.** Duplicate refusal
  only bounds what is carried; consuming re-arms production, and pending meal
  bonuses sum. #432 owns any systemic correction across cudgel and food props.
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
  item and re-arms the producer. #432 owns the class-level balance call.
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
