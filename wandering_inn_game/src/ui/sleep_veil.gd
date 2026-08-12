extends CanvasLayer
## PRESENTATION-ONLY, ZERO SIM CHANGE. The veil is a pure RENDERER over the
## world: it CONSUMES nothing (no set_input_as_handled), CHANGES no existing
## event, and never touches Game.sim state. The very same phase_changed /
## class_* / skill_unlocked / toast stream still fires beneath it — the toasts
## the veil re-voices are the identical toasts message_layer renders (they play
## out under the black), so every prior QA assertion holds untouched by
## construction. The one additive signal is UI_SLEEP_VEIL_RENDERED, a UI
## confirmation in the message_layer ui_*_rendered idiom (a brand-new type, so
## it interleaves with — never rewrites — any existing stream).
## TRIGGER: sleep() (wi_game.gd) emits phase_changed UNCONDITIONALLY as its
## first event, resetting the clock so phase() == "day" (actions_since_sleep is
## 0), and TAGS that emit `{"slept": true}`. That flag is the trigger, and the
## whole trigger. `_tick_action` never sets it, and no load/boot path re-emits
## phase_changed at all, so it is a precise, sim-change-free sleep signal.
## TRAP: never re-derive "slept" from the phase VALUE. This keyed on
## phase == "day" while the clock was monotone per waking; #359's wrap emits day
## from `_tick_action` at action 2*night_at (1800 shipped), which fired a full
## blackout mid-field and spent the one-shot finale off the bed.
## The announcements arrive as class_gained/class_level_up/skill_unlocked/
## class_evolved events fired SYNCHRONOUSLY right after that phase_changed in
## the same sleep() call; the veil buffers them, then a single call_deferred
## runs the reveal once the whole synchronous beat has unwound (so the buffer is
## complete). Assumes a phase config where the fresh-clock phase is "day"
## (dusk_at > 0), which is invariant for every shipped/data moods.json config.

const VEIL_LAYER := 30

const FADE_SECONDS := 0.6
const HOLD_BEFORE_TEXT := 0.35
const LINE_INTERVAL := 0.55
const LINE_FADE := 0.4
const READ_HOLD := 1.5
const EMPTY_HOLD := 0.4
const LINE_FONT_SIZE := 24

## v0.15 A4, VISUAL-LOG FINALE/LONG-LINE (P3) + VEIL-COPY/UNMEASURED (P4).
## Veil lines used to be bare SHRINK_CENTER Labels with no autowrap, so a line
## drew at its natural width whatever the viewport was: the Invrisil region
## recap measured 1114px of a 1280px viewport (87%) and burst the centred
## column every other line forms. These three are the wrap-aware budget, and
## `test_copy_fit._check_veil_lines` mirrors all three with the drift-tripwire
## idiom so the ceiling is ENFORCED, never merely observed.
##
##  * VEIL_LINE_TEXT_WIDTH is THE COLUMN. Measured: the widest authored
##    one-thought line in the tables below is 867px ("[You re-cut the ward with
##    your own hands...]"), so 880 keeps every shipped one-thought line on ONE
##    row and wraps only genuinely two-sentence copy. AUTHORED COPY IS NEVER
##    REWRITTEN TO FIT -- that is the whole point of a wrap-aware budget.
##  * VEIL_BLOCK_MAX_HEIGHT is the 720px viewport less a 24px band top and
##    bottom. `_line_box` is FULL_RECT with ALIGNMENT_CENTER, so a block taller
##    than the viewport loses its FIRST and LAST lines off both edges at once.
##  * VEIL_LINE_SEPARATIONS is the ladder `_apply_line_budget` walks: the first
##    separation whose measured block fits the budget wins, so a long finale
##    (three act presences + three region lines + a class per held class)
##    tightens instead of overflowing. Only when even the tightest rung
##    overflows does the oldest line evict -- the combat feed's idiom, and the
##    honest degradation for a paced sequence the player reads line by line.
const VEIL_LINE_TEXT_WIDTH := 880.0
const VEIL_BLOCK_MAX_HEIGHT := 672.0
const VEIL_LINE_SEPARATIONS := [18, 14, 10, 6]

## The GDI new-game opener. A New Game opens on BLACK: the Grand Design's
## voice speaks a few arrival lines in this SAME gold-on-black device
## (reusing _black + _add_line + the layer-30 discipline above — one
## renderer, not a second), then fades into the inn. WIMain calls
## play_opener() ONLY on the GAME_RESET (fresh-world) path — never on
## Continue/load (see main.gd swap_to_world(new_game)). Under QA/headless
## it collapses to instant and emits UI_GDI_OPENER_RENDERED{lines} for
## coverage (title_flow asserts it); in real play it is SKIPPABLE —
## confirm/cancel advances line-by-line and, past the last line, fades to
## the inn, so a replaying player is never held hostage. This is the ONE
## interactive exception to the veil's "consumes nothing" invariant: the
## opener swallows ONLY confirm/cancel while it holds; the sleep path
## above still intercepts no input at all.
const OPENER_LINES: Array[String] = [
	"[Class: none.]",
	"[Skills: none.]",
	"This world watches what you do.",
	"[Begin.]",
]
const OPENER_HOLD_BEFORE_TEXT := 0.6
const OPENER_LINE_HOLD := 1.7
const OPENER_READ_HOLD := 2.2

