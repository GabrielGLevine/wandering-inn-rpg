extends SceneTree
## d1 #247 Friends of the Inn -- unit-pins the pure rotation (WIInnGuests).
## The live canonical (inn_guests_loop) proves present-when-met + servable
## for the pilot pair; the ROTATION MATH (windowing, dedup, no-duplicate)
## can't show with only 2 roster members over 2 seats, so it is pinned here
## across synthetic pools that outgrow the seats -- the PR2+ behavior.

func _met(present: Array) -> Callable:
	return func(npc: String) -> bool: return present.has(npc)


func _init() -> void:
	var roster := ["selys", "krshia", "olesm", "pisces"]

	# Empty pool / no seats -> nobody on shift.
	assert(WIInnGuests.active_guests(roster, _met([]), 0, 2).is_empty(), "no met guests -> empty")
	assert(WIInnGuests.active_guests(roster, _met(["selys"]), 0, 0).is_empty(), "zero seats -> empty")

	# Pool smaller than seats: the trailing seat stays EMPTY, never duplicates.
	var one := WIInnGuests.active_guests(roster, _met(["selys"]), 0, 2)
	assert(one == ["selys"], "pool of 1 fills only 1 of 2 seats (no duplicate): got %s" % [one])

	# Pilot case (roster order preserved): both met, 2 seats -> both, every waking.
	assert(WIInnGuests.active_guests(roster, _met(["selys", "krshia"]), 0, 2) == ["selys", "krshia"], "both met -> both, t=0")
	assert(WIInnGuests.active_guests(roster, _met(["selys", "krshia"]), 7, 2) == ["krshia", "selys"], "both met, odd waking -> window slides but same two present")

	# Pool larger than seats: the window of `seats` DISTINCT people slides by times_slept.
	var big := _met(["selys", "krshia", "olesm", "pisces"])  # pool size 4
	assert(WIInnGuests.active_guests(roster, big, 0, 2) == ["selys", "krshia"], "t=0 -> [selys,krshia]")
	assert(WIInnGuests.active_guests(roster, big, 1, 2) == ["krshia", "olesm"], "t=1 slides one")
	assert(WIInnGuests.active_guests(roster, big, 3, 2) == ["pisces", "selys"], "t=3 wraps the window")
	assert(WIInnGuests.active_guests(roster, big, 4, 2) == ["selys", "krshia"], "t=4 == t=0 (period = pool size)")

	# No seat ever holds a duplicate person, for every waking across a full period.
	for t in range(12):
		var active := WIInnGuests.active_guests(roster, big, t, 3)
		var seen := {}
		for npc: String in active:
			assert(not seen.has(npc), "t=%d seats a duplicate: %s" % [t, active])
			seen[npc] = true
		assert(active.size() == 3, "t=%d fills all 3 seats from a pool of 4" % t)

	# PR2b: the SHIPPED roster completes at six, and the two shipped fixture
	# positions window DIFFERENTLY off the same times_slept -- the exact math
	# the canonicals pin live, mirrored here so a roster edit reds a unit test
	# before it reds a 90-second QA run.
	var six := ["selys", "krshia", "olesm", "pisces", "relc", "zevara"]
	var pool5 := _met(["selys", "krshia", "olesm", "pisces", "relc"])  # inn_guests_start: zevara alone unmet
	assert(WIInnGuests.active_guests(six, pool5, 10, 2) == ["selys", "krshia"], "inn_guests_start t=10: pool 5, start 10%%5=0 -> the pilot pair")
	assert(WIInnGuests.active_guests(six, pool5, 11, 2) == ["krshia", "olesm"], "inn_guests_start t=11: krshia STAYS, olesm arrives (a slide, not a swap)")
	assert(WIInnGuests.active_guests(six, pool5, 12, 2) == ["olesm", "pisces"], "inn_guests_start t=12: olesm stays, pisces arrives")
	var pool6 := _met(six)  # inn_guests_full_start: all six met
	assert(WIInnGuests.active_guests(six, pool6, 10, 2) == ["relc", "zevara"], "inn_guests_full_start t=10: pool 6, start 10%%6=4 -> the PR2b pair")
	assert(WIInnGuests.active_guests(six, pool6, 11, 2) == ["zevara", "selys"], "inn_guests_full_start t=11: the window wraps the roster's tail onto its head")
	assert(WIInnGuests.active_guests(six, pool6, 16, 2) == ["relc", "zevara"], "full pool period is 6 wakings deep")
	# An unmet member never shifts the window: the pool, not the roster, is the modulus.
	assert(WIInnGuests.active_guests(six, pool5, 10, 2) != WIInnGuests.active_guests(six, pool6, 10, 2), "an unmet roster member changes the modulus, so the same waking seats a different pair")

	# Negative times_slept is guarded (never crashes / never out-of-range).
	assert(WIInnGuests.active_guests(roster, big, -1, 2).size() == 2, "negative times_slept guarded")

	# guest_active mirrors membership in the active set.
	assert(WIInnGuests.guest_active("selys", roster, big, 0, 2), "selys active at t=0")
	assert(not WIInnGuests.guest_active("pisces", roster, big, 0, 2), "pisces off-shift at t=0")
	assert(not WIInnGuests.guest_active("olesm", roster, _met(["selys", "krshia"]), 0, 2), "unmet olesm never seats")

	_test_quest_gates()

	print("PASS: inn-guest rotation windows, dedups, and slides deterministically")
	quit(0)


