extends SceneTree

## M4/M5: paired retired-legacy / production controlled-dig rollout.
##
##     godot --headless --path . \
##       --script res://tools/run_platform_dig_rollout_probe.gd
##
## This opens only the physical controlled-dig path. It does not open the
## continuous reception/setter/attack/block stack, and it does not tune against
## the terminal-outcome delta it reports.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const FreeFlightInterception := preload(
	"res://scripts/simulation/free_flight_interception_system.gd"
)

const FIRST_SEED: int = 23000
const RALLIES_PER_SERVER: int = 300

var failures: int = 0


func _initialize() -> void:
	var legacy := _arm(false)
	var physical := _arm(true)
	_print_outcomes(legacy, physical)
	_print_contacts(legacy, physical)
	_gate(
		int(legacy.promoted) == 0,
		"the debug legacy arm publishes no promoted platform dig",
	)
	_gate(
		int(physical.successful_digs) > 0
			and int(physical.promoted) == int(physical.successful_digs),
		"every successful controlled dig uses the shared physical launch",
	)
	_gate(
		int(physical.failed_with_launch) == 0,
		"a failed dig cannot manufacture an outgoing physical ball",
	)
	_gate(
		int(physical.complete_trajectories) == int(physical.promoted),
		"every promoted dig publishes one complete resolved trajectory",
	)
	_gate(
		int(physical.event_endpoint_matches) == int(physical.promoted),
		"the DIG event and its outgoing trajectory end at the same point",
	)
	_gate(
		int(physical.authoritative_free_flights) == int(physical.promoted),
		"every promoted dig publishes one authoritative free flight",
	)
	_gate(
		int(physical.prefix_failures) == 0,
		"every realised segment is a prefix of its authoritative free flight",
	)
	_gate(
		int(physical.launch_mutations) == 0,
		"later interception never rewrites the platform launch",
	)
	_gate(
		int(physical.duplicate_contact_actors) == 0,
		"the digger cannot also take the second contact",
	)
	_gate(
		int(physical.next_actor_mismatches) == 0,
		"the realised interceptor is the next contact actor exactly once",
	)
	_gate(
		int(physical.unreachable_intended_terminations) == 0,
		"an intended setter without an opportunity cannot terminate the flight",
	)
	_gate(
		int(physical.alternate_interceptors) > 0,
		"a viable non-intended voli can intercept the ball en route",
	)
	_gate(
		_terminal_reason(Vector2(0.50, 0.80), Vector3(1.0, 2.0, 0.0)) \
			== "floor",
		"an uncontrolled in-court launch terminates on the floor",
	)
	_gate(
		_terminal_reason(Vector2(0.95, 0.80), Vector3(8.0, 2.0, 0.0)) \
			== "out",
		"an uncontrolled launch crossing a court boundary terminates out",
	)
	_gate(
		_terminal_reason(Vector2(0.50, 0.55), Vector3(0.0, 0.0, -4.0)) \
			== "net",
		"an uncontrolled launch below tape height terminates at the net",
	)
	if failures == 0:
		print("\nPASS: physical controlled-dig rollout gates")
		quit(0)
	else:
		push_error("FAIL: %d physical controlled-dig rollout gates" % failures)
		quit(1)


