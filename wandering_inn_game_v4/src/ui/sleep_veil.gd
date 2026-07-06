extends CanvasLayer
## M-JUICE Track P2 — the GDI (Grand Design of Isthekenous) sleep sequence.
##
## When the player sleeps, instead of an instant morning this veil fades the
## whole screen to BLACK, holds the darkness, and renders the night's
## level/class/evolution announcements as centered proclamations in the dark —
## the System's voice, canon cadence ("[Warrior Class Obtained!]",
## "[Warrior Level 2!]", "[Skill – Basic Cleaning Obtained!]") — then fades back
## in on morning. A plain sleep (no announcements) is a brief black dip.
##
## PRESENTATION-ONLY, ZERO SIM CHANGE. The veil is a pure RENDERER over the
## world: it CONSUMES nothing (no set_input_as_handled), CHANGES no existing
## event, and never touches Game.sim state. The very same phase_changed /
## class_* / skill_unlocked / toast stream still fires beneath it — the toasts
## the veil re-voices are the identical toasts message_layer renders (they play
## out under the black), so every prior QA assertion holds untouched by
## construction. The one additive signal is UI_SLEEP_VEIL_RENDERED, a UI
## confirmation in the message_layer ui_*_rendered idiom (a brand-new type, so
## it interleaves with — never rewrites — any existing stream).
##
## TRIGGER: sleep() (wi_game.gd) emits phase_changed UNCONDITIONALLY as its
## first event, resetting the clock so phase() == "day" (actions_since_sleep is
## 0). A dusk/night threshold crossing during the day emits phase_changed with
## phase "dusk"/"night" and never "day" (see wi_game.gd `_tick_action` vs
## `sleep`), and no load/boot path re-emits phase_changed at all — so
## `phase_changed{phase:"day"}` is a precise, sim-change-free sleep signal. The
## announcements arrive as class_gained/class_level_up/skill_unlocked/
## class_evolved events fired SYNCHRONOUSLY right after that phase_changed in
## the same sleep() call; the veil buffers them, then a single call_deferred
## runs the reveal once the whole synchronous beat has unwound (so the buffer is
## complete). Assumes a phase config where the fresh-clock phase is "day"
## (dusk_at > 0), which is invariant for every shipped/data moods.json config.
##
## QA/HEADLESS COLLAPSE (the M4 T10 paced-playback precedent): under
## TestDriver.active() or the headless server the entire fade/hold/reveal
## collapses to ~0 and the veil clears the same beat — windowed QA is never
## slowed and no screenshot catches a stuck black frame. FEEL is therefore
## human-playtest-gated (like AI pacing); UI_SLEEP_VEIL_RENDERED{lines} is the
## automated coverage proof that it fired.
##
## CONSOLIDATION: a consolidation OFFER can fire at sleep (wi_game.gd defers the
## rest of the beat and emits consolidation_offered). Its modal prompt
## (consolidation_prompt.gd, layer 1) is input-blocking and lives BENEATH this
## veil (layer 30). To never deadlock or hide it, the veil DEFERS: on seeing
## consolidation_offered in the sleep burst it skips the dark hold/reveal and
## fades straight back so the modal owns an unobstructed screen. That sleep
## simply forgoes the GDI treatment (its class/level toasts still fire beneath
## for the player and QA); the black-screen voice returns on the next ordinary
## sleep. A consolidation is rare and self-announced by its own themed modal,
## so this is the low-risk, non-deadlocking choice.

## Layer above every other UI (journal/inventory are 10; message_layer/dialogue/
## consolidation are the default 1) so the darkness covers the whole screen.
const VEIL_LAYER := 30

const FADE_SECONDS := 0.6
const HOLD_BEFORE_TEXT := 0.35
const LINE_INTERVAL := 0.55
const LINE_FADE := 0.4
const READ_HOLD := 1.5
const EMPTY_HOLD := 0.4
const LINE_FONT_SIZE := 24

