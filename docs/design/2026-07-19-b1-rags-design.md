# b1 Rags — design (2026-07-19, Fable; #199 step 2)

Audit: docs/design/2026-07-19-b1-rags-conduct-audit.md. Canon: early-volume
Rags — small Goblin chieftain, Flooded Waters tribe, wary of Humans, sharp;
chess-with-Erin is attested and fair game. Spoiler bar Book 17 / Vol 7
advertised; never the Vol-9 door name.

## 1. Conduct banks (new producers, ships first)

- goblin_parley "(Back away slowly.)" gains effects:
  `goblin_left_in_peace` (NEW counter) + `goblins_spared` — honoring the
  parley file's own contract ("every future nonviolent goblin route must
  also bank it"). ADJUDICATED (CHOICE-LOG): outcome-based mercy — Erin's
  sign cares that goblins live, not how bravely; the garden's
  goblins_spared leg becomes pacifist-reachable (no Warrior 1 needed),
  which is thematically correct, not drift.
- The b3 parley talk-downs (separate package) bank `goblins_spared` on
  their goblin arms per the same contract when they land.

## 2. Gates (both must hold; encounter uses `present_when`)

- **(a) Erin relationship**: `reward_acknowledged >= 1` (the errand chain
  closed warmly) AND `chatted_with_erin >= 3` (repeat conversation, not
  drive-by). Derived from existing counters only — no new grind. Data
  thresholds; tune via trace measurement.
- **(b) Goblin conduct**: `goblins_spared >= 1` AND zero-aggression
  window: `fought_goblin_encounter_1 + fought_goblin_encounter_2 +
  fought_goblin_night_patrol + fought_chieftains_raid == 0` is TOO
  strict (the tutorial arc pushes goblin_encounter_1 defense — sign
  fight is self-defense in canon terms). RULING: conduct = mercy shown
  at least once AND no goblin kills SINCE the first mercy — expressed as
  a delta gate? Delta machinery doesn't exist for present_when. V1 CUT:
  `goblins_spared >= 1` and NOT `chieftains_raid` completed
  (`fought_chieftains_raid == 0` — the one unambiguous aggression: you
  hunted their camp). present_when supports counter reads; absence-of-
  counter gates exist (hide_when idiom). Simple, readable, canon-fair.
  Flag in CHOICE-LOG for the user (the exact "friendly enough" bar is
  taste).

## 3. The encounter (floodplains south — goblin territory)

- New entity `rags_scouting_party` (kind encounter, conversation-first:
  `rags_meeting` graph) at the southern floodplains edge;
  `present_when` = the composed gate above. NOT a fight-first entity —
  interact opens dialogue; a combat CLOSE exists but is the failure-ish
  path (three-pillars: talk / help / fight all real).
- Cast: Rags + two goblin warriors (existing goblin_raider sprites for
  the escort; Rags sprite = c3 bespoke, INTERIM: ships with the goblin
  chieftain sheet + distinct tint + display_name "Rags" — flagged in
  VISUAL-LOG for the c3 swap; wi-art-and-sprites placeholder rules).

## 4. The quest — "The Chieftain's Price" (working title, invention-flagged)

Shape (mirror of shipped multi-path quests; all machinery exists):
- START: the meeting banks `met_rags`; quest auto-starts (start_quest on
  the dialogue close, erin_errand precedent).
- PROBLEM (canon-fair, invention-within-gap): her tribe needs medicine/
  supplies for wounded goblins after a Watch sweep — she won't beg,
  offers trade: a carved chess piece (chess = the attested Erin link).
- PATHS (`resolution_paths` + #211 `resolution_grant`s, path-exclusive):
  1. **SUPPLY (helper/social)**: bring poultice/rations (existing items;
     alchemist bench crafts qualify) → `helped_rags_tribe`.
     Grant: {persuaded_someone: 3, befriended_moments: 4, heard_gossip: 3}.
  2. **BROKER (social)**: talk Krshia/Erin into quiet trade goods (gold
     cost, the sanctioned fee band) → `brokered_goblin_trade`.
     Grant: {persuaded_someone: 4, heard_gossip: 5}.
  3. **FIGHT (the betrayal path)**: draw steel at the meeting →
     `drove_off_rags` — closes the quest COLD (no reward, Erin
     relationship consequence: her sign line hardens via talk_pool_stage
     on the counter; garden leg unaffected — mercy already shown once).
     Grant: {melee_hit: 8, won_combat: 1} (combat line paid, smaller —
     ambush of a parley is not adversity).
- REWARD (peaceful closes): the carved chess piece = accessory item
  (small CHA-flavored resonance piece, #92 economy band) + Rags's camp
  becomes a repeatable talk-pool visit (rotation idiom); chess nod line.
- Journal/beat copy stays OBLIQUE per canon-reveal precedent.

## 5. QA + acceptance

- New canonical `rags_meeting_loop` (fixture pre-holding both gates):
  gate visibility (present_when flip), conversation open, SUPPLY close,
  grant deposit assertions, chess-piece in inventory. A second arm
  (fixture WITHOUT conduct gate) asserts entity ABSENT (can-fail proof
  built in). Registration: manifest + AGENTS seed table + notes render.
- Balance: the FIGHT close's encounter cell (rags + 2 escorts vs the
  gate-era build) sim-gated 0.55–0.95; Rags herself flees at low HP
  (coward profile — canon: she is a survivor, not a boss).
- Conduct-bank edits re-gate: parley-crossing canonicals + garden
  scripts (goblins_spared producer widening → garden_walkthrough,
  climax scripts using the leg).

## 6. Execution order

1. Conduct banks + parley edit (+ re-gates) — small PR, unblocks b3 too.
2. rags_meeting graph + entity + gates + quest + grants + interim sprite.
3. rags_meeting_loop canonical + fixture pair + sim cell.
4. VISUAL-LOG row for the c3 bespoke swap.
CHOICE-LOG: the conduct-bar cut (§2b), the outcome-based mercy ruling
(§1), quest title/problem invention flags (§4).
