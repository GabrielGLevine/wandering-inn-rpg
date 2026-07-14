class_name WIKeys
extends RefCounted
## A shared home for the
## stringly-typed dict keys used at HOT src/core call sites (combatant,
## skill, effect, item, and entity records) so a typo'd key becomes a
## visible-at-review named constant instead of a silent runtime `null`.
##
## TYPE CHOICE — const String, NOT StringName (read this before "upgrading"
## it): every one of these dicts is either parsed straight from JSON
## (`data/*.json` via `JSON.parse_string`) or built to match the exact shape
## of a JSON-parsed dict (so it round-trips through `WISave`/`snapshot()`
## unchanged). JSON object keys deserialize as plain `String`, never
## `StringName` — `dict.has(&"hp")` and `dict.has("hp")` are NOT the same
## lookup when `dict` came from `JSON.parse_string` (StringName and String
## hash/compare distinctly as Dictionary keys in Godot 4.x), so a
## StringName catalog would silently miss every JSON-sourced dict while
## still working on hand-built literal dicts in unit tests — exactly the
## kind of gap that stays invisible until a real data file is touched.
## `const String` is a drop-in for every existing `"key"` literal with zero
## lookup-semantics change, which is the whole point of a minimum-viable,
## zero-behavior-change refactor. Do not change these to StringName.
##
## SCOPE — hot paths only, not a full schema. Cataloged here: the
## combatant/build record, the skill record, the effect record, the item
## record, and the entity record. One-off/rare keys
## are deliberately NOT here — a catalog that tries to cover every key in
## the codebase becomes its own drift surface (goes stale the moment a new
## key is added elsewhere and nobody remembers to add it here). Data files
## (`data/*.json`) and JSON construction stay string-literal; they ARE the
## strings this catalog names.
##
## NOT in scope (explicitly, per the brief): typed wrapper classes/Resources
## around these dicts. That is a bigger, successor-hostile change — this
## task is only the const catalog + call-site adoption.

# --- Combatant / build record ---
const ID := "id"
## The data/combatants.json id this runtime combatant was built from, BEFORE
## any same-id dedup suffix (WICombat._init) makes ID itself unique within a
## fight. Equal to ID for every non-duplicate roster (the overwhelming
## majority) -- only diverges when a roster fields the same catalog id twice
## (e.g. `shield_spider`/`shield_spider_2`). Presentation-only: anything that
## needs to re-read a combatant's STATIC catalog record (sprite, combat_scale)
## must key off this, never off ID, or a suffixed second combatant resolves
## to an unknown catalog id and renders with no sprite.
const TEMPLATE_ID := "template_id"
const SIDE := "side"
const ALIVE := "alive"
const HP := "hp"
const MAX_HP := "max_hp"
const MP := "mp"
const MAX_MP := "max_mp"
const SKILLS := "skills"
const STATS := "stats"
const WEAPON_DIE := "weapon_die"
## GH#70: a combatant's live weapon range (Chebyshev cells), threaded onto
## the runtime combatant dict at build time the SAME way WEAPON_DIE already
## is -- see wi_combat.gd's `_init` (reads `cfg.get(WEAPON_RANGE, 1)`) and
## wi_game.gd's `_build_player_combatant` (writes it from the equipped
## weapon's items.json `range`, default 1). Absent on every pre-existing
## combatant config (no enemy carries a ranged weapon; no pre-M-ARCHER
## weapon item declares `range`), so this defaults to 1 (melee) everywhere
## except a PC with a bow equipped -- the byte-identical guarantee.
const WEAPON_RANGE := "weapon_range"
const DAMAGE_MOD := "damage_mod"
const DAMAGE_REDUCTION := "damage_reduction"
const AP := "ap"
const MOVE_POOL := "move_pool"
const DISPLAY_NAME := "display_name"
const AI := "ai"

# --- Skill record ---
# ID, DISPLAY_NAME shared with combatant record above.
const EFFECT := "effect"
const AP_COST := "ap_cost"
const MP_COST := "mp_cost"
const CONTEXTS := "contexts"
const FIELD := "field"
const WEAPON := "weapon"
## Skill-level (not effect-level) pacing knob for combat_ai.gd's melee-profile
## windup arm: a windup-carrying skill only gets DECLARED on rounds where
## `combat.round_number % windup_cadence == 0`, so the AI doesn't lead with it
## every single turn it's in range. Read only by that one arm -- absent on
## every skill without a windup (defaults to 3 where read, per that call
## site's own doc comment).
const WINDUP_CADENCE := "windup_cadence"
## Class-foundation pass R1 (2026-07-12), [Sudden Strike]'s ONCE-per-fight
## gate. Checked in `WICombat.use_skill` against the ALREADY-EXISTING
## `used_skills_tally` per-actor/per-fight set (`_mark_skill_used`, populated
## by every skill's own `spend_skill_costs` call -- see that var's doc
## comment: it resets every fight by construction, journal_skills' lifetime
## reveal set lives on WIGame instead, merged in at `resolve_combat`). Reused
## state, not new sim ground: a refused repeat cast costs neither AP nor MP
## (checked before the affordability gates, matching the file's existing "a
## refused cast costs nothing" contract). Absent (false) on every
## pre-existing skill -- byte-identical for everything that isn't
## `sudden_strike`.
const ONCE_PER_FIGHT := "once_per_fight"

# --- Effect record ---
const TYPE := "type"
const AMOUNT := "amount"
const MULT := "mult"
const RANGE := "range"
const LENGTH := "length"
const APPLIES := "applies"
## The effect's blast radius (Chebyshev cells around the target -- shared by
## icy_floor's terrain blast and blast_damage's instant-damage blast, see
## skill_effects.gd's `_radius_area`) and how many rounds a cast cell stays
## icy (icy_floor only -- blast_damage writes no duration).
const RADIUS := "radius"
const DURATION_ROUNDS := "duration_rounds"
## Issue #82's WINDUP SIM SPEC: a positive value means the skill never
## resolves on cast -- it DECLARES (freezes the target cell set, spends its
## cost, ends the action) and resolves at the caster's own NEXT turn start
## instead. Only 1 is supported v1 (WICombat._resolve_windup/WISkillEffects.
## declare_windup both assume "the very next turn", not N turns out). Absent
## (0) on every pre-existing skill, so any code path gating on this defaults
## to the old immediate-resolve behavior -- byte-identical for everything
## that isn't `slam`.
const WINDUP_ROUNDS := "windup_rounds"

# --- Item record ---
# ID, DAMAGE_MOD, DAMAGE_REDUCTION shared with combatant record above.
const KIND := "kind"
const PRICE := "price"
const RESONANCE := "resonance"
const HP_MOD := "hp_mod"
const LORE := "lore"
## Issue #92 R1: an item's consumable-use payload, e.g. `{"heal": 8}` or
## `{"next_fight": {"damage_mod": 1}}` -- see WIItems.resolve_use's own doc
## comment for the full sanctioned-shape list. Absent on every pre-#92 item
## (every existing item is either equippable or plain-carried flavor) --
## mutually exclusive with an equippable `kind` (weapon/armor/accessory),
## enforced by tests/test_items.gd.
const USE_EFFECT := "use_effect"

# --- Entity record ---
# ID shared with combatant record above.
const CELL := "cell"
const SPRITE := "sprite"
const CONVERSATION := "conversation"
