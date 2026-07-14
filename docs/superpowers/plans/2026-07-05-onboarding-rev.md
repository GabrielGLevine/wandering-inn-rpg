# Onboarding Rev Implementation Plan

> Status: **DONE** — executed; retained as a design record.

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Project skills READ-ONLY for subagents. Controller commits per green task.

**Goal:** The approved onboarding redesign (spec `docs/superpowers/specs/2026-07-04-onboarding-rev-design.md` §1-§9, user-approved + playtest addendum): classless start, Relc arms and TEACHES you, inert dummies, the ambush becomes a mandatory proximity-triggered tutorial part 2, Pisces teaches magic, every system gets its explaining beat.

**Plan-time state corrections (things the spec's earlier text predates):**
1. **M7 shipped real items** — Relc's spear gift is ALREADY a real `relcs_spare_spear` grant in `relc_intro` (E3); §1's "flavor beat + accomplishment until M7" hedge is dead. This plan re-stages WHERE the gift lands (part-1 close) and adds the teaching line (§9).
2. **Helper L1 cooking swap (spec §6) ALREADY SHIPPED** (wave A). Skip.
3. **Cellar "too dark" interim toast + grants-listing groundwork**: the locked_toast shipped (wave A); §4's grants-listing class toast is NOT yet shipped — it's task O4 here.
4. Canonical suite is 30 scripts; save VERSION 5; the sleep-phase system exists (irrelevant here but streams carry phase events).
5. M-BEAUTY R3 may remove floating labels BEFORE this executes — briefs must not rely on label-based windowed identification.

## Global Constraints

- Stats hidden; opaque-until-sleep (tutor/teaching lines carry NO numbers-toward).
- Canon: Relc voice per shipped graphs; Pisces Jealnv = Human [Necromancer] (wiki-check at content time).
- Tune data never sim, EXCEPT the two named sim seams below (trigger_radius; inert-AI profile) — both small, unit-tested.
- ONE QA re-path window (spec §3): the trigger-radius task discloses its expected-red set up front, Q-task closes it — M-FP W1→Q1 discipline verbatim.
- NO COMMIT by implementers; alarm-wrap; grep discipline; windowed reads controller-read.

---

### Task O1: classless start + warrior gained_by + inert dummies

**Files:** Modify `data/skeleton_scene.json` (player block: classes {} — read how classes seed today), `data/classes.json` (warrior gains `gained_by: {accomplishment: {sparred_with_relc: 1}}`), `data/combatants.json` (training_dummy: zero offense), `src/core/combat/combat_ai.gd` (an `inert` ai profile: never acts, ends turn — the ONE sim-adjacent addition; unit case), `data/arenas.json` if the dummy ai profile is arena-side (read where combatant ai profiles live), tests (progression + combat_sim cases), QA scripts that assume a level-1 warrior at boot (ENUMERATE first — work_loop asserts helper beats; combat scripts field warrior kits from fight 1: EVERY combat script now needs the spar-first prologue OR re-derivation... **DISCLOSURE: this is the biggest re-path driver — bundle its QA impact into O5's window, do NOT fix scripts here; run only load_gate/units/smoke + the scripts this task can keep green, list the expected-red set explicitly**).
- Classless boot: hotbar = Attack/Dash/End only (verify the hotbar builds from granted skills — empty classes = empty skill slots already? trace, don't assume).
- Warrior L1 fires at first post-spar sleep (mage gained_by precedent).
- Dummies: 0 damage + inert profile (user: no block mechanics = no reason they move).

### Task O2: proximity trigger + no-corridor ambush placement

**Files:** Modify `src/core/wi_game.gd` (encounter `trigger_radius: N` — Chebyshev check after successful move; fires start_combat like interact does; respects ally_requires/dormant semantics), `data/skeleton_scene.json` (goblin_encounter_1 gains trigger_radius + placement so every path to liscor_gate crosses the zone — compute the corridor-free placement against the merged blocked set; other encounters stay interact-only), tests (sim cases: trigger fires on entry, not on adjacent-but-outside, dormant respawner doesn't trigger, met_relc gate unaffected).
- **DISCLOSURE:** every road-crossing canonical script red until O5. List them.

### Task O3: tutorial beats rev (part 1 + part 2 content)

**Files:** Modify `data/dialogue/relc_intro.json` (gift moves to part-1 close + the §9 teaching line "equip via I" + soft-gate: facing Relc unequipped-spear gets a nudge line — hide_when/requires per dialogue rules), `data/arenas.json` (training_yard tutor_lines rev: attack-prompt beat added, skill-explain beats MOVED OUT [PC has no skills in part 1]; goblin_encounter_1's arena gains part-2 tutor_lines: skill use [Power Strike]/[Piercing Strikes] explained, fielding Relc), `data/dialogue/dummies_note.json` if the spar copy shifts. Opacity audit per D2-5 precedent.

### Task O4: Pisces + grants-listing toasts

**Files:** Modify `data/skeleton_scene.json` (pisces npc at the Guild frontage — canon sprite call: a_hunter-class stand-in tinted? CHECK sprites; VISUAL-LOG if stand-in), NEW `data/dialogue/pisces_magic.json` (magic explainer beats banking `learned_magic_from_pisces`), `data/classes.json` (mage gained_by → the new accomplishment; dusty_scroll retires to flavor — its used_magic effect stays harmless or converts to flavor toast, decide + document), `src/core/wi_game.gd` sleep-beat toast construction (class_gained toast lists granted skills: "[Mage] class gained! — [Light], [Frost Bolt]…" — copy exact, no numbers), QA: mage_unlock_loop + lantern_check + crate_light re-route through Pisces (their scroll prologues die — this task OWNS those three script rewrites; seeds re-verified).

### Task O5: THE RE-PATH WINDOW (Q-task; immediately after O1-O4 land)

**Files:** `qa/scripts/*` + `wandering_inn_game_v4/CLAUDE.md`.
- Every combat script gains the spar-first prologue (classless boot → meet Relc → spar → sleep → warrior L1) or a fixture that starts post-tutorial (fixture edits allowed, position/progression fields per the established rules — a `post_tutorial` fixture is probably the cheap path for the deep loops: DESIGN CALL baked here: build ONE shared post_tutorial fixture save + route fixture-loading scripts through it; walk-in scripts get the real prologue).
- Trigger-radius re-paths (O2's set). New canonical: `tutorial_flow` (the full part1→sleep→part2 arc, the onboarding's own proof). Seed searches documented; both CLAUDE.md tables updated.

### Task OF: gate + docs + opus whole-branch review

- Full sweep (all canonical + tutorial_flow) + units + harness (warrior1_tutorial_solo cell semantics change: solo classless vs solo warrior1 — re-derive the cell definitions to match the new start; document) + web parity + windowed set (controller reads: the full new-player arc frame by frame).
- HANDOFF playtest checklist: the cold-start experience (THE test: hand it to someone who's never seen it).
- Opus review method hints: save-compat (old saves have classes — classless start only affects NEW games; migration untouched — verify), trigger×defeat×reload composition, the soft-gate edge (refuse-to-equip path), Pisces graph gating.

## Self-review notes
- Spec §1-§9 → O1 (§1,§2-dummies), O2 (§3-trigger), O3 (§2/§3 beats + §9 teaching), O4 (§4/§9), O5+OF (window+gates). §5 interim + §6 already shipped. §8 opens resolved: death-teaches accepted (revisit at playtest); PC-death=defeat already shipped (wave A2) — part-2 defeat = clean reload, no mask.
- Biggest risk: O1+O2's combined expected-red set — O5 budgeted as the M-FP-Q1-class task it is.