## THE FINALE — the demo's one true ending, and the retirement of the old
## post-seal epilogue (2026-07-26 main-quest wave, Phase 8). Sealing the
## warren used to end the game; under the reframe it is a mid-story act
## transition, and the curtain moved to `seal_resolved` — the settling of
## "What the Seal Was Feeding", by whichever of its three paths. Same
## gold-on-black device, same _black/_add_line renderer; only the trigger and
## the copy changed. The open lines survive the move verbatim: they were
## always about the record, not about the warren.
const FINALE_LINES_OPEN: Array[String] = [
	"[When you came to Liscor, there was nothing to record.]",
	"[This is no longer true.]",
]
## v0.15 A5. ACT PRESENCES, one line per act, each emitted ONLY if that act's
## own counter banked — the same per-counter shape as the region recap below,
## and deliberately NOT a last-match-wins ladder: a finale player holds all
## three, and the point is that the recap walks the whole story, not just its
## end. Before this, Acts I–III had no presence in the ending at all: the recap
## opened on "there was nothing to record", jumped straight to the pilgrimage,
## and the arrival, the city learning your face, and the warren under it went
## unmentioned. Placed between the class recount and the region recap so the
## sequence reads chronologically — who you became, what the city did about it,
## then where the Door took you. SHORT by contract (spec A5: "seasoning, not a
## second epilogue"): all three measure under the 880px column at 773/667/706px,
## so each draws on ONE row and the three presences cost the block three rows,
## not six. The first drafts ran 879/915/894px -- two of them wrapped, and the
## worst-case block needed the separation ladder's third rung to fit. Measured,
## not eyeballed; `test_copy_fit._check_veil_lines` holds the ceiling.
##
## `post_game` carries Act II rather than a "known face" counter of its own:
## that beat's own gate is `reached_two_classes` + `quests_completed >= 3`, a
## compound with no single id, and `post_game` banks at the first sleep after
## the seal — by which point the city HAS decided, which is the thing the line
## says.
const FINALE_ACT_LINES: Array[Array] = [
	["reached_liscor", "[You arrived with no class and no name here. Liscor has both now.]"],
	["post_game", "[The city learned your face, and never once mentioned it.]"],
	["raskghar_sealed", "[The warren under Liscor is sealed, and what it fed is cut off.]"],
]
## Region recap, one line per pilgrimage stop, each emitted ONLY if that
## stop's counter banked. Ordered Riverfarm → Invrisil → Pallass, the spine's
## own order, so the recap reads back as the road the player walked.
const FINALE_REGION_LINES: Array[Array] = [
	["lattice_witch_lore", "[Riverfarm keeps a witch who taught you what a ward eats.]"],
	["lattice_hedault_reading", "[Invrisil keeps an enchanter who called your Door 'competent work'. From him, that is a parade.]"],
	["lattice_forge_rune", "[Pallass stamped your name into a forge tier's ledger.]"],
]
## ONE path close, LAST MATCH WINS — so this table's ORDER IS THE PRECEDENCE
## RULE, and `seal_opened` sits first on purpose. Act V's deliberate
## no-dead-end hatch lets a player break the seal, walk back out of the vault
## without touching the anchor, and still resolve through Olesm or the re-ward,
## which leaves them holding `seal_opened` AND a resolution counter; the
## resolution is the true state, so it must overwrite. (#440 narrowed the
## hatch's ENTRY, never the hatch: the warden is now down before `seal_opened`
## can bank at all, so "opened it and lost the fight" is no longer one of the
## ways a player arrives here. Every other route in is unchanged.) `seal_kept_fed` and `seal_rewarded` can never
## co-occur (both their dialogue entries carry hide_when seal_resolved), so
## their relative order is inert — it follows the plan's stated precedence.
const FINALE_CLOSE_LINES: Array[Array] = [
	["seal_opened", "[You opened what was fed. The record does not flinch.]"],
	["seal_kept_fed", "[You chose to keep feeding it. Some seals are promises.]"],
	["seal_rewarded", "[You re-cut the ward with your own hands. It will hold longer than the city.]"],
]
const FINALE_LINK_LINE := "— The story continues at wanderinginn.com —"
const FINALE_HOLD_BEFORE_TEXT := 0.8
const FINALE_LINE_HOLD := 1.6
const FINALE_READ_HOLD := 2.6

