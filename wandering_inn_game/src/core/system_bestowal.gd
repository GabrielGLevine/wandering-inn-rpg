class_name WISystemBestowal
extends RefCounted

## Issue #347 PROTOTYPE (v0.18 lane W2), behind a debug flag, ZERO player
## surface. Authority: docs/design/2026-08-02-dynamic-class-creation-spec.md
## (verdict BUILD-REDUCED -- authored records selected by derived portfolio
## predicates; generative assembly is the §2.1 no-build).
##
## What this file IS: the pure derivation half of slice 0. It reads tracked
## state (held classes + accomplishment counters, which is where skill-use and
## quest-path tallies already live) and returns AT MOST ONE authored candidate
## from data/system_bestowals.json.
##
## What this file deliberately is NOT, this wave:
##  - it never grants a class, never writes a counter, never touches a save;
##  - it is never consulted unless the debug flag is on (log_enabled());
##  - it holds no class RECORD -- data/classes.json is another lane's file, so
##    the prototype table carries authored NAMES ONLY (proposals for the
##    naming-voice read), not levels/grants/balance. SEAM: when the real step
##    lands, the rows move into classes.json as `bestowed_by` blocks per spec
##    §3.1 and the name pool dies with this file.
##
## Determinism: no rng, no clock, no autoload, no engine state. Same counters +
## same table -> byte-identical payload, at every seed. `inputs` keys are
## emitted in sorted order so the log line itself is stable.
##
## Naming: the System is never named on any surface (spoiler-cutoff.md rule 1);
## internal identifiers are neutral -- system_bestowal_*.

const RULES_PATH := "res://data/system_bestowals.json"

## Three flag paths, one meaning; any of them ON arms the log.
##   --system-bestowal-log=1   user arg (the --map-transition-visual=1 idiom;
##                             works through qa/run_qa.sh's arg passthrough)
##   WI_SYSTEM_BESTOWAL_LOG=1  environment (shells, CI, the demo launch line)
##   wi/debug/system_bestowal_log  ProjectSettings (editor + in-process tests;
##                             absent from project.godot on purpose -- reading
##                             a missing setting yields the false default)
const FLAG_ARG := "system-bestowal-log"
const FLAG_ENV := "WI_SYSTEM_BESTOWAL_LOG"
const FLAG_SETTING := "wi/debug/system_bestowal_log"

## Spec §3.3 one-per-run cap. Read-only here: the prototype bestows nothing, so
## nothing banks this -- the arm exists so the shipped step inherits it proven.
const CAP_COUNTER := "class_bestowed"

## Spec §3.1's CLOSED predicate vocabulary. A rule asking for a seventh arm is
## DECLINED, not accommodated (kill criterion K1) -- _row_verdict returns
## met=false with the offending arm named, and the table test fails loud.
const ARMS: Array[String] = ["requires", "requires_any", "dominance", "breadth", "absence", "excludes_classes"]

static var _rules_cache: Dictionary = {}
static var _rules_loaded := false


static func log_enabled() -> bool:
	if String(QAPaths.user_args().get(FLAG_ARG, "")) == "1":
		return true
	if OS.get_environment(FLAG_ENV) == "1":
		return true
	return bool(ProjectSettings.get_setting(FLAG_SETTING, false))


## Disk read, cached. Kept OUT of evaluate() so the derivation itself stays a
## pure function of its arguments (that is what the determinism arms assert).
static func rules() -> Dictionary:
	if not _rules_loaded:
		_rules_cache = load_rules(RULES_PATH)
		_rules_loaded = true
	return _rules_cache


