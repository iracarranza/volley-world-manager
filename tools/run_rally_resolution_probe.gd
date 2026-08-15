extends SceneTree

## Do the rally verdict and the ball the player sees describe the same point?
##
##     godot --headless --path . --script res://tools/run_rally_resolution_probe.gd
##
## This probe was added for two playback reports that are easy to wave away if
## they are measured separately from the resolution that produced them:
##
##   * roll shots that still rise implausibly high;
##   * a ball that lands out after touching the block but awards the point to
##     the blocking side.
##
## The height figures come from `BallPresentation.display_trajectory`, the same
## trajectory the match screen samples.  Block ownership is checked against the
## final endpoint of the block event's outgoing trajectory.  Once the block is
## the last touch, an endpoint outside the painted court must award the point to
## the attacking side, regardless of the contact's earlier `stuff`/`touch`
## classification.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const ApproachMechanicsScript := preload(
	"res://scripts/simulation/approach_mechanics_system.gd"
)

const RALLIES_PER_STARTING_SERVER: int = 600
const FIRST_SEED: int = 23000
const MAX_PLAUSIBLE_COVERAGE_SPEED_MPS: float = 8.0


func _initialize() -> void:
	var attacks := {}
	var out_block_contacts: Array[Dictionary] = []
	var ownership_failures: Array[Dictionary] = []
	var soft_block_contacts: Array[Dictionary] = []
	var routing_failures: Array[Dictionary] = []
	var tempo_counts := {}
	var tempo_failures: Array[Dictionary] = []
	var second_contact_checks := 0
	var second_contact_failures: Array[Dictionary] = []
	var missed_attacks_with_walls := 0
	var missing_jump_timing: Array[Dictionary] = []
	var deflection_motion: Array[Dictionary] = []
	var deflection_motion_failures: Array[Dictionary] = []
	var set_contact_depths := {}
	var set_path_outcomes := {}
	var set_path_failures: Array[Dictionary] = []
	for serving_home in [true, false]:
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		for sample in range(RALLIES_PER_STARTING_SERVER):
			manager.match_state.serving_home = serving_home
			var seed_value := FIRST_SEED + sample
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			_collect_attacks(result, seed_value, attacks)
			_collect_block_ownership(
				result, seed_value, out_block_contacts, ownership_failures,
				soft_block_contacts, routing_failures,
			)
			_collect_tempo_and_contact_rules(
				result, seed_value, tempo_counts, tempo_failures,
				second_contact_failures, missing_jump_timing,
			)
			second_contact_checks += int(result.analysis.get(
				"probe_second_contact_checks", 0
			))
			missed_attacks_with_walls += int(result.analysis.get(
				"probe_missed_attacks_with_walls", 0
			))
			_collect_deflection_motion(
				result, seed_value, deflection_motion,
				deflection_motion_failures,
			)
			_collect_set_contact_depths(
				result, seed_value, set_contact_depths, set_path_outcomes,
				set_path_failures,
			)
		manager.free()

	print("=== displayed attack apex ===")
	print("%-32s %6s %8s %8s %8s %8s %8s" % [
		"attack / launch", "n", "rise50", "rise90", "rise95",
		"apex95", "max apex",
	])
	var keys := attacks.keys()
	keys.sort()
	for key in keys:
		_print_attack_bucket(str(key), attacks[key])
	var all_rows: Array = attacks.get("ALL · all", []).duplicate()
	all_rows.sort_custom(func(a, b): return float(a.apex) > float(b.apex))
	if not all_rows.is_empty() and float(all_rows[0].apex) > 5.0:
		print("")
		print("highest displayed attacks above 5 m")
		for index in range(mini(10, all_rows.size())):
			var row: Dictionary = all_rows[index]
			if float(row.apex) <= 5.0:
				break
			_print_attack_case(row)
	var roll_rows: Array = attacks.get("ROLL · all", []).duplicate()
	roll_rows.sort_custom(func(a, b): return float(a.apex) > float(b.apex))
	if not roll_rows.is_empty():
		print("")
		print("highest displayed roll shots")
		for index in range(mini(10, roll_rows.size())):
			_print_attack_case(roll_rows[index])

	print("")
	print("=== out after a block contact ===")
	print("contacts: %d; wrong winner: %d" % [
		out_block_contacts.size(), ownership_failures.size(),
	])
	var out_kinds := {}
	for case in out_block_contacts:
		var key := "%s/%s/%s" % [case.side, case.outcome, case.terminal]
		out_kinds[key] = int(out_kinds.get(key, 0)) + 1
	var out_keys := out_kinds.keys()
	out_keys.sort()
	for key in out_keys:
		print("  %-38s %5d" % [key, int(out_kinds[key])])
	for index in range(mini(12, ownership_failures.size())):
		var case: Dictionary = ownership_failures[index]
		print(
			"  seed %d  block=%s/%s  end=(%.3f, %.3f)  winner=%s  expected=%s  terminal=%s"
			% [
				case.seed, case.side, case.outcome, case.end.x, case.end.y,
				"home" if case.home_won else "opponent",
				"home" if case.expected_home else "opponent", case.terminal,
			]
		)
	print("")
	print("=== playable touch behind the block ===")
	print("contacts: %d; routing/event failures: %d" % [
		soft_block_contacts.size(), routing_failures.size(),
	])
	for index in range(mini(12, routing_failures.size())):
		var case: Dictionary = routing_failures[index]
		print("  seed %d  block=%s/%s  end=(%.3f, %.3f)  next=%s/%s  %s" % [
			case.seed, case.side, case.outcome, case.end.x, case.end.y,
			case.next_type, case.next_side, case.reason,
		])

	print("")
	print("=== hitter-led tempo ===")
	var tempo_keys := tempo_counts.keys()
	tempo_keys.sort()
	for key in tempo_keys:
		print("  %-12s %5d" % [str(key), int(tempo_counts[key])])
	print("metadata/relation failures: %d" % tempo_failures.size())
	for index in range(mini(12, tempo_failures.size())):
		var case: Dictionary = tempo_failures[index]
		print("  seed %d %s actor=%d  %s" % [
			case.seed, case.side, case.actor_id, case.reason,
		])

	print("")
	print("=== contact ownership and block commitment ===")
	print("first-to-second contacts checked: %d; consecutive-actor failures: %d" % [
		second_contact_checks, second_contact_failures.size(),
	])
	print("missed attacks into a wall: %d; missing jump timing: %d" % [
		missed_attacks_with_walls, missing_jump_timing.size(),
	])
	for index in range(mini(12, second_contact_failures.size())):
		var case: Dictionary = second_contact_failures[index]
		print("  seed %d %s actor=%d  %s" % [
			case.seed, case.side, case.actor_id, case.reason,
		])
	for index in range(mini(12, missing_jump_timing.size())):
		var case: Dictionary = missing_jump_timing[index]
		print("  seed %d %s attacker=%d has wall but no jump timing" % [
			case.seed, case.side, case.actor_id,
		])

	print("")
	print("=== block-to-defense movement ===")
	var movement_speeds: Array = []
	var deflection_rises: Array = []
	var deflection_durations: Array = []
	for case in deflection_motion:
		movement_speeds.append(float(case.speed_mps))
		deflection_rises.append(float(case.rise_meters))
		deflection_durations.append(float(case.duration))
	movement_speeds.sort()
	deflection_rises.sort()
	deflection_durations.sort()
	print("pairs: %d; implausible movement: %d" % [
		deflection_motion.size(), deflection_motion_failures.size(),
	])
	print("  defender speed p50/p95/max: %.2f / %.2f / %.2f m/s" % [
		_at(movement_speeds, 0.50), _at(movement_speeds, 0.95),
		_at(movement_speeds, 1.0),
	])
	print("  deflection rise p50/p95/max: %.2f / %.2f / %.2f m" % [
		_at(deflection_rises, 0.50), _at(deflection_rises, 0.95),
		_at(deflection_rises, 1.0),
	])
	print("  deflection time p05/p50/p95: %.2f / %.2f / %.2f s" % [
		_at(deflection_durations, 0.05), _at(deflection_durations, 0.50),
		_at(deflection_durations, 0.95),
	])
	var highest_deflections := deflection_motion.duplicate()
	highest_deflections.sort_custom(
		func(a, b): return float(a.rise_meters) > float(b.rise_meters)
	)
	for index in range(mini(6, highest_deflections.size())):
		var case: Dictionary = highest_deflections[index]
		print("  high seed %d %s/%s %s rise=%.2f time=%.2f vY=%.2f dist=%.2f" % [
			case.seed, case.block_side, case.defense_side, case.outcome,
			case.rise_meters, case.duration, case.vertical_mps,
			case.ball_distance_meters,
		])
	for index in range(mini(12, deflection_motion_failures.size())):
		var case: Dictionary = deflection_motion_failures[index]
		print("  seed %d %s/%s defender=%d %.2fm in %.2fs = %.2fm/s" % [
			case.seed, case.block_side, case.defense_side, case.actor_id,
			case.distance_meters, case.duration, case.speed_mps,
		])

	print("")
	print("=== set and attack depth from net ===")
	print("%-26s %5s %7s %7s %7s %7s %7s %7s" % [
		"side / lane", "n", "ask05", "ask50", "ball05", "ball50",
		"hit05", "hit50",
	])
	var depth_keys := set_contact_depths.keys()
	depth_keys.sort()
	for key in depth_keys:
		_print_set_depth_bucket(str(key), set_contact_depths[key])
	print("")
	print("=== hitter set-path reading ===")
	var path_keys := set_path_outcomes.keys()
	path_keys.sort()
	for key in path_keys:
		print("  %-28s %5d" % [str(key), int(set_path_outcomes[key])])
	print("metadata/trajectory failures: %d" % set_path_failures.size())
	for index in range(mini(12, set_path_failures.size())):
		var case: Dictionary = set_path_failures[index]
		print("  seed %d %s actor=%d outcome=%s  %s" % [
			case.seed, case.side, case.actor_id, case.outcome, case.reason,
		])
	quit(1 if not ownership_failures.is_empty() \
		or not routing_failures.is_empty() \
		or not tempo_failures.is_empty() \
		or not second_contact_failures.is_empty() \
		or not missing_jump_timing.is_empty() \
		or not deflection_motion_failures.is_empty() \
		or not set_path_failures.is_empty() else 0)


