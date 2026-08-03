extends SceneTree

## Issue #347 slice-0 PROTOTYPE gate (v0.18 lane W2). Three jobs:
##  1. the predicate vocabulary behaves exactly as the spec's §3.1 table says,
##     arm by arm, including the two NEW semantics (breadth, absence);
##  2. the derivation is DETERMINISTIC -- same save, same candidate, every
##     seed, regardless of counter insertion order;
##  3. the flag is a real fence -- flag off, the sleep beat emits nothing new
##     and the whole event stream is unchanged.
## Locals are w2_-prefixed where they could collide with a sibling lane's arms.

const FIXTURE := "res://qa/fixtures/system_bestowal_demo.json"
const PLAYTEST_COPY := "res://qa/playtest_saves/2026-08-03-v018-w2-demo/system-bestowal-demo.json"
const FORBIDDEN_TOKENS := ["Isthekenous", "Grand Design", "GDI"]

var _events: Array = []


func _init() -> void:
	WITestWatchdog.arm(self)
	_flag_off()
	WISystemBestowal.reset_cache()

	_test_arms()
	_test_closed_vocabulary()
	_test_order_and_cap()
	_test_flag_paths()
	_test_shipped_table()
	_test_demo_fixture_and_determinism()

	print("PASS: system-bestowal prototype — arms, determinism, flag fence, demo fixture")
	quit(0)


# ---------------------------------------------------------------- arm truth table

func _rule(when: Dictionary, id: String = "w2_rule") -> Dictionary:
	return {"id": id, "name_proposed": "Test Name", "why": "because", "when": when}


func _table(rows: Array) -> Dictionary:
	return {"bestowals": rows}


func _matched(when: Dictionary, classes: Dictionary, accs: Dictionary) -> bool:
	return bool(WISystemBestowal.evaluate(_table([_rule(when)]), classes, accs)["matched"])