## d1 #247 FoTI extension (2026-07-26): three of the four new roster members
## join the met-pool only once their QUEST closes, not when first met, so the
## pool now takes a SECOND predicate (banked-accomplishment lookup) alongside
## the met one. Klbkch is the control: rostered, gate-free, met-only.
func _banked(keys: Array) -> Callable:
	return func(key: String) -> bool: return keys.has(key)


func _test_quest_gates() -> void:
	var ten := ["selys", "krshia", "olesm", "pisces", "relc", "zevara", "klbkch", "rags", "wilovan", "grimalkin"]
	var all_met := _met(ten)

	# Every roster member chatted, every gate banked EXCEPT Rags's.
	var most := _banked(["brothers_job_done", "elevator_pass_stamped"])
	for t in range(20):
		var active := WIInnGuests.active_guests(ten, all_met, t, 2, most)
		assert(not active.has("rags"), "t=%d seats rags with rags_meeting_settled unbanked: %s" % [t, active])
	assert(WIInnGuests.met_pool(ten, all_met, most).size() == 9, "the ungated nine still pool")
	assert(not WIInnGuests.guest_active("rags", ten, all_met, 7, 2, most), "guest_active agrees with the pool filter")
	# The gate is Rags's alone: her two fellow quest-gates are banked and they seat.
	var pool9 := WIInnGuests.met_pool(ten, all_met, most)
	assert(pool9.has("wilovan") and pool9.has("grimalkin") and pool9.has("klbkch"), "only the unbanked gate is filtered: %s" % [pool9])

	# Bank it and she rotates in on the very next full pool.
	var all_banked := _banked(["rags_meeting_settled", "brothers_job_done", "elevator_pass_stamped"])
	assert(WIInnGuests.met_pool(ten, all_met, all_banked).size() == 10, "all ten pool once every gate is banked")
	var seen_rags := false
	for t in range(20):
		if WIInnGuests.active_guests(ten, all_met, t, 2, all_banked).has("rags"):
			seen_rags = true
	assert(seen_rags, "rags rotates in across a full cycle once rags_meeting_settled is banked")

	# The extension fixture's pins, mirrored off the live math (pool 10, 2 seats):
	# the three wakings that walk the four new registers through both seats.
	assert(WIInnGuests.active_guests(ten, all_met, 16, 2, all_banked) == ["klbkch", "rags"], "t=16: start 16%%10=6 -> klbkch + rags")
	assert(WIInnGuests.active_guests(ten, all_met, 17, 2, all_banked) == ["rags", "wilovan"], "t=17: rags STAYS, wilovan arrives")
	assert(WIInnGuests.active_guests(ten, all_met, 18, 2, all_banked) == ["wilovan", "grimalkin"], "t=18: wilovan stays, grimalkin arrives")
	assert(WIInnGuests.active_guests(ten, all_met, 10, 2, all_banked) == ["selys", "krshia"], "t=10: a pool of ten wraps the pilot pair back round")

	# THE BETRAYAL BRANCH (ghost-empty-seat regression). rags_meeting_settled
	# is ALSO banked by rags_scouting_party's on_victory, next to
	# drove_off_rags -- so a positive-only gate would pool the Chieftain the
	# player drove off the plains while her row's own `absent` arm hid her,
	# and the window would spend a seat on nobody. The dict-shaped gate states
	# the row's condition exactly, so the two can never disagree.
	var betrayed := _banked(["rags_meeting_settled", "drove_off_rags", "brothers_job_done", "elevator_pass_stamped"])
	var pool_after_betrayal := WIInnGuests.met_pool(ten, all_met, betrayed)
	assert(not pool_after_betrayal.has("rags"), "a driven-off chieftain never pools, settled counter or not: %s" % [pool_after_betrayal])
	assert(pool_after_betrayal.has("wilovan") and pool_after_betrayal.has("grimalkin"), "only Rags's gate closes on the betrayal: %s" % [pool_after_betrayal])
	for t in range(20):
		var seated := WIInnGuests.active_guests(ten, all_met, t, 2, betrayed)
		assert(not seated.has("rags"), "t=%d seats a driven-off rags: %s" % [t, seated])
		# The regression itself: an excluded guest RE-BASES the modulus, it
		# never leaves a hole in the rotation.
		assert(seated.size() == 2, "t=%d must still fill BOTH seats after the exclusion (ghost-empty chair): %s" % [t, seated])

	# Both value shapes stay legal, and the bare-String form is untouched.
	assert(WIInnGuests.GUEST_POOL_GATES["wilovan"] is String, "the bare-accomplishment form stays supported")
	assert(WIInnGuests.GUEST_POOL_GATES["rags"] is Dictionary, "Rags's gate carries the two-arm form")
	assert(WIInnGuests.met_pool(ten, all_met, _banked(["brothers_job_done"])).has("wilovan"), "String gate opens on its own counter")
	assert(not WIInnGuests.met_pool(ten, all_met, _banked(["brothers_job_done"])).has("grimalkin"), "String gate stays shut without its counter")

	# Klbkch carries NO gate: met alone seats him, with nothing banked at all.
	var nothing := _banked([])
	assert(WIInnGuests.met_pool(ten, all_met, nothing).has("klbkch"), "klbkch is gate-free -- met is the whole gate")
	# FAIL-CLOSED holds for the dict shape too: an `absent`-only-looking gate
	# is still shut when there is no predicate to ask (see _gate_open).
	assert(not WIInnGuests.met_pool(ten, all_met).has("rags"), "no predicate -> the two-arm gate stays shut, same as the String one")

	# A SPEC THAT RESOLVES TO NO ARMS IS SHUT, NOT OPEN (fix round 2). Before
	# the guard these fell through every loop to `return true`, so one
	# misspelled key would have re-opened the ghost-seat class the whole const
	# exists to prevent -- and silently, since a typo'd key raises nothing.
	var live := _banked(["rags_meeting_settled"])
	assert(not WIInnGuests._gate_open({}, live), "an empty spec is shut, not unconditioned")
	assert(not WIInnGuests._gate_open({"require": ["rags_meeting_settled"]}, live), "a misspelled `require` key is shut, not unconditioned")
	assert(not WIInnGuests._gate_open({"requires": [], "absent": []}, live), "explicitly empty arms are shut too")
	# Positive controls, so the guard cannot pass by shutting everything.
	assert(WIInnGuests._gate_open({"requires": ["rags_meeting_settled"]}, live), "a real requires arm still opens")
	assert(WIInnGuests._gate_open({"absent": ["drove_off_rags"]}, live), "a real absent arm still opens")
	assert(WIInnGuests._gate_open("rags_meeting_settled", live), "the bare-String form still opens")
	assert(not WIInnGuests._gate_open({}, Callable()), "no predicate, no opinion, still shut")

	# FAIL-CLOSED default: a caller that forgets the gate predicate never seats
	# a gated guest (the row's own present_when.requires would hide it anyway,
	# so an ungated pool would only ever produce a ghost-empty seat).
	assert(WIInnGuests.met_pool(ten, all_met).size() == 7, "no gate predicate -> the three quest-gated members stay out")
	assert(not WIInnGuests.guest_active("wilovan", ten, all_met, 8, 2), "gated guest never seats without a gate predicate")