func _collect_set_contact_depths(
	result: Resource,
	seed_value: int,
	buckets: Dictionary,
	outcomes: Dictionary,
	failures: Array[Dictionary],
) -> void:
	var contacts := _contacts(result)
	var latest_set_by_side := {}
	for event in contacts:
		var side := str(event.metadata.get("side", "?"))
		if int(event.event_type) == RallyEventScript.EventType.SET:
			latest_set_by_side[side] = event
			continue
		if int(event.event_type) != RallyEventScript.EventType.ATTACK \
				or not latest_set_by_side.has(side):
			continue
		var set_event: Resource = latest_set_by_side[side]
		var intended := Vector2(set_event.metadata.get(
			"intended_target", set_event.end_position
		))
		var delivered := Vector2(set_event.end_position)
		var struck := Vector2(event.start_position)
		var body := Vector2(event.metadata.get(
			"body_contact_position", struck
		))
		var set_path_outcome := str(event.metadata.get(
			"set_path_outcome", "missing"
		))
		var set_path_read: Dictionary = event.metadata.get("set_path_read", {})
		var set_path_contact: Dictionary = event.metadata.get(
			"set_path_contact", {}
		)
		var outgoing: Dictionary = event.metadata.get("outgoing_trajectory", {})
		var row := {
			"seed": seed_value,
			"intended_m": absf(intended.y - CourtConstants.NET_Y)
				* CourtConstants.COURT_LENGTH_METERS,
			"delivered_m": absf(delivered.y - CourtConstants.NET_Y)
				* CourtConstants.COURT_LENGTH_METERS,
			"struck_m": absf(struck.y - CourtConstants.NET_Y)
				* CourtConstants.COURT_LENGTH_METERS,
			"body_m": absf(body.y - CourtConstants.NET_Y)
				* CourtConstants.COURT_LENGTH_METERS,
			"ball_body_gap_m": RallyKinematics.court_distance_meters(body, struck),
			"path_error_m": float(set_path_contact.get("error_meters", 0.0)),
			"read_error_m": float(set_path_read.get(
				"perception_error_meters", 0.0
			)),
			"set_path_outcome": set_path_outcome,
			"crossed_net": (side == "home" and struck.y <= CourtConstants.NET_Y) \
				or (side == "opponent" and struck.y >= CourtConstants.NET_Y),
			"net_outcome": str(event.metadata.get("geometric_outcome", "")) == "net",
		}
		var lane := str(event.metadata.get("lane", "unknown"))
		_note(buckets, "%s / %s" % [side, lane], row)
		var outcome_key := "%s / %s" % [side, set_path_outcome]
		outcomes[outcome_key] = int(outcomes.get(outcome_key, 0)) + 1
		var reasons: Array[String] = []
		if set_path_outcome == "missing" or set_path_read.is_empty() \
				or set_path_contact.is_empty():
			reasons.append("set-path evidence is missing")
		if bool(set_path_read.get("uses_delivered_truth", true)):
			reasons.append("hitter movement consumed delivered truth")
		var body_crossed := (side == "home" and body.y <= CourtConstants.NET_Y) \
			or (side == "opponent" and body.y >= CourtConstants.NET_Y)
		if body_crossed:
			reasons.append("hitter body crossed the net plane")
		if bool(event.metadata.get("set_path_whiff", false)):
			var endpoint := Vector2(outgoing.get("end_position", event.end_position))
			var dropped_opponent_side := (
				side == "home" and endpoint.y < CourtConstants.NET_Y
			) or (side == "opponent" and endpoint.y > CourtConstants.NET_Y)
			if bool(event.success) or not bool(event.metadata.get(
				"attack_missed", false
			)):
				reasons.append("whiff is not a failed attack")
			if dropped_opponent_side:
				reasons.append("untouched set was drawn across the net")
		if not reasons.is_empty():
			failures.append({
				"seed": seed_value,
				"side": side,
				"actor_id": int(event.actor_id),
				"outcome": set_path_outcome,
				"reason": "; ".join(reasons),
			})