func _test_arms() -> void:
	# requires -- every counter at or above its floor (>=, not >).
	assert(_matched({"requires": {"a": 2}}, {}, {"a": 2}), "requires is inclusive at the threshold")
	assert(not _matched({"requires": {"a": 2}}, {}, {"a": 1}), "requires unmet one short")
	assert(not _matched({"requires": {"a": 1, "b": 1}}, {}, {"a": 9}), "requires is AND across counters")
	assert(not _matched({"requires": {"a": 1}}, {}, {}), "an absent counter reads 0")

	# requires_any -- one is enough, none is not.
	assert(_matched({"requires_any": {"a": 3, "b": 3}}, {}, {"b": 3}), "requires_any fires on either arm")
	assert(not _matched({"requires_any": {"a": 3, "b": 3}}, {}, {"a": 2, "b": 2}), "requires_any unmet when both fall short")

	# dominance -- share of the pool, ties rejected, empty pool never dominant.
	var w2_dom := {"dominance": {"counter": "a", "pool": ["a", "b", "c"], "share": 0.6}}
	assert(_matched(w2_dom, {}, {"a": 7, "b": 2, "c": 1}), "7/10 clears a 0.6 share")
	assert(not _matched(w2_dom, {}, {"a": 5, "b": 4, "c": 1}), "5/10 misses a 0.6 share")
	assert(not _matched(w2_dom, {}, {"a": 4, "b": 4, "c": 0}), "a tie at the top is never dominance")
	assert(not _matched(w2_dom, {}, {}), "an untouched pool is never dominance")
	assert(not _matched({"dominance": {"counter": "z", "pool": ["a", "b"], "share": 0.1}}, {}, {"a": 5, "b": 1}),
		"a subject outside the top is never dominance even at a low share")

	# breadth (NEW) -- every listed counter touched min_each times.
	var w2_breadth := {"breadth": {"counters": ["a", "b", "c"], "min_each": 2}}
	assert(_matched(w2_breadth, {}, {"a": 2, "b": 3, "c": 9}), "breadth met when every counter clears min_each")
	assert(not _matched(w2_breadth, {}, {"a": 2, "b": 1, "c": 9}), "breadth fails on ONE short counter, volume elsewhere cannot pay for it")
	assert(not _matched({"breadth": {"counters": [], "min_each": 1}}, {}, {"a": 9}), "an empty breadth list is never met (no vacuous truth)")

	# absence (NEW) -- ceiling, inclusive, and NON-MONOTONE by design.
	assert(_matched({"absence": {"won_combat": 2}}, {}, {"won_combat": 2}), "absence is inclusive at its ceiling")
	assert(_matched({"absence": {"won_combat": 2}}, {}, {}), "never having done it satisfies absence")
	assert(not _matched({"absence": {"won_combat": 2}}, {}, {"won_combat": 3}), "one over the ceiling closes it")

	# excludes_classes -- held-class veto.
	assert(_matched({"excludes_classes": ["spellsword"]}, {"warrior": 3}, {}), "veto silent when the class is not held")
	assert(not _matched({"excludes_classes": ["spellsword"]}, {"spellsword": 1}, {}), "holding the vetoed class declines the rule")

	# All declared arms must pass together.
	var w2_all := {"requires": {"a": 1}, "absence": {"b": 0}}
	assert(_matched(w2_all, {}, {"a": 1}), "AND across arms, both met")
	assert(not _matched(w2_all, {}, {"a": 1, "b": 1}), "AND across arms, absence broken")

	# The unmatched report names the first failing arm in ARMS order, and
	# carries the inputs that decided it.
	var w2_miss: Dictionary = WISystemBestowal.evaluate(
		_table([_rule({"requires": {"a": 5}, "absence": {"b": 0}})]), {}, {"a": 1, "b": 4})
	assert(not bool(w2_miss["matched"]), "unmatched report")
	assert(String(w2_miss["blocked_by"]) == "requires", "first failing arm in ARMS order is named, got %s" % w2_miss["blocked_by"])
	assert((w2_miss["inputs"] as Dictionary) == {"a": 1, "b": 4}, "inputs carry every counter the rule read")


func _test_closed_vocabulary() -> void:
	# Kill criterion K1: a seventh arm is DECLINED, never silently ignored --
	# silently ignoring it would make the rule fire on a weaker predicate than
	# its author wrote.
	var w2_verdict: Dictionary = WISystemBestowal.evaluate(
		_table([_rule({"requires": {"a": 1}, "never_did": {"b": 1}})]), {}, {"a": 9})
	assert(not bool(w2_verdict["matched"]), "an unknown arm declines the rule")
	assert(String(w2_verdict["blocked_by"]).begins_with("unknown_arm:"), "the unknown arm is named: %s" % w2_verdict["blocked_by"])
	assert(not _matched({}, {}, {"a": 9}), "an empty `when` is never a bestowal")


func _test_order_and_cap() -> void:
	# Catalog order is the only tie-break: first matching row wins, then stop.
	var w2_two := _table([
		_rule({"requires": {"a": 1}}, "w2_first"),
		_rule({"requires": {"a": 1}}, "w2_second"),
	])
	assert(String(WISystemBestowal.evaluate(w2_two, {}, {"a": 1})["id"]) == "w2_first", "first matching row wins")
	# Reversing the table reverses the winner -- proof the order IS the rule,
	# not an accident of dictionary hashing.
	var w2_rev := _table([
		_rule({"requires": {"a": 1}}, "w2_second"),
		_rule({"requires": {"a": 1}}, "w2_first"),
	])
	assert(String(WISystemBestowal.evaluate(w2_rev, {}, {"a": 1})["id"]) == "w2_second", "row order decides the winner")

	# Spec §3.3: one bestowal per run. Prototype banks nothing, so this arm is
	# read-only -- but it must already be true.
	var w2_capped: Dictionary = WISystemBestowal.evaluate(w2_two, {}, {"a": 1, "class_bestowed": 1})
	assert(not bool(w2_capped["matched"]) and String(w2_capped["blocked_by"]) == "cap", "the cap counter closes every rule")

	assert(not bool(WISystemBestowal.evaluate({}, {}, {"a": 1})["matched"]), "an empty table matches nothing")


