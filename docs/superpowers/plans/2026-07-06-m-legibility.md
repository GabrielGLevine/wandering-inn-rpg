# M-LEGIBILITY Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Project skills READ-ONLY for subagents (propose via HANDOFF). Controller commits per green task, EXPLICIT paths while lanes live. FOREGROUND-ONLY verification in every brief.

**Goal:** The ratified §2 of `docs/superpowers/specs/2026-07-06-systems-depth-priorities.md`: every item, Skill, and status becomes mechanically legible in the game's VISIBLE currencies (HP/MP/AP/damage/moves/gold/resonance-later) — no raw attributes, no progress-toward, ever.

**Architecture:** Pure data + presentation. Items/skills/statuses gain structured `effects_text`-class fields rendered by existing panels; ONE derivation helper may live sim-side (pure, unit-tested) so effect lines are GENERATED from the actual mechanical fields rather than hand-written twins that drift.

## Global Constraints

- The visible-currency tier ONLY: HP, MP, AP, damage dice/mods, move cells, gold. FORBIDDEN in any player string: STR/DEX/CON/INT/WIS/CHA, percentages-toward, level math, dominance/evolution internals.
- **Generated, not hand-written:** effect lines derive from mechanical data (damage_mod, hp_mod, damage_reduction, ap/mp costs, status params) via one pure formatter — a hand-written line that contradicts the data is the defect class this milestone exists to kill.
- Flavor lore lines stay SEPARATE from effect lines (M-GEAR §1 owns lore; don't merge the fields).
- Suite = qa/ci_sweep.sh (42 by then — verify count at execution); disclosure discipline for any panel-payload change.

---

### Task L1: the effect-line formatter (sim-side, pure)

**Files:** New `src/core/effect_text.gd` (pure static: `item_effect_lines(item: Dictionary) -> Array[String]` reading damage_mod/hp_mod/damage_reduction/price/resonance-if-present → "+1 damage on melee hits", "+4 HP", "Reduces every hit taken by 1"; `skill_effect_lines(skill)` reading ap_cost/mp_cost/damage dice/range/statuses → "1 AP, 2 MP — damage 1d6 at range 4. Slows."; `status_line(status_id)` → the one-sentence glossary form, param-substituted: "Slowed — moves 2 fewer cells next turn (min 1)."). Status params come from where statuses are DEFINED (trace: slowed's pool_penalty lives in skill data/sim constants — read, don't duplicate numbers).
**Tests:** exact-string cases for every shipped item + skill + status; a tripwire case proving a data change moves the line (formatter reads data, not literals); the FORBIDDEN-vocabulary grep test (no attribute names in any generated line — extend test_content's opacity checks).

### Task L2: item cards (inventory + shop surfaces)

**Files:** Modify `src/ui/inventory.gd` (detail area: name, effect lines via L1, gold value if priced; lore line slot reserved-but-empty for M-GEAR); the shop surface (Krshia's buy options — trace how option text renders: append/attach the effect line so "what am I buying" is answered in-panel; dialogue-panel budget discipline — wrapped lines, page if needed); windowed reads.
**QA:** extend `inventory_loop` + `economy_loop` payload asserts (panels carry effect lines — assert presence + ONE exact string each; disclose).

### Task L3: skill cards (journal + hotbar readout)

**Files:** Modify `src/ui/journal.gd` (skills panel: post-first-use reveal now shows name + L1 effect line + description — the reveal mechanic unchanged, the revealed CONTENT gets mechanical); `src/combat/combat_hud.gd` + `src/ui/field_hotbar.gd` slot-info/readout lines gain the cost/effect summary (bb_escape placeholder rule).
**QA:** `journal_skills` payload extension (disclose); `combat_move_input`'s slot-info pin re-checked (it pins [Power Strike] text — will change: re-pin honestly).

### Task L4: the status glossary + first-encounter toasts

**Files:** New journal section "Effects" listing every status the player has ENCOUNTERED (a seen-statuses set — additive save field, used_skills precedent; banked presentation-side? NO — sim-side seen set banked where statuses APPLY, pure); first-encounter toast on a status's first application ("Slowed — moves 2 fewer cells next turn."), once per status per save (the set gates it); glossary renders L1 status_line per seen status.
**Tests:** seen-set banking + round-trip; once-only toast.
**QA:** a status first-encounter assert in a combat canonical (line_of_sight_denial or level_up_loop fights slow-appliers — trace which fight actually applies slowed at pinned seed; extend that script, disclose).

### Task L5: the copy audit + canonical polish

**Files:** data pass over items.json/skills.json descriptions — flavor text stays flavor; anything mechanically WRONG or mechanically-implying-but-vague gets corrected (the effect line now carries mechanics, so descriptions can be purely voice); CLAUDE.md architecture note; any remaining panel with mechanical vagueness (equip confirmation? loot toast?) swept.
**QA:** full sweep; the FORBIDDEN-vocab test extended to ALL player-string fields it can reach.

### Task LF: gate + docs + opus whole-branch review

- Full gate + windowed set (inventory card, shop card, journal skill card, glossary, first-encounter toast — controller-read).
- HANDOFF playtest checklist: "Pick between two armors WITHOUT opening a wiki — could you? Did any surface feel like a spreadsheet? Did any Skill's effect surprise you after reading its card?"
- Opus hints: formatter-vs-data drift tripwire coverage; opacity grep completeness (find ONE player-reachable string path the test misses); panel budget under the longest generated line (resonance+3 effects item); seen-set × defeat-reload; the reveal mechanic × mechanical cards (pre-first-use still name-only?).

## Self-review notes
- Spec §2 bullets map: cards→L2/L3, glossary+toasts→L4, hidden-tier absolutes→L1's grep test + Global Constraints, copy audit→L5.
- The formatter-derivation rule is the plan's spine — reviewers should treat any hand-written mechanical string as Important.
- L4's seen-set is the one save-field addition (additive, tolerant default).