## M-ARC Task F1 — the GDI new-game opener. A New Game opens on BLACK: the Grand
## Design's voice speaks a few arrival lines in this SAME gold-on-black device
## (reusing _black + _add_line + the layer-30 discipline above — one renderer,
## not a second), then fades into the inn. WIMain calls play_opener() ONLY on the
## GAME_RESET (fresh-world) path — never on Continue/load (see main.gd
## swap_to_world(new_game)). Under QA/headless it collapses to instant and emits
## UI_GDI_OPENER_RENDERED{lines} for coverage (title_flow asserts it); in real
## play it is SKIPPABLE — confirm/cancel advances line-by-line and, past the last
## line, fades to the inn, so a replaying player is never held hostage. This is
## the ONE interactive exception to the veil's "consumes nothing" invariant: the
## opener swallows ONLY confirm/cancel while it holds; the sleep path above still
## intercepts no input at all.
##
## COPY — flagged for user taste-review (revisable via these constants / a
## future string table). A vast, neutral, faintly wondering System voice; the
## last line is a bracketed proclamation in the sleep-veil cadence. Opaque-safe:
## no numbers, no lore claim beyond what the game itself shows (classes/levels).
##
## M-ARC §5: the opener BRANCHES by PC race (canon-safe — only Humans are Earth
## otherworlders). Human keeps the "far from where you began" arrival; Drake and
## Gnoll get a "starting over in Liscor" variant (they are native to Izril, not
## displaced from another world). All three are 4 lines and share the identity-
## neutral bracket close, so the QA opener-line count is invariant across races.
## ⚑ USER TASTE-REVIEW: the Drake/Gnoll copy is a first draft — revise freely.
const OPENER_LINES_HUMAN: Array[String] = [
	"You are far from where you began.",
	"This world watches what you do,",
	"and answers by making you someone.",
	"[Class: none. Level: none. — Begin.]",
]
const OPENER_LINES_DRAKE: Array[String] = [
	"You have come to Liscor to begin again.",
	"This world watches what you do,",
	"and answers by making you someone.",
	"[Class: none. Level: none. — Begin.]",
]
const OPENER_LINES_GNOLL: Array[String] = [
	"The road behind you is long; Liscor is where it ends.",
	"This world watches what you do,",
	"and answers by making you someone.",
	"[Class: none. Level: none. — Begin.]",
]
## Human is the default fallback (an unknown/absent race lands here, matching the
## sim's tolerant "human" default).
const OPENER_LINES: Array[String] = OPENER_LINES_HUMAN
const OPENER_HOLD_BEFORE_TEXT := 0.6
const OPENER_LINE_HOLD := 1.7
const OPENER_READ_HOLD := 2.2

## Display-name maps loaded from data (presentation-only, exactly how content=
## data UI resolves labels): class ids -> raw names ("Warrior"), skill ids ->
## bracketed names ("[Basic Cleaning]"). Loaded once in _ready; independent of
## the sim so the GDI cadence never leaks a raw id.
var _class_names: Dictionary = {}
var _skill_names: Dictionary = {}
## class id -> its level-1 grant skill ids (same source classes.json the
## class_gained toast lists). A CLASS_GAINED event carries ONLY the class id;
## the sim fires NO skill_unlocked for the level-1 kit (check_level_ups starts
## at level+1), so the veil must expand the kit itself to voice the opening
## grants — matching the toast — the way later level-ups already read from
## their own skill_unlocked stream. Loaded once in _ready.
var _class_level1_grants: Dictionary = {}

var _black: ColorRect
var _line_box: VBoxContainer

## True from the sleep phase_changed until the deferred sequence finishes —
## gates line collection and guards against a re-entrant trigger.
var _running := false
## Guards the single call_deferred so a stray second phase_changed can't queue
## a second reveal for the same sleep.
var _reveal_queued := false
var _lines: Array[String] = []
var _consolidation := false

## F1 opener state. _opener_running gates its own input/sequence; _opener_advance
## is set by a confirm/cancel press to cut the current line's hold short.
var _opener_running := false
var _opener_advance := false


func _ready() -> void:
	layer = VEIL_LAYER
	_load_display_names()

	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Pure renderer: never intercept input (zero behaviour change — a player
	# mashing keys under the brief black still drives the world exactly as
	# before). CanvasLayer has no modulate, so fade the ColorRect's own alpha.
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.modulate.a = 0.0
	_black.hide()
	add_child(_black)

	_line_box = VBoxContainer.new()
	UIChrome.apply_theme(_line_box)
	_line_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_line_box.add_theme_constant_override("separation", 18)
	_line_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_line_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_line_box)

	ObservableBus.domain_event.connect(_on_domain_event)


