# Friends of the Inn PR2 — implementation spec (2026-07-20, Fable)

TRACKING ISSUE: #269 (the dispatch brief points here).

Extends the shipped guest rotation (PR #261) to the remaining four
roster NPCs. Two PRs: **PR2a = Olesm + Pisces**, **PR2b = Relc +
Zevara**. Evidence-verified against the shipped mechanism; every file
path below was read this session.

## The shipped contract (do not re-derive)

- `present_when.guest = {npc, roster, seats}` on a `kind:npc` entity;
  met = `chatted_with_<npc> >= 1`; evaluated in
  `wi_game._present_gate_met` (phase now composes as a fall-through
  AND). Rotation: `WIInnGuests.active_guests` windows
  `mini(seats,pool)` DISTINCT met-pool members in FIXED roster order,
  start `= times_slept % pool`; smaller-pool → trailing seats empty.
- **Co-located roster validator** (test_content ~line 426): every
  guest entity on the inn must carry an IDENTICAL `{roster, seats}` —
  so EACH PR edits the roster array in ALL prior guest entities in the
  same commit as its new rows.
- Conversation contract: fresh 3-node `<npc>_inn.json`
  (greet / one off-duty topic / served), attached ONLY to the guest
  row, NO talk_pool on the row (so interact opens the conversation
  directly). Serve option on greet AND the topic node:
  `requires {once_per_waking: "serve:<entity_id>", item: "hot_meal"}`,
  effects `[{bank_first_use}, {accomplishment: served_customer},
  {gold: 2}, {remove_item: hot_meal}]` — four separate one-verb dicts.
- Guest rows are REGISTER-PURE. Home-only mechanics that must never
  ride the guest row: Olesm = the chess arc/wager + briefings;
  Pisces = magic tutor, necromancy pupil, ALL door consults;
  Relc = spar + wager + gift + descent windows; Zevara = cisterns
  sweep, summons/dispatch, seal report, any Watch authorization.

## Roster order is APPEND-ONLY (rotation math depends on it)

`["selys","krshia","olesm","pisces","relc","zevara"]` — final order,
never reorder. Window math for `inn_guests_start` (times_slept=10,
fixture banks chatted_with selys/krshia/olesm/pisces/relc; NOT zevara):

| state | pool | start=10%pool | seated |
|---|---|---|---|
| PR1 (shipped) | 2 | 0 | selys, krshia |
| PR2a (roster 4) | 4 | 2 | **olesm, pisces** |
| PR2b (roster 6, zevara still unmet in fixture) | 5 | 0 | selys, krshia |
| PR2b full-pool fixture (all six met, t=10) | 6 | 4 | **relc, zevara** |

So: PR2a's canonical RE-DERIVES — boot seats olesm+pisces (proving the
new pair), then a **sleep leg** (t=11 → start=3 → pisces,relc-unmet→
pisces,selys) proves the rotation LIVE for the first time. PR2b keeps
`inn_guests_start` un-edited (zevara unbanked keeps pool 5 → the PR2a
pins that hold selys/krshia at t=10%5=0 stay... NOTE 10%5=0 seats
selys+krshia again — re-pin accordingly) and adds a SECOND fixture
`inn_guests_full_start` (all six met, t=10 → seats relc+zevara) for
the PR2b pair's legs. Every pin re-derived from a real run's
events.jsonl, never assumed.

## Seats

Two new seats at **(3,5)** and **(6,5)** — free floor, west of the
armed leak (9,7), off every pinned lane: boot cell (2,6), serve lane
(4,7)/(5,7)/(6,7) + hungry_patron (5,6), garden approach (3,7)→(3,8),
walkthrough diagonal (2,3)/(3,3)/(4,4), PR1 seats (6,6)/(4,6).
4 guests share 2 shift-seats? No — seats stay 2 TOTAL; the four
entities exist but only the windowed two render. New entities:
`olesm_inn_guest`(3,5), `pisces_inn_guest`(6,5),
`relc_inn_guest`(3,5), `zevara_inn_guest`(6,5) — seat cells may be
SHARED across entities because at most one of each pair is on shift
per the window... **NO — verify**: with 6 rostered and 2 seats, any
two adjacent-window members can co-render; assign FOUR distinct cells:
olesm (3,5), pisces (6,5), relc (2,5), zevara (3,6) (all in the free
set; screenshot-verify no crowding).