func _test_flag_paths() -> void:
	# The SHIPPED off-state is the key being ABSENT, so that is what this arm
	# must read. Asserting against an explicitly-false key instead would pass
	# even if log_enabled()'s fallback default flipped to true -- i.e. even if
	# every shipped build evaluated the bestowal on every sleep. Mutation-checked
	# (`get_setting(FLAG_SETTING, true)` must red this line).
	assert(not ProjectSettings.has_setting(WISystemBestowal.FLAG_SETTING),
		"the flag key must be ABSENT here, not false -- absent is what project.godot ships")
	assert(not WISystemBestowal.log_enabled(), "flag is OFF by default -- no project.godot entry, no env, no user arg")
	OS.set_environment(WISystemBestowal.FLAG_ENV, "1")
	assert(WISystemBestowal.log_enabled(), "the environment path arms the log")
	OS.set_environment(WISystemBestowal.FLAG_ENV, "")
	assert(not WISystemBestowal.log_enabled(), "clearing the environment disarms it")
	ProjectSettings.set_setting(WISystemBestowal.FLAG_SETTING, true)
	assert(WISystemBestowal.log_enabled(), "the ProjectSettings path arms the log")
	# ...and an editor/user who writes the key as false is off too -- a separate
	# claim from the absent-key default above, so both are asserted.
	ProjectSettings.set_setting(WISystemBestowal.FLAG_SETTING, false)
	assert(not WISystemBestowal.log_enabled(), "an explicitly-false key reads off")
	_flag_off()
	assert(not ProjectSettings.has_setting(WISystemBestowal.FLAG_SETTING),
		"_flag_off must REMOVE the key, not pin it false -- every later flag-off arm depends on it")
	assert(not WISystemBestowal.log_enabled(), "and disarms again")


# ---------------------------------------------------------------- shipped table

func _test_shipped_table() -> void:
	var w2_table: Dictionary = WISystemBestowal.load_rules(WISystemBestowal.RULES_PATH)
	var w2_rows: Array = w2_table.get("bestowals", [])
	assert(not w2_rows.is_empty(), "the prototype table ships at least one rule")
	var w2_shipped: Dictionary = _load_json("res://data/shipped_ids.json")
	var w2_counters: Dictionary = {}
	for id: Variant in w2_shipped.get("accomplishments", []):
		w2_counters[String(id)] = true
	var w2_classes: Dictionary = {}
	for cls: Dictionary in _load_json("res://data/classes.json").get("classes", []):
		w2_classes[String(cls["id"])] = true
	var w2_seen_ids: Dictionary = {}
	var w2_arms_covered: Dictionary = {}
	for row: Dictionary in w2_rows:
		var id := String(row.get("id", ""))
		# Spoiler discipline: the System is never named, so its internal ids
		# stay neutral (system_bestowal_*) even in a dev-only log line.
		assert(id.begins_with("system_bestowal_"), "row id '%s' must be neutral (system_bestowal_*)" % id)
		assert(not w2_seen_ids.has(id), "duplicate row id %s" % id)
		w2_seen_ids[id] = true
		assert(String(row.get("name_proposed", "")) != "", "%s carries a proposed name" % id)
		assert(String(row.get("why", "")) != "", "%s says why in the log line" % id)
		var arms: Array = WISystemBestowal.present_arms(row)
		assert(not arms.is_empty(), "%s declares at least one arm" % id)
		for arm: Variant in (row.get("when", {}) as Dictionary):
			assert(WISystemBestowal.ARMS.has(String(arm)), "%s uses arm '%s' outside the closed vocabulary" % [id, arm])
			w2_arms_covered[String(arm)] = true
		for counter: Variant in WISystemBestowal.counters_read(row):
			assert(w2_counters.has(String(counter)), "%s reads counter '%s' which no producer banks" % [id, counter])
		for excluded: Variant in (row.get("when", {}) as Dictionary).get("excludes_classes", []):
			assert(w2_classes.has(String(excluded)), "%s vetoes class '%s' which has no classes.json row" % [id, excluded])
	# The prototype exists to prove the vocabulary, so the shipped table must
	# exercise ALL SIX arms between its rows -- a rule shape nobody demonstrates
	# is a rule shape nobody has tested against real counters.
	for arm: String in WISystemBestowal.ARMS:
		assert(w2_arms_covered.has(arm), "no shipped prototype rule exercises the '%s' arm" % arm)

	var w2_raw := FileAccess.get_file_as_string(WISystemBestowal.RULES_PATH)
	for token: String in FORBIDDEN_TOKENS:
		assert(not w2_raw.contains(token), "spoiler token '%s' in the rule table" % token)


