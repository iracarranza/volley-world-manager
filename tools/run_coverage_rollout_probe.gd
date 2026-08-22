extends SceneTree

## M4: paired retired-legacy / physical attack-coverage rollout.
##
##     godot --headless --path . \
##       --script res://tools/run_coverage_rollout_probe.gd
##
## The mirror of `run_platform_dig_rollout_probe.gd` for the third and last
## platform-contact family that still fabricated its outgoing ball: attack
## coverage. It opens only the shared physical platform path (the same flag and
## development override the dig rollout uses) and does not tune against the
## terminal-outcome delta it reports -- counts and rates here are observational.
##
## What is being certified is that a successful coverage contact now owns an
## authoritative free flight instead of a `_ensure_event_trajectories` fabrication
## at a fixed 0.58 s / 1.8 m / 1.0 m, that its intended recipient is exactly the
## actor the existing second-contact policy names (never the coverer), that the
## launch is immutable and the realised segment a prefix, and that M5 interception
## -- not the launch -- decides who touches the ball next, so the intended actor
## may miss, a teammate may intercept, or the ball may floor/sail/cross.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const FreeFlightInterception := preload(
	"res://scripts/simulation/free_flight_interception_system.gd"
)

const FIRST_SEED: int = 41000
const RALLIES_PER_SERVER: int = 700
## The fabricated coverage ball's signature, retired by this rollout.
const LEGACY_DURATION: float = 0.58
const LEGACY_APEX: float = 1.80
const LEGACY_HEIGHT: float = 1.00

var failures: int = 0


func _initialize() -> void:
	var legacy := _arm(false)
	var physical := _arm(true)
	_print_summary(legacy, physical)
	_gate(
		int(legacy.owned) == 0,
		"the debug legacy arm publishes no owned coverage ball",
	)
	_gate(
		int(physical.successful) > 0
			and int(physical.owned) == int(physical.successful),
		"every successful coverage owns the shared physical launch",
	)
	_gate(
		int(physical.authoritative_free_flights) == int(physical.owned),
		"every owned coverage publishes one authoritative free flight",
	)
	_gate(
		int(physical.launch_mutations) == 0,
		"the coverage launch is never rewritten by a later interception",
	)
	_gate(
		int(physical.prefix_failures) == 0,
		"every realised coverage segment is a prefix of its free flight",
	)
	_gate(
		int(physical.recipient_is_coverer) == 0,
		"the intended recipient is never the coverer",
	)
	_gate(
		int(physical.recipient_available) == int(physical.owned),
		"the intended recipient is a legal, available second-contact actor",
	)
	_gate(
		int(physical.interceptor_is_coverer) == 0,
		"the coverer cannot also take the contact after their own cover",
	)
	_gate(
		int(physical.alternate_interceptors) > 0,
		"a non-intended teammate can intercept the coverage ball en route",
	)
	_gate(
		int(physical.intended_misses) > 0,
		"an intended recipient without an opportunity does not end the flight",
	)
	_gate(
		int(physical.bound_violations) == 0,
		"every coverage launch stays inside the T1--T3 outgoing-speed bound",
	)
	_gate(
		int(physical.legacy_signatures) == 0,
		"no owned coverage ball carries the retired 0.58 s / 1.8 m / 1.0 m shape",
	)
	_gate(
		int(physical.sides.get("home", 0)) > 0
			and int(physical.sides.get("opponent", 0)) > 0,
		"both sides launch physical coverage balls",
	)
	_gate(
		_terminal_reason(Vector2(0.50, 0.80), Vector3(1.0, 2.0, 0.0)) == "floor",
		"an uncontrolled coverage launch in court terminates on the floor",
	)
	_gate(
		_terminal_reason(Vector2(0.95, 0.80), Vector3(8.0, 2.0, 0.0)) == "out",
		"an uncontrolled coverage launch over a boundary terminates out",
	)
	_gate(
		_terminal_reason(Vector2(0.50, 0.55), Vector3(0.0, 0.0, -4.0)) == "net",
		"an uncontrolled coverage launch below the tape terminates at the net",
	)
	if failures == 0:
		print("\nPASS: physical attack-coverage rollout gates")
		quit(0)
	else:
		push_error("FAIL: %d physical attack-coverage rollout gates" % failures)
		quit(1)


func _arm(open_physical: bool) -> Dictionary:
	var report := {
		"rallies": 0,
		"coverage": 0,
		"successful": 0,
		"owned": 0,
		"fabricated": 0,
		"authoritative_free_flights": 0,
		"launch_mutations": 0,
		"prefix_failures": 0,
		"recipient_is_coverer": 0,
		"recipient_available": 0,
		"interceptor_is_coverer": 0,
		"alternate_interceptors": 0,
		"intended_misses": 0,
		"bound_violations": 0,
		"legacy_signatures": 0,
		"resolutions": {},
		"sides": {},
	}
	for serving_home in [true, false]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + RALLIES_PER_SERVER):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var rally: Resource = manager.resolve_active_rally(
				seed_value, false, open_physical, not open_physical
			)
			if rally != null:
				report.rallies += 1
				_scan(rally, report)
			manager.free()
	return report


