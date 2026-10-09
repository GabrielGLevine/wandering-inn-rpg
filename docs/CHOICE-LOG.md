# Choice log

Durable user/controller rulings for shipped and open work, grouped by domain.
The 2026-07-18 user directive permits controller judgment on unreserved
decisions.

Insertion: head within the relevant section. Amend existing entries; preserve
the call, significant rejected alternative and reason. Evidence, measurements
and chronology belong in issue PRs. Earlier context:
`git show 1aee127d:docs/CHOICE-LOG.md`, merged PRs and
`git log -p -- docs/CHOICE-LOG.md` (compacted 2026-10-07).

## Open decisions

- **#19 Steam commercial gate:** free-on-Steam is recommended. A paid path
  requires pirateaba's explicit permission before store or release work.
- **#452/#347:** doctrine-spec ratification and dynamic unique classes keep
  their user gates; #347 is deferred.
- **#584:** music adds and the swish-on-miss change need an explicit ear
  verdict; new footsteps, beds and foley are ear-checked in place.

## Current product and system rulings

### Balance and encounter doctrine

- **No build auto-wins; QA proves completability, sims prove balance.**
  Dumb-autoplay victory pins were a ratchet that shipped fights a tier easy.
  Tune against the competent-policy-at-band column; pinned combat canonicals
  use fixtures at or over band so the weakest policy wins deterministically.
  **Never tune an encounter to green an autoplay pin.** A build no tuning can
  make win is a red flag to surface, not to tune around.
- **Combat chokepoints are sanctioned leveling gates.** Acts must require
  leveling; an unwinnable spine fight is the signal to do side content. Civil
  spines are expected to multiclass into a martial line for climax fights
  (ruled option c); their climax losses are design, and the civil pace
  overshoot (G6) is the multiclass level budget.
- **Ruled bands gate in CI via `RULED_WINDOWS`** at 100 seeds on both edges,
  with documented per-row `RULED_SLACK`. Never widen a reference window or use
  a 0.5 categorical the defect shape would pass.
