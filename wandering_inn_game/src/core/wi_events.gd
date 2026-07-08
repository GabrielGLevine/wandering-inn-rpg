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
## Skills Wave Task K1 (traversal seams): a map CELL changed its traversable
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
## Skills Wave Task K2 (the sneak seam): `sneaking` toggled true/false. Fired by
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
## Skills Wave Task K2b: `WIGame.hotbar_loadout` changed (a journal
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
## M-DEPTH DP5: emitted by `WIGame.remove_item` -- the first inventory-REMOVAL
## seam this codebase has needed (every prior item flow only ever ADDS via
## `pickup`). Payload `{item:String, source:String}`, the same shape as
## ITEM_GAINED -- `source` is free-form provenance (a delivery id on a
## handoff or a sleep-fail return), never branched on here.
const ITEM_LOST := &"item_lost"
## Economy v1 Task D1: emitted by `WIGame.earn_gold`/`spend_gold` on every
## successful gold change (a refused spend at insufficient gold emits NOTHING
## here -- only the refusal TOAST). Payload `{delta:int, total:int,
## source:String}` -- `delta` is signed (+earn, -spend), `total` is the new
## balance, `source` is the free-form earn source / spend sink id (a
## conversation id for a shop buy, an encounter id for loot gold, a prop id
## for a chore). Diegetic-money direction: no always-on HUD reads this; the
## inventory-panel coin line (D3) and the earn/spend toasts are the display.
const GOLD_CHANGED := &"gold_changed"
## M7 Task E2, M-BEAUTY FOLD amendment: emitted whenever `WIGame.phase()`'s
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
const DASHED := &"dashed"
const AP_CHANGED := &"ap_changed"
const MP_CHANGED := &"mp_changed"
const STATUS_APPLIED := &"status_applied"
const STATUS_EXPIRED := &"status_expired"
## GH#21 ([Ice Floor] area terrain effect): emitted by WISkillEffects.
## resolve_active's icy_floor resolver the moment cells are registered into
## WICombat.terrain. Payload `{kind:"icy_floor", cells:[[x,y],...] sorted,
## rounds:int}` -- `cells` is the FULL blast area (walls/out-of-bounds
## already clipped), `rounds` is the skill's `duration_rounds` (informational;
## the authoritative expiry lives on each terrain entry's
## `expires_after_round`, not recomputed from this payload).
const TERRAIN_ADDED := &"terrain_added"
## GH#21: emitted by WICombat._advance_turn's round-rollover branch, once per
## kind, whenever purging stale terrain removes at least one cell. Payload
## `{kind:String, cells:[[x,y],...] sorted}`.
const TERRAIN_EXPIRED := &"terrain_expired"

# --- Presentation confirmations (ui_* back onto the bus) + audio ---
# M-BEAUTY R3 (spec §8 addendum): `ui_world_labels_rendered` RETIRED -- field
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
## Three Pillars P2: the overworld field-skill hotbar re-rendered (WORLD_READY /
## class gain-levelup-evolve). Payload `{slots: int}` -- the count of KNOWN
## field-tagged skills currently shown (0 for a classless cold start), mirroring
## UI_HOTBAR_RENDERED's `{slots}` shape exactly.
const UI_FIELD_HOTBAR_RENDERED := &"ui_field_hotbar_rendered"
const UI_TARGETING_SHOWN := &"ui_targeting_shown"
const UI_SLOT_INFO_RENDERED := &"ui_slot_info_rendered"
## GH#21 ([Ice Floor] area terrain effect): board_renderer.gd's confirmation
## that a TERRAIN_ADDED cast actually drew its persistent cell overlay.
## Payload `{kind:String, cells:[[x,y],...]}`, same shape as the domain
## event it confirms -- the ui_*_rendered idiom (UI_ARENA_RENDERED et al.).
const UI_TERRAIN_RENDERED := &"ui_terrain_rendered"
const UI_AI_PLAYBACK_DONE := &"ui_ai_playback_done"
const UI_DIALOGUE_SHOWN := &"ui_dialogue_shown"
const UI_DIALOGUE_HIDDEN := &"ui_dialogue_hidden"
const UI_DIALOGUE_RENDERED := &"ui_dialogue_rendered"
const UI_TOAST_RENDERED := &"ui_toast_rendered"
const UI_HINT_RENDERED := &"ui_hint_rendered"
const UI_JOURNAL_SHOWN := &"ui_journal_shown"
const UI_JOURNAL_HIDDEN := &"ui_journal_hidden"
## Skills Wave Task K2b: journal.gd's confirmation that its own skills-panel
## body redrew after a loadout toggle (the cursor highlight + the ✓/blank
## assign marker) -- separate from UI_JOURNAL_SHOWN (which only fires on
## open) so QA can assert the LIVE in-panel update without closing/reopening.
## Payload `{skill:String, assigned:bool, cursor_index:int}`.
const UI_JOURNAL_LOADOUT_RENDERED := &"ui_journal_loadout_rendered"
const UI_INVENTORY_SHOWN := &"ui_inventory_shown"
const UI_INVENTORY_HIDDEN := &"ui_inventory_hidden"
const UI_PAUSE_SHOWN := &"ui_pause_shown"
const UI_PAUSE_HIDDEN := &"ui_pause_hidden"
const UI_TITLE_RENDERED := &"ui_title_rendered"
const UI_TITLE_GATE_RENDERED := &"ui_title_gate_rendered"
const UI_TITLE_NOTICE_RENDERED := &"ui_title_notice_rendered"
## Issue #43 (playtest state boot): title_screen.gd's confirmation that the
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