## WHICH conversations may draw the curtain. An owed finale must not roll off
## the peddler saying "watch gear, mostly honest" — on the FIGHT path, whose
## resolution is a container open rather than a conversation, ANY dialogue end
## would otherwise credit-roll the next shopkeeper the player greets.
##
## `olesm_intro` and `pisces_seal` are the two graphs that actually BANK
## `seal_resolved` (TALK's standing posting, SKILL's re-cut), so on those paths
## the curtain still falls the instant the resolving conversation closes —
## unchanged behaviour, exactly where the epilogue used to roll. `pisces_seal`
## doubles as the FIGHT path's curtain: the escort at the door carries a
## post-`seal_opened` variant, so a player who walks out of the vault and tells
## Pisces gets the ending there. `pisces_magic` is the same voice on the inn
## side, and the arc's only other Pisces surface — he is the story voice of
## this whole quest, and no other graph in the game speaks for it.
##
## Nothing else qualifies, and nothing needs to: the bed hook below is the
## unconditional catch-all, so a filtered-out conversation delays the ending to
## the player's next sleep, never loses it.
const FINALE_CURTAIN_CONVERSATIONS: Array[String] = [
	"olesm_intro",
	"pisces_seal",
	"pisces_magic",
]

## The seal's own light transition, re-homed from the retired epilogue's close
## pair (spec §2.2: "a light act-transition sleep beat (one GDI line)"). It
## rides `post_game`, which sleep_beat.gd banks silently at the first sleep
## AFTER `raskghar_sealed` — so the Design marks the seal on the bed, where it
## marks every other slow change, instead of rolling credits at Zevara's desk.
## Zero new copy: both retired sentences, and the second is precisely what
## makes the beat read as mid-story rather than as an ending.
const SEAL_TRANSITION_LINE := "[The warren is sealed. The record remains open.]"

## v0.16.1 finding 25. The Watch-runner pointer banks INSIDE WIGame.sleep(), one
## frame after PHASE_CHANGED -- and that same PHASE_CHANGED starts this veil.
## The veil draws at layer 30, toasts at layer 12, so the pointer toast was
## spoken UNDER the black and its hold expired around the time the black lifted;
## a first step then killed whatever was left. The surface the player is
## unavoidably watching at that instant is this one, so the beat gets a line
## here. The toast stays the nudge and quests.json stays the durable copy
## (GH#167); this is the guaranteed read.
const WATCH_RUNNER_VEIL_LINE := "[A Watch runner was asking for you by name.]"

const _EVOLUTION_RESULT_FLAVOR := {
	"swordsman": "Your hands have chosen the sword.",
	"spearmaster": "Your hands have chosen the spear.",
	"ice_mage": "Your focus has settled on frost.",
	"fire_mage": "Your focus has settled on flame.",
	"barmaid": "You've settled into serving the room.",
	"server": "You've settled into running the city.",
}

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

var _running := false
var _reveal_queued := false
var _lines: Array[String] = []
var _sleep_has_consolidation := false

var _opener_running := false
var _opener_advance := false

var _finale_running := false
## DIALOGUE_ENDED carries an EMPTY payload (dialogue.gd emits `{}` from both
## its end paths), so the conversation id has to be remembered from the
## DIALOGUE_STARTED that opened it — that one does carry `conversation`.
var _open_conversation := ""

var _defeat_running := false
var _defeat_choice_pending := false
var _defeat_choice_result := true


func _ready() -> void:
	layer = VEIL_LAYER
	_load_display_names()

	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Never intercepts KEYBOARD input (zero behaviour change there -- a player
	# mashing keys under the brief black still drives the world exactly as
	# before; `world.gd`'s `_movement_gated()` gates that via
	# `veil_modal_active()`, not this Control). STOP for MOUSE (mouse-filter
	# audit, issue #57): the veil is a full-screen cover -- a click during it
	# must not leak through to a world click-to-walk/interact underneath the
	# black. `.show()`/`.hide()` below already gate this Control's own
	# visibility, so this is harmless while the veil is inactive. CanvasLayer
	# has no modulate, so fade the ColorRect's own alpha.
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	_black.modulate.a = 0.0
	_black.hide()
	add_child(_black)

	_line_box = VBoxContainer.new()
	UIChrome.apply_theme(_line_box)
	_line_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_line_box.add_theme_constant_override("separation", int(VEIL_LINE_SEPARATIONS[0]))
	_line_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_line_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_line_box)

	ObservableBus.domain_event.connect(_on_domain_event)