func _on_domain_event(type: String, payload: Dictionary) -> void:
	match type:
		WIEvents.PHASE_CHANGED:
			# Only the sleep beat resets the clock to "day"; dusk/night crossings
			# carry their own phase and boot/load never re-emits — so this is the
			# sleep signal (see the file doc comment).
			if String(payload.get("phase", "")) == "day":
				_begin_sleep()
		WIEvents.CLASS_GAINED:
			if _running:
				var gained_id := String(payload.get("class", ""))
				_lines.append("[%s Class Obtained!]" % _class_name(gained_id))
				# The level-1 kit fires no skill_unlocked event of its own, so
				# expand it here — one [Skill – X Obtained!] line per level-1
				# grant, exactly the kit the class_gained toast lists.
				for sk: Variant in _class_level1_grants.get(gained_id, []):
					_lines.append("[Skill – %s Obtained!]" % _skill_name(String(sk)))
		WIEvents.CLASS_LEVEL_UP:
			if _running:
				_lines.append("[%s Level %d!]" % [_class_name(String(payload.get("class", ""))), int(payload.get("level", 0))])
		WIEvents.SKILL_UNLOCKED:
			if _running:
				_lines.append("[Skill – %s Obtained!]" % _skill_name(String(payload.get("skill", ""))))
		WIEvents.CLASS_EVOLVED:
			if _running:
				_lines.append("[%s Class → %s Class!]" % [_class_name(String(payload.get("from", ""))), _class_name(String(payload.get("to", "")))])
		WIEvents.CONSOLIDATION_OFFERED:
			if _running:
				_consolidation = true


## Opens the collection window and queues the (single) deferred reveal. The
## deferred call runs at the next idle, AFTER sleep()'s whole synchronous emit
## burst has unwound, so `_lines`/`_consolidation` are fully populated by then.
func _begin_sleep() -> void:
	# EF review I2: guard against a sleep beat racing the F1/M-ARC cold open. A
	# player who reaches the inn bed during the ~8s opener would otherwise start a
	# SECOND veil coroutine over the shared _black/_line_box (a cosmetic un-black
	# glitch); _opener_running blocks that until the opener has faded out and
	# cleared. (play_opener has the mirror guard against a sleep already running.)
	if _running or _opener_running:
		return
	_running = true
	_lines = []
	_consolidation = false
	if not _reveal_queued:
		_reveal_queued = true
		_run_sequence.call_deferred()


## M-ARC Task F1 — the GDI new-game cold open. Called by WIMain right after the
## fresh world is spawned, ONLY on GAME_RESET. Opens opaque-black immediately (no
## fade-in — a cold open, not a dip), speaks the arrival lines, then fades to the
## inn. QA/headless collapses to an instant coverage event; real play is paced +
## skippable via _unhandled_input below.
func play_opener() -> void:
	if _running or _opener_running:
		return
	if _is_qa():
		# Collapsed: no visible hold — record coverage the same beat, right after
		# world_ready, so title_flow's assert is deterministic.
		_emit_opener_rendered(_opener_lines().size())
		return
	_opener_running = true
	_run_opener.call_deferred()


## M-ARC §5: the race-branched opener copy (presentation reads the sim's cosmetic
## pc_race; an unknown/absent race falls back to Human, matching the sim default).
func _opener_lines() -> Array:
	match Game.sim.pc_race:
		"drake": return OPENER_LINES_DRAKE
		"gnoll": return OPENER_LINES_GNOLL
		_: return OPENER_LINES_HUMAN


func _run_opener() -> void:
	# Opaque immediately so the just-spawned inn never flashes before the dark.
	_black.modulate.a = 1.0
	_black.show()
	await _wait(OPENER_HOLD_BEFORE_TEXT)
	var lines := _opener_lines()
	for i in lines.size():
		_add_line(String(lines[i]))
		var last := i == lines.size() - 1
		await _wait_or_advance(OPENER_READ_HOLD if last else OPENER_LINE_HOLD)
	_emit_opener_rendered(lines.size())
	await _fade(_black, 0.0)
	_opener_running = false
	_finish()


## Waits up to `seconds`, but returns early the moment a confirm/cancel press
## sets _opener_advance (see _unhandled_input) — line-by-line advance / skip.
func _wait_or_advance(seconds: float) -> void:
	_opener_advance = false
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline and not _opener_advance:
		await get_tree().process_frame


