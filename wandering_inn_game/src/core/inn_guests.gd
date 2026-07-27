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


## Quest-completion gates on pool membership (2026-07-26 FoTI extension):
## a rostered npc joins the met-pool only when chatted AND its gate (if
## any) is open -- otherwise the window would seat an entity whose
## present_when hides it (a ghost-empty seat all waking).
##
## A value is EITHER a bare accomplishment id (the common "this quest must
## have closed" case) OR a `{"requires": [...], "absent": [...]}` dict that
## mirrors present_when's two arms, so a row carrying a negative arm can
## state the SAME condition here. Rags is why the dict shape exists: her
## encounter's on_victory banks rags_meeting_settled alongside
## drove_off_rags, so the positive arm alone would pool the Chieftain the
## player drove off the plains while her row's own `absent` hid her.
## Pool membership and row presence must never disagree.
const GUEST_POOL_GATES := {
	"rags": {"requires": ["rags_meeting_settled"], "absent": ["drove_off_rags"]},
	"wilovan": "brothers_job_done",
	"grimalkin": "elevator_pass_stamped",
}


## Is a GUEST_POOL_GATES value satisfied? FAIL-CLOSED in both shapes: with
## no predicate to ask, a gated npc never pools -- including one whose gate
## is nothing but an `absent` arm, because "we cannot read the counters" is
## never evidence that a counter is unbanked.
static func _gate_open(gate: Variant, gate_met: Callable) -> bool:
	if not gate_met.is_valid():
		return false
	if gate is Dictionary:
		var spec: Dictionary = gate
		for key: Variant in (spec.get("requires", []) as Array):
			if not bool(gate_met.call(String(key))):
				return false
		for key: Variant in (spec.get("absent", []) as Array):
			if bool(gate_met.call(String(key))):
				return false
		return true
	return bool(gate_met.call(String(gate)))


## The ordered met-pool: roster members (fixed order) the player has met,
## minus any whose GUEST_POOL_GATES gate is not open.
##
## `gate_met` takes an ACCOMPLISHMENT KEY (not an npc id) and answers
## whether it is banked. It is optional and FAIL-CLOSED: a caller that
## omits it seats no gated guest at all, which degrades to the same
## nothing the row's own present_when would render. Callers that can read
## accomplishments (wi_game) always pass it.
static func met_pool(roster: Array, is_met: Callable, gate_met := Callable()) -> Array:
	var pool: Array = []
	for npc: Variant in roster:
		var id := String(npc)
		if not bool(is_met.call(id)):
			continue
		if GUEST_POOL_GATES.has(id) and not _gate_open(GUEST_POOL_GATES[id], gate_met):
			continue
		pool.append(id)
	return pool


## The NPCs on shift this waking: seats distinct people, windowed by
## times_slept over the met-pool. Empty when the pool is empty or seats<=0.
static func active_guests(roster: Array, is_met: Callable, times_slept: int, seats: int, gate_met := Callable()) -> Array:
	var pool := met_pool(roster, is_met, gate_met)
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
static func guest_active(npc: String, roster: Array, is_met: Callable, times_slept: int, seats: int, gate_met := Callable()) -> bool:
	return active_guests(roster, is_met, times_slept, seats, gate_met).has(npc)
