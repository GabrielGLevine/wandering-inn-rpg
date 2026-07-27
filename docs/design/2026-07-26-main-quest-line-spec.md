# Main Quest Line restructure — "post-game is defunct" (2026-07-26, Fable)

STATUS: user-approved design (brainstorm 2026-07-26); supersedes the
*framing* of post-Act-III content everywhere, and AMENDS (does not
replace) docs/design/2026-07-20-door-continuation-spec.md (#270) — that
doc remains the beat-level source for Act V; the amendments in §7 win
where they conflict.

## Goal

The demo outgrew its original scope. Everything after the Raskghar seal
is currently gated `post_game` and reads as optional epilogue content.
Replace that with one Main Quest line that threads every region
(Liscor → Riverfarm → Invrisil → Pallass) in a fixed order and ends in
an appropriately leveled Act V conclusion in Liscor's dungeon.

User rulings baked in:

- **The Inn's Magical Door IS Thresk's door.** No "second door" fiction
  anywhere. The dungeon rune-door (`seal_kept_door`) is a FEEDING WARD
  cut by the same hand — never another portal.
- **Full backport (approach C):** a playable quest where the player
  joins the Horns of Hammerad to retrieve the door itself from the ruin.
- **Ordered pilgrimage:** Riverfarm → Invrisil → Pallass → finale.
- **Tuned bands + harness** for difficulty; no hard level gates.
- **New finale sequence** at the end of Act V; the current
  raskghar-sealed epilogue card is retired.

## Non-goals

- No new regions, no inter-continental portal rows, no door
  mana-simulation (standing rulings hold).
- `chieftains_price` (Rags) stays a side quest, order-free.
- No renaming of the frozen `post_game` counter id (fiction changes,
  id does not).
- Book-17 bar and oblique-Thresk naming unchanged.

## 1. Act structure (acts.json)

| Act | Title | Contents | Entered when (predecessor advance_when) |
|-----|-------|----------|------------------------------------------|
| I   | Arrival | intro, first class | — |
| II  | Make a Place for Yourself | errand + three postings | unchanged |
| III | What Stirs Beneath | `something_beneath` (Raskghar arc) | unchanged (2 classes + 3 quests) |
| IV  | What the Door Opened | Horns delve → door retrieval → awakening → pilgrimage | `raskghar_sealed` **alone** (drop `door_awakened` from act_iii.advance_when — door work moves inside Act IV) |
| V   | What the Seal Was Feeding | descent, three-path resolution, finale sequence | pilgrimage complete (three lattice pieces + `seal_kept_reported`) |

Act IV's derived beats are rewritten to narrate the new order (delve,
retrieval, mounting, awakening, one beat per pilgrimage stop). Act V
fills the reserved slot exactly as #270 planned, advancing on
`seal_resolved`.

### `post_game` reframe

The counter id survives (shipped_ids freeze; bounties, Olesm stipend,
chronicle-facts consumers untouched). New banking: silently at the
sleep that banks `raskghar_sealed` (sleep_beat, not the epilogue —
the epilogue is retired). New meaning: "Liscor counts you among its
own" — the Act III→IV gate. All copy that implies "the story is over"
is rewritten during the copy pass (guild board comment, Olesm stipend
framing, dev-facing comments).

## 2. Main quest chain (ordered)

1. `the_errand` → three postings (Act II) — untouched.
2. `something_beneath` (Act III) — untouched. `raskghar_sealed` gets a
   light act-transition sleep beat (one GDI line), NOT the epilogue.
3. `what_the_seal_kept` (Act IV opener) — content untouched; the Olesm
   start option re-gates from `post_game` to the same flag with
   mid-story copy. Its role: discover the sealed rune-door. This is
   where the player first works with the Horns.
4. **NEW quest — door retrieval** (working id `horns_dig`, working
   title "The Dig"; title needs user ACK). Title and all pre-reveal
   beat copy MUST NOT name or hint at a door — the journal is visible
   from quest start, and what the pedestal holds is the quest's
   reveal (user ruling 2026-07-26). Detail in §3.
