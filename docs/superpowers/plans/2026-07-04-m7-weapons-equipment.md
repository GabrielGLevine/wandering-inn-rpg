# M7 Weapons & Equipment Implementation Plan

> Status: **DONE** — executed; retained as a design record.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax. Project skills (`.claude/skills/wi-*`) are READ-ONLY and govern process/verification.

**Goal:** Weapons gate skill families (wielded weapon → fieldable tagged skills → counters → evolution identity) + two equip slots + acquisition (loot/containers/gift) + inventory UI — per the user-approved spec `docs/superpowers/specs/2026-07-03-wandering-inn-m7-weapons-equipment-design.md` (its §0 decisions are LOCKED).

**Architecture:** Pure-sim equipment state (spec Approach A); combat reads equipment ONCE at build; data in `data/items.json`; UI is a new field panel using the M6.5 component discipline. M6's weapon tags are the seam — zero M6 machinery changes.

## Plan-time corrections to the spec (authoritative; spec text predates M-FP/M6.5)

1. **Save bump is v4 → v5** (spec says v3 — stale). MIGRATE, don't reject: v2→v3→v4→v5 composes (save.gd's sequential-step precedent); v5 defaults for older saves: `inventory: []`, `equipped: {"weapon": "rusty_sword", "armor": ""}`, `container_state: {}` — rusty-sword default keeps old saves' fights shaped. v1 still rejected.
2. **Relc's gift wires DIRECTLY into the shipped `relc_intro` graph** (M-FP delivered it) — no "placed fallback copy". New dialogue effect kind `{"item": id}` handled in `WIGame.dialogue_choose`.
3. **Loot RNG isolation (new decision):** loot rolls use a rng seeded from `hash(run_seed, encounter_id)` — NEVER the live sim stream. A post-victory draw on the main stream would shift every subsequent fight's trajectory and invalidate multi-fight canonical seeds (level_up_loop class bugs). Deterministic per run-seed, stream-isolated.
4. Canonical suite is now 28 scripts (seed table in v4 CLAUDE.md; level_up_loop 12, defeat_ally_alive 11, journal_skills per its row). PC start state interacts with the approved Onboarding rev (classless start) — that lands AFTER M7 and will re-point the start state; M7 ships rusty-sword-start per spec §0.
5. Inventory panel must follow the M6.5 UI discipline (own file, autoload touches per the documented pattern) and the journal grammar; the skills-by-class journal panel (UI wave) is the interaction precedent.

## Global Constraints

- Stats hidden (no STR/DEX in any item line — prose + HP/damage numbers only); opaque-until-sleep untouched.
- Tune data via harness, never sim. Zero warnings; alarm-wrap; grep discipline (`[godot_ai game_helper]` exempt).
- Single implementer at a time; NO COMMIT (controller commits per green task); ledger live.
- `tier`/`abilities` fields ship INERT (schema hooks only — validation accepts, nothing reads them).
- Every player-visible addition: bus event + `ui_*_rendered` + QA assert (QA-first rule).
- New `.gd`: import pass + commit `.uid`. Combat-data/rules changes: full combat-seed re-check per wi-verifying-changes.

---

### Task E1: items data + events + validation (foundation)

**Files:** Create `wandering_inn_game_v4/data/items.json` + `tests/test_items.gd` (+uid); Modify `src/core/wi_events.gd` (or wherever WIEvents consts live — match file).

**Interfaces — Produces:** item ids consumed by E2-E5: `rusty_sword, relcs_spare_spear, crude_blade, chipped_spear, solid_oak_spear, leather_jerkin, watch_issue_gambeson, traveler_charm`; event consts `ITEM_GAINED, ITEM_EQUIPPED, ITEM_UNEQUIPPED, LOOT_DROPPED, UI_INVENTORY_SHOWN, UI_INVENTORY_HIDDEN`.

- [ ] items.json per spec §1 schema, all 8 starter items, spec's provisional numbers verbatim (`relcs_spare_spear` damage_mod +1, `leather_jerkin` hp_mod +4, `watch_issue_gambeson` damage_reduction 1, `traveler_charm` hp_mod +2, others 0/flavor; descriptions canon-flavored prose, no stat words).
- [ ] test_items.gd (SceneTree script, plain-suite convention): unique ids; kind ∈ {weapon, armor}; weapon_family ∈ {sword, spear, none} and consistent with kind; numeric fields ints ≥ 0; tier = "mundane" for all; abilities empty; every skills.json weapon tag has ≥1 family match (cross-ref the M6 T1 tags — find the tag field name in skills.json first and cite it in the report).
- [ ] Verify: new suite + test_content + load_gate + smoke. Commit.

