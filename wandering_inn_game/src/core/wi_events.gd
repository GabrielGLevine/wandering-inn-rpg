class_name WIEvents
extends RefCounted
## StringName constants for every domain-event name emitted or matched in
## src/** (M5 arch finding 2-lite). One canonical spelling per event so a
## typo'd emit or match site becomes a parse-time unknown-identifier error
## instead of a silently dead branch.
##
## PURITY: constants only — no autoload, Node, or scene-tree references, so
## this is safe to reference from the sim core (src/core/**) and from bare
## --script test runs alike.
##
## The values ARE the bus contract: QA scripts (qa/scripts/*.json) and the
## JSONL event log assert on these exact strings, so the string a constant
## carries must never change even if code stops referencing it. qa/
## test_driver.gd and the QA JSON scripts stay raw-string/data-driven by
## design and do not use these constants.

# --- Sim lifecycle (wi_game.gd / game.gd) ---
const SIM_INITIALIZED := &"sim_initialized"
const GAME_RESET := &"game_reset"
const GAME_LOADED := &"game_loaded"
const GAME_OVER := &"game_over"
const TOAST := &"toast"

# --- Field / exploration (wi_game.gd) ---
const MAP_CHANGED := &"map_changed"
const PLAYER_MOVED := &"player_moved"
const PLAYER_BLOCKED := &"player_blocked"
const INTERACT_NOTHING := &"interact_nothing"
const INTERACT_UNHANDLED := &"interact_unhandled"
const ENTITY_REMOVED := &"entity_removed"
## A map CELL changed its traversable
## look. Payload `{map:String, cell:[x,y], to:String}` where `to` is:
##   "ice"      -- a freezable water cell was frost-cast into walkable ice
##                 (frozen until the next sleep). Presentation paints the ice
##                 tile overlay (the water-shimmer overlay precedent) at the cell.
##   "scorched" -- a burnable blocking prop was fire-cast away (the prop itself
##                 is removed via ENTITY_REMOVED; this carries the vacated cell so
##                 presentation can drop a burn poof there, the hit_sparks reuse).
## Purely additive: the sim's walkability (is_cell_blocked) already reflects the
## change before this fires; nothing existing consumes or depends on it.
const TERRAIN_CHANGED := &"terrain_changed"
## `sneaking` toggled true/false. Fired by
## the deliberate field-hotbar toggle (`_toggle_sneak`, a `sneaks: true`-tagged
## skill's number key) AND by every automatic break (`_break_sneak` -- interact()
## reaching a non-door response, a successful field-skill use on a target,
## start_combat from any cause). Payload `{}` -- presentation reads the
## authoritative `Game.sim.sneaking` bool, not the event, matching the
## light_active/UI_PC_LIGHT_RENDERED reconcile idiom. The toast (the player-
## visible "You soften your step."/"You straighten up." line) is a separate
## TOAST emit alongside these, same as every other state-change pair in this
## file.
const SNEAK_STARTED := &"sneak_started"
const SNEAK_ENDED := &"sneak_ended"
## `WIGame.hotbar_loadout` changed (a journal
## assign/unassign toggle). Payload `{skill:String, assigned:bool,
## loadout:Array[String]}` -- `assigned` is true on an assign, false on an
## unassign; `loadout` is the FULL updated ordered array so QA can assert
## exact contents/order without a separate snapshot read. Mirrors
## GOLD_CHANGED/SNEAK_STARTED's "plain sim-state event, not ui_-prefixed"
## naming (the plan text's placeholder name was `ui_loadout_changed`; this is
## a SIM mutation like those, not a presentation confirmation, so it follows
## their naming convention instead -- disclosed in the K2b report).
## `field_hotbar.gd` listens for this to re-render (same trigger-list idiom
## as CLASS_GAINED/CLASS_LEVEL_UP/CLASS_EVOLVED); combat's bar re-derives
## fresh from `Game.sim.hotbar_loadout` at the next `TURN_STARTED` (the
## journal can never be open mid-combat, so no listener is needed there).
const LOADOUT_CHANGED := &"loadout_changed"

# --- Skills / progression (wi_game.gd) ---
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

