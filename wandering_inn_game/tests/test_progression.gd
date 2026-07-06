extends SceneTree
## Pure progression tests.
## Run: /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_progression.gd


func _init() -> void:
	WITestWatchdog.arm(self)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/classes.json"))

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

	# --- M3 Task 5: earned multiclass (gained_by) ---
	assert(WIProgression.check_class_gains({"warrior": 1}, {}, catalog).is_empty(), "unmet gained_by yields no gain")
	# Onboarding rev O4: mage.gained_by moved from the retired Dusty Scroll
	# (used_magic) to Pisces' lesson (learned_magic_from_pisces).
	assert(WIProgression.check_class_gains({"warrior": 1}, {"learned_magic_from_pisces": 1}, catalog) == ["mage"], "met gained_by grants mage")
	assert(WIProgression.check_class_gains({"warrior": 1, "mage": 1}, {"learned_magic_from_pisces": 1}, catalog).is_empty(), "already-held class is not re-gained")
	assert(WIProgression.check_class_gains({"warrior": 1}, {"used_magic": 1}, catalog).is_empty(), "retired scroll accomplishment no longer grants mage")
	assert(WIProgression.check_class_gains({"warrior": 1}, {"won_combat": 5}, catalog).is_empty(), "already-held warrior is skipped regardless of any other accomplishment")
	var mage_l2 := WIProgression.check_level_ups({"mage": 1}, {"won_combat": 3}, catalog)
	assert(mage_l2.size() == 1 and mage_l2[0]["class"] == "mage" and mage_l2[0]["level"] == 2, "mage L2 pending on won_combat")
	assert((mage_l2[0]["grants"] as Array).has("flame_jet") and (mage_l2[0]["grants"] as Array).has("mana_shield"), "mage L2 grants")
	var mage_l1 := WIProgression.granted_skills({"mage": 1}, catalog)
	assert(mage_l1.has("frost_bolt") and mage_l1.has("quick_cast"), "mage L1 grants frost_bolt + quick_cast")

	# --- Onboarding rev Task O1: warrior is EARNED via gained_by (mage precedent shape) ---
	# Classless start means warrior no longer holds by default; the first
	# post-spar sleep (sparred_with_relc>=1, banked by training_yard's
	# trivial relc_spar encounter) is what grants it.
	assert(WIProgression.check_class_gains({}, {}, catalog).is_empty(), "classless + no accomplishments = no gain")
	assert(WIProgression.check_class_gains({}, {"sparred_with_relc": 1}, catalog) == ["warrior"], "met sparred_with_relc gained_by grants warrior")
	assert(WIProgression.check_class_gains({"warrior": 1}, {"sparred_with_relc": 1}, catalog).is_empty(), "already-held warrior is not re-gained")
	assert(WIProgression.check_class_gains({}, {"sparred_with_relc": 0}, catalog).is_empty(), "sparred_with_relc banked but below threshold = no gain")
	var warrior_l1 := WIProgression.granted_skills({"warrior": 1}, catalog)
	assert(warrior_l1 == ["basic_swordwork", "tough_body", "power_strike", "piercing_strikes"], "warrior L1 still grants the full 4-skill kit once earned")

	# --- Three Pillars P3: [Tactician] EARNED via studied_the_cellar (mage precedent) ---
	# The slice's guile path banks studied_the_cellar; the next sleep grants
	# [Tactician], whose L1 kit spans pillars ([Observe] field + [Battlefield
	# Awareness] combat). Levels then climb on observed_things (banked by [Observe]).
	assert(WIProgression.check_class_gains({"warrior": 1}, {"studied_the_cellar": 1}, catalog) == ["tactician"], "met studied_the_cellar gained_by grants tactician")
	assert(WIProgression.check_class_gains({"warrior": 1, "tactician": 1}, {"studied_the_cellar": 1}, catalog).is_empty(), "already-held tactician is not re-gained")
	assert(WIProgression.check_class_gains({"warrior": 1}, {"studied_the_cellar": 0}, catalog).is_empty(), "studied_the_cellar banked but below threshold = no gain")
	var tactician_l1 := WIProgression.granted_skills({"tactician": 1}, catalog)
	assert(tactician_l1 == ["observe", "battlefield_awareness"], "tactician L1 kit spans field + combat pillars")
	var tac_l2 := WIProgression.check_level_ups({"tactician": 1}, {"observed_things": 3}, catalog)
	assert(tac_l2.size() == 1 and tac_l2[0]["class"] == "tactician" and tac_l2[0]["level"] == 2, "tactician L2 pending on observed_things")
	assert(WIProgression.check_level_ups({"tactician": 1}, {"observed_things": 2}, catalog).is_empty(), "below observed_things threshold = no tactician level")

	# --- Social Pillar S3: [Diplomat] EARNED via a MULTI-KEY gained_by ---
	# gained_by = {persuaded_someone:1, heard_gossip:3} — check_class_gains
	# composes multi-key thresholds with AND semantics (every key must clear its
	# threshold), so BOTH the persuasion identity gate AND the gossip volume gate
	# must be met. persuaded_someone is banked by the persuade dialogue options
	# (goblin_parley/watch_crate); heard_gossip by any talk_pool's first-talk bank.
	assert(WIProgression.check_class_gains({}, {"persuaded_someone": 1}, catalog).is_empty(), "persuasion alone (no gossip volume) does not grant diplomat")
	assert(WIProgression.check_class_gains({}, {"heard_gossip": 5}, catalog).is_empty(), "gossip alone (never persuaded) does not grant diplomat")
	assert(WIProgression.check_class_gains({}, {"persuaded_someone": 1, "heard_gossip": 2}, catalog).is_empty(), "persuaded but below the gossip-3 volume gate = no diplomat")
	assert(WIProgression.check_class_gains({}, {"persuaded_someone": 1, "heard_gossip": 3}, catalog) == ["diplomat"], "both gates met (persuaded>=1 AND gossip>=3) grants diplomat")
	assert(WIProgression.check_class_gains({"diplomat": 1}, {"persuaded_someone": 2, "heard_gossip": 9}, catalog).is_empty(), "already-held diplomat is not re-gained")
	var dip_l1 := WIProgression.granted_skills({"diplomat": 1}, catalog)
	assert(dip_l1 == ["charming_smile", "calming_touch"], "diplomat L1 kit is the 2-skill social kit (field + combat)")
	# Levels climb on EITHER social counter (requires_any over heard_gossip /
	# befriended_moments), modest and opaque.
	var dip_l2_gossip := WIProgression.check_level_ups({"diplomat": 1}, {"heard_gossip": 5}, catalog)
	assert(dip_l2_gossip.size() == 1 and dip_l2_gossip[0]["level"] == 2, "diplomat L2 pending on heard_gossip>=5")
	var dip_l2_befriend := WIProgression.check_level_ups({"diplomat": 1}, {"befriended_moments": 2}, catalog)
	assert(dip_l2_befriend.size() == 1 and dip_l2_befriend[0]["level"] == 2, "diplomat L2 ALSO pending on befriended_moments>=2 (requires_any)")
	assert(WIProgression.check_level_ups({"diplomat": 1}, {"heard_gossip": 4, "befriended_moments": 1}, catalog).is_empty(), "below BOTH L2 thresholds = no diplomat level")

	# --- M6 T2: counter-driven leveling (spec §2.2 REV 2) ---
	# Warrior levels from cumulative melee counters; one call returns EVERY
	# earned level in ascending order (multi-level sleeps).
	assert(WIProgression.check_level_ups({"warrior": 2}, {"melee_hit": 5}, catalog).is_empty(), "below the L3 melee threshold = no level")
	var w3 := WIProgression.check_level_ups({"warrior": 2}, {"melee_hit": 6}, catalog)
	assert(w3.size() == 1 and w3[0]["class"] == "warrior" and w3[0]["level"] == 3, "warrior L3 from melee_hit 6")
	assert((w3[0]["grants"] as Array) == ["quick_movement"], "L3 grant carried")
	var w_multi := WIProgression.check_level_ups({"warrior": 2}, {"melee_hit": 18}, catalog)
	assert(w_multi.size() == 3, "melee_hit 18 earns THREE levels in one check")
	for i in w_multi.size():
		assert(w_multi[i]["class"] == "warrior" and int(w_multi[i]["level"]) == 3 + i, "levels arrive consecutively ascending")
	assert((w_multi[2]["grants"] as Array) == ["dangersense"], "each level keeps its own grants")
	# Legacy requires-style still gates the same walk (both requirement styles
	# coexist until T9 unifies content).
	var w2 := WIProgression.check_level_ups({"warrior": 1}, {"won_combat": 1}, catalog)
	assert(w2.size() == 1 and w2[0]["level"] == 2, "warrior L2 still keys on won_combat")

	# Mage levels from cast counters; styles compose across one walk.
	var m_multi := WIProgression.check_level_ups({"mage": 1}, {"won_combat": 3, "spell_cast": 8}, catalog)
	assert(m_multi.size() == 3, "mage walks L2 (won_combat) then L3/L4 (spell_cast) in one check")
	assert(int(m_multi[2]["level"]) == 4, "cast-counter walk stops at spell_cast 8 = L4")
	assert(WIProgression.check_level_ups({"mage": 1}, {"spell_cast": 100}, catalog).is_empty(), "an unmet early gate blocks the whole walk (no level skipping)")

	# requires_any (spellsword): a level is met when EITHER counter reaches
	# its threshold — canon "levels via either parent's counters" (spec §2.5).
	var sw_melee := WIProgression.check_level_ups({"spellsword": 1}, {"melee_hit": 3}, catalog)
	assert(sw_melee.size() == 1 and sw_melee[0]["level"] == 2, "spellsword L2 via the melee arm")
	var sw_spell := WIProgression.check_level_ups({"spellsword": 1}, {"spell_cast": 2}, catalog)
	assert(sw_spell.size() == 1 and sw_spell[0]["level"] == 2, "spellsword L2 via the spell arm")
	assert(WIProgression.check_level_ups({"spellsword": 1}, {"melee_hit": 2, "spell_cast": 1}, catalog).is_empty(), "neither arm met = no level (requires_any is not vacuously true)")
	var sw_mixed := WIProgression.check_level_ups({"spellsword": 1}, {"melee_hit": 3, "spell_cast": 4}, catalog)
	assert(sw_mixed.size() == 2 and int(sw_mixed[1]["level"]) == 3, "each level may be met by a DIFFERENT arm (L2 melee, L3 spell)")
	assert((sw_mixed[0]["grants"] as Array).is_empty(), "spellsword L2 grants nothing (keener_edge is L1)")

	# --- M6 T3: granted_skills resolves `inherits` (spec §2.6 ⟦B5⟧) ---
	# (a) held Swordsman 10 yields the warrior grants it grew out of PLUS its
	# own swordsman grants (swordsman's own levels 1-9 grant nothing; L10
	# grants quick_slash/flash_cut).
	var swordsman10 := WIProgression.granted_skills({"swordsman": 10}, catalog)
	for sk: String in ["basic_swordwork", "tough_body", "power_strike", "piercing_strikes", "counter_strike", "battle_momentum", "quick_movement", "second_wind", "dangersense"]:
		assert(swordsman10.has(sk), "swordsman 10 inherits warrior grant %s" % sk)
	assert(swordsman10.has("quick_slash") and swordsman10.has("flash_cut"), "swordsman 10 keeps its own L10 grants")
	assert(not swordsman10.has("frost_bolt"), "swordsman does not inherit mage")

	# (b) held Spellsword yields warrior ∪ mage ∪ its own (multi-parent inherits).
	var spellsword1 := WIProgression.granted_skills({"spellsword": 1}, catalog)
	assert(spellsword1.has("basic_swordwork"), "spellsword 1 inherits warrior L1")
	assert(spellsword1.has("frost_bolt") and spellsword1.has("quick_cast") and spellsword1.has("light"), "spellsword 1 inherits mage L1")
	assert(spellsword1.has("keener_edge"), "spellsword 1 keeps its own L1 grant")

	# (c) a hand-built cyclic catalog terminates and returns a finite set —
	# never infinite-loops, never crashes.
	var cyclic_catalog := {
		"classes": [
			{"id": "a", "inherits": "b", "levels": [{"level": 1, "requires": {}, "grants": ["skill_a"]}]},
			{"id": "b", "inherits": "a", "levels": [{"level": 1, "requires": {}, "grants": ["skill_b"]}]},
		]
	}
	var cyclic := WIProgression.granted_skills({"a": 1}, cyclic_catalog)
	assert(cyclic.size() == 2 and cyclic.has("skill_a") and cyclic.has("skill_b"), "cyclic inherits chain terminates with the finite correct set")

	# (d) warrior/mage (no inherits) unchanged from today.
	assert(WIProgression.granted_skills({"warrior": 1}, catalog) == l1, "warrior grants unaffected by inherits resolution")
	assert(WIProgression.granted_skills({"mage": 1}, catalog) == mage_l1, "mage grants unaffected by inherits resolution")

	# --- M6 T3: check_evolutions (spec §2.3 REV 2) ---
	# warrior 10, sword-dominant -> Replacement to swordsman, carrying level.
	var warrior_sword := WIProgression.check_evolutions({"warrior": 10}, {"sword_skill_used": 12, "spear_skill_used": 2}, catalog, [])
	assert(warrior_sword.size() == 1, "warrior sword-dominant yields exactly one outcome")
	assert(warrior_sword[0]["class"] == "warrior" and warrior_sword[0]["to"] == "swordsman" and int(warrior_sword[0]["level"]) == 10, "warrior 10 sword-dominant evolves to swordsman at level 10")
	assert(not bool(warrior_sword[0].get("off_interval", false)), "on-schedule (level 10) evolution is not off_interval")

	# warrior 10, spear-dominant -> Replacement to spearmaster.
	var warrior_spear := WIProgression.check_evolutions({"warrior": 10}, {"sword_skill_used": 2, "spear_skill_used": 10}, catalog, [])
	assert(warrior_spear.size() == 1 and warrior_spear[0]["to"] == "spearmaster", "warrior 10 spear-dominant evolves to spearmaster")

	# warrior 10, total 10 < min_uses 12 -> WAITS (no outcome mutation, at-cap flag).
	var warrior_underuse := WIProgression.check_evolutions({"warrior": 10}, {"sword_skill_used": 5, "spear_skill_used": 5}, catalog, [])
	assert(warrior_underuse.size() == 1 and bool(warrior_underuse[0].get("waiting", false)) and warrior_underuse[0]["class"] == "warrior", "warrior under min_uses waits, no evolution")
	assert(not warrior_underuse[0].has("to") and not bool(warrior_underuse[0].get("generalist", false)), "waiting outcome carries no replacement or generalist grant")

	# warrior 10, total 14 >= 12 but share 0.5 < 0.6 -> WAITS (warrior has no generalist branch).
	var warrior_split := WIProgression.check_evolutions({"warrior": 10}, {"sword_skill_used": 7, "spear_skill_used": 7}, catalog, [])
	assert(warrior_split.size() == 1 and bool(warrior_split[0].get("waiting", false)), "warrior below dominance with no balanced_grants waits, never generalizes")

	# mage 10, ice-dominant -> Replacement to ice_mage.
	var mage_ice := WIProgression.check_evolutions({"mage": 10}, {"ice_cast": 13, "fire_cast": 1}, catalog, [])
	assert(mage_ice.size() == 1 and mage_ice[0]["to"] == "ice_mage" and int(mage_ice[0]["level"]) == 10, "mage 10 ice-dominant evolves to ice_mage")

	# mage 10, split 7/7 (total 14 >= 12, share 0.5 < 0.6) -> Generalist grant.
	var mage_split := WIProgression.check_evolutions({"mage": 10}, {"ice_cast": 7, "fire_cast": 7}, catalog, [])
	assert(mage_split.size() == 1 and bool(mage_split[0].get("generalist", false)), "mage below dominance with enough volume takes the generalist path")
	assert(mage_split[0]["class"] == "mage" and (mage_split[0]["grants"] as Array) == ["ice_shard", "flare_burst"], "generalist grant carries balanced_grants verbatim")
	# M6 whole-branch review fix: those balanced_grants must reach the COMBAT KIT,
	# which is built only from granted_skills -- so granted_skills adds a
	# generalist class's evolution.balanced_grants when the class id is passed in
	# generalist_classes (and does NOT otherwise, i.e. before the evolution fires).
	assert(not WIProgression.granted_skills({"mage": 10}, catalog).has("ice_shard"), "pre-generalist mage 10 kit excludes balanced_grants")
	var gen_kit := WIProgression.granted_skills({"mage": 10}, catalog, ["mage"])
	assert(gen_kit.has("ice_shard") and gen_kit.has("flare_burst"), "a generalist mage fields its balanced_grants in the granted kit")
	# Sub-dominance WITHOUT a tie (8/6 = share 0.571 < 0.6, total 14 >= 12) still
	# takes the generalist path -- distinct from the 7/7 tie case above.
	var mage_subdom := WIProgression.check_evolutions({"mage": 10}, {"ice_cast": 8, "fire_cast": 6}, catalog, [])
	assert(mage_subdom.size() == 1 and bool(mage_subdom[0].get("generalist", false)), "below dominance without a tie still generalizes (share 0.57 < 0.6)")

	# mage already in generalist_classes -> skipped even if now dominant (identity locked).
	var mage_locked := WIProgression.check_evolutions({"mage": 10}, {"ice_cast": 13, "fire_cast": 1}, catalog, ["mage"])
	assert(mage_locked.is_empty(), "generalist-locked mage is never re-evolved, even when dominant")

	# off_interval: fires at level 12+, not at 10/11.
	var warrior_off_interval := WIProgression.check_evolutions({"warrior": 12}, {"sword_skill_used": 12, "spear_skill_used": 2}, catalog, [])
	assert(warrior_off_interval.size() == 1 and bool(warrior_off_interval[0].get("off_interval", false)), "evolution resolved at level 12 carries off_interval")
	var warrior_on_interval := WIProgression.check_evolutions({"warrior": 11}, {"sword_skill_used": 12, "spear_skill_used": 2}, catalog, [])
	assert(not bool(warrior_on_interval[0].get("off_interval", false)), "evolution resolved at level 11 is not off_interval")

	# A class below at_level is never considered (no outcome at all).
	assert(WIProgression.check_evolutions({"warrior": 9}, {"sword_skill_used": 50, "spear_skill_used": 1}, catalog, []).is_empty(), "below at_level: not considered, no outcome")

	# A class carrying no evolution block (swordsman, a terminal evolution) never appears.
	assert(WIProgression.check_evolutions({"swordsman": 2}, {}, catalog, []).is_empty(), "classes without an evolution block never produce an outcome")

	# An evolved class itself has no evolution block (naturally capped).
	assert(WIProgression.check_evolutions({"ice_mage": 12}, {"ice_cast": 100, "fire_cast": 100}, catalog, []).is_empty(), "an evolved/inherited class has no evolution block, never re-evolves")

	# --- M6 T3: sleep()-path integration — proves the early-return restructure ---
	# A sleep with NO level-ups (warrior already at 10, no melee_hit banked
	# this beat) must still resolve evolutions and emit class_evolved; the
	# old `if gains.is_empty(): return` early return would have skipped this.
	var evo_events: Array = []
	var sink := func(type: String, payload: Dictionary) -> void:
		evo_events.append({"type": type, "payload": payload})
	var scene_cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skeleton_scene.json"))
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

	# --- M6 T4: non-linear multiclass scaling (spec §2.4 REV 2) ---
	# THE GATE: at the shipped power_k, a 5/5 split lands in the locked
	# 20-25% split-friction band relative to a focused 10.
	var split_power := WIProgression.effective_power({"warrior": 5, "mage": 5}, catalog)
	var pure_power := WIProgression.effective_power({"warrior": 10}, catalog)
	var ratio := split_power / pure_power
	assert(ratio >= 0.75 and ratio <= 0.80, "5/5 split lands in the locked 0.75-0.80 friction band (got %f)" % ratio)

	# Monotonicity: more levels in one class never decreases effective_power.
	assert(WIProgression.effective_power({"warrior": 5}, catalog) < WIProgression.effective_power({"warrior": 6}, catalog), "adding a level raises effective_power")
	# Adding a second class raises TOTAL effective_power (5/5 > pure-5)...
	assert(split_power > WIProgression.effective_power({"warrior": 5}, catalog), "5/5 split has higher total effective_power than pure-5")
	# ...but the per-level MULTIPLIER drops relative to a focused build.
	assert(WIProgression.power_multiplier({"warrior": 5, "mage": 5}, catalog) < WIProgression.power_multiplier({"warrior": 5}, catalog), "split multiplier is lower than a focused build's")

	# power_multiplier == 1.0 EXACTLY for any single-class build, no penalty.
	assert(WIProgression.power_multiplier({"warrior": 10}, catalog) == 1.0, "focused warrior 10 multiplier is exactly 1.0")
	assert(WIProgression.power_multiplier({"warrior": 2}, catalog) == 1.0, "focused warrior 2 multiplier is exactly 1.0")

	# power_multiplier < 1.0 for split builds.
	assert(WIProgression.power_multiplier({"warrior": 5, "mage": 5}, catalog) < 1.0, "warrior5/mage5 split incurs a penalty")
	assert(WIProgression.power_multiplier({"warrior": 2, "mage": 2}, catalog) < 1.0, "warrior2/mage2 split incurs a penalty")

	# Empty classes: no divide-by-zero, sane defaults.
	assert(WIProgression.effective_power({}, catalog) == 0.0, "empty classes yields effective_power 0.0")
	assert(WIProgression.power_multiplier({}, catalog) == 1.0, "empty classes yields multiplier 1.0 (no penalty, no crash)")

	# --- M6 T4b: additive stat_growth (spec §2.4 REVISION 2026-07-03) ---
	# Pinned formula: stat_bonus[S] = round((Σ_class growth_c[S] * L_c) * efficiency),
	# efficiency == power_multiplier, rounded ONCE per stat, ADDED to base stats.

	# Focused warrior 10 (growth {str:1, con:1}) -> efficiency exactly 1.0 -> +10 str, +10 con, 0 elsewhere.
	var warrior10_bonus := WIProgression.derived_stat_bonuses({"warrior": 10}, catalog)
	assert(int(warrior10_bonus.get("str", 0)) == 10, "focused warrior 10 grants +10 str")
	assert(int(warrior10_bonus.get("con", 0)) == 10, "focused warrior 10 grants +10 con")
	assert(int(warrior10_bonus.get("dex", 0)) == 0, "focused warrior 10 grants 0 dex")
	assert(int(warrior10_bonus.get("int", 0)) == 0, "focused warrior 10 grants 0 int")

	# Focused warrior 2 (growth {str:1, con:1}) -> +2 str, +2 con.
	var warrior2_bonus := WIProgression.derived_stat_bonuses({"warrior": 2}, catalog)
	assert(int(warrior2_bonus.get("str", 0)) == 2, "focused warrior 2 grants +2 str")
	assert(int(warrior2_bonus.get("con", 0)) == 2, "focused warrior 2 grants +2 con")

	# warrior 5 / mage 5 split (efficiency ~= 0.78196 at k=1.55) ->
	# str/con bonus = round(5 * 0.78196) = 4 each; int bonus = round(5 * 0.78196) = 4.
	var split_bonus := WIProgression.derived_stat_bonuses({"warrior": 5, "mage": 5}, catalog)
	assert(int(split_bonus.get("str", 0)) == 4, "5/5 split grants +4 str (scaled by split-efficiency)")
	assert(int(split_bonus.get("con", 0)) == 4, "5/5 split grants +4 con (scaled by split-efficiency)")
	assert(int(split_bonus.get("int", 0)) == 4, "5/5 split grants +4 int (scaled by split-efficiency)")
	assert(int(split_bonus.get("dex", 0)) == 0, "5/5 split grants 0 dex (neither class touches dex)")

	# {} (no classes) -> all-zero bonuses, no crash.
	var empty_bonus := WIProgression.derived_stat_bonuses({}, catalog)
	for stat_key: String in ["str", "dex", "con", "int"]:
		assert(int(empty_bonus.get(stat_key, 0)) == 0, "empty classes yields zero bonus for %s" % stat_key)

	# Missing stat_growth on a class must not crash and must contribute zero growth.
	var no_growth_catalog := {
		"meta": {"power_k": 1.55},
		"classes": [{"id": "blank", "levels": [{"level": 1, "requires": {}, "grants": []}]}],
	}
	var blank_bonus := WIProgression.derived_stat_bonuses({"blank": 5}, no_growth_catalog)
	for stat_key: String in ["str", "dex", "con", "int"]:
		assert(int(blank_bonus.get(stat_key, 0)) == 0, "class with no stat_growth contributes zero for %s" % stat_key)

	# apply_stat_bonuses: shared application helper (wi_game.gd + sim_combat_batch.gd
	# must call the SAME code path, per T4 review's duplication flag).
	var base_stats := {"str": 10, "dex": 10, "con": 10, "int": 10}
	var applied := WIProgression.apply_stat_bonuses(base_stats, {"warrior": 10}, catalog)
	assert(int(applied["str"]) == 20 and int(applied["con"]) == 20, "apply_stat_bonuses adds bonus to base stat")
	assert(int(applied["dex"]) == 10 and int(applied["int"]) == 10, "apply_stat_bonuses leaves untouched stats as base")
	assert(int(base_stats["str"]) == 10, "apply_stat_bonuses does not mutate the input dictionary")

	# --- M6 T5: check_consolidation (spec §2.5 REV 2) ---
	# Pinned math: merged = max(ceil(2*(L_a+L_b)/3), max(L_a, L_b)), INTEGER
	# arithmetic only. Trigger: both parents >= min_parent_level (6) AND
	# sum >= min_combined_level (13).
	var offer_9_12 := WIProgression.check_consolidation({"warrior": 9, "mage": 12}, catalog)
	assert(not offer_9_12.is_empty(), "warrior 9 / mage 12 both meet the trigger")
	assert((offer_9_12["parents"] as Array) == ["warrior", "mage"], "parents reported in catalog order")
	assert(offer_9_12["target"] == "spellsword", "target is spellsword")
	assert(int(offer_9_12["level"]) == 14, "(9,12) -> 14 (the vision example)")

	assert(int(WIProgression.check_consolidation({"warrior": 6, "mage": 7}, catalog)["level"]) == 9, "(6,7) -> 9")
	assert(int(WIProgression.check_consolidation({"warrior": 10, "mage": 10}, catalog)["level"]) == 14, "(10,10) -> 14")
	assert(int(WIProgression.check_consolidation({"warrior": 20, "mage": 8}, catalog)["level"]) == 20, "(20,8) -> 20 (max() clamp, never drops below the higher parent)")

	# Trigger boundary: both parents must be >= 6 AND sum >= 13.
	assert(WIProgression.check_consolidation({"warrior": 5, "mage": 8}, catalog).is_empty(), "one parent below min_parent_level (6) -> no offer")
	assert(WIProgression.check_consolidation({"warrior": 6, "mage": 6}, catalog).is_empty(), "both parents at min_parent_level but sum 12 < 13 -> no offer")
	assert(not WIProgression.check_consolidation({"warrior": 6, "mage": 7}, catalog).is_empty(), "both >=6 and sum ==13 -> offer fires (boundary inclusive)")

	# Only one parent held -> no offer (need BOTH lines).
	assert(WIProgression.check_consolidation({"warrior": 12}, catalog).is_empty(), "only one parent line held -> no offer")
	assert(WIProgression.check_consolidation({}, catalog).is_empty(), "no classes held -> no offer")

	# Already consolidated (spellsword held) -> parents are gone, no re-offer possible
	# via this function (the caller never has both parent lines held simultaneously
	# once accept_consolidation erases them, but check_consolidation itself is a
	# pure function of `classes` and must not crash on the target already present).
	assert(WIProgression.check_consolidation({"spellsword": 14}, catalog).is_empty(), "holding only the target class -> no offer (no parent lines held)")

	# --- Lineage (⟦I7⟧): evolved classes remain valid parents. ---
	# [Swordsman]+[Ice Mage] still offer [Spellsword] -- a held class counts
	# for a parent line if it IS the base id or an evolution target of that line.
	var evolved_offer := WIProgression.check_consolidation({"swordsman": 9, "ice_mage": 12}, catalog)
	assert(not evolved_offer.is_empty(), "evolved parents (swordsman + ice_mage) still trigger the offer")
	assert((evolved_offer["parents"] as Array) == ["swordsman", "ice_mage"], "parents reported by their HELD (evolved) ids, not the base line id")
	assert(evolved_offer["target"] == "spellsword", "evolved parents still target spellsword")
	assert(int(evolved_offer["level"]) == 14, "evolved-parent math uses the SAME formula (9,12) -> 14")

	var mixed_evolved := WIProgression.check_consolidation({"spearmaster": 10, "fire_mage": 10}, catalog)
	assert(not mixed_evolved.is_empty() and int(mixed_evolved["level"]) == 14, "spearmaster + fire_mage (10,10) -> 14")

	# Two held classes from the SAME line (shouldn't normally happen in real
	# play -- evolution erases the base id -- but the function must not crash
	# on a hand-built dict that holds both) -- picks the HIGHEST-level
	# candidate from that line, never double-counts a line.
	var same_line := WIProgression.check_consolidation({"warrior": 3, "swordsman": 9, "mage": 12}, catalog)
	assert(not same_line.is_empty(), "the higher-level candidate (swordsman 9) qualifies even though warrior 3 (same line, sub-threshold) is also held")
	assert((same_line["parents"] as Array) == ["swordsman", "mage"], "the best (highest-level) candidate per line is reported, not the first-listed id")

	print("PASS: progression checks behave correctly")
	quit(0)