static func load_rules(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func reset_cache() -> void:
	_rules_cache = {}
	_rules_loaded = false


## THE derivation. Returns the log payload -- always a Dictionary, never empty:
## `matched` says whether a bestowal WOULD fire. Catalog order is the only
## tie-break (first matching row wins, then stop), exactly as
## WIProgression.check_class_gains iterates its catalog.
##
## The unmatched report names the FIRST row's first failing arm. First, not
## "closest": a nearness score would be a heuristic nobody could reproduce by
## hand, and this line exists to be reproducible.
static func evaluate(rule_table: Dictionary, classes: Dictionary, accomplishments: Dictionary) -> Dictionary:
	var rows: Array = rule_table.get("bestowals", [])
	if int(accomplishments.get(CAP_COUNTER, 0)) >= 1:
		return {
			"matched": false,
			"id": "",
			"name": "",
			"arms": [],
			"inputs": {CAP_COUNTER: int(accomplishments.get(CAP_COUNTER, 0))},
			"blocked_by": "cap",
			"why": "one bestowal per run (spec 3.3); this run already spent it",
		}
	var first_miss: Dictionary = {}
	for row: Dictionary in rows:
		var verdict := _row_verdict(row, classes, accomplishments)
		if bool(verdict["met"]):
			return {
				"matched": true,
				"id": String(row.get("id", "")),
				"name": String(row.get("name_proposed", "")),
				"arms": present_arms(row),
				"inputs": verdict["inputs"],
				"blocked_by": "",
				"why": String(row.get("why", "")),
			}
		if first_miss.is_empty():
			first_miss = {
				"matched": false,
				"id": String(row.get("id", "")),
				"name": String(row.get("name_proposed", "")),
				"arms": present_arms(row),
				"inputs": verdict["inputs"],
				"blocked_by": String(verdict["failed_arm"]),
				"why": String(row.get("why", "")),
			}
	if first_miss.is_empty():
		return {"matched": false, "id": "", "name": "", "arms": [], "inputs": {}, "blocked_by": "no_rules", "why": ""}
	return first_miss


## Every arm this row actually declares, in the canonical ARMS order (so two
## rows with the same arms always log the same list).
static func present_arms(row: Dictionary) -> Array:
	var when: Dictionary = row.get("when", {})
	var out: Array = []
	for arm: String in ARMS:
		if when.has(arm):
			out.append(arm)
	return out


## Every counter id this row reads, sorted. Used by the log payload and by the
## table test's producer check.
static func counters_read(row: Dictionary) -> Array:
	var when: Dictionary = row.get("when", {})
	var seen: Dictionary = {}
	for arm: String in ["requires", "requires_any", "absence"]:
		for counter: String in (when.get(arm, {}) as Dictionary):
			seen[counter] = true
	for counter: Variant in (when.get("breadth", {}) as Dictionary).get("counters", []):
		seen[String(counter)] = true
	var dom: Dictionary = when.get("dominance", {})
	if not dom.is_empty():
		seen[String(dom.get("counter", ""))] = true
		for counter: Variant in (dom.get("pool", []) as Array):
			seen[String(counter)] = true
	seen.erase("")
	var keys: Array = seen.keys()
	keys.sort()
	return keys


static func _inputs_for(row: Dictionary, accomplishments: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for counter: String in counters_read(row):
		out[counter] = int(accomplishments.get(counter, 0))
	return out


## All declared arms must pass (AND). Arms are evaluated in ARMS order so the
## reported failure is stable, never dependent on JSON key order.
static func _row_verdict(row: Dictionary, classes: Dictionary, accomplishments: Dictionary) -> Dictionary:
	var when: Dictionary = row.get("when", {})
	var inputs := _inputs_for(row, accomplishments)
	for arm: String in when:
		if not ARMS.has(arm):
			return {"met": false, "failed_arm": "unknown_arm:%s" % arm, "inputs": inputs}
	if when.is_empty():
		return {"met": false, "failed_arm": "empty_when", "inputs": inputs}
	for arm: String in ARMS:
		if not when.has(arm):
			continue
		if not _arm_met(arm, when[arm], classes, accomplishments):
			return {"met": false, "failed_arm": arm, "inputs": inputs}
	return {"met": true, "failed_arm": "", "inputs": inputs}


static func _arm_met(arm: String, spec: Variant, classes: Dictionary, accomplishments: Dictionary) -> bool:
	match arm:
		"requires":
			return _requires_met(spec as Dictionary, accomplishments)
		"requires_any":
			return _requires_any_met(spec as Dictionary, accomplishments)
		"dominance":
			return _dominance_met(spec as Dictionary, accomplishments)
		"breadth":
			return _breadth_met(spec as Dictionary, accomplishments)
		"absence":
			return _absence_met(spec as Dictionary, accomplishments)
		"excludes_classes":
			return _excludes_met(spec as Array, classes)
	return false


## Mirrors WIProgression._level_met's requires branch (progression.gd:182-186).
static func _requires_met(reqs: Dictionary, accomplishments: Dictionary) -> bool:
	for counter: String in reqs:
		if int(accomplishments.get(counter, 0)) < int(reqs[counter]):
			return false
	return true


## Mirrors WIProgression._level_met's requires_any branch (progression.gd:176-181).
static func _requires_any_met(reqs: Dictionary, accomplishments: Dictionary) -> bool:
	for counter: String in reqs:
		if int(accomplishments.get(counter, 0)) >= int(reqs[counter]):
			return true
	return false


## Mirrors the evolution dominance read (progression.gd:201-226): share of the
## pool, ties REJECTED, an empty pool is never dominant.
static func _dominance_met(spec: Dictionary, accomplishments: Dictionary) -> bool:
	var subject := String(spec.get("counter", ""))
	var pool: Array = spec.get("pool", [])
	var share := float(spec.get("share", 1.0))
	var total := 0
	var top := -1
	var tie := false
	for entry: Variant in pool:
		var count := int(accomplishments.get(String(entry), 0))
		total += count
		if count > top:
			top = count
			tie = false
		elif count == top:
			tie = true
	if total <= 0 or tie:
		return false
	var subject_count := int(accomplishments.get(subject, 0))
	if subject_count < top:
		return false
	return float(subject_count) / float(total) >= share


## NEW semantic (spec §3.1): the cross-pillar shape -- every listed counter has
## been touched at least min_each times. Breadth, not volume.
static func _breadth_met(spec: Dictionary, accomplishments: Dictionary) -> bool:
	var counters: Array = spec.get("counters", [])
	if counters.is_empty():
		return false
	var min_each := int(spec.get("min_each", 1))
	for entry: Variant in counters:
		if int(accomplishments.get(String(entry), 0)) < min_each:
			return false
	return true


## NEW semantic (spec §3.1): the "never did X" shape, and the one arm that
## breaks the monotonicity check_class_gains enjoys. Documented, not fixed:
## acting can CLOSE a future bestowal (canon-true -- paths close). Because
## evaluation only ever happens at the sleep beat, a closed path can never
## revoke a bestowal that already fired.
static func _absence_met(spec: Dictionary, accomplishments: Dictionary) -> bool:
	for counter: String in spec:
		if int(accomplishments.get(counter, 0)) > int(spec[counter]):
			return false
	return true


## The one non-counter arm: a held-class veto. Reads the classes dict only.
static func _excludes_met(ids: Array, classes: Dictionary) -> bool:
	for id: Variant in ids:
		if classes.has(String(id)):
			return false
	return true
