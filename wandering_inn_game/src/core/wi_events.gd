class_name WIEvents
extends RefCounted

# Event names are persisted QA/API contracts; rename only with all producers, consumers, and save fixtures migrated.

const SIM_INITIALIZED := &"sim_initialized"
const GAME_RESET := &"game_reset"
const GAME_LOADED := &"game_loaded"
const SAVE_EXPORTED := &"save_exported"
const SAVE_IMPORTED := &"save_imported"
const SAVE_MIGRATED := &"save_migrated"  ## #111: legacy user:// dir carried over after the project rename
const GAME_OVER := &"game_over"
const TOAST := &"toast"

const MAP_CHANGED := &"map_changed"
const PLAYER_MOVED := &"player_moved"
const PLAYER_TELEPORTED := &"player_teleported"
const PLAYER_BLOCKED := &"player_blocked"
const INTERACT_NOTHING := &"interact_nothing"
const INTERACT_UNHANDLED := &"interact_unhandled"
const ENTITY_REMOVED := &"entity_removed"
const TERRAIN_CHANGED := &"terrain_changed"
const SNEAK_STARTED := &"sneak_started"
const SNEAK_ENDED := &"sneak_ended"
const WARD_PLACED := &"ward_placed"
const COMPANION_CHANGED := &"companion_changed"
const LOADOUT_CHANGED := &"loadout_changed"

const SKILL_USED := &"skill_used"
const SKILL_UNKNOWN := &"skill_unknown"
const SKILL_NO_EFFECT := &"skill_no_effect"
const SKILL_UNLOCKED := &"skill_unlocked"
const ACCOMPLISHMENT_RECORDED := &"accomplishment_recorded"
const CLASS_GAINED := &"class_gained"
const CLASS_LEVEL_UP := &"class_level_up"
const CLASS_EVOLVED := &"class_evolved"
const CONSOLIDATION_OFFERED := &"consolidation_offered"
const CONSOLIDATION_ACCEPTED := &"consolidation_accepted"
const CONSOLIDATION_DECLINED := &"consolidation_declined"
# v018-W2 (#347 prototype): DEV-ONLY log line. Emitted at the sleep beat ONLY
# while WISystemBestowal.log_enabled() -- it grants nothing and no UI listens.
const SYSTEM_BESTOWAL_CANDIDATE := &"system_bestowal_candidate"

const DIALOGUE_STARTED := &"dialogue_started"
const DIALOGUE_NODE := &"dialogue_node"
const DIALOGUE_LINE := &"dialogue_line"
const DIALOGUE_CHOICE := &"dialogue_choice"
const DIALOGUE_ENDED := &"dialogue_ended"
const DIALOGUE_EFFECT_FAILED := &"dialogue_effect_failed"
const PRE_COMBAT_CHOICE := &"pre_combat_choice"

const QUEST_STARTED := &"quest_started"
const QUEST_BEAT_COMPLETED := &"quest_beat_completed"
const QUEST_COMPLETED := &"quest_completed"

const ITEM_GAINED := &"item_gained"
const ITEM_EQUIPPED := &"item_equipped"
const ITEM_UNEQUIPPED := &"item_unequipped"
const LOOT_DROPPED := &"loot_dropped"
const ITEM_LOST := &"item_lost"
const ITEM_USED := &"item_used"
const GOLD_CHANGED := &"gold_changed"
const PHASE_CHANGED := &"phase_changed"