## M-BEAUTY Task B1: emitted by src/world/atmosphere.gd (a CanvasModulate
## child of the world viewport's root, WIWorld) every time it applies a
## mood color for (map, phase) — on world_ready, map_changed, and
## phase_changed. Identity-grade this task (moods.json ships [1,1,1] for
## every map/phase — zero visible change); the pilot (B4) is the first
## consumer of real color data.
const UI_MOOD_APPLIED := &"ui_mood_applied"
## M-BEAUTY Task B2 (declared now per plan, not yet emitted): light layer
## confirmation — {map, count} once PointLight2Ds are spawned from
## entity/decor `light` data.
const UI_LIGHTS_RENDERED := &"ui_lights_rendered"
## M-BEAUTY Task B3 (declared now per plan, not yet emitted): ambience layer
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
## Skills Wave Task K2: world.gd's confirmation that the PC sprite's
## translucency (modulate.a ~0.6, the tint-machinery precedent) actually
## matches `Game.sim.sneaking`. Payload `{active: bool}` -- mirrors
## UI_PC_LIGHT_RENDERED's shape exactly. Emitted from `_reconcile_sneak_visual`,
## called on SNEAK_STARTED/SNEAK_ENDED and from `_rebuild_field` (a door
## crossing keeps `sneaking` true, so the translucency must survive the field
## rebuild the new map triggers).
const UI_SNEAK_RENDERED := &"ui_sneak_rendered"
## M-JUICE Track P2 (GDI sleep sequence): emitted by src/ui/sleep_veil.gd once
## the black veil is fully drawn and the night's GDI proclamation lines are laid
## out (before the read-hold), carrying {lines:int} = how many announcement lines
## the veil rendered (0 = a plain "slept soundly" black dip). PURELY ADDITIVE UI
## confirmation (the message_layer ui_*_rendered idiom): the veil consumes and
## alters NO existing event — the same phase_changed/class_*/toast stream still
## fires beneath it — so every prior QA assertion holds unchanged. Under QA/
## headless the veil's fades/holds collapse to ~0 (the M4 T10 pacing precedent),
## so this event fires effectively synchronously right after the sleep beat.
const UI_SLEEP_VEIL_RENDERED := &"ui_sleep_veil_rendered"
## M-ARC Task F1 (GDI new-game opener): emitted by src/ui/sleep_veil.gd once the
## black cold-open's Grand Design arrival lines are laid out, carrying
## {lines:int} = how many opener lines were rendered. Fired ONLY on a New Game
## (GAME_RESET -> fresh world; WIMain drives it), never on Continue/load. Same
## additive ui_*_rendered idiom as UI_SLEEP_VEIL_RENDERED; under QA/headless the
## opener collapses to instant and this fires synchronously right after
## world_ready, so title_flow can assert it deterministically.
const UI_GDI_OPENER_RENDERED := &"ui_gdi_opener_rendered"
## M-ARC Task A4 (the GDI epilogue -- the veil's THIRD mode): emitted by
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
## M-ARC §5 character creation: emitted by src/ui/char_creation.gd each time the
## creation screen (re)renders a step, carrying {step:String} where step is
## "pick" (the six-sprite grid, issue #42) / "name" -- lets the char_creation QA script wait on the real
## UI advancing without frame-count guessing (the title_gate/title_rendered
## idiom). A separate {race,gender,name} payload rides UI_CHAR_CREATION_CONFIRMED
## when the player confirms and the New Game (with creation) fires.
const UI_CHAR_CREATION_RENDERED := &"ui_char_creation_rendered"
const UI_CHAR_CREATION_CONFIRMED := &"ui_char_creation_confirmed"

## Controller support (S3, issue #18): emitted by `src/ui/input_hints.gd`
## (`WIInputHints` autoload) the moment the last-seen input device class
## actually CHANGES (never on every event -- see that file's doc comment).
## Payload `{device: "kb"|"pad"}`. Presentation panels that render a keycap
## hint listen for this to re-render with the new device's glyphs.
const INPUT_DEVICE_CHANGED := &"input_device_changed"
