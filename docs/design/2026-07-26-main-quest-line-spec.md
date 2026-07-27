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
4. **NEW quest — door retrieval** (working id `door_in_the_ruin`,
   working title "The Door in the Ruin"; title needs user ACK).
   Detail in §3.
5. `door_that_goes_elsewhere` — SLIMMED. The consult beat
   (`door_understood`) and the anchor-stone beat
   (`recovered_anchor_stone`) move into / are absorbed by the
   retrieval quest (§3). Remaining beats: buy catalyst → attune with
   Pisces → `door_awakened`. All copy re-fictioned: the player is
   awakening the door they personally carried home. Counter ids
   (`door_understood`, `recovered_anchor_stone`, `bought_catalyst`,
   `door_awakened`) are frozen and keep their ids; only *which quest's
   beats consume them* and the copy change. The slimmed chain starts
   automatically at `door_mounted` (Pisces, at the mounting: now we
   wake it) — no separate start option remains.
6. **NEW quest — pilgrimage spine** (working id `follow_the_lattice`,
   working title "Following the Lattice"; title needs user ACK).
   Detail in §4.
7. **Act V** — #270 spec as amended in §7. Banks `seal_resolved`.
8. **Finale sequence** at `seal_resolved` — §5.

## 3. The retrieval quest (`door_in_the_ruin`) — the backport

Fiction. Erin's pantry doorway leaks strangeness — the shipped cellar
rift-vermin fights ARE this leak, re-explained. Pisces traces the
resonance east to the ruin past the gate road, where Ceria's
expedition is already digging (the canon Albez echo, never named —
oblique per the Book-17 bar). The dig has hit a sealed level the Horns
can't crack alone. The player joins the dig, gets through the sealed
pedestal level, and what the pedestal held is **the door itself** —
Thresk's door — plus its anchor stone. The Horns haul it back to the
inn; it is mounted over the pantry doorway. Closing line of fiction:
the doorway remembered its door.

Beats (order-gated; do NOT accept the catalyst-style cosmetic skip
here — this is the main line):

1. `trace` — fight what leaks through the cellar / ask Pisces / read
   the pantry doorway's wardwork (the three-path consult moved from
   the door chain; still banks `door_understood`).
2. `join_dig` — reach the ruin, find the Horns' camp; banks
   `horns_dig_joined` (new).
3. `breach` — three-path the sealed pedestal level (fight the
   pedestal's guardian arm / Ksmvr-style plate navigation for the
   stealth-social arm / a wardwork-reading skill arm — reuse the
   shipped ruin map with a dig-state variant, no new region).
   Banks `pedestal_breached` (new).
4. `haul` — the reveal + the trip home; banks `door_retrieved` (new)
   and `recovered_anchor_stone` (frozen id, kept — the stone comes
   home with the door). Door mounted: banks `door_mounted` (new);
   the pantry-door prop swaps to the mounted state.

Quest start: from Erin (the current door-chain start option in
erin_errand.json re-points here), gated on `seal_kept_reported`
(pilgrimage prerequisite: the Horns delve is done and reported).

The Ceria backstory scene from approach B is folded in as the dig-camp
conversation: how the expedition found the site, why the door matters.
Past-tense variant of the same arm serves migrated saves (§8).

## 4. The pilgrimage spine (`follow_the_lattice`)

Purpose-driven: Pisces cannot read the seal under Liscor without three
things, and the door — reaching farther as it re-attunes — is how you
get them. Each stop uses the EXISTING region chain as the
"earn trust/access" body and adds one small capstone dialogue arm that
banks a lattice piece:

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
- **Progressive portal rows:** the Riverfarm row appears at
  `door_awakened`, Invrisil at `lattice_witch_lore`, Pallass at
  `lattice_hedault_reading`. Fiction: the door's reach grows as it
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

- Save has `door_awakened` but no `door_in_the_ruin` progress: backfill
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
2. Retrieval quest (`door_in_the_ruin`) + door-chain slimming + save
   backfill.
3. Pilgrimage spine + region capstone arms + ordering gates +
   progressive portal rows (+ re-pins).
4. Act V (#270 as amended) + seal-warden tuning cell.
5. Finale sequence + epilogue retirement.
6. Difficulty band retune sweep + harness cells (can ride 3–5).

## Open items (user-gated)

- Quest title ACKs: "The Door in the Ruin", "Following the Lattice"
  (working titles; ids follow repo convention once ACKed).
- Act IV title: keeping "What the Door Opened" (it now describes the
  whole act better than before) — flag if a rename is wanted.
- #270's B-side (Pallass return anchor) stays optional/separate; say
  the word to fold it into PR 4.
