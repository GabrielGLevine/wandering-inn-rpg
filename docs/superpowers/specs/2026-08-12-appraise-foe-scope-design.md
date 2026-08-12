# [Appraise Foe] scope narrowing — design

**Date:** 2026-08-12
**Status:** approved (user, section by section)
**Origin:** playtest triage 2026-08-12 → #445, plus the user ruling "[Observe] is
potentially too broad of a Skill … it effectively gates so much player information."

## Problem

One Skill gates nearly all world description, and only one class in thirty-five can
take it.

- 366 entities carry an authored `observe` string (253 props, 58 NPCs, 40 encounters,
  15 doors).
- `observe` is granted **only** by Tactician L1 (`data/classes.json`). No starting
  grant, no second class. Every other path through the game never reads any of it.
- The Skill was renamed `[Appraise Foe]` in the canon pass (id `observe` unchanged for
  save-compat), but its behaviour stayed universal: it reads kegs, plinths and shop
  signs as readily as it reads a foe. Name and behaviour disagree.
- The same over-broad tail causes #445: a prop with no interact arm falls through
  `interactions.gd` into `use_skill("")`, and the player is told they lack a Skill for
  an action that does not exist. 102 props are in that class.
- `observed_things` — banked on first appraisal of anything — is the entire
  Tactician→Strategist levelling spine, up to 126 observations at Strategist L16.

## Design

### §1 Scope

