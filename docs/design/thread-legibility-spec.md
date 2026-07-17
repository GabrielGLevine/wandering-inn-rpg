# Thread Legibility Spec (#148) — v0.10.0 headline

**Authority:** user-approved 2026-07-17: tiers 1+2 core, tier 3 on the
two stuck points only, tier 4 as a default-OFF settings toggle. No
floating quest markers, ever. Anti-trivialization rule: relay lines say
WHO/WHERE, never WHAT TO DO. Ground truth: the #148 quest cartography +
signal-surfaces scout reports (2026-07-17, session records); every
mechanism cited below was verified against src this session.

## Tier 1 — beat-text audit + structure fixes (data/quests.json + dialogue)

1. **Door chain gains its missing third beat.** `door_that_goes_elsewhere`
   currently ends at the fetch; the payoff (`door_awakened`, the Act III
   gate) banks in a quest-untracked Pisces step. Add beat `attune`:
   "Bring the anchor stone and Krshia's catalyst back to Pisces, by the
   Guild steps on Market Street, and see the door awakened." —
   `complete_when {door_awakened: 1}`. (journal_history's quest_lines
   pin counts QUESTS not beats — safe; journal_skills pins acts.json
   only — safe.)
2. **Split the dual fetch.** Beat `recover` becomes two beats:
   `recover_stone` ("Recover the anchor stone from the ruin east past
   the gate road — cross the floodplains and look for the sealed
   pedestal." — `{recovered_anchor_stone: 1}`) and `buy_catalyst`
   ("Buy the attunement catalyst from Krshia's stall on Market Street
   in Liscor." — `{bought_catalyst: 1}`).
3. **Ashgrave/Dresk mismatch.** the_missing_recruit's report beat names
   "Sergeant Ashgrave"; the NPC is display_name "Dresk". Fix by making
   the world match the journal, not vice versa: Dresk's display_name
   becomes "Sergeant Ashgrave" ("Dresk Ashgrave" is already his
   profile name — the barracks entity keeps id `duty_sergeant`/`dresk`
   ids untouched, display only). Audit his dialogue speaker labels to
   match. (Ids never change; display_name is free.)
4. **Person+place audit** — the rule, precisely: every beat names its
   PLACE, and names a PERSON where a person is the beat's contact
   (fetch/act beats with no NPC contact are place-only by design — the
   approved recover_stone copy is the template, not a violation).
   THE CHECKLIST (from the cartography audit; rewrite exactly these):
   - missing_crate/report: add place ("at her market stall on Market Street").
   - cisterns/resolve: add person-of-reference ("the nest Olesm marked").
   - wrong_order/resolve: name the three venues explicitly ("the supplier on Market Street, Krshia's stall, or the inn kitchen").
   - wrong_order/report: add place ("in the inn common room").
   - door chain/consult: name all three paths' anchors ("fight what leaks through in the cellar, ask Pisces by the Guild steps, or read the wardwork on the pantry door yourself").
   - door chain/recover_stone: place-only is CORRECT (no person guards it in prose; the Guardian stays a surprise).
   - price_of_a_favor/report: "Tell the headman, at the village longhouse-side square, it's done."
   - a_gentlemans_disagreement/report: add place ("at the Brothers' parlor off the alleys").
   - what_the_seal_kept/report: add place ("at the Guild" — the sibling phrasing).
   - the_missing_recruit/report: fixed by the Dresk display rename (item 3).
   - papers_for_pallass/arrive: "the stamp clerk on the market tier, just through the Door."
   - forge_tier_permit/apply + /stamped: keep place-precise, person optional (the clerk is the door; acceptable as-is — rewrite ONLY if a natural clerk-naming reads better).

## Tier 2 — the rumor lattice (pure data, talk_pool_stages)

Mechanism (verified): stages are array-order-LAST-match-wins with
AND-only `requires_accomplishment`; retirement = a LATER stage gated on
the beat's completion counter (there is NO hide_when on stages — the
erin_bed_slept idiom is the retirement pattern).

**Lattice table** — for each main-line handoff, relay lines on CITY-side
hub carriers (the dungeon/ruin/sewer maps are relay dead zones by
design; carriers live where players return):

| Armed state (gate) | Retires on | Carriers (map) | Line register |
|---|---|---|---|
| `heard_about_cisterns` | `resolved_the_cisterns` | erin (inn), krshia (street) | "Olesm's been muttering at sewer maps all morning — go rescue him from himself." |
| `resolved_the_cisterns` | `cisterns_reported` | erin (inn), zevara (street) | "Word is the cistern thing's settled. Olesm will want it from you, not rumor." |
| `watch_runner_pointed` | `heard_the_deep_tremor` | erin (inn), olesm (street), krshia (street) | "A runner was asking after you. Captain wants you at the gate." |
| `heard_the_deep_tremor` | `cleared_the_warren` | erin (inn), pisces (street) | "You've got the look of someone the Watch pointed at a hole in the ground." |
| `cleared_the_warren` | `raskghar_sealed` | erin (inn) | "You came back up. TELL Zevara you came back up — she counts." |
| `door_chain_started` | `door_understood` | lyonette (inn), pisces (street) | "Erin's door is doing the thing again. She's pretending it's fine." |
| `door_understood` | `recovered_anchor_stone` | erin (inn), krshia (street) | "Pisces said something about a ruin east past the gate road. He used the word 'trivial,' which means it isn't." |
| `recovered_anchor_stone` | `bought_catalyst` | erin (inn) | "Krshia holds the catalyst at her stall. She will absolutely overcharge you. Pay it." |
| `bought_catalyst` (+stone) | `door_awakened` | erin (inn), krshia (street) | "You have everything. Pisces is by the Guild steps, being smug at pigeons." |
| `horns_delve_started` | `horns_party_formed` | erin (inn), selys (guild) | "Ceria's team went down to the gallery already. They'll wait. Ceria said so. Twice." |
| `took_brothers_job` | `coyle_operation_found` | ratici (parlor) | "Boulevard's where the operation runs, friend. Start where the money's loudest." |
| `heard_price_of_a_favor` | `blight_lifted` | riverfarm_headman, riverfarm_hunter (village) | "The hollow's west past the fields. Nobody walks you there. Nobody local, anyway." |
| `pallass_sponsored` | `pallass_attuned` | selys (guild) | "Krshia's stone, market row — the Door can't reach Pallass without it." |

Authoring rules: each relay = ONE stage per carrier (armed gate as
requires + a retirement stage AFTER it in array keyed on the retire
counter with that carrier's neutral lines — reuse the neutral stage
when several relays share a carrier by CHAINING: later stages win, so
order stages by story progression). Voice per carrier's profile. All
lines copy-fit tested. NO new machinery.

**Ordering trap (from the scout):** inserting stages before existing
later stages changes which stage wins mid-progression — every carrier's
final stage array must be reviewed as a WHOLE progression (write the
array in story order, earliest gates first). spot-check social_loop +
each carrier's walkthrough script.

## Tier 3 — arrival re-orientation (small engine seam + 2 data uses)

New: map-level `arrival_toasts` array on map JSON:
`[{ "requires": {counter: n}, "hide_when": {counter: n}, "text": ... }]`
— evaluated in `transition()` (mirror the portal `arrival_toast` emit at
wi_game.gd:1200-1209; first satisfied entry wins, emit TOAST). Pure sim,
~15 lines + tests. SCOPED USES (exactly two):
- dungeon_approach: armed `heard_the_deep_tremor`, retired
  `cleared_the_warren`: "The fissure Zevara spoke of is down past the
  gallery. The dark has a direction today."
- ruin_surface: armed `door_understood`, retired
  `recovered_anchor_stone`: "East past the gate road — this is the ruin.
  The pedestal Pisces described is deeper in."

## Tier 4 — opt-in thread line (default OFF)

- WISettings: section "field_hud", key "show_quest_thread", default
  false, is_/set_ accessors (mirror readout_expanded, no tri-state).
- settings_panel ROWS: append "Quest Thread" IMMEDIATELY BEFORE "Back"
  (index-safety contract; settings_loop's move-counts survive only in
  that slot). Toggle case mirrors Reduce Motion. Add the boolean to the
  UI_SETTINGS_RENDERED payload (subset-match safe).
- field_hotbar `_render()`: when the setting is true, append ONE line —
  first entry of `Game.sim.quest_summary()` (already formatted
  "Title (Region) — beat text"; journal.gd precedent call) — appended
  AFTER skill lines and ONLY inside the `_readout_lines` build so the
  default-off state leaves every existing readout_lines array pin
  byte-identical (field_skills_loop / mage_invisibility_loop /
  rogue_earn_loop pin exact arrays).
- settings_loop: extend with the new row's toggle + save/load
  round-trip proof (append steps, never insert).

## Lanes & gates

- **L-SPEC-DATA** (quests.json + dialogue beat rewrites + Dresk display):
  tier 1. Owner: controller or Codex.
- **L-LATTICE** (map talk_pool_stages across inn/street/guild/parlor/
  village): tier 2 — copy is voice work (controller authors lines; lane
  wires + orders arrays).
- **L-ARRIVAL** (wi_game.gd transition seam + 2 maps + tests): tier 3.
  Single implementer on src.
- **L-TOGGLE** (wi_settings/settings_panel/field_hotbar + settings_loop):
  tier 4. Single implementer on ui.
- Gates per lane: full unit suite (CI bar), touching sweeps, the
  carriers' walkthrough scripts, copy-fit, a NEW `thread_lattice_loop`
  QA script (fixture at a mid-chain armed state → assert the relay line
  plays → complete the beat → assert retirement) with a can-fail proof,
  and a **prepared Playtest State** (playtest_saves/, per the 2026-07-17
  directive) parked at the Raskghar handoff for the user's next
  eye-gate. Whole-wave review before PR; #154's validator (landing
  separately) must stay green across all new gates.
