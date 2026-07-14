extends CanvasLayer
## The GDI (Grand Design of Isthekenous) sleep sequence.
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
## QA/HEADLESS COLLAPSE: under TestDriver.active() or the headless server the
## entire fade/hold/reveal collapses to ~0 and the veil clears the same beat
## — windowed QA is never slowed and no screenshot catches a stuck black
## frame. FEEL is therefore human-playtest-gated (like AI pacing);
## UI_SLEEP_VEIL_RENDERED{lines} is the automated coverage proof that it
## fired.
##
## CONSOLIDATION (playtest hotfix #8): a consolidation OFFER can fire at sleep
## (wi_game.gd defers the rest of the beat and emits consolidation_offered).
## Its modal prompt (consolidation_prompt.gd, layer 1) is input-blocking and
## lives BENEATH this veil (layer 30) -- but shows itself IMMEDIATELY and
## unconditionally on consolidation_offered (`_show_offer`/`_root.show()`),
## independent of the veil's own timing; it never needs the veil to defer to
## it. RULING: progression resolves in sleep, so the offer is fiction-bound to
## the SAME sleep beat as every other announcement -- the veil now runs its
## ordinary full reveal (hold, then this sleep's class/level toast lines, same
## as any other sleep) for a consolidation-offering sleep too, no special-case
## skip. The modal sits ready beneath the whole time; it only becomes VISIBLE
## once the veil fades back to transparent at the end of the sequence, so the
## offer surfaces with/after the level-up toasts, never before the player has
## seen "you slept."
##
## PLAIN-SLEEP SKIP (issue #87, gap-2): unlike the opener/epilogue/defeat,
## `_run_sequence`'s ordinary reveal used to intercept NO input at all (see
## the file doc comment's old "the sleep path above still intercepts no input
## at all" claim, now corrected) -- the most-repeated beat in the whole game
## was the one hold-out a player could never speed through. It now routes its
## per-line + final hold through the SAME `_wait_or_advance` seam the
## opener/epilogue already use, gated by `_running` in `_unhandled_input`
## (consuming confirm/cancel exactly like every other veil mode). GUARD: a
## sleep that offered a consolidation (`_sleep_has_consolidation`, set by the
## CONSOLIDATION_OFFERED handler below, reset every `_begin_sleep`) stays
## FULLY UNSKIPPABLE -- `_wait()`, never `_wait_or_advance()`, for its whole
## reveal -- so a player's habitual confirm-mash through routine level-up
## sleeps can never also fast-forward past the one line that actually informs
## a permanent choice (the modal itself only unlocks input on
## UI_SLEEP_VEIL_FINISHED, but a player who never READ "The Design offers: X"
## because they spammed through it would still be choosing blind the instant
## it appears). No deadlock risk either way: every branch below still reaches
## `_finish()`/`_emit_finished()` on its own, so the modal's own input
## handling is unaffected by how long the veil holds first.

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
##
## COPY — final, user-approved (docs/archive/staging/gdi-copy-staging.md), no open
## taste flag remains. A cold system-readout opener, ONE version for every
## race (the former Human/Drake/Gnoll branch read as an unearned canon
## distinction — dropped per user ruling; race-neutral by construction). 4
## lines, ending on the same bracketed proclamation cadence as the rest of
## the veil. Opaque-safe: no numbers, no lore claim beyond what the game
## itself shows (the epilogue's class recount pays off the "none/none" open).
const OPENER_LINES: Array[String] = [
	"[Class: none.]",
	"[Skills: none.]",
	"This world watches what you do.",
	"[Begin.]",
]
const OPENER_HOLD_BEFORE_TEXT := 0.6
const OPENER_LINE_HOLD := 1.7
const OPENER_READ_HOLD := 2.2