**[Appraise Foe] reads living things.** The `observe` arm in `field_skills.gd:151`
gains a kind filter: it banks and prints only for `npc`, `encounter`, and combat
targets. Used on scenery it answers with a scoped ambient line ("Nothing here is going
to fight you") rather than the world-read.

**Everything else reads free.** The armless-prop tail in `interactions.gd:191-198`
prints the entity's own `observe` string instead of routing to `use_skill("")`. All
253 prop strings become reachable by every class, and #445 closes as a side effect.

**Doors** print their `observe` when the door's gate is unmet — the locked path already
stops there, and interact otherwise transitions before the text could show.

**Grants:** `observe` is granted to **Tactician L1 and Diplomat L5**. Classes sharing
Skills is fine; the four-level gap plus the whole ladder built on it keeps the
Tactician's edge. Diplomat L5 currently grants `soothing_presence`; that level carries
**both** grants rather than sliding anything — multi-grant levels are already shipped
(Tactician L1 grants two), so no other rung moves.

**NPCs keep their gate.** Interact talks, unchanged; the read of the person stays the
appraiser's. This is the one place the design makes a class poorer than the status quo
(any non-Tactician/Diplomat can no longer be given that read), and it is accepted: the
Skill is appraisal, not conversation.

### §2 Gates

Seven props gate `requires_skill: "observe"`. The Skill **id is unchanged**, so their
`requires_skill` values need no edit — only the two multi-arm conversions and one
re-point below.

Kept single-arm on `observe` (all four are foe-reads, correct audience):
`nest_ledge`, `counting_house_watch`, `counting_room_watch_gap`, `counting_house_ledger`.

Converted to multi-arm `skill_uses`, following the shipped precedent
(`seal_kept_door` and `inn`'s `pantry_door` both accept `observe` **or** `detect_magic`):

| Prop | `skill_uses` arms |
|---|---|
| `illusory_floor_a` | `find_trap` (Rogue) · `keen_eye` (Archer) · `observe` (existing arm kept) |
| `dart_slit_a` | `find_trap` · `observe` (existing arm kept) |

No route closes, so no alternate-path audit is owed. Each arm needs its own toast — a
Rogue reading a wire and a Tactician reading a firing angle must not print the same
line.

Re-pointed: `hollow_true_knot` → `evil_eye` (Hedge Witch). Its read is occult, not
tactical ("the knot resolves into a price, tied off and unpaid"). Its toast still says
"[Observe]" — stale from the canon rename; fix in the same pass.

Rejected substitutes, recorded so they are not re-proposed: `battlefield_awareness` is
combat-only (`field: None`) and cannot gate a field prop without being made
field-capable; `dangersense` is thematically ideal and Tactician-held at L3, but is
`field: None` and drives the #446 overlay passively — making it hotbar-usable drags
that issue into scope.

### §3 Levelling spine

Narrowing the Skill cuts the `observed_things` pool from 366 to **98** (58 NPCs + 40
encounters), against thresholds of 78 (Tactician L12) and 126 (Strategist L16). The
existing ladder becomes unreachable, so the spine splits: appraisal carries the early
levels, landed tactics carry the late ones.

**New counter `tactic_used`**, minted exactly as the weapon families are. Tag
`battlefield_awareness`, `directed_strike`, `flanking_step`, `read_the_field` and
`phantom_barrage` with `"family": "tactic"`; `_tally_skill_use`
(`wi_combat.gd:961`) emits `tactic_used`. All five are activatable (`ap_cost` 0–3), so
all five can tally. No new banking path: `combat_banking._bank_action_tally` already
applies adversity weighting and repetition decay, so farming weak fights yields decayed
banks.

| Level | `observed_things` | `tactic_used` |
|---|---|---|
| Tactician L2–L5 | 3 / 6 / 10 / 15 | — |
| L6 | 20 | 4 |
| L7 *(flanking_step)* | 24 | 8 |
| L8–L10 | 28 / 32 / 36 | 12 / 17 / 22 |
| L11–L12 | 40 / 44 | 28 / 34 |
| Strategist L13–L14 *(phantom_barrage)* | 48 / 52 | 42 / 50 |
| L15–L16 | 56 / 60 | 58 / 68 |

Peak appraisal demand drops 78 → 60 (Tactician L12) and 126 → 60 (Strategist L16),
i.e. 61% of the 98-entity pool against today's impossible 129%.

**This table is a starting shape, not finals.** The early rungs (3/6/10/15) keep their
current values, which were tuned against a 366-entity pool and are now proportionally
~3.7× stiffer; they look reachable, but that is a read, not a measurement. The balance
program (#437's spine viability table, #441's re-fixturing) sets the real thresholds by
simulation. Approved by the user *subject to that rebalancing*. Both Tactician and
Strategist canonicals need re-pinning regardless.

### §4 Surface

**Code:**

- `src/core/field_skills.gd:151` — kind filter on the `observe` arm + scoped ambient
- `src/core/interactions.gd:189-198` — armless-prop tail prints `observe`; gate-unmet
  doors print theirs
- `src/core/combat/wi_combat.gd:961` — `_tally_skill_use` emits `tactic_used` for
  `family: "tactic"`
- `src/core/wi_game.gd:785` — `_resolve_observe_text` is unchanged, but its coverage
  widens: conditional `observe` (the `warren_mouth` / `rift_vermin_leak` counter swaps)
  must resolve on the free interact path, not only the Skill path

**Data:** `data/skills.json` (5 `family: "tactic"` tags; Appraise description and
`field_ambient` copy) · `data/classes.json` (Diplomat L5 grant; both ladders) ·
3 map props (2 multi-arm, 1 re-point plus its stale "[Observe]" toast).

**Risks, all accepted:**

1. **Save compatibility.** Existing saves carry `observed_things` earned largely from
   scenery; thresholds drop sharply, so a mid-game Tactician may gain several levels at
   the next sleep beat. Accepted: it is a forward jump, never a downgrade, and clawing
   back banked counts is worse than the jump.
2. **Toast volume.** 253 prop strings become free-readable; dense maps
   (`brothers_parlor` has four armless props in a row) may read as spam where they read
   as silence before. Needs a windowed machine-playtest pass, not a pin.
3. **Balance re-fixture**, per §3.

**Out of scope:** #446 ([Dangersense] overlay aesthetics) is deliberately untouched.
The class-expansion spec's pending [Eagle Eyes] name ACK is unrelated and stays pending.

## Verification

- Unit/QA pins: interact on an armless prop prints its `observe`; appraise on a prop
  gives the scoped ambient and banks nothing; gate-unmet door prints its `observe`;
  conditional `observe` resolves on the free path; `tactic_used` tallies once per
  qualifying combat use and banks through the adversity path.
- Multi-arm props: each arm prints its own toast and banks its own accomplishment.
- Balance: Tactician and Strategist canonicals re-fixtured; spine viability re-run.
- Machine playtest: dense-map toast pacing (risk 2), and the setup of a save that can
  reach Diplomat L5 to confirm the shared grant.

## Related

- #445 — "You don't know how to do that yet." on 102 armless props (closed by §1)
- #446 — [Dangersense] overlay reads as a HUD box (out of scope)
- #441 / #437 — balance program, re-fixturing and spine viability (owns §3 finals)
