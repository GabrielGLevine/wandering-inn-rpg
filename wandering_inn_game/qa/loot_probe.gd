extends SceneTree
## Throwaway probe: replicate WIGame._roll_loot's isolated RNG to learn which
## loot entries fire per (run_seed, encounter_id). Mirrors the roll ORDER exactly:
## table iterated in-order, one randf() per entry, entry fires iff randf < chance.
## Gold entries are APPENDED after existing item entries (so item draws are byte
## identical). Run: godot --headless --path . --script res://qa/loot_probe.gd

func _roll(run_seed: int, id: String, table: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%s" % [run_seed, id])
	var out := {"items": [], "gold": 0, "rolls": []}
	for drop: Dictionary in table:
		var chance: float = float(drop.get("chance", 0.0))
		var r: float = rng.randf()
		var fired: bool = r < chance
		out["rolls"].append("%s r=%.4f<%.2f %s" % [drop.get("item", "gold%d" % int(drop.get("gold", 0))), r, chance, "FIRE" if fired else "-"])
		if fired:
			if drop.has("gold"):
				out["gold"] += int(drop["gold"])
			else:
				out["items"].append(String(drop["item"]))
	return out

func _init() -> void:
	# Candidate tables: existing item entry FIRST, appended gold SECOND.
	var cases := [
		[9, "goblin_encounter_1", [{"item": "crude_blade", "chance": 0.25}, {"gold": 2, "chance": 0.5}]],
		[9, "goblin_encounter_2", [{"item": "chipped_spear", "chance": 0.25}, {"gold": 2, "chance": 0.5}]],
		[9, "chieftains_raid", [{"item": "chipped_spear", "chance": 0.5}, {"gold": 5, "chance": 0.75}]],
		[1, "chieftains_raid", [{"item": "chipped_spear", "chance": 0.5}, {"gold": 5, "chance": 0.75}]],
		[3, "chieftains_raid", [{"item": "chipped_spear", "chance": 0.5}, {"gold": 5, "chance": 0.75}]],
		[9, "crate_scavengers", [{"gold": 2, "chance": 0.5}]],
		[9, "supplier_scavengers", [{"gold": 2, "chance": 0.5}]],
		[3, "goblin_encounter_2", [{"item": "chipped_spear", "chance": 0.25}, {"gold": 2, "chance": 0.5}]],
		[3, "goblin_encounter_1", [{"item": "crude_blade", "chance": 0.25}, {"gold": 2, "chance": 0.5}]],
	]
	for c: Array in cases:
		var res := _roll(int(c[0]), String(c[1]), c[2] as Array)
		print("seed=%d %-20s items=%s gold=%d  | %s" % [int(c[0]), c[1], str(res["items"]), int(res["gold"]), " ; ".join(res["rolls"])])
	quit(0)
