class_name WIResonance
extends RefCounted

const DEFAULT_INITIAL := 4
const DEFAULT_GROWTH := 1
const LEGACY_BASELINE_INCREASE := 2
# JSON reparses numbers as doubles; every accepted integer must survive that trip.
const MAX_CAPACITY: int = 9007199254740991


static func valid_capacity(value: Variant) -> bool:
	if value is int:
		return value >= 0 and value <= MAX_CAPACITY
	if value is float:
		return is_finite(value) and value >= 0.0 and value == floor(value) and value <= float(MAX_CAPACITY)
	return false


static func initial(config: Dictionary) -> int:
	var value: Variant = config.get("initial_capacity", DEFAULT_INITIAL)
	return int(value) if valid_capacity(value) else DEFAULT_INITIAL


static func growth(config: Dictionary) -> int:
	var value: Variant = config.get("growth_amount", DEFAULT_GROWTH)
	return int(value) if valid_capacity(value) else DEFAULT_GROWTH
