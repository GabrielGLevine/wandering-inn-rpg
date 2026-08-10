---
name: wi-adding-a-class-or-skill
description: Use when adding, renaming, or rebalancing a class, class level, evolution, consolidation, or a [Skill] entry in the Wandering Inn RPG (`data/classes.json` / `data/skills.json`).
---

# Adding a Class or Skill

## Core principle
Leveling is **accomplishment-driven, never chosen**, resolved **only at the
sleep beat** (`WIGame.sleep()`: class gains → level-ups → consolidation
offer → evolutions). `src/core/progression.gd` (`WIProgression`, pure
static functions) is the only reader of `classes.json`/`skills.json` — never
hand-roll leveling math elsewhere.

## `classes.json` record
| Field | Meaning |
|---|---|
| `stat_growth` | e.g. `{"str":1,"con":1}` per-level additive growth, folded via `apply_stat_bonuses` |
| `gained_by.accomplishment` | earned multiclass (e.g. `mage`: `{"used_magic":1}`), checked BEFORE level-ups |
| `inherits` | id or list; `granted_skills` folds ALL ancestor grants at the child's own level (`swordsman`→`warrior`; `spellsword`→ BOTH `warrior` and `mage`) |
| `evolution` | `{at_level, dominance_share, min_uses, targets, balanced_grants}` |
| `levels` | `[{level, requires \| requires_any, grants}]` |

`requires` thresholds are **cumulative** lifetime totals, not deltas.
`requires_any` (spellsword) is met when **either** parent's counter clears
its threshold; empty `requires_any` is never met (free-level guard). No
key = unconditionally met.

