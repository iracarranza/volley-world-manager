extends SceneTree

## M7 / P4 -- do required actions overlap the ball phases that precede them?
##
##     godot --headless --path . \
##       --script res://tools/run_continuous_action_probe.gd
##
## The packet's P4 says this stage "proves the continuous-action **architecture**,
## not visual polish", and its closure criterion is that "every contact samples
## the state those actions produced". So each gate below asks whether an action
## that must have begun earlier can be shown to have begun earlier -- from the
## resolver's own published record, not from a drawing.
##
## The one that needed a field before it could be asked at all is C6. "Early
## arrivals finish and wait" is unfalsifiable while a movement publishes only a
## destination: an actor who arrived in a third of the window and one who took
## all of it look identical. `_travel_intent` now publishes `traversal_seconds`
## against `window_seconds`, so the question has an answer, and the answer is a
## population rather than a yes.
##
## **These are gates, not observations.** Each asserts a structural claim the
## first draft is supposed to have made true. Rates and distributions are printed
## for context and none of them is asserted.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const FIRST_SEED: int = 74000
const RALLIES_PER_SERVER: int = 200

## Anything shorter than this is a voli who was already standing on their mark,
## not a journey. Below it, "arrived early" is arithmetic on nothing.
const REAL_JOURNEY_SECONDS: float = 0.02

var failures: int = 0


func _initialize() -> void:
	var report := _run()
	_print(report)
	_gate(
		int(report.journeys) > 200,
		"off-ball journeys are published with a duration at all",
	)
	_gate(
		int(report.stretched) == 0,
		"no journey is stretched to fill its window",
	)
	_gate(
		int(report.early_arrivals) > 0,
		"a voli can arrive before the ball and wait",
	)
	_gate(
		int(report.ran_out) > 0,
		"a voli can run out of window and stop where they got to",
	)
	_gate(
		int(report.blocker_journeys) > 0,
		"blockers are moving before the attack contact, not standing up at it",
	)
	_gate(
		int(report.defender_journeys) > 0,
		"floor defenders establish before the swing",
	)
	_gate(
		int(report.setter_staged) > 0,
		"the next setter is staged on the contact before theirs",
	)
	_gate(
		int(report.hitter_staged) > 0,
		"the hitter's approach start is published on the set, before the attack",
	)
	_gate(
		int(report.recovery_carried) > 0,
		"a contact leaves recovery debt that the next leg still owes",
	)
	if failures == 0:
		print("\nPASS: continuous-action gates")
		quit(0)
		return
	push_error("FAIL: %d continuous-action gates" % failures)
	quit(1)


func _gate(condition: bool, description: String) -> void:
	if condition:
		print("  ok    %s" % description)
		return
	failures += 1
	print("  FAIL  %s" % description)


func _run() -> Dictionary:
	var report := {
		"rallies": 0,
		"journeys": 0,
		"early_arrivals": 0,
		"ran_out": 0,
		"stretched": 0,
		"blocker_journeys": 0,
		"defender_journeys": 0,
		"setter_staged": 0,
		"hitter_staged": 0,
		"recovery_carried": 0,
		"slack_total": 0.0,
	}
	for serving_home in [true, false]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + RALLIES_PER_SERVER):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var rally: Resource = manager.resolve_active_rally(seed_value)
			if rally != null:
				report.rallies += 1
				_scan(rally, report)
			manager.free()
	return report


func _scan(rally: Resource, report: Dictionary) -> void:
	for event in rally.events:
		var meta: Dictionary = event.metadata
		var kind := int(event.event_type)
		if meta.has("staged_next_actor_id"):
			report.setter_staged += 1
		if meta.has("staged_next_position") \
				and kind == RallyEventScript.EventType.SET:
			report.hitter_staged += 1
		if not Dictionary(meta.get("recovery_debt", {})).is_empty():
			report.recovery_carried += 1
		for key in ["home_phase_intents", "opponent_phase_intents"]:
			var intents: Dictionary = meta.get(key, {})
			for raw_player_id in intents:
				var record: Dictionary = intents[raw_player_id]
				if not record.has("traversal_seconds"):
					continue
				var traversal := float(record["traversal_seconds"])
				var window := float(record.get("window_seconds", 0.0))
				if traversal <= REAL_JOURNEY_SECONDS or window <= 0.0:
					continue
				report.journeys += 1
				## **The C6 assertion.** A traversal longer than its own window is
				## the shape of a movement stretched to fill the ball's flight,
				## which is the thing the rule forbids. `_reached_point` bisects
				## to exactly the point the window buys, so a cut-short journey
				## lands *on* the window and never past it -- the tolerance below
				## is float noise, not a band.
				if traversal > window + 0.0005:
					report.stretched += 1
				elif traversal < window - 0.0005:
					report.early_arrivals += 1
					report.slack_total += window - traversal
				else:
					report.ran_out += 1
				if kind == RallyEventScript.EventType.ATTACK:
					report.defender_journeys += 1
				elif kind == RallyEventScript.EventType.BLOCK:
					report.blocker_journeys += 1


func _print(report: Dictionary) -> void:
	print("\ncontinuous action -- %d rallies\n" % report.rallies)
	print("  off-ball journeys with a duration   %d" % int(report.journeys))
	print("    arrived early and waited          %d" % int(report.early_arrivals))
	print("    ran out of window                 %d" % int(report.ran_out))
	print("    stretched past the window         %d" % int(report.stretched))
	if int(report.early_arrivals) > 0:
		print("    mean slack after arriving         %.3f s" % (
			float(report.slack_total) / float(report.early_arrivals)
		))
	print("  journeys on the attack event        %d" % int(report.defender_journeys))
	print("  journeys on the block event         %d" % int(report.blocker_journeys))
	print("  contacts staging the next actor     %d" % int(report.setter_staged))
	print("  sets publishing a hitter start      %d" % int(report.hitter_staged))
	print("  contacts carrying recovery debt     %d" % int(report.recovery_carried))
	print("")
