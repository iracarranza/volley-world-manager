extends SceneTree

## M4 slice 1's own acceptance criterion, measured rather than asserted.
##
##     godot --headless --path . --script res://tools/run_platform_intent_census.gd
##
## `PLATFORM_CONTACT.md` section 11 asks two things of this slice and they pull in
## opposite directions:
##
##   1. **rallies must come back byte-identical** -- nothing reads the intent, so
##      publishing it may not move a single outcome;
##   2. it must make countable, "for the first time, how many platform contacts in
##      the game have any stated intent at all."
##
## The first is what makes the second trustworthy. A census of a population that
## moved while being counted measures the counting.
##
## The doc also states its own expectation, which is what makes this falsifiable:
## "the expected answer is that coverage has none and the other two have half of
## one." Half of one, because reception and dig name a target and a recipient and
## the two disagree -- the dig aims a stride from the digger and calls it a pass
## to the setter.
##
## Run it on the production tree and again with the change stashed. Comparing the
## two runs on one instrument is the check; quoting a census taken on a different
## seed base would not be.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const RallySimulatorScript := preload(
	"res://scripts/simulation/rally_simulator.gd"
)

const COURT_WIDTH_METERS: float = 9.0
const COURT_LENGTH_METERS: float = 18.0

const FIRST_SEED: int = 23000
const RALLIES_PER_SERVER: int = 300


## How far the anchor a contact published sits from the seat its own named
## recipient is heading for. Accumulated across the sweep; see part 4.
var _anchor_to_seat: Dictionary = {}


func _initialize() -> void:
	_report(_sweep())
	_anchor_against_the_seat()
	quit()


func _sweep() -> Dictionary:
	var counts := {}
	var intents := {}
	var events := 0
	var home_points := 0
	var rallies := 0
	for serving_home in [true, false]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + RALLIES_PER_SERVER):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				manager.free()
				continue
			rallies += 1
			events += result.events.size()
			if bool(result.home_team_won):
				home_points += 1
			var outcome := str(result.terminal_outcome)
			counts[outcome] = int(counts.get(outcome, 0)) + 1
			_collect(result, intents)
			_collect_seat_gap(manager, result)
			manager.free()
	return {
		"outcomes": counts, "events": events, "home_points": home_points,
		"intents": intents, "rallies": rallies,
	}


func _collect(result: Resource, intents: Dictionary) -> void:
	for entry in result.events:
		var event := entry as RallyEvent
		if event == null:
			continue
		if event.event_type not in [
			RallyEventScript.EventType.RECEPTION,
			RallyEventScript.EventType.DIG,
			RallyEventScript.EventType.ATTACK_COVERAGE,
		]:
			continue
		var record: Dictionary = event.metadata.get("platform_intent", {})
		## `MISSING` is a real answer, not a formatting fallback: a platform
		## contact with no intent record at all is a site this slice failed to
		## reach, and it has to be distinguishable from one whose intent is
		## honestly `unset`.
		var purpose := str(record.get("purpose", "MISSING"))
		var bucket: Dictionary = intents.get(purpose, {
			"contacts": 0, "recipient": 0, "height": 0, "arrival": 0,
			"seat_anchor": 0, "offset_anchor": 0, "preference": 0,
			"floor_total": 0.0, "floor_slack": 0, "height_total": 0.0,
			"height_min": 99.0, "height_max": 0.0,
		})
		bucket["contacts"] = int(bucket["contacts"]) + 1
		if int(record.get("intended_recipient_id", -1)) >= 0:
			bucket["recipient"] = int(bucket["recipient"]) + 1
		## `has` first, then the marker. Without the `has` an *absent* record
		## reported a stated height on every contact -- `get` returns `null`,
		## and `null is String` is false. Caught by running this probe against
		## the pre-slice tree, where it claimed 785 of 785 anchors existed.
		if record.has("height_anchor_meters") \
				and not (record["height_anchor_meters"] is String):
			bucket["height"] = int(bucket["height"]) + 1
			var anchor_height := float(record["height_anchor_meters"])
			bucket["height_total"] = float(bucket["height_total"]) + anchor_height
			## Min and max, not only the mean. A body-derived anchor that comes
			## back constant is a knob that cannot reach its own range, which is
			## `FAILURE_MODES.md` section 0 and the one thing a mean hides.
			bucket["height_min"] = minf(float(bucket["height_min"]), anchor_height)
			bucket["height_max"] = maxf(float(bucket["height_max"]), anchor_height)
		if record.has("arrival_floor_seconds") \
				and not (record["arrival_floor_seconds"] is String):
			bucket["arrival"] = int(bucket["arrival"]) + 1
			var floor_seconds := float(record["arrival_floor_seconds"])
			bucket["floor_total"] = float(bucket["floor_total"]) + floor_seconds
			if floor_seconds <= 0.0001:
				bucket["floor_slack"] = int(bucket["floor_slack"]) + 1
		match str(record.get("anchor_source", "")):
			"release_seat":
				bucket["seat_anchor"] = int(bucket["seat_anchor"]) + 1
			"contact_offset":
				bucket["offset_anchor"] = int(bucket["offset_anchor"]) + 1
		if str(record.get("preference_source", "none")) != "none":
			bucket["preference"] = int(bucket["preference"]) + 1
		intents[purpose] = bucket


