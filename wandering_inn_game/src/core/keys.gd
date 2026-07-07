class_name WIKeys
extends RefCounted
## ARCH-3 (const key catalog, minimum viable): a shared home for the
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
## record, and the entity record (consultant's list). One-off/rare keys
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
const SIDE := "side"
const ALIVE := "alive"
const HP := "hp"
const MAX_HP := "max_hp"
const MP := "mp"
const MAX_MP := "max_mp"
const SKILLS := "skills"
const STATS := "stats"
const WEAPON_DIE := "weapon_die"
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
