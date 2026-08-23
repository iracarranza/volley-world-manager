extends SceneTree

## M4: paired retired-legacy / physical serve-reception rollout.
##
##     godot --headless --path . \
##       --script res://tools/run_reception_rollout_probe.gd
##
## The third and last platform family to move onto the shared physical authority,
## after the controlled dig and attack coverage. Reception is the hard one: it
## feeds the first-ball set path, which had no interception branch, so this
## certifies a retrofit rather than a wiring change. It opens only physical
## reception (its own decoupled development override) and does not tune against
## the terminal-outcome delta it reports.
##
## Certified: a successful reception owns one authoritative outgoing free flight
## through the shared resolver; the intended setter is soft intent; M5 -- not the
## launch -- decides the actual second contact, so the intended setter may miss,
## an alternate/emergency setter may intercept, or the ball may floor, sail,
## cross the net (opponent first contact) or hit the tape; the SET consumes the
## realised intercepted prefix by identity; launches stay inside the T1--T3 bound;
## and both serving sides share the semantics.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const FreeFlightInterception := preload(
	"res://scripts/simulation/free_flight_interception_system.gd"
)

const FIRST_SEED: int = 52000
const RALLIES_PER_SERVER: int = 700

var failures: int = 0


func _initialize() -> void:
	var legacy := _arm(false)
	var physical := _arm(true)
	_print_summary(legacy, physical)
	_gate(
		int(legacy.owned) == 0,
		"the legacy arm publishes no owned reception free flight",
	)
	_gate(
		int(physical.successful) > 0
			and int(physical.owned) == int(physical.successful),
		"every successful physical reception owns the shared launch",
	)
	_gate(
		int(physical.authoritative_free_flights) == int(physical.owned),
		"every owned reception publishes one authoritative free flight",
	)
	_gate(
		int(physical.launch_mutations) == 0,
		"the reception launch is never rewritten by a later interception",
	)
	_gate(
		int(physical.prefix_failures) == 0,
		"every realised reception segment is a prefix of its free flight",
	)
	_gate(
		int(physical.chain_breaks) == 0,
		"the set incoming trajectory is the reception's realised prefix by identity",
	)
	_gate(
		int(physical.recipient_is_receiver) == 0,
		"the intended setter is never the receiver",
	)
	_gate(
		int(physical.interceptor_is_receiver) == 0,
		"the receiver cannot also take the second contact",
	)
	_gate(
		int(physical.alternate_interceptors) > 0,
		"a non-intended setter can take the reception en route",
	)
	_gate(
		int(physical.intended_misses) > 0,
		"an intended setter without an opportunity does not end the flight",
	)
	_gate(
		int(physical.bound_violations) == 0,
		"every reception launch stays inside the T1--T3 outgoing-speed bound",
	)
	_gate(
		int(physical.sides.get("home", 0)) > 0
			and int(physical.sides.get("opponent", 0)) > 0,
		"both serving sides launch physical receptions",
	)
	_gate(
		int(physical.resolutions.get("floor", 0)) > 0,
		"a reception no setter reaches terminates truthfully on the floor",
	)
	_gate(
		_terminal_reason(Vector2(0.50, 0.30), Vector3(1.0, 2.0, 0.0)) == "floor"
			and _terminal_reason(Vector2(0.95, 0.30), Vector3(9.0, 2.0, 0.0)) == "out"
			and _terminal_reason(Vector2(0.50, 0.46), Vector3(0.0, 0.0, 4.0)) == "net",
		"the uncontrolled reception terminal vocabulary is floor / out / net",
	)
	if failures == 0:
		print("\nPASS: physical serve-reception rollout gates")
		quit(0)
	else:
		push_error("FAIL: %d physical serve-reception rollout gates" % failures)
		quit(1)


func _arm(open_physical: bool) -> Dictionary:
	var report := {
		"rallies": 0, "receptions": 0, "successful": 0, "owned": 0,
		"fabricated": 0, "authoritative_free_flights": 0, "launch_mutations": 0,
		"prefix_failures": 0, "chain_breaks": 0, "recipient_is_receiver": 0,
		"interceptor_is_receiver": 0, "alternate_interceptors": 0,
		"intended_misses": 0, "bound_violations": 0,
		"resolutions": {}, "sides": {},
	}
	for serving_home in [true, false]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + RALLIES_PER_SERVER):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var rally: Resource = manager.resolve_active_rally(
				seed_value, false, false,
				not open_physical, open_physical,
			)
			if rally != null:
				report.rallies += 1
				_scan(rally, report, open_physical)
			manager.free()
	return report