func _print_set_depth_bucket(key: String, rows: Array) -> void:
	var intended: Array = []
	var delivered: Array = []
	var struck: Array = []
	var bodies: Array = []
	var gaps: Array = []
	var path_errors: Array = []
	var crossed := 0
	var netted := 0
	for row in rows:
		intended.append(float(row.intended_m))
		delivered.append(float(row.delivered_m))
		struck.append(float(row.struck_m))
		bodies.append(float(row.body_m))
		gaps.append(float(row.ball_body_gap_m))
		path_errors.append(float(row.path_error_m))
		crossed += 1 if bool(row.crossed_net) else 0
		netted += 1 if bool(row.net_outcome) else 0
	intended.sort()
	delivered.sort()
	struck.sort()
	bodies.sort()
	gaps.sort()
	path_errors.sort()
	print("%-26s %5d %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f  body05=%.2f gap50=%.2f err95=%.2f cross=%d net=%d" % [
		key, rows.size(), _at(intended, 0.05), _at(intended, 0.50),
		_at(delivered, 0.05), _at(delivered, 0.50),
		_at(struck, 0.05), _at(struck, 0.50), _at(bodies, 0.05),
		_at(gaps, 0.50), _at(path_errors, 0.95), crossed, netted,
	])


func _collect_attacks(result: Resource, seed_value: int, buckets: Dictionary) -> void:
	var contacts := _contacts(result)
	var profiles: Dictionary = result.player_physical_profiles
	for index in range(contacts.size()):
		var event: Resource = contacts[index]
		if int(event.event_type) != RallyEventScript.EventType.ATTACK:
			continue
		var trajectory: Dictionary = event.metadata.get("outgoing_trajectory", {})
		if trajectory.is_empty():
			continue
		var next_contact: Resource = contacts[index + 1] \
			if index + 1 < contacts.size() else null
		var display: Dictionary = BallPresentation.display_trajectory(
			event, next_contact, trajectory, profiles
		)
		var start_height := float(display.get("start_height_meters", 0.0))
		var apex := float(display.get("apex_height_meters", start_height))
		var attack_type := str(event.metadata.get("attack_type", "Attack"))
		var launch_mode := str(event.metadata.get("launch_mode", "unknown"))
		var family := "ROLL" if "roll" in attack_type.to_lower() else "OTHER"
		var row := {
			"rise": maxf(apex - start_height, 0.0),
			"apex": apex,
			"seed": seed_value,
			"attack_type": attack_type,
			"launch_mode": launch_mode,
			"side": str(event.metadata.get("side", "?")),
			"angle": rad_to_deg(atan2(
				float(display.get("launch_vertical_mps", 0.0)),
				maxf(
					RallyKinematics.court_distance_meters(
						Vector2(display.get("start_position", Vector2.ZERO)),
						Vector2(display.get("end_position", Vector2.ZERO)),
					) / maxf(float(display.get("duration", 0.0)), 0.001),
					0.001,
				),
			)),
			"duration": float(display.get("duration", 0.0)),
			"distance": RallyKinematics.court_distance_meters(
				Vector2(display.get("start_position", Vector2.ZERO)),
				Vector2(display.get("end_position", Vector2.ZERO)),
			),
			"trajectory_type": str(trajectory.get("trajectory_type", "")),
			"next_type": next_contact.type_name() if next_contact != null else "floor",
			"speed": sqrt(
				pow(float(display.get("launch_vertical_mps", 0.0)), 2.0)
				+ pow(
					RallyKinematics.court_distance_meters(
						Vector2(display.get("start_position", Vector2.ZERO)),
						Vector2(display.get("end_position", Vector2.ZERO)),
					) / maxf(float(display.get("duration", 0.0)), 0.001),
					2.0,
				)
			),
			"detail": "%s q=%.2f power=%.2f raw=(%s -> %s)" % [
				str(event.metadata.get("geometric_outcome", "")),
				float(event.quality),
				float(event.metadata.get("chosen_power_fraction", 0.0)),
				str(trajectory.get("start_position", Vector2.ZERO)),
				str(trajectory.get("end_position", Vector2.ZERO)),
			],
		}
		_note(buckets, "%s · %s" % [family, launch_mode], row)
		_note(buckets, "ALL · all", row)
		if family == "ROLL":
			_note(buckets, "ROLL · all", row)