func _arm(open_physical_dig: bool) -> Dictionary:
	var report := {
		"rallies": 0,
		"events": 0,
		"outcomes": {},
		"successful_digs": 0,
		"failed_digs": 0,
		"promoted": 0,
		"failed_with_launch": 0,
		"complete_trajectories": 0,
		"event_endpoint_matches": 0,
		"authoritative_free_flights": 0,
		"intercepted": 0,
		"alternate_interceptors": 0,
		"intended_misses": 0,
		"prefix_failures": 0,
		"launch_mutations": 0,
		"duplicate_contact_actors": 0,
		"next_actor_mismatches": 0,
		"unreachable_intended_terminations": 0,
		"unresolved_overpasses": 0,
		"terminal_reasons": {},
		"intent_satisfiable": 0,
		"reaches_target_plane": 0,
		"bindings": {},
		"speeds": [],
		"angles": [],
		"apexes": [],
		"durations": [],
		"target_errors": [],
	}
	for serving_home in [true, false]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + RALLIES_PER_SERVER):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var rally: Resource = manager.resolve_active_rally(
				seed_value, false, open_physical_dig, not open_physical_dig
			)
			if rally == null:
				manager.free()
				continue
			report.rallies += 1
			report.events += rally.events.size()
			var outcome := str(rally.terminal_outcome)
			report.outcomes[outcome] = int(report.outcomes.get(outcome, 0)) + 1
			for event_index in range(rally.events.size()):
				var event := rally.events[event_index] as RallyEvent
				if event == null \
						or event.event_type != RallyEventScript.EventType.DIG:
					continue
				if event.success:
					report.successful_digs += 1
				else:
					report.failed_digs += 1
				var platform: Dictionary = event.metadata.get("platform_contact", {})
				var trajectory: Dictionary = event.metadata.get("outgoing_trajectory", {})
				if not event.success and not trajectory.is_empty():
					report.failed_with_launch += 1
				if str(platform.get("source", "")) != "shared_physical_platform":
					continue
				report.promoted += 1
				var free_flight: Dictionary = event.metadata.get(
					"authoritative_free_flight", {}
				)
				if not free_flight.is_empty():
					report.authoritative_free_flights += 1
				var resolution := str(event.metadata.get(
					"free_flight_resolution", "missing"
				))
				if resolution == "intercepted":
					report.intercepted += 1
					var actual_id := int(event.metadata.get(
						"realised_interceptor_id", -1
					))
					var intended_value: Variant = Dictionary(event.metadata.get(
						"platform_intent", {}
					)).get("intended_recipient_id", -1)
					var intended_id := int(intended_value) \
						if intended_value is int else -1
					if actual_id != intended_id:
						report.alternate_interceptors += 1
					if not bool(event.metadata.get(
						"intended_setter_had_opportunity", false
					)):
						report.intended_misses += 1
						if actual_id == intended_id:
							report.unreachable_intended_terminations += 1
					if actual_id == event.actor_id:
						report.duplicate_contact_actors += 1
					if event_index + 1 >= rally.events.size() \
							or (rally.events[event_index + 1] as RallyEvent).event_type \
								!= RallyEventScript.EventType.SET \
							or (rally.events[event_index + 1] as RallyEvent).actor_id \
								!= actual_id:
						report.next_actor_mismatches += 1
					if not _is_prefix(free_flight, trajectory):
						report.prefix_failures += 1
					if not _same_launch(free_flight, trajectory):
						report.launch_mutations += 1
				else:
					report.terminal_reasons[resolution] = int(
						report.terminal_reasons.get(resolution, 0)
					) + 1
					if resolution == "crossed_net_unresolved":
						report.unresolved_overpasses += 1
				if bool(platform.get("intent_satisfiable", false)):
					report.intent_satisfiable += 1
				if bool(platform.get("reaches_target_plane", false)):
					report.reaches_target_plane += 1
				var binding := str(platform.get("binding_constraint", "missing"))
				report.bindings[binding] = int(report.bindings.get(binding, 0)) + 1
				var velocity := Vector3(platform.get(
					"realised_velocity_mps", Vector3.ZERO
				))
				report.speeds.append(velocity.length())
				report.angles.append(rad_to_deg(atan2(
					velocity.y, Vector2(velocity.x, velocity.z).length()
				)))
				report.apexes.append(float(event.metadata.get(
					"pass_apex_meters", 0.0
				)))
				report.durations.append(float(trajectory.get("duration", 0.0)))
				report.target_errors.append(float(event.metadata.get(
					"target_error_meters", 0.0
				)))
				if not trajectory.is_empty() \
						and trajectory.has("launch_vertical_mps") \
						and str(trajectory.get("height_source", "")) == "resolved" \
						and float(trajectory.get("duration", 0.0)) > 0.0:
					report.complete_trajectories += 1
				if Vector2(trajectory.get(
					"end_position", Vector2(-9.0, -9.0)
				)).is_equal_approx(event.end_position):
					report.event_endpoint_matches += 1
			manager.free()
	return report


func _print_outcomes(legacy: Dictionary, physical: Dictionary) -> void:
	print("=".repeat(90))
	print("M4 CONTROLLED-DIG PAIRED ROLLOUT -- OUTCOMES ARE DIAGNOSTIC, NOT TARGETS")
	print("=".repeat(90))
	var keys: Array = legacy.outcomes.keys()
	for key in physical.outcomes:
		if key not in keys:
			keys.append(key)
	keys.sort()
	print("  %-28s %8s %10s %8s" % ["terminal outcome", "closed", "physical", "delta"])
	for key in keys:
		var closed_count := int(legacy.outcomes.get(key, 0))
		var physical_count := int(physical.outcomes.get(key, 0))
		print("  %-28s %8d %10d %+8d" % [
			str(key), closed_count, physical_count, physical_count - closed_count,
		])
	print("\n  Closed: %d rallies / %d events" % [legacy.rallies, legacy.events])
	print("  Physical: %d rallies / %d events" % [physical.rallies, physical.events])
	print("  No acceptance bound reads these counts; they expose integration effects.")


