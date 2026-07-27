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

	print("PASS: inn-guest rotation windows, dedups, and slides deterministically")
	quit(0)
