extends SceneTree
## #514 L1: the combat bar's one-line Skill readout keeps its important clauses.
## Measures through the HUD's own fitter (`WICombatHud._compose_readout`) on a
## themed RichTextLabel in the tree, so the font and width are the shipped ones:
## the damage tag, the cooldown rule while ready, and the live Recovering clause
## while cooling must all survive the ellipsis.

const HEAD := "Traveler  AP ●●●●  Move ○○○"
const HINT := "Arrows move, number keys act, E ends turn"

var _host: Control
var _label: RichTextLabel
var _hud: WICombatHud
var _skills: Dictionary = {}


func _initialize() -> void:
	WITestWatchdog.arm(self)
	_host = Control.new()
	_host.theme = UIChrome.THEME
	root.add_child(_host)
	_label = UIChrome.make_rich_label("CombatReadout")
	_host.add_child(_label)
	_hud = WICombatHud.new(_host, null, null)
	_hud._readout_label = _label
	for s: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/skills.json"))[WIKeys.SKILLS]:
		_skills[String(s[WIKeys.ID])] = s


func _shown(skill_id: String, cooling: int) -> String:
	var sk: Dictionary = _skills[skill_id]
	var slot := {
		"type": "skill", "label": String(sk[WIKeys.DISPLAY_NAME]), "description": String(sk.get("description", "")),
		"effect": sk[WIKeys.EFFECT], WIKeys.WEAPON: String(sk.get(WIKeys.WEAPON, "")),
		WIKeys.DAMAGE_SOURCE: String(sk.get(WIKeys.DAMAGE_SOURCE, "")),
		"once_per_fight": bool(sk.get(WIKeys.ONCE_PER_FIGHT, false)),
		WICombat.COOLDOWN_ROUNDS: int(sk.get(WICombat.COOLDOWN_ROUNDS, 0)),
		"ap_cost": int(sk.get(WIKeys.AP_COST, 0)), "mp_cost": int(sk.get(WIKeys.MP_COST, 0)),
		"cooldown_remaining": cooling,
	}
	var readout := _hud._compose_readout(HEAD, HINT, _hud._slot_info_line(slot))
	return readout.split("\n")[-1]


func _process(_delta: float) -> bool:
	var expect := {
		"piercing_shot": ["weapon damage to all in a 4-cell line", "Once every 2 rounds."],
		"piercing_volley": ["weapon damage to all in a 5-cell line", "Once every 2 rounds."],
		"flame_pillar": ["spell damage 1d6 to friend and foe in a 3×3 area"],
	}
	for skill_id: String in expect:
		var ready := _shown(skill_id, 0)
		for clause: String in expect[skill_id]:
			assert(ready.contains(clause), "%s ready readout keeps '%s': %s" % [skill_id, clause, ready])
	for skill_id: String in ["piercing_shot", "piercing_volley"]:
		var cooling := _shown(skill_id, 2)
		assert(cooling.contains("Recovering — ready in 2 rounds."), "%s cooling readout keeps its live clause: %s" % [skill_id, cooling])
	_host.free()
	print("PASS: combat readout keeps the damage tag, cooldown and Recovering clauses")
	quit(0)
	return true