# --- Dialogue (dialogue.gd / wi_game.gd) ---
const DIALOGUE_STARTED := &"dialogue_started"
const DIALOGUE_NODE := &"dialogue_node"
const DIALOGUE_LINE := &"dialogue_line"
const DIALOGUE_CHOICE := &"dialogue_choice"
const DIALOGUE_ENDED := &"dialogue_ended"
const DIALOGUE_EFFECT_FAILED := &"dialogue_effect_failed"

# --- Quests (wi_game.gd) ---
const QUEST_STARTED := &"quest_started"
const QUEST_BEAT_COMPLETED := &"quest_beat_completed"
const QUEST_COMPLETED := &"quest_completed"

# --- Items / equipment (wi_game.gd, M7) ---
const ITEM_GAINED := &"item_gained"
const ITEM_EQUIPPED := &"item_equipped"
const ITEM_UNEQUIPPED := &"item_unequipped"
const LOOT_DROPPED := &"loot_dropped"
## Emitted by `WIGame.remove_item` -- the first inventory-REMOVAL
## seam this codebase has needed (every prior item flow only ever ADDS via
## `pickup`). Payload `{item:String, source:String}`, the same shape as
## ITEM_GAINED -- `source` is free-form provenance (a delivery id on a
## handoff or a sleep-fail return), never branched on here.
const ITEM_LOST := &"item_lost"
## Emitted by `WIGame.earn_gold`/`spend_gold` on every
## successful gold change (a refused spend at insufficient gold emits NOTHING
## here -- only the refusal TOAST). Payload `{delta:int, total:int,
## source:String}` -- `delta` is signed (+earn, -spend), `total` is the new
## balance, `source` is the free-form earn source / spend sink id (a
## conversation id for a shop buy, an encounter id for loot gold, a prop id
## for a chore). Diegetic-money direction: no always-on HUD reads this; the
## inventory-panel coin line (D3) and the earn/spend toasts are the display.
const GOLD_CHANGED := &"gold_changed"
## Emitted whenever `WIGame.phase()`'s
## classification of `actions_since_sleep` crosses a threshold (day->dusk->
## night), AND unconditionally on every `sleep()` reset (even a same-phase
## "day"->"day" reset) -- see wi_game.gd's `_tick_action`/`phase`/`sleep` doc
## comments. Nothing renders this yet (a future Beauty/mood pilot consumes it).
const PHASE_CHANGED := &"phase_changed"

# --- Combat (wi_combat.gd / skill_effects.gd / wi_game.gd) ---
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
## Issue #60 item 3: emitted by WICombat._move_pool_bonus_total (called from
## `_start_turn`) once per holder per turn for EVERY skill whose
## `effect.type == "move_pool_bonus"` (today quick_movement/battlefield_
## awareness -- data-driven off the effect type, never a skill-id check, so
## a future 0-cost move_pool_bonus passive is covered for free). Payload
## `{id:String, skill:String}` -- same shape as REACTION_TRIGGERED, on
## purpose: wi_game.gd's `_combat_event_relay` matches BOTH types to bank
## the first proc into `used_skills` (the journal's first-use reveal), since
## a passive never "casts" and so never reaches `used_skills` any other way.
## Fires unconditionally every turn a holder acts (no cast/cost/refusal --
## see `_move_pool_bonus_total`'s own doc comment), so this is NOT a rare
## trigger like a reaction -- the relay's used_skills.append is idempotent
## (a no-op past the first proc), same contract REACTION_TRIGGERED already
## relies on. Presentation-inert: `combat_screen.gd` has no render arm for
## it and it needs none (no card/feed text change, no visual) -- fires fine
## from inside an AI-controlled turn's `_start_turn` (verified: TURN_STARTED
## for the NEXT active combatant, fired synchronously from inside
## WICombatAI.take_turn's own end_turn() call, already reaches combat_
## screen.gd's live match arm the same way even though `_ai_turn_active` is
## still true at that moment -- AI_PLAYBACK_TYPES only matters for events
## with an actual render effect; this one has none, so no new entry needed
## there).
const PASSIVE_APPLIED := &"passive_applied"
const DASHED := &"dashed"
const AP_CHANGED := &"ap_changed"
const MP_CHANGED := &"mp_changed"
const STATUS_APPLIED := &"status_applied"
const STATUS_EXPIRED := &"status_expired"
## Emitted by WISkillEffects.
## resolve_active's icy_floor resolver the moment cells are registered into
## WICombat.terrain. Payload `{kind:"icy_floor", cells:[[x,y],...] sorted,
## rounds:int}` -- `cells` is the FULL blast area (walls/out-of-bounds
## already clipped), `rounds` is the skill's `duration_rounds` (informational;
## the authoritative expiry lives on each terrain entry's
## `expires_after_round`, not recomputed from this payload).
const TERRAIN_ADDED := &"terrain_added"
## Emitted by WICombat._advance_turn's round-rollover branch, once per
## kind, whenever purging stale terrain removes at least one cell. Payload
## `{kind:String, cells:[[x,y],...] sorted}`.
const TERRAIN_EXPIRED := &"terrain_expired"
## Issue #82's WINDUP SIM SPEC: emitted by WISkillEffects.declare_windup the
## moment a `windup_rounds`-carrying skill DECLARES (spends its cost, freezes
## the target cell set) instead of resolving. Payload `{id:String (the
## caster), skill:String, cells:[[x,y],...] sorted}` -- `cells` is the SAME
## frozen shape resolution will apply against later (WICombat._resolve_windup,
## at the caster's own next turn start), not recomputed at that point. Fires
## mid-AI-turn (today's only holder, `slam`, is enemy-only) -- MUST ride
## combat_screen.gd's `AI_PLAYBACK_TYPES` (see that const's own TRAP comment)
## or it renders desynced against end-of-turn state.
const WINDUP_DECLARED := &"windup_declared"

