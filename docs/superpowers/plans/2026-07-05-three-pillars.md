# Three Pillars / World-Skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Project skills READ-ONLY for subagents. Controller commits per green task.

**Goal:** The approved Three Pillars v1 (spec `docs/superpowers/specs/2026-07-04-three-pillars-world-skills-design.md` §2-§6): the overworld hotbar (field skills, facing-cell + ambient), [Tactician] as the cerebral earned multiclass, and the carried content debts — non-combat play becomes a first-class pillar.

**Plan-time state corrections:**
1. **Helper line + slice content SHIPPED** (slice T1-T3): Helper/Barmaid/Server classes, work-loop, Missing Crate, `studied_the_cellar` seam — all live. This plan ships what remains.
2. **Toast queue (the slice review's REQUIRED follow-up) SHIPPED** (90f4d85). Skip.
3. Carried debts owned here: Barmaid/Server L10 evolution grants (empty vs the 2-skills precedent); `warrior2_helper2` measured harness cell; exploration-pillar thinness (the audit's flag — [Observe] + the hotbar are the fix).
4. The journal skills panel + used_skills reveal (UI wave) exists — [Observe]/field skills integrate with it for free; first-use reveal applies.
5. M-BEAUTY R3 removes floating labels — [Observe]'s info toast becomes MORE valuable (the sanctioned way to "inspect" a thing); brief P2 accordingly.
6. Save v5 current; 30+ canonical scripts; onboarding rev may land first (order per ladder) — plans are independent except both touch relc_intro-adjacent content: THIS plan touches none of it. No file collision.

## Global Constraints

- Stats hidden; opaque-until-sleep; [Observe] toasts are flavor/info, NEVER numbers-toward or raw stats.
- Canon: [Tactician] + kit skill names wiki-checked at content time; fallbacks escalate, never invent.
- The ONE engine surface: `field` skill dispatch in `WIGame.use_skill` growing facing-cell-then-ambient semantics + the hotbar UI. Everything else is data/content.
- QA-first per feature; NO COMMIT by implementers; alarm-wrap; grep discipline.

---

### Task P1: field-skill dispatch (sim) + skills data tags

**Files:** Modify `src/core/wi_game.gd` (`use_skill_field(skill_id)`: no target arg — resolves the FACED cell's entity first [reuse the interact raycast]; entity with matching `requires_skill`/`on_skill_use` responds [same seam, new trigger]; NPC with an `on_observe`-style response? NO — v1: [Observe]'s NPC behavior is data on the SKILL not the NPC: an `ambient_effect` fallback per skill [light = existing lantern path? [Light] currently prop-gated — give it an ambient no-target toast]; no valid target → the established refusal toast), `data/skills.json` (`field: true` on basic_cleaning, light, basic_cooking + the new Tactician kit; `field_ambient` flavor lines where applicable), tests (sim cases: faced-prop fires the SAME on_skill_use as interact; ambient fallback; unknown-skill refusal preserved).
- Contract: pressing a field skill FACING a qualifying prop ≡ today's interact-with-requires_skill — byte-same events (QA compat: work_loop/crate_light/lantern_check untouched and green).

### Task P2: overworld hotbar UI

**Files:** Create `src/ui/field_hotbar.gd` (+uid); Modify the UI spawn site + `src/world/world.gd` input routing (number keys in field mode when no panel open — arbitration with inventory/journal/pause per the E4 triangle), `wandering_inn_game_v4/CLAUDE.md`.
- REUSES the combat hotbar component style (UIChrome 52x52 slots — read combat_hud's slot rendering; the M6.5 seam verdict says a slot addition is a 3-file edit, mirror the pattern); shows KNOWN field-tagged skills; number key → P1's dispatch; slot-info line idiom for the readout (bb_escape placeholder rule!).
- Emits `ui_field_hotbar_rendered {slots}`; renders on skill gain/load.
- Windowed set controller-read; the journal reveal interplay noted (using a field skill reveals it — free via used_skills).

### Task P3: [Tactician] + [Observe] + kit

**Files:** Modify `data/classes.json` (tactician: earned multiclass, `gained_by: {studied_the_cellar: 1}` — the slice's seam, ALREADY bankable via crate_light's path; levels + small kit), `data/skills.json` ([Observe]: field-tagged; on a faced entity → an info TOAST from data [`observe_lines` on entities? v1: a per-entity `observe` string in skeleton data with a generic fallback "You watch. Details surface." — flavor only]; one combat positioning skill — reuse an existing effect type [movement/status] — NO new combat effect machinery), `data/skeleton_scene.json` (observe lines on the marquee entities: Relc, Erin, Krshia, the dummies, sewer grates…, canon-voiced), tests + content validation.
- CANON-CHECK [Tactician] + kit names (wiki); escalate misses.

### Task P4: carried content debts

**Files:** `data/classes.json` (Barmaid/Server L10 grants — canon service skills, 2 each per the evolution precedent; wiki-check), `tests/sim_combat_batch.gd` (`warrior2_helper2` measured cell), `data/skills.json` if the L10 grants are new skill records.

### Task P5: QA + pillar re-audit

**Files:** New `qa/scripts/field_skills_loop.json` (canonical: gain a field skill → hotbar renders → faced-prop use ≡ interact parity assert → ambient fallback → [Observe] on an entity → info toast + used_skills reveal in the journal → Tactician gained at sleep after the cellar study route); extend `crate_light` OR keep untouched (parity contract means untouched should hold — verify); CLAUDE.md rows; the pillar audit table re-run (spec §5): exploration pillar must now show REPEATABLE sources ([Observe] everywhere + field skills) — report the before/after table.

### Task PF: gate + docs + opus whole-branch review

- Full sweep + units + harness (P4's new cell + gates hold) + web parity + windowed set.
- HANDOFF playtest checklist: does the overworld hotbar feel like combat's (grammar transfer)? Is [Observe] delightful or noise? Does Tactician's arrival read earned? Pillar-balance gut check.
- Opus method hints: dispatch-parity trace (field vs interact byte-equality), input arbitration composition (hotbar × 3 panels × dialogue), gained_by collision (a player who did crate_light's guile path BEFORE this milestone lands already has studied_the_cellar=1 → Tactician arrives at their next sleep with zero new action — save-compat surprise: adjudicate ship-with-note vs a fresher gate), journal reveal composition.

## Self-review notes
- Spec §2.2 Tactician→P3; §3 hotbar→P1/P2; §2.3 non-goals respected (no Helper+Tactician consolidation content); §5 QA/audit→P5; carried debts→P4. §2.1 shipped.
- The gained_by-collision (PF hint) is REAL: pre-existing studied_the_cellar saves — surface it in P3's report, adjudicate at PF.
- No file collision with the Onboarding-rev plan (verified surfaces: O-tasks own relc_intro/tutor_lines/classes.warrior/pisces; P-tasks own field dispatch/hotbar/tactician/service classes) — EXCEPT data/classes.json + data/skills.json shared: the plans are SEQUENTIAL per ladder, no concurrency intended.