# ---------------------------------------------------- demo fixture + determinism

func _test_demo_fixture_and_determinism() -> void:
	var w2_raw := FileAccess.get_file_as_string(FIXTURE)
	assert(w2_raw != "", "demo fixture is readable")
	assert(FileAccess.get_file_as_string(PLAYTEST_COPY) == w2_raw,
		"the playtest_saves copy has drifted from qa/fixtures/system_bestowal_demo.json -- re-copy it")

	# The flag fence, proven through the REAL sleep beat: flag off, the stream
	# carries no candidate line at all. "Off" here is the SHIPPED off -- the key
	# absent, not written false -- so this arm reds if the default ever flips.
	_flag_off()
	assert(not ProjectSettings.has_setting(WISystemBestowal.FLAG_SETTING),
		"the flag-off sleep arm must run against an ABSENT key")
	var w2_off := _sleep_events(9)
	for event: Dictionary in w2_off:
		assert(String(event["type"]) != WIEvents.SYSTEM_BESTOWAL_CANDIDATE, "flag off must emit no candidate")

	ProjectSettings.set_setting(WISystemBestowal.FLAG_SETTING, true)
	var w2_on := _sleep_events(9)
	var w2_candidates: Array = []
	var w2_stream_on: Array = []
	for event: Dictionary in w2_on:
		if String(event["type"]) == WIEvents.SYSTEM_BESTOWAL_CANDIDATE:
			w2_candidates.append(event["payload"])
		else:
			w2_stream_on.append(event)
	assert(w2_candidates.size() == 1, "exactly one candidate line per sleep, got %d" % w2_candidates.size())
	# Everything else about the night is untouched: the log is additive only.
	assert(JSON.stringify(w2_stream_on) == JSON.stringify(w2_off),
		"the flag added something other than the candidate line to the sleep stream")

	var w2_payload: Dictionary = w2_candidates[0]
	assert(bool(w2_payload["matched"]), "the demo fixture's first sleep matches a rule")
	assert(String(w2_payload["id"]) == "system_bestowal_pacifist", "demo matches the pacifist rule, got %s" % w2_payload["id"])
	assert(String(w2_payload["name"]) != "" and String(w2_payload["why"]) != "", "the log line carries name + why")
	assert((w2_payload["arms"] as Array).size() == 4, "the pacifist rule logs its four arms")
	var w2_inputs: Dictionary = w2_payload["inputs"]
	assert(int(w2_inputs["won_combat"]) == 2, "the log line carries the counters that decided it")
	var w2_keys: Array = w2_inputs.keys()
	var w2_sorted: Array = w2_inputs.keys()
	w2_sorted.sort()
	assert(w2_keys == w2_sorted, "input counters are logged in sorted order (stable log lines)")

	# Determinism: same save -> byte-identical candidate at every seed.
	var w2_reference := JSON.stringify(w2_payload)
	for seed_value: int in [1, 7, 9, 42, 4242]:
		var w2_again := _candidate_for(_sleep_events(seed_value))
		assert(JSON.stringify(w2_again) == w2_reference, "seed %d produced a different candidate" % seed_value)

	# ...and independent of counter insertion order (dictionaries preserve
	# insertion order in GDScript, so this is a real hazard, not a hypothetical).
	var w2_table := WISystemBestowal.load_rules(WISystemBestowal.RULES_PATH)
	var w2_state: Dictionary = (_load_json(FIXTURE).get("state", {}) as Dictionary)
	var w2_accs: Dictionary = w2_state.get("accomplishments", {})
	var w2_reversed: Dictionary = {}
	var w2_acc_keys: Array = w2_accs.keys()
	w2_acc_keys.reverse()
	for key: Variant in w2_acc_keys:
		w2_reversed[key] = w2_accs[key]
	var w2_classes_cfg: Dictionary = w2_state.get("classes", {})
	assert(JSON.stringify(WISystemBestowal.evaluate(w2_table, w2_classes_cfg, w2_accs))
		== JSON.stringify(WISystemBestowal.evaluate(w2_table, w2_classes_cfg, w2_reversed)),
		"counter insertion order changed the log line")

	# The absence arm's boundary is where the demo sits: one more win closes it.
	var w2_one_more: Dictionary = w2_accs.duplicate()
	w2_one_more["won_combat"] = int(w2_one_more["won_combat"]) + 1
	var w2_closed: Dictionary = WISystemBestowal.evaluate(w2_table, w2_classes_cfg, w2_one_more)
	assert(not bool(w2_closed["matched"]) and String(w2_closed["blocked_by"]) == "absence",
		"one more victory closes the pacifist path (non-monotonicity, documented)")

	_flag_off()


