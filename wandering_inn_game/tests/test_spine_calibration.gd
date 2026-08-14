extends SceneTree
## #439 — THE BALANCE GATE IN CI.
##
## `tests/sim_spine_viability.gd` is the REPORT: every row of its ROSTER x two
## build families x two policies x 100 seeds, and it regenerates
## `docs/design/spine-viability-table.md`. The row count is deliberately NOT
## written down here — it was "twelve" for exactly as long as it took the next
## wave to add a row, and a stale number in a header is a lie nothing tests.
## The generator prints the live count on every run. It is named `sim_` on purpose, so
## `scripts/preflight.sh --full` (which sweeps `tests/test_*.gd`) does not run
## it — a full table costs minutes.
##
## This file is the gate that DOES run: the same harness, the same builds, a
## deterministic seed subset, and only the rows whose value is a contract.
##
##   (a) THE FIVE CALIBRATION ROWS. Outcomes the shipped steel thread measured,
##       plus the two Act III rows #439 deliberately superseded. The expectation
##       list is read straight off `sim_spine_viability.gd` — never restated
##       here — so a row added or amended there is gated here on the next run
##       and the two files cannot drift. Asserted with the same subset slack the
##       window rows use, not as a bare categorical; see the loop's own note for
##       the knife-edge row that forces it.
##
##   (b) THE FOUR RETUNED FIGHTS, in the tuning window. Acts I–III climaxes
##       measured 0.98 / 1.00 / 0.99 / 1.00 competent-at-band before #439 (see
##       `docs/design/balance-bands-and-policy.md`'s measured table). The window
##       set there is competent-at-band in [0.55, 0.85]: hard enough that the
##       act gates, winnable by a player who uses their kit. IV and V were
##       already inside it and are NOT gated here — they are untouched content,
##       and gating them would make this file fail for someone else's change.
##
##   (c) THE RULED BANDS (#448). `sim_spine_viability.gd`'s `RULED_WINDOWS`,
##       read off the report the same way (a) reads `CALIBRATION`. These gate a
##       BAND rather than a categorical, because the fight they were written for
##       is DESIGNED to sit under 0.5: the Relc-veto solo branch read LOSS 0.04
##       when it was the join pack with the ally slot empty, and every
##       categorical gate in this file was green through it. Widened for the
##       subset like (b), but by `RULED_SLACK` — the solo row's own 25-vs-100
##       seed gap is measured at 0.15, wider than `WINDOW_SLACK` covers.
##
## THE SEED-COUNT TRADEOFF, stated because it is the one thing that makes this
## file cheaper than the report and the one thing that could mislead a reader:
## RUNS seeds instead of the table's 100. That is NOT a confidence interval —
## seeds are 1..RUNS, fixed, so the measurement is DETERMINISTIC and re-running
## it changes nothing. What the short run costs is AGREEMENT WITH THE TABLE: a
## 25-seed win rate sits within roughly +/-0.10 of the 100-seed one, so the
## windows below are the policy window WIDENED by that sampling gap
## (`WINDOW_SLACK`) and this file can only catch a fight that has left the
## window by more than the subset can see. The 100-seed table stays the
## authority; regenerate it (WI_SPINE_WRITE=1) after any encounter data change
## and read the numbers there. `WI_SPINE_RUNS=100 ...` runs this gate at full
## width when a wave wants the strict read.
##
##   Run:  godot --headless --path wandering_inn_game --script res://tests/test_spine_calibration.gd

const SPINE: GDScript = preload("res://tests/sim_spine_viability.gd")
const BATCH: GDScript = preload("res://tests/sim_combat_batch.gd")
const DRIVEN := {"pc": true}

## The #439 target from `docs/design/balance-bands-and-policy.md`.
const WINDOW_LO := 0.55
const WINDOW_HI := 0.85
## Widening for the short deterministic subset — see the tradeoff note above.
const WINDOW_SLACK := 0.10
## #448: the ruled bands need MORE than `WINDOW_SLACK`, and the number is
## measured, not padded for comfort. `act3_awakened_boss_solo | band | competent`
## reads 0.37 over the report's 100 seeds and 0.52 over this file's first 25 --
## a 0.15 gap, half again the +/-0.10 the header claims for the subset. Seeds
## 1-25 are simply a kind block for that fight, and a re-seeding is not a
## regression. Widening to 0.20 keeps the gate honest in the direction that
## matters: the defect #448 fixed measured 0.04 at 100 seeds and 0.00 over these
## 25, which is still far outside [0.15, 0.65] and still reds this file. A gate
## that cries wolf on sampling gets muted; this one only fires on content.
const RULED_SLACK := 0.20