func _collect_block_ownership(
	result: Resource,
	seed_value: int,
	out_contacts: Array[Dictionary],
	failures: Array[Dictionary],
	soft_contacts: Array[Dictionary],
	routing_failures: Array[Dictionary],
) -> void:
	var contacts := _contacts(result)
	for contact_index in range(contacts.size()):
		var event: Resource = contacts[contact_index]
		if int(event.event_type) != RallyEventScript.EventType.BLOCK:
			continue
		if not bool(event.success):
			continue
		var trajectory: Dictionary = event.metadata.get("outgoing_trajectory", {})
		if trajectory.is_empty():
			continue
		var endpoint := Vector2(trajectory.get(
			"end_position", event.end_position
		))
		var side := str(event.metadata.get("side", ""))
		if side not in ["home", "opponent"]:
			continue
		var outcome := str(event.metadata.get("outcome", ""))
		var event_matches := Vector2(event.end_position).is_equal_approx(endpoint)
		var behind_wall := _on_blocking_side(endpoint, side)
		if behind_wall and outcome == "touch":
			var next_contact: Resource = contacts[contact_index + 1] \
				if contact_index + 1 < contacts.size() else null
			var touch_case := {
				"seed": seed_value,
				"side": side,
				"outcome": outcome,
				"end": endpoint,
				"next_type": next_contact.type_name() if next_contact != null else "none",
				"next_side": str(next_contact.metadata.get("side", "")) \
					if next_contact != null else "",
				"reason": "",
			}
			soft_contacts.append(touch_case)
			if not event_matches:
				touch_case["reason"] = "event endpoint differs from drawn trajectory"
				routing_failures.append(touch_case)
			elif next_contact == null \
					or int(next_contact.event_type) != RallyEventScript.EventType.DEFENSE \
					or str(next_contact.metadata.get("side", "")) != side:
				touch_case["reason"] = "next defense belongs to the wrong side"
				routing_failures.append(touch_case)
		elif outcome == "recycle":
			var next_contact: Resource = contacts[contact_index + 1] \
				if contact_index + 1 < contacts.size() else null
			var expected_side := "opponent" if side == "home" else "home"
			var recycle_case := {
				"seed": seed_value,
				"side": side,
				"outcome": outcome,
				"end": endpoint,
				"next_type": next_contact.type_name() if next_contact != null else "none",
				"next_side": str(next_contact.metadata.get("side", "")) \
					if next_contact != null else "",
				"reason": "",
			}
			soft_contacts.append(recycle_case)
			if behind_wall:
				recycle_case["reason"] = "recycle landed behind the blocking wall"
				routing_failures.append(recycle_case)
			elif next_contact == null \
					or int(next_contact.event_type) != RallyEventScript.EventType.DEFENSE \
					or str(next_contact.metadata.get("side", "")) != expected_side \
					or str(next_contact.metadata.get("coverage", "")) != "attack":
				recycle_case["reason"] = "next attack coverage belongs to the wrong side"
				routing_failures.append(recycle_case)
		elif behind_wall and outcome == "stuff":
			routing_failures.append({
				"seed": seed_value, "side": side, "outcome": outcome,
				"end": endpoint, "next_type": "-", "next_side": "-",
				"reason": "stuff landed behind its own wall",
			})
		elif not event_matches:
			routing_failures.append({
				"seed": seed_value, "side": side, "outcome": outcome,
				"end": endpoint, "next_type": "-", "next_side": "-",
				"reason": "event endpoint differs from drawn trajectory",
			})
		if _inside_court(endpoint):
			continue
		var expected_home := side == "opponent"
		var case := {
			"seed": seed_value,
			"side": side,
			"outcome": outcome,
			"end": endpoint,
			"home_won": bool(result.home_team_won),
			"expected_home": expected_home,
			"terminal": str(result.terminal_outcome),
		}
		out_contacts.append(case)
		if bool(result.home_team_won) != expected_home:
			failures.append(case)


