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

const FIRST_SEED: int = 23000
const RALLIES_PER_SERVER: int = 300


func _initialize() -> void:
	_report(_sweep())
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