func _report(census: Dictionary) -> void:
	print("=".repeat(78))
	print("PART 1 -- the outcome mix, which must not have moved")
	print("=".repeat(78))
	print("  %d rallies, %d home points, %d events" % [
		int(census.rallies), int(census.home_points), int(census.events),
	])
	var outcomes: Dictionary = census.outcomes
	var names: Array = outcomes.keys()
	names.sort()
	for name in names:
		print("  %-28s %d" % [str(name), int(outcomes[name])])
	print("")
	print("  Compare against the same probe run with the change stashed. Any")
	print("  disagreement means something read the intent, and slice 1 forbids it.")

	print("\n" + "=".repeat(78))
	print("PART 2 -- how many platform contacts state an intent, by purpose")
	print("=".repeat(78))
	var intents: Dictionary = census.intents
	var purposes: Array = intents.keys()
	purposes.sort()
	print("  %-18s %-9s %-11s %-9s %-9s %-11s" % [
		"purpose", "contacts", "recipient", "height", "arrival", "steerable",
	])
	var total := 0
	for purpose in purposes:
		var bucket: Dictionary = intents[purpose]
		total += int(bucket["contacts"])
		print("  %-18s %-9d %-11d %-9d %-9d %-11d" % [
			str(purpose), int(bucket["contacts"]), int(bucket["recipient"]),
			int(bucket["height"]), int(bucket["arrival"]),
			int(bucket["seat_anchor"]),
		])
	print("  %-18s %-9d" % ["all", total])
	print("")
	print("  `steerable` is the count whose target came from the manager-set")
	print("  release seat rather than a fixed offset off the contact point. It is")
	print("  section 13.9's item 3, countable: every contact outside that column")
	print("  aims a stride from itself and calls it a pass.")

	print("\n" + "=".repeat(78))
	print("PART 3 -- the two derived anchors, and how often the floor binds")
	print("=".repeat(78))
	print("  A floor of zero is *slack*, not urgency: a setter already at the")
	print("  anchor stops constraining the ball rather than compressing it to")
	print("  nothing. Section 3a's own worked example, measured.\n")
	print("  %-18s %-22s %-14s %-14s" % [
		"purpose", "height anchor m (min/p50/max)", "mean floor s", "slack (<=0)",
	])
	for purpose in purposes:
		var bucket: Dictionary = intents[purpose]
		var stated := int(bucket["arrival"])
		if stated == 0:
			print("  %-18s %-22s %-14s %-14s" % [
				str(purpose), "unset", "unset", "--",
			])
			continue
		print("  %-18s %-22s %-14.3f %-14d" % [
			str(purpose),
			"%.3f / %.3f / %.3f" % [
				float(bucket["height_min"]),
				float(bucket["height_total"]) / int(bucket["height"]),
				float(bucket["height_max"]),
			],
			float(bucket["floor_total"]) / stated, int(bucket["floor_slack"]),
		])

	var preference_stated := 0
	for purpose in purposes:
		preference_stated += int(Dictionary(intents[purpose])["preference"])
	print("\n  `preference_source` other than \"none\": %d of %d. Nothing supplies" % [
		preference_stated, total,
	])
	print("  a tactical preference yet, and the field exists so that when one does")
	print("  the marker takes a new value and the record does not grow a new shape.")