func _on_domain_event(type: String, payload: Dictionary) -> void:
	match type:
		WIEvents.PHASE_CHANGED:
			# `slept`, NOT the phase value — see this file's TRIGGER block. A
			# cycle wrap emits phase "day" from `_tick_action` with no sleep
			# behind it and must not raise the veil.
			if bool(payload.get("slept", false)):
				_begin_sleep()
		WIEvents.CLASS_GAINED:
			if _running:
				var gained_id := String(payload.get("class", ""))
				_lines.append("[%s Class Obtained!]" % _class_name(gained_id))
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
				var to_id := String(payload.get("to", ""))
				_lines.append("[%s Class → %s Class!]" % [_class_name(String(payload.get("from", ""))), _class_name(to_id)])
				var flavor := String(_EVOLUTION_RESULT_FLAVOR.get(to_id, ""))
				if flavor != "":
					_lines.append(flavor)
		WIEvents.CONSOLIDATION_OFFERED:
			# The GDI ANNOUNCES the offer under the veil (user ruling: the
			# consolidation choice is delivered by the Grand Design during
			# sleep) -- one line in its own voice, riding the same collection
			# idiom as every other reveal. The CHOICE itself still happens in
			# consolidation_prompt.gd's modal AFTER the veil completes: the
			# input-dead-until-UI_SLEEP_VEIL_FINISHED contract (the
			# prompt-held rework) is untouched. Issue #87: also arms
			# `_sleep_has_consolidation`, forcing this sleep's whole reveal
			# unskippable (see the PLAIN-SLEEP SKIP guard doc comment).
			if _running:
				_sleep_has_consolidation = true
				var parents: Array = payload.get("parents", [])
				if parents.size() == 2:
					_lines.append("[%s and %s pull toward one another. The Design offers: %s.]" % [
						_class_name(String(parents[0])), _class_name(String(parents[1])),
						_class_name(String(payload.get("target", "")))])
		WIEvents.ACCOMPLISHMENT_RECORDED:
			if _running and String(payload.get("id", "")) == "post_game":
				_lines.append(SEAL_TRANSITION_LINE)
			if _running and String(payload.get("id", "")) == "door_awakened":
				_lines.append("[The inn has a Door. The Door has opinions.]")
			if _running and String(payload.get("id", "")) == "garden_door_unlocked":
				_lines.append("[A door opens that no one built. The Garden of Sanctuary remembers how to wait.]")
			if _running and String(payload.get("id", "")) == "watch_runner_pointed":
				_lines.append(WATCH_RUNNER_VEIL_LINE)
			if _running and String(payload.get("id", "")) == "resonance_grown":
				_lines.append("[The anchor stone gives up a sliver of itself. You have room for it now.]")
		WIEvents.DIALOGUE_STARTED:
			_open_conversation = String(payload.get("conversation", ""))
		WIEvents.DIALOGUE_ENDED:
			# The resolving conversation's own curtain, and ONLY a conversation
			# that can carry one (see FINALE_CURTAIN_CONVERSATIONS). TALK
			# (Olesm's posting) and SKILL (Pisces' re-cut) both bank
			# `seal_resolved` mid-dialogue, so the finale rolls the instant that
			# conversation closes — exactly where the epilogue used to roll.
			# No arming flag: play_finale() re-derives whether it is owed.
			var ended := _open_conversation
			_open_conversation = ""
			if FINALE_CURTAIN_CONVERSATIONS.has(ended):
				play_finale()
		WIEvents.CONSOLIDATION_ACCEPTED, WIEvents.CONSOLIDATION_DECLINED:
			# THE BED HOOK'S RETRY. `_play_finale_off_the_bed()` stands down
			# when a merge offer is queued behind the veil, so without this an
			# owed finale would wait for a whole extra night. These two fire
			# from wi_game AFTER the merge is applied (consolidation_prompt's
			# `_choose` emits UI_CONSOLIDATION_PROMPT_HIDDEN *before* calling
			# into the sim, which is the wrong edge for a sequence that
			# recounts classes — the recount must show the class the player
			# just chose, not the two it replaced).
			#
			# DEFERRED, and that is load-bearing for the same reason. Neither
			# emit is the END of its sim call: `decline_consolidation()` fires
			# CONSOLIDATION_DECLINED and only THEN runs `_resolve_evolutions()`
			# (wi_game.gd — the decline path owns the evolutions the offer
			# deferred out of the sleep beat). Calling straight through would
			# recount classes mid-flight, and worse, differently in QA than in
			# play: the QA collapse builds the line list synchronously inside
			# `play_finale()` and would name the PRE-evolution class, while
			# real play's own `_run_finale.call_deferred()` names the evolved
			# one. Deferring here puts both on the far side of the whole
			# synchronous chain, so the recount reads one settled snapshot.
			# The emit sites stay untouched (consolidation_flow's pins hold).
			play_finale.call_deferred()


func _begin_sleep() -> void:
	if _running or _opener_running or _finale_running:
		return
	_running = true
	_lines = []
	_sleep_has_consolidation = false
	if not _reveal_queued:
		_reveal_queued = true
		_run_sequence.call_deferred()