# --- Presentation confirmations (ui_* back onto the bus) + audio ---
# `ui_world_labels_rendered` RETIRED (spec §8 addendum) -- field
# name tags/combat name tags no longer render at all, so nothing publishes
# this event anymore (see world.gd's/board_renderer.gd's doc comments).
# Combat's HP/MP stat readout still goes through WIWorldLabels, just with no
# corresponding "rendered" confirmation event of its own -- QA reads it via
# `assert_world_labels_in_view` (geometry, not an emit-count) instead.
const WORLD_READY := &"world_ready"
const AUDIO_PLAYED := &"audio_played"
const UI_MAP_RENDERED := &"ui_map_rendered"
const UI_ENTITIES_RENDERED := &"ui_entities_rendered"
const UI_ARENA_RENDERED := &"ui_arena_rendered"
const UI_COMBAT_SHOWN := &"ui_combat_shown"
const UI_COMBAT_HIDDEN := &"ui_combat_hidden"
const UI_HOTBAR_RENDERED := &"ui_hotbar_rendered"
## The overworld field-skill hotbar re-rendered (WORLD_READY /
## class gain-levelup-evolve). Payload `{slots: int}` -- the count of KNOWN
## field-tagged skills currently shown (0 for a classless cold start), mirroring
## UI_HOTBAR_RENDERED's `{slots}` shape exactly.
const UI_FIELD_HOTBAR_RENDERED := &"ui_field_hotbar_rendered"
## The field hotbar's cursor selection (re)rendered -- fires from
## `field_hotbar.gd`'s `set_selected(index)`, the single call site world.gd's
## Tab-prime/[/]/pad-cursor navigation and the confirm/cancel/disarm branches
## all route through (issue #58). Distinct from UI_FIELD_HOTBAR_RENDERED
## (which means "the slot LIST changed"): this one means "the HIGHLIGHT (and
## its floating skill-name label) changed", firing on every cursor step
## including disarm (`index == -1`, label goes away). Payload `{index: int,
## skill: String, label: String}` -- `index` mirrors world.gd's
## `_field_slot_index`; `skill` is the selected slot's skill id ("" when
## disarmed); `label` is the rendered bracket-style text ("[Basic Cleaning]"
## -- already bracketed by `display_name` itself, see field_hotbar.gd's file
## doc comment) or "" when disarmed.
const UI_FIELD_HOTBAR_SELECTION_RENDERED := &"ui_field_hotbar_selection_rendered"
const UI_TARGETING_SHOWN := &"ui_targeting_shown"
const UI_SLOT_INFO_RENDERED := &"ui_slot_info_rendered"
## board_renderer.gd's confirmation
## that a TERRAIN_ADDED cast actually drew its persistent cell overlay.
## Payload `{kind:String, cells:[[x,y],...]}`, same shape as the domain
## event it confirms -- the ui_*_rendered idiom (UI_ARENA_RENDERED et al.).
const UI_TERRAIN_RENDERED := &"ui_terrain_rendered"
## Issue #75 item 1: board_renderer.gd's confirmation that the board-space aim
## preview (target ring, range tint, line/blast footprint) redrew while
## ATTACK/SKILL_TARGET is armed -- fires on `enter()`/cycle/direction-change/
## click-reselect (every `combat_screen.gd._refresh()` while in_targeting),
## deduped so an unchanged preview doesn't re-fire. AIM STATE, not juice --
## unlike the shake/spark/flash effects, this is NOT QA-collapsed (it must
## render and confirm identically headless and windowed). Payload
## `{kind: "attack"|"skill"|"line"|"blast", cells: [[x,y],...]}` -- `cells` is
## the PRIMARY sim-derived footprint for `kind` (the line path for "line", the
## radius_area for "blast", the single selected candidate's cell for
## "attack"/"skill"; the faint range-reach tint is paint-only, not asserted
## here).
const UI_AIM_PREVIEW_RENDERED := &"ui_aim_preview_rendered"
const UI_AI_PLAYBACK_DONE := &"ui_ai_playback_done"
const UI_DIALOGUE_SHOWN := &"ui_dialogue_shown"
const UI_DIALOGUE_HIDDEN := &"ui_dialogue_hidden"
const UI_DIALOGUE_RENDERED := &"ui_dialogue_rendered"
const UI_TOAST_RENDERED := &"ui_toast_rendered"
const UI_HINT_RENDERED := &"ui_hint_rendered"
const UI_JOURNAL_SHOWN := &"ui_journal_shown"
const UI_JOURNAL_HIDDEN := &"ui_journal_hidden"
## journal.gd's confirmation that its own skills-panel
## body redrew after a loadout toggle (the cursor highlight + the ✓/blank
## assign marker) -- separate from UI_JOURNAL_SHOWN (which only fires on
## open) so QA can assert the LIVE in-panel update without closing/reopening.
## Payload `{skill:String, assigned:bool, cursor_index:int}`.
const UI_JOURNAL_LOADOUT_RENDERED := &"ui_journal_loadout_rendered"
const UI_INVENTORY_SHOWN := &"ui_inventory_shown"
## inventory.gd's confirmation that the selection corner (icon + mechanical
## breakout) redrew after a cursor move -- separate from UI_INVENTORY_SHOWN
## (which fires on open and on gold/equip re-confirms) so QA can pin the
## per-selection corner WITHOUT re-firing the panel-open event: audio.json
## keys the `ui_open` chime on UI_INVENTORY_SHOWN, so a shown-per-cursor-move
## emit would replay the open chime on every arrow press (the
## UI_JOURNAL_LOADOUT_RENDERED idiom, same reason). Payload `{cursor:int,
## item:String, selected_icon:bool, mech_line:String}`.
const UI_INVENTORY_SELECTION_RENDERED := &"ui_inventory_selection_rendered"
const UI_INVENTORY_HIDDEN := &"ui_inventory_hidden"
const UI_PAUSE_SHOWN := &"ui_pause_shown"
const UI_PAUSE_HIDDEN := &"ui_pause_hidden"
const UI_TITLE_RENDERED := &"ui_title_rendered"
const UI_TITLE_GATE_RENDERED := &"ui_title_gate_rendered"
const UI_TITLE_NOTICE_RENDERED := &"ui_title_notice_rendered"
## title_screen.gd's confirmation that the
## debug-only "Playtest States" picker opened. Payload `{count:int, pages:int}`
## -- `count` is the total fixture entries discovered under `qa/fixtures/`,
## `pages` is the derived page count at `PLAYTEST_PAGE_SIZE` rows/page. Fired
## once per open (the UI_PAUSE_SHOWN idiom), not on every cursor move.
const UI_PLAYTEST_LIST_RENDERED := &"ui_playtest_list_rendered"
const UI_CONSOLIDATION_PROMPT_RENDERED := &"ui_consolidation_prompt_rendered"
const UI_CONSOLIDATION_PROMPT_HIDDEN := &"ui_consolidation_prompt_hidden"
## Floodplains P1: declarative `arena_config["tutor_lines"]` feed handler in
## combat_screen.gd. Emitted at most once per tutor_lines entry id, the
## moment that entry's line actually renders into the prose feed (paced to
## the AI playback queue for AI-turn triggers, immediate for player-turn
## triggers — see combat_screen.gd's _render_tutor_line doc comment).
const UI_TUTOR_LINE_RENDERED := &"ui_tutor_line_rendered"
## combat_screen.gd's confirmation that the one-time first-combat kit hint
## (issue #60 item 1: combat skills are class+weapon-derived, no loadout
## editor -- the player just needs to be TOLD) pushed into the prose feed.
## Fires at most once per process/GAME_RESET (the message_layer.gd first-
## pickup-hint static-var idiom), on the FIRST combat_started only. Payload
## `{text:String}` -- the exact composed line (WIInputHints.label("hotbar")
## threaded in), so QA can assert content without OCR-ing a screenshot.
const UI_COMBAT_HINT_RENDERED := &"ui_combat_hint_rendered"

