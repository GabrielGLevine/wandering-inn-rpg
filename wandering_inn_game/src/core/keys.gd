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

# --- Item record ---
# ID, DAMAGE_MOD, DAMAGE_REDUCTION shared with combatant record above.
const KIND := "kind"
const PRICE := "price"
const RESONANCE := "resonance"
const HP_MOD := "hp_mod"
const LORE := "lore"

# --- Entity record ---
# ID shared with combatant record above.
const CELL := "cell"
const SPRITE := "sprite"
const CONVERSATION := "conversation"