func play_opener() -> void:
	if _running or _opener_running or _finale_running:
		return
	if _is_qa():
		_emit_opener_rendered(_opener_lines().size())
		return
	_opener_running = true
	_run_opener.call_deferred()


func _opener_lines() -> Array:
	return OPENER_LINES


func _run_opener() -> void:
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


func _wait_or_advance(seconds: float) -> void:
	_opener_advance = false
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline and not _opener_advance:
		await get_tree().process_frame


func modal_active() -> bool:
	return _running or _opener_running or _finale_running or _defeat_running


func _unhandled_input(event: InputEvent) -> void:
	if _defeat_choice_pending:
		if event.is_action_pressed("confirm"):
			_defeat_choice_result = true
			_defeat_choice_pending = false
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("cancel"):
			_defeat_choice_result = false
			_defeat_choice_pending = false
			get_viewport().set_input_as_handled()
		return
	if not (_running or _opener_running or _finale_running or _defeat_running):
		return
	if event.is_action_pressed("confirm") or event.is_action_pressed("cancel"):
		_opener_advance = true
		get_viewport().set_input_as_handled()


func _emit_opener_rendered(count: int) -> void:
	# `race` predates the de-race-ification (the opener no longer branches
	# on it) but stays in the payload harmlessly per the copy-staging doc's
	# call — char_creation's payload_contains still pins it, no re-pin
	# needed since Game.sim.pc_race itself is unchanged.
	ObservableBus.emit_domain_event(WIEvents.UI_GDI_OPENER_RENDERED, {"lines": count, "race": Game.sim.pc_race})


## Plays the finale IF it is owed. Callers never decide that themselves —
## both delivery hooks just call this and let _finale_owed() rule, which is
## why there is no arming flag anywhere in this file any more.
func play_finale() -> void:
	if _running or _opener_running or _finale_running:
		return
	if not _finale_owed():
		return
	if _is_qa():
		_emit_finale_rendered(_finale_lines().size())
		_bank_finale_played()
		return
	_finale_running = true
	_run_finale.call_deferred()


## THE ONE-SHOT GATE, read from SIM STATE rather than a runtime flag. The old
## epilogue armed on one event and fired on the next, and leaned on `post_game`
## to never re-fire; `post_game` now banks MID-STORY at the seal sleep
## (sleep_beat.gd, Task 1.2), so it would suppress the ending outright. Its
## replacement is `finale_played`, a counter of its own — which also means a
## save/quit between the resolution and the curtain can no longer strand the
## game's one true ending, because nothing about the trigger lives in memory.
func _finale_owed() -> bool:
	if Game.sim == null:
		return false
	return Game.sim.accomplishment_count("seal_resolved") > 0 \
		and Game.sim.accomplishment_count("finale_played") == 0


func _finale_lines() -> Array[String]:
	var lines: Array[String] = []
	lines.append_array(FINALE_LINES_OPEN)
	# Recount straight from the sim snapshot: {class_id: level}, in the order the
	# classes were earned (Dictionary insertion order). Names resolve through the
	# same data-loaded map the sleep/opener lines use, so no raw id ever leaks.
	var classes: Dictionary = Game.sim.snapshot().get("classes", {})
	for cid: Variant in classes:
		lines.append("[%s Level %d.]" % [_class_name(String(cid)), int(classes[cid])])
	for row: Array in FINALE_ACT_LINES:
		if Game.sim.accomplishment_count(String(row[0])) > 0:
			lines.append(String(row[1]))
	for row: Array in FINALE_REGION_LINES:
		if Game.sim.accomplishment_count(String(row[0])) > 0:
			lines.append(String(row[1]))
	# LAST match wins (see FINALE_CLOSE_LINES): a resolution counter always
	# overwrites the bare seal_opened line.
	var close := ""
	for row: Array in FINALE_CLOSE_LINES:
		if Game.sim.accomplishment_count(String(row[0])) > 0:
			close = String(row[1])
	if close != "":
		lines.append(close)
	lines.append(FINALE_LINK_LINE)
	return lines


func _run_finale() -> void:
	_black.show()
	await _fade(_black, 1.0)
	await _wait(FINALE_HOLD_BEFORE_TEXT)
	var lines := _finale_lines()
	for i in lines.size():
		_add_line(String(lines[i]))
		var last := i == lines.size() - 1
		await _wait_or_advance(FINALE_READ_HOLD if last else FINALE_LINE_HOLD)
	_emit_finale_rendered(lines.size())
	_bank_finale_played()
	await _fade(_black, 0.0)
	_finale_running = false
	_finish()


func _bank_finale_played() -> void:
	if Game.sim.accomplishment_count("finale_played") == 0:
		Game.sim.record_accomplishment("finale_played")


