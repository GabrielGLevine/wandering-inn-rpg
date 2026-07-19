# d1 — Friends of the Inn spec (#247; user idea 2026-07-19) — USER READ GATES IMPLEMENTATION

Met canon NPCs rotate through the Wandering Inn as servable guests.
This spec is the go/no-go artifact; nothing implements until the
flagged asks at the bottom are answered.

## Roster + gates (census verified)

Rotating pool (all currently single-row, ungated, met via their own
counters): **Selys** (guild desk; met = chatted_with_selys ≥ 1),
**Krshia** (street stall), **Olesm** (street), **Pisces** (street),
**Relc** (floodplains), **Zevara** (street gate). Erin + Lyonette are
residents, not guests. The Horns trio already does gated inn residency
(`present_when` rows, horns_residence canonical) — that is the
presence mechanism, proven. `hungry_patron` is the servable-guest
mechanics precedent (once-per-waking serve keys).

## Mechanism

1. **Guest slots**: two inn seats (cells TBD off the common-room
   table band; must dodge the walkthrough lanes — the Relc #201
   playbook). Each slot is a NEW entity row per NPC
   (`selys_inn_guest`, ...) with `present_when {requires:
   {chatted_with_<npc>: 1}, slot: ...}` — presence derives from a
   deterministic rotation: `guest_for_slot(slot_i) =
   met_pool[(times_slept + slot_i) % met_pool.size()]`, zero-rng,
   assertable via assert_state (board/fence slate precedent). Needs
   ONE small sim arm (the rotation function + a `present_when` guest
   arm) — this is the only new code; everything else is data.
2. **Context awareness (the user's hard requirement)**: guest rows
   carry their OWN talk pools and (where warranted) small
   conversations in an INN register — the home conversation NEVER
   attaches to a guest row. The named example holds: Selys-at-the-inn
   has no "board's over there" surface because her guild hub simply
   isn't reachable from the guest entity. Each guest gets 3-4
   inn-specific pool lines (off-duty registers; Gnoll lines may use
   the ", yes?" palette) + one serve-ack line.
3. **Servable**: each guest row banks a once-per-waking serve
   (`served_<npc>` + the shared servings/helper counters —
   hungry_patron's exact key shape), so Helper play pays real faces.
4. **Double presence ADJUDICATION (recommendation: accept for v1)**:
   home rows stay ungated. Gating six home rows costs a QA re-derive
   across 43+ street-crossing canonicals plus guild/floodplains sets
   (per-NPC #201-scale packages), and the shipped game already
   tolerates Relc's descent-window double presence (b7 review,
   adjudicated). Wakings are abstract; the guest register reads as
   "evening at the inn". If a specific NPC's double presence reads
   wrong in playtest, gate THAT one as its own #203-style package.

## QA plan (the real cost)

- New canonical `inn_guests_loop`: rotation pins across 2-3 sleeps
  (assert_state on the derived slate), one guest pool-line pin, one
  serve leg (counter + toast + once-per-waking spent).
- Inn sprite-count pins: inn_walkthrough / work_loop /
  upstairs_walkthrough pin 16 rendered sprites — two occupied guest
  slots move it to 18 in their fixture states IF those fixtures meet
  any met-gate (audit per fixture; fixtures with zero chatted_with_*
  counters render 16 unchanged — likely most of them, since fixtures
  are minimal). Deep-derive before authoring, not after.
- test_content: guest pools/gates cross-ref automatically; the
  rotation arm gets sim_core units (pool of 0 → empty seats; 1 → one
  guest both slots? no — slot dedup rule: a pool smaller than the
  slot count leaves later slots EMPTY, never duplicates a person).
- Voice: per-profile inn registers, canon-checked; profiles updated
  with an "inn register" note per NPC in the same PR.

## Split

PR 1: rotation sim arm + the two seat rows for TWO pilot guests
(recommend Selys + Krshia — the user's named example + the Gnoll
palette showcase) + canonical + pins. PR 2+: remaining four guests,
one PR per pair, pool copy per profile. Est. M per PR.

## USER ASKS (answer any; silence = defaults in bold)

1. Roster: the six above? Add/remove anyone? (**six as listed**)
2. Seat count: **2** (1 = quieter inn; 3 = busier + bigger pin wave)?
3. Double presence: **accept for v1** (gate per-NPC later if it reads
   wrong) — or gate home rows now and eat the re-derive waves?
4. Pilot pair: **Selys + Krshia**?