func _collect_tempo_and_contact_rules(
	result: Resource,
	seed_value: int,
	tempo_counts: Dictionary,
	tempo_failures: Array[Dictionary],
	second_contact_failures: Array[Dictionary],
	missing_jump_timing: Array[Dictionary],
) -> void:
	var contacts := _contacts(result)
	var second_contact_checks := 0
	var missed_attacks_with_walls := 0
	for event in contacts:
		if int(event.event_type) != RallyEventScript.EventType.ATTACK:
			continue
		var side := str(event.metadata.get("side", "?"))
		var timing: Dictionary = event.metadata.get("tempo_coordination", {})
		if not timing.is_empty():
			var requested := clampi(int(timing.get("tempo", 3)), 0, 3)
			var progress := float(timing.get("achieved_release_progress", 0.0))
			var achieved := ApproachMechanicsScript.achieved_tempo(timing, progress)
			var published_achieved := int(event.metadata.get(
				"achieved_tempo", -1
			))
			var key := "T%d -> T%d" % [requested, published_achieved]
			tempo_counts[key] = int(tempo_counts.get(key, 0)) + 1
			var reasons: Array[String] = []
			if published_achieved != achieved:
				reasons.append("achieved tempo disagrees with release progress")
			var relationship := str(event.metadata.get("tempo_relationship", ""))
			if relationship != ApproachMechanicsScript.TEMPO_RELATIONSHIPS[achieved]:
				reasons.append("published relationship disagrees with achieved tempo")
			var requested_relationship := str(event.metadata.get(
				"requested_tempo_relationship", ""
			))
			if requested_relationship \
					!= ApproachMechanicsScript.TEMPO_RELATIONSHIPS[requested]:
				reasons.append("requested relationship disagrees with the call")
			var release_position: Variant = timing.get("release_position", null)
			if not (release_position is Vector2) \
					or not Vector2(event.metadata.get(
						"movement_start", event.start_position
					)).is_equal_approx(Vector2(release_position)):
				reasons.append("drawn approach does not start at setter release position")
			var published_flight := float(event.metadata.get(
				"set_flight_time",
				event.metadata.get("set_flight_seconds", -1.0),
			))
			if published_flight < 0.0 or absf(
				published_flight - float(timing.get(
					"delivered_flight_seconds", -2.0
				))
			) > 0.001:
				reasons.append("attack and tempo clock disagree on set flight")
			var delay := float(event.metadata.get("movement_delay_seconds", 0.0))
			if published_achieved == 3 and delay <= 0.0:
				reasons.append("achieved T3 has no post-release approach delay")
			elif published_achieved != 3 and delay > 0.001:
				reasons.append("achieved pre-release tempo carries a T3 delay")
			if not reasons.is_empty():
				tempo_failures.append({
					"seed": seed_value, "side": side,
					"actor_id": int(event.actor_id),
					"reason": "; ".join(reasons),
				})
		if bool(event.metadata.get("attack_missed", false)) \
				and int(event.metadata.get("wall_size", 0)) > 0:
			missed_attacks_with_walls += 1
			var jump_timing: Dictionary = event.metadata.get(
				"block_jump_timing", {}
			)
			if jump_timing.is_empty():
				missing_jump_timing.append({
					"seed": seed_value, "side": side,
					"actor_id": int(event.actor_id),
				})

	for index in range(contacts.size() - 1):
		var first: Resource = contacts[index]
		if not bool(first.success) or int(first.event_type) not in [
			RallyEventScript.EventType.RECEPTION,
			RallyEventScript.EventType.DEFENSE,
		]:
			continue
		var side := str(first.metadata.get("side", ""))
		var next_index := index + 1
		while next_index < contacts.size() \
				and int(contacts[next_index].event_type) \
					== RallyEventScript.EventType.BLOCK:
			next_index += 1
		if next_index >= contacts.size():
			continue
		var second: Resource = contacts[next_index]
		if int(second.event_type) != RallyEventScript.EventType.SET \
				or str(second.metadata.get("side", "")) != side:
			continue
		second_contact_checks += 1
		var reasons: Array[String] = []
		if int(first.actor_id) == int(second.actor_id):
			reasons.append("the first-contact player also took second contact")
		if second.metadata.has("first_contact_id") \
				and int(second.metadata.first_contact_id) != int(first.actor_id):
			reasons.append("SET first_contact_id names a different player")
		if not reasons.is_empty():
			second_contact_failures.append({
				"seed": seed_value, "side": side,
				"actor_id": int(first.actor_id),
				"reason": "; ".join(reasons),
			})
	result.analysis["probe_second_contact_checks"] = second_contact_checks
	result.analysis["probe_missed_attacks_with_walls"] = \
		missed_attacks_with_walls