## Event id unchanged on purpose: `ui_gdi_epilogue_rendered` is a shipped QA
## contract (manifest surfaces + canonical pins). The sequence behind it moved;
## the signal "the GDI's closing sequence rendered N lines" did not.
func _emit_finale_rendered(count: int) -> void:
	ObservableBus.emit_domain_event(WIEvents.UI_GDI_EPILOGUE_RENDERED, {"lines": count})


func play_defeat() -> void:
	if _running or _opener_running or _finale_running or _defeat_running:
		return
	if _is_qa():
		_emit_defeat_rendered(_defeat_lines().size())
		# The collapsed QA path still closes the beat: audio's field-bed resume
		# hangs off this event now (see _emit_defeat_finished), so swallowing it
		# under QA would leave the defeat latch set for the rest of the run.
		_emit_defeat_finished(true)
		return
	_defeat_running = true
	_run_defeat.call_deferred()


## GH#372. Line 3 used to tell every player, at every point in the story, to
## "step more carefully" -- advice that is useless to someone who has not yet
## learned there IS a spear lesson on the road, and patronising to someone who
## has cleared the warren. Two variants replace it at the ONE authored beat
## where losing is close to expected: the floodplains ambush, before the
## tutorial spar and before the first sleep.
##
## SCOPE IS map + counters, deliberately NOT a per-encounter copy table: one
## beat does not earn a data schema, and the moment a second defeat beat wants
## its own line is the moment to data-drive this. `slept` (not `times_slept`)
## is the gate-visible counter, per the GH#130 bed-nudge precedent.
##
## Lines 1 and 2 never vary. Line 2 -- "the fight undone" -- is literally true
## since GH#374's ward grace landed: the reload rewinds to the pre-fight cell
## AND the encounter holds its fire until you walk away from it.
const DEFEAT_VARIANT_MAP := "floodplains"
const DEFEAT_NUDGE_LINES := {
	"pre_spar": "A Drake with a spear guards this road, bored enough to teach. Ask him to show you how to hold one.",
	"pre_sleep": "You have not slept once under this sky. The inn keeps a bed upstairs, and mornings here are kinder than the nights.",
	"default": "Try again, or step more carefully.",
}


## Which closer this defeat earns. Composed at render time off live sim state
## -- the sim is ALREADY the reloaded pre-combat snapshot by the time
## `play_defeat()` runs (main.gd swaps the world first), so these counters read
## the state the player wakes into, which is the state the line describes.
func _defeat_variant() -> String:
	if Game.sim == null or String(Game.sim.current_map) != DEFEAT_VARIANT_MAP:
		return "default"
	if Game.sim.accomplishment_count("sparred_with_relc") == 0:
		return "pre_spar"
	if Game.sim.accomplishment_count("slept") == 0:
		return "pre_sleep"
	return "default"


func _defeat_lines() -> Array[String]:
	return [
		"[Defeat.]",
		"You wake at %s, the fight undone." % _map_display_name(String(Game.sim.current_map)),
		String(DEFEAT_NUDGE_LINES[_defeat_variant()]),
	]


func _map_display_name(map_id: String) -> String:
	var words := map_id.split("_")
	for i in words.size():
		var w: String = words[i]
		if not w.is_empty():
			words[i] = w[0].to_upper() + w.substr(1)
	return " ".join(words)


func _run_defeat() -> void:
	_black.modulate.a = 1.0
	_black.show()
	await _wait(HOLD_BEFORE_TEXT)
	var lines := _defeat_lines()
	for i in lines.size():
		_add_line(String(lines[i]))
		var last := i == lines.size() - 1
		await _wait_or_advance(READ_HOLD if last else LINE_INTERVAL)
	_emit_defeat_rendered(lines.size())
	_add_choice_rows()
	var continue_chosen := await _wait_for_defeat_choice()
	await _fade(_black, 0.0)
	_defeat_running = false
	_finish()
	_emit_defeat_finished(continue_chosen)
	if not continue_chosen:
		var main := get_parent()
		if main != null and main.has_method("swap_to_title"):
			main.call_deferred("swap_to_title")


func _add_choice_rows() -> void:
	var continue_row := UIChrome.make_label("Continue — %s" % WIInputHints.label("confirm"), "Menu")
	continue_row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_row.mouse_filter = Control.MOUSE_FILTER_STOP
	continue_row.gui_input.connect(_on_choice_row_input.bind(true))
	_line_box.add_child(continue_row)
	var title_row := UIChrome.make_label("Title Screen — %s" % WIInputHints.label("cancel"), "Menu")
	title_row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_row.mouse_filter = Control.MOUSE_FILTER_STOP
	title_row.gui_input.connect(_on_choice_row_input.bind(false))
	_line_box.add_child(title_row)


func _on_choice_row_input(event: InputEvent, continue_chosen: bool) -> void:
	if not _defeat_choice_pending:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	_defeat_choice_result = continue_chosen
	_defeat_choice_pending = false


