class_name WIVitals
extends RefCounted

const MAX_SAVED_VALUE := 2147483647

var hp: int = 1
var mp: int = 0
var mp_potion_doses: int = 0


func reconcile(maxima: Dictionary) -> void:
	hp = clampi(hp, 1, int(maxima[WIKeys.MAX_HP]))
	mp = clampi(mp, 0, int(maxima[WIKeys.MAX_MP]))


func refill(maxima: Dictionary) -> void:
	hp = int(maxima[WIKeys.MAX_HP])
	mp = int(maxima[WIKeys.MAX_MP])
	mp_potion_doses = 0


func serialized() -> Dictionary:
	return {WIKeys.HP: hp, WIKeys.MP: mp, "mp_potion_doses": mp_potion_doses}


func restore(state: Dictionary, maxima: Dictionary) -> void:
	hp = int(state[WIKeys.HP])
	mp = int(state[WIKeys.MP])
	mp_potion_doses = int(state["mp_potion_doses"])
	reconcile(maxima)


static func valid_saved(state: Variant) -> bool:
	if not (state is Dictionary):
		return false
	for key: String in [WIKeys.HP, WIKeys.MP, "mp_potion_doses"]:
		if not state.has(key):
			return false
		var value: Variant = state[key]
		if not (value is int or value is float):
			return false
		var number := float(value)
		if not is_finite(number) or number != floor(number):
			return false
		if number < (1 if key == WIKeys.HP else 0) or number > MAX_SAVED_VALUE:
			return false
	return true