## Emitted by src/world/atmosphere.gd (a CanvasModulate
## child of the world viewport's root, WIWorld) every time it applies a
## mood color for (map, phase) — on world_ready, map_changed, and
## phase_changed. Identity-grade this task (moods.json ships [1,1,1] for
## every map/phase — zero visible change); the pilot (B4) is the first
## consumer of real color data.
const UI_MOOD_APPLIED := &"ui_mood_applied"
## Declared but not yet emitted: light layer
## confirmation — {map, count} once PointLight2Ds are spawned from
## entity/decor `light` data.
const UI_LIGHTS_RENDERED := &"ui_lights_rendered"
## Declared but not yet emitted: ambience layer
## confirmation — {map, emitters} once GPUParticles2D presets are spawned
## from map `ambience` data.
const UI_AMBIENCE_RENDERED := &"ui_ambience_rendered"
## Playtest feature 3 ([Light] glow on the PC): world.gd's confirmation that the
## PC-following arcane glow (an UNREGISTERED constant PointLight2D on the player
## visual, bypassing the phase multiplier so it stays lit at day too) actually
## attached or detached. Payload `{active: bool}` -- true when the glow is drawn
## (the field-ambient [Light] cast, or a rebuild re-attach while `light_active`),
## false when it is removed (the sleep clear). Emitted ONLY on a real state
## change, never on an idempotent re-cast/phase-crossing reconcile.
const UI_PC_LIGHT_RENDERED := &"ui_pc_light_rendered"
## world.gd's confirmation that the PC sprite's
## translucency (modulate.a ~0.6, the tint-machinery precedent) actually
## matches `Game.sim.sneaking`. Payload `{active: bool}` -- mirrors
## UI_PC_LIGHT_RENDERED's shape exactly. Emitted from `_reconcile_sneak_visual`,
## called on SNEAK_STARTED/SNEAK_ENDED and from `_rebuild_field` (a door
## crossing keeps `sneaking` true, so the translucency must survive the field
## rebuild the new map triggers).
const UI_SNEAK_RENDERED := &"ui_sneak_rendered"
## GDI sleep sequence: emitted by src/ui/sleep_veil.gd once
## the black veil is fully drawn and the night's GDI proclamation lines are laid
## out (before the read-hold), carrying {lines:int} = how many announcement lines
## the veil rendered (0 = a plain "slept soundly" black dip). PURELY ADDITIVE UI
## confirmation (the message_layer ui_*_rendered idiom): the veil consumes and
## alters NO existing event — the same phase_changed/class_*/toast stream still
## fires beneath it — so every prior QA assertion holds unchanged. Under QA/
## headless the veil's fades/holds collapse to ~0 (the paced-playback precedent),
## so this event fires effectively synchronously right after the sleep beat.
const UI_SLEEP_VEIL_RENDERED := &"ui_sleep_veil_rendered"
## The veil's sleep sequence is FULLY OVER (fade back to transparent complete,
## black hidden, line labels freed) -- emitted by src/ui/sleep_veil.gd at the
## very end of _run_sequence, AFTER UI_SLEEP_VEIL_RENDERED (which fires at
## line-layout time, before the read-hold/fade-out). This is the "screen is
## the player's again" moment: consolidation_prompt.gd holds a pending offer
## modal hidden (and its input dead) until this event, so the offer surfaces
## with/after the sleep's own announcements, never on top of the black
## (playtest hotfix #8). Fires for EVERY sleep sequence (offer or not) in
## both the QA-collapsed and real-paced paths -- so event ORDER
## (ui_sleep_veil_rendered -> ui_sleep_veil_finished ->
## ui_consolidation_prompt_rendered) is headless-provable.
const UI_SLEEP_VEIL_FINISHED := &"ui_sleep_veil_finished"
## GDI new-game opener: emitted by src/ui/sleep_veil.gd once the
## black cold-open's Grand Design arrival lines are laid out, carrying
## {lines:int} = how many opener lines were rendered. Fired ONLY on a New Game
## (GAME_RESET -> fresh world; WIMain drives it), never on Continue/load. Same
## additive ui_*_rendered idiom as UI_SLEEP_VEIL_RENDERED; under QA/headless the
## opener collapses to instant and this fires synchronously right after
## world_ready, so title_flow can assert it deterministically.
const UI_GDI_OPENER_RENDERED := &"ui_gdi_opener_rendered"
## The GDI epilogue -- the veil's THIRD mode: emitted by
## src/ui/sleep_veil.gd once the post-victory epilogue's Grand Design lines are
## laid out, carrying {lines:int} = how many epilogue lines rendered (the GDI
## open/close copy + the GENERATED per-class recount + the wanderinginn.com
## line). Fires ONCE, the beat after `raskghar_sealed` banks (armed by that
## accomplishment_recorded, played on the following dialogue_ended). Same
## additive ui_*_rendered idiom as the opener; under QA/headless the epilogue
## collapses to instant and this fires synchronously so arc_flow can assert the
## line count. The epilogue's completion banks `post_game` (its re-fire guard +
## the journal Act III completed beat), so this event never re-emits.
const UI_GDI_EPILOGUE_RENDERED := &"ui_gdi_epilogue_rendered"
## Character creation: emitted by src/ui/char_creation.gd each time the
## creation screen (re)renders a step, carrying {step:String} where step is
## "pick" (the six-sprite grid) / "name" -- lets the char_creation QA script wait on the real
## UI advancing without frame-count guessing (the title_gate/title_rendered
## idiom). A separate {race,gender,name} payload rides UI_CHAR_CREATION_CONFIRMED
## when the player confirms and the New Game (with creation) fires.
const UI_CHAR_CREATION_RENDERED := &"ui_char_creation_rendered"
const UI_CHAR_CREATION_CONFIRMED := &"ui_char_creation_confirmed"