func _scan(rally: Resource, report: Dictionary) -> void:
	var events: Array = rally.events
	for index in range(events.size()):
		var event: Resource = events[index]
		if int(event.event_type) != RallyEventScript.EventType.ATTACK_COVERAGE:
			continue
		report.coverage += 1
		if not bool(event.success):
			continue
		report.successful += 1
		var meta: Dictionary = event.metadata
		var platform: Dictionary = meta.get("platform_contact", {})
		var owned := str(platform.get("source", "")) == "shared_physical_platform"
		if not owned:
			report.fabricated += 1
			continue
		report.owned += 1
		var side := str(meta.get("side", "?"))
		report.sides[side] = int(report.sides.get(side, 0)) + 1
		var free_flight: Dictionary = meta.get("authoritative_free_flight", {})
		if str(free_flight.get("trajectory_role", "")) \
				== "authoritative_free_flight":
			report.authoritative_free_flights += 1
		## Launch immutability: the ball the platform launched is the ball that
		## flies. `_stamp_free_flight_resolution` may have replaced the event's
		## displayed `outgoing_trajectory` with a realised prefix, but the
		## authoritative flight and the platform record keep the original launch.
		var launched := Vector3(platform.get("realised_velocity_mps", Vector3.ZERO))
		var flown := Vector3(free_flight.get("launch_velocity_mps", Vector3.ZERO))
		if launched.distance_to(flown) > 0.0001:
			report.launch_mutations += 1
		## Bound: the realised launch never exceeds what the model said the contact
		## could produce.
		if launched.length() > float(platform.get(
			"maximum_outgoing_speed_mps", 0.0
		)) + 0.0001:
			report.bound_violations += 1
		## The retired fabrication's exact shape must not reappear on an owned ball.
		var traj: Dictionary = free_flight
		if _is_legacy_signature(traj):
			report.legacy_signatures += 1
		## Intent is the second-contact policy's actor, never the coverer, and it
		## is a legal available candidate on the covering side.
		var intent: Dictionary = meta.get("platform_intent", {})
		var recipient_id := int(intent.get("intended_recipient_id", -1))
		if recipient_id == int(event.actor_id):
			report.recipient_is_coverer += 1
		if recipient_id >= 0 and recipient_id != int(event.actor_id):
			report.recipient_available += 1
		## M5 decides the actual next contact against the flight.
		var resolution := str(meta.get("free_flight_resolution", "unresolved"))
		report.resolutions[resolution] = int(
			report.resolutions.get(resolution, 0)
		) + 1
		var interceptor_id := int(meta.get("realised_interceptor_id", -1))
		if resolution == "intercepted":
			if interceptor_id == int(event.actor_id):
				report.interceptor_is_coverer += 1
			if interceptor_id >= 0 and interceptor_id != recipient_id:
				report.alternate_interceptors += 1
			var realised: Dictionary = meta.get("outgoing_trajectory", {})
			if str(realised.get("trajectory_role", "")) != "realised_segment" \
					or str(realised.get("authoritative_flight_id", "")) \
						!= str(free_flight.get("authoritative_flight_id", "")):
				report.prefix_failures += 1
		if not bool(meta.get("intended_setter_had_opportunity", true)):
			report.intended_misses += 1


func _is_legacy_signature(traj: Dictionary) -> bool:
	return absf(float(traj.get("duration", -1.0)) - LEGACY_DURATION) < 0.001 \
		and absf(float(traj.get("apex_height_meters", -1.0)) - LEGACY_APEX) < 0.001 \
		and absf(float(traj.get("start_height_meters", -1.0)) - LEGACY_HEIGHT) < 0.001 \
		and absf(float(traj.get("end_height_meters", -1.0)) - LEGACY_HEIGHT) < 0.001


## The same uncontrolled-terminal check the dig rollout uses, on the shared
## interception model, so the coverage probe certifies the terminal vocabulary
## itself and not only what this population happened to hit.
func _terminal_reason(start: Vector2, launch: Vector3) -> String:
	var flight := FreeFlightInterception.from_launch(
		"probe", start, 0.95, launch, 0.0,
		"coverage-terminal:%s:%s" % [str(start), str(launch)],
	)
	## The terminal is discovered by resolving the flight against no claimants,
	## the same way `_stamp_free_flight_resolution` reaches it live.
	var physical := FreeFlightInterception.opportunities(flight, [])
	return str(Dictionary(physical.get("terminal", {})).get("reason", "missing"))


func _print_summary(legacy: Dictionary, physical: Dictionary) -> void:
	print("=".repeat(78))
	print("PAIRED ATTACK-COVERAGE ROLLOUT")
	print("=".repeat(78))
	print("  legacy arm:   %d rallies | coverage %d | successful %d | owned %d | fabricated %d"
		% [int(legacy.rallies), int(legacy.coverage), int(legacy.successful),
			int(legacy.owned), int(legacy.fabricated)])
	print("  physical arm: %d rallies | coverage %d | successful %d | owned %d | fabricated %d"
		% [int(physical.rallies), int(physical.coverage), int(physical.successful),
			int(physical.owned), int(physical.fabricated)])
	print("  physical: authoritative flights %d | launch mutations %d | prefix failures %d"
		% [int(physical.authoritative_free_flights),
			int(physical.launch_mutations), int(physical.prefix_failures)])
	print("  physical: recipient==coverer %d | recipient available %d | interceptor==coverer %d"
		% [int(physical.recipient_is_coverer), int(physical.recipient_available),
			int(physical.interceptor_is_coverer)])
	print("  physical: alternate interceptors %d | intended misses %d | bound violations %d | legacy shapes %d"
		% [int(physical.alternate_interceptors), int(physical.intended_misses),
			int(physical.bound_violations), int(physical.legacy_signatures)])
	print("  physical sides: %s" % str(physical.sides))
	print("  physical resolutions: %s" % str(physical.resolutions))
	print("=".repeat(78))


func _gate(passed: bool, description: String) -> void:
	if passed:
		print("  PASS  %s" % description)
	else:
		failures += 1
		print("  FAIL  %s" % description)