func _candidate_for(events: Array) -> Dictionary:
	for event: Dictionary in events:
		if String(event["type"]) == WIEvents.SYSTEM_BESTOWAL_CANDIDATE:
			return event["payload"]
	return {}


## Boots a real WIGame at `seed_value`, applies the demo save, sleeps once, and
## returns the whole event stream (the sleep beat is the subject, so nothing is
## stubbed).
func _sleep_events(seed_value: int) -> Array:
	_events = []
	WISceneCatalog.reset()
	var game := WIGame.new(
		WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, seed_value, _combat_config())
	assert(WISave.apply(game, _load_json(FIXTURE)), "demo fixture applies cleanly")
	_events = []
	game.sleep()
	return _events.duplicate()


func _combat_config() -> Dictionary:
	return {
		"combatants": _load_json("res://data/combatants.json"),
		"classes": _load_json("res://data/classes.json"),
		"arenas": _load_json("res://data/arenas.json"),
		"dialogue": {},
		"quests": _load_json("res://data/quests.json"),
		"acts": _load_json("res://data/acts.json"),
		"items": _load_json("res://data/items.json"),
		"progression": _load_json("res://data/progression.json"),
	}


func _sink(type: String, payload: Dictionary) -> void:
	_events.append({"type": type, "payload": payload})


## Restores the state a SHIPPED build is in: env cleared and the ProjectSettings
## key genuinely absent. Pinning it to false instead (the original shape) made
## every "flag off" arm in this file -- the default-state assert AND the
## flag-off sleep-stream comparison -- test a key no build ever carries, so a
## flipped default in log_enabled() sailed through the whole suite green.
## `clear` errors on a missing property, hence the guard.
func _flag_off() -> void:
	OS.set_environment(WISystemBestowal.FLAG_ENV, "")
	if ProjectSettings.has_setting(WISystemBestowal.FLAG_SETTING):
		ProjectSettings.clear(WISystemBestowal.FLAG_SETTING)


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON at " + path)
	return parsed