### Task E2: sim — equipment state, combat injection, save v5

**Files:** Modify `src/core/wi_game.gd`, `src/core/save.gd`, `src/core/combat/wi_combat.gd` (build-time only), `tests/test_save.gd`, `tests/test_sim_core.gd`, `tests/test_combat_sim.gd`.

**Interfaces — Produces (E3/E4/E5 consume):**
```gdscript
# WIGame
var inventory: Array[String]
var equipped: Dictionary            # {"weapon": String, "armor": String} — "" = empty
var container_state: Dictionary     # container entity id -> true (emptied)
func pickup(item_id: String, source_id: String) -> bool    # ITEM_GAINED {item, source}
func equip(item_id: String) -> bool                         # kind/possession validated; ITEM_EQUIPPED {item, slot}
func unequip(slot: String) -> bool                          # ITEM_UNEQUIPPED {slot}; weapon unequip = deliberate unarmed
func item(item_id: String) -> Dictionary                    # items.json record
```
- [ ] Start state: `equipped.weapon = "rusty_sword"`, `rusty_sword` in inventory (data-driven via skeleton player block if that's the existing config pattern — match how player.skills is seeded).
- [ ] Combat build injection at the existing start_combat build site: PC kit = class kit filtered by weapon gate (tagged skills require the equipped weapon_family; untagged always pass — reuse the T1 tag field), attack damage + weapon damage_mod, max_hp + armor hp_mod, `damage_reduction` applied in `_deduct_hp` BEFORE mana_shield with the ≥1 floor. Fields read ONCE at build (no live equipment reads in combat).
- [ ] Dialogue effect `{"item": id}` in dialogue_choose (grants via pickup; source = conversation id).
- [ ] Save v5 per correction 1 (composing migration; tolerant defaults; container_state persisted). **M-BEAUTY FOLD (controller amendment 2026-07-04 night, user-approved concurrency plan): the same v5 bump ALSO carries `actions_since_sleep: int` (increments on move/interact/combat-turn — pick ONE cheap central site and document it; sleep() resets to 0; default 0 on migration) + a pure `phase() -> String` reading it against thresholds injected via config (defaults: dusk ≥ 40, night ≥ 90 — data-overridable later by moods.json meta) + a `phase_changed {phase}` emit on threshold crossings and on the sleep reset. Consumes NO rng; unit case: deterministic phase walk + save round-trip. Nothing renders it this milestone — the Beauty pilot consumes it tomorrow without touching sim files.** Unit coverage: round-trip incl. containers; v4-with-no-inventory migrates to rusty-sword default; v2 chains all three steps; kit-intersection math; damage_reduction floor; unarmed = base attack + untagged.
- [ ] **Seed check (iron rule):** rusty_sword damage_mod 0 + no loot yet ⇒ canonical fights SHOULD be byte-identical — prove it: full 28-script sweep at pinned seeds; any red = injection changed a trajectory (bug, not re-derivation — STOP and fix). Commit.

### Task E3: loot + containers

**Files:** Modify `src/core/wi_game.gd` (victory loot roll + container interact), `data/skeleton_scene.json` (goblin drop tables; inn chest `contains`; ruin-stones trinket), `tests/test_sim_core.gd`.

- [ ] Encounter `loot: [{item, chance}]` rolled at victory with the CORRECTION-3 derived rng; `LOOT_DROPPED {items}` then pickup each (toast per spec §3 timing: after banner close — trace where victory resolution meets the banner and note the seam; the EVENT can fire at resolve, the TOAST renders on banner close via the queue).
- [ ] Container props: `contains: [ids]` + interact → pickup all + `container_state[id]=true` (persisted; emptied container toast "Empty." on re-interact). Data: goblin_encounter_1/2 drop tables (crude_blade/chipped_spear, chance 0.25), chieftains_raid (chipped_spear 0.5), inn chest (leather_jerkin), ruin-stones POI prop (traveler_charm), relc_intro gift effect (relcs_spare_spear on the spar-accept path — wire into the SHIPPED graph, effects array addition only).
- [ ] Unit: derived-rng determinism (same run seed → same drops; different encounter ids → independent); container persistence round-trip (extend the v5 case).
- [ ] Seed check: loot rolls isolated ⇒ canonical seeds still hold — full combat-script re-run proves correction 3 worked. relc_intro graph edit shifts dialogue option indices? The gift rides an EXISTING option's effects array — verify the three relc-route scripts (relc_tutorial, combat_walkthrough, defeat_ally_alive) stay green; fix cursor paths ONLY if the graph structurally changed (it should not). Commit.

### Task E4: inventory UI

**Files:** Create `src/ui/inventory.gd` (+uid); Modify `src/world/main.gd` or the UI-spawn site (match how journal spawns), `src/ui/message_layer.gd` ONLY if the footer hint lives there (add "I — inventory"), `src/combat/combat_hud.gd` NOT touched (hotbar re-render rides the existing ui_hotbar_rendered contract — verify, don't edit).

- [ ] Panel per spec §3: I toggles; UIChrome parchment within art bbox; journal grammar (arrows/Enter/Esc); slot rows pinned top; carried list below; equips call the E2 API; `ui_inventory_shown {items: N}` / `ui_inventory_hidden`. Layer above world labels (the journal layer=10 lesson). Wrapped-line discipline for descriptions.
- [ ] Pickup toasts ride the existing toast queue (no new panel). Footer hint added.
- [ ] Windowed shots (panel open, equip moment, pickup toast) copied to fp-handoff immediately; controller reads. Commit.

### Task E5: QA — inventory_loop + walkthrough beats

**Files:** Create `qa/scripts/inventory_loop.json`; Modify ONE existing walkthrough for a container beat (inn chest in a script already in the inn — work_loop is the candidate); `wandering_inn_game_v4/CLAUDE.md` rows.

- [ ] inventory_loop (derive seed, start at 9): pickup (chest) → I → ui_inventory_shown → equip spear (relc gift path or found spear) → hotbar re-render assert → fight → snapshot-assert spear-tagged counters accrued AND sword counters did NOT → victory loot (forced-chance table or the deterministic derived roll — pin whichever the seed gives, document) → ITEM_GAINED + ui_toast_rendered.
- [ ] The reveal interplay: equipping a different weapon changes the fieldable kit — assert the journal skills panel (UI wave) still lists ALL known skills (knowledge ≠ fieldability; if the design wants a "requires spear" annotation, note as F-question, don't invent).
- [ ] Full sweep + units + smoke. Commit.

### Task E6: balance — loadout axis

**Files:** Modify `tests/sim_combat_batch.gd`, `data/items.json` (numbers only).

- [ ] Harness loadout axis per spec §5: sword/spear × armored/unarmored across existing compositions (keep cell count sane — pick the 4-6 design-relevant cells, measured or gated per the existing conventions incl. A2's ungated_comps mechanism + relc_downed_rate print). Gates 0.55-0.95/3-12 hold; tune ITEM NUMBERS only. Document the frontier like wave A's report.
- [ ] Combat data changed if numbers moved: full combat-seed re-check; re-derive + document per the protocol. Commit.

### Task F: gate, docs, review

- [ ] Full gate: all canonical scripts (28 + inventory_loop) + 12+2 units + harness + smoke + web parity (combat_walkthrough wasm; NOTE web build must pick up items.json — the export includes data/ wholesale, verify).
- [ ] VISUAL-LOG drain pass (standing directive): triage open entries actionable within scope (bb_escape copies if still open post-UI-wave; combat Relc chip is FIXED — verify entry moved).
- [ ] CLAUDE.md: equipment architecture block (sim state, injection-at-build, loot rng isolation, v5); HANDOFF playtest checklist (equip feel, inventory discoverability via footer hint, the sword-vs-spear identity moment, loot excitement).
- [ ] Whole-branch review (opus) with method hints: kit-intersection edge cases (class with zero tagged skills; weapon with no matching class skills), damage_reduction × mana_shield ordering, save v5 chain from a REAL v2 fixture, loot-rng isolation proof (two canonical multi-fight scripts byte-identical), the ≥1 floor under stacked reduction. Fix wave; commit `M7 F: gate + docs`.

## Self-review notes

- Spec §0-§5 fully covered: model/slots/acquisition/UI/extensibility→E1-E4; balance→E6; QA→E5; §4 content→E3. §6 exclusions respected (nothing prices/stacks/consumes).
- Type consistency: pickup/equip/unequip signatures fixed in E2, consumed E3/E4/E5 identically; item ids fixed in E1.
- Known risks: (a) kit-intersection could surprise mage kits (spells untagged? verify T1 tag coverage in E1's cross-ref — spells SHOULD be untagged/always-fieldable; if any spell carries a weapon tag, escalate before E2); (b) toast-after-banner seam (E3 notes it — the toast queue handles ordering, trace it); (c) save v5 fixture volume (5 fixture files claim versions — E2 verifies each still behaves).