## The retuned fights, by ROSTER id, with what they measured at 100 seeds on the
## regeneration that landed the retune (2026-08-12). The recorded value is
## documentation, not the gate: the gate is the window.
const RETUNED := [
	{"row": "act1_gate_ambush", "at_100": 0.80, "note": "2 raiders + shaman (was raider + shaman); pre-retune 0.98"},
	{"row": "act2_cistern_nest", "at_100": 0.78, "note": "pair + [Shield Spider Matriarch]; pre-retune 1.00"},
	{"row": "act3_raskghar_scouts", "at_100": 0.70, "note": "scout + [Raskghar Pack-Leader]; pre-retune 0.99"},
	{"row": "act3_awakened_boss", "at_100": 0.69, "note": "Awakened + 3 scouts (was 2); pre-retune 1.00"},
]

var _runs := 25
var _failures: Array = []


func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _median(values: Array) -> int:
	if values.is_empty():
		return 0
	var sorted: Array = values.duplicate()
	sorted.sort()
	return int(sorted[sorted.size() / 2])


func _find_build(name: String) -> Dictionary:
	for b: Dictionary in SPINE.BUILDS:
		if String(b["name"]) == name:
			return b
	assert(false, "unknown build %s" % name)
	return {}


func _find_row(row_id: String) -> Dictionary:
	for r: Dictionary in SPINE.ROSTER:
		if String(r["id"]) == row_id:
			return r
	assert(false, "unknown spine row %s" % row_id)
	return {}


## The map entity IS the encounter definition, exactly as the report reads it —
## so a roster edit lands here without anyone remembering to mirror it.
func _entity(map_id: String, entity_id: String) -> Dictionary:
	var map_data := _load("res://data/maps/%s.json" % map_id)
	for e: Dictionary in map_data.get("entities", []):
		if String(e.get(WIKeys.ID, "")) == entity_id:
			return e
	assert(false, "no entity %s in map %s" % [entity_id, map_id])
	return {}


func _measure(cell: Dictionary) -> Dictionary:
	var wins := 0
	var rounds: Array = []
	for seed_v in range(1, _runs + 1):
		var pol := WICombatPolicies.new(String(cell["policy"]))
		pol.items_by_id = cell["items_by_id"]
		pol.driven = DRIVEN.duplicate()
		var pack: Array = []
		for d: Variant in (cell["draughts"] as Array):
			pack.append(String(d))
		pol.carried = {"pc": pack}
		var cfgs: Array = []
		for cfg: Dictionary in (cell["cfgs"] as Array):
			cfgs.append(cfg.duplicate(true))
		var combat := WICombat.new(cell["arena"], cfgs, cell["skills"], func(_t: String, _p: Dictionary) -> void: pass, seed_v)
		# #460: a CI gate row naming the same fight as a table row must BE the same
		# fight, and that now includes the roster a summoner can reach for.
		combat.summon_catalog = cell.get("summon_catalog", {})
		combat.begin()
		var guard := 0
		while not combat.finished and guard < 2000:
			guard += 1
			pol.take_turn(combat)
		assert(combat.finished, "%s/%s seed %d did not terminate" % [cell["row"], cell["policy"], seed_v])
		rounds.append(int(combat.outcome["rounds"]))
		if bool(combat.outcome["victory"]):
			wins += 1
	var win_rate := float(wins) / float(_runs)
	return {
		"win_rate": win_rate,
		"result": "WIN" if win_rate >= 0.5 else "LOSS",
		"rounds": _median(rounds),
	}