const COMBAT_STARTED := &"combat_started"
const COMBAT_FINISHED := &"combat_finished"
const COMBAT_RESOLVED := &"combat_resolved"
const ROUND_STARTED := &"round_started"
const TURN_STARTED := &"turn_started"
const TURN_ENDED := &"turn_ended"
const COMBATANT_MOVED := &"combatant_moved"
const COMBATANT_DOWNED := &"combatant_downed"
const ATTACK_RESOLVED := &"attack_resolved"
const SKILL_RESOLVED := &"skill_resolved"
const ACTION_REFUSED := &"action_refused"
const REACTION_TRIGGERED := &"reaction_triggered"
# Relay seam: first player passive use is discovered from this live event.
const PASSIVE_APPLIED := &"passive_applied"
const DASHED := &"dashed"
const AP_CHANGED := &"ap_changed"
const MP_CHANGED := &"mp_changed"
const STATUS_APPLIED := &"status_applied"
const STATUS_EXPIRED := &"status_expired"
const STATUS_TICKED := &"status_ticked"
const TERRAIN_ADDED := &"terrain_added"
const TERRAIN_EXPIRED := &"terrain_expired"
# Payload cells freeze the declaration geometry and drive AI playback later.
const WINDUP_DECLARED := &"windup_declared"

const WORLD_READY := &"world_ready"
const AUDIO_PLAYED := &"audio_played"
const UI_MAP_RENDERED := &"ui_map_rendered"
const UI_ENTITIES_RENDERED := &"ui_entities_rendered"
const UI_ARENA_RENDERED := &"ui_arena_rendered"
const UI_COMBAT_SHOWN := &"ui_combat_shown"
const UI_COMBAT_HIDDEN := &"ui_combat_hidden"
const UI_HOTBAR_RENDERED := &"ui_hotbar_rendered"
# Full field-hotbar render is distinct from cursor-only selection updates.
const UI_FIELD_HOTBAR_RENDERED := &"ui_field_hotbar_rendered"
const UI_FIELD_HOTBAR_SELECTION_RENDERED := &"ui_field_hotbar_selection_rendered"
const UI_TARGETING_SHOWN := &"ui_targeting_shown"
const UI_SLOT_INFO_RENDERED := &"ui_slot_info_rendered"
const UI_TERRAIN_RENDERED := &"ui_terrain_rendered"
const UI_AIM_PREVIEW_RENDERED := &"ui_aim_preview_rendered"
const UI_AI_PLAYBACK_DONE := &"ui_ai_playback_done"
const UI_DIALOGUE_SHOWN := &"ui_dialogue_shown"
const UI_DIALOGUE_HIDDEN := &"ui_dialogue_hidden"
const UI_DIALOGUE_PAGE_RENDERED := &"ui_dialogue_page_rendered"
const UI_DIALOGUE_RENDERED := &"ui_dialogue_rendered"
const UI_DIALOGUE_LINE_HIDDEN := &"ui_dialogue_line_hidden"
const UI_PICKER_RENDERED := &"ui_picker_rendered"
const UI_TOAST_RENDERED := &"ui_toast_rendered"
const UI_DEBUG_OVERLAY_RENDERED := &"ui_debug_overlay_rendered"  ## GH#279 dev overlay (debug builds only)
const UI_DEBUG_OVERLAY_HIDDEN := &"ui_debug_overlay_hidden"
const UI_HINT_RENDERED := &"ui_hint_rendered"
const UI_JOURNAL_SHOWN := &"ui_journal_shown"
const UI_JOURNAL_HIDDEN := &"ui_journal_hidden"
const UI_JOURNAL_LOADOUT_RENDERED := &"ui_journal_loadout_rendered"
const UI_CHRONICLE_RENDERED := &"ui_chronicle_rendered"
# Opening inventory drives open audio; selection renders must not replay it.
const UI_INVENTORY_SHOWN := &"ui_inventory_shown"
const UI_INVENTORY_SELECTION_RENDERED := &"ui_inventory_selection_rendered"
const UI_INVENTORY_HIDDEN := &"ui_inventory_hidden"
const UI_PAUSE_SHOWN := &"ui_pause_shown"
const UI_PAUSE_HIDDEN := &"ui_pause_hidden"
const UI_SLOT_PICKER_RENDERED := &"ui_slot_picker_rendered"
const UI_SLOT_PICKER_HIDDEN := &"ui_slot_picker_hidden"
const UI_TITLE_RENDERED := &"ui_title_rendered"
const UI_TITLE_GATE_RENDERED := &"ui_title_gate_rendered"
const UI_TITLE_NOTICE_RENDERED := &"ui_title_notice_rendered"
const UI_NEW_GAME_CONFIRM_RENDERED := &"ui_new_game_confirm_rendered"
const UI_PLAYTEST_LIST_RENDERED := &"ui_playtest_list_rendered"
const UI_CONSOLIDATION_PROMPT_RENDERED := &"ui_consolidation_prompt_rendered"
const UI_CONSOLIDATION_PROMPT_HIDDEN := &"ui_consolidation_prompt_hidden"
const UI_TUTOR_LINE_RENDERED := &"ui_tutor_line_rendered"
const UI_COMBAT_HINT_RENDERED := &"ui_combat_hint_rendered"
## A combat beat AT THE MOMENT IT IS SEEN. The sim emits an AI turn
## SYNCHRONOUSLY -- footsteps, attack, downed, sting, all at t=0 -- while the
## playback queue unspools the visuals one beat_delay() apart, so anything that
## listened to the raw bus fired seconds before the matching animation. Audio
## rides THIS instead for the beats where the mismatch is audible; the payload
## is the original one plus `beat_type`, so a data row matches on that.
const UI_COMBAT_BEAT := &"ui_combat_beat"