## The GDI epilogue (the veil's THIRD mode). The cinematic beat after the
## Raskghar is SEALED: ARMED by accomplishment_recorded{raskghar_sealed}
## (banked mid Zevara's seal dialogue) and PLAYED on the following
## dialogue_ended, so her line lands and the conversation clears BEFORE the
## black. Renders the GDI open lines, a GENERATED results-only recount
## (each EARNED class + its level from the sim snapshot — the visible-tier
## rule: a class NAME + its level, never a stat), the "warren is
## sealed"/"record remains open" close, and the wanderinginn.com line, then
## fades back to the SAME world beneath (FREE PLAY — nothing resets, the
## sleep machinery re-arms encounters as before). At completion it banks
## `post_game` — the ONE sim write the epilogue mode makes ("the ending was
## witnessed" is genuine game state, not presentation): the journal's Act
## III completed beat reads it and it GUARDS the epilogue from ever
## re-firing. QA/headless collapses to an instant UI_GDI_EPILOGUE_RENDERED
## {lines} (arc_flow asserts the count) and banks post_game the same beat.
## Skippable in real play via the SAME confirm/cancel advance the opener
## uses (_unhandled_input below now covers both modes).
##
## TRIGGER CHOICE: dialogue-end, NOT the next sleep. It is the more
## cinematic beat (Zevara's seal line → fade to black, no walk-home gap)
## AND it structurally SIDESTEPS the epilogue×consolidation collision: a
## consolidation OFFER only ever fires at a SLEEP, never at a
## dialogue-end, so the epilogue reveal and the consolidation modal can
## NEVER contend for the same frame. The first free-play sleep after the
## epilogue still routes through the ordinary sleep path above, which
## already defers to a consolidation modal — so the two mechanisms stay
## fully independent by construction (no shared trigger moment to
## arbitrate).
##
## COPY — final, user-approved (docs/archive/staging/gdi-copy-staging.md), no open
## taste flag remains. Ledger-voiced understatement replacing the old
## framing's announced sentiment ("Now Liscor knows your name", "The world
## keeps counting" read as aphorism/cheese) — the System states facts and
## lets the class recount between OPEN and CLOSE carry the weight.
## Opaque-safe: class names + levels only, no stats; the bracketed GDI
## cadence matches the sleep/opener proclamations. The class-recount
## mechanism itself is UNCHANGED.
const EPILOGUE_LINES_OPEN: Array[String] = [
	"[When you came to Liscor, there was nothing to record.]",
	"[This is no longer true.]",
]
const EPILOGUE_LINES_CLOSE: Array[String] = [
	"[The warren is sealed.]",
	"[The record remains open.]",
]
const EPILOGUE_LINK_LINE := "— The story continues at wanderinginn.com —"
const EPILOGUE_HOLD_BEFORE_TEXT := 0.8
const EPILOGUE_LINE_HOLD := 1.6
const EPILOGUE_READ_HOLD := 2.6

## Issue #79 (evolution-fork visibility): a one-line RESULT flavor per
## evolution TARGET class id, spoken as a second GDI line right after the
## bare "[X Class -> Y Class!]" proclamation (CLASS_EVOLVED handler below).
## Results-only, no pre-telegraph -- the opaque-until-sleep lock's own
## discipline holds: this speaks ONLY once the fork has already resolved,
## never a hint beforehand (`_EVOLUTION_WAITING_TOASTS` in wi_game.gd is the
## PRE-resolution voice; this is its POST-resolution twin, deliberately
## mirrored in the same "Your X have/hasn't Y" cadence). Presentation-only
## (matches this whole file's own doc comment) -- lives here, not
## wi_game.gd, since it's purely the veil's own re-voicing, never read by
## the sim or the plain class_evolved toast (wi_game.gd's own "[X] has
## become [Y]!" stays unchanged). Covers every shipped Replacement target
## (warrior -> swordsman/spearmaster, mage -> ice_mage/fire_mage, helper ->
## barmaid/server); archer -> sharpshooter is Replacement-only with a
## SINGLE target (no real fork to voice, see that class's own _comment) so
## it's deliberately absent -- `.get(..., "")` degrades a future fork-less
## target to silence, not a crash.
const _EVOLUTION_RESULT_FLAVOR := {
	"swordsman": "Your hands have chosen the sword.",
	"spearmaster": "Your hands have chosen the spear.",
	"ice_mage": "Your focus has settled on frost.",
	"fire_mage": "Your focus has settled on flame.",
	"barmaid": "You've settled into serving the room.",
	"server": "You've settled into running the city.",
}

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
## Issue #87: true iff THIS sleep's collection window saw a
## CONSOLIDATION_OFFERED (set below, reset every `_begin_sleep`) -- makes
## `_run_sequence`'s real-play reveal fully unskippable for that one sleep
## (see the file doc comment's PLAIN-SLEEP SKIP guard).
var _sleep_has_consolidation := false

## Opener state. _opener_running gates its own input/sequence; _opener_advance
## is set by a confirm/cancel press to cut the current line's hold short.
var _opener_running := false
var _opener_advance := false

## Epilogue state. _epilogue_armed is set true by
## accomplishment_recorded{raskghar_sealed} and consumed by the next
## dialogue_ended (which plays the epilogue); _epilogue_running gates its
## sequence. The skip flag is shared with the opener (_opener_advance).
var _epilogue_running := false
var _epilogue_armed := false