func _scan(rally: Resource, report: Dictionary, open_physical: bool) -> void:
	var events: Array = rally.events
	var last_ball := {}
	for index in range(events.size()):
		var event: Resource = events[index]
		var kind := int(event.event_type)
		if kind == RallyEventScript.EventType.RECEPTION:
			report.receptions += 1
			if not bool(event.success):
				last_ball = Dictionary(event.metadata.get("outgoing_trajectory", {}))
				continue
			report.successful += 1
			var meta: Dictionary = event.metadata
			var free_flight: Dictionary = meta.get("authoritative_free_flight", {})
			var owned := str(free_flight.get("trajectory_role", "")) \
				== "authoritative_free_flight"
			if not owned:
				report.fabricated += 1
				last_ball = Dictionary(meta.get("outgoing_trajectory", {}))
				continue
			report.owned += 1
			report.authoritative_free_flights += 1
			var side := str(meta.get("side", "?"))
			report.sides[side] = int(report.sides.get(side, 0)) + 1
			var platform: Dictionary = meta.get("platform_contact", {})
			var launched := Vector3(platform.get("realised_velocity_mps", Vector3.ZERO))
			var flown := Vector3(free_flight.get("launch_velocity_mps", Vector3.ZERO))
			if launched.distance_to(flown) > 0.0001:
				report.launch_mutations += 1
			if launched.length() > float(platform.get(
				"maximum_outgoing_speed_mps", 0.0
			)) + 0.0001:
				report.bound_violations += 1
			var intent: Dictionary = meta.get("platform_intent", {})
			var recipient_id := int(intent.get("intended_recipient_id", -1))
			if recipient_id == int(event.actor_id):
				report.recipient_is_receiver += 1
			var resolution := str(meta.get("free_flight_resolution", "unresolved"))
			report.resolutions[resolution] = int(
				report.resolutions.get(resolution, 0)
			) + 1
			var interceptor_id := int(meta.get("realised_interceptor_id", -1))
			if resolution == "intercepted":
				if interceptor_id == int(event.actor_id):
					report.interceptor_is_receiver += 1
				if interceptor_id >= 0 and interceptor_id != recipient_id:
					report.alternate_interceptors += 1
				var realised: Dictionary = meta.get("outgoing_trajectory", {})
				if str(realised.get("trajectory_role", "")) != "realised_segment" \
						or str(realised.get("authoritative_flight_id", "")) \
							!= str(free_flight.get("authoritative_flight_id", "")):
					report.prefix_failures += 1
			if not bool(meta.get("intended_setter_had_opportunity", true)):
				report.intended_misses += 1
			last_ball = Dictionary(meta.get("outgoing_trajectory", {}))
			continue
		if kind == RallyEventScript.EventType.SET and open_physical:
			var incoming: Dictionary = event.metadata.get(
				"incoming_trajectory",
				event.metadata.get("incoming_pass_trajectory", {}),
			)
			## Only check the chain when the feeding ball was a physical reception
			## prefix; a legacy dig/coverage feed is a different family's concern.
			if not last_ball.is_empty() and not incoming.is_empty() \
					and str(last_ball.get("trajectory_role", "")) == "realised_segment":
				if not _same_ball(last_ball, incoming):
					report.chain_breaks += 1
			last_ball = Dictionary(event.metadata.get("outgoing_trajectory", {}))
			continue
		var published: Dictionary = event.metadata.get("outgoing_trajectory", {})
		if not published.is_empty():
			last_ball = published


func _same_ball(first: Dictionary, second: Dictionary) -> bool:
	return Vector2(first.get("start_position", Vector2.ZERO)).is_equal_approx(
			Vector2(second.get("start_position", Vector2.ONE))
		) and Vector2(first.get("end_position", Vector2.ZERO)).is_equal_approx(
			Vector2(second.get("end_position", Vector2.ONE))
		) and is_equal_approx(
			float(first.get("duration", -1.0)), float(second.get("duration", -2.0))
		)


func _terminal_reason(start: Vector2, launch: Vector3) -> String:
	var flight := FreeFlightInterception.from_launch(
		"reception", start, 0.95, launch, 0.0,
		"reception-terminal:%s:%s" % [str(start), str(launch)],
	)
	var physical := FreeFlightInterception.opportunities(flight, [])
	return str(Dictionary(physical.get("terminal", {})).get("reason", "missing"))


func _print_summary(legacy: Dictionary, physical: Dictionary) -> void:
	print("=".repeat(78))
	print("PAIRED SERVE-RECEPTION ROLLOUT")
	print("=".repeat(78))
	print("  legacy arm:   %d rallies | receptions %d | successful %d | owned %d"
		% [int(legacy.rallies), int(legacy.receptions), int(legacy.successful),
			int(legacy.owned)])
	print("  physical arm: %d rallies | receptions %d | successful %d | owned %d | fabricated %d"
		% [int(physical.rallies), int(physical.receptions), int(physical.successful),
			int(physical.owned), int(physical.fabricated)])
	print("  physical: authoritative %d | launch mutations %d | prefix failures %d | chain breaks %d"
		% [int(physical.authoritative_free_flights), int(physical.launch_mutations),
			int(physical.prefix_failures), int(physical.chain_breaks)])
	print("  physical: recipient==receiver %d | interceptor==receiver %d | alternate %d | intended misses %d"
		% [int(physical.recipient_is_receiver), int(physical.interceptor_is_receiver),
			int(physical.alternate_interceptors), int(physical.intended_misses)])
	print("  physical: bound violations %d | sides %s"
		% [int(physical.bound_violations), str(physical.sides)])
	print("  physical resolutions: %s" % str(physical.resolutions))
	print("=".repeat(78))


func _gate(passed: bool, description: String) -> void:
	if passed:
		print("  PASS  %s" % description)
	else:
		failures += 1
		print("  FAIL  %s" % description)