## The opener's ONE interactive touch (the sleep path never intercepts input):
## while the cold open holds, confirm/cancel advances the current line and,
## past the last, skips straight to the inn fade. Swallows only those two
## actions so a replaying player is never held hostage.
func _unhandled_input(event: InputEvent) -> void:
	if not _opener_running:
		return
	if event.is_action_pressed("confirm") or event.is_action_pressed("cancel"):
		_opener_advance = true
		get_viewport().set_input_as_handled()


func _emit_opener_rendered(count: int) -> void:
	# M-ARC §5: carry the PC race so a QA script can assert the branch fired for
	# the chosen race (line count is 4 for every race, so it can't distinguish).
	ObservableBus.emit_domain_event(WIEvents.UI_GDI_OPENER_RENDERED, {"lines": count, "race": Game.sim.pc_race})


func _run_sequence() -> void:
	_reveal_queued = false
	var lines := _lines.duplicate()
	var defer_to_modal := _consolidation

	if _is_qa():
		# Collapsed: no visible hold — record coverage and clear the same beat so
		# no QA screenshot ever catches a black frame.
		_emit_rendered(lines.size())
		_finish()
		return

	_black.show()
	await _fade(_black, 1.0)

	if defer_to_modal:
		# A consolidation modal is about to demand the screen (layer 1, beneath
		# this veil): fade straight back so it is unobstructed. This sleep forgoes
		# the GDI reveal; its toasts still fire beneath for the player + QA.
		_emit_rendered(0)
		await _fade(_black, 0.0)
		_finish()
		return

	await _wait(HOLD_BEFORE_TEXT)
	for line: String in lines:
		_add_line(line)
		await _wait(LINE_INTERVAL)
	_emit_rendered(lines.size())
	await _wait(READ_HOLD if not lines.is_empty() else EMPTY_HOLD)
	await _fade(_black, 0.0)
	_finish()


## Adds one centered proclamation label that fades itself in.
func _add_line(text: String) -> void:
	var label := UIChrome.make_label(text, "Header")
	label.add_theme_font_size_override("font_size", LINE_FONT_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.modulate.a = 0.0
	_line_box.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, LINE_FADE)


func _finish() -> void:
	_running = false
	_black.hide()
	_black.modulate.a = 0.0
	for child: Node in _line_box.get_children():
		child.queue_free()


func _emit_rendered(count: int) -> void:
	ObservableBus.emit_domain_event(WIEvents.UI_SLEEP_VEIL_RENDERED, {"lines": count})


func _fade(rect: ColorRect, to_alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(rect, "modulate:a", to_alpha, FADE_SECONDS)
	await tween.finished


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Same TestDriver.active()/headless collapse gate combat_screen.gd and
## world.gd use for their presentation delays (the M4 T10 precedent).
func _is_qa() -> bool:
	return (TestDriver != null and TestDriver.active()) or DisplayServer.get_name() == "headless"


## Reads display names straight from the data files (content=data; the sim's
## snapshot() carries no name map). classes.json ships raw names ("Warrior") and
## skills.json bracketed ones ("[Basic Cleaning]") — the GDI class lines re-add
## their own brackets and the skill line strips the display brackets so
## "[Skill – Basic Cleaning Obtained!]" reads cleanly.
func _load_display_names() -> void:
	var classes: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/classes.json"))
	if classes is Dictionary:
		for cls: Variant in (classes as Dictionary).get("classes", []):
			if cls is Dictionary and (cls as Dictionary).has("id"):
				var cid := String(cls["id"])
				_class_names[cid] = String((cls as Dictionary).get("display_name", cid))
				for lv: Variant in (cls as Dictionary).get("levels", []):
					if lv is Dictionary and int((lv as Dictionary).get("level", 0)) == 1:
						_class_level1_grants[cid] = ((lv as Dictionary).get("grants", []) as Array).duplicate()
	var skills: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills.json"))
	if skills is Dictionary:
		for sk: Variant in (skills as Dictionary).get("skills", []):
			if sk is Dictionary and (sk as Dictionary).has("id"):
				_skill_names[String(sk["id"])] = String((sk as Dictionary).get("display_name", sk["id"]))


func _class_name(id: String) -> String:
	if id == "":
		return id
	return String(_class_names.get(id, id))


func _skill_name(id: String) -> String:
	if id == "":
		return id
	var display := String(_skill_names.get(id, id))
	return display.trim_prefix("[").trim_suffix("]")