const UI_MOOD_APPLIED := &"ui_mood_applied"
const UI_LIGHTS_RENDERED := &"ui_lights_rendered"
const UI_AMBIENCE_RENDERED := &"ui_ambience_rendered"
const UI_PC_LIGHT_RENDERED := &"ui_pc_light_rendered"
const UI_SNEAK_RENDERED := &"ui_sneak_rendered"
const UI_TELEPORT_RENDERED := &"ui_teleport_rendered"
const UI_WARD_RENDERED := &"ui_ward_rendered"
const UI_COMPANION_RENDERED := &"ui_companion_rendered"
const UI_SLEEP_VEIL_RENDERED := &"ui_sleep_veil_rendered"
const UI_SLEEP_VEIL_FINISHED := &"ui_sleep_veil_finished"
const UI_GDI_OPENER_RENDERED := &"ui_gdi_opener_rendered"
const UI_GDI_EPILOGUE_RENDERED := &"ui_gdi_epilogue_rendered"
const UI_DEFEAT_VEIL_RENDERED := &"ui_defeat_veil_rendered"
## The defeat presentation is OVER: black faded out, the player has chosen.
## Carries `continue` (false == they picked Title). Audio owns the field bed's
## resume off this rather than racing the reload -- see wi_audio's defeat latch.
const UI_DEFEAT_VEIL_FINISHED := &"ui_defeat_veil_finished"
const UI_CHAR_CREATION_RENDERED := &"ui_char_creation_rendered"
const UI_CHAR_CREATION_CONFIRMED := &"ui_char_creation_confirmed"

const INPUT_DEVICE_CHANGED := &"input_device_changed"

const UI_SETTINGS_SHOWN := &"ui_settings_shown"
const UI_SETTINGS_HIDDEN := &"ui_settings_hidden"
const UI_SETTINGS_RENDERED := &"ui_settings_rendered"
const UI_CONTROLS_RENDERED := &"ui_controls_rendered"
const UI_HINTS_REPLAYED := &"ui_hints_replayed"
const UI_HELP_RENDERED := &"ui_help_rendered"
const UI_CREDITS_RENDERED := &"ui_credits_rendered"
const UI_CREDITS_LINK_OPENED := &"ui_credits_link_opened"

## The faced-interactable bracket's state CHANGED (shown, hidden, or moved to a
## different cell/entity). Emitted only on a real transition, never per
## reconcile call -- the reconciler runs on ten event types and most of them
## leave the answer identical. `{showing, cell:[x,y], entity}`; `cell` is the
## faced cell even while hidden, `entity` is "" when nothing is there. The
## bracket itself is pixels a headless log cannot see; this is what makes it
## assertable at all.
const UI_AFFORDANCE_RENDERED := &"ui_affordance_rendered"