**DIALOGUE-GATE COUPLING TRAP (GH#64):** dialogue persuade options gate
on `requires.skill` (charming_smile / calming_touch / observe today, all
L1 grants). Moving a dialogue-gated skill's grant to a higher level
silently tightens every conversation gate on it — before rebalancing any
grant level, grep `data/dialogue/**` + `data/maps/**` for
`"skill":"<id>"` and re-adjudicate each gate (see
wi-adding-dialogue-and-quests' SKILL-GATES section).

## `skills.json` record
`id`/`display_name` (bracketed canon voice, `"[Power Strike]"`);
`contexts` (`combat`/`exploration` — non-combat skills omit `ap_cost`/
`effect`); `ap_cost`/`mp_cost` (mp_cost presence grants `max_mp` at all);
`weapon` (`sword`/`spear` gate); `icon` (id into `sprites.json`, 16x16,
required for any hotbar slot); `effect.type` (`hit_bonus`, `hp_bonus`,
`damage_mult`, `riposte`, `ap_on_kill`, `spell_damage`, `line_damage`,
`mana_shield`, `quick_cast`, `move_pool_bonus`, `heal`, `dangersense`,
`icy_floor`); `description` (canon prose, never a stat readout).

## Evolution (`check_evolutions`, `evolution.at_level`, default 10)
1. **Replacement** — a `targets` key dominates (`share >= dominance_share`,
   default 0.6, no tie) and `total >= min_uses` (12): class swaps to target,
   level carries over.
2. **Generalist** — `total >= min_uses`, no dominance, `balanced_grants`
   present: id persists into `generalist_classes` (locks identity forever),
   its skills unlock **only reaching the combat kit via `granted_skills`
   checking `generalist_classes`** — not `player_skills`. Missing this
   wiring was the M6 F1 bug.
3. **Waiting** — below `min_uses`: no outcome, rechecked every sleep.

## Consolidation (`consolidations[]`)
`{parent_lines: [[lineA],[lineB]], min_parent_level, min_combined_level,
target}`. Each line = base id + evolution targets in canon order;
`_held_line_candidate` picks whichever is held. Fires when both lines'
candidates are `>= min_parent_level` and sum `>= min_combined_level`.
Merged level = `max(ceil(2*(L_a+L_b)/3), max(L_a,L_b))`, **integer** math
only. Sleep DEFERS the offer before evolutions; decline is re-offered every
qualifying sleep.

## SPARSE LEVEL TABLES for evolution-only classes (GH#54 convention)
A class reached ONLY via Replacement (`evolution.targets`) or
consolidation (`consolidations[].target`) never counts up from 1 —
`_resolve_evolutions`/`accept_consolidation` write the held level in
directly. Author its `levels` array starting EXACTLY at its floor,
contiguous to its max, with a `_comment` stating floor + formula:
- Replacement floor = the source class's `evolution.at_level`.
- Consolidation floor = the merge formula's minimum given
  `min_parent_level`/`min_combined_level` — DERIVE it (see
  `WIProgression._consolidation_merged_level`), never guess.
`tests/test_content.gd::_validate_class_level_tables` enforces all three
rules (no sub-floor entries, contiguous, lowest == floor) from the same
evolution/consolidation data — a new evolution-only class is covered
automatically, no list to maintain.
**Trap:** if a to-be-trimmed low entry carries a REAL skill grant (not
`[]`), migrate the grant onto the floor entry — deleting the entry
silently unlearns the skill for every future holder (spellsword's
`keener_edge` nearly shipped that way).
Shape 2 (an `extends` inheritance key) is PARKED until the class count
justifies a resolver — don't build it ad-hoc.

## PRODUCT LOCKS (checked every time)
Opaque-until-sleep (no "3/12", no %, no merged-level in prompts — results
only); stat grammar default (STR/DEX/etc. out of player text by default,
HP/MP/AP/damage fine — tripwire-enforced, clarity exceptions allowed);
canon names from the wiki.

## Example
Adding a level-10 evolution skill: add to `skills.json` (with `icon` if
hotbar-bound), add its id to the target class's `grants`, then check if it
changes the **level-1 kit's slot count** — any QA script asserting
`ui_hotbar_rendered {"slots": N}` at that level needs `N` updated (see
`mage_unlock_loop.json`, `slots: 6`).

## THE REGISTRATION MATRIX (2026-07-17 — every surface a new class/skill/companion touches)

Discovered serially at Wave D-2 cost (~7 boot-fail-diagnose cycles). Check ALL
of these BEFORE the first test boot; each is a separate hand-maintained pin:
1. `tests/test_effect_text.gd::EXPECTED_SKILLS` — EVERY new skill id needs a
   pinned effect-lines entry (passives pin `[]`).
2. `tests/test_combat_data.gd` — combat-context skills need `ap_cost` AND
   `effect` (hidden boon carriers too: `ap_cost: 0`).
3. `tests/test_sprite_registry.gd::_build_expected_counts` — every new
   sprites.json entry (icons AND follower/combatant aliases) needs a frame
   count pin.
4. `tests/test_fixture_coherence.gd` — new fixtures need gained_by counters
   for EVERY held class (check the class's actual gained_by id — mage is
   `learned_magic_from_pisces`, NOT used_magic) and level-consistent curve
   counters incl. inherited requires (mage L2+ needs won_combat).
5. `qa/manifest.json` + `wandering_inn_game/AGENTS.md` canonical seed table —
   BOTH, same seeds, or ci_sweep FATALs on drift.
6. `scripts/derive_qa_surfaces.py` then (repo root) `scripts/render_qa_notes.py
   --write` — in that order, after manifest edits.
7. Code-banked counters → STRUCTURAL_LITERALS in BOTH
   `tests/test_shipped_ids.gd` and `scripts/generate_shipped_ids.py` at the
   moment the call site lands (not at cut time — the review WILL flag it).

**Shipped-JSON edits: use `wandering_inn_game/scripts/splice_json.py`** (array
`--container`, dict `--container-dict --key`) — it clones sibling indentation
and PROVES top-level placement (a hand splice once nested ten records inside
the last existing entry, parse-valid). Never `json.dump` a shipped file.

## Verification
`tests/test_progression.gd` (pins the math); `tests/sim_combat_batch.gd`
(balance harness, win-rate 0.55-0.95, rounds 3-12) after any kit/stat
change; `tests/test_content.gd` (every `gained_by` accomplishment must be
produced somewhere). New class-tree content needs a QA loop script —
model on `qa/scripts/class_evolution_loop.json` (Replacement, fixture
`near_evolution.json`) or `generalist_loop.json` (Generalist, fixture
`near_generalist.json`); both assert the domain event AND a fight's
`combat.combatants.pc.skills` actually contains the new grant.

## Common mistakes
Writing a `requires` threshold as a delta; forgetting `requires_any` needs
sibling classes' data in sync; wiring `balanced_grants` only into
`player_skills` display and not `granted_skills`; rendering any
progress-toward text; changing `stat_growth`/`power_k` without re-running
the balance harness and canonical combat QA seeds.

## Cross-references
`wi-verifying-changes` (gates), `wi-art-and-sprites` (icon entries),
`wi-adding-dialogue-and-quests` (class-gated options read the same
`classes` dict).

## Shipped-id freeze (issue #99, 2026-07-12)
Once an id ships in a public release (frozen in
`wandering_inn_game/data/shipped_ids.json`), it is permanent API — a
class or skill id already frozen must NEVER be renamed or
re-semanticized. To retire one, add an entry to `WISave.DEPRECATED_IDS`
(`src/core/save.gd`) mapping old→new instead of deleting/renaming in
place; `tests/test_shipped_ids.gd` fails loud otherwise, and a mapped
class outside `MIGRATABLE_ID_CLASSES` fails until its remap arm exists
(green means handled, never advertised). A NEW id is free to be
renamed/reworked until the next `scripts/generate_shipped_ids.py` cut
(wi-shipping deploy step 0).

## The no-treadmill principle (user directive 2026-07-29, GH#330)
**Actions must never exist solely to level a class.** Every producer a
`gained_by` or level `requires` counter reads must have a real in-world
function beyond the counter — it pays, feeds, resolves, unlocks, or
advances something a player would do anyway (cooking feeds guests AND
levels; combat wins fights AND levels). A prop whose interact banks a
counter and nothing else is the violation class (the Wounded Corusdeer,
pre-#330). When adding a class/level: name each counter's producers and
what ELSE each one does; a producer with no second function needs one
designed before the rung ships.

## Field-vs-combat gating split + real blast radius (2026-08-10, #412)
- **Never add `weapon:` to gate a skill's FIELD use** —
  `WICombatBuild.weapon_gated_kit` consumes `weapon` and strips
  mismatched skills from the COMBAT kit, passives included (a
  `weapon:"sword"` on [Basic Swordwork] would nerf spear warriors' hit
  passive). Field gating uses `field_weapon` (consumed only by
  `_field_skill_weapon_ready`; inert without `cuts:true`). Trap comment
  lives at that function.
- **A skill-pool change's blast radius is NOT an id-grep.** Enumerate:
  (a) id refs, (b) DISPLAY-NAME pins ("[Power Strike] — ..." in
  readout_lines/comments across qa/scripts), (c) player-facing prose
  naming the skill (map locked_toasts, hints, dialogue), (d) tests/
  pins (exhaustive tables red on any pool change), (e) derived hotbar
  slot pins. #412 STOPped three times on surfaces (b) and (c) that the
  id-grep missed.