func _init() -> void:
	WITestWatchdog.arm(self)
	var runs_env := OS.get_environment("WI_SPINE_RUNS")
	if runs_env != "":
		_runs = maxi(1, int(runs_env))

	var arena_by_id := {}
	for a: Dictionary in _load("res://data/arenas.json")["arenas"]:
		arena_by_id[String(a[WIKeys.ID])] = a
	var skills := _load("res://data/skills.json")
	var classes := _load("res://data/classes.json")
	var by_id := {}
	for c: Dictionary in _load("res://data/combatants.json")["combatants"]:
		by_id[String(c[WIKeys.ID])] = c
	var skills_by_id := {}
	for s: Dictionary in skills[WIKeys.SKILLS]:
		skills_by_id[String(s[WIKeys.ID])] = s
	var items_by_id := {}
	for it: Dictionary in _load("res://data/items.json")["items"]:
		items_by_id[String(it[WIKeys.ID])] = it

	# Only the cells this file gates get built — the report's other 39 are the
	# report's business.
	var wanted := {}
	for cal: Dictionary in SPINE.CALIBRATION:
		wanted["%s|%s|%s" % [cal["row"], cal["column"], cal["policy"]]] = cal
	for tuned: Dictionary in RETUNED:
		wanted["%s|band|%s" % [tuned["row"], WICombatPolicies.COMPETENT]] = null
	# (c) #448's ruled bands, read off the report exactly like CALIBRATION so the
	# two files cannot drift. A ruled band is the ONLY gate here that would fail
	# on a row sitting comfortably on the right side of 0.5, which is precisely
	# the shape of the defect it was written for.
	for ruled: Dictionary in SPINE.RULED_WINDOWS:
		wanted["%s|%s|%s" % [ruled["row"], ruled["column"], ruled["policy"]]] = null

	var measured := {}
	print("[calibration] %d cells x %d deterministic seeds (the table runs 100 — see the header)" % [wanted.size(), _runs])
	for key: String in wanted:
		var parts := key.split("|")
		var row := _find_row(parts[0])
		var entity := _entity(String(row["map"]), String(row["entity"]))
		var build := _find_build(String(row[parts[1]]))
		var rank := WIProgression.power_rank(build["classes"], classes) if bool(entity.get("scales", false)) else "bronze"
		var cfgs: Array = [BATCH._build_pc(build, by_id["pc"], classes, skills_by_id, items_by_id)]
		(cfgs[0] as Dictionary)[WIKeys.HP_MOD] = int((cfgs[0] as Dictionary).get(WIKeys.HP_MOD, 0)) + int(build.get("hp_mod_bonus", 0))
		# #448: branch selection goes through the report's own helpers, so a veto
		# row here fields the same pack the report measured and the same pack
		# `start_combat` builds.
		for ally_v: Variant in SPINE.row_allies(row, entity):
			var ally: Dictionary = (by_id[String(ally_v)] as Dictionary).duplicate(true)
			var hp_mods: Dictionary = row.get("ally_hp_mods", {})
			if hp_mods.has(String(ally_v)):
				ally[WIKeys.HP_MOD] = int(ally.get(WIKeys.HP_MOD, 0)) + int(hp_mods[String(ally_v)])
			cfgs.append(ally)
		for enemy_v: Variant in SPINE.row_enemies(row, entity):
			cfgs.append(WIBountyScaling.scale_enemy((by_id[String(enemy_v)] as Dictionary).duplicate(true), rank))
		measured[key] = _measure({
			"row": parts[0], "policy": parts[2], "arena": arena_by_id[String(entity["arena"])],
			"cfgs": cfgs, "skills": skills, "items_by_id": items_by_id, "draughts": row["draughts"],
			"summon_catalog": by_id,
		})
		print("[calibration] %-46s %s %.2f / %d rd" % [key, measured[key]["result"], measured[key]["win_rate"], measured[key]["rounds"]])

	# (a) the calibration rows, read off the report so they cannot drift apart.
	#
	# NOT a bare WIN/LOSS comparison, and the reason is measured: `act5_seal_warden
	# | ship | dumb` is a KNIFE-EDGE row. It reads 0.48 over the report's 100
	# seeds, so the categorical it carries ("LOSS") is decided by two points. A
	# 25-seed subset reproduces 0.48; a 40-seed subset reads exactly 0.50, which
	# `_measure` classifies as a WIN, and the row reddens on nothing but the seed
	# count. Gating the categorical here would therefore make the CHEAP gate the
	# strict one, which is backwards. So the subset asserts the weaker, honest
	# claim -- the row is not on the WRONG SIDE of 0.5 by more than the subset can
	# resolve -- and the 100-seed report keeps the categorical (and the
	# `rounds_near` checks this file does not duplicate). A real regression moves
	# these rows far further than WINDOW_SLACK; a re-seeding does not.
	for cal: Dictionary in SPINE.CALIBRATION:
		var key := "%s|%s|%s" % [cal["row"], cal["column"], cal["policy"]]
		var m: Dictionary = measured[key]
		var rate := float(m["win_rate"])
		var wrong := (rate < 0.5 - WINDOW_SLACK) if String(cal["want"]) == "WIN" else (rate > 0.5 + WINDOW_SLACK)
		if wrong:
			_failures.append("[calibration] %s: want %s, measured %s %.2f over %d deterministic seeds — past the 0.5 +/- %.2f the subset can resolve. Regenerate docs/design/spine-viability-table.md (WI_SPINE_WRITE=1); its 100-seed run owns the categorical. Ground truth: %s" % [
				key, cal["want"], m["result"], rate, _runs, WINDOW_SLACK, cal["why"]])

	# (b) the retuned fights, inside the tuning window
	var lo := WINDOW_LO - WINDOW_SLACK
	var hi := WINDOW_HI + WINDOW_SLACK
	for tuned: Dictionary in RETUNED:
		var key := "%s|band|%s" % [tuned["row"], WICombatPolicies.COMPETENT]
		var rate := float((measured[key] as Dictionary)["win_rate"])
		if rate < lo or rate > hi:
			_failures.append("[window] %s: competent-at-band %.2f is outside [%.2f, %.2f] (the #439 window [%.2f, %.2f] widened by the %d-seed subset's %.2f sampling gap). It measured %.2f at 100 seeds when the retune landed: %s. Regenerate docs/design/spine-viability-table.md (WI_SPINE_WRITE=1) and read the authoritative number before touching data." % [
				tuned["row"], rate, lo, hi, WINDOW_LO, WINDOW_HI, _runs, WINDOW_SLACK, tuned["at_100"], tuned["note"]])

	# (c) #448's ruled bands, widened by the same subset slack the window rows use.
	for ruled: Dictionary in SPINE.RULED_WINDOWS:
		var rkey := "%s|%s|%s" % [ruled["row"], ruled["column"], ruled["policy"]]
		var rrate := float((measured[rkey] as Dictionary)["win_rate"])
		var rlo := float(ruled["lo"]) - RULED_SLACK
		var rhi := float(ruled["hi"]) + RULED_SLACK
		if rrate < rlo or rrate > rhi:
			_failures.append("[ruled] %s: %.2f is outside [%.2f, %.2f] (the RULED band [%.2f, %.2f] widened by the %d-seed subset's %.2f sampling gap). This band is a user ruling, not a policy default: move the composition, never the window. Regenerate docs/design/spine-viability-table.md (WI_SPINE_WRITE=1) and read the 100-seed number before touching data. Ruling: %s" % [
				rkey, rrate, rlo, rhi, float(ruled["lo"]), float(ruled["hi"]), _runs, RULED_SLACK, ruled["why"]])

	if not _failures.is_empty():
		for line: String in _failures:
			printerr("FAIL %s" % line)
		# ORDER MATTERS (same defect already fixed in `sim_spine_viability.gd`):
		# a failed `assert` ABORTS the enclosing function, so with the assert
		# first `quit(1)` never ran and the one path this file exists to take
		# exited by WATCHDOG TIMEOUT instead of by failing. A hang is not a test
		# result — CI reads it as a stuck job, not a red gate. Claim the exit
		# code first; the assert still carries the message.
		quit(1)
		assert(false, "spine calibration/window rows disagree — see FAIL lines above")
		return
	print("PASS: %d calibration rows hold, %d retuned climaxes sit inside the #439 tuning window, and %d ruled band(s) hold" % [
		(SPINE.CALIBRATION as Array).size(), RETUNED.size(), (SPINE.RULED_WINDOWS as Array).size()])
	quit(0)