func _wait_for_defeat_choice() -> bool:
	_defeat_choice_pending = true
	while _defeat_choice_pending:
		await get_tree().process_frame
	return _defeat_choice_result


## GH#372, the QA-first half: `variant` joins the payload so authored copy that
## only ever appears under a gate is still structurally pinnable. Additive key
## -- every shipped `payload_contains` subset match survives by construction --
## and it is derived, never stored, so it can never disagree with the line the
## player just read (both call sites compose from `_defeat_variant()`).
func _emit_defeat_rendered(count: int) -> void:
	ObservableBus.emit_domain_event(WIEvents.UI_DEFEAT_VEIL_RENDERED, {
		"lines": count, "map": String(Game.sim.current_map), "variant": _defeat_variant(),
	})


## v0.16.1 finding 24: the defeat presentation now OWNS the moment the world's
## music comes back, instead of the reload racing the veil. The reload fires
## GAME_LOADED{reason:"defeat"} -> WORLD_READY, which used to crossfade the
## restored map's cheery bed straight back in BEFORE the black even started --
## and `_wait_for_defeat_choice` then holds that black indefinitely, so the
## bazaar looped under "[Defeat.]". wi_audio latches on that reason, skips the
## WORLD_READY sync, and resumes here. `continue` is false when the player picked
## Title: the latch still clears (it must never strand), but there is no field
## bed worth a half-second of playback before the title theme takes over.
func _emit_defeat_finished(continue_chosen: bool) -> void:
	ObservableBus.emit_domain_event(WIEvents.UI_DEFEAT_VEIL_FINISHED, {"continue": continue_chosen})


## Playtest hotfix #8: NO special case for a consolidation-offering sleep any
## more -- it runs this exact same sequence as every other sleep, then emits
## UI_SLEEP_VEIL_FINISHED as its very last act. consolidation_prompt.gd holds
## a pending offer HIDDEN (input dead) until that event, so the offer
## surfaces with/after this sleep's own announcement lines, never on top of
## the black and never answerable blind. TRAP: the finished emit must fire in
## the QA-collapsed branch too, and must always come AFTER _finish() -- the
## whole ordering contract (rendered -> finished -> prompt) is pinned by
## consolidation_flow's forward-only event waits.
func _run_sequence() -> void:
	_reveal_queued = false
	var lines := _lines.duplicate()

	if _is_qa():
		# Collapsed: no visible hold — record coverage and clear the same beat so
		# no QA screenshot ever catches a black frame. The finished emit still
		# fires (after _finish, mirroring the real path below) so the
		# rendered -> finished -> prompt order is provable headless.
		_emit_rendered(lines.size())
		_finish()
		_emit_finished()
		_play_finale_off_the_bed()
		return

	_black.show()
	await _fade(_black, 1.0)

	await _wait(HOLD_BEFORE_TEXT)
	var skippable := not _sleep_has_consolidation
	for line: String in lines:
		_add_line(line)
		if skippable:
			await _wait_or_advance(LINE_INTERVAL)
		else:
			await _wait(LINE_INTERVAL)
	_emit_rendered(lines.size())
	var final_hold := READ_HOLD if not lines.is_empty() else EMPTY_HOLD
	if skippable:
		await _wait_or_advance(final_hold)
	else:
		await _wait(final_hold)
	await _fade(_black, 0.0)
	_finish()
	_emit_finished()
	_play_finale_off_the_bed()


## THE FINALE'S SECOND DELIVERY HOOK, and the one that cannot be routed
## around. Act V's FIGHT path banks `seal_resolved` at the vault anchor -- a
## CONTAINER open, with no conversation behind it -- so DIALOGUE_ENDED alone
## would leave the ending waiting on an optional chat with Pisces, and a
## save/quit before that chat would strand it. The bed is where the Design
## already speaks; an owed finale rolls off the sleep it follows. Called AFTER
## _finish()/_emit_finished() so the sleep reveal's own contract
## (rendered -> finished -> consolidation prompt) is untouched, and so
## play_finale()'s `_running` guard has already cleared.
##
## YIELDS TO THE CONSOLIDATION PROMPT. UI_SLEEP_VEIL_FINISHED is what tells
## consolidation_prompt.gd to show its modal, so a sleep that offered a merge
## would have the finale's black fall straight over that choice. The finale
## stays OWED instead -- it is sim state, not a flag, so the next dialogue end
## or the next sleep still delivers it, with nothing lost.
func _play_finale_off_the_bed() -> void:
	if _sleep_has_consolidation:
		return
	play_finale()


