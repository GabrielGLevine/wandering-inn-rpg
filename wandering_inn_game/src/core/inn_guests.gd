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
## THREE value shapes, and the same condition must appear on the npc's guest
## ROW(s) -- pool membership and row presence may never disagree, or the window
## spends a seat on nobody (test_content._validate_guest_gate_windows pins it):
##   String  -- a bare accomplishment id ("this quest must have closed").
##   Dict    -- {"requires": [...], "absent": [...]}, an AND of present_when's
##              two arms. Rags is why it exists: rags_scouting_party's
##              on_victory banks rags_meeting_settled next to drove_off_rags,
##              so a positive-only gate would pool the Chieftain the player
##              drove off the plains while her row's own `absent` hid her.
##   Array   -- ANY-of specs (v0.15 ruling 1). The ARC WINDOW: a guest vacates
##              the inn for the span of their own live story, which is a
##              DISJUNCTION (before it opens OR after it closes) that one dict
##              cannot state. Zevara is at her gate from the summons she gives
##              until she writes the warren down as closed; Pisces is at the
##              pantry hanging the Door through the haul window, where
##              pisces_mounting (13,5) holds him and BOTH his guest rows hide
##              (his chair used to render empty there).
## Every entry makes its npc gate-DEPENDENT: the fail-closed default drops them
## for any caller that omits the predicate. wi_game always passes it.
## RELC, AUDITED AND NOT LISTED (v0.15 T3.1): relc_descent_cameo occupies
## [reached_the_warren, cleared_the_warren) on deep_tunnels, but a cross-MAP
## double is the shipped idiom, not a defect -- every guest also stands at a
## permanent home post (relc on floodplains, zevara at the gate). His inn row
## is ungated, so no ghost seat exists to close, and no inn-map line contradicts
## a seated Relc. Gating him would buy nothing and cost a shipped ungated row.
const GUEST_POOL_GATES := {
	"rags": {"requires": ["rags_meeting_settled"], "absent": ["drove_off_rags"]},
	"wilovan": "brothers_job_done",
	"grimalkin": "elevator_pass_stamped",
	"zevara": [{"absent": ["heard_the_deep_tremor"]}, {"requires": ["raskghar_sealed"]}],
	"pisces": [{"absent": ["door_retrieved"]}, {"requires": ["door_mounted"]}],
}


## Is a GUEST_POOL_GATES value satisfied? FAIL-CLOSED everywhere: with no
## predicate to ask, a gated npc never pools -- including one whose gate is
## nothing but an `absent` arm, because "we cannot read the counters" is
## never evidence that a counter is unbanked.
##
## A dict that resolves to NO arms is fail-closed too (fix round 2). `{}`, or
## a spec whose key is misspelled (`"require"`), would otherwise fall through
## every loop to `return true` and silently re-open the ghost-seat class
## through a typo -- the one failure mode this whole const exists to prevent.
## An unrecognized shape has to read as "shut", never as "no conditions".
##
## The ANY-of Array inherits that discipline WHOLE: an empty Array opens
## nothing, and ONE malformed member shuts the whole disjunction rather than
## being skipped past -- a typo'd member must not leave a narrower window
## silently passing as if it were the authored one.
static func _gate_open(gate: Variant, gate_met: Callable) -> bool:
	if not gate_met.is_valid():
		return false
	if gate is Array:
		var specs: Array = gate
		if specs.is_empty():
			return false
		var any_open := false
		for spec: Variant in specs:
			if not (spec is Dictionary):
				return false
			if _gate_open(spec, gate_met):
				any_open = true
		return any_open
	if gate is Dictionary:
		var spec: Dictionary = gate
		var requires: Array = spec.get("requires", []) as Array
		var absent: Array = spec.get("absent", []) as Array
		if requires.is_empty() and absent.is_empty():
			return false
		for key: Variant in requires:
			if not bool(gate_met.call(String(key))):
				return false
		for key: Variant in absent:
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