func _print_contacts(legacy: Dictionary, physical: Dictionary) -> void:
	print("\n" + "=".repeat(90))
	print("CONTROLLED-DIG OWNERSHIP AND PLAUSIBILITY")
	print("=".repeat(90))
	print("  forced-legacy promoted:    %d / %d successful" % [
		legacy.promoted, legacy.successful_digs,
	])
	print("  physical rollout promoted:  %d / %d successful" % [
		physical.promoted, physical.successful_digs,
	])
	print("  failed digs with a launch:   %d / %d" % [
		physical.failed_with_launch, physical.failed_digs,
	])
	print("  authoritative free flights:  %d / %d" % [
		physical.authoritative_free_flights, physical.promoted,
	])
	print("  realised interceptions:      %d / %d" % [
		physical.intercepted, physical.promoted,
	])
	print("  intended setter misses:      %d" % physical.intended_misses)
	print("  alternate interceptors:      %d" % physical.alternate_interceptors)
	print("  uncontrolled terminals (observed, not exhaustive): %s" % _counts_text(
		physical.terminal_reasons
	))
	print("  intent simultaneously met:  %d / %d" % [
		physical.intent_satisfiable, physical.promoted,
	])
	print("  reaches target plane alive:  %d / %d" % [
		physical.reaches_target_plane, physical.promoted,
	])
	print("  binding constraints: %s" % _counts_text(physical.bindings))
	print("  launch speed min/p50/max: %s m/s" % _stats_text(physical.speeds))
	print("  launch angle min/p50/max: %s deg" % _stats_text(physical.angles))
	print("  apex height min/p50/max: %s m" % _stats_text(physical.apexes))
	print("  segment duration min/p50/max: %s s" % _stats_text(physical.durations))
	print("  horizontal target error min/p50/max: %s m" % \
		_stats_text(physical.target_errors))


func _is_prefix(free_flight: Dictionary, realised: Dictionary) -> bool:
	if free_flight.is_empty() or realised.is_empty():
		return false
	if str(realised.get("trajectory_role", "")) != "realised_segment" \
			or str(realised.get("authoritative_flight_id", "")) \
				!= str(free_flight.get("authoritative_flight_id", "")):
		return false
	var realised_end := float(realised.get("end_time", 0.0))
	if realised_end > float(free_flight.get("end_time", 0.0)) + 0.00001:
		return false
	var expected_position := FreeFlightInterception.position_at_time(
		free_flight, realised_end
	)
	var expected_height := FreeFlightInterception.height_at_time(
		free_flight, realised_end
	)
	return expected_position.distance_to(Vector2(realised.get(
		"end_position", Vector2(-9.0, -9.0)
	))) <= 0.00001 \
		and absf(expected_height - float(realised.get(
			"end_height_meters", -9.0
		))) <= 0.00001


func _same_launch(free_flight: Dictionary, realised: Dictionary) -> bool:
	for key in [
		"launch_speed_mps", "launch_angle_degrees", "launch_horizontal_mps",
		"launch_vertical_mps", "launch_gravity_mps2",
	]:
		if not is_equal_approx(
			float(free_flight.get(key, NAN)), float(realised.get(key, NAN))
		):
			return false
	return Vector3(free_flight.get(
		"launch_velocity_mps", Vector3(INF, INF, INF)
	)).is_equal_approx(Vector3(realised.get(
		"launch_velocity_mps", Vector3(-INF, -INF, -INF)
	)))


func _terminal_reason(contact: Vector2, velocity: Vector3) -> String:
	var free_flight := FreeFlightInterception.from_launch(
		"probe", contact, 0.95, velocity, 0.0,
		"terminal:%s:%s" % [str(contact), str(velocity)],
	)
	var physical := FreeFlightInterception.opportunities(free_flight, [])
	return str(Dictionary(physical.get("terminal", {})).get("reason", "missing"))


func _stats_text(values: Array) -> String:
	if values.is_empty():
		return "missing"
	var ordered := values.duplicate()
	ordered.sort()
	return "%.3f / %.3f / %.3f" % [
		float(ordered.front()),
		float(ordered[int((ordered.size() - 1) * 0.5)]),
		float(ordered.back()),
	]


func _counts_text(counts: Dictionary) -> String:
	var keys: Array = counts.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		parts.append("%s %d" % [str(key), int(counts[key])])
	return ", ".join(parts)


func _gate(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  %s" % label)
	else:
		failures += 1
		print("  FAIL  %s" % label)
