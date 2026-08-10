extends SceneTree


func _init() -> void:
	WITestWatchdog.arm(self)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/classes.json"))
	var skills_catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills.json"))
	var dangersense: Dictionary = {}
	for skill: Dictionary in skills_catalog.get("skills", []):
		if String(skill.get("id", "")) == "dangersense":
			dangersense = skill
			break
	assert((dangersense.get("contexts", []) as Array) == ["combat", "exploration"],
		"[Dangersense] keeps combat context and adds exploration")
	assert(not dangersense.has("field"), "[Dangersense] is passive-while-held, never a field-hotbar cast")

	var l1 := WIProgression.granted_skills({"warrior": 1}, catalog)
	assert(l1 == ["basic_swordwork", "tough_body", "power_strike", "piercing_strikes"], "L1 grants in catalog order")
	var l2 := WIProgression.granted_skills({"warrior": 2}, catalog)
	assert(l2.has("counter_strike") and l2.has("battle_momentum") and l2.size() == 6, "L2 adds both grants")

	assert(WIProgression.check_level_ups({"warrior": 1}, {}, catalog).is_empty(), "no accomplishments = no level")
	assert(WIProgression.check_level_ups({"warrior": 1}, {"won_combat": 0}, catalog).is_empty(), "zero count insufficient")
	var ups := WIProgression.check_level_ups({"warrior": 1}, {"won_combat": 1}, catalog)
	assert(ups.size() == 1 and ups[0]["class"] == "warrior" and ups[0]["level"] == 2, "warrior 2 pending")
	assert((ups[0]["grants"] as Array).has("counter_strike"), "gains carry grants")
	assert(WIProgression.check_level_ups({"warrior": 2}, {"won_combat": 5}, catalog).is_empty(), "warrior L3 gates on melee_hit, so won_combat alone earns no further level")

	assert(WIProgression.check_class_gains({"warrior": 1}, {}, catalog).is_empty(), "unmet gained_by yields no gain")
	assert(WIProgression.check_class_gains({"warrior": 1}, {"learned_magic_from_pisces": 1}, catalog) == ["mage"], "met gained_by grants mage")
	assert(WIProgression.check_class_gains({"warrior": 1, "mage": 1}, {"learned_magic_from_pisces": 1}, catalog).is_empty(), "already-held class is not re-gained")
	assert(WIProgression.check_class_gains({"warrior": 1}, {"used_magic": 1}, catalog).is_empty(), "retired scroll accomplishment no longer grants mage")
	assert(WIProgression.check_class_gains({"warrior": 1}, {"won_combat": 5}, catalog).is_empty(), "already-held warrior is skipped regardless of any other accomplishment")
	var mage_l2 := WIProgression.check_level_ups({"mage": 1}, {"won_combat": 3}, catalog)
	assert(mage_l2.size() == 1 and mage_l2[0]["class"] == "mage" and mage_l2[0]["level"] == 2, "mage L2 pending on won_combat")
	assert((mage_l2[0]["grants"] as Array).has("flame_jet") and (mage_l2[0]["grants"] as Array).has("mana_shield"), "mage L2 grants")
	var mage_l1 := WIProgression.granted_skills({"mage": 1}, catalog)
	assert(mage_l1.has("frost_bolt") and mage_l1.has("quick_cast"), "mage L1 grants frost_bolt + quick_cast")
	assert(WIProgression.granted_skills({"mage": 7}, catalog).has("detect_magic"), "mage L7 grants detect_magic while L11 remains sparse")
	assert(not WIProgression.granted_skills({"rogue": 3}, catalog).has("dangersense"), "Rogue L3 does not grant [Dangersense] early")
	assert(WIProgression.granted_skills({"rogue": 4}, catalog).has("dangersense"), "Rogue L4 grants [Dangersense]")

	assert(WIProgression.check_class_gains({}, {"completed_delivery": 2}, catalog) == ["runner"], "two completed deliveries grant runner")
	assert(WIProgression.check_class_gains({}, {"witch_lessons": 1}, catalog) == ["hedge_witch"], "one witch lesson grants hedge witch")
	assert(WIProgression.check_class_gains({}, {"studied_necromancy": 1}, catalog) == ["necromancer"], "one necromancy study grants necromancer")
	assert(WIProgression.check_class_gains({}, {"cooked_meal": 5}, catalog) == ["cook"], "five cooked meals grant cook")
	assert(WIProgression.granted_skills({"runner": 1}, catalog) == ["quick_movement", "runners_legs"], "runner L1 kit")
	assert(WIProgression.granted_skills({"hedge_witch": 7}, catalog).has("evil_eye"), "hedge witch L7 kit includes evil_eye")
	var necro_l3 := WIProgression.check_level_ups({"necromancer": 1}, {"won_combat": 3, "death_cast": 4}, catalog)
	assert(necro_l3.size() == 2 and int(necro_l3[1]["level"]) == 3 and (necro_l3[1]["grants"] as Array) == ["deathbolt"], "necromancer walks to L3 and grants deathbolt")
	assert(WIProgression.granted_skills({"necromancer": 3}, catalog).has("bone_dart"), "necromancer L3 retains bone_dart")
	var dual_necro3 := WIProgression.granted_skills({"mage": 3, "necromancer": 3}, catalog)
	assert(dual_necro3.has("frost_bolt") and dual_necro3.has("bone_dart") and dual_necro3.has("deathbolt"), "mage 3/necromancer 3 folds both class kits")
	var dual_necro7 := WIProgression.granted_skills({"mage": 5, "necromancer": 7}, catalog)
	assert(dual_necro7.has("frost_bolt") and dual_necro7.has("bone_dart") and dual_necro7.has("deathbolt"), "mage 5/necromancer 7 folds both class kits")
	assert(WIProgression.granted_skills({"runner": 5}, catalog).has("double_step"), "runner L5 grants double_step")
	assert(WIProgression.granted_skills({"necromancer": 5}, catalog).has("animate_dead"), "necromancer L5 grants animate_dead")
	assert(WIProgression.granted_skills({"necromancer": 7}, catalog).has("flash_step"), "necromancer L7 grants flash_step")
	assert(WIProgression.granted_skills({"mage": 11}, catalog).has("flash_step"), "mage L11 grants flash_step")
	assert(WIProgression.granted_skills({"hedge_witch": 5}, catalog).has("hearthward_charm"), "hedge witch L5 grants hearthward_charm")
	assert(WIProgression.granted_skills({"witch": 10}, catalog).has("greater_hearthward"), "witch L10 grants greater_hearthward")
	assert(WIProgression.granted_skills({"cook": 5}, catalog).has("perfect_recall"), "cook L5 grants perfect_recall")

	assert(WIProgression.check_class_gains({}, {}, catalog).is_empty(), "classless + no accomplishments = no gain")
	assert(WIProgression.check_class_gains({}, {"sparred_with_relc": 1}, catalog) == ["warrior"], "met sparred_with_relc gained_by grants warrior")
	assert(WIProgression.check_class_gains({"warrior": 1}, {"sparred_with_relc": 1}, catalog).is_empty(), "already-held warrior is not re-gained")
	assert(WIProgression.check_class_gains({}, {"sparred_with_relc": 0}, catalog).is_empty(), "sparred_with_relc banked but below threshold = no gain")
	var warrior_l1 := WIProgression.granted_skills({"warrior": 1}, catalog)
	assert(warrior_l1 == ["basic_swordwork", "tough_body", "power_strike", "piercing_strikes"], "warrior L1 still grants the full 4-skill kit once earned")

	assert(WIProgression.check_class_gains({"warrior": 1}, {"chess_with_olesm": 1}, catalog) == ["tactician"], "winning Olesm's chess match grants tactician (the class is earned at the board)")
	assert(WIProgression.check_class_gains({"warrior": 1}, {"studied_the_cellar": 1}, catalog).is_empty(), "the cellar study no longer grants tactician (superseded driver)")
	assert(WIProgression.check_class_gains({"warrior": 1, "tactician": 1}, {"studied_the_cellar": 1}, catalog).is_empty(), "already-held tactician is not re-gained")
	assert(WIProgression.check_class_gains({"warrior": 1}, {"studied_the_cellar": 0}, catalog).is_empty(), "studied_the_cellar banked but below threshold = no gain")
	var tactician_l1 := WIProgression.granted_skills({"tactician": 1}, catalog)
	assert(tactician_l1 == ["observe", "battlefield_awareness"], "tactician L1 kit spans field + combat pillars")
	var tac_l2 := WIProgression.check_level_ups({"tactician": 1}, {"observed_things": 3}, catalog)
	assert(tac_l2.size() == 1 and tac_l2[0]["class"] == "tactician" and tac_l2[0]["level"] == 2, "tactician L2 pending on observed_things")
	assert(WIProgression.check_level_ups({"tactician": 1}, {"observed_things": 2}, catalog).is_empty(), "below observed_things threshold = no tactician level")

	assert(WIProgression.check_class_gains({}, {"persuaded_someone": 1}, catalog).is_empty(), "persuasion alone (no gossip volume) does not grant diplomat")
	assert(WIProgression.check_class_gains({}, {"heard_gossip": 5}, catalog).is_empty(), "gossip alone (never persuaded) does not grant diplomat")
	assert(WIProgression.check_class_gains({}, {"persuaded_someone": 1, "heard_gossip": 2}, catalog).is_empty(), "persuaded but below the gossip-3 volume gate = no diplomat")
	assert(WIProgression.check_class_gains({}, {"persuaded_someone": 1, "heard_gossip": 3}, catalog) == ["diplomat"], "both gates met (persuaded>=1 AND gossip>=3) grants diplomat")
	assert(WIProgression.check_class_gains({"diplomat": 1}, {"persuaded_someone": 2, "heard_gossip": 9}, catalog).is_empty(), "already-held diplomat is not re-gained")
	var dip_l1 := WIProgression.granted_skills({"diplomat": 1}, catalog)
	assert(dip_l1 == ["charming_smile", "calming_touch"], "diplomat L1 kit is the 2-skill social kit (field + combat)")
	var dip_l2_gossip := WIProgression.check_level_ups({"diplomat": 1}, {"heard_gossip": 5}, catalog)
	assert(dip_l2_gossip.size() == 1 and dip_l2_gossip[0]["level"] == 2, "diplomat L2 pending on heard_gossip>=5")
	var dip_l2_befriend := WIProgression.check_level_ups({"diplomat": 1}, {"befriended_moments": 2}, catalog)
	assert(dip_l2_befriend.size() == 1 and dip_l2_befriend[0]["level"] == 2, "diplomat L2 ALSO pending on befriended_moments>=2 (requires_any)")
	assert(WIProgression.check_level_ups({"diplomat": 1}, {"heard_gossip": 4, "befriended_moments": 1}, catalog).is_empty(), "below BOTH L2 thresholds = no diplomat level")

	assert(WIProgression.check_level_ups({"warrior": 2}, {"melee_hit": 5}, catalog).is_empty(), "below the L3 melee threshold = no level")
	var w3 := WIProgression.check_level_ups({"warrior": 2}, {"melee_hit": 6}, catalog)
	assert(w3.size() == 1 and w3[0]["class"] == "warrior" and w3[0]["level"] == 3, "warrior L3 from melee_hit 6")
	assert((w3[0]["grants"] as Array) == ["quick_movement"], "L3 grant carried")
	var w_multi := WIProgression.check_level_ups({"warrior": 2}, {"melee_hit": 18}, catalog)
	assert(w_multi.size() == 3, "melee_hit 18 earns THREE levels in one check")
	for i in w_multi.size():
		assert(w_multi[i]["class"] == "warrior" and int(w_multi[i]["level"]) == 3 + i, "levels arrive consecutively ascending")
	assert((w_multi[2]["grants"] as Array) == ["dangersense"], "each level keeps its own grants")
	var w2 := WIProgression.check_level_ups({"warrior": 1}, {"won_combat": 1}, catalog)
	assert(w2.size() == 1 and w2[0]["level"] == 2, "warrior L2 still keys on won_combat")

	var m_multi := WIProgression.check_level_ups({"mage": 1}, {"won_combat": 3, "spell_cast": 8}, catalog)
	assert(m_multi.size() == 3, "mage walks L2 (won_combat) then L3/L4 (spell_cast) in one check")
	assert(int(m_multi[2]["level"]) == 4, "cast-counter walk stops at spell_cast 8 = L4")
	assert(WIProgression.check_level_ups({"mage": 1}, {"spell_cast": 100}, catalog).is_empty(), "an unmet early gate blocks the whole walk (no level skipping)")

	var sw_melee := WIProgression.check_level_ups({"spellsword": 14}, {"melee_hit": 119}, catalog)
	assert(sw_melee.size() == 1 and sw_melee[0]["level"] == 15, "spellsword L15 via the melee arm")
	var sw_spell := WIProgression.check_level_ups({"spellsword": 14}, {"spell_cast": 100}, catalog)
	assert(sw_spell.size() == 1 and sw_spell[0]["level"] == 15, "spellsword L15 via the spell arm")
	assert(WIProgression.check_level_ups({"spellsword": 14}, {"melee_hit": 118, "spell_cast": 99}, catalog).is_empty(), "neither arm met = no level (requires_any is not vacuously true)")
	var sw_mixed := WIProgression.check_level_ups({"spellsword": 14}, {"melee_hit": 119, "spell_cast": 114}, catalog)
	assert(sw_mixed.size() == 2 and int(sw_mixed[1]["level"]) == 16, "each level may be met by a DIFFERENT arm (L15 melee, L16 spell)")
	assert((sw_mixed[0]["grants"] as Array).is_empty(), "spellsword L15 grants nothing (keener_edge migrated to the L14 floor entry)")

	var swordsman10 := WIProgression.granted_skills({"swordsman": 10}, catalog)
	for sk: String in ["basic_swordwork", "tough_body", "power_strike", "piercing_strikes", "counter_strike", "battle_momentum", "quick_movement", "second_wind", "dangersense"]:
		assert(swordsman10.has(sk), "swordsman 10 inherits warrior grant %s" % sk)
	assert(swordsman10.has("quick_slash") and swordsman10.has("flash_cut"), "swordsman 10 keeps its own L10 grants")
	assert(WIProgression.granted_skills({"helper": 2}, catalog).has("basic_repair"),
		"Helper L2 grants Basic Repair")
	assert(not WIProgression.granted_skills({"warrior": 8}, catalog).has("basic_repair"),
		"Warrior L8 no longer grants Basic Repair")
	assert(not swordsman10.has("frost_bolt"), "swordsman does not inherit mage")

	var spellsword14 := WIProgression.granted_skills({"spellsword": 14}, catalog)
	assert(spellsword14.has("basic_swordwork"), "spellsword 14 inherits warrior L1")
	assert(spellsword14.has("frost_bolt") and spellsword14.has("quick_cast") and spellsword14.has("light"), "spellsword 14 inherits mage L1")
	assert(spellsword14.has("keener_edge"), "spellsword 14 keeps its own signature grant (migrated to the floor entry)")

	var cyclic_catalog := {
		"classes": [
			{"id": "a", "inherits": "b", "levels": [{"level": 1, "requires": {}, "grants": ["skill_a"]}]},
			{"id": "b", "inherits": "a", "levels": [{"level": 1, "requires": {}, "grants": ["skill_b"]}]},
		]
	}
	var cyclic := WIProgression.granted_skills({"a": 1}, cyclic_catalog)
	assert(cyclic.size() == 2 and cyclic.has("skill_a") and cyclic.has("skill_b"), "cyclic inherits chain terminates with the finite correct set")

	assert(WIProgression.granted_skills({"warrior": 1}, catalog) == l1, "warrior grants unaffected by inherits resolution")
	assert(WIProgression.granted_skills({"mage": 1}, catalog) == mage_l1, "mage grants unaffected by inherits resolution")

	var warrior_sword := WIProgression.check_evolutions({"warrior": 10}, {"sword_skill_used": 12, "spear_skill_used": 2}, catalog, [])
	assert(warrior_sword.size() == 1, "warrior sword-dominant yields exactly one outcome")
	assert(warrior_sword[0]["class"] == "warrior" and warrior_sword[0]["to"] == "swordsman" and int(warrior_sword[0]["level"]) == 10, "warrior 10 sword-dominant evolves to swordsman at level 10")
	assert(not bool(warrior_sword[0].get("off_interval", false)), "on-schedule (level 10) evolution is not off_interval")

	var warrior_spear := WIProgression.check_evolutions({"warrior": 10}, {"sword_skill_used": 2, "spear_skill_used": 10}, catalog, [])
	assert(warrior_spear.size() == 1 and warrior_spear[0]["to"] == "spearmaster", "warrior 10 spear-dominant evolves to spearmaster")

	var warrior_underuse := WIProgression.check_evolutions({"warrior": 10}, {"sword_skill_used": 5, "spear_skill_used": 5}, catalog, [])
	assert(warrior_underuse.size() == 1 and bool(warrior_underuse[0].get("waiting", false)) and warrior_underuse[0]["class"] == "warrior", "warrior under min_uses waits, no evolution")
	assert(not warrior_underuse[0].has("to") and not bool(warrior_underuse[0].get("generalist", false)), "waiting outcome carries no replacement or generalist grant")

	var warrior_split := WIProgression.check_evolutions({"warrior": 10}, {"sword_skill_used": 7, "spear_skill_used": 7}, catalog, [])
	assert(warrior_split.size() == 1 and bool(warrior_split[0].get("waiting", false)), "warrior below dominance with no balanced_grants waits, never generalizes")

	var mage_ice := WIProgression.check_evolutions({"mage": 10}, {"ice_cast": 13, "fire_cast": 1}, catalog, [])
	assert(mage_ice.size() == 1 and mage_ice[0]["to"] == "ice_mage" and int(mage_ice[0]["level"]) == 10, "mage 10 ice-dominant evolves to ice_mage")

	var mage_split := WIProgression.check_evolutions({"mage": 10}, {"ice_cast": 7, "fire_cast": 7}, catalog, [])
	assert(mage_split.size() == 1 and bool(mage_split[0].get("generalist", false)), "mage below dominance with enough volume takes the generalist path")
	assert(mage_split[0]["class"] == "mage" and (mage_split[0]["grants"] as Array) == ["ice_shard", "flare_burst"], "generalist grant carries balanced_grants verbatim")
	assert(not WIProgression.granted_skills({"mage": 10}, catalog).has("ice_shard"), "pre-generalist mage 10 kit excludes balanced_grants")
	var gen_kit := WIProgression.granted_skills({"mage": 10}, catalog, ["mage"])
	assert(gen_kit.has("ice_shard") and gen_kit.has("flare_burst"), "a generalist mage fields its balanced_grants in the granted kit")
	var mage_subdom := WIProgression.check_evolutions({"mage": 10}, {"ice_cast": 8, "fire_cast": 6}, catalog, [])
	assert(mage_subdom.size() == 1 and bool(mage_subdom[0].get("generalist", false)), "below dominance without a tie still generalizes (share 0.57 < 0.6)")

	var mage_locked := WIProgression.check_evolutions({"mage": 10}, {"ice_cast": 13, "fire_cast": 1}, catalog, ["mage"])
	assert(mage_locked.is_empty(), "generalist-locked mage is never re-evolved, even when dominant")

	var runner_courier := WIProgression.check_evolutions({"runner": 10}, {"completed_delivery": 36}, catalog, [])
	assert(runner_courier.size() == 1 and runner_courier[0]["to"] == "courier" and int(runner_courier[0]["level"]) == 10, "runner evolves to courier at the level-10 floor")
	assert(WIProgression.granted_skills({"courier": 10}, catalog).has("enhanced_movement"), "courier floor kit inherits runner and adds enhanced_movement")
	var hedge_witch := WIProgression.check_evolutions({"hedge_witch": 10}, {"witch_craft_used": 36}, catalog, [])
	assert(hedge_witch.size() == 1 and hedge_witch[0]["to"] == "witch", "hedge witch evolves to witch")
	assert(WIProgression.granted_skills({"witch": 10}, catalog).has("evil_eye"), "witch floor kit inherits hedge witch combat grant")
	var cook_chef := WIProgression.check_evolutions({"cook": 10}, {"cooked_meal": 68}, catalog, [])
	assert(cook_chef.size() == 1 and cook_chef[0]["to"] == "chef", "cook evolves to chef")
	assert(WIProgression.granted_skills({"chef": 10}, catalog).has("signature_dish"), "chef floor kit adds signature_dish")

	var warrior_off_interval := WIProgression.check_evolutions({"warrior": 12}, {"sword_skill_used": 12, "spear_skill_used": 2}, catalog, [])
	assert(warrior_off_interval.size() == 1 and bool(warrior_off_interval[0].get("off_interval", false)), "evolution resolved at level 12 carries off_interval")
	var warrior_on_interval := WIProgression.check_evolutions({"warrior": 11}, {"sword_skill_used": 12, "spear_skill_used": 2}, catalog, [])
	assert(not bool(warrior_on_interval[0].get("off_interval", false)), "evolution resolved at level 11 is not off_interval")

	assert(WIProgression.check_evolutions({"warrior": 9}, {"sword_skill_used": 50, "spear_skill_used": 1}, catalog, []).is_empty(), "below at_level: not considered, no outcome")

	assert(WIProgression.check_evolutions({"swordsman": 2}, {}, catalog, []).is_empty(), "classes without an evolution block never produce an outcome")

	assert(WIProgression.check_evolutions({"ice_mage": 12}, {"ice_cast": 100, "fire_cast": 100}, catalog, []).is_empty(), "an evolved/inherited class has no evolution block, never re-evolves")

	var evo_events: Array = []
	var sink := func(type: String, payload: Dictionary) -> void:
		evo_events.append({"type": type, "payload": payload})
	var scene_cfg: Dictionary = WISceneCatalog.compose()
	var skill_cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills.json"))
	var game := WIGame.new(scene_cfg, skill_cfg, sink, 42, {"classes": catalog})
	game.classes = {"warrior": 10}
	game.accomplishments = {"sword_skill_used": 12, "spear_skill_used": 2}
	game.sleep()
	var level_up_events := evo_events.filter(func(e: Dictionary) -> bool: return e["type"] == WIEvents.CLASS_LEVEL_UP)
	assert(level_up_events.is_empty(), "no level-ups occur this sleep (precondition for proving the restructure)")
	var evolved_events := evo_events.filter(func(e: Dictionary) -> bool: return e["type"] == WIEvents.CLASS_EVOLVED)
	assert(evolved_events.size() == 1, "sleep() with zero level-ups still resolves and emits class_evolved")
	assert(String(evolved_events[0]["payload"]["from"]) == "warrior" and String(evolved_events[0]["payload"]["to"]) == "swordsman", "sleep() evolves warrior into swordsman via check_evolutions")
	assert(int(evolved_events[0]["payload"]["level"]) == 10, "evolution carries the class's current level")
	assert(game.classes.has("swordsman") and int(game.classes["swordsman"]) == 10, "sleep() applies the replacement to the live classes dict")
	assert(not game.classes.has("warrior"), "the old class id is erased on evolution")
	var toast_events := evo_events.filter(func(e: Dictionary) -> bool: return e["type"] == WIEvents.TOAST)
	assert(not toast_events.is_empty(), "sleep() emits at least one toast for the evolution")
	for t: Dictionary in toast_events:
		var text := String(t["payload"]["text"])
		assert(not text.is_empty(), "toast text is non-empty")

	var split_power := WIProgression.effective_power({"warrior": 5, "mage": 5}, catalog)
	var pure_power := WIProgression.effective_power({"warrior": 10}, catalog)
	var ratio := split_power / pure_power
	assert(ratio >= 0.75 and ratio <= 0.80, "5/5 split lands in the locked 0.75-0.80 friction band (got %f)" % ratio)

	assert(WIProgression.effective_power({"warrior": 5}, catalog) < WIProgression.effective_power({"warrior": 6}, catalog), "adding a level raises effective_power")
	assert(split_power > WIProgression.effective_power({"warrior": 5}, catalog), "5/5 split has higher total effective_power than pure-5")
	assert(WIProgression.power_multiplier({"warrior": 5, "mage": 5}, catalog) < WIProgression.power_multiplier({"warrior": 5}, catalog), "split multiplier is lower than a focused build's")

	assert(WIProgression.power_multiplier({"warrior": 10}, catalog) == 1.0, "focused warrior 10 multiplier is exactly 1.0")
	assert(WIProgression.power_multiplier({"warrior": 2}, catalog) == 1.0, "focused warrior 2 multiplier is exactly 1.0")

	assert(WIProgression.power_multiplier({"warrior": 5, "mage": 5}, catalog) < 1.0, "warrior5/mage5 split incurs a penalty")
	assert(WIProgression.power_multiplier({"warrior": 2, "mage": 2}, catalog) < 1.0, "warrior2/mage2 split incurs a penalty")

	assert(WIProgression.effective_power({}, catalog) == 0.0, "empty classes yields effective_power 0.0")
	assert(WIProgression.power_multiplier({}, catalog) == 1.0, "empty classes yields multiplier 1.0 (no penalty, no crash)")


	var warrior10_bonus := WIProgression.derived_stat_bonuses({"warrior": 10}, catalog)
	assert(int(warrior10_bonus.get("str", 0)) == 10, "focused warrior 10 grants +10 str")
	assert(int(warrior10_bonus.get("con", 0)) == 10, "focused warrior 10 grants +10 con")
	assert(int(warrior10_bonus.get("dex", 0)) == 0, "focused warrior 10 grants 0 dex")
	assert(int(warrior10_bonus.get("int", 0)) == 0, "focused warrior 10 grants 0 int")

	var warrior2_bonus := WIProgression.derived_stat_bonuses({"warrior": 2}, catalog)
	assert(int(warrior2_bonus.get("str", 0)) == 2, "focused warrior 2 grants +2 str")
	assert(int(warrior2_bonus.get("con", 0)) == 2, "focused warrior 2 grants +2 con")

	var split_bonus := WIProgression.derived_stat_bonuses({"warrior": 5, "mage": 5}, catalog)
	assert(int(split_bonus.get("str", 0)) == 4, "5/5 split grants +4 str (scaled by split-efficiency)")
	assert(int(split_bonus.get("con", 0)) == 4, "5/5 split grants +4 con (scaled by split-efficiency)")
	assert(int(split_bonus.get("int", 0)) == 4, "5/5 split grants +4 int (scaled by split-efficiency)")
	assert(int(split_bonus.get("dex", 0)) == 0, "5/5 split grants 0 dex (neither class touches dex)")

	var empty_bonus := WIProgression.derived_stat_bonuses({}, catalog)
	for stat_key: String in ["str", "dex", "con", "int"]:
		assert(int(empty_bonus.get(stat_key, 0)) == 0, "empty classes yields zero bonus for %s" % stat_key)

	var no_growth_catalog := {
		"meta": {"power_k": 1.55},
		"classes": [{"id": "blank", "levels": [{"level": 1, "requires": {}, "grants": []}]}],
	}
	var blank_bonus := WIProgression.derived_stat_bonuses({"blank": 5}, no_growth_catalog)
	for stat_key: String in ["str", "dex", "con", "int"]:
		assert(int(blank_bonus.get(stat_key, 0)) == 0, "class with no stat_growth contributes zero for %s" % stat_key)

	var base_stats := {"str": 10, "dex": 10, "con": 10, "int": 10}
	var applied := WIProgression.apply_stat_bonuses(base_stats, {"warrior": 10}, catalog)
	assert(int(applied["str"]) == 20 and int(applied["con"]) == 20, "apply_stat_bonuses adds bonus to base stat")
	assert(int(applied["dex"]) == 10 and int(applied["int"]) == 10, "apply_stat_bonuses leaves untouched stats as base")
	assert(int(base_stats["str"]) == 10, "apply_stat_bonuses does not mutate the input dictionary")

	var offer_11_10 := WIProgression.check_consolidation({"warrior": 11, "mage": 10}, catalog)
	assert(not offer_11_10.is_empty(), "warrior 11 / mage 10 both meet the new trigger (the near_consolidation fixture's own shape)")
	assert((offer_11_10["parents"] as Array) == ["warrior", "mage"], "parents reported in catalog order")
	assert(offer_11_10["target"] == "spellsword", "target is spellsword")
	assert(int(offer_11_10["level"]) == 14, "(11,10) -> 14 (the new floor)")

	assert(int(WIProgression.check_consolidation({"warrior": 10, "mage": 11}, catalog)["level"]) == 14, "(10,11) -> 14, the same total split the other way")
	assert(int(WIProgression.check_consolidation({"warrior": 25, "mage": 10}, catalog)["level"]) == 25, "(25,10) -> 25 (max() clamp, never drops below the higher parent: two_thirds=24 < 25)")

	assert(WIProgression.check_consolidation({"warrior": 9, "mage": 12}, catalog).is_empty(), "one parent below min_parent_level (10) -> no offer")
	assert(WIProgression.check_consolidation({"warrior": 10, "mage": 10}, catalog).is_empty(), "both parents at min_parent_level but sum 20 < 21 -> no offer")
	assert(not WIProgression.check_consolidation({"warrior": 10, "mage": 11}, catalog).is_empty(), "both >=10 and sum ==21 -> offer fires (boundary inclusive)")

	assert(WIProgression.check_consolidation({"warrior": 12}, catalog).is_empty(), "only one parent line held -> no offer")
	assert(WIProgression.check_consolidation({}, catalog).is_empty(), "no classes held -> no offer")

	assert(WIProgression.check_consolidation({"spellsword": 14}, catalog).is_empty(), "holding only the target class -> no offer (no parent lines held)")

	var evolved_offer := WIProgression.check_consolidation({"swordsman": 11, "ice_mage": 10}, catalog)
	assert(not evolved_offer.is_empty(), "evolved parents (swordsman + ice_mage) still trigger the offer")
	assert((evolved_offer["parents"] as Array) == ["swordsman", "ice_mage"], "parents reported by their HELD (evolved) ids, not the base line id")
	assert(evolved_offer["target"] == "spellsword", "evolved parents still target spellsword")
	assert(int(evolved_offer["level"]) == 14, "evolved-parent math uses the SAME formula (11,10) -> 14")

	var mixed_evolved := WIProgression.check_consolidation({"spearmaster": 11, "fire_mage": 10}, catalog)
	assert(not mixed_evolved.is_empty() and int(mixed_evolved["level"]) == 14, "spearmaster + fire_mage (11,10) -> 14")

	var same_line := WIProgression.check_consolidation({"warrior": 3, "swordsman": 11, "mage": 12}, catalog)
	assert(not same_line.is_empty(), "the higher-level candidate (swordsman 11) qualifies even though warrior 3 (same line, sub-threshold) is also held")
	assert((same_line["parents"] as Array) == ["swordsman", "mage"], "the best (highest-level) candidate per line is reported, not the first-listed id")

	var scout_offer := WIProgression.check_consolidation({"rogue": 10, "archer": 11}, catalog)
	assert(not scout_offer.is_empty() and scout_offer["target"] == "scout", "rogue and archer lines offer scout consolidation")
	assert((scout_offer["parents"] as Array) == ["rogue", "archer"], "scout offer reports held parents in catalog order")
	assert(int(scout_offer["level"]) == 14, "scout consolidation floor derives to 14 from the shared 10/21 gate")
	assert(WIProgression.check_consolidation({"rogue": 10, "archer": 10}, catalog).is_empty(), "scout does not offer below combined level 21")
	var evolved_scout_offer := WIProgression.check_consolidation({"infiltrator": 10, "sharpshooter": 11}, catalog)
	assert(not evolved_scout_offer.is_empty() and evolved_scout_offer["target"] == "scout" and int(evolved_scout_offer["level"]) == 14, "evolved rogue/archer parents preserve scout floor")
	assert(WIProgression.granted_skills({"scout": 14}, catalog).has("eagle_eyes"), "scout floor kit grants eagle_eyes")

	var post_consolidation := WIProgression.check_class_gains(
		{"spellsword": 14},
		{"sparred_with_relc": 5, "learned_magic_from_pisces": 5},
		catalog)
	assert(not post_consolidation.has("warrior") and not post_consolidation.has("mage"),
		"held spellsword retires BOTH parent lines from re-acquisition")
	var post_evolution := WIProgression.check_class_gains(
		{"swordsman": 10},
		{"sparred_with_relc": 5},
		catalog)
	assert(not post_evolution.has("warrior"),
		"held swordsman (warrior's evolution target) retires warrior from re-acquisition")
	assert(WIProgression.check_class_gains({}, {"sparred_with_relc": 5}, catalog).has("warrior"),
		"retire rule leaves normal first-acquisition untouched")

	# Issue #163: rank derivation, boundaries DERIVED from effective_power's own
	# math (never hardcoded level ints). A single L10 line's power == 10.0 by
	# construction ((10^k)^(1/k)); a two-L10-line build (the "14-equivalent
	# consolidation": max(ceil(2*(10+10)/3),10)==14) has power 10*2^(1/k)~=15.64.
	var k := float(catalog["meta"]["power_k"])
	var silver_floor := WIProgression.silver_power_floor(catalog)
	var gold_floor := WIProgression.gold_power_floor(catalog)
	assert(is_equal_approx(silver_floor, 10.0), "silver floor == single L10 line power (10.0)")
	assert(is_equal_approx(gold_floor, 10.0 * pow(2.0, 1.0 / k)), "gold floor == two-L10-line power (10*2^(1/k))")
	assert(gold_floor > 15.0 and gold_floor < 16.0, "gold floor lands ~15.64 at k=1.55")
	# Bronze below silver floor; both EDGES of each band pinned.
	assert(WIProgression.power_rank({}, catalog) == "bronze", "classless == bronze")
	assert(WIProgression.power_rank({"warrior": 9}, catalog) == "bronze", "L9 single line just under silver floor == bronze")
	assert(WIProgression.power_rank({"swordsman": 10}, catalog) == "silver", "L10 single line == silver (silver floor is inclusive)")
	assert(WIProgression.power_rank({"swordsman": 14}, catalog) == "silver", "L14 single line (power 14.0) still under gold floor == silver")
	assert(WIProgression.power_rank({"spellsword": 15}, catalog) == "silver", "L15 single line (15.0 < 15.64) == silver")
	assert(WIProgression.power_rank({"spellsword": 16}, catalog) == "gold", "L16 single line (16.0 >= gold floor) == gold")
	# The literal "14-equivalent consolidation" build lands exactly on the gold
	# floor -> gold (inclusive edge).
	assert(WIProgression.power_rank({"warrior": 10, "mage": 10}, catalog) == "gold", "two L10 lines == gold (the consolidation-tier build IS the gold floor)")

	# GH#211 challenge-weight math (WICombatBanking statics; behavioral
	# integration = the pace harness + canonical byte-diffs).
	var cw_cfg := {"weight_gamma": 1.6, "weight_floor": 0.0, "weight_cap": 2.0, "gray_ratio": 0.55, "gray_scale": 0.15, "decay_rate": 0.9}
	assert(is_equal_approx(WICombatBanking.challenge_weight(cw_cfg, 10.0, 10.0), 1.0), "par ratio weighs 1.0")
	assert(is_equal_approx(WICombatBanking.challenge_weight(cw_cfg, 10.0, 0.0), 1.0), "unknown enemy power (0) is NEUTRAL 1.0 — rollout-safe")
	assert(WICombatBanking.challenge_weight(cw_cfg, 10.0, 20.0) == 2.0, "double-power enemy hits the 2.0 cap")
	var gray := WICombatBanking.challenge_weight(cw_cfg, 20.0, 10.0)
	assert(gray < 0.06, "half-power enemy grays out (pow(0.5,1.6)*0.15 ~= 0.05), got %f" % gray)
	assert(WICombatBanking.challenge_weight(cw_cfg, 0.0, 5.0) >= 2.0 - 0.001, "classless player vs real enemy clamps at cap (player_power floors at 1)")
	assert(is_equal_approx(WICombatBanking.repetition_decay(cw_cfg, 0), 1.0), "first win decays nothing")
	var d10 := WICombatBanking.repetition_decay(cw_cfg, 10)
	var d100 := WICombatBanking.repetition_decay(cw_cfg, 100)
	assert(d10 < 0.35 and d10 > 0.25, "win #11 decays to ~0.32, got %f" % d10)
	assert(d100 < 0.2, "win #101 is needle-immovable (<0.2), got %f" % d100)
	assert(d100 < d10 and d10 < 1.0, "decay is monotone")

	print("PASS: progression checks behave correctly")
	quit(0)
