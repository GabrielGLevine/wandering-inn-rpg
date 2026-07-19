class_name WIInnGuests
## d1 #247 Friends of the Inn -- the deterministic guest rotation.
##
## PURE: no autoload/Node refs, no rng. Given the fixed roster order, a
## met-predicate, times_slept, and the seat count, it returns the ordered
## list of NPCs currently "on shift" at the inn. The window slides by
## times_slept, so who is present rotates each waking once the met-pool
## outgrows the seats; before then every met guest is simply present.
##
## Dedup is STRUCTURAL: the active set is a set of DISTINCT met-pool
## indices, so a pool smaller than the seat count leaves the trailing
## seats EMPTY -- a person is never duplicated across two seats (the
## spec's slot-dedup rule). Consumed by wi_game._present_gate_met's
## `guest` present_when arm; validated by test_content._validate_present_when.


## The ordered met-pool: roster members (fixed order) the player has met.
static func met_pool(roster: Array, is_met: Callable) -> Array:
	var pool: Array = []
	for npc: Variant in roster:
		if bool(is_met.call(String(npc))):
			pool.append(String(npc))
	return pool


## The NPCs on shift this waking: seats distinct people, windowed by
## times_slept over the met-pool. Empty when the pool is empty or seats<=0.
static func active_guests(roster: Array, is_met: Callable, times_slept: int, seats: int) -> Array:
	var pool := met_pool(roster, is_met)
	var k := pool.size()
	if k == 0 or seats <= 0:
		return []
	var start := ((times_slept % k) + k) % k  # guard negative times_slept
	var fill := mini(seats, k)  # never more people than the pool holds
	var out: Array = []
	for s in range(fill):
		out.append(pool[(start + s) % k])
	return out


## Is this specific NPC on shift this waking?
static func guest_active(npc: String, roster: Array, is_met: Callable, times_slept: int, seats: int) -> bool:
	return active_guests(roster, is_met, times_slept, seats).has(npc)