func _add_line(text: String) -> void:
	var label := UIChrome.make_label(text, "Header")
	label.add_theme_font_size_override("font_size", LINE_FONT_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# The wrap half of the budget (see VEIL_LINE_TEXT_WIDTH): a fixed-width
	# autowrapping label centred in the viewport, so a two-sentence line folds
	# into the column instead of drawing 1114px wide out of it. Short lines are
	# unchanged on screen -- the label is wider than its text, and the text is
	# centre-aligned inside it.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = VEIL_LINE_TEXT_WIDTH
	label.modulate.a = 0.0
	_line_box.add_child(label)
	_apply_line_budget()
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, LINE_FADE)


## The height half of the budget. Walks VEIL_LINE_SEPARATIONS for the first
## rung whose measured block fits VEIL_BLOCK_MAX_HEIGHT and applies it; if even
## the tightest rung overflows, the OLDEST line evicts (never the newest -- the
## line just added is the one the player is being shown right now).
func _apply_line_budget() -> void:
	if _line_box == null or _line_box.get_child_count() == 0:
		return
	for raw_separation: Variant in VEIL_LINE_SEPARATIONS:
		var separation := int(raw_separation)
		if _line_block_height(separation) <= VEIL_BLOCK_MAX_HEIGHT:
			_line_box.add_theme_constant_override("separation", separation)
			return
	var tightest := int(VEIL_LINE_SEPARATIONS[VEIL_LINE_SEPARATIONS.size() - 1])
	_line_box.add_theme_constant_override("separation", tightest)
	while _line_box.get_child_count() > 1 and _line_block_height(tightest) > VEIL_BLOCK_MAX_HEIGHT:
		var oldest := _line_box.get_child(0)
		_line_box.remove_child(oldest)
		oldest.queue_free()


## Measured, not estimated: each row is the FONT's own height at
## LINE_FONT_SIZE, and a wrapped line contributes every row it wraps to.
##
## TWO KNOWN IMPRECISIONS, both inert today, both recorded so a future edit that
## makes them matter is recognisable rather than mysterious:
##  * ALIGNMENT ARG MIRROR. This passes HORIZONTAL_ALIGNMENT_CENTER (what the
##    labels actually draw with) while `test_copy_fit._check_veil_lines` mirrors
##    the same measurement with HORIZONTAL_ALIGNMENT_LEFT. Alignment does not
##    change where TextServer breaks a line, so the two agree on the row COUNT --
##    which is the only thing either uses the result for. If a future budget ever
##    reads the measured WIDTH, make the two calls identical first.
##  * `row_height` CARRIES the last measured label's value out of the loop. Every
##    veil label is the same Header variation at the same LINE_FONT_SIZE, so every
##    iteration writes the same number and the sum is exact. A veil line drawn at
##    a different size would silently multiply the whole row count by the LAST
##    label's height; if that day comes, accumulate per-label height instead.
func _line_block_height(separation: int) -> float:
	var rows := 0
	var row_height := 0.0
	for child: Node in _line_box.get_children():
		var label := child as Label
		if label == null:
			continue
		var font := label.get_theme_font("font")
		if font == null:
			continue
		row_height = font.get_height(LINE_FONT_SIZE)
		var measured := font.get_multiline_string_size(
			label.text, HORIZONTAL_ALIGNMENT_CENTER, VEIL_LINE_TEXT_WIDTH, LINE_FONT_SIZE)
		rows += max(int(round(measured.y / row_height)), 1) if row_height > 0.0 else 1
	if rows == 0:
		return 0.0
	return float(rows) * row_height + float(maxi(_line_box.get_child_count() - 1, 0)) * float(separation)


func _finish() -> void:
	_running = false
	_black.hide()
	_black.modulate.a = 0.0
	for child: Node in _line_box.get_children():
		child.queue_free()


func _emit_rendered(count: int) -> void:
	ObservableBus.emit_domain_event(WIEvents.UI_SLEEP_VEIL_RENDERED, {"lines": count})


func _emit_finished() -> void:
	ObservableBus.emit_domain_event(WIEvents.UI_SLEEP_VEIL_FINISHED, {})


## True while a SLEEP reveal is running or queued (from the sleep
## phase_changed until _run_sequence's finished emit) -- queried by
## consolidation_prompt.gd the instant an offer arrives, to decide
## wait-for-finished vs show-now. Sleep-mode only on purpose: the offer can
## only ever fire inside wi_game.gd's sleep() (whose UNCONDITIONAL
## phase_changed has already run _begin_sleep by the time the offer event
## lands, bus delivery being synchronous and in-order), so opener/epilogue
## states are irrelevant here -- if THEY blocked _begin_sleep (the rare race
## _begin_sleep's own guard covers), this correctly reads false and the
## prompt shows immediately rather than waiting for a finished emit that
## would never come.
func sleep_sequence_active() -> bool:
	return _running or _reveal_queued


func _fade(rect: ColorRect, to_alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(rect, "modulate:a", to_alpha, FADE_SECONDS)
	await tween.finished


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _is_qa() -> bool:
	return (TestDriver != null and TestDriver.active()) or DisplayServer.get_name() == "headless"


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
