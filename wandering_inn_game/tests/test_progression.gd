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
	
	# #453 G2 (user ruling 2026-08-13): [Rogue] entry is `accomplishment_any`.
	# Three arms, same discipline as the requires_any pins below: old path alone,
	# new path alone, neither. The third arm uses `sneaked_past_danger` on purpose
	# -- it is the counter the C3 proposal named, and the one that CANNOT gate
	# this entry (it banks only while already sneaking, and no class grants a
	# sneak before [Rogue] does), so this line pins the circularity out.
	assert(WIProgression.check_class_gains({}, {"recovered_crate_watch": 1}, catalog).has("rogue"), "OLD PATH ONLY: the Liscor crate job still earns [Rogue]")
	assert(WIProgression.check_class_gains({}, {"crossed_under_cover": 1}, catalog).has("rogue"), "NEW PATH ONLY: one crossing under cover earns [Rogue] in Act I")
	assert(not WIProgression.check_class_gains({}, {"sneaked_past_danger": 99, "took_the_low_road": 99}, catalog).has("rogue"), "NEITHER arm met = no [Rogue]: neither sneaking itself nor merely entering the cut is the gate")
	assert(WIProgression.check_class_gains({"rogue": 1}, {"crossed_under_cover": 5}, catalog).is_empty(), "already-held rogue is not re-gained through the new arm")
	assert(WIProgression.check_class_gains({"warrior": 1}, {"studied_the_cellar": 0}, catalog).is_empty(), "studied_the_cellar banked but below threshold = no gain")
	var tactician_l1 := WIProgression.granted_skills({"tactician": 1}, catalog)
	assert(tactician_l1 == ["observe", "battlefield_awareness"], "tactician L1 kit spans field + combat pillars")
	var tac_l2 := WIProgression.check_level_ups({"tactician": 1}, {"observed_things": 3}, catalog)
	assert(tac_l2.size() == 1 and tac_l2[0]["class"] == "tactician" and tac_l2[0]["level"] == 2, "tactician L2 pending on observed_things")
	assert(WIProgression.check_level_ups({"tactician": 1}, {"observed_things": 2}, catalog).is_empty(), "below observed_things threshold = no tactician level")
	assert(WIProgression.check_level_ups({"tactician": 5}, {"observed_things": 20, "tactic_used": 3}, catalog).is_empty(), "tactician L6 needs both appraisal and landed tactics")
	var tac_l6 := WIProgression.check_level_ups({"tactician": 5}, {"observed_things": 20, "tactic_used": 4}, catalog)
	assert(tac_l6.size() == 1 and int(tac_l6[0]["level"]) == 6, "tactician L6 clears at observed 20 + tactic 4")
	# #453 G3 (user ruling 2026-08-13): the ladder WIDENS before it steepens --
	# [Flanking Step] moved L7 -> L6. Pinned in both directions so a revert reds.
	assert((tac_l6[0]["grants"] as Array) == ["flanking_step"], "tactician L6 now carries [Flanking Step]")
	assert(WIProgression.granted_skills({"tactician": 6}, catalog).has("flanking_step"), "a L6 tactician holds [Flanking Step] -- three tactic-family Skills from L6 on")
	assert(not WIProgression.granted_skills({"tactician": 5}, catalog).has("flanking_step"), "L5 does not: the rung moved down one, it did not move to the floor")
	assert(WIProgression.granted_skills({"diplomat": 5}, catalog).has("observe"), "diplomat L5 shares Appraise Foe without moving soothing_presence")

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
	# #453 G1 RE-ADJUDICATION (user ruling 2026-08-13). This line USED to read
	# `mage 1 + spell_cast 100 -> empty` and prove no-level-skipping off mage L2's
	# won_combat wall. That wall is now a requires_any arm, so the case it tested
	# is no longer a blocked walk -- it is G1's whole point. The PRINCIPLE is
	# unchanged and stays pinned, re-pointed at [Archer], whose L2 is still a
	# plain AND gate on a DIFFERENT counter than its L3+ curve reads.
	assert(WIProgression.check_level_ups({"archer": 1}, {"ranged_hit": 100}, catalog).is_empty(), "an unmet early gate blocks the whole walk (no level skipping): archer L2 wants won_combat, so a bottomless ranged_hit bank earns nothing")
	
	# #453 G1: mage L2 is `requires_any {won_combat 3, spell_cast 4}`. All three
	# arms pinned -- old path alone, new path alone, and neither -- so a revert to
	# `requires` reds the second and a widening to a vacuous gate reds the third.
	var m_martial := WIProgression.check_level_ups({"mage": 1}, {"won_combat": 3}, catalog)
	assert(m_martial.size() == 1 and int(m_martial[0]["level"]) == 2, "OLD PATH ONLY: three wins still earns mage L2 with zero spells cast")
	var m_caster := WIProgression.check_level_ups({"mage": 1}, {"spell_cast": 4}, catalog)
	assert(m_caster.size() == 2 and int(m_caster[0]["level"]) == 2 and int(m_caster[1]["level"]) == 3, "NEW PATH ONLY: four casts and no wins earns L2, and L3 with it (L3 reuses the same threshold)")
	assert(WIProgression.check_level_ups({"mage": 1}, {"won_combat": 2, "spell_cast": 3}, catalog).is_empty(), "NEITHER arm met = no mage level (requires_any is not vacuously true)")

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

	# #472 audit FAIL 1 REPLACED THESE TWO PINS. They asserted that EVOLVED
	# parents merge through the broad lines -- and under automatic consolidation
	# that is precisely the Skill loss the ruling forbids (swordsman+ice_mage
	# became [Spellsword], quietly dropping four sword grants and three ice
	# ones). The evolved pairs now wait for their own authored targets; the
	# narrowed live surface is pinned immediately below.
	# #449 ORDER CONTRACT, still gated: the evolved SPEAR lineage reaches its own
	# class and never [Spellsword], and the base pair still reaches [Spellsword].
	var spear_lineage := WIProgression.check_consolidation({"spearmaster": 11, "mage": 10}, catalog)
	assert(spear_lineage["target"] == "spellspear", "#449: an EVOLVED spear parent targets its OWN class -- the spellspear row must stay above spellsword's")
	assert(int(spear_lineage["level"]) == 14, "the evolved lineage uses the SAME merge formula (11,10) -> 14")
	assert(String(WIProgression.check_consolidation({"warrior": 11, "mage": 10}, catalog)["target"]) == "spellsword", "#449 the other direction: the BASE warrior pair still reaches [Spellsword]")

	# --- #472 audit FAIL 1: THE NARROWED LIVE SURFACE. Consolidation is
	# automatic, so a row may only fire pairs whose no-Skill-loss is PROVEN.
	# Every live row was narrowed to exactly the pair its target `inherits`;
	# these pins are what stops a future widening from silently re-opening it. ---
	assert(WIProgression.check_consolidation({"warrior": 11, "ice_mage": 10}, catalog).is_empty(), "warrior + ice_mage merges NOTHING: [Spellsword] does not inherit ice_mage, so the merge would drop [Ice Shard]/[Ice Wall]/[Icy Floor] -- the audit's own repro")
	assert(WIProgression.check_consolidation({"warrior": 11, "fire_mage": 10}, catalog).is_empty(), "warrior + fire_mage likewise loses the whole flame kit -- no merge")
	assert(WIProgression.check_consolidation({"swordsman": 14, "mage": 10}, catalog).is_empty(), "an EVOLVED martial parent has its own kit ([Crescent Cut] etc.) that [Spellsword] never inherits -- it waits for its own target, it does not merge lossily")
	assert(WIProgression.check_consolidation({"spearmaster": 11, "ice_mage": 10}, catalog).is_empty(), "the same rule binds the evolved-lineage row: [Spellspear] inherits mage, not ice_mage")
	# NOTE (#438): beast_master + mage and spearmaster + archer used to be pinned
	# HERE, as two more evolved pairs that merge NOTHING. Both now have authored
	# targets ([Wild Sage], [Skirmisher]) and are pinned as live merges in the
	# #438 block further down -- the pair left this list by being SOLVED, which
	# is the only legal way out of it.
	assert(WIProgression.check_consolidation({"infiltrator": 12, "archer": 10}, catalog).is_empty(), "[Infiltrator]'s [Shadowstep] is not in [Scout]'s inherits -- no merge")
	assert(WIProgression.check_consolidation({"barmaid": 12, "diplomat": 10}, catalog).is_empty(), "[Barmaid]'s service kit is not in [Innkeeper]'s inherits -- no merge")
	# ...and the four proven pairs still merge, at the same derived floors.
	assert(String(WIProgression.check_consolidation({"warrior": 11, "mage": 10}, catalog).get("target", "")) == "spellsword", "the PROVEN warrior+mage pair still merges")
	assert(String(WIProgression.check_consolidation({"rogue": 11, "archer": 10}, catalog).get("target", "")) == "scout", "rogue+archer still merges")
	assert(String(WIProgression.check_consolidation({"helper": 11, "diplomat": 10}, catalog).get("target", "")) == "innkeeper", "helper+diplomat still merges")
	assert(String(WIProgression.check_consolidation({"warrior": 11, "archer": 10}, catalog).get("target", "")) == "ranger", "warrior+archer still merges")

	# --- #438 THE THREE 2026-08-13 CONSOLIDATION FAMILIES, and the ORDER
	# CONTRACT each rests on. User ruling (docs/CHOICE-LOG.md): [Wild Sage] and
	# [Skirmisher] are the two authored targets that reduce family reuse, and
	# [Necromancer] becomes consolidation-eligible via [Deathknight].
	# EVERY PIN IS DOUBLE-ENDED: the new pair reaches the NEW target, AND the
	# baseline's own unevolved pair still reaches the BASELINE. A single-ended
	# pin would pass just as happily with the new row swallowing its baseline's
	# traffic, which is the failure that only surfaces in a playtest.
	var sage_merge := WIProgression.check_consolidation({"beast_master": 11, "mage": 10}, catalog)
	assert(String(sage_merge.get("target", "")) == "wild_sage", "#438: an EVOLVED [Beast Master] merges into its OWN class -- the wild_sage row must stay ABOVE druid's, whose `[beast_tamer]` line's evolution closure lists beast_master")
	assert(int(sage_merge.get("level", 0)) == 14, "same merge formula, no bespoke gate: (11,10) -> max(ceil(2*21/3), 11) == 14")
	assert(String(WIProgression.check_consolidation({"beast_tamer": 11, "mage": 10}, catalog).get("target", "")) == "druid", "#438 the other direction: the UNEVOLVED tamer pair still reaches [Druid] -- the new row must not swallow the case it does not own")

	var skirm_merge := WIProgression.check_consolidation({"spearmaster": 11, "archer": 10}, catalog)
	assert(String(skirm_merge.get("target", "")) == "skirmisher", "#438: spearmaster + archer reaches [Skirmisher] -- the row must stay ABOVE ranger's, whose `[warrior]` line's evolution closure lists spearmaster")
	assert(int(skirm_merge.get("level", 0)) == 14, "(11,10) -> 14, the same formula every family uses")
	assert(String(WIProgression.check_consolidation({"warrior": 11, "archer": 10}, catalog).get("target", "")) == "ranger", "#438 the other direction: the BASE warrior pair still reaches [Ranger]")

	var dk_merge := WIProgression.check_consolidation({"warrior": 11, "necromancer": 10}, catalog)
	assert(String(dk_merge.get("target", "")) == "deathknight", "#438: warrior + necromancer reaches [Deathknight], the row placed ABOVE spellsword's (same line_a)")
	assert(int(dk_merge.get("level", 0)) == 14, "(11,10) -> 14")
	assert(String(WIProgression.check_consolidation({"warrior": 11, "mage": 10}, catalog).get("target", "")) == "spellsword", "#438 the other direction: warrior + mage is untouched by the row now sitting above it")

	# THE CAP IS THE POINT. [Necromancer]'s table stops at 12 with no evolution,
	# so this merge is the only rung the class has above it: the FLOOR of the
	# consolidation already clears the cap, and a maxed pair clears it by four.
	assert(int(WIProgression.check_consolidation({"warrior": 10, "necromancer": 11}, catalog).get("level", 0)) == 14, "the CHEAPEST legal pair (10,11) already lands at 14 -- two levels past [Necromancer]'s own ceiling")
	assert(int(WIProgression.check_consolidation({"warrior": 12, "necromancer": 12}, catalog).get("level", 0)) == 16, "a MAXED pair lands at max(ceil(2*24/3), 12) == 16, the top of the reachable range")
	assert(WIProgression.check_consolidation({"warrior": 10, "necromancer": 10}, catalog).is_empty(), "both at min_parent_level but sum 20 < 21 -> no merge, the same boundary every family shares")

	# THE NARROWED SURFACE HOLDS FOR THE NEW ROWS TOO: each lists exactly the
	# pair its target `inherits`, so the evolved siblings still wait for their
	# own targets rather than merging lossily into these.
	assert(WIProgression.check_consolidation({"beast_master": 11, "ice_mage": 10}, catalog).is_empty(), "[Wild Sage] inherits mage, not ice_mage -- the elemental sibling does not merge here")
	assert(WIProgression.check_consolidation({"spearmaster": 11, "sharpshooter": 10}, catalog).is_empty(), "[Skirmisher] inherits archer, not sharpshooter")
	assert(WIProgression.check_consolidation({"swordsman": 11, "necromancer": 10}, catalog).is_empty(), "[Deathknight] inherits warrior, not swordsman -- the APPROVED-REUSE pair is still `_exempt` pending its coverage authoring, and until then it must not fire lossily")
	assert(WIProgression.check_consolidation({"spearmaster": 11, "necromancer": 10}, catalog).is_empty(), "spear-owns-its-hybrids: the spear line waits for its own target rather than reusing the sword-shaped one")

	# CHAINED-CONSOLIDATION PROBE (#438). Three new consolidated classes means
	# three new lineage PROXIES, so the question the #472 machinery raises is
	# whether any chain now fires on shipped data. It does NOT, and these pins
	# are why: a proxy is only ever a CANDIDATE, and `_merge_proven` demands the
	# target inherit EXACTLY the substituted pair. [Deathknight] inherits
	# {warrior, necromancer}, never {spellsword, necromancer}, so [Spellsword]
	# proxying the warrior line reaches its row and is refused there.
	assert(WIProgression.check_consolidation({"spellsword": 16, "necromancer": 10}, catalog).is_empty(), "#438 chain probe: [Spellsword] proxies deathknight's `[warrior]` line, but deathknight inherits {warrior, necromancer} -- the substitution is NOT proven and nothing fires")
	assert(WIProgression.check_consolidation({"deathknight": 16, "mage": 10}, catalog).is_empty(), "the reverse chain: [Deathknight] proxies spellsword's `[warrior]` line, but spellsword inherits {warrior, mage} -- refused, and a merge would have dropped the whole necromancy kit")
	assert(WIProgression.check_consolidation({"deathknight": 16, "archer": 10}, catalog).is_empty(), "and into [Ranger]'s row on the same line -- refused for the same reason")
	assert(WIProgression.check_consolidation({"skirmisher": 16, "mage": 10}, catalog).is_empty(), "[Skirmisher] proxies spellspear's `[spearmaster]` line; spellspear inherits {spearmaster, mage} -- refused")
	assert(WIProgression.check_consolidation({"wild_sage": 16, "beast_tamer": 10}, catalog).is_empty(), "[Wild Sage] against druid's row -- refused, and `_pair_holdable` aside, druid inherits {beast_tamer, mage}")
	assert(WIProgression.check_consolidation({"warrior": 16, "skirmisher": 10}, catalog).is_empty(), "[Skirmisher] proxying ranger's `[archer]` line is refused too -- the proxy direction is not the escape hatch")

	# --- #472 3, LINEAGE PROXY. A held consolidated class stands in for either
	# parent line its OWN row consumed, at its CURRENT level -- but ONLY where
	# the chained merge is itself proven. Nothing inherits {spellsword, archer}
	# today, so no chain fires on shipped data; the machinery is proved on a
	# synthetic catalog that DOES author the chained target, and lights up for
	# real the moment such a class lands. ---
	assert(WIProgression.check_consolidation({"spellsword": 16, "archer": 10}, catalog).is_empty(), "a chained pair with no authored target does NOT fire -- [Ranger] inherits warrior+archer and would drop the whole mage half of [Spellsword]")
	assert(WIProgression.check_consolidation({"ranger": 14, "mage": 10}, catalog).is_empty(), "the same chain from the other side: [Spellsword] would drop [Ranger]'s bow kit")
	assert(WIProgression.check_consolidation({"spellsword": 16, "beast_tamer": 10}, catalog).is_empty(), "and on the other line -- [Druid] does not inherit spellsword")

	var chain_catalog := catalog.duplicate(true)
	(chain_catalog["classes"] as Array).append({
		WIKeys.ID: "_chained_target", WIKeys.DISPLAY_NAME: "[Chained]",
		"inherits": ["spellsword", "archer"],
		"levels": [{"level": 18, "grants": []}],
	})
	(chain_catalog["consolidations"] as Array).append({
		"id": "_chained", "target": "_chained_target",
		"parent_lines": [["warrior"], ["archer"]],
		"min_parent_level": 10, "min_combined_level": 21,
	})
	var chained := WIProgression.check_consolidation({"spellsword": 16, "archer": 10}, chain_catalog)
	assert(not chained.is_empty() and String(chained["target"]) == "_chained_target", "3 CHAINING, PROVEN: once a class inherits {spellsword, archer}, [Spellsword] proxies the warrior line it consumed and the chain fires")
	assert((chained["parents"] as Array) == ["spellsword", "archer"], "the second consolidation CONSUMES the consolidated class itself")
	assert(int(chained["level"]) == 18, "the proxy stands in at the CONSOLIDATED class's CURRENT level, not a consumed parent's frozen one: (16,10) -> max(ceil(52/3),16) == 18")
	var chained_higher := WIProgression.check_consolidation({"spellsword": 20, "archer": 10}, chain_catalog)
	assert(int(chained_higher["level"]) == 20, "climbing the consolidated class climbs the lineage with it -- (20,10) -> 20, strictly above the 18 a frozen warrior-11 stand-in would give")

	# CONTAINMENT DIRECTION, unchanged: [Spellsword]'s warrior side must not
	# satisfy [Spellspear]'s narrower `[spearmaster]` line.
	assert(WIProgression.check_consolidation({"spellsword": 16, "mage": 10}, catalog).is_empty(), "a [Spellsword] + re-earned [Mage] matches NO row: it cannot proxy the spearmaster line, and its own row refuses to merge it with itself")

	# SELF-MERGE GUARD. One consolidated class covers BOTH sides of its own row.
	assert(WIProgression.check_consolidation({"spellsword": 16}, catalog).is_empty(), "a class never merges with itself, however many lines it proxies")

	# --- #472 2, the runtime half of the UPGRADE escape hatch. ---
	assert(WIProgression.consolidation_upgrades("spellsword", catalog).is_empty(), "no shipped row registers an upgrades map")
	var upgrade_catalog := catalog.duplicate(true)
	for row: Dictionary in upgrade_catalog["consolidations"]:
		if String(row.get("target", "")) == "spellsword":
			row["upgrades"] = {"power_strike": "keener_edge"}
	assert(WIProgression.consolidation_upgrades("spellsword", upgrade_catalog) == {"power_strike": "keener_edge"}, "an authored upgrades map is read off the consolidations row")
	assert(WIProgression.consolidation_upgrades("ranger", upgrade_catalog).is_empty(), "the map is per-row, never shared across targets")

	# --- #449 EVOLVED-LINEAGE CONSOLIDATION, and the ORDER CONTRACT it rests on.
	# User ruling 2026-08-12 (docs/CHOICE-LOG.md): spearmaster + mage does not
	# lineage-carry into [Spellsword]; it consolidates into [Spellspear].
	# `check_consolidation` returns the FIRST matching row and [Spellsword]'s own
	# warrior line still literally lists `spearmaster`, so the whole ruling hangs
	# on the spellspear row sitting ABOVE the spellsword row in classes.json.
	# THAT is what these assertions gate: a reorder (or a deletion) of that row
	# silently re-routes every spear holder back into [Spellsword], which is
	# invisible in the data and would only surface in a playtest. The paired
	# warrior assertion is the other half -- the new row must NOT swallow the
	# unevolved case it does not own.
	var spear_offer := WIProgression.check_consolidation({"spearmaster": 11, "mage": 10}, catalog)
	assert(not spear_offer.is_empty(), "spearmaster 11 / mage 10 clears the shared 10/21 gate")
	assert(spear_offer["target"] == "spellspear", "the evolved spear line consolidates into [Spellspear], NOT [Spellsword] (#449 ruling); a spellspear row ordered below spellsword reds exactly here")
	assert((spear_offer["parents"] as Array) == ["spearmaster", "mage"], "parents reported by their HELD ids")
	assert(int(spear_offer["level"]) == 14, "same parents math as spellsword: (11,10) -> 14, the sparse table's derived floor")
	assert(WIProgression.check_consolidation({"warrior": 11, "mage": 10}, catalog)["target"] == "spellsword", "the UNEVOLVED warrior line still reaches spellsword -- the new row must not shadow it")
	assert(WIProgression.check_consolidation({"spearmaster": 10, "mage": 10}, catalog).is_empty(), "spellspear inherits the same gate: sum 20 < min_combined_level 21 -> no offer")
	assert(WIProgression.granted_skills({"spellspear": 14}, catalog).has("keener_point"), "spellspear floor kit grants its OWN consolidation skill")
	assert(WIProgression.granted_skills({"spellspear": 14}, catalog).has("pierce_thrust"), "spellspear floor kit inherits the spear lineage's L14 grant")
	assert(WIProgression.granted_skills({"spellspear": 14}, catalog).has("flash_step"), "spellspear floor kit inherits the mage line too (both halves fold, the spellsword precedent)")
	assert(not WIProgression.granted_skills({"spellspear": 14}, catalog).has("keener_edge"), "the twin's baseline skill is NOT granted -- spellspear carries its own id")
	assert(not WIProgression.granted_skills({"spellspear": 14}, catalog).has("spellbound_thrust"), "L16 grant stays behind its level")
	assert(WIProgression.granted_skills({"spellspear": 16}, catalog).has("spellbound_thrust"), "L16 grant lands at 16")

	# #472 audit FAIL 1: this pin used to assert that holding a sub-threshold
	# [Warrior] 3 alongside [Blademaster] 11 merged the BLADEMASTER. It cannot any
	# more -- swordsman is off the live line precisely because [Spellsword]
	# would drop its kit -- and a sub-threshold warrior is no merge either.
	assert(WIProgression.check_consolidation({"warrior": 3, "swordsman": 11, "mage": 12}, catalog).is_empty(), "a sub-threshold base parent plus an evolved sibling merges NOTHING: warrior 3 is below min_parent_level and swordsman is not a proven pair for [Spellsword]")
	# The best-candidate-per-line rule itself is unchanged; it just needs a line
	# with more than one member to be visible, which no shipped row has now.
	var multi_catalog := catalog.duplicate(true)
	for row: Dictionary in (multi_catalog["consolidations"] as Array):
		if String(row.get("target", "")) == "spellsword":
			row["parent_lines"] = [["warrior", "_alt_warrior"], ["mage"]]
	(multi_catalog["classes"] as Array).append({
		WIKeys.ID: "_alt_warrior", WIKeys.DISPLAY_NAME: "[Alt]",
		"inherits": "warrior", "levels": [{"level": 1, "grants": []}],
	})
	var best := WIProgression.check_consolidation({"warrior": 10, "_alt_warrior": 13, "mage": 11}, multi_catalog)
	assert((best["parents"] as Array) == ["_alt_warrior", "mage"], "the best (HIGHEST-level) candidate per line is reported, not the first-listed id")

	var scout_offer := WIProgression.check_consolidation({"rogue": 10, "archer": 11}, catalog)
	assert(not scout_offer.is_empty() and scout_offer["target"] == "scout", "rogue and archer lines offer scout consolidation")
	assert((scout_offer["parents"] as Array) == ["rogue", "archer"], "scout offer reports held parents in catalog order")
	assert(int(scout_offer["level"]) == 14, "scout consolidation floor derives to 14 from the shared 10/21 gate")
	assert(WIProgression.check_consolidation({"rogue": 10, "archer": 10}, catalog).is_empty(), "scout does not offer below combined level 21")
	# #472 audit FAIL 1: the evolved rogue/archer pair used to merge into [Scout]
	# and lose [Shadowstep] + the whole sharpshooter kit with it. It waits for
	# its own target now (lineage completeness tracks it as `_exempt`).
	assert(WIProgression.check_consolidation({"infiltrator": 10, "sharpshooter": 11}, catalog).is_empty(), "evolved rogue/archer parents merge NOTHING -- [Scout] inherits rogue+archer and would drop [Shadowstep], [Blinding Arrow], [Called Shot], [Piercing Volley]")
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