## Defeat-interstitial state (issue #78). Gates play_defeat()'s own
## sequence, mirroring _opener_running/_epilogue_running. Its terminal beat
## is a real CHOICE (not a skip) -- _defeat_choice_pending gates a dedicated
## await loop in _unhandled_input (confirm=continue into the reloaded world,
## cancel=title screen), deliberately NOT sharing _opener_advance (that flag
## means "cut this hold short", not "pick between two different outcomes").
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
			# A4: ARM the epilogue the instant the Raskghar is sealed (banked mid
			# Zevara's seal dialogue). The reveal waits for the dialogue to END so
			# her line lands first. raskghar_sealed banks exactly once (the seal
			# option is hide_when-guarded), and accomplishment_recorded never
			# re-emits on load, so this arms at most once per playthrough.
			if String(payload.get("id", "")) == "raskghar_sealed":
				_epilogue_armed = true
			# Magical Door: the door's OWN milestone line -- the veil's FOURTH
			# cameo (after the class/level/evolution toasts above, the opener,
			# and the epilogue). door_awakened banks INSIDE wi_game.gd's
			# sleep() (after progression resolves, additive-only),
			# synchronously within the SAME sleep burst this veil is already
			# buffering (`_running` is true from this sleep's own
			# UNCONDITIONAL phase_changed emit, which always fires FIRST) --
			# so this rides the EXACT SAME collection idiom
			# CLASS_GAINED/CLASS_LEVEL_UP/etc. use above, not a new
			# mechanism. The door itself NEVER speaks (Global Constraint) --
			# this is the GDI's OWN voice.
			if _running and String(payload.get("id", "")) == "door_awakened":
				_lines.append("[The inn has a Door. The Door has opinions.]")
			# Garden fanfare (user ruling: the unlock was silent): the
			# qualifying sleep banks garden_door_unlocked inside sleep() --
			# same synchronous-burst idiom as door_awakened above, the
			# veil's fifth cameo. Erin's own morning acknowledgment
			# (talk_pool_stages) remains the daylight half of the beat.
			if _running and String(payload.get("id", "")) == "garden_door_unlocked":
				_lines.append("[A door opens that no one built. The Garden of Sanctuary remembers how to wait.]")
			# Issue #92 R4 (resonance growth): the veil's SIXTH cameo (after
			# class/level/evolution toasts, the opener, the epilogue, door_
			# awakened, and garden_door_unlocked). resonance_grown banks
			# INSIDE wi_game.gd's sleep() (gated on door_awakened already
			# being true, so this can only ever land on a LATER sleep than
			# the awakening's own -- see that hook's own doc comment for why
			# that gating exists), same synchronous-burst idiom as every
			# cameo above.
			if _running and String(payload.get("id", "")) == "resonance_grown":
				_lines.append("[The anchor stone gives up a sliver of itself. You have room for it now.]")
		WIEvents.DIALOGUE_ENDED:
			# A4: the armed epilogue plays as the seal conversation clears.
			if _epilogue_armed:
				_epilogue_armed = false
				play_epilogue()


## Opens the collection window and queues the (single) deferred reveal. The
## deferred call runs at the next idle, AFTER sleep()'s whole synchronous emit
## burst has unwound, so `_lines` is fully populated by then.
func _begin_sleep() -> void:
	# Guard against a sleep beat racing the cold open. A player who reaches
	# the inn bed during the ~8s opener would otherwise start a SECOND veil
	# coroutine over the shared _black/_line_box (a cosmetic un-black
	# glitch); _opener_running blocks that until the opener has faded out and
	# cleared. (play_opener has the mirror guard against a sleep already running.)
	if _running or _opener_running or _epilogue_running:
		return
	_running = true
	_lines = []
	_sleep_has_consolidation = false
	if not _reveal_queued:
		_reveal_queued = true
		_run_sequence.call_deferred()


## The GDI new-game cold open. Called by WIMain right after the fresh world
## is spawned, ONLY on GAME_RESET. Opens opaque-black immediately (no
## fade-in — a cold open, not a dip), speaks the arrival lines, then fades
## to the inn. QA/headless collapses to an instant coverage event; real
## play is paced + skippable via _unhandled_input below.
func play_opener() -> void:
	if _running or _opener_running or _epilogue_running:
		return
	if _is_qa():
		# Collapsed: no visible hold — record coverage the same beat, right after
		# world_ready, so title_flow's assert is deterministic.
		_emit_opener_rendered(_opener_lines().size())
		return
	_opener_running = true
	_run_opener.call_deferred()