5. `door_that_goes_elsewhere` — RESHAPED. The anchor-stone beat
   (`recovered_anchor_stone`) is absorbed by the retrieval quest (§3).
   The door is NOT dead while this chain runs — the Liscor hop works
   from the moment of mounting (§3 haul). The chain's job is the
   first FAR attunement: `door_awakened` re-semantics to "the door
   reaches beyond Liscor" (frozen id, new meaning), and its concrete
   payoff is the Riverfarm link. Remaining beats: consult
   (`door_understood`, kept — re-fictioned: the door manages the
   short hop but STRAINS at anything farther; the shipped cellar
   rift-vermin arm becomes "what leaks through when it strains", the
   Pisces arm and the wardwork-reading arm read the recovered door
   itself) → buy catalyst → attune with Pisces → `door_awakened`.
   All copy re-fictioned: the player is extending the reach of the
   door they personally carried home, and attunement is what makes
   the straining stop. Counter ids (`door_understood`,
   `recovered_anchor_stone`, `bought_catalyst`, `door_awakened`) are
   frozen and keep their ids; only *which quest's beats consume them*
   and the copy change. The slimmed chain starts automatically at
   `door_mounted` (Pisces, at the mounting: it works — now let us see
   how far it can go) — no separate start option remains.
6. **NEW quest — pilgrimage spine** (working id `where_the_door_reaches`,
   working title "Where the Door Reaches"; title needs user ACK).
   Detail in §4.
7. **Act V** — #270 spec as amended in §7. Banks `seal_resolved`.
8. **Finale sequence** at `seal_resolved` — §5.

## 3. The retrieval quest (`horns_dig`, "The Dig") — the backport

SPOILER RULE (binding): the quest title and the `join_dig`/`breach`
beat descriptions never mention a door. They sell the dig itself — a
sealed level, an expedition short-handed, an unknown prize. The door
is named only from the `haul` beat onward, after the reveal has
happened on screen. (Former working title "The Door in the Ruin"
rejected for spoiling the reveal from the journal.)

Fiction (user-corrected 2026-07-26: NO pantry-doorway resonance, no
pre-linking the inn to the ruin — they find the door in the ruin, and
it ends up at the Inn, that simple). Hook: the Horns of Hammerad have
moved into the inn after the delve (`the_horns_home` is a shipped Act
IV beat) and Ceria is planning a dig at the ruin east past the gate
road (the canon Albez echo, never named — oblique per the Book-17
bar). The dig has hit a sealed level the team can't crack short-handed;
Ceria invites the player — they worked together in the trapped halls.
What the pedestal level holds is **the door itself** — Thresk's door —
plus its anchor stone. The Horns haul it back and it is mounted at the
inn (a magic door is exactly the kind of thing Erin's inn absorbs; the
Horns owe her room and board).

Beats (order-gated; do NOT accept the catalyst-style cosmetic skip
here — this is the main line):

1. `join_dig` — take Ceria's invitation at the inn, reach the ruin,
   find the Horns' camp; banks `horns_dig_joined` (new). The dig-camp
   conversation carries the backstory: how the expedition found the
   site, what they hope is down there. Past-tense variant of the same
   arm serves migrated saves (§8).
2. `breach` — three-path the sealed pedestal level (fight the
   pedestal's guardian arm / Ksmvr-style plate navigation for the
   stealth-social arm / a wardwork-reading skill arm — reuse the
   shipped ruin map with a dig-state variant, no new region).
   Banks `pedestal_breached` (new).
3. `haul` — the reveal + the trip home; banks `door_retrieved` (new)
   and `recovered_anchor_stone` (frozen id, kept — the stone comes
   home with the door). Door mounted at the inn: banks `door_mounted`
   (new); the pantry-door prop swaps to the mounted state. **Mounting
   grants the inn↔Liscor link immediately** (user ruling 2026-07-26):
   a new portal row gated on `door_mounted`. This is WHY the door
   stays at the inn — an inn outside the walls with a door straight
   into the city proves its worth on day one. No dead-door period.

Quest start: from Ceria at the inn, gated on `seal_kept_reported`.
Erin's current door-chain start option in erin_errand.json is retired
(the slimmed chain auto-starts, §2.5); if a pointer option is wanted,
Erin can nudge toward Ceria's planning table instead.

## 4. The pilgrimage spine (`where_the_door_reaches`)

(Renamed from `follow_the_lattice` — "lattice" is Act V's REVEAL, the
four shipped `detected_wardwork` sites reading as one warding system;
a quest title cannot assume the player already knows it. Working title
"Where the Door Reaches"; ACK gated.)

Discovery-driven, NOT a fetch list (user ruling 2026-07-26): the
player is never told "get X from Riverfarm, Y from Invrisil, Z from
Pallass". The door's growing reach IS the guidance — each newly
reachable region is the next place to go because it is the only new
place to go. The three things Pisces will eventually need for the
descent are DISCOVERED in-region while living each chain, then
contextualized after the fact.