- **Hurt entry (#453, 2026-10-07/08):** chokepoints collapse when entered
  depleted. Keep balance as is. Signposting is environmental and implicit,
  never a triggered toast or hint: a Watch bunk in Liscor's barracks once the
  Watch sends you below, recovery loot (a sewer meal +6 HP, a Gnoll satchel
  draught +8 HP past the Raskghar scouts), bedrolls at the dungeon approach and
  the ruin, and a visual cue on the gate road; the existing autosaves supply the
  checkpoints (`docs/design/453-rest-signposting.md`). Rejected: retuning for
  hurt entry (moves ruled windows) and toast hints at an HP threshold.
- **The main-quest stop ladder is gated on the competent column**, restored by
  `hired_blades` composition with frozen stat blocks. The wiring pin (all
  rungs measured) is hard on every leg.
- **Spine builds must be holdable.** `derived_stat_bonuses` has no table-floor
  check, and Acts I–IV levels 2/3/5/7 precede evolved floors of 10. Evolved
  parents in `parent_lines` follow #449's spear-owned convention; future
  evolved-lineage targets need the holdable-line walk, including all of
  spellspear III. Over-levelled harness builds are fixed, not relabelled.
- **[Ranger]'s Warden wall gets a kit-gap lane;** binding: it must not push any
  other cell above 0.85. **Skirmisher walls are a kit/Skill gap:** measure what
  the spearmaster x archer spine lacks at act2 and act5, propose additions
  (names via the clearance flow), implement to window.
- **`act2_cistern_nest` 0.40 is an accepted mid-act wall.** Rejected: the
  cheapest reaching edit trades one wall for two ceiling breaches, and Acts
  I–IV measure parent lines, so a pre-consolidation wall is correct. Cisterns
  and `arc_flow` headroom flags are monitors.
- **The six window-drift cells are one re-window lane;** the same lane repairs
  `beast_master14` by broadening growth to con 1 + str 1, while the flat-growth
  rule itself stands. wild_sage V is the NO-AUTO-WIN case: keep druid in
  window and surface wild_sage V rather than strengthen the counter, which
  drops druid below floor.
- **spellspear/skirmisher I/IV are accepted corrected measurements, parked.**
  Capping [Piercing Strikes] once per round would reauthor steel-thread victory
  pins, so it needs a budgeted lane.
- **Act V capstone:** trim capstone growth and/or raise Warden difficulty, then
  give too-weak spines composition or kit relief; Warden-side movement is a
  sanctioned frozen-block exception.
- **Tactician-split Act V ceiling:** fix without trivialising the climax, using
  measurement-led composition/class-data levers only; STOP and report if the
  window is unreachable without policy or frozen-stat movement.
- **The Warden gains a counter to companions**, not a companion nerf: the wolf
  is the spine's identity, and a companion-threatening boss generalises.
- **Relc's veto (#448)** branches to a hard solo fight at 0.35–0.45
  competent-at-band via a different solo composition, without trivialising
  the with-Relc fight (measured 0.78). It is a hard-mode choice, not a trap or
  a free skip.
- **#451:** the once-per-round cap at L2 ships alone; [Improved Counter Strike]
  waits for a martial-table adjudication.

### Combat rules and gear

- **#495 gear damage (2026-10-07):** weapon-gated physical Skills take the
  weapon's `damage_mod` and scale off STR. Spells and blasts keep INT and gain
  a new caster spell-power stat on implements. Implemented by #514 as one
  re-window. Rejected (options presented): `damage_mod` at full weight on every
  arm including spells (largest re-window), and keeping melee-only (no gear
  path for Skill users or casters).
  - (A), 2026-10-08: weapon-gated Skills take the whole melee damage bonus,
    like an ordinary attack (weapon, accessories and meals).
  - (B), 2026-10-08: keep the "spell damage" wording. Spell power is player
    gear only, so enemy-only casts (e.g. [Raskghar Maul]) do not read "spell
    damage". [Instantaneous Barrage] (the Tactician's illusory arrows) is not
    a spell. Both carry a data-driven `"damage_source": "innate"`: INT scaling
    as before, no gear add, plain "damage" on the card. Exemption: enemy-only
    [Slam] keeps "weapon damage", because it really adds the enemy's
    `damage_mod` (bounty scaling); no player card shows it.
- **#494 resonance (2026-10-07):** a power budget, with stronger gear costing
  more. Hedault's trueing lowers an item's resonance (a craft discount, matching
  canon's "better craft interferes less"), and the toast is reworded to match.
  Rejected: inverse-quality repricing of all 26 enchanted items with every
  affected spine re-measured.
- **#570:** capacity grows at the existing once-only beat, independently of the
  semantic ruling; no extra physical gear positions are selected.
- **#591 (2026-10-07):** diagonal melee past a blocked corner is allowed for
  everyone. Rejected (option presented): blocking it for all, which removes
  enemy attacks and forces a re-measure.
- **Worn-accessory abilities are known while worn;** the field bar re-renders
  on equip, and effect text drops "in combat" exactly for field-capable
  abilities. Rejected: a Warden retune (erases the intended wall), a mage-grind
  route, or shipping a red finale.
- **Equipment:** the nine-item sketch
  (`docs/superpowers/specs/2026-08-13-equipment-gaps-design.md`) implements
  under its balance rails, and missing gear is added across tracks (spear first) through vendors,
  loot, treasure, quest rewards and Hedault upgrades. Domination defects are
  fixed as defects.

### Classes, Skills and naming

- **Consolidation is automatic** (supersedes the #472 choice request). It never
  removes Skills (upgrades are allowed), and advancement paths stay open because
  consolidated classes carry their parents' lineage credit.
- **Evolved lineages consolidate into their own unique classes** (#449:
  spearmaster + mage → [Spellspear]). Rejected: evolved parents reusing the
  base target (erases lineage identity), and deferring evolution while
  consolidation is in reach.
- **#347 doctrine (ratified):** authored uniques with derived triggers; every
  consolidation-eligible lineage pair resolves to a unique authored target.
  Generative-at-runtime classes stay NO-BUILD.
- **Coverage before go-live:** a reuse pair ships only when its coverage is
  authored (rows proving no Skill loss), not via a `maps_to` note.
  Necromancer is consolidation-eligible (warrior-line x necromancer family;
  spear owns its hybrids). Orphan mappings are approved as inventoried, with
  swordsman x mage-line into [Spellsword]. #452 ships unnamed orphans as
  `_exempt` rather than scaffolding them silently.
- **Naming (#485):** blanket GO for proposed first-order names. Wiki-verify at
  build still binds, post-bar hits return for clearance, and a later user edit
  supersedes a shipped display name (ids freeze at release cut only). Base x
  base pairs keep the base target; evolved or elemental pairs earn distinct
  names. Swordsman displays as [Blademaster], whose aspiration becomes [Sword
  Saint] (wiki-verify at build). Class and Skill names past the Book 17 bar are
  proposable with user clearance; content spoilers stay barred. Renames change
  a class's renders, never common-noun prose that shares the word.
- **[Ice Floor] is one dual-context id** (`icy_floor`). **[Rope Arrow]** is the
  display name for `rope_work`. **[Pick Lock]** is a rogue L2 active for literal
  locks only (not bars, tripwires or wedged crates), debuting at Hedault's work
  room with a legitimate non-Skill trust route.
- **Grants:** [Dangersense] at rogue L4 (warrior L5 already); [Firefly]/`kindle`
  at hedge_witch L2; [Snap Freeze]/`frost_touch` at hedge_witch L4. [Flame Jet]
  has field `burns`. [Durable Picks] waits for a labour-line class.
- **Martial allocation:** [Greater Strength] stays; [Power Strike] and
  [Piercing Strikes] are combat-only; [Basic Repair] is helper L2; [Basic
  Swordwork] owns the sword-gated `cuts` field action via `field_weapon`.
- **#450:** [Evil Eye] gains `field: true` and an occult ambient read. Free
  scenery reads apply to armless props only; armed props keep their interact
  action, except danger-bearing ones, which the trap-perception family covers.
  Passive tactic Skills tally at their proc site, and actives tally on use.
  Rejected: a new free-inspection mechanism, and an ap_cost-0 activation engine
  (every passive would become slottable).
- **Property effects stay declarative:** `cell_properties` replaced the freeze
  flag; verbs widen deliberately; target counters can override the default;
  one Skill use may bank several accomplishments.

### Recovery, items and economy

- **#565 recovery (shipped #578, cut over #592):** HP/MP persist between battles,
  and actual sleep refills them. Inn meals, held-Skill cooking, food and potions
  restore; combat potions cost AP; excess MP doses poison. Show current/max
  HP/MP and preparation (#567). The proposed numbers are tuning, not rulings.
  Preserve unlimited existing kitchen access and measure it.
- **Meal buffs cap at the strongest single meal per key (#432);** re-eating
  refreshes. #334 ruling 5 (pay twice, get both) still holds for different
  keys. Cudgel and food-prop production stays unbounded; duplicate refusal
  bounds only what is carried.
- **#513 (2026-10-07):**
  - show the shortfall on locked fee rows;
  - fix the delivery gold toast;
  - offer standing deliveries every waking: one rotating standing slip joins
    the 3-slot window whenever it holds none (rejected: all three always,
    7 cards and overlong board pages);
  - add a Pallass side quest: a Gnoll–Drake social quest paying about 12g plus
    a sellable trade bale (2026-10-08). The Runners' Post guild follows later
    (#600). Rejected: another grinding job, and a bonded-room paperwork quest
    (repeats Pallass's paperwork theme).
- **Pallass themes (2026-10-08):** besides bureaucracy, Pallass is the City of
  Inventions, famous for alchemists and smiths, with Grimalkin's fitness, and
  home to other races such as Garuda and Dullahans (canon-check each at build).
  Re-theme existing Pallass quests so only one (`papers_for_pallass`) stays
  paperwork-focused; ids, rewards and fees stay. "Grand Lift" stays.
  Approved design (`docs/design/513-pallass-income.md`): "Room on the Row"
  (talk/help, no fight); `forge_tier_permit` → Grimalkin's fitness,
  `tempered_standards` → smiths and alchemists, `ledger_eats_first` → City of
  Inventions. New owned art (PixelLab, best art wins) for the Gnoll trader and
  on-screen Garuda and Dullahan residents. A third floodplains quest: not now.
  Shipped in #603/#604 (2026-10-08). Lift plates and the market toasts follow
  the theme (lift token, exam-floor booking).
- **Purchases confirm before any gold or item effect commits** (#504).
- **Serve stays cooking-gated;** `source_hint` tells a blocked player where a
  meal comes from, and combat builds are not entitled to bypass the cooking
  pillar.
- **Producer gaps G1–G5** are approved at their recommended shapes (#478).
- **Regional odd jobs** are once-per-waking props with flat pay, up to 12g per
  waking for a marker-holding helper with [Perfect Hospitality].
- **Quest rewards describe the route actually taken** (resolution fallbacks,
  `complete_when_any`, distinct force/disarm accomplishments).
- **Item specifics:** Hedault's 40g bead grants `hedaults_wardstone`. The
  `improvised_cudgel` comes from [Bar Fighting] on taproom furniture, the
  `solid_oak_spear` from the barracks crate. Coyle's bounty suppresses
  alley-nest re-arming.

### World, content and narrative

- **Three Pillars is a standing content gate:** real talk, help and fight
  routes. Pillars govern breadth of viable playstyles, not that every gate is
  bypassable.
- **The Seal Warden fights on every descent (#440);** all three endings resolve
  after it, and sneak gives an in-fight edge, never a skip. #590 gates Olesm's
  seal-funding option on the warden too. The seal door's `door_when` stays
  `seal_opened` alone, not gated on the warden counter (it would be inert behind
  the choice gate, and `seal_opened` is frozen); the refusal is a `variants`
  rung. `test_fixture_coherence` rejects resolution counters without
  `seal_warden_downed`.
- **Book 17 is the wiki's ebook index** (*Lady of Fire*, Vol 7 Pt 3). "Runner's
  Sandals of the Second Wind" is cleared ([Second Wind] already ships).
- **Field gates have two honest modes:** a Skill route plus a legitimate
  alternative, with equivalent payoff where directed. Negative QA walks into
  the gate and asserts refusal; it never teleports.
- **Riverfarm was redesigned (#396):** `a_winter_of_teeth` replaces
  `what_the_thicket_keeps` for new saves; legacy completion remains; briar
  fights are solo-gated; `the_makings` wraps [Hedge Witch].
- **Placement:** the Invrisil mothbear sits on the floodplains verge (original,
  not canon); `goblin_night_patrol` is ashore at (7,21); Hedault's door sits on
  the open facade, with a bespoke sign deferred to VISUAL-LOG (#444).
- **Presence:** Horns reconciliation defers until dialogue ends. Inn visitors
  (#371) schedule one canonical party at a time; do not revive the
  always-present crowd. `encounter_when` is read from the sim predicate, and the
  gate vocabulary gains no OR arm (#475).
- **Unique-class creation (#347) stays behind its gate;** no prototype naming
  in player copy, and no "Five Families" under the spoiler cutoff.
- **Dead content stays honest:** remove hints for unobtainable Skills but keep
  truthful copy when a grant path is planned; orphan detectors harden category
  by category once the shipped set is clean.

### Prose and dialogue

- **Discovery beats instruction:** field-gate prose describes capability;
  receipt toasts may name the Skill used.
- **Zero-inference scenery** for map-register prose: keep facts, quoted
  documents and character beats; invent no motives, quantities or outcomes.
- **Uniform plainness is a machine signature;** #397 round two rebalanced
  cadence before the blind read. #406 is one follow-up pass (fresh holdout,
  residue drain, interruption and silence shapes); do not split off a separate
  ending-variety rewrite.
- **Conversation hubs are append-sensitive:** add hidden options last; reactive
  copy uses `text_variants`, pool stages or twin presence rows.
- **A ruled redesign may rewrite frozen holdout strings.** Each rewritten
  string is excluded from the holdout in both `holdout.json` and
  `HOLDOUT_EXCLUSIONS`, with a reason and a note of what moved. The ids stay in
  the inventory. Precedents: #396, #450, #513 (four strings).

### Simulation, reachability and QA

- **`qa/manifest.json` is the script/seed inventory;** notes and sweeps derive
  from it. A `journey` row must also be `full` and registered in
  `qa/journeys.json` (#515).
- **Continuous journeys (#571):** one PC, title to ending, true act order, no
  `install_fixture` or `teleport` (the stitched six-fixture album was rejected).
  Walls may be retried after defeat and cleared with existing optional content,
  all logged; no tuning, new content or XP-only repeats. A defeat rollback
  replays the same fight, so retries follow a real state change.
- **Engine noise:** unit scripts require `PASS` and reject `SCRIPT ERROR`,
  `Parse Error`, `ERROR:` and `WARNING` beyond exit codes. The only deferred
  lines are #586's exact shutdown particle-shader leaks, owned by
  `qa/noise_scan.sh`; an unreadable log fails.
- **Itinerary equivalence (M3.6 §6.3)** extends to compiled-only
  `wait_for_event`, which is strictly stricter. Rejected: per-node emitter keys,
  which push corpus knowledge back into itineraries.
- **Reachability has two authorities:** data lint for graph reachability, and
  GDScript over the real loader for cells. A declared resource is not a wire.
- **Difficulty x1.0 is inert;** tier sweeps keep monotonic direction.
  `weapon_die` was the rung-4 lever.
- **Time of day is a loop, not a progress meter.**
- **Presence gates:** `present_when` controls existence; `encounter_when`
  controls trigger eligibility. Tests walk the real cell.
- **Eye and ear gates ride a prepared save** (Playtest States).

### Presentation, art and mobile

- **Regional kits (#606, user 2026-10-08; spec
  `docs/superpowers/specs/2026-10-08-regional-kits-design.md`):**
  - **Goal:** regional identity without within-region monotony or clutter.
    Use the pool first; gaps go to `docs/art-generation-list.md`, and
    generation needs user approval. Scenes close only on a blind Fable
    art-direction read; the read beats the metrics.
  - **Hash (controller, #607):** the pick hash is a SHA-256 32-bit prefix,
    not `String.hash()`. Rejected: djb2, because it is linear and a shared
    cell suffix collapses picks (3 of 24 rank orders, the same subset on
    every map).
  - **Slices** live under a top-level untracked `potential_assets/_sliced/`.
    Some pack folders are read-only on disk and are never modified.
  - **Pack art** is wired only as a `region` row on an already-bundled
    sheet; there are no loose pack copies and no bundle release.
  - **Label check:** ground truth follows the prompt's own vocabulary
    (`food_basket` is a container). It is never tuned to the labels, so the
    potted plant stays "plant".
  - **G2:** biome sharing is report-only, because biomes are shared across
    regions.
  - **G3:** `qa/baselines/scene-repetition.json` was first generated on
    #607; regenerate only with `--regen-scene-baseline` plus an entry here.
  - **G3 regens (#608 pilot 1a, controller):** each regen follows a
    reviewed conversion and never hides repetition. The Invrisil generic
    placements went 84 → 76 after the street conversions (share 43.3% →
    39.18%), → 75 with the dedicated rigged-crate-stack sprite, held at 75
    when the art-read fixes added three cross-street lamps and dropped the
    stationery bundle, and → 74 when the boulevard's generic door at (4,1)
    was pinned to the Invrisil shop door (share 37.76%). It held at 74 when
    the counting-room guard took the new regional `invrisil_enforcer` rig
    (one new class row, no counter change).
  - **Counting-room guard rig (#608 final review):** `counting_room_guard`
    (The Factor's Closed Account) wears `invrisil_enforcer`, the owned
    2026-07-06 `hired_blade_a` generation (broad build, club), wired at 28px
    like the alley's other heavy, `footpad_bruiser`. No named character
    wears it. Rejected: `former_headman` (the only rig of Riverfarm's named
    Former Headman), `hired_blade` (already on the alley as Coyle's crew,
    the duplicate the art read removed), and `brothers_lieutenant` /
    `gentleman_bowler` (they read as the Brothers of the Door, not the
    Factor's man).
  - **Cross-street recomposition (#608 art read, `_kits_recompose`):** three
    street lamps at (3,4), (12,4) and (9,11), each blocking its cell; both
    shop signs moved from row 2 to row 1; the stationery display was
    removed. G4 reports it as an advisory naming both the cells and the
    blocked change, not as a silent pass.
  - **Shared floor sheet (#608 final review):** `ashlar_over_checker_v1` is
    Invrisil's `floor_alley` material (tile [0,3]) and also Pallass's public
    fallback floor sheet (`pallass_market`, `pallass_forge`, tile [2,1]). G2
    enforces material exclusivity by material name only. Pixel-level sheet
    exclusivity is a rollout concern and is not enforced.
- **Best art wins per asset (#564/#554)** within a coherent scene, at gameplay
  scale; otherwise keep the official or owned public fallback. READY is not
  acceptance, and there is no quota wiring. Animation, geometry, scale and
  anchor swap together; terrain inherits the original parent before complete
  fallback selection with owned coordinates. Keep the 16px grid; unsuitable
  rigs and physical devices remain explicit coverage records.
- **Tint is not identity:** named subjects need distinct silhouettes; named
  characters do not share another named character's rig; `pc_*` sprites are
  player-only.
- **Combat figure acceptance** is measured from the rendered animation (1.25–3.55
  cells); move subject data rather than relax the bar.
- **Blocked board cells use biome prop data before renderer fallbacks.**
- **Visible lanes:** event emission does not prove pixels; windowed reads decide.
- **Pause scrim:** full-rect black at alpha 0.55, `MOUSE_FILTER_STOP`.
- **HUD (#588/#589):** the desktop Skills readout overlays the world, capped
  below the followed player. The field toggle reads "Show/Hide Skills".
  Rejected: "Details" (vague, and phone combat keeps its own Details panel)
  and "Skill info" (immersion-breaking on an always-visible label).
- **M1:** #508 grants covered-crossing credit for deliberate drainage-cover use
  plus an actual crossing after goblin defeat; bare or prop-only visits earn
  none; once per crossing per waking, no respawn, Rogue only at sleep; live
  danger still needs a threat (`docs/design/rogue-recovery-proposal.md`). #507
  puts an appearance-only footer under the art and the difficulty explanation
  under its prompt, keeping Settings Help. Mobile acceptance (#511,
  #504–#506, #510, #253, #585) needs physical iPhone Safari/Android Chrome,
  three unfamiliar players and a desktop reference, and is deferred.

## Superseded calls — do not resurrect

- `[Rope Work]` → **[Rope Arrow]**; `frost_touch` via Eloise dialogue →
  **hedge_witch L4**; [Flame Jet] without `burns` → **field `burns`**.
- "Same-map `present_when` is unsafe" → **false**.
- "Same-key meal mods sum" and "duplicate refusal bounds cudgel production" →
  **false since #432**.
- "Passing events prove a visible feature" → **false;** windowed reads decide.
- #472's consolidation choice → **automatic consolidation**.
- Ladder ordering "report-only until re-ruled" → **gated on the competent
  column**.
- Resonance "deferred, no doctrine" → **#494 power budget with craft discount**.
- [Blademaster] aspiration open question → **[Sword Saint]**.
- Book 17 as *Garden of Sanctuary* (Vol 7 Pt 1) → **the wiki's ebook index**.
- #397 engineering-green prose → **blind-reader acceptance required**.

## Historical release index

Moved to `docs/RELEASE-HISTORY.md`.
