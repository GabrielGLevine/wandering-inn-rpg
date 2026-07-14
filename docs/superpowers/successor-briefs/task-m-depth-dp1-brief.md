# Task DP1: the Adventurer's Guild interior + Selys relocation — M-DEPTH

## Goal
The first Liscor interior: `guild_door` (street 28,3) stops being a toast
and opens a real ~16x12 Guild map — desk, THE REQUEST BOARD as dressed
prop (mechanics are DP2's), notice wall, tables, 2-3 canon-flavored
adventurer walk-ons — with Selys RELOCATED from the street (26,4) to
behind the Guild desk. Her relocation is the task's ripple center;
enumerate its blast radius before touching anything.

## Plan text (verbatim, `docs/superpowers/plans/2026-07-06-m-depth.md` Task DP1)
**Files:** skeleton_scene.json (guild map ~16x12: desk, board, notice
wall, tables, 2-3 adventurer background NPCs [profiles first —
canon-flavored walk-ons, e.g. a Gnoll archer + a Drake duo; talk_pool 1-2
lines each]; `guild_door` becomes a real door [door_when NOT needed — the
Guild is public]; Selys MOVES from street (26,4) to behind the desk);
moods.json (warm bureaucratic card); dialogue: Selys's graph gains
desk-context lines; Olesm gains a Guild-interior presence variant? (trace
— he stays at the frontage; a pool line references the desk).
**QA:** `guild_interior_walkthrough` canonical; re-path the Selys-touching
scripts (disclosed set — quest_errand_* end at Selys!); windowed reads.

## Plan global constraints that bind DP1 (same plan, verbatim)
- Canon dressing per wiki (Liscor's Guild/barracks/inn layouts are
  described — verify at content time); direction card per interior;
  profiles for any NEW NPC first.
- Disclosure discipline: Selys's relocation reds
  gate_district_walkthrough + any script interacting with her at (26,4) —
  enumerate FIRST.
- Suite count per CLAUDE.md at execution.

## Staged content you consume (do NOT re-write what's staged)
`docs/archive/staging/board-staging/board-copy.md`:
- §2 "Selys — board-adjacent desk lines" — her desk-context graph
  extensions, voice-linted, lift VERBATIM (register: dry, competent,
  secretly soft-hearted).
- §1 board framing copy — the board PROP's dressing lines are usable in
  DP1 (a plain-interact/observe surface); the posting graph itself is
  DP2's (fed from `guild-bounties.json`, which you do NOT touch).
- The Tekshia canon note (§1): the Guildmistress stays OFFSTAGE — a
  signature ("— S.S." footer) and a warning, never an NPC. Do not place
  her.
New walk-on NPCs need PROFILES FIRST: check
`docs/design/character-profiles.md` + `character-profiles-staging.md` for
existing entries; author missing walk-on profiles (short form, canon
races/naming per wiki) BEFORE writing their talk_pool lines, and voice-lint
the lines.

## Design decisions already made
- Door pair via the sewers precedent: `guild_door` (street) ↔ a return
  door inside the guild map; return-cell integrity is a known review hunt
  (walking in then out lands you on a sane street cell, not inside a
  wall). `door_when` NOT needed — the Guild is public.
- The current `guild_door` entity is a TOAST prop — its exact toast text
  is pinned in `gate_district_walkthrough` (and possibly elsewhere): the
  conversion moves that pin. Grep first.
- Selys behind the desk keeps her ENTIRE existing surface: her talk_pool
  (shipped, 4 lines — `chatted_with_selys` must keep accruing), her
  conversation graph (+ the staged desk-context lines), her role as
  quest_errand_* endpoint. Relocation = same entity id, new map+cell —
  verify save-compat (an old save's `removed_entities`/accomplishments
  must not resurrect a street-Selys ghost; trace how entity placement
  loads).
- Walk-on NPCs: `talk_pool` 1-2 lines each, `inert`-adjacent dressing —
  NO quests, NO graphs v1. Sprites: reuse/park per `wi-art-and-sprites`
  conventions; check `.superpowers/sdd/progress.md` for the PARKED
  expansion art batch (character sets were pre-generated 2026-07-06 —
  integration happens per-milestone from the park; if suitable adventurer
  sprites are parked, integrate rather than generate).
- moods.json: "warm bureaucratic" card (the direction-card convention —
  every interior ships one; the mood grade is B1's machinery).
- `guild_interior_walkthrough`: a walkthrough's ROUTE is its subject, so
  an organic start is legitimate (the FIXTURE-FIRST policy's carve-out) —
  but a `near_guild` fixture start is cheaper and re-derivation-proof;
  implementer's call, disclosed. Assert: door in/out round-trip, Selys
  desk interaction (pool line absorb + graph), the board prop's dressed
  surface, one walk-on pool line, mood applied
  (`ui_mood_applied{guild,...}` if the card wires that event — trace B1's
  atmosphere_check idiom).

## HAZARD: the Selys blast radius (enumerate BEFORE editing)
Grep `qa/scripts/*.json`, `qa/fixtures/*.json`, `tests/`, and
`data/skeleton_scene.json` for `selys` AND for her cell (`26` near `4` /
the literal `[26, 4]` / `26,4`). Known members of the set (verify, the
tree may have moved since this brief was written):
- `gate_district_walkthrough` — asserts Selys at (26,4) on the street +
  her surfaces; also pins the old `guild_door` toast.
- `quest_errand_fight` / `quest_errand_parley` — END at Selys.
- The S4 pool-absorb re-paths — `dialogue_hub_loop`,
  `save_load_roundtrip`, and any other script whose first-talk-of-waking
  hits Selys now does it WHEREVER she stands: each needs its route
  extended through the Guild door (or a fixture conversion — FIXTURE-FIRST
  is ratified policy; a heavy re-path is a conversion candidate, disclose
  per script).
- `social_loop` phase A talks to Selys — check its route.
Decide per script: re-path (add the door leg) vs fixture-convert. Every
change disclosed with its seed status (routes without combat usually hold
their seed; anything reaching combat needs the pinned-seed re-check).

## Binding constraints
- OPACITY; stats hidden; visible currencies only. No progress leaks.
- Voice lint every NEW line you compose (walk-on pools, any connective
  copy): banned-tell list in
  `.claude/skills/wi-adding-dialogue-and-quests/SKILL.md`; staged Selys
  copy ships byte-verbatim.
- Canon: wiki-verify the Guild-interior dressing claims and walk-on
  naming (WebFetch `https://wiki.wanderinginn.com/...`; annotate verdicts
  in the report, the gear-staging `[CANON-VERDICT]` style).
- Blocking/reachability per `wi-adding-a-scene` if loadable (minimum: BFS
  sanity — every interactive entity reachable, no walk-through-wall, door
  cells open on both sides).
- Zero-warning; GDQuest style; additive events; commit `*.uid` for new
  `.gd` files.

## Successor safety rails (spelled out — do not skip)
1. **Ledger first:** `tail -40 .superpowers/sdd/progress.md` — confirm the
   Skills wave + Social II state; if DP1 already appears, reconcile.
2. **Exact-pin discipline:** grep before edit (the Selys sweep above +
   every toast/option text you move); same-edit pin updates; report every
   pin old → new.
3. **Registration conditional on ARCH-1:** if
   `wandering_inn_game/qa/manifest.json` exists it is the single source of
   truth — register `guild_interior_walkthrough` there per its convention;
   else BOTH `wandering_inn_game/CLAUDE.md` lists AND `qa/ci_sweep.sh`'s
   CANON, counts bumped everywhere. Count, never trust hardcoded numbers.
4. **Alarm-wrap every run** (failed asserts HANG; macOS has no `timeout`):
   `perl -e 'alarm 120; exec @ARGV' /usr/local/bin/godot …`; kill >2min
   runs, read partial output.
5. **Zero-warning grep:** `SCRIPT ERROR|Parse Error|WARNING` on every
   run's output; never `^PASS` alone.
6. **Windowed shots READ by eyes** — a new MAP is the most visual change
   there is: sprite anchors, tile seams, label placement, "could a
   stranger find the door?"; `qa_output/<script>/` clobbers per re-run —
   copy PNGs out immediately, then look.
7. **Voice lint** (rail 3 of Binding constraints — repeated because copy
   hides in map data: prop toasts, observe lines, door labels).
8. **Worktree-merge intersection rule:** `skeleton_scene.json` is the
   repo's highest-contention file (the K1/L2 clobber happened there) —
   file-map intersection vs `git status` AND live-lane reports before any
   copy-merge; re-gate the MERGED tree; in doubt serialize.
9. **NO-COMMIT implementers;** controller stages explicit lane-reported
   paths; never `git add -A` while a lane is live.
10. **CLAUDE.md sections by NAME** (slimmed); per-script routing detail may
    live in `wandering_inn_game/docs/QA-SCRIPT-NOTES.md` if it exists.

## Verification (FOREGROUND, alarm-wrapped, sequential — never background
## a run and wait; notifications cannot reach you)
1. load_gate + smoke (a malformed map fails here first).
2. test_content + test_sim_core + any touched suite individually, grep
   discipline.
3. `guild_interior_walkthrough` (new) + EVERY script in the disclosed
   Selys set at pinned seeds + `gate_district_walkthrough` +
   `tutorial_flow`.
4. Full `bash wandering_inn_game/qa/ci_sweep.sh`.
5. Windowed `guild_interior_walkthrough`: the interior, the desk+Selys,
   the board prop, a walk-on; PNGs to
   `/Users/gabriel/wandering_inn_rpg/.superpowers/sdd/fp-handoff/dp1-shots/`,
   READ them.

## Report contract
- NO commit, NO git add. Full report to
  `/Users/gabriel/wandering_inn_rpg/.superpowers/sdd/fp-handoff/task-dp1-guild-report.md`:
  files touched, the map layout (cells, doors, entities), the Selys
  blast-radius table (script → re-path/fixture-convert → seed status),
  every pin moved, the canon-verdict notes, profiles added, gate table,
  shot names.
- Return only: status, one-line test summary, concerns.

## After DP1 (pointer — the rest of M-DEPTH follows the plan)
DP2 (THE REQUEST BOARD — the mechanical payoff; staged data READY at
`docs/archive/staging/board-staging/guild-bounties.json` incl. a BINDING
delta-since-accept condition-semantics note in its `_comment`, + board
framing copy §1) → DP3 (inn upstairs + your room) → DP4 (Watch barracks +
market depth) → DP5 (Runner's Guild; staged
`board-staging/runner-deliveries.json` rides DP2's machinery) → DPF (gate
+ opus review; the plan's opus hints name the review hunts). Execute each
from `docs/superpowers/plans/2026-07-06-m-depth.md` under this brief's
same safety rails.