Copy discipline (binding on every surface this quest touches):

- Spine journal beats point at reach, not objects: "The door reaches
  Riverfarm now. See what's out there." — never an itemized ask.
- Each lattice piece surfaces organically inside its region's story
  (the witch's ward-lore emerges from her own chain; Hedault notices
  the wardcraft of the door himself; the rune work comes out of the
  forge-tier permit's own business). The capstone arm is the region
  NPC raising it, not the player shopping for it.
- Pisces foreshadows, never assigns: early line at spine start hints
  the seal will take more than what Liscor knows; after each piece
  banks, a Pisces reaction line contextualizes what it means. The
  full picture assembles only at the Act V reading.

Each stop uses the EXISTING region chain as the body and adds one
small capstone dialogue arm that banks a lattice piece:

| Stop | Existing chain (untouched body) | New capstone arm | Banks |
|------|--------------------------------|------------------|-------|
| Riverfarm | `price_of_a_favor` | the witch's ward-lore (witch hollow is a shipped `detected_wardwork` site) | `lattice_witch_lore` (new) |
| Invrisil | `a_gentlemans_disagreement` | Hedault reads Thresk's wardcraft (enchanting surface shipped) | `lattice_hedault_reading` (new) |
| Pallass | `papers_for_pallass` + `forge_tier_permit` | forge-tier rune work | `lattice_forge_rune` (new) |

Spine beats: one per stop (completes on that stop's lattice counter)
plus a closing "return to Pisces" beat. Spine quest starts from Pisces
at `door_awakened`.

Ordering enforcement, two layers:

- **Quest-start gates:** each region opener's dialogue option requires
  the previous leg's lattice counter (Riverfarm opener requires
  `door_awakened`; Invrisil opener requires `lattice_witch_lore`;
  Pallass opener requires `lattice_hedault_reading`). Gates are
  `requires` on the START options only — a started quest is never
  interrupted (§8 covers pre-restructure saves).
- **Progressive portal rows:** REALITY CHECK (recon 2026-07-26): the
  region rows ALREADY ship progressively — `riverfarm_attuned` (guild
  board rumor), `invrisil_attuned` (banked in riverfarm_witch.json —
  the witch already hands you Invrisil), `pallass_attuned` (Krshia's
  attunement stone, gated `pallass_sponsored`). The shipped flow is
  already an ordered Riverfarm → Invrisil → Pallass ladder. Work
  remaining: re-gate the inn↔Liscor pair from `door_awakened` to
  `door_mounted` (§3 — day-one value), keep Riverfarm's rumor beat
  gated behind `door_awakened`, and hang the lattice capstone arms
  NEXT TO the existing attunement banks (the witch's ward-lore arm
  beside her `invrisil_attuned` bank, etc.) rather than inventing a
  parallel unlock system. Fiction: the door's reach grows as it
  re-attunes (`resonance_grown` mechanism already ships this idea).
  WARNING (from the portals census): changing row visibility changes
  option order on every carrier — re-pin the portal_menu +
  pallass_walkthrough canonicals in the same PR, and do not clone the
  vacuously-true `portal_menu_when` wrapper shape from
  invrisil_boulevard.json:903.

`chieftains_price` stays reachable from the floodplains on foot,
order-free, side-tabbed.

## 5. Finale sequence (replaces the epilogue)

The current epilogue (sleep_veil: EPILOGUE_LINES_OPEN/CLOSE + link)
retires. New sequence plays once at `seal_resolved`, same
veil/dialogue-end delivery mechanism:

- Region recap lines — one per pilgrimage stop, echoing what the
  player actually did there (reuse the act_iv derived-beat facts).
- Path-specific closing lines — opened (`seal_opened`) / fed
  (`seal_kept_fed`) / re-warded (`seal_rewarded`).
- Class recount (kept from the current epilogue — it works).
- The wanderinginn.com outro link stays as the demo's curtain line.

The raskghar-sealed moment keeps only a light transition beat (§2.2).
QA epilogue canonicals re-point to the new trigger.

## 6. Difficulty: tuned bands + harness (no gates)

No hard level gates anywhere — an underleveled player loses fights,
never access. Enforcement is tuning + verification:

- Derive the CURRENT expected class-level at each main-line milestone
  from existing harness fixtures (plan-time task; #211
  challenge-weighted leveling is flag-on and shifts the curve).
- Retune so each pilgrimage stop's encounters sit one band above the
  previous stop; the Act V seal-warden is the top band.
- Every stop gets a gated 0.55–0.95 winrate harness cell at its
  expected level (the shipped harness convention); the warden cell is
  mandatory before merge (#270 already requires it).
- Any combat retune re-derives pinned rng_state in door_chain_* and
  affected fixtures via tests/_derive_rng_state.gd.

## 7. Amendments to #270 (door-continuation-spec)

1. **All "second door" language is dead.** The rune-door under Liscor
   is a feeding ward cut by the same hand as the Magical Door. Rename
   the planned counter `second_door_descent_agreed` →
   `seal_descent_agreed` (not yet shipped, safe). The
   `heard_pisces_second_door` counter IS shipped/frozen: keep the id,
   re-copy every surface that surfaces it so the fiction reads "the
   seal's wardwork," never a second door. Audit `dungeon_attuned`'s
   study-sleep copy the same way.
2. **Descent unlock:** requires the three lattice pieces (replaces the
   spec's looser gating). Pisces' descent ask fires when
   `lattice_forge_rune` banks.
3. Working title of the quest stays `what_the_seal_was_feeding`; Act V
   title unchanged.
4. Everything else in #270 (three-path finale, warden encounter rules,
   feeding-ward reveal, B-side Pallass return anchor) stands.

## 8. Migration + compatibility

save.gd backfill (the GH#167 template), applied at load:

- Save has ANY old door-chain progress (`door_that_goes_elsewhere`
  started, or any of `door_understood` / `recovered_anchor_stone` /
  `bought_catalyst` / `door_awakened` banked) but no `horns_dig`
  progress: backfill
  the retrieval quest complete (bank `horns_dig_joined`,
  `pedestal_breached`, `door_retrieved`, `door_mounted`); the Ceria
  dig-camp arm reads past-tense for these saves.
- Save has region terminals already banked (old freeform order): spine
  beats are counter-derived, so they auto-complete; each region
  opener's gate is `previous lattice counter OR own quest already
  started/completed` — no stranded saves, no un-startable quests.
- Saves with `post_game` banked keep it; new banking path is additive.
- The lattice capstone arms must be reachable AFTER a region chain is
  already complete (re-visit arms, not one-shot chain tails), so old
  saves can collect pieces.

## 9. New counters (freeze list — name at first write)

`horns_dig_joined`, `pedestal_breached`, `door_retrieved`,
`door_mounted`, `lattice_witch_lore`, `lattice_hedault_reading`,
`lattice_forge_rune`, `seal_descent_agreed` (renamed from #270's
planned id), plus #270's existing planned list (`read_the_seal_runes`,
`read_the_feeding_ward`, `seal_opened`, `seal_kept_fed`,
`seal_rewarded`, `seal_resolved`, `pallass_return_carved`). All plain
accomplishments, zero save.gd plumbing beyond the §8 backfill.

## 10. QA blast radius

- test_content for every new/edited dialogue surface; new canonicals
  for the ruin dig-state map variant and the mounted-door pantry state.
- Cellar rift-vermin encounter gating moves to `door_mounted`-based
  (they are now "what leaks through the unattuned door" — cannot fire
  before the door exists at the inn); re-derive affected fixtures.
- Portal option-order re-pins (§4 warning) in the same PR as the row
  changes.
- Epilogue/finale canonicals re-point; sleep-veil QA fixtures updated.
- Blocking/reachability validators on the ruin dig-state variant and
  the Act V vault map (#270 requirement).
- wi-machine-playtest at milestone close (player-eyes pass over the
  full main line).

## 11. Delivery shape (multi-PR milestone — this is the v0.14 core)

Suggested PR sequence (plan-time refinement expected):

1. Acts/gating reframe: acts.json rework, `post_game` re-banking,
   copy pass, `what_the_seal_kept` re-gate. Smallest, unblocks all.
2. Retrieval quest (`horns_dig`) + door-chain reshape + inn↔Liscor
   row + save backfill.
3. Pilgrimage spine + region capstone arms + ordering gates +
   progressive portal rows (+ re-pins).
4. Act V (#270 as amended) + seal-warden tuning cell.
5. Finale sequence + epilogue retirement.
6. Difficulty band retune sweep + harness cells (can ride 3–5).

## Open items (user-gated)

- Quest title ACKs: "The Dig", "Where the Door Reaches" (working
  titles; ids follow repo convention once ACKed).
- Act IV title: keeping "What the Door Opened" (it now describes the
  whole act better than before) — flag if a rename is wanted.
- #270's B-side (Pallass return anchor) stays optional/separate; say
  the word to fold it into PR 4.
