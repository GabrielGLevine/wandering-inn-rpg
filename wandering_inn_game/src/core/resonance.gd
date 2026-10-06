class_name WIResonance
extends RefCounted

const DEFAULT_INITIAL := 4
const DEFAULT_GROWTH := 1
const LEGACY_BASELINE_INCREASE := 2
const MAX_CAPACITY: int = 9223372036854775807


static func valid_capacity(value: Variant) -> bool:
	if value is int:
		return value >= 0
	if value is float:
		return is_finite(value) and value >= 0.0 and value == floor(value) and value < float(MAX_CAPACITY)
	return false


static func initial(config: Dictionary) -> int:
	return int(config.get("initial_capacity", DEFAULT_INITIAL))


static func growth(config: Dictionary) -> int:
	return int(config.get("growth_amount", DEFAULT_GROWTH))
