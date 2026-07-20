# Door-chain continuation — "What the Seal Was Feeding" (2026-07-20, Fable)

TRACKING ISSUE: #270 (the dispatch brief points here).

The next story beat after `door_awakened`. Evidence-verified spine:
every loose thread below is a shipped, unconsumed surface (paths read
this session). Working title only — the quest NEVER names the door
anything but "the Magical Door" (Vol-9 name banned; Book-17 bar on all
new material; oblique-Thresk lore precedent for anything the wiki
doesn't attest).

## Where the story visibly stops today

Act IV "What the Door Opened" has a defined `advance_when` with NO Act
V behind it (acts.json:37-49) — the slot is literally reserved. The
player fast-travels (6 portal rows), banked `seal_kept_reported`
("A construct, a vault, and ANOTHER rune-door… Nothing good."), the
Horns moved into the inn, and `seal_kept_door` (trapped_halls.json:
331-355) sits shut with NO `door_when` — a prop that can never open.
PR #268 added the fuse: Pisces' treatise beat ends on "bound, FED, and
waiting a very long time. Be alarmed." — `scroll_secret_shared` is an
unconsumed terminal.

## The spine (three beats, each with the 3-path parity the chain set)

### Beat 1 — "Bring your own rope" (the descent ask)
New Pisces greet option, gated `{heard_pisces_second_door: 1}` +
hide_when the beat's own counter. The treatise leg
(`scroll_secret_shared`) is an OR-enrichment, NOT mandatory (keeps the
[Mage] line optional, mirroring the chain's parity convention): with
it, Pisces connects treatise→second door explicitly; without it, his
own curiosity carries the ask. He wants to READ the second door in
person; the player escorts him down (Ceria's shipped "bring his own
rope" pool line is the pre-echo; Yvlon's "If the door down there
opens, I want to be standing in front of it" is pre-written consent
for an optional Horns presence flavor arm). Banks
`second_door_descent_agreed`; starts quest `what_the_seal_was_feeding`
(new, quests.json, region Liscor, 3+ beats — order-gate the beats or
consciously accept the catalyst-style skip; DECIDE at implementation
and comment it).

### Beat 2 — the reading (the detected_wardwork quartet pays off)
At `seal_kept_door` with Pisces' escort armed: the door gains
`skill_uses` arms (the PR #268 mechanism, zero sim work):
- `observe` → the runes match the pantry door's hand — banks
  `read_the_seal_runes`.
- `detect_magic` → THE QUARTET PAYOFF: the four shipped
  `detected_wardwork` sites (pantry door, ruin socket, trapped-halls
  seam, witch hollow) finally read together — they are one WARDING
  LATTICE, and the seal is not a lock, it is a FEEDING ward: something
  behind the door has been fed a trickle of mana for a very long time
  (fits item lore: "the same crude trick that woke somewhere it
  shouldn't have, once"). Banks `read_the_feeding_ward`. Gate the
  richest text on `detected_wardwork >= 3` as a text_variant (reward
  the literate player; base text still lands the fact).
- Interact (no skill) → Pisces narrates the minimum (the GDI/door
  never speaks; Pisces is the voice, per the Global Constraint).
Both reads (either suffices — OR-producers) unlock Beat 3.

### Beat 3 — the choice (open it, or feed it properly)
Three real-cost paths, all banking `seal_resolved` (+ a path-specific
counter for text_variants downstream):
- **FIGHT — open it**: `seal_kept_door` gains `door_when` gated
  `{seal_opened: 1}`; the opening wakes the seal's warden — a NEW
  encounter (`encounter_when {seal_opened:1}`, visible-but-inert
  foreshadow BEFORE arming per the rift-vermin pattern; reuse/retint
  the `ruin_warden` rig at ward scale — roster-only, new combatant id,
  gated 0.55-0.95 harness cell). Behind the door: ONE room (small map
  `dungeon/seal_vault.json` or a walled extension of trapped_halls —
  prefer the new small map; wi-adding-a-scene validators) holding what
  was fed: the payoff chamber — Thresk-oblique lore terminus + a real
  reward (candidate: the Pallass RETURN-ANCHOR RUNE — see B-side).
- **TALK — study it sealed**: Pisces argues the ward is safer fed;
  a [Charming Smile]/gold-alternate fork (the witch pattern: Skill
  visible-locked + priced alternate) to convince OLESM's civic dread
  (his shipped seal_kept_report line is the hook) to post a Watch
  seal-warden bounty instead — banks `seal_kept_fed`; the door stays
  shut, the reward arrives as the bounty chain + lore.
- **SKILL — re-ward it properly**: `detect_magic`/`hedge_witch`-class
  arm re-cuts the feeding ward ([Hedge Remedy]/[Detect Magic] gate,
  requires_item a warding token — `guardian_ward_fragment` already in
  hand from the vault) — banks `seal_rewarded`; same closed-door
  outcome, different fiction + the fragment consumed (real cost).
Opaque-until-sleep holds: any sleep-adjacent banking stays silent
except the banking sleep.

### Act V
`acts.json` gains act_v ("What the Seal Was Feeding") advancing on
`seal_resolved` — filling the reserved slot; act_iv's derived beats
gain the new quest's line.

## B-side (separate PR, optional): the Pallass return anchor
`pallass_market_arrival_anchor` is a blank plinth "waiting on a rune
nobody has carved yet" — shipped copy pre-stages the beat. The FIGHT
path's chamber (or the TALK bounty chain) yields the rune knowledge;
carving it makes Pallass round-trip: plinth gains
`portal_menu + portal_menu_when {requires:{pallass_return_carved:1}}`
+ a portals.json row. WARNING (from the census): a new portal row
changes the menu OPTION ORDER on EVERY carrier — pallass_walkthrough
+ portal_menu canonicals pin the exact order; re-pin in the same PR.
Also: copy the `portal_menu_when {requires:{...}}` WRAPPER correctly —
invrisil_boulevard.json:903 ships a bare `{door_awakened:1}` that is
vacuously true (masked); do not clone that shape.

## Hard constraints (all from shipped rulings)

- Book-17 bar; "the Magical Door" only; the door prop NEVER speaks;
  oblique lore (Thresk precedent) where the wiki is silent; no door
  mana-simulation, no moving the door, no inter-continental rows.
- present_when is validator-FORBIDDEN on encounters (encounter_when
  arms fights; foreshadow stays visible-inert).
- New counters: name for the freeze at first write
  (`second_door_descent_agreed`, `read_the_seal_runes`,
  `read_the_feeding_ward`, `seal_opened`, `seal_kept_fed`,
  `seal_rewarded`, `seal_resolved`, `pallass_return_carved`); all ride
  plain accomplishments (zero save.gd plumbing).
- QA blast radius: door_chain_* fixtures carry pinned rng_state (any
  combat retune re-derives via tests/_derive_rng_state.gd); the new
  map needs blocking/reachability validators + a gated harness cell
  for the warden fight; every new dialogue surface = test_content
  auto-crossref + a canonical leg (one new canonical
  `seal_resolution_loop` with three fixture starts, mirroring the
  cisterns_talk/fight/scout triple).

## Scope + order

PR A: Beat 1 + 2 (dialogue + skill_uses arms + quest shell) — data
only. PR B: Beat 3 + the room + the warden + Act V (map + encounter +
harness cell). PR C (optional): Pallass return anchor. Est: M, M-L, S.