## ONE opener for every race now, so this just returns the single const.
## Kept as a function (not inlined at call sites) so a future string-table
## swap stays a one-line change here.
func _opener_lines() -> Array:
	return OPENER_LINES


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


## True while the cold-open, the epilogue, the defeat interstitial, or (issue
## #87) the plain-sleep reveal holds the screen. world.gd's `_movement_
## gated()` treats this as a modal (via WIMain.veil_modal_active()) -- on
## pad, `interact` and this veil's confirm-advance share button A, so
## without the gate a pad player advancing the reveal text would
## simultaneously fire world interact()s at whatever the PC happens to face
## under the black. Never observably true under QA/TestDriver:
## `play_opener()`/`play_epilogue()`/`play_defeat()` collapse to an instant
## coverage emit before ever setting their own running flags, and
## `_begin_sleep()`'s `_running = true` is undone by `_run_sequence`'s own
## `_is_qa()` branch (`_finish()`, synchronously inside the same deferred
## call, no `await` reached) before any later frame's input can observe it
## -- every canonical's input timing is untouched by the new gate.
func modal_active() -> bool:
	return _running or _opener_running or _epilogue_running or _defeat_running


## The veil's ONLY interactive touch (the plain sleep path never intercepts
## input): while the cold-open OR the epilogue holds, confirm/cancel advances the
## current line and, past the last, skips straight to the fade. Swallows only
## those two actions so a replaying/finishing player is never held hostage.
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
	# Issue #87: `_running` (the plain-sleep reveal) joins the other three
	# veil modes -- consumed unconditionally, even during a consolidation-
	# guarded sleep (`_sleep_has_consolidation`), where `_wait()` (not
	# `_wait_or_advance()`) simply ignores the resulting `_opener_advance`
	# flag; consuming the input either way still stops it leaking through to
	# world.gd underneath, same as every other veil mode.
	if not (_running or _opener_running or _epilogue_running or _defeat_running):
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


## The GDI epilogue. Called from the DIALOGUE_ENDED handler once the seal
## beat has closed. Fades to black over the SAME world beneath, speaks the
## arrival-mirroring close + the generated recount, then fades back to free
## play and banks post_game. QA/headless collapses to an instant coverage event.
func play_epilogue() -> void:
	if _running or _opener_running or _epilogue_running:
		return
	# Hard once-only: if the ending was already witnessed, never re-fire (guards a
	# stray dialogue_ended after a post-game load, though the arm is already
	# once-only by raskghar_sealed's hide_when).
	if Game.sim.accomplishment_count("post_game") > 0:
		return
	if _is_qa():
		# Collapsed: record coverage + bank post_game the same beat, no visible hold.
		_emit_epilogue_rendered(_epilogue_lines().size())
		_bank_post_game()
		return
	_epilogue_running = true
	_run_epilogue.call_deferred()


## The full epilogue line list: the GDI open copy, the GENERATED per-class recount
## (results-only — a class name + its level, the visible-tier rule), the close
## copy, and the wanderinginn.com line. Read once; the QA-collapse and the paced
## reveal share it so the emitted `lines` count always matches what rendered.
func _epilogue_lines() -> Array[String]:
	var lines: Array[String] = []
	lines.append_array(EPILOGUE_LINES_OPEN)
	# Recount straight from the sim snapshot: {class_id: level}, in the order the
	# classes were earned (Dictionary insertion order). Names resolve through the
	# same data-loaded map the sleep/opener lines use, so no raw id ever leaks.
	var classes: Dictionary = Game.sim.snapshot().get("classes", {})
	for cid: Variant in classes:
		lines.append("[%s Level %d.]" % [_class_name(String(cid)), int(classes[cid])])
	lines.append_array(EPILOGUE_LINES_CLOSE)
	lines.append(EPILOGUE_LINK_LINE)
	return lines


func _run_epilogue() -> void:
	_black.show()
	await _fade(_black, 1.0)
	await _wait(EPILOGUE_HOLD_BEFORE_TEXT)
	var lines := _epilogue_lines()
	for i in lines.size():
		_add_line(String(lines[i]))
		var last := i == lines.size() - 1
		# Reuses the opener's confirm/cancel advance (_opener_advance) so the
		# ending is skippable line-by-line, never a hostage hold.
		await _wait_or_advance(EPILOGUE_READ_HOLD if last else EPILOGUE_LINE_HOLD)
	_emit_epilogue_rendered(lines.size())
	_bank_post_game()
	await _fade(_black, 0.0)
	_epilogue_running = false
	_finish()