func _collect_deflection_motion(
	result: Resource,
	seed_value: int,
	rows: Array[Dictionary],
	failures: Array[Dictionary],
) -> void:
	var contacts := _contacts(result)
	for index in range(contacts.size() - 1):
		var block: Resource = contacts[index]
		var defense: Resource = contacts[index + 1]
		if int(block.event_type) != RallyEventScript.EventType.BLOCK \
				or not bool(block.success) \
				or int(defense.event_type) != RallyEventScript.EventType.DEFENSE:
			continue
		var trajectory: Dictionary = block.metadata.get("outgoing_trajectory", {})
		if trajectory.is_empty():
			continue
		var display := BallPresentation.display_trajectory(
			block, defense, trajectory, result.player_physical_profiles
		)
		var duration := maxf(float(display.get("duration", 0.0)), 0.001)
		var movement_start := Vector2(defense.metadata.get(
			"movement_start", defense.start_position
		))
		var distance := RallyKinematics.court_distance_meters(
			movement_start, defense.start_position
		)
		var speed := distance / duration
		var row := {
			"seed": seed_value,
			"block_side": str(block.metadata.get("side", "?")),
			"defense_side": str(defense.metadata.get("side", "?")),
			"actor_id": int(defense.actor_id),
			"outcome": str(block.metadata.get("outcome", "")),
			"distance_meters": distance,
			"duration": duration,
			"speed_mps": speed,
			"vertical_mps": float(trajectory.get("launch_vertical_mps", 0.0)),
			"ball_distance_meters": RallyKinematics.court_distance_meters(
				Vector2(display.get("start_position", Vector2.ZERO)),
				Vector2(display.get("end_position", Vector2.ZERO)),
			),
			"rise_meters": maxf(
				float(display.get("apex_height_meters", 0.0))
					- float(display.get("start_height_meters", 0.0)),
				0.0,
			),
		}
		rows.append(row)
		if speed > MAX_PLAUSIBLE_COVERAGE_SPEED_MPS and distance > 0.25:
			failures.append(row)