## Emitted by `src/ui/input_hints.gd`
## (`WIInputHints` autoload) the moment the last-seen input device class
## actually CHANGES (never on every event -- see that file's doc comment).
## Payload `{device: "kb"|"pad"}`. Presentation panels that render a keycap
## hint listen for this to re-render with the new device's glyphs.
const INPUT_DEVICE_CHANGED := &"input_device_changed"

# --- Settings / accessibility (src/ui/wi_settings.gd, src/ui/settings_panel.gd) ---
## settings_panel.gd's confirmation that it opened -- reachable from BOTH
## pause_menu.gd's and title_screen.gd's own "Settings" row (issue #77).
const UI_SETTINGS_SHOWN := &"ui_settings_shown"
const UI_SETTINGS_HIDDEN := &"ui_settings_hidden"
## Fires on every settings_panel.gd `_refresh()` (open, cursor move, value
## change -- the UI_INVENTORY_SELECTION_RENDERED idiom), carrying the FULL
## live snapshot so QA can assert any control's current state without a
## dedicated probe per field. Payload `{master:int, music:int, sfx:int,
## fullscreen:bool, text_scale_step:int, reduce_motion:bool}`.
const UI_SETTINGS_RENDERED := &"ui_settings_rendered"
## settings_panel.gd's confirmation that the Controls reference sub-page
## (keyboard/pad/mouse tables, reusing WIInputHints.LABELS) rendered.
## Payload `{rows:int}` -- the action-row count shown.
const UI_CONTROLS_RENDERED := &"ui_controls_rendered"
## settings_panel.gd's confirmation that "Replay Hints" re-armed the
## process-lifetime one-shot tutorial hints (WISettings.replay_hints() --
## message_layer.gd's first-pickup hint, combat_screen.gd's first-combat
## hint). Presentation-only re-arm, never touches accomplishment counters.
const UI_HINTS_REPLAYED := &"ui_hints_replayed"