## Voice (profile blocks REQUIRED first, PR1 precedent)

Add four "Inn register" blocks to character-profiles.md before writing
dialogue:
- **Olesm**: earnest off-duty; chess-adjacent but NOT the wager (that
  is home-only) — he analyzes the ROOM like a board; self-deprecating
  about taking a night off.
- **Pisces**: haughty-thawing; performatively above tavern food while
  visibly enjoying it; no magic talk beyond deflection.
- **Relc**: loud + at-ease, off-shift hunger, "the good chair"; kind
  under it. 124px HUGE frames — windowed-verify the seated bulk.
- **Zevara**: dry, off-shift-but-never-off-duty; the register is a
  watch captain failing to relax; persuaded by nothing, warmed by
  competence (a well-carried tray earns one degree of thaw).

## Helper-pace gate (the #261 flag — evidence-driven, not speculative)

PR2a ships all-day guests, then runs `tests/sim_progression_pace.gd`
vs the baseline helper p50 bands (10/21/26). IF the Act-II overshoot
worsens: PR2b's first commit applies the flagged lever — evening
presence `present_when {phase:[dusk,night], guest:{...}}` for ALL SIX
guests (composes since the #247 fix; fits the off-duty fiction) with
the fixture migration (`actions_since_sleep` past the dusk threshold
so the canonical still sees guests) + PR1-pair retrofit. If the bands
hold, keep all-day and note the measurement in the PR body.

## Known cross-canonical exposure (from the census)

- `olesm_chess_loop` teleports INTO the inn at (5,7) with olesm
  rostered+met → his guest row may render mid-script (asserts dialogue
  events, not sprite counts — should hold; run it in the PR bar).
- `stage3_perks_loop` walks the inn with relc+selys met → same class;
  route avoids the seat cells; run it.
- Sprite-count canonicals (inn_walkthrough 16/0 fresh, horns 19,
  atmosphere_check flip) stay green ONLY while their fixtures bank no
  roster counters — unchanged, but re-run all five in each PR bar.
- Zevara has ZERO existing met-state QA coverage — her leg exists only
  via the new full-pool fixture.

## Per-PR checklist

1. Profile blocks → dialogue files (voice lint, dash budget, spoiler
   bar) → entities (roster edit in ALL prior guest rows same commit)
   → registry untouched (all four reuse registered home sprites; only
   Relc needs a windowed containment check).
2. Canonical re-derivation per the window table + rotation sleep leg
   (PR2a) / full-pool fixture (PR2b). All-three QA registration
   (manifest + AGENTS seed table + render_qa_notes) + derive_surfaces.
3. Full bar + the five exposure canonicals + windowed FEEL shots
   (both new guests seated, served-toast beat) → user FEEL gate →
   merge.

Est: M per PR. New frozen-at-next-cut counters: none beyond
`serve:<id>` first-use keys (entity_first_use, not accomplishments).

## Amendment (2026-07-26, user-directed wave expansion)

Roster grows APPEND-ONLY past this spec's six:
`[selys,krshia,olesm,pisces,relc,zevara,klbkch,rags,wilovan,grimalkin]`.
Klbkch gates on met only (`chatted_with_klbkch`). Rags/Wilovan/Grimalkin
gate on QUEST COMPLETION, not first-met: `rags_meeting_settled` /
`brothers_job_done` / `elevator_pass_stamped` — enforced BOTH in pool
membership (wi_inn_guests.gd GUEST_POOL_GATES) and on the guest row's
present_when.requires. Detail: Phase 5 of
docs/superpowers/plans/2026-07-26-main-quest-foti-wave.md.