func _contacts(result: Resource) -> Array:
	var contacts: Array = []
	for raw_event in result.events:
		var event: Resource = raw_event
		if int(event.event_type) in [
			RallyEventScript.EventType.SET_DECISION,
			RallyEventScript.EventType.POINT,
		]:
			continue
		contacts.append(event)
	return contacts


func _inside_court(point: Vector2) -> bool:
	return point.x >= 0.0 and point.x <= 1.0 \
		and point.y >= 0.0 and point.y <= 1.0


func _on_blocking_side(point: Vector2, blocking_side: String) -> bool:
	if not _inside_court(point):
		return false
	return point.y > 0.5 if blocking_side == "home" else point.y < 0.5


func _note(buckets: Dictionary, key: String, row: Dictionary) -> void:
	if not buckets.has(key):
		buckets[key] = []
	(buckets[key] as Array).append(row)


func _print_attack_bucket(key: String, rows: Array) -> void:
	var rises: Array = []
	var apexes: Array = []
	for row in rows:
		rises.append(float(row.rise))
		apexes.append(float(row.apex))
	rises.sort()
	apexes.sort()
	print("%-32s %6d %8.2f %8.2f %8.2f %8.2f %8.2f" % [
		key, rows.size(), _at(rises, 0.50), _at(rises, 0.90),
		_at(rises, 0.95), _at(apexes, 0.95), _at(apexes, 1.0),
	])


func _print_attack_case(row: Dictionary) -> void:
	print(
		"  seed %d %s/%s  apex %.2f m (+%.2f), angle %.1f°, %.2f s, %.2f m, v=%.2f  %s -> %s  %s"
		% [
			row.seed, row.side, row.launch_mode, row.apex, row.rise,
			row.angle, row.duration, row.distance, row.speed,
			row.trajectory_type, row.next_type, row.detail,
		]
	)


func _at(sorted_values: Array, quantile: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	return float(sorted_values[clampi(
		int(floor(quantile * float(sorted_values.size() - 1))),
		0, sorted_values.size() - 1,
	)])
