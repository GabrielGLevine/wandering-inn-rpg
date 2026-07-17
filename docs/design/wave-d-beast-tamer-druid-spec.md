# Wave D-2: [Beast Tamer] + [Druid] consolidation (spec)

**Authority:** #134 rulings (Beast Tamer = new base with the
ally/companion mechanic; Druid = Beast Tamer × Mage consolidation —
the two-way liberty is canon-confirmed: Nalthaliarstrelous holds
[Druid]+[Gardener] unconsolidated, 4.44 M; Mrsha's path is one of
plural routes). All skill names carry verdicts from the #134 research.
v0.10.0 set per user.

## Companion machinery generalization (the one engine seam)

Wave B shipped a HARDCODED skeleton companion (`_animate_field` matches
three bone-pile ids; state key = one companion). Generalize:
- Prop flag `companion_source: {companion_id, skill}` replaces the id
  list (retires Wave B review finding L1): [Animate Dead] and the new
  [Lesser Bond] route through ONE seam — faced prop carrying the flag +
  the matching skill known → consume prop (structural remove), set
  `companion` state `{id, source}`.
- Companion state stays SINGLE-SLOT (one companion at a time — a new
  bond releases the old with a toast; canon: tamers bond few animals,
  and the spawn-capacity guard already caps rosters).
- start_combat injection, death/sleep clearing, follower visual, and
  the capacity guard are ALL shipped — they read the state key
  unchanged. skeleton_ally keeps its record; new combatant records:
  `wolf_companion` (carn-wolf canon; clone a wolf enemy at tuned HP),
  `razorbeak_companion` (clone razorbeak). Sim: with-companion cells
  for a beast_tamer build, GATED band, cell-selection only.
- Sleep-clear DELTA for tamed companions: canon bonds persist — tamed
  companions survive sleep (skeleton keeps clearing: the working
  fades). One branch on `source` at the sleep-clear site, doc-commented.

## [Beast Tamer] — base class

- `gained_by {soothed_a_beast: 1}` — partial taming counts (canon:
  Lyonette + a hurt bee, 3.23 L). Producer: NEW wounded-beast props
  (below). stat_growth {con: 1}.
- Curve: ROGUE shape verbatim on umbrella `tended_beasts` (banked by
  every soothe/tame/train interaction).
- Kit: L1 [Healthy Rearing] (ATTESTED 3.23 L) — passive identity.
  L2 [Animals: Basic Command] (ATTESTED 4.21 E) — combat, ap 0,
  effect: companion hit_bonus (data-tuned; reuses hit_bonus applied to
  the companion — verify effect scoping at implementation; if
  companion-scoped buffs need sim work, downgrade to pure passive +
  flag). L3 **[Lesser Bond]** (ATTESTED 3.11 E shape "[Lesser Bond:
  Name]") — field, `companion_source` casts at tameable props: wolf
  pup (floodplains den prop), razorbeak chick (corusdeer_range/
  razorbeak nest area prop). L5 [Beast's Mending] (⚑ ORIGINAL — care
  tier): field-cast at the companion? v1 SIMPLER: bench-style cast at
  wounded-beast props → banks + small gold/reputation flavor. L7
  [Wild Affinity] (ATTESTED, Mrsha pre-upgrade): passive — BEAST-kind
  ambush encounters get `trigger_radius` reduced by 1 for this player
  (one small sim read at _check_trigger_radius, kind-tagged via a
  `beast: true` flag on the relevant encounters; distinct from ward/
  sneak/blink: always-on, beasts only).
- Evolution: single-axis `{tended_beasts: "beast_master"}`?? — [Beast
  Master] IS attested (Redscar 5.55 G). YES: Replacement at 10, sparse
  floor 10, L10 grant [Pack Bond] (⚑ ORIGINAL: companion max-hp step).
  Aspiration: { display_name: "Beast Master", text: "Redfang riders
  bond a wolf for life. Level far enough, and the wild starts offering." }
- Canon guardrails: NO tamer above Lv 40 anywhere in world data; rock
  crabs refuse taming with the fail-loudly joke (6.08 insect/monster
  lore) — a refusal line on the crab encounters; NO Mrsha/white-fur/
  Doombringer references; creler taming never referenced.

## [Druid] — consolidation

- consolidations[] entry: parent_lines [["beast_tamer","beast_master"],
  ["mage","ice_mage","fire_mage"]], min_parent_level 10,
  min_combined_level 21 (the pinned gate shape). Target `druid`.
- Class record: SPARSE floor 14 (derived, spellsword walk). stat_growth
  {int: 1, con: 1}. inherits ["beast_tamer","mage"].
  L14 grants [Peace of the Wild] (ATTESTED 5.06 M — the Wild Affinity
  upgrade): beast-kind trigger_radius reduction 2 (supersedes; same
  seam). L15 []. L16 [Thorn Hand] (ATTESTED, Two Rats interlude):
  combat, ap 2 mp 3, spell_damage range 1 + `rooted` rider 1 round
  (all shipped effect shapes; element "nature" → banks nature_cast free).
- Aspiration: { display_name: "Druid of the Wilds" ⚑ ORIGINAL-wrapper,
  text: "Druids are not made by teachers. The wild decides, and it is
  a harsher judge of character than any guild." } — carries the
  restricted-class canon flavor.
- Fences: druids are rare loners (no orders/temples); [Natural Allies:
  X] NOT granted (cross-class canon, parked); Vol-8 druid content
  banned; the Gardener omission is documented in the consolidation
  `_comment` as the engine-shaped liberty with the 4.44 M proof.

## Content slices

- Wounded corusdeer prop (corusdeer_range) — the gained_by producer:
  interact soothes → `soothed_a_beast` + `tended_beasts` (repeatable
  variant: later visits give tended_beasts only).
- Wolf-den prop (floodplains, off the road) + razorbeak-chick prop —
  [Lesser Bond] targets. Each with observe copy + refusal-when-skill-
  unknown toasts.
- Rock-crab refusal line (crab_nest / rock crab encounters): "The crab
  regards you with all the tameable warmth of a boulder." (banks
  nothing — pure joke, canon-grounded).

## Verification

Full wi-adding-a-class-or-skill gate set + sim rows (beast_tamer with
wolf companion; druid dual-kit build) GATED; beast_tamer_loop +
druid_consolidation_loop QA scripts (fixtures near-threshold, no
hand-banks past reachable positions — #152 lesson) with can-fail
proofs; #154 validator green; windowed: companion wolf follower +
tame cast + the refusal joke; prepared Playtest State at the wolf den;
icons ×~7 placeholder shapes (PixelLab user-gated); Dresk-style voice
review on all new copy. Sequenced AFTER Wave D-1 merges (classes.json/
skills.json single-writer).
