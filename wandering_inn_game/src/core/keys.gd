class_name WIKeys
extends RefCounted

const ID := "id"
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
const WEAPON_RANGE := "weapon_range"
const DAMAGE_MOD := "damage_mod"
const DAMAGE_REDUCTION := "damage_reduction"
const AP := "ap"
const MOVE_POOL := "move_pool"
const DISPLAY_NAME := "display_name"
const AI := "ai"

const EFFECT := "effect"
const AP_COST := "ap_cost"
const MP_COST := "mp_cost"
const CONTEXTS := "contexts"
const FIELD := "field"
const WEAPON := "weapon"
const WINDUP_CADENCE := "windup_cadence"
const ONCE_PER_FIGHT := "once_per_fight"

## #474 THE COMPANION COUNTER, in two halves that only mean anything together.
##
## `BONDED` is a ROLE, on the combatant row: this body is on the player's side
## because a bond, a taming or a raising put it there, not because the story
## did. `TARGET_RULE` is the other half, on a SKILL: "this Skill may only be
## spent on a body carrying that role".
##
## Why a role flag and not an id list: the counter has to generalise. A boss
## authored today against `wolf_companion` would be a hack that the next
## companion walks straight past; a boss authored against BONDED meets every
## companion the game ever ships, on the day it ships, because the new row
## carries the flag to be a companion at all (`data_lint.check_companion_bond_flag`
## makes that a gate, not a convention).
const BONDED := "bonded"
const TARGET_RULE := "target_rule"

const TYPE := "type"
const AMOUNT := "amount"
const MULT := "mult"
const RANGE := "range"
const LENGTH := "length"
const APPLIES := "applies"
const RADIUS := "radius"
const DURATION_ROUNDS := "duration_rounds"
const WINDUP_ROUNDS := "windup_rounds"

const KIND := "kind"
const PRICE := "price"
const RESONANCE := "resonance"
const HP_MOD := "hp_mod"
const LORE := "lore"
const USE_EFFECT := "use_effect"
const ABILITIES := "abilities"

const CELL := "cell"
const SPRITE := "sprite"
const CONVERSATION := "conversation"