## The one sim write the epilogue mode makes: "the ending was witnessed" is
## genuine game state (the journal's Act III completed beat reads it; it guards
## re-fire). Idempotent — banks post_game at most once.
func _bank_post_game() -> void:
	if Game.sim.accomplishment_count("post_game") == 0:
		Game.sim.record_accomplishment("post_game")


func _emit_epilogue_rendered(count: int) -> void:
	ObservableBus.emit_domain_event(WIEvents.UI_GDI_EPILOGUE_RENDERED, {"lines": count})


## Issue #78: the defeat interstitial (the veil's FOURTH mode). Called by
## WIMain right after a defeat-reload's FRESH world has spawned (see
## main.gd's swap_to_world(defeat_reload) arg, driven off
## GAME_LOADED{reason:"defeat"}) -- PRESENTATION ONLY, over an
## ALREADY-COMPLETE reload: combat_screen.gd's `_close_banner` has already
## run `resolve_combat -> teardown_board -> Game.load_slot("auto", "defeat")`
## by the time this fires, so this function reads the ALREADY-restored
## `Game.sim.current_map` for its "where you are" line, never causes the
## reload itself. Diegetic register (waking up after loss, not a "GAME
## OVER" screen), per the project's tone. Two beats: (1) short GDI-voiced
## lines (what happened + where the autosave returned you + a retry hint),
## paced/skippable exactly like the opener; (2) a terminal CHOICE, not an
## auto-fade -- Confirm dismisses into the reloaded world (you're already
## standing there), Cancel returns to the title screen instead (e.g. to
## pick a different save). QA/headless collapses to an instant coverage
## emit with NEITHER beat run -- the collapsed path never shows or resolves
## the choice, so defeat_reload's existing "confirm on the banner -> land
## back in the reloaded world" flow is untouched by construction; a human
## windowed playtest is what actually exercises the Confirm/Cancel branches
## (same precedent as the opener/epilogue's own skip-ability, per this
## file's header doc: "FEEL is therefore human-playtest-gated").
func play_defeat() -> void:
	if _running or _opener_running or _epilogue_running or _defeat_running:
		return
	if _is_qa():
		_emit_defeat_rendered(_defeat_lines().size())
		return
	_defeat_running = true
	_run_defeat.call_deferred()


## GDI-voiced: blunt system readout, the reload location (title-cased from
## `current_map`, the same underscore-split convention title_screen.gd's
## fixture-name display uses), then a plain diegetic retry nudge -- no
## stats, no "press X" imperative (the terminal choice's own labels carry
## the actual button hints, see _add_choice_rows).
func _defeat_lines() -> Array[String]:
	return [
		"[Defeat.]",
		"You wake at %s, the fight undone." % _map_display_name(String(Game.sim.current_map)),
		"Try again, or step more carefully.",
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
	if not continue_chosen:
		var main := get_parent()
		if main != null and main.has_method("swap_to_title"):
			main.call_deferred("swap_to_title")


## The terminal choice's two clickable rows (issue #84: keyboard-native via
## confirm/cancel already, this adds mouse parity). Freed along with every
## other line label by `_finish()`'s existing "clear _line_box's children"
## sweep -- no separate teardown needed.
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


## Awaits the terminal choice, resolved either by `_unhandled_input`
## (confirm/cancel) or `_on_choice_row_input` (a row click) -- both just
## flip `_defeat_choice_pending` false and set `_defeat_choice_result`.
func _wait_for_defeat_choice() -> bool:
	_defeat_choice_pending = true
	while _defeat_choice_pending:
		await get_tree().process_frame
	return _defeat_choice_result


func _emit_defeat_rendered(count: int) -> void:
	ObservableBus.emit_domain_event(WIEvents.UI_DEFEAT_VEIL_RENDERED, {"lines": count, "map": String(Game.sim.current_map)})


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
		return

	_black.show()
	await _fade(_black, 1.0)

	await _wait(HOLD_BEFORE_TEXT)
	# Issue #87: skippable via the opener's own _wait_or_advance seam UNLESS
	# this sleep offered a consolidation -- see the PLAIN-SLEEP SKIP guard
	# doc comment. Every line still gets its own _add_line() call either way
	# (only the HOLD between lines is ever cut short), so the consolidation
	# line itself is never dropped -- it just can't be rushed past.
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
	# The "screen is the player's again" moment. CONSTRAINT: after _finish()
	# (black hidden, _running false) so a listener showing UI on this event
	# can never race the fade-out.
	_emit_finished()


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


## Same TestDriver.active()/headless collapse gate combat_screen.gd and
## world.gd use for their presentation delays.
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