## ----------------------------------------------------------------- part four
##
## `PLATFORM_CONTACT.md` section 4b's *first* traced defect, in metres.
##
## > **The controlled dig has no setting target at all.** All three sites aim at
## > `contact + (0.03–0.04, −0.03 to −0.05)` -- about 0.8 m from where the ball
## > was dug. **The setter's position is never consulted.**
##
## Slice 1 published the anchor and the intended recipient side by side, which is
## what makes this measurable rather than anecdotal: the record names the setter
## and then aims somewhere the setter is not, and the gap between those two is a
## number nobody had.
func _collect_seat_gap(manager: Object, result: Resource) -> void:
	var lineup: RotationLineup = manager.current_lineup()
	var plan: Resource = manager.defensive_plans.get(
		lineup.rotation_number
	) if lineup != null else null
	var home_seat := Vector2(0.50, 0.60)
	if plan != null and lineup != null:
		home_seat = plan.setter_release_target(lineup.active_setter_id())
	var opponent_seat: Vector2 = \
		RallySimulatorScript._opponent_setter_release_target(manager.opponent_team)
	for entry in result.events:
		var event := entry as RallyEvent
		if event == null:
			continue
		var record: Dictionary = event.metadata.get("platform_intent", {})
		if record.is_empty():
			continue
		var purpose := str(record.get("purpose", ""))
		if purpose == "attack_coverage":
			continue
		var seat := home_seat if str(event.metadata.get("side", "")) == "home" \
			else opponent_seat
		var anchor := Vector2(record.get("target_anchor", seat))
		var gap := Vector2(
			(anchor.x - seat.x) * COURT_WIDTH_METERS,
			(anchor.y - seat.y) * COURT_LENGTH_METERS,
		).length()
		var bucket: Array = _anchor_to_seat.get(purpose, [])
		bucket.append(gap)
		_anchor_to_seat[purpose] = bucket


func _anchor_against_the_seat() -> void:
	print("\n" + "=".repeat(78))
	print("PART 4 -- how far the anchor sits from the recipient it names")
	print("=".repeat(78))
	print("  Section 4b, in metres. A contact that names the setter and then aims")
	print("  somewhere the setter is not has said two contradictory things, and")
	print("  until slice 1 published both there was no way to count it.\n")
	var purposes: Array = _anchor_to_seat.keys()
	purposes.sort()
	print("  %-18s %-7s %-9s %-9s %-9s %-9s" % [
		"purpose", "n", "min m", "p50 m", "max m", "mean m",
	])
	for purpose in purposes:
		var stats := _stats(_anchor_to_seat[purpose])
		print("  %-18s %-7d %-9.3f %-9.3f %-9.3f %-9.3f" % [
			str(purpose), int(stats.n), stats.min, stats.p50, stats.max,
			stats.mean,
		])
	print("")
	print("  The reception is the control: it aims *at* the seat by construction,")
	print("  offset only by `_desired_pass_target`'s overpass safety margin, so its")
	print("  row is what a small honest gap looks like. Whatever the dig's row")
	print("  reads above that is the distance between what it says it wants and")
	print("  where it throws the ball.")


func _stats(values: Array) -> Dictionary:
	if values.is_empty():
		return {"n": 0, "min": 0.0, "p50": 0.0, "max": 0.0, "mean": 0.0}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted:
		total += float(value)
	return {
		"n": sorted.size(),
		"min": float(sorted[0]),
		"p50": float(sorted[sorted.size() / 2]),
		"max": float(sorted[sorted.size() - 1]),
		"mean": total / sorted.size(),
	}
